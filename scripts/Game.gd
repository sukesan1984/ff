extends Node2D
## Flappy Fever — メインコントローラ。
## 状態管理 / 生成 / 当たり判定 / スコア / フィーバー / パワーアップ / 演出 / 保存。

const W := 540.0
const H := 960.0
const GROUND_Y := 850.0
const BIRD_X := 160.0
const SPACING := 300.0          # パイプ間の横距離
const BASE_SPEED := 210.0
const SAVE_PATH := "user://flappyfever.save"

enum { TITLE, PLAY, DEAD }
var state := TITLE

# ノード
var bg: Background
var world: Node2D
var ground: Ground
var bird: Bird
var ui: CanvasLayer
var hud: Hud
var sfx: Sfx
var score_label: Label
var multi_label: Label
var title_box: Control
var over_box: Control
var over_score: Label
var over_best: Label
var over_medal: Label
var over_new: Label

# 障害物
var pipes: Array[Pipe] = []
var coins: Array[Coin] = []
var powerups: Array[PowerUp] = []
var spawn_countdown := 200.0

# スコア類
var score := 0
var best := 0
var combo := 0
var coins_collected := 0
var scroll_speed := BASE_SPEED

# フィーバー
var fever_gauge := 0.0
var fever_active := false
var fever_time := 0.0
const FEVER_DUR := 7.0

# パワーアップ状態
var shield := false
var slowmo_t := 0.0
var magnet_t := 0.0
var invuln_t := 0.0

# 演出
var shake := 0.0
var idle_t := 0.0
var dead_cd := 0.0


func _ready() -> void:
	randomize()
	load_best()
	_build()
	_reset(true)


# ---------------------------------------------------------------- 構築
func _build() -> void:
	bg = Background.new()
	bg.W = W
	bg.H = H
	add_child(bg)

	world = Node2D.new()
	add_child(world)

	ground = Ground.new()
	ground.W = W
	ground.H = H
	ground.top_y = GROUND_Y
	world.add_child(ground)

	bird = Bird.new()
	bird.position = Vector2(BIRD_X, 420)
	world.add_child(bird)

	sfx = Sfx.new()
	add_child(sfx)

	ui = CanvasLayer.new()
	ui.layer = 5
	add_child(ui)

	score_label = _mk_label(ui, "0", 36, 70, Color.WHITE)
	multi_label = _mk_label(ui, "", 108, 26, Color(1, 0.85, 0.3))
	multi_label.visible = false

	_build_title()
	_build_over()

	# HUDは最後に追加して最前面に(メダルがパネルに隠れないように)
	hud = Hud.new()
	hud.W = W
	hud.H = H
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(hud)


func _mk_label(parent: Node, txt: String, y: float, fs: int, col: Color) -> Label:
	var l := Label.new()
	l.text = txt
	l.position = Vector2(0, y)
	l.size = Vector2(W, fs + 24)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.65))
	l.add_theme_constant_override("outline_size", 8)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _build_title() -> void:
	title_box = Control.new()
	title_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(title_box)
	_mk_label(title_box, "FLAPPY", 250, 76, Color(1, 0.85, 0.25))
	_mk_label(title_box, "FEVER", 326, 88, Color(1, 0.45, 0.35))
	_mk_label(title_box, "Collect coins to fill the gauge -> FEVER!", 440, 20, Color(1, 1, 1, 0.92))
	_mk_label(title_box, "Skim the pipes for a NICE! bonus", 470, 20, Color(1, 1, 1, 0.8))
	var tap := _mk_label(title_box, "TAP / SPACE TO START", 600, 30, Color.WHITE)
	_mk_label(title_box, "BEST  " + str(best), 660, 26, Color(1, 1, 0.6))
	# 点滅
	var tw := create_tween().set_loops()
	tw.tween_property(tap, "modulate:a", 0.25, 0.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(tap, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE)


func _build_over() -> void:
	over_box = Control.new()
	over_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	over_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(over_box)
	# 半透明パネル
	var panel := ColorRect.new()
	panel.color = Color(0, 0, 0, 0.45)
	panel.position = Vector2(60, 300)
	panel.size = Vector2(W - 120, 360)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	over_box.add_child(panel)
	_mk_label(over_box, "GAME OVER", 330, 54, Color(1, 0.4, 0.35))
	over_medal = _mk_label(over_box, "", 470, 30, Color(1, 1, 1))
	over_score = _mk_label(over_box, "SCORE 0", 510, 34, Color.WHITE)
	over_best = _mk_label(over_box, "BEST 0", 552, 26, Color(1, 1, 0.6))
	over_new = _mk_label(over_box, "★ NEW BEST! ★", 590, 26, Color(0.4, 1, 0.5))
	over_new.visible = false
	_mk_label(over_box, "TAP TO RETRY", 700, 28, Color.WHITE)
	over_box.visible = false


# ---------------------------------------------------------------- リセット
func _reset(to_title: bool) -> void:
	for p in pipes:
		p.queue_free()
	for c in coins:
		c.queue_free()
	for u in powerups:
		u.queue_free()
	pipes.clear()
	coins.clear()
	powerups.clear()

	score = 0
	combo = 0
	coins_collected = 0
	scroll_speed = BASE_SPEED
	fever_gauge = 0.0
	fever_active = false
	fever_time = 0.0
	shield = false
	slowmo_t = 0.0
	magnet_t = 0.0
	invuln_t = 0.0
	shake = 0.0
	spawn_countdown = 200.0

	bird.velocity = 0.0
	bird.alive = true
	bird.angle = 0.0
	bird.position = Vector2(BIRD_X, 420)
	bird.fever = false
	bird.shield = false
	bird.magnet = false

	score_label.text = "0"
	score_label.visible = not to_title
	multi_label.visible = false
	hud.visible = not to_title
	over_box.visible = false

	if to_title:
		state = TITLE
		title_box.visible = true
	else:
		state = PLAY
		title_box.visible = false
		bird.flap()
		sfx.play("flap")


# ---------------------------------------------------------------- 入力
func _unhandled_input(event: InputEvent) -> void:
	if not _is_flap(event):
		return
	match state:
		TITLE:
			sfx.play("click")
			_reset(false)
		PLAY:
			bird.flap()
			sfx.play("flap", randf_range(0.92, 1.08))
			_feathers()
		DEAD:
			if dead_cd <= 0.0:
				sfx.play("click")
				_reset(false)


func _is_flap(event: InputEvent) -> bool:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		return true
	if event is InputEventScreenTouch and event.pressed:
		return true
	if event is InputEventKey and event.pressed and not event.echo:
		return event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_UP, KEY_W]
	return false


# ---------------------------------------------------------------- メインループ
func _process(delta: float) -> void:
	delta = minf(delta, 0.05)  # スパイク対策
	_update_shake(delta)

	match state:
		TITLE:
			_update_title(delta)
		PLAY:
			_update_play(delta)
		DEAD:
			_update_dead(delta)

	_update_hud()


func _update_shake(delta: float) -> void:
	shake = maxf(0.0, shake - delta * 40.0)
	if shake > 0.1:
		world.position = Vector2(randf_range(-shake, shake), randf_range(-shake, shake))
	else:
		world.position = Vector2.ZERO


func _update_title(delta: float) -> void:
	idle_t += delta
	bird.position = Vector2(BIRD_X, 430 + sin(idle_t * 2.2) * 16)
	bird.angle = sin(idle_t * 2.2) * 0.15
	bird.anim(delta)
	bg.tick(BASE_SPEED * 0.3 * delta, delta)
	ground.tick(BASE_SPEED * 0.3 * delta)


func _update_dead(delta: float) -> void:
	dead_cd = maxf(0.0, dead_cd - delta)
	# 鳥は落下して着地
	if bird.position.y < GROUND_Y - Bird.RADIUS:
		bird.tick(delta)
	else:
		bird.position.y = GROUND_Y - Bird.RADIUS
		bird.angle = lerp_angle(bird.angle, deg_to_rad(90), delta * 6.0)
	bird.anim(delta)


func _update_play(delta: float) -> void:
	var speed_mult := (1.12 if fever_active else 1.0) * (0.5 if slowmo_t > 0.0 else 1.0)
	var dx := scroll_speed * delta * speed_mult
	var pdelta := delta * speed_mult

	# 背景・地面
	bg.tick(dx, delta)
	ground.tick(dx)

	# 鳥
	bird.tick(pdelta)
	bird.anim(delta)

	# 天井
	if bird.position.y < Bird.RADIUS:
		bird.position.y = Bird.RADIUS
		bird.velocity = maxf(bird.velocity, 0.0)
	# 着地=死
	if bird.position.y > GROUND_Y - Bird.RADIUS:
		bird.position.y = GROUND_Y - Bird.RADIUS
		_on_hit(true)
		return

	# 生成
	spawn_countdown -= dx
	if spawn_countdown <= 0.0:
		spawn_countdown += SPACING
		_spawn_pipe()

	# 障害物の移動・更新
	for p in pipes:
		p.position.x -= dx
		p.phase += pdelta * p.osc_speed
		p.tick(pdelta)
	for c in coins:
		c.position.x -= dx
		c.tick(delta)
	for u in powerups:
		u.position.x -= dx
		u.tick(delta)

	# マグネット
	if magnet_t > 0.0:
		for c in coins:
			if c.position.distance_to(bird.position) < 230.0:
				c.position = c.position.move_toward(bird.position, 620.0 * delta)

	_check_pipes()
	if state != PLAY:
		return  # 被弾でDEADに移行したらこのフレームの残処理を打ち切る
	_check_pickups()
	_cleanup()

	# タイマー類(実時間)
	if slowmo_t > 0.0:
		slowmo_t -= delta
	if magnet_t > 0.0:
		magnet_t -= delta
		if magnet_t <= 0.0:
			bird.magnet = false
	if invuln_t > 0.0:
		invuln_t -= delta
	if fever_active:
		fever_time -= delta
		if fever_time <= 0.0:
			_end_fever()

	# 難易度
	scroll_speed = BASE_SPEED + minf(score * 3.0, 175.0)

	score_label.text = str(score)
	_update_combo_label()


# ---------------------------------------------------------------- 生成
func _spawn_pipe() -> void:
	var gap := clampf(240.0 - score * 2.2, 165.0, 240.0)
	if fever_active:
		gap += 30.0  # フィーバー中は少し楽に
	var margin := 90.0
	var lo := gap * 0.5 + margin
	var hi := GROUND_Y - gap * 0.5 - margin
	var center := randf_range(lo, hi)

	var p := Pipe.new()
	p.width = 88.0
	p.gap = gap
	p.base_center = center
	p.center = center
	p.screen_h = H
	p.ground_y = GROUND_Y
	p.position = Vector2(W + 70, 0)

	# 上下に揺れるパイプ(スコアが上がると登場)
	if score >= 12 and randf() < 0.33:
		p.moving = true
		var room := minf(center - lo, hi - center)
		p.osc_amp = minf(40.0 + score, 110.0)
		p.osc_amp = minf(p.osc_amp, room)
		p.osc_speed = randf_range(1.2, 2.0)
		p.phase = randf_range(0.0, TAU)

	# 時間帯に合わせてパイプ色を少し変化
	var tint := bg.tod
	if tint > 0.5 and tint < 0.92:
		p.body_col = Color(0.30, 0.55, 0.62)  # 夜は青緑
		p.cap_col = Color(0.22, 0.45, 0.52)

	world.add_child(p)
	pipes.append(p)

	# ミッドポイントにコイン or パワーアップ
	var mid_x := W + 70 + SPACING * 0.5
	if score >= 4 and randf() < 0.16:
		_spawn_powerup(mid_x, center)
	elif randf() < 0.82:
		_spawn_coins(mid_x, center, gap)


func _spawn_coins(x: float, center: float, gap: float) -> void:
	var n := randi_range(3, 5)
	var pattern := randi() % 3  # 0=縦, 1=上アーチ, 2=下アーチ
	var cy := center + randf_range(-gap * 0.2, gap * 0.2)
	for i in n:
		var c := Coin.new()
		var t := float(i) - (n - 1) * 0.5
		var ox := 0.0
		var oy := 0.0
		match pattern:
			0:
				oy = t * 40.0
			1:
				ox = t * 34.0
				oy = -abs(t) * 18.0 + 30.0
			2:
				ox = t * 34.0
				oy = abs(t) * 18.0 - 30.0
		c.position = Vector2(x + ox, clampf(cy + oy, 80.0, GROUND_Y - 80.0))
		world.add_child(c)
		coins.append(c)


func _spawn_powerup(x: float, center: float) -> void:
	var u := PowerUp.new()
	u.kind = randi() % 3
	u.position = Vector2(x, clampf(center, 100.0, GROUND_Y - 100.0))
	world.add_child(u)
	powerups.append(u)


# ---------------------------------------------------------------- 当たり判定
func _check_pipes() -> void:
	var invincible := fever_active or invuln_t > 0.0
	for p in pipes:
		# スコア(通過)
		if not p.passed and bird.position.x > p.position.x:
			p.passed = true
			var pts := 2 if fever_active else 1
			score += pts
			_add_fever(0.08)
			sfx.play("score", 1.0 + minf(score, 25) * 0.008)
			_floater("+%d" % pts, Vector2(p.position.x, p.gap_top() + p.gap * 0.5), Color.WHITE, 26)
			# ニアミス
			var near: float = min(absf(bird.position.y - p.gap_top()), absf(bird.position.y - p.gap_bottom()))
			if near < 30.0 and bird.alive:
				var nb := 4 if fever_active else 2
				score += nb
				_add_fever(0.07)
				shake = maxf(shake, 5.0)
				sfx.play("nice")
				_floater("NICE! +%d" % nb, bird.position + Vector2(0, -40), Color(0.5, 1, 0.6), 30)
		# 衝突
		if not invincible:
			if _circle_rect(bird.position, Bird.RADIUS, p.top_rect()) or _circle_rect(bird.position, Bird.RADIUS, p.bottom_rect()):
				_on_hit(false)
				return


func _check_pickups() -> void:
	# 取得時に配列をeraseするため、複製を走査して取りこぼしを防ぐ
	for c in coins.duplicate():
		if c.collected:
			continue
		if bird.position.distance_to(c.position) < Bird.RADIUS + Coin.RADIUS:
			_collect_coin(c)
	for u in powerups.duplicate():
		if u.collected:
			continue
		if bird.position.distance_to(u.position) < Bird.RADIUS + PowerUp.RADIUS:
			_collect_powerup(u)


func _circle_rect(c: Vector2, r: float, rect: Rect2) -> bool:
	var nx := clampf(c.x, rect.position.x, rect.position.x + rect.size.x)
	var ny := clampf(c.y, rect.position.y, rect.position.y + rect.size.y)
	return Vector2(nx, ny).distance_to(c) < r


# ---------------------------------------------------------------- 取得処理
func _collect_coin(c: Coin) -> void:
	c.collected = true
	combo += 1
	coins_collected += 1
	var mult := minf(1.0 + combo * 0.15, 8.0)
	var fmult := 2 if fever_active else 1
	var val := int(round(2.0 * mult)) * fmult
	score += val
	_add_fever(0.05)
	sfx.play("coin", 1.0 + minf(combo, 14) * 0.04)
	_burst(c.position, Color(1, 0.85, 0.3), 10, 160.0, 0.5, 3.0)
	_floater("+%d" % val, c.position, Color(1, 0.9, 0.4), 24, 50.0)
	if combo % 10 == 0:
		_floater("COMBO x%d!" % combo, bird.position + Vector2(0, -70), Color(1, 0.6, 0.2), 36)
		shake = maxf(shake, 6.0)
	coins.erase(c)
	c.queue_free()


func _collect_powerup(u: PowerUp) -> void:
	u.collected = true
	sfx.play("powerup")
	_burst(u.position, u.color(), 18, 220.0, 0.6, 4.0)
	shake = maxf(shake, 7.0)
	match u.kind:
		PowerUp.SHIELD:
			shield = true
			bird.shield = true
			_floater("SHIELD!", bird.position + Vector2(0, -60), Color(0.5, 0.8, 1), 34)
		PowerUp.SLOWMO:
			slowmo_t = 4.0
			_floater("SLOW-MO!", bird.position + Vector2(0, -60), Color(0.8, 0.6, 1), 34)
		PowerUp.MAGNET:
			magnet_t = 6.0
			bird.magnet = true
			_floater("MAGNET!", bird.position + Vector2(0, -60), Color(0.4, 0.95, 0.85), 34)
	powerups.erase(u)
	u.queue_free()


# ---------------------------------------------------------------- フィーバー
func _add_fever(a: float) -> void:
	if fever_active:
		return
	fever_gauge += a
	if fever_gauge >= 1.0:
		_start_fever()


func _start_fever() -> void:
	fever_active = true
	fever_time = FEVER_DUR
	fever_gauge = 1.0
	bird.fever = true
	sfx.play("fever")
	shake = maxf(shake, 14.0)
	_burst(bird.position, Color(1, 0.7, 0.2), 40, 320.0, 0.8, 5.0)
	_floater("FEVER TIME!", Vector2(W * 0.5, H * 0.42), Color(1, 0.85, 0.2), 44)


func _end_fever() -> void:
	fever_active = false
	bird.fever = false
	fever_gauge = 0.0


# ---------------------------------------------------------------- 被弾・死亡
func _on_hit(is_ground: bool) -> void:
	if fever_active:
		if is_ground:
			bird.velocity = -460.0
		return
	if invuln_t > 0.0:
		if is_ground:
			bird.velocity = -360.0
		return
	if shield and not is_ground:
		shield = false
		bird.shield = false
		invuln_t = 0.9
		bird.velocity = -380.0
		sfx.play("shield")
		shake = maxf(shake, 10.0)
		_burst(bird.position, Color(0.5, 0.8, 1.0), 22, 240.0, 0.6, 4.0)
		_floater("SAVED!", bird.position + Vector2(0, -50), Color(0.6, 0.9, 1), 32)
		return
	_die()


func _die() -> void:
	if state == DEAD:
		return
	state = DEAD
	bird.alive = false
	bird.velocity = -260.0
	combo = 0
	dead_cd = 0.6
	sfx.play("hit")
	sfx.play("die")
	shake = maxf(shake, 18.0)
	_burst(bird.position, Color(1, 0.5, 0.2), 32, 300.0, 0.8, 4.5)
	_burst(bird.position, Color.WHITE, 16, 200.0, 0.6, 3.0)

	var new_best := false
	if score > best:
		best = score
		new_best = true
		save_best()

	multi_label.visible = false
	over_score.text = "SCORE  %d" % score
	over_best.text = "BEST  %d" % best
	over_new.visible = new_best
	var m := _medal(score)
	over_medal.text = ["", "BRONZE", "SILVER", "GOLD", "PLATINUM"][m]
	over_medal.add_theme_color_override("font_color", Hud.MEDAL_COLS[m])
	hud.medal = m
	hud.show_medal = m > 0
	over_box.visible = true


func _medal(s: int) -> int:
	if s >= 40: return 4
	if s >= 25: return 3
	if s >= 12: return 2
	if s >= 5: return 1
	return 0


# ---------------------------------------------------------------- 後始末
func _cleanup() -> void:
	var alive_pipes: Array[Pipe] = []
	for p in pipes:
		if p.position.x < -130.0:
			p.queue_free()
		else:
			alive_pipes.append(p)
	pipes = alive_pipes

	var alive_coins: Array[Coin] = []
	for c in coins:
		if c.position.x < -60.0:
			c.queue_free()
		else:
			alive_coins.append(c)
	coins = alive_coins

	var alive_pu: Array[PowerUp] = []
	for u in powerups:
		if u.position.x < -60.0:
			u.queue_free()
		else:
			alive_pu.append(u)
	powerups = alive_pu


# ---------------------------------------------------------------- HUD更新
func _update_hud() -> void:
	hud.fever = fever_gauge
	hud.fever_active = fever_active
	hud.fever_time = fever_time
	hud.fever_max = FEVER_DUR
	hud.shield = shield
	hud.slowmo_t = slowmo_t
	hud.magnet_t = magnet_t


func _update_combo_label() -> void:
	if fever_active:
		multi_label.text = "FEVER  x2   (combo %d)" % combo
		multi_label.add_theme_color_override("font_color", Color(1, 0.6, 0.2))
		multi_label.visible = true
	elif combo > 1:
		var mult := minf(1.0 + combo * 0.15, 8.0)
		multi_label.text = "COMBO %d   x%.1f" % [combo, mult]
		multi_label.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
		multi_label.visible = true
	else:
		multi_label.visible = false


# ---------------------------------------------------------------- 演出ヘルパ
func _floater(txt: String, pos: Vector2, color: Color, fs := 30, rise := 70.0) -> void:
	var ft := FloatingText.new()
	ui.add_child(ft)
	ft.setup(txt, pos, color, fs, rise)


func _feathers() -> void:
	_burst(bird.position + Vector2(-8, 4), Color(1, 0.95, 0.8), 5, 90.0, 0.5, 2.2)


func _burst(pos: Vector2, color: Color, amount: int, speed: float, lifetime: float, sc: float) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = lifetime
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.gravity = Vector2(0, 480)
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.scale_amount_min = sc * 0.6
	p.scale_amount_max = sc
	p.color = color
	world.add_child(p)
	get_tree().create_timer(lifetime + 0.5).timeout.connect(p.queue_free)


# ---------------------------------------------------------------- 保存
func load_best() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if f:
			best = int(f.get_line())


func save_best() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_line(str(best))
