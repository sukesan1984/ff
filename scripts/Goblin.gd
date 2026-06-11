class_name Goblin
extends Node2D
## トレジャーゴブリン(ディアブロ風)。金袋を抱え、コインを撒きながら逃げる。
## 捕まえれば大量報酬、逃すと消える。安全ルートを外れて追うか?のジレンマ。

const RADIUS := 20.0
var base_y := 300.0
var phase := 0.0
var drop_t := 0.0   # コインを撒く間隔タイマー(Gameが管理)
var _t := 0.0


func _ready() -> void:
	z_index = 6


func tick(delta: float) -> void:
	_t += delta
	phase += delta * 3.2
	drop_t -= delta
	position.y = base_y + sin(phase) * 72.0
	queue_redraw()


func _draw() -> void:
	var c := Color(0.42, 0.72, 0.36)
	var hop := absf(sin(_t * 8.0)) * 2.0
	# きらめき
	for i in 5:
		var a := _t * 3.0 + TAU * i / 5.0
		draw_circle(Vector2(cos(a), sin(a)) * (RADIUS + 8), 1.6, Color(1, 0.95, 0.5, 0.6))
	# 影
	draw_circle(Vector2(0, RADIUS - 2), RADIUS * 0.7, Color(0, 0, 0, 0.18))
	# 耳
	draw_colored_polygon(PackedVector2Array([Vector2(-RADIUS + 4, -8), Vector2(-RADIUS - 8, -18), Vector2(-RADIUS + 2, 2)]), c)
	draw_colored_polygon(PackedVector2Array([Vector2(RADIUS - 4, -8), Vector2(RADIUS + 8, -18), Vector2(RADIUS - 2, 2)]), c)
	# 体
	draw_circle(Vector2(0, -hop), RADIUS, c)
	draw_circle(Vector2(0, -hop), RADIUS, Color(0, 0, 0, 0.0))
	# 金袋(背負っている)
	draw_circle(Vector2(11, -10 - hop), 12, Color(0.85, 0.6, 0.1))
	draw_circle(Vector2(11, -10 - hop), 10, Color(1.0, 0.85, 0.25))
	draw_string(ThemeDB.fallback_font, Vector2(7, -6 - hop), "$", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.6, 0.4, 0.0))
	# 目
	draw_circle(Vector2(-5, -6 - hop), 4, Color.WHITE)
	draw_circle(Vector2(5, -6 - hop), 4, Color.WHITE)
	draw_circle(Vector2(-5, -6 - hop), 2, Color(0.1, 0.1, 0.1))
	draw_circle(Vector2(5, -6 - hop), 2, Color(0.1, 0.1, 0.1))
	# 口(ニヤリ)
	draw_arc(Vector2(0, 0 - hop), 7, 0.2, PI - 0.2, 10, Color(0.1, 0.1, 0.1), 2.0)
