class_name Boss
extends Node2D
## ボス:画面上部に居座り、横一線のレーザーを「予告→発射」で撃ってくる。
## バンドの外に居れば回避。規定回数しのげば撃破。一本指で戦えるシューティング風。

var W := 540.0
var H := 960.0
var ground_y := 850.0
var attacks_left := 6
var phase := "intro"      # intro/warn/fire/cool/done
var phase_t := 0.0
var band_y := 400.0
var band_h := 100.0
var _t := 0.0


func _ready() -> void:
	z_index = 7


func tick(delta: float) -> void:
	_t += delta
	phase_t += delta
	match phase:
		"intro":
			if phase_t > 1.3:
				_next_warn()
		"warn":
			if phase_t > 1.0:
				phase = "fire"
				phase_t = 0.0
		"fire":
			if phase_t > 0.45:
				phase = "cool"
				phase_t = 0.0
				attacks_left -= 1
		"cool":
			if phase_t > 0.6:
				if attacks_left <= 0:
					phase = "done"
				else:
					_next_warn()
	queue_redraw()


func _next_warn() -> void:
	phase = "warn"
	phase_t = 0.0
	band_y = randf_range(170.0, ground_y - 120.0)
	band_h = randf_range(80.0, 120.0)


func lethal() -> bool:
	return phase == "fire"


func done() -> bool:
	return phase == "done"


func in_band(y: float) -> bool:
	return absf(y - band_y) < band_h * 0.5


func _draw() -> void:
	# レーザー予告/発射
	if phase == "warn":
		var bl := 0.4 + 0.4 * sin(phase_t * 22.0)
		draw_rect(Rect2(0, band_y - band_h * 0.5, W, band_h), Color(1, 0.25, 0.2, 0.18 + 0.18 * bl))
		draw_line(Vector2(0, band_y), Vector2(W, band_y), Color(1, 0.3, 0.3, 0.9), 2.0)
	elif phase == "fire":
		draw_rect(Rect2(0, band_y - band_h * 0.5, W, band_h), Color(1, 0.85, 0.4, 0.9))
		draw_rect(Rect2(0, band_y - band_h * 0.5, W, band_h), Color(1, 0.4, 0.1, 0.6))

	# ボス本体(上部に居座る巨大な目玉)
	var cx := W * 0.5
	var cy := 96.0 + sin(_t * 1.5) * 8.0
	draw_circle(Vector2(cx, cy), 70, Color(0.2, 0.06, 0.1))
	draw_circle(Vector2(cx, cy), 64, Color(0.45, 0.08, 0.12))
	# 目
	var look := clampf((band_y - cy) / 400.0, -0.4, 0.6) if phase != "intro" else 0.0
	draw_circle(Vector2(cx, cy), 36, Color(0.95, 0.95, 0.9))
	draw_circle(Vector2(cx, cy + look * 30.0), 18, Color(0.9, 0.2, 0.15) if phase == "fire" else Color(0.1, 0.1, 0.12))
	draw_circle(Vector2(cx - 6, cy + look * 30.0 - 6), 5, Color(1, 1, 1, 0.7))
	# 角
	draw_colored_polygon(PackedVector2Array([Vector2(cx - 60, cy - 40), Vector2(cx - 86, cy - 78), Vector2(cx - 40, cy - 56)]), Color(0.3, 0.05, 0.08))
	draw_colored_polygon(PackedVector2Array([Vector2(cx + 60, cy - 40), Vector2(cx + 86, cy - 78), Vector2(cx + 40, cy - 56)]), Color(0.3, 0.05, 0.08))
