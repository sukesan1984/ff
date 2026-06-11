class_name PvWipe
extends Node2D
## PV用の「ワイプ」。実況する鳥のナビゲーターを右下の小窓に表示する。

var _t := 0.0
var talking := true     # 喋っている間くちばしがパクパク
var hype := 0.0         # 盛り上がり 0..1(フィーバーで上げる)
var _blink := 0.0
var _blink_cd := 2.0
var _font := load("res://fonts/MochiyPopOne-Regular.ttf")

const PW := 188.0
const PH := 150.0


func _process(delta: float) -> void:
	_t += delta
	_blink_cd -= delta
	if _blink_cd <= 0.0:
		_blink = 0.16
		_blink_cd = 2.0 + fmod(_t, 1.7)
	_blink = maxf(0.0, _blink - delta)
	queue_redraw()


func _draw() -> void:
	# パネル(影 → 枠 → 中身)
	var bounce := -sin(_t * 6.0) * (2.0 + hype * 5.0)
	draw_rect(Rect2(6, 8, PW, PH), Color(0, 0, 0, 0.35))
	var border := Color(1.0, 0.85, 0.25).lerp(Color(1.0, 0.4, 0.35), hype)
	draw_rect(Rect2(0, 0, PW, PH), border)
	draw_rect(Rect2(5, 5, PW - 10, PH - 10), Color(0.16, 0.36, 0.55))
	# ヘッダー
	draw_rect(Rect2(5, 5, PW - 10, 30), border)
	if _font:
		draw_string(_font, Vector2(16, 28), "じっきょう中継", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(0.2, 0.15, 0.05))

	# 背景の放射(ハイプ時にキラッと)
	if hype > 0.05:
		for i in 10:
			var a := TAU * i / 10.0 + _t * 1.5
			var c := Vector2(PW * 0.5, PH * 0.6)
			draw_line(c, c + Vector2(cos(a), sin(a)) * 90.0, Color(1, 1, 0.5, 0.10 * hype), 6.0)

	# ナビ鳥(正面顔)
	var center := Vector2(PW * 0.5, PH * 0.62 + bounce)
	_draw_navi(center)


func _draw_navi(c: Vector2) -> void:
	var head_col := Color(1.0, 0.82, 0.25)
	# ヘッドホンのバンド
	draw_arc(c + Vector2(0, -2), 44, PI + 0.3, TAU - 0.3, 24, Color(0.2, 0.2, 0.24), 7.0)
	# 頭
	draw_circle(c, 40, Color(0, 0, 0, 0.2))
	draw_circle(c, 38, head_col)
	draw_circle(c + Vector2(0, 6), 30, head_col.lightened(0.25))
	# ヘッドホンの耳あて
	draw_circle(c + Vector2(-40, 0), 11, Color(0.18, 0.18, 0.22))
	draw_circle(c + Vector2(40, 0), 11, Color(0.18, 0.18, 0.22))

	# 目(ハイプ時は星目、通常は丸目+まばたき)
	var eye_l := c + Vector2(-14, -6)
	var eye_r := c + Vector2(14, -6)
	if hype > 0.5:
		_star(eye_l, 9, 4, Color(1, 0.9, 0.3))
		_star(eye_r, 9, 4, Color(1, 0.9, 0.3))
	else:
		var lid := _blink > 0.0
		for e in [eye_l, eye_r]:
			draw_circle(e, 8, Color.WHITE)
			if lid:
				draw_rect(Rect2(e.x - 8, e.y - 2, 16, 4), Color(0.1, 0.1, 0.12))
			else:
				draw_circle(e + Vector2(1, 1), 4, Color(0.1, 0.1, 0.12))
				draw_circle(e + Vector2(-0.5, -1.5), 1.5, Color.WHITE)

	# ほっぺ
	draw_circle(c + Vector2(-24, 8), 6, Color(1.0, 0.55, 0.45, 0.6))
	draw_circle(c + Vector2(24, 8), 6, Color(1.0, 0.55, 0.45, 0.6))

	# くちばし(喋るとパクパク開く)
	var open := 0.0
	if talking:
		open = (0.5 + 0.5 * sin(_t * 18.0)) * (5.0 + hype * 4.0)
	var beak := c + Vector2(0, 8)
	# 上ばし
	draw_colored_polygon(PackedVector2Array([
		beak + Vector2(-9, -open), beak + Vector2(9, -open), beak + Vector2(0, 2 - open)]),
		Color(1.0, 0.6, 0.1))
	# 下ばし(開いたとき口の中が見える)
	if open > 0.5:
		draw_colored_polygon(PackedVector2Array([
			beak + Vector2(-7, open * 0.4), beak + Vector2(7, open * 0.4), beak + Vector2(0, open)]),
			Color(0.8, 0.3, 0.2))


func _star(c: Vector2, outer: float, inner: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2 + TAU * i / 10.0
		var r := outer if i % 2 == 0 else inner
		pts.append(c + Vector2(cos(a) * r, sin(a) * r))
	draw_colored_polygon(pts, col)
