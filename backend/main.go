// Flappy Fever ランキング用の軽量バックエンド。
// 静的ファイル(Godot Web書き出し)と /api/scores を同一オリジンで配信する。
package main

import (
	"context"
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"log"
	"mime"
	"net/http"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"
	"unicode"

	"cloud.google.com/go/firestore"
	"google.golang.org/api/iterator"
)

const (
	collection = "scores"
	topN       = 10
	maxName    = 12
	maxScore   = 200000 // 現実的な上限
	// スコアの稼ぎ速度の上限(points/秒)。実プレイの最大瞬間値より十分高く、
	// 「数秒で数万点」のような偽投稿だけを弾く
	maxPtsPerSec = 150
)

var (
	fsClient   *firestore.Client
	staticDir  = envOr("STATIC_DIR", "/web")
	hmacSecret []byte
)

type scoreEntry struct {
	Name  string `firestore:"name" json:"name"`
	Score int    `firestore:"score" json:"score"`
}

// ---------------------------------------------------------------- ランタイムトークン
// ラン開始時に発行するHMAC署名付きトークン。送信時に「経過時間 vs スコア」の
// 整合を検証し、curl等での即席偽スコアを弾く(完全防御ではなく敷居上げ)。

func initSecret() {
	if s := os.Getenv("HMAC_SECRET"); s != "" {
		hmacSecret = []byte(s)
		return
	}
	hmacSecret = make([]byte, 32)
	if _, err := rand.Read(hmacSecret); err != nil {
		log.Fatalf("secret: %v", err)
	}
	log.Printf("WARN: HMAC_SECRET 未設定。ランダム秘密鍵を使用(複数インスタンスでトークン検証が失敗し得ます)")
}

func signTS(ts string) string {
	mac := hmac.New(sha256.New, hmacSecret)
	mac.Write([]byte(ts))
	return hex.EncodeToString(mac.Sum(nil))
}

func issueToken() string {
	ts := strconv.FormatInt(time.Now().Unix(), 10)
	return ts + "." + signTS(ts)
}

func validToken(tok string, score int) bool {
	parts := strings.SplitN(tok, ".", 2)
	if len(parts) != 2 {
		return false
	}
	if !hmac.Equal([]byte(signTS(parts[0])), []byte(parts[1])) {
		return false
	}
	ts, err := strconv.ParseInt(parts[0], 10, 64)
	if err != nil {
		return false
	}
	age := time.Now().Unix() - ts
	if age < 0 || age > 6*3600 {
		return false // 未来 or 6時間超は無効
	}
	return age >= int64(score/maxPtsPerSec) // スコアに見合う経過時間が必要
}

func main() {
	initSecret()
	ctx := context.Background()
	var err error
	fsClient, err = firestore.NewClient(ctx, firestore.DetectProjectID)
	if err != nil {
		log.Fatalf("firestore init: %v", err)
	}
	defer fsClient.Close()

	mime.AddExtensionType(".wasm", "application/wasm")
	mime.AddExtensionType(".pck", "application/octet-stream")
	mime.AddExtensionType(".js", "application/javascript")

	mux := http.NewServeMux()
	mux.HandleFunc("/api/scores", handleScores)
	mux.HandleFunc("/api/daily", handleDaily)
	mux.HandleFunc("/api/run-token", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, http.StatusOK, map[string]string{"token": issueToken()})
	})
	mux.HandleFunc("/api/healthz", func(w http.ResponseWriter, r *http.Request) { w.Write([]byte("ok")) })
	mux.HandleFunc("/", serveStatic)

	port := envOr("PORT", "8080")
	log.Printf("listening on :%s (static=%s)", port, staticDir)
	if err := http.ListenAndServe(":"+port, securityHeaders(mux)); err != nil {
		log.Fatal(err)
	}
}

// 静的ファイル配信。Cloud Run の 32MiB レスポンス上限を避けるため、
// 事前gzip(.gz)があればそれを Content-Encoding: gzip で返す(wasm は圧縮で約13MB)。
func serveStatic(w http.ResponseWriter, r *http.Request) {
	upath := r.URL.Path
	if upath == "/" || upath == "" {
		upath = "/index.html"
	}
	clean := filepath.Clean("/" + strings.TrimPrefix(upath, "/"))
	root := filepath.Clean(staticDir)
	full := filepath.Join(root, clean)
	if full != root && !strings.HasPrefix(full, root+string(os.PathSeparator)) {
		http.NotFound(w, r)
		return
	}
	if strings.Contains(r.Header.Get("Accept-Encoding"), "gzip") {
		if fi, err := os.Stat(full + ".gz"); err == nil && !fi.IsDir() {
			if f, err := os.Open(full + ".gz"); err == nil {
				defer f.Close()
				if ct := mime.TypeByExtension(filepath.Ext(full)); ct != "" {
					w.Header().Set("Content-Type", ct)
				}
				w.Header().Set("Content-Encoding", "gzip")
				w.Header().Add("Vary", "Accept-Encoding")
				r.Header.Del("Range") // gzip配信時はレンジ無効化
				http.ServeContent(w, r, filepath.Base(full), fi.ModTime(), f)
				return
			}
		}
	}
	http.ServeFile(w, r, full)
}

func handleScores(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodGet:
		writeJSON(w, http.StatusOK, map[string]any{"scores": fetchTop(r.Context())})
	case http.MethodPost:
		if !allow(clientIP(r)) {
			writeJSON(w, http.StatusTooManyRequests, map[string]string{"error": "rate limited"})
			return
		}
		var body struct {
			Name  string `json:"name"`
			Score int    `json:"score"`
			Token string `json:"token"`
		}
		if err := json.NewDecoder(http.MaxBytesReader(w, r.Body, 2048)).Decode(&body); err != nil {
			writeJSON(w, http.StatusBadRequest, map[string]string{"error": "bad json"})
			return
		}
		name := sanitizeName(body.Name)
		if body.Score < 0 || body.Score > maxScore {
			writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid score"})
			return
		}
		if !validToken(body.Token, body.Score) {
			writeJSON(w, http.StatusForbidden, map[string]string{"error": "invalid token"})
			return
		}
		_, _, err := fsClient.Collection(collection).Add(r.Context(), scoreEntry{Name: name, Score: body.Score})
		if err != nil {
			log.Printf("add: %v", err)
			writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "store failed"})
			return
		}
		writeJSON(w, http.StatusOK, map[string]any{"scores": fetchTop(r.Context())})
	default:
		w.Header().Set("Allow", "GET, POST")
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
	}
}

// ---------------------------------------------------------------- デイリー挑戦
// 全員が同じシード(日付)の世界を飛ぶ。日別ランキング + 王者ゴースト(飛行軌跡)。

var jst = time.FixedZone("JST", 9*3600)

const maxPath = 100000 // ゴースト軌跡の最大文字数

type ghostEntry struct {
	Name  string `firestore:"name" json:"name"`
	Score int    `firestore:"score" json:"score"`
	Path  string `firestore:"path" json:"path"`
}

type dailyPost struct {
	Name  string `json:"name"`
	Score int    `json:"score"`
	Path  string `json:"path"`
	Token string `json:"token"`
}

func dailyDay() string {
	return time.Now().In(jst).Format("20060102")
}

func dailyCollection(day string) string {
	return "daily_" + day
}

func fetchDaily(ctx context.Context, day string) ([]scoreEntry, *ghostEntry) {
	out := []scoreEntry{}
	it := fsClient.Collection(dailyCollection(day)).OrderBy("score", firestore.Desc).Limit(topN).Documents(ctx)
	defer it.Stop()
	for {
		doc, err := it.Next()
		if err == iterator.Done {
			break
		}
		if err != nil {
			log.Printf("daily query: %v", err)
			break
		}
		var e scoreEntry
		if doc.DataTo(&e) == nil {
			out = append(out, e)
		}
	}
	sort.SliceStable(out, func(i, j int) bool { return out[i].Score > out[j].Score })
	var ghost *ghostEntry
	gdoc, err := fsClient.Collection("ghosts").Doc(day).Get(ctx)
	if err == nil {
		var g ghostEntry
		if gdoc.DataTo(&g) == nil {
			ghost = &g
		}
	}
	return out, ghost
}

func handleDaily(w http.ResponseWriter, r *http.Request) {
	day := dailyDay()
	switch r.Method {
	case http.MethodGet:
		scores, ghost := fetchDaily(r.Context(), day)
		writeJSON(w, http.StatusOK, map[string]any{"day": day, "scores": scores, "ghost": ghost})
	case http.MethodPost:
		if !allow(clientIP(r)) {
			writeJSON(w, http.StatusTooManyRequests, map[string]string{"error": "rate limited"})
			return
		}
		var body dailyPost
		if err := json.NewDecoder(http.MaxBytesReader(w, r.Body, 256*1024)).Decode(&body); err != nil {
			writeJSON(w, http.StatusBadRequest, map[string]string{"error": "bad json"})
			return
		}
		name := sanitizeName(body.Name)
		if body.Score < 0 || body.Score > maxScore || len(body.Path) > maxPath {
			writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid"})
			return
		}
		if !validToken(body.Token, body.Score) {
			writeJSON(w, http.StatusForbidden, map[string]string{"error": "invalid token"})
			return
		}
		ctx := r.Context()
		if _, _, err := fsClient.Collection(dailyCollection(day)).Add(ctx, scoreEntry{Name: name, Score: body.Score}); err != nil {
			log.Printf("daily add: %v", err)
			writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "store failed"})
			return
		}
		// 王者ゴースト更新(本日の最高スコアなら軌跡を保存)
		if body.Path != "" {
			gref := fsClient.Collection("ghosts").Doc(day)
			cur, err := gref.Get(ctx)
			replace := true
			if err == nil {
				var g ghostEntry
				if cur.DataTo(&g) == nil && g.Score >= body.Score {
					replace = false
				}
			}
			if replace {
				if _, err := gref.Set(ctx, ghostEntry{Name: name, Score: body.Score, Path: body.Path}); err != nil {
					log.Printf("ghost set: %v", err)
				}
			}
		}
		scores, ghost := fetchDaily(ctx, day)
		writeJSON(w, http.StatusOK, map[string]any{"day": day, "scores": scores, "ghost": ghost})
	default:
		w.Header().Set("Allow", "GET, POST")
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
	}
}

func fetchTop(ctx context.Context) []scoreEntry {
	out := []scoreEntry{}
	it := fsClient.Collection(collection).OrderBy("score", firestore.Desc).Limit(topN).Documents(ctx)
	defer it.Stop()
	for {
		doc, err := it.Next()
		if err == iterator.Done {
			break
		}
		if err != nil {
			log.Printf("query: %v", err)
			break
		}
		var e scoreEntry
		if doc.DataTo(&e) == nil {
			out = append(out, e)
		}
	}
	// 念のため降順に整える
	sort.SliceStable(out, func(i, j int) bool { return out[i].Score > out[j].Score })
	return out
}

// 名前を安全な形に整える(制御文字除去・長さ制限・空なら「ななし」)
func sanitizeName(s string) string {
	s = strings.TrimSpace(s)
	var b strings.Builder
	for _, r := range s {
		if unicode.IsControl(r) {
			continue
		}
		b.WriteRune(r)
		if len([]rune(b.String())) >= maxName {
			break
		}
	}
	out := strings.TrimSpace(b.String())
	if out == "" {
		return "ななし"
	}
	return out
}

// --- 簡易レート制限(IPごと 1分20回まで)---
type bucket struct {
	count int
	reset time.Time
}

var (
	limMu   sync.Mutex
	buckets = map[string]*bucket{}
)

func allow(ip string) bool {
	limMu.Lock()
	defer limMu.Unlock()
	now := time.Now()
	b := buckets[ip]
	if b == nil || now.After(b.reset) {
		buckets[ip] = &bucket{count: 1, reset: now.Add(time.Minute)}
		return true
	}
	if b.count >= 20 {
		return false
	}
	b.count++
	return true
}

func clientIP(r *http.Request) string {
	if xff := r.Header.Get("X-Forwarded-For"); xff != "" {
		return strings.TrimSpace(strings.Split(xff, ",")[0])
	}
	return r.RemoteAddr
}

func securityHeaders(next http.Handler) http.Handler {
	const csp = "default-src 'self'; script-src 'self' 'unsafe-inline' 'wasm-unsafe-eval'; " +
		"worker-src 'self' blob:; child-src 'self' blob:; img-src 'self' data: blob:; " +
		"media-src 'self' data: blob:; style-src 'self' 'unsafe-inline'; connect-src 'self' blob:; " +
		"base-uri 'self'; form-action 'self'; frame-ancestors 'self'; object-src 'none'"
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		h := w.Header()
		h.Set("X-Content-Type-Options", "nosniff")
		h.Set("X-Frame-Options", "SAMEORIGIN")
		h.Set("Referrer-Policy", "no-referrer")
		h.Set("Cross-Origin-Resource-Policy", "same-origin")
		h.Set("Permissions-Policy", "geolocation=(), camera=(), microphone=(), payment=(), usb=()")
		h.Set("Strict-Transport-Security", "max-age=31536000; includeSubDomains")
		h.Set("Content-Security-Policy", csp)
		next.ServeHTTP(w, r)
	})
}

func writeJSON(w http.ResponseWriter, code int, v any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.Header().Set("Cache-Control", "no-store")
	w.WriteHeader(code)
	json.NewEncoder(w).Encode(v)
}

func envOr(k, def string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return def
}
