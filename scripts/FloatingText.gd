class_name FloatingText
extends Label
## スコアやコンボの「+1」「NICE!」をふわっと浮かせて消すラベル。

func setup(txt: String, pos: Vector2, color: Color, font_size := 34, rise := 70.0) -> void:
	text = txt
	add_theme_font_size_override("font_size", font_size)
	add_theme_color_override("font_color", color)
	add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	add_theme_constant_override("outline_size", 6)
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var box := Vector2(240, 56)
	custom_minimum_size = box
	size = box
	position = pos - box * 0.5
	pivot_offset = box * 0.5
	z_index = 100

	scale = Vector2(0.4, 0.4)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "position:y", position.y - rise, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(self, "modulate:a", 0.0, 0.35)
	tw.chain().tween_callback(queue_free)
