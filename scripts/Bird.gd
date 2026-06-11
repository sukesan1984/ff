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
var deco := {}   # ビルドに応じた見た目(crown/helmet/cape/goggles/phoenix/gold/small)
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

	# --- ビルドに応じた進化見た目 ---
	var crown: int = int(deco.get("crown", 0))
	var phoenix: bool = deco.get("phoenix", false)
	var gold: bool = deco.get("gold", false)

	# 不死鳥の炎(本体の後ろ)
	if phoenix:
		for k in 5:
			var fa := _t * 4.0 + k * 1.25
			var fr := RADIUS + 6.0 + sin(_t * 8.0 + k) * 4.0
			draw_circle(Vector2(cos(fa), sin(fa)) * fr, 5.0, Color(1.0, 0.45 + 0.3 * sin(fa), 0.1, 0.5))

	# --- 本体の色(フィーバーは虹、金運で金色化) ---
	var body_col := base_color
	if crown > 0:
		body_col = body_col.lerp(Color(1.0, 0.84, 0.2), minf(crown * 0.18, 0.6))
	if gold:
		body_col = Color(1.0, 0.8, 0.15)
	if fever:
		body_col = Color.from_hsv(fposmod(_t * 1.2, 1.0), 0.7, 1.0)

	# 影/縁取り
	draw_circle(Vector2.ZERO, RADIUS + 2.0, Color(0, 0, 0, 0.25))
	# 胴体
	draw_circle(Vector2.ZERO, RADIUS, body_col)
	# お腹(明るい部分)
	draw_circle(_rot(Vector2(2, 5)), RADIUS * 0.62, body_col.lightened(0.35))

	# マント(羽のように)
	var cape: int = int(deco.get("cape", 0))
	if cape > 0:
		var cw := 10.0 + cape * 3.0
		var sway := sin(_t * 6.0 + wing) * 4.0
		var c0 := _rot(Vector2(-RADIUS + 2, -8))
		var c1 := _rot(Vector2(-RADIUS - cw, -2 + sway))
		var c2 := _rot(Vector2(-RADIUS - cw + 3, 12 + sway))
		var c3 := _rot(Vector2(-RADIUS + 2, 10))
		draw_colored_polygon(PackedVector2Array([c0, c1, c2, c3]), Color(0.85, 0.2, 0.3, 0.9))

	# 羽(羽ばたき)
	var flap_y := sin(wing) * 7.0
	var wing_center := _rot(Vector2(-3, -1 + flap_y * 0.4))
	_draw_ellipse(wing_center, 11, 7, angle - 0.3 + flap_y * 0.04, body_col.darkened(0.18))

	# くちばし
	var bk := _rot(Vector2(RADIUS - 1, 2))
	var b1 := bk + _rot(Vector2(14, -4))
	var b2 := bk + _rot(Vector2(14, 5))
	draw_colored_polygon(PackedVector2Array([bk, b1, b2]), Color(1.0, 0.55, 0.1))

	# 目(白目 + 黒目)。ゴーグル(子機)装備時はゴーグル
	var eye := _rot(Vector2(8, -6))
	if deco.get("goggles", false):
		draw_circle(eye, 7.0, Color(0.2, 0.9, 1.0))
		draw_circle(eye, 4.5, Color(0.05, 0.1, 0.15))
		draw_circle(eye + _rot(Vector2(-1.5, -1.5)), 1.6, Color(0.7, 1, 1, 0.9))
	else:
		draw_circle(eye, 6.5, Color.WHITE)
		draw_circle(eye + _rot(Vector2(2, 0)), 3.2, Color(0.1, 0.1, 0.12))
		draw_circle(eye + _rot(Vector2(0.6, -1.6)), 1.2, Color.WHITE)

	# 兜(守りの心得)
	if deco.get("helmet", false):
		var hc := _rot(Vector2(-1, -RADIUS + 2))
		_draw_ellipse(hc, RADIUS * 0.9, RADIUS * 0.55, angle, Color(0.6, 0.65, 0.72))
		draw_arc(_rot(Vector2(0, -2)), RADIUS + 1.0, angle + PI + 0.2, angle + TAU - 0.2, 20, Color(0.5, 0.55, 0.62), 3.0)

	# 王冠(金運)
	if crown > 0:
		var cy := -RADIUS - 4.0
		var cc := Color(1.0, 0.85, 0.2)
		var cp := PackedVector2Array([
			_rot(Vector2(-9, cy + 8)), _rot(Vector2(-9, cy)), _rot(Vector2(-4.5, cy + 5)),
			_rot(Vector2(0, cy - 3)), _rot(Vector2(4.5, cy + 5)), _rot(Vector2(9, cy)),
			_rot(Vector2(9, cy + 8))])
		draw_colored_polygon(cp, cc)

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
