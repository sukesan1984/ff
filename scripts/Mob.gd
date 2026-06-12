class_name Mob
extends Node2D
## クラフトモードのモブ。クリーパー(近づくと爆発)とコウモリ(乱舞する妨害)。

const CREEPER := 0
const BAT := 1
const RADIUS := 18.0

var kind := CREEPER
var base_y := 300.0
var phase := 0.0
var fuse := 99.0     # <50 で点火中(残り時間)。99=未点火
var dead := false
var _t := 0.0


func _ready() -> void:
	z_index = 6


func lit() -> bool:
	return fuse < 50.0


func tick(delta: float) -> void:
	_t += delta
	phase += delta * (6.0 if kind == BAT else 2.0)
	if fuse < 50.0:
		fuse -= delta
	if kind == BAT:
		position.y = base_y + sin(phase) * 60.0
	else:
		position.y = base_y + sin(phase) * 14.0
	queue_redraw()


func _draw() -> void:
	if kind == CREEPER:
		var is_lit := fuse < 50.0
		var body := Color(0.35, 0.75, 0.35)
		if is_lit:
			var bl := 0.5 + 0.5 * sin((1.0 - fuse) * 40.0)
			body = body.lerp(Color(1, 1, 1), bl * 0.7)
			draw_circle(Vector2.ZERO, RADIUS + 12, Color(1, 0.9, 0.5, 0.25))
		# 体(ドットっぽい四角)
		draw_rect(Rect2(-RADIUS, -RADIUS - 6, RADIUS * 2, RADIUS * 2 + 12), body)
		draw_rect(Rect2(-RADIUS, -RADIUS - 6, RADIUS * 2, RADIUS * 2 + 12), Color(0, 0, 0, 0.18), false, 2.0)
		# 顔
		draw_rect(Rect2(-12, -10, 8, 8), Color(0.05, 0.05, 0.05))
		draw_rect(Rect2(4, -10, 8, 8), Color(0.05, 0.05, 0.05))
		draw_rect(Rect2(-5, 0, 10, 6), Color(0.05, 0.05, 0.05))
		draw_rect(Rect2(-9, 6, 6, 8), Color(0.05, 0.05, 0.05))
		draw_rect(Rect2(3, 6, 6, 8), Color(0.05, 0.05, 0.05))
	else:
		# コウモリ
		var fl := sin(_t * 18.0) * 8.0
		var c := Color(0.3, 0.2, 0.32)
		draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(-22, -8 - fl), Vector2(-10, 6)]), c)
		draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(22, -8 - fl), Vector2(10, 6)]), c)
		draw_circle(Vector2.ZERO, 9, c)
		draw_circle(Vector2(-3, -2), 2.0, Color(1, 0.3, 0.3))
		draw_circle(Vector2(3, -2), 2.0, Color(1, 0.3, 0.3))
