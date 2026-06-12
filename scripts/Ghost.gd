class_name Ghost
extends Node2D
## デイリー王者のゴースト。本日1位の飛行軌跡を半透明の鳥として並走させる。

const STEP_PX := 40.0  # 軌跡の記録間隔(スクロールpx)

var ys: PackedFloat32Array = []
var champ_name := ""
var champ_score := 0
var dist := 0.0
var _t := 0.0
var _font := load("res://fonts/MochiyPopOne-Regular.ttf")


func _ready() -> void:
	z_index = 9


func alive() -> bool:
	return not ys.is_empty() and dist / STEP_PX < float(ys.size() - 1)


func set_dist(d: float) -> void:
	dist = d
	if alive():
		var f := dist / STEP_PX
		var i := int(f)
		var frac := f - i
		position.y = lerpf(ys[i], ys[mini(i + 1, ys.size() - 1)], frac)
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta


func _draw() -> void:
	if not alive():
		return
	var a := 0.42 + 0.08 * sin(_t * 4.0)
	var col := Color(0.55, 0.85, 1.0, a)
	# 残像
	draw_circle(Vector2(-14, 2), 9.0, Color(0.55, 0.85, 1.0, a * 0.3))
	# 体
	draw_circle(Vector2.ZERO, 14.0, col)
	# 羽
	var fl := sin(_t * 11.0) * 5.0
	draw_circle(Vector2(-4, -2 + fl * 0.4), 7.0, Color(0.45, 0.75, 0.95, a))
	# 目
	draw_circle(Vector2(6, -4), 3.5, Color(1, 1, 1, a + 0.2))
	draw_circle(Vector2(7, -4), 1.8, Color(0.05, 0.1, 0.2, a + 0.3))
	# 王冠(王者の証)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-7, -16), Vector2(-7, -22), Vector2(-3.5, -18),
		Vector2(0, -23), Vector2(3.5, -18), Vector2(7, -22), Vector2(7, -16)]),
		Color(1.0, 0.85, 0.25, a + 0.15))
	# 名前
	if _font and champ_name != "":
		var label := champ_name
		var w: float = _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		draw_string_outline(_font, Vector2(-w * 0.5, -30), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 4, Color(0, 0, 0, 0.5))
		draw_string(_font, Vector2(-w * 0.5, -30), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.7, 0.92, 1.0, 0.85))
