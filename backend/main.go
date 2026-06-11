// Flappy Fever ランキング用の軽量バックエンド。
// 静的ファイル(Godot Web書き出し)と /api/scores を同一オリジンで配信する。
package main

import (
	"context"
	"encoding/json"
	"log"
	"mime"
	"net/http"
	"os"
	"path/filepath"
	"sort"
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
	maxScore   = 1000000
)

var (
	fsClient  *firestore.Client
	staticDir = envOr("STATIC_DIR", "/web")
)

type scoreEntry struct {
	Name  string `firestore:"name" json:"name"`
	Score int    `firestore:"score" json:"score"`
}

func main() {
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
		var body scoreEntry
		if err := json.NewDecoder(http.MaxBytesReader(w, r.Body, 1024)).Decode(&body); err != nil {
			writeJSON(w, http.StatusBadRequest, map[string]string{"error": "bad json"})
			return
		}
		name := sanitizeName(body.Name)
		if body.Score < 0 || body.Score > maxScore {
			writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid score"})
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
