class_name Hud
extends Control
## 最前面のHUD。フィーバーゲージ、発動中パワーアップ、メダルを描画する。

var W := 540.0
var H := 960.0

var fever := 0.0
var fever_active := false
var fever_time := 0.0
var fever_max := 7.0

var shield := false
var slowmo_t := 0.0
var magnet_t := 0.0

var show_medal := false
var medal := 0  # 0=none,1=bronze,2=silver,3=gold,4=platinum
var build_list: Array = []  # 所持アビリティ [{short,lv,max,evo}]

const MEDAL_COLS := [
	Color(0.5, 0.5, 0.5),
	Color(0.80, 0.50, 0.30),
	Color(0.78, 0.80, 0.85),
	Color(1.00, 0.82, 0.25),
	Color(0.55, 0.90, 1.00),
]


var _font := load("res://fonts/MochiyPopOne-Regular.ttf")

func _hud_font() -> Font:
	return _font if _font else get_theme_default_font()


func _process(_d: float) -> void:
	queue_redraw()


var _ft := 0.0

func _draw() -> void:
	_ft += 0.016
	if fever_active:
		_draw_fever_border()
	_draw_fever_bar()
	_draw_powerups()
	_draw_build()
	if show_medal:
		_draw_medal(Vector2(W * 0.5, H * 0.5 - 70), 46, medal)


func _draw_fever_border() -> void:
	# フィーバー中:画面ふちに脈打つ虹色ボーダー
	var thick := 14.0 + 4.0 * sin(_ft * 8.0)
	var seg := 30
	for i in seg:
		var hue := fposmod(float(i) / seg + _ft * 0.6, 1.0)
		var c := Color.from_hsv(hue, 0.85, 1.0, 0.5)
		# 上下
		draw_rect(Rect2(W * i / seg, 0, W / seg + 1, thick), c)
		draw_rect(Rect2(W * i / seg, H - thick, W / seg + 1, thick), c)
	for i in seg:
		var hue2 := fposmod(float(i) / seg + _ft * 0.6 + 0.5, 1.0)
		var c2 := Color.from_hsv(hue2, 0.85, 1.0, 0.5)
		draw_rect(Rect2(0, H * i / seg, thick, H / seg + 1), c2)
		draw_rect(Rect2(W - thick, H * i / seg, thick, H / seg + 1), c2)


func _draw_build() -> void:
	if build_list.is_empty():
		return
	var f := _hud_font()
	var x := W - 150.0
	var y := 196.0
	for it in build_list:
		var evo: bool = it["evo"]
		var col := Color(1, 0.6, 0.2) if evo else Color(0.5, 0.85, 1.0)
		draw_rect(Rect2(x, y, 34, 24), Color(0, 0, 0, 0.35))
		draw_rect(Rect2(x + 1, y + 1, 32, 22), col.darkened(0.05))
		if f:
			draw_string(f, Vector2(x + 4, y + 18), str(it["short"]), HORIZONTAL_ALIGNMENT_LEFT, 30, 14, Color(0.1, 0.1, 0.12))
		var mx: int = it["max"]
		var lv: int = it["lv"]
		for i in mx:
			var on := i < lv
			draw_circle(Vector2(x + 42 + i * 11, y + 12), 4.0, col if on else Color(1, 1, 1, 0.22))
		y += 28.0


func _draw_fever_bar() -> void:
	var bw := 320.0
	var bh := 20.0
	var x := (W - bw) * 0.5
	var y := 132.0
	# 枠
	draw_rect(Rect2(x - 3, y - 3, bw + 6, bh + 6), Color(0, 0, 0, 0.35))
	draw_rect(Rect2(x, y, bw, bh), Color(0.1, 0.1, 0.14, 0.7))
	# 中身
	var fill := fever
	if fever_active:
		fill = clampf(fever_time / fever_max, 0.0, 1.0)
	var fw := bw * clampf(fill, 0.0, 1.0)
	if fw > 1.0:
		# 虹グラデを縦4頂点ポリゴンで近似(横方向に色変化)
		var seg := 24
		for i in range(seg):
			var f0 := float(i) / seg
			var f1 := float(i + 1) / seg
			if f0 > fill:
				break
			var sx := x + bw * f0
			var ex := x + bw * minf(f1, fill)
			var hue := fposmod(f0 * 0.8 + (fever_time if fever_active else 0.0) * 0.5, 1.0)
			var c := Color.from_hsv(hue, 0.8, 1.0) if fever_active else Color(1.0, 0.55 + f0 * 0.3, 0.15)
			draw_rect(Rect2(sx, y, ex - sx + 1, bh), c)
	# ラベル
	var f := _hud_font()
	var fs := 15
	var txt := "フィーバー！" if fever_active else "フィーバー"
	var col := Color(1, 1, 0.4) if (fever >= 1.0 and not fever_active) else Color(1, 1, 1, 0.85)
	if f:
		draw_string(f, Vector2(x + 2, y - 7), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _draw_powerups() -> void:
	var x := 28.0
	var y := 200.0
	if shield:
		_chip(Vector2(x, y), Color(0.45, 0.78, 1.0), 1.0, "盾")
		y += 56
	if slowmo_t > 0.0:
		_chip(Vector2(x, y), Color(0.75, 0.55, 1.0), clampf(slowmo_t / 4.0, 0, 1), "時")
		y += 56
	if magnet_t > 0.0:
		_chip(Vector2(x, y), Color(0.4, 0.95, 0.85), clampf(magnet_t / 6.0, 0, 1), "磁")
		y += 56


func _chip(pos: Vector2, col: Color, frac: float, letter: String) -> void:
	draw_circle(pos, 21, Color(0, 0, 0, 0.35))
	draw_circle(pos, 19, col.darkened(0.1))
	draw_circle(pos + Vector2(-5, -5), 9, col.lightened(0.4))
	# 残量アーク
	if frac < 1.0:
		draw_arc(pos, 23, -PI / 2, -PI / 2 + TAU * frac, 28, Color(1, 1, 1, 0.9), 3.0)
	var f := _hud_font()
	if f:
		draw_string(f, pos + Vector2(-9, 7), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color(1, 1, 1))


func _draw_medal(c: Vector2, r: float, level: int) -> void:
	if level <= 0:
		return
	var col: Color = MEDAL_COLS[clampi(level, 0, 4)]
	# リボン
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(-r * 0.5, 0), c + Vector2(-r * 0.2, 0),
		c + Vector2(-r * 0.2, r * 1.6), c + Vector2(-r * 0.55, r * 1.4)]),
		Color(0.9, 0.3, 0.3))
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(r * 0.5, 0), c + Vector2(r * 0.2, 0),
		c + Vector2(r * 0.2, r * 1.6), c + Vector2(r * 0.55, r * 1.4)]),
		Color(0.3, 0.5, 0.9))
	# メダル本体
	draw_circle(c, r + 3, Color(0, 0, 0, 0.3))
	draw_circle(c, r, col.darkened(0.15))
	draw_circle(c, r * 0.82, col)
	draw_circle(c, r * 0.82, Color(1, 1, 1, 0.0))
	draw_arc(c, r * 0.82, 0, TAU, 40, col.lightened(0.4), 3.0)
	draw_circle(c + Vector2(-r * 0.3, -r * 0.3), r * 0.25, Color(1, 1, 1, 0.4))
