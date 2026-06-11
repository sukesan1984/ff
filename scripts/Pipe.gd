class_name Pipe
extends Node2D
## 上下一対のパイプ。隙間(gap)を通り抜ける。スコア閾値で上下に揺れるタイプも出る。

var width := 88.0
var gap := 220.0
var base_center := 480.0
var center := 480.0
var screen_h := 960.0
var ground_y := 850.0
var passed := false
var scored_near := false

# 上下移動
var moving := false
var osc_amp := 0.0
var osc_speed := 1.6
var phase := 0.0

var body_col := Color(0.32, 0.78, 0.34)
var cap_col := Color(0.24, 0.64, 0.27)


func tick(_delta: float) -> void:
	if moving:
		center = base_center + sin(phase) * osc_amp
	else:
		center = base_center
	queue_redraw()


func gap_top() -> float:
	return center - gap * 0.5


func gap_bottom() -> float:
	return center + gap * 0.5


func top_rect() -> Rect2:
	# global座標(node.y=0前提)
	var left := position.x - width * 0.5
	return Rect2(left, -50.0, width, gap_top() + 50.0)


func bottom_rect() -> Rect2:
	var left := position.x - width * 0.5
	var top := gap_bottom()
	return Rect2(left, top, width, ground_y - top + 60.0)


func _draw() -> void:
	var half := width * 0.5
	var cap_h := 26.0
	var cap_over := 7.0
	# 上のパイプ
	_draw_pipe(Rect2(-half, -50, width, gap_top() + 50))
	_draw_cap(Rect2(-half - cap_over, gap_top() - cap_h, width + cap_over * 2, cap_h))
	# 下のパイプ
	var bh := ground_y - gap_bottom() + 60.0
	_draw_pipe(Rect2(-half, gap_bottom(), width, bh))
	_draw_cap(Rect2(-half - cap_over, gap_bottom(), width + cap_over * 2, cap_h))


func _draw_pipe(r: Rect2) -> void:
	# 縦に薄→濃のグラデ + 左にハイライト
	var left := body_col.lightened(0.18)
	var right := body_col.darkened(0.22)
	var pts := PackedVector2Array([
		r.position, Vector2(r.position.x + r.size.x, r.position.y),
		Vector2(r.position.x + r.size.x, r.position.y + r.size.y),
		Vector2(r.position.x, r.position.y + r.size.y),
	])
	var cols := PackedColorArray([left, right, right, left])
	draw_polygon(pts, cols)
	# 輪郭
	draw_rect(r, Color(0, 0, 0, 0.22), false, 2.0)
	# ハイライト帯
	draw_rect(Rect2(r.position.x + 6, r.position.y, 8, r.size.y), Color(1, 1, 1, 0.18))


func _draw_cap(r: Rect2) -> void:
	var left := cap_col.lightened(0.16)
	var right := cap_col.darkened(0.18)
	var pts := PackedVector2Array([
		r.position, Vector2(r.position.x + r.size.x, r.position.y),
		Vector2(r.position.x + r.size.x, r.position.y + r.size.y),
		Vector2(r.position.x, r.position.y + r.size.y),
	])
	var cols := PackedColorArray([left, right, right, left])
	draw_polygon(pts, cols)
	draw_rect(r, Color(0, 0, 0, 0.25), false, 2.0)
	draw_rect(Rect2(r.position.x + 6, r.position.y + 4, 8, r.size.y - 8), Color(1, 1, 1, 0.16))
