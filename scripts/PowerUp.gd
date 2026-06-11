class_name PowerUp
extends Node2D
## パワーアップ玉。SHIELD / SLOWMO / MAGNET の3種。

const RADIUS := 20.0
const SHIELD := 0
const SLOWMO := 1
const MAGNET := 2

var kind := SHIELD
var collected := false
var _t := 0.0


func _ready() -> void:
	z_index = 6


func tick(delta: float) -> void:
	_t += delta
	queue_redraw()


func color() -> Color:
	match kind:
		SHIELD: return Color(0.45, 0.78, 1.0)
		SLOWMO: return Color(0.75, 0.55, 1.0)
		MAGNET: return Color(0.4, 0.95, 0.85)
	return Color.WHITE


func _draw() -> void:
	var c := color()
	var pulse := 1.0 + 0.08 * sin(_t * 5.0)
	# 後光
	draw_circle(Vector2.ZERO, (RADIUS + 8) * pulse, Color(c.r, c.g, c.b, 0.18))
	draw_arc(Vector2.ZERO, (RADIUS + 5) * pulse, 0, TAU, 32, Color(c.r, c.g, c.b, 0.6), 2.5)
	# 玉本体
	draw_circle(Vector2.ZERO, RADIUS, Color(0, 0, 0, 0.2))
	draw_circle(Vector2.ZERO, RADIUS - 1, c.darkened(0.1))
	draw_circle(Vector2(-5, -5), RADIUS * 0.55, c.lightened(0.4))
	# アイコン
	match kind:
		SHIELD: _icon_shield()
		SLOWMO: _icon_clock()
		MAGNET: _icon_magnet()


func _icon_shield() -> void:
	var w := Color(1, 1, 1, 0.95)
	var pts := PackedVector2Array([
		Vector2(0, -10), Vector2(9, -5), Vector2(9, 3),
		Vector2(0, 11), Vector2(-9, 3), Vector2(-9, -5),
	])
	draw_colored_polygon(pts, w)
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -6), Vector2(5, -3), Vector2(5, 2),
		Vector2(0, 7), Vector2(-5, 2), Vector2(-5, -3),
	]), color().darkened(0.1))


func _icon_clock() -> void:
	var w := Color(1, 1, 1, 0.95)
	draw_arc(Vector2.ZERO, 10, 0, TAU, 24, w, 2.5)
	draw_line(Vector2.ZERO, Vector2(0, -7), w, 2.0)
	draw_line(Vector2.ZERO, Vector2(5, 1), w, 2.0)


func _icon_magnet() -> void:
	var w := Color(1, 1, 1, 0.95)
	# U字マグネット
	draw_arc(Vector2(0, -1), 8, PI, TAU, 16, w, 4.0)
	draw_line(Vector2(-8, -1), Vector2(-8, 8), w, 4.0)
	draw_line(Vector2(8, -1), Vector2(8, 8), w, 4.0)
	draw_line(Vector2(-8, 8), Vector2(-8, 11), Color(1, 0.3, 0.3), 4.0)
	draw_line(Vector2(8, 8), Vector2(8, 11), Color(0.3, 0.5, 1), 4.0)
