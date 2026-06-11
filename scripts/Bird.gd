class_name Bird
extends Node2D
## 主役の鳥。物理・傾き・羽ばたきアニメ・トレイル・各種オーラ描画を担う。

const GRAVITY := 2100.0
const FLAP_IMPULSE := -560.0
const MAX_FALL := 820.0
const RADIUS := 17.0  # 当たり判定半径

var velocity := 0.0
var alive := true
var gravity_mult := 1.0   # ローグライク強化(低重力)用
var max_fall := MAX_FALL  # 落下速度上限(羽のように で下げる)
var angle := 0.0          # 表示用の傾き(rad)
var wing := 0.0           # 羽ばたき位相
var _flap_kick := 0.0     # 羽ばたき直後の強調
var base_color := Color(1.0, 0.82, 0.25)

# 状態(Gameが設定)
var fever := false
var shield := false
var magnet := false
var _t := 0.0

var _trail: Array = []    # 直近の位置履歴(global)


func _ready() -> void:
	z_index = 10


func flap() -> void:
	velocity = FLAP_IMPULSE
	_flap_kick = 1.0


func tick(delta: float) -> void:
	velocity += GRAVITY * gravity_mult * delta
	velocity = minf(velocity, max_fall)
	position.y += velocity * delta
	# 上昇で上向き、落下で下向きに傾ける
	var target := remap(clampf(velocity, FLAP_IMPULSE, MAX_FALL), FLAP_IMPULSE, MAX_FALL, deg_to_rad(-32), deg_to_rad(78))
	angle = lerp_angle(angle, target, clampf(delta * 9.0, 0.0, 1.0))


func anim(delta: float) -> void:
	_t += delta
	wing += delta * (10.0 + _flap_kick * 40.0)
	_flap_kick = maxf(0.0, _flap_kick - delta * 4.0)
	# トレイル更新
	_trail.push_front(global_position)
	if _trail.size() > 12:
		_trail.pop_back()
	queue_redraw()


func _rot(v: Vector2) -> Vector2:
	return v.rotated(angle)


func _draw() -> void:
	# --- トレイル(回転の影響を受けないようローカル基準で)---
	for i in range(_trail.size()):
		var p: Vector2 = to_local(_trail[i])
		var f := 1.0 - float(i) / float(_trail.size())
		var r := RADIUS * (0.85 * f)
		var col: Color
		if fever:
			col = Color.from_hsv(fposmod(_t * 0.8 + i * 0.06, 1.0), 0.85, 1.0, 0.5 * f)
		else:
			col = Color(1.0, 0.95, 0.7, 0.18 * f)
		if r > 0.5:
			draw_circle(p, r, col)

	# --- マグネットの磁力オーラ ---
	if magnet:
		var pulse := 1.0 + 0.12 * sin(_t * 8.0)
		draw_arc(Vector2.ZERO, 46 * pulse, 0, TAU, 32, Color(0.4, 0.9, 1.0, 0.5), 3.0)

	# --- フィーバー中の輝き(虹色グロー) ---
	if fever:
		var gp := 1.0 + 0.15 * sin(_t * 10.0)
		for k in 3:
			var gr := (RADIUS + 10.0 + k * 8.0) * gp
			draw_circle(Vector2.ZERO, gr, Color.from_hsv(fposmod(_t * 1.5 + k * 0.12, 1.0), 0.8, 1.0, 0.18 - k * 0.04))

	# --- 本体の色(フィーバーは虹) ---
	var body_col := base_color
	if fever:
		body_col = Color.from_hsv(fposmod(_t * 1.2, 1.0), 0.7, 1.0)

	# 影/縁取り
	draw_circle(Vector2.ZERO, RADIUS + 2.0, Color(0, 0, 0, 0.25))
	# 胴体
	draw_circle(Vector2.ZERO, RADIUS, body_col)
	# お腹(明るい部分)
	draw_circle(_rot(Vector2(2, 5)), RADIUS * 0.62, body_col.lightened(0.35))

	# 羽(羽ばたき)
	var flap_y := sin(wing) * 7.0
	var wing_center := _rot(Vector2(-3, -1 + flap_y * 0.4))
	_draw_ellipse(wing_center, 11, 7, angle - 0.3 + flap_y * 0.04, body_col.darkened(0.18))

	# くちばし
	var bk := _rot(Vector2(RADIUS - 1, 2))
	var b1 := bk + _rot(Vector2(14, -4))
	var b2 := bk + _rot(Vector2(14, 5))
	draw_colored_polygon(PackedVector2Array([bk, b1, b2]), Color(1.0, 0.55, 0.1))

	# 目(白目 + 黒目)
	var eye := _rot(Vector2(8, -6))
	draw_circle(eye, 6.5, Color.WHITE)
	draw_circle(eye + _rot(Vector2(2, 0)), 3.2, Color(0.1, 0.1, 0.12))
	draw_circle(eye + _rot(Vector2(0.6, -1.6)), 1.2, Color.WHITE)

	# --- シールドのリング ---
	if shield:
		var sp := 1.0 + 0.06 * sin(_t * 6.0)
		draw_arc(Vector2.ZERO, (RADIUS + 9) * sp, 0, TAU, 40, Color(0.5, 0.8, 1.0, 0.85), 3.5)
		draw_circle(Vector2.ZERO, (RADIUS + 9) * sp, Color(0.5, 0.8, 1.0, 0.12))


func _draw_ellipse(center: Vector2, rx: float, ry: float, rot: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot))
	draw_colored_polygon(pts, col)
