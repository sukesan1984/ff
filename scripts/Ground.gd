class_name Ground
extends Node2D
## スクロールする地面。草の縞と土を描く。

var W := 540.0
var H := 960.0
var top_y := 850.0
var scroll := 0.0


func _ready() -> void:
	z_index = 8


func tick(dx: float) -> void:
	scroll += dx
	queue_redraw()


func _draw() -> void:
	var gh := H - top_y
	# 土
	draw_rect(Rect2(0, top_y, W, gh), Color(0.86, 0.71, 0.42))
	draw_rect(Rect2(0, top_y, W, gh), Color(0.78, 0.62, 0.36))
	# 草の帯
	draw_rect(Rect2(0, top_y, W, 22), Color(0.46, 0.80, 0.36))
	draw_rect(Rect2(0, top_y + 20, W, 4), Color(0.30, 0.62, 0.26))
	# スクロールする草の縞
	var stripe := 34.0
	var off := fposmod(scroll, stripe)
	var x := -off
	var i := int(scroll / stripe)
	while x < W:
		var c := Color(0.40, 0.74, 0.32) if (i % 2 == 0) else Color(0.50, 0.82, 0.38)
		draw_colored_polygon(PackedVector2Array([
			Vector2(x, top_y), Vector2(x + stripe * 0.5, top_y),
			Vector2(x + stripe * 0.5 - 5, top_y + 22), Vector2(x - 5, top_y + 22)]), c)
		x += stripe
		i += 1
	# 土のドット模様
	var dstripe := 48.0
	var doff := fposmod(scroll * 1.0, dstripe)
	var dx2 := -doff
	while dx2 < W:
		draw_circle(Vector2(dx2 + 12, top_y + 50), 3.0, Color(0.7, 0.55, 0.30, 0.6))
		draw_circle(Vector2(dx2 + 34, top_y + 78), 2.5, Color(0.7, 0.55, 0.30, 0.5))
		dx2 += dstripe
