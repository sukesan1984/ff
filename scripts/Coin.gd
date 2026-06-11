class_name Coin
extends Node2D
## 回転する金貨。連続取得でコンボ&フィーバーゲージが溜まる。

const RADIUS := 15.0
var collected := false
var spin := 0.0
var bob_base := 0.0
var _t := 0.0


func _ready() -> void:
	z_index = 5


func tick(delta: float) -> void:
	spin += delta * 6.0
	_t += delta
	queue_redraw()


func _draw() -> void:
	# コインの回転(横幅をcosで伸縮)
	var sx := absf(cos(spin))
	sx = 0.25 + sx * 0.75
	var edge := Color(0.85, 0.6, 0.1)
	var face := Color(1.0, 0.84, 0.25)
	# 影
	draw_circle(Vector2(0, 2), RADIUS, Color(0, 0, 0, 0.2))
	# 側面の厚み
	_ellipse(Vector2(2.5, 0), RADIUS * sx, RADIUS, edge.darkened(0.2))
	# 表面
	_ellipse(Vector2.ZERO, RADIUS * sx, RADIUS, edge)
	_ellipse(Vector2.ZERO, RADIUS * sx * 0.78, RADIUS * 0.78, face)
	# 中央の星マーク(正面寄りのときだけ)
	if sx > 0.45:
		var a := (sx - 0.45) / 0.55
		_star(Vector2.ZERO, RADIUS * 0.5 * sx, RADIUS * 0.22, Color(1.0, 0.95, 0.6, a))
	# きらめき
	var tw := 0.5 + 0.5 * sin(_t * 5.0)
	draw_circle(Vector2(-RADIUS * 0.3 * sx, -RADIUS * 0.35), 2.0, Color(1, 1, 1, 0.8 * tw))


func _ellipse(c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 20:
		var ang := TAU * i / 20.0
		pts.append(c + Vector2(cos(ang) * rx, sin(ang) * ry))
	draw_colored_polygon(pts, col)


func _star(c: Vector2, outer: float, inner: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var ang := -PI / 2 + TAU * i / 10.0
		var r := outer if i % 2 == 0 else inner
		pts.append(c + Vector2(cos(ang) * r, sin(ang) * r))
	draw_colored_polygon(pts, col)
