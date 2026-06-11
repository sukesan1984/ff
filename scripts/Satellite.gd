class_name Satellite
extends Node2D
## 鳥の周りを周回するサテライト子機。コインを自動回収し、ノコギリを破壊する。

const COLLECT_R := 26.0
var ang := 0.0          # 周回角
var orbit := 54.0       # 周回半径
var cool := 0.0         # ノコ破壊後のクールダウン(この間は無効)
var _t := 0.0


func _ready() -> void:
	z_index = 11


func tick(delta: float, center: Vector2) -> void:
	_t += delta
	ang += delta * 3.2
	cool = maxf(0.0, cool - delta)
	var r := orbit + sin(_t * 2.0) * 5.0
	position = center + Vector2(cos(ang), sin(ang)) * r
	queue_redraw()


func ready_to_act() -> bool:
	return cool <= 0.0


func _draw() -> void:
	var on := cool <= 0.0
	var col := Color(0.5, 0.95, 1.0) if on else Color(0.5, 0.5, 0.6)
	# 回収範囲のうっすらリング
	if on:
		draw_circle(Vector2.ZERO, COLLECT_R, Color(0.5, 0.9, 1.0, 0.10))
	# 本体(小さなドローン)
	draw_circle(Vector2.ZERO, 9, Color(0, 0, 0, 0.3))
	draw_circle(Vector2.ZERO, 8, col.darkened(0.1))
	draw_circle(Vector2(-2, -2), 3.5, col.lightened(0.5))
	draw_arc(Vector2.ZERO, 11, _t * 6.0, _t * 6.0 + PI * 1.4, 16, Color(1, 1, 1, 0.7 if on else 0.3), 2.0)
