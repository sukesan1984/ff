class_name Background
extends Node2D
## 時間帯が朝→昼→夕→夜→朝とループする多層パララックス背景。

var W := 540.0
var H := 960.0

var scroll := 0.0       # 横スクロール総距離
var tod := 0.08         # time of day 0..1(0=朝, 0.25=昼, 0.5=夕, 0.7=夜）
var _stars: Array = []  # [Vector2 pos, float phase, float size]
var _t := 0.0

# 時間帯キーフレーム: pos, 空上, 空下, 星のalpha, 天体色, 天体が月か
const KEYS := [
	{ "p": 0.00, "top": Color(0.42, 0.55, 0.95), "bot": Color(1.0, 0.78, 0.62), "star": 0.0, "cel": Color(1.0, 0.95, 0.7), "moon": false },   # 朝焼け
	{ "p": 0.22, "top": Color(0.30, 0.68, 1.00), "bot": Color(0.72, 0.92, 1.0), "star": 0.0, "cel": Color(1.0, 0.97, 0.8), "moon": false },   # 昼
	{ "p": 0.45, "top": Color(1.00, 0.62, 0.45), "bot": Color(1.0, 0.84, 0.55), "star": 0.0, "cel": Color(1.0, 0.7, 0.35), "moon": false },   # 夕
	{ "p": 0.58, "top": Color(0.10, 0.10, 0.30), "bot": Color(0.45, 0.25, 0.40), "star": 0.7, "cel": Color(0.95, 0.95, 1.0), "moon": true },  # 宵
	{ "p": 0.80, "top": Color(0.04, 0.05, 0.16), "bot": Color(0.10, 0.13, 0.30), "star": 1.0, "cel": Color(0.95, 0.95, 1.0), "moon": true },  # 深夜
	{ "p": 1.00, "top": Color(0.42, 0.55, 0.95), "bot": Color(1.0, 0.78, 0.62), "star": 0.2, "cel": Color(1.0, 0.95, 0.7), "moon": false },   # 朝へ戻る
]


func _ready() -> void:
	z_index = -20
	var seed := 9137
	for i in 90:
		seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
		var x := float(seed % 1000) / 1000.0 * W
		seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
		var y := float(seed % 1000) / 1000.0 * H * 0.6
		seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
		var ph := float(seed % 1000) / 1000.0 * TAU
		seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
		var sz := 1.0 + float(seed % 100) / 100.0 * 1.8
		_stars.append([Vector2(x, y), ph, sz])


func tick(world_dx: float, delta: float) -> void:
	scroll += world_dx
	tod = fposmod(tod + world_dx * 0.000018, 1.0)
	_t += delta
	queue_redraw()


func _interp() -> Dictionary:
	# 現在のtodに対応する空・天体の状態を補間して返す
	var a = KEYS[0]
	var b = KEYS[KEYS.size() - 1]
	for i in range(KEYS.size() - 1):
		if tod >= KEYS[i]["p"] and tod <= KEYS[i + 1]["p"]:
			a = KEYS[i]
			b = KEYS[i + 1]
			break
	var span: float = max(0.0001, b["p"] - a["p"])
	var f: float = clampf((tod - a["p"]) / span, 0.0, 1.0)
	return {
		"top": a["top"].lerp(b["top"], f),
		"bot": a["bot"].lerp(b["bot"], f),
		"star": lerpf(a["star"], b["star"], f),
		"cel": a["cel"].lerp(b["cel"], f),
		"moon": a["moon"] if f < 0.5 else b["moon"],
	}


func _draw() -> void:
	var s := _interp()
	# 空グラデーション(頂点カラー付きポリゴン)
	var pts := PackedVector2Array([Vector2(0, 0), Vector2(W, 0), Vector2(W, H), Vector2(0, H)])
	var cols := PackedColorArray([s["top"], s["top"], s["bot"], s["bot"]])
	draw_polygon(pts, cols)

	# 星
	var sa: float = s["star"]
	if sa > 0.01:
		for st in _stars:
			var twinkle: float = 0.6 + 0.4 * sin(_t * 2.0 + st[1])
			var pos: Vector2 = st[0]
			pos.x = fposmod(pos.x - scroll * 0.04, W)
			draw_circle(pos, st[2], Color(1, 1, 1, sa * twinkle))

	# 天体(太陽/月)— todに沿って弧を描く
	var arc := fposmod(tod * 1.0, 1.0)
	var cx := W * (1.15 - arc * 1.3)
	var cy := H * 0.34 + sin(arc * PI) * -H * 0.16 + H * 0.06
	var cel: Color = s["cel"]
	if s["moon"]:
		draw_circle(Vector2(cx, cy), 38, cel)
		draw_circle(Vector2(cx + 13, cy - 10), 38, Color(s["top"].r, s["top"].g, s["top"].b, 1.0))  # 三日月の欠け
	else:
		draw_circle(Vector2(cx, cy), 70, Color(cel.r, cel.g, cel.b, 0.20))  # 太陽のハロー
		draw_circle(Vector2(cx, cy), 44, cel)

	# 遠景の丘(パララックス遅い)
	_draw_hills(scroll * 0.06, H * 0.70, 120.0, s["bot"].darkened(0.45), 220.0)
	_draw_hills(scroll * 0.11, H * 0.78, 90.0, s["bot"].darkened(0.62), 170.0)

	# 雲(パララックス速い)
	var cloud_col := Color(1, 1, 1, lerpf(0.85, 0.18, s["star"]))
	for i in 6:
		var base_x := float(i) * 230.0
		var cxp := fposmod(base_x - scroll * 0.22, W + 260.0) - 130.0
		var cyp := 90.0 + float((i * 137) % 220)
		_draw_cloud(Vector2(cxp, cyp), 1.0 + float(i % 3) * 0.35, cloud_col)


func _draw_hills(off: float, base_y: float, amp: float, col: Color, wl: float) -> void:
	var pts := PackedVector2Array()
	pts.append(Vector2(0, H))
	var x := 0.0
	while x <= W:
		var y := base_y - sin((x + off) / wl * TAU) * amp * 0.5 - amp * 0.5
		pts.append(Vector2(x, y))
		x += 16.0
	pts.append(Vector2(W, H))
	draw_colored_polygon(pts, col)


func _draw_cloud(pos: Vector2, sc: float, col: Color) -> void:
	draw_circle(pos, 26 * sc, col)
	draw_circle(pos + Vector2(30 * sc, 6 * sc), 20 * sc, col)
	draw_circle(pos + Vector2(-28 * sc, 8 * sc), 18 * sc, col)
	draw_circle(pos + Vector2(6 * sc, -14 * sc), 18 * sc, col)
