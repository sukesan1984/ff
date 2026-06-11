class_name Coin
extends Node2D
## 回転する金貨。連続取得でコンボ&フィーバーゲージが溜まる。

const RADIUS := 15.0
var collected := false
var spin := 0.0
var value := 2       # 取得時の基礎価値
var big := false     # でかいコイン(高価値だがリスキーな位置に出る)
var _t := 0.0


func _ready() -> void:
	z_index = 5


func radius() -> float:
	return 28.0 if big else RADIUS


func tick(delta: float) -> void:
	spin += delta * (4.5 if big else 6.0)
	_t += delta
	queue_redraw()


func _draw() -> void:
	var r := radius()
	# コインの回転(横幅をcosで伸縮)
	var sx := absf(cos(spin))
	sx = 0.25 + sx * 0.75
	var edge := Color(0.95, 0.62, 0.05) if big else Color(0.85, 0.6, 0.1)
	var face := Color(1.0, 0.88, 0.2) if big else Color(1.0, 0.84, 0.25)
	# でかコインは後光
	if big:
		var pulse := 1.0 + 0.1 * sin(_t * 4.0)
		draw_circle(Vector2.ZERO, (r + 10) * pulse, Color(1.0, 0.85, 0.2, 0.18))
	# 影
	draw_circle(Vector2(0, 2), r, Color(0, 0, 0, 0.2))
	# 側面の厚み
	_ellipse(Vector2(2.5, 0), r * sx, r, edge.darkened(0.2))
	# 表面
	_ellipse(Vector2.ZERO, r * sx, r, edge)
	_ellipse(Vector2.ZERO, r * sx * 0.78, r * 0.78, face)
	# 中央の星マーク(正面寄りのときだけ)
	if sx > 0.45:
		var a := (sx - 0.45) / 0.55
		_star(Vector2.ZERO, r * 0.5 * sx, r * 0.22, Color(1.0, 0.95, 0.6, a))
	# きらめき
	var tw := 0.5 + 0.5 * sin(_t * 5.0)
	draw_circle(Vector2(-r * 0.3 * sx, -r * 0.35), r * 0.13, Color(1, 1, 1, 0.8 * tw))


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
