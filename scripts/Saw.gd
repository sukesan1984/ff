class_name Saw
extends Node2D
## 回転ノコギリ。隙間を上下に動く致命的ハザード(無敵/シールドで防げる)。

const RADIUS := 24.0
var lo := 200.0       # 可動域(上)
var hi := 600.0       # 可動域(下)
var phase := 0.0
var speed := 1.8
var spin := 0.0
var cur_y := 0.0
var warn := 0.6       # 出現直後の警告時間(この間は無害でチカチカ)


func _ready() -> void:
	z_index = 4


func tick(delta: float) -> void:
	if warn > 0.0:
		warn = maxf(0.0, warn - delta)
	phase += delta * speed
	spin += delta * 14.0
	var mid := (lo + hi) * 0.5
	var amp := (hi - lo) * 0.5
	cur_y = mid + sin(phase) * amp
	position.y = cur_y
	queue_redraw()


func active() -> bool:
	return warn <= 0.0


func _draw() -> void:
	var col := Color(0.75, 0.78, 0.82)
	var teeth := 12
	# 警告中は赤く点滅
	if warn > 0.0:
		var bl := 0.5 + 0.5 * sin(warn * 30.0)
		col = Color(1.0, 0.3, 0.3, 0.4 + 0.4 * bl)
	# ノコ刃(ギザギザ多角形)
	var pts := PackedVector2Array()
	for i in teeth * 2:
		var a := spin + TAU * i / float(teeth * 2)
		var r := RADIUS if i % 2 == 0 else RADIUS * 0.7
		pts.append(Vector2(cos(a) * r, sin(a) * r))
	draw_colored_polygon(pts, col)
	# 中心
	draw_circle(Vector2.ZERO, RADIUS * 0.4, col.darkened(0.3))
	draw_circle(Vector2.ZERO, RADIUS * 0.15, Color(0.2, 0.2, 0.25))
	if warn > 0.0:
		draw_arc(Vector2.ZERO, RADIUS + 4, 0, TAU, 24, Color(1, 0.3, 0.3, 0.8), 2.0)
