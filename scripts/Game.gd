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
var help_box: Control
var _help_open := false
var over_box: Control
var over_score: Label
var over_best: Label
var over_medal: Label
var over_new: Label
var over_souls: Label

# メタ進行(魂の祭壇)
var souls := 0
var meta := {}                 # id -> 永続強化レベル
var meta_box: Control
var _meta_open := false
var meta_souls_label: Label
var meta_rows: Array = []      # [{def, lvl_label, buy_btn}]

const META_DEFS := [
	{"id": "m_coin", "name": "豊穣の祝福", "desc": "開始時コイン価値+1", "max": 3, "costs": [40, 100, 220]},
	{"id": "m_small", "name": "小柄の祝福", "desc": "開始時 当たり判定が小さい", "max": 2, "costs": [60, 160]},
	{"id": "m_shield", "name": "守護の祝福", "desc": "開始時シールド1枚", "max": 1, "costs": [90]},
	{"id": "m_luck", "name": "幸運の祝福", "desc": "レア/ユニークが出やすい", "max": 3, "costs": [80, 180, 360]},
	{"id": "m_soul", "name": "強欲な魂", "desc": "獲得ソウル+25%", "max": 3, "costs": [50, 130, 260]},
]

# ランキング(リーダーボード)
var name_box: Control
var name_display: Label   # 画面内キーボードで入力中の名前表示
var entry_text := ""
var rank_box: Control
var rank_list: VBoxContainer
var rank_title: Label
var title_rank: VBoxContainer
var _modal := false
var _player_name := ""
var _last_scores: Array = []

# ローグライク(レベルアップ強化。フィーバー終了で1枚選ぶ)
var ups := {}                  # id -> 取得数
var _leveling := false
var _pipes_since_level := 0
var _revive_count := 0         # このランで復活した回数
var _regen_count := 0          # シールド再生用の通過カウンタ
var _evo_gold := false
var _evo_phoenix := false
var _evo_dodge := false
var _evo_drone := false
var _evo_engine := false
var _evo_greed := false
# ユニーク効果フラグ
var _u_midas := false
var _u_hourglass := false
var _u_greed := false
var _u_glass := false
var _u_feverheart := false
var _u_cloak := false
var _u_aegis := false
var cur_radius := 17.0
var level_box: Control
var level_cards: Array = []    # 3枚のカードButton
var _offered: Array = []       # 今提示中の定義
var _level_lock := false       # 出現直後の誤タップ防止
var _selected_card := -1       # 2タップ確定式の選択中インデックス
var _offered_qty: Array = []   # 各カードの付与レベル数(レア度で変化)
var _offered_rar: Array = []   # 各カードのレア度(1-5)
var _fever_pending := false    # ゲージ満タン→カード選択後にフィーバー開始
var level_hint: Label

const UP_DEFS := [
	{"id": "small", "name": "ちいさくなる", "desc": "当たり判定が小さくなる", "short": "小", "max": 4, "rar": 1},
	{"id": "float", "name": "ふわり", "desc": "重力が軽くなる", "short": "浮", "max": 3, "rar": 1},
	{"id": "slow", "name": "スロー体質", "desc": "全体スピードが遅くなる", "short": "遅", "max": 3, "rar": 3},
	{"id": "coin", "name": "こばん大好き", "desc": "コインの価値 +1", "short": "金", "max": 5, "rar": 1},
	{"id": "feverdur", "name": "フィーバー長持ち", "desc": "フィーバーが1秒長く", "short": "熱", "max": 4, "rar": 2},
	{"id": "fevergain", "name": "フィーバー体質", "desc": "ゲージが溜まりやすい", "short": "充", "max": 3, "rar": 2},
	{"id": "combo", "name": "コンボ名人", "desc": "コンボ倍率がぐんぐん上がる", "short": "連", "max": 3, "rar": 2},
	{"id": "near", "name": "ニアミスの達人", "desc": "NICE判定が広がりボーナス増", "short": "際", "max": 3, "rar": 2},
	{"id": "magnet", "name": "マグネット体質", "desc": "常にコインを軽く引き寄せる", "short": "磁", "max": 3, "rar": 2},
	{"id": "luck", "name": "強運", "desc": "パワーアップが出やすい", "short": "運", "max": 3, "rar": 2},
	{"id": "biglover", "name": "大玉好き", "desc": "でかコインが増え価値も上がる", "short": "大", "max": 3, "rar": 2},
	{"id": "midas", "name": "ミダスタッチ", "desc": "フィーバー中コインさらに2倍", "short": "倍", "max": 1, "rar": 3},
	{"id": "nearfever", "name": "際どい快感", "desc": "ニアミスでゲージ大量", "short": "快", "max": 2, "rar": 3},
	{"id": "shieldregen", "name": "守りの心得", "desc": "今すぐ盾＋一定間隔で盾再生", "short": "盾", "max": 2, "rar": 3},
	{"id": "lucky7", "name": "ラッキーナンバー", "desc": "コンボ10ごとに大ボーナス", "short": "7", "max": 3, "rar": 2},
	{"id": "featherfall", "name": "羽のように", "desc": "落下が遅く操作しやすい", "short": "羽", "max": 3, "rar": 1},
	{"id": "satellite", "name": "サテライト子機", "desc": "周回する子機がコイン回収＆ノコギリ破壊", "short": "機", "max": 3, "rar": 4},
	{"id": "revive", "name": "不死鳥", "desc": "1度だけ復活できる", "short": "蘇", "max": 1, "rar": 4},
]

# レアリティ(1=コモン..4=エピック, 5=レジェンダリー/進化)
const RAR_NAMES := ["", "コモン", "アンコモン", "レア", "エピック", "レジェンダリー"]
const RAR_COLS := [
	Color(0.7, 0.7, 0.7), Color(0.75, 0.78, 0.82), Color(0.4, 0.85, 0.45),
	Color(0.4, 0.72, 1.0), Color(0.75, 0.45, 1.0), Color(1.0, 0.7, 0.2),
]
const RAR_BG := [
	Color(0.15, 0.15, 0.18, 0.95), Color(0.16, 0.17, 0.2, 0.95), Color(0.1, 0.22, 0.12, 0.95),
	Color(0.1, 0.18, 0.3, 0.95), Color(0.2, 0.12, 0.3, 0.95), Color(0.4, 0.2, 0.05, 0.95),
]

# 進化(シナジー)。前提を満たすと専用カードが出現する
const EVO_DEFS := [
	{"id": "evo_gold", "name": "★黄金旋風★", "desc": "コイン全自動回収＋価値1.5倍", "short": "旋", "req": {"coin": 5, "magnet": 3}},
	{"id": "evo_phoenix", "name": "★不死鳥転生★", "desc": "復活時にフィーバー＆復活回数+1", "short": "転", "req": {"revive": 1, "feverdur": 4}},
	{"id": "evo_dodge", "name": "★絶対回避★", "desc": "ノコギリ無効＋極小の当たり判定", "short": "避", "req": {"small": 4, "slow": 3}},
	{"id": "evo_drone", "name": "★ドローン軍団★", "desc": "子機+1・回収範囲特大・破壊し放題", "short": "軍", "req": {"satellite": 3}},
	{"id": "evo_engine", "name": "★永久機関★", "desc": "フィーバー超長持ち＆ゲージ獲得1.5倍", "short": "永", "req": {"fevergain": 3, "feverdur": 4}},
	{"id": "evo_greed", "name": "★金の亡者★", "desc": "コインがすべて巨大化(高額)", "short": "亡", "req": {"coin": 5, "biglover": 3}},
]

# ユニーク(固有)アイテム=稀ドロップの「やった！」枠(ディアブロのトレハン感)。各1回のみ
const UNIQUES := [
	{"id": "u_midas", "name": "ミダスの指輪", "short": "指", "desc": "コインの価値が常に2倍"},
	{"id": "u_hourglass", "name": "時の砂時計", "short": "砂", "desc": "世界が常に15%スロー"},
	{"id": "u_greed", "name": "強欲の王冠", "short": "冠", "desc": "コイン+80%／隙間-15(危険)"},
	{"id": "u_magnetking", "name": "磁王のコア", "short": "核", "desc": "全コインを自動回収"},
	{"id": "u_glass", "name": "ガラスの大砲", "short": "砲", "desc": "スコア2倍／隙間-20(危険)"},
	{"id": "u_feverheart", "name": "フィーバーの心臓", "short": "芯", "desc": "ゲージ倍速＆フィーバー超延長"},
	{"id": "u_cloak", "name": "羽毛の外套", "short": "套", "desc": "落下がとても遅くなる"},
	{"id": "u_aegis", "name": "イージスの盾", "short": "璧", "desc": "今すぐ盾＋高速で盾再生"},
	{"id": "u_swarm", "name": "サテライト群", "short": "群", "desc": "子機を一気に2機追加"},
	{"id": "u_phoenixheart", "name": "不死鳥の心臓", "short": "翼", "desc": "復活+1＆復活で即フィーバー"},
]

# 障害物
var pipes: Array[Pipe] = []
var coins: Array[Coin] = []
var powerups: Array[PowerUp] = []
var saws: Array[Saw] = []
var satellites: Array[Satellite] = []
var goblins: Array[Goblin] = []
var spawn_countdown := 200.0

# スコア類
var score := 0
var best := 0
var combo := 0
var coins_collected := 0
var pipes_passed := 0   # 難易度はスコアでなく通過パイプ数で決める(フィーバーで跳ねないように)
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
var _hitstop := 0.0
var flash_rect: ColorRect
var _ms_idx := 0
var _beat_best := false
const MILESTONES := [100, 250, 500, 1000, 2000, 4000, 7000, 10000, 15000, 20000]
var _boss: Boss
var _boss_active := false
var _next_boss_at := 40
var current_biome := -1
var tint_rect: ColorRect
var _biome_grav := 1.0
var _biome_spd := 1.0
var _biome_gap := 0.0
var _biome_saw := 1.0

const BIOME_LEN := 10
# grav=重力倍率, spd=速度倍率, gapadd=隙間補正, sawmul=ノコ出現倍率, hint=突入時の一言
const BIOMES := [
	{"name": "草原", "pb": Color(0.32, 0.78, 0.34), "pc": Color(0.24, 0.64, 0.27), "tint": Color(0, 0, 0, 0),
		"grav": 1.0, "spd": 1.0, "gapadd": 0.0, "sawmul": 1.0, "hint": ""},
	{"name": "夕焼けの丘", "pb": Color(0.88, 0.52, 0.3), "pc": Color(0.72, 0.4, 0.24), "tint": Color(1.0, 0.5, 0.15, 0.16),
		"grav": 1.0, "spd": 1.08, "gapadd": 8.0, "sawmul": 1.0, "hint": "風が少し速い"},
	{"name": "星空のかなた", "pb": Color(0.34, 0.42, 0.72), "pc": Color(0.24, 0.3, 0.56), "tint": Color(0.1, 0.12, 0.4, 0.26),
		"grav": 0.68, "spd": 0.95, "gapadd": 0.0, "sawmul": 1.0, "hint": "重力が軽い！"},
	{"name": "洞窟", "pb": Color(0.52, 0.46, 0.4), "pc": Color(0.4, 0.35, 0.3), "tint": Color(0.22, 0.13, 0.05, 0.34),
		"grav": 1.06, "spd": 0.95, "gapadd": -24.0, "sawmul": 1.7, "hint": "狭い！ノコギリ多発"},
	{"name": "天空都市", "pb": Color(0.92, 0.96, 1.0), "pc": Color(0.72, 0.82, 0.96), "tint": Color(0.7, 0.85, 1.0, 0.13),
		"grav": 1.0, "spd": 1.2, "gapadd": 14.0, "sawmul": 0.7, "hint": "超スピード！"},
]

# ===== PV(ニンテンドーダイレクト風デモ録画)用。FF_PV環境変数で有効化 =====
var _pv := false
var _pv_t := 0.0
var _pv_pipe_n := 0
var _pv_cap_idx := 0
var _pv_scene_idx := 0
var _pv_scene := "intro"
var _pv_dead_done := false
var _pv_revealed := false
var _pv_ended := false
var _pv_pending_pu := -1
var _pv_layer: CanvasLayer
var _pv_fade: ColorRect
var _pv_bar_top: ColorRect
var _pv_bar_bot: ColorRect
var _pv_title: Control

# [開始時刻, シーン名] — シーンごとにAIと生成の挙動を切り替える
const PV_SCENES := [
	[2.3, "basic"],
	[8.5, "combo"],
	[14.5, "shield"],
	[19.5, "slowmo"],
	[24.0, "magnet"],
	[28.0, "fever"],
	[35.5, "medal"],
	[38.5, "end"],
]

# [時刻, テキスト](下三分の一の日本語キャプション。ナレーションと連動)
const PV_CAPS := [
	[3.0, "ワンタップで土管をくぐれ！"],
	[9.0, "コインを集めてコンボ！スコア倍増"],
	[15.0, "シールド：一度だけ衝突を防ぐ"],
	[20.0, "スローモー：世界がゆっくりに"],
	[24.5, "マグネット：コインを引き寄せる"],
	[28.5, "フィーバー：無敵で土管を貫通！スコア2倍"],
	[36.0, "記録に応じてメダル獲得！"],
]


func _ready() -> void:
	randomize()
	load_best()
	_build()
	_reset(true)
	if OS.has_environment("FF_PV"):
		_pv_setup()
	elif OS.has_environment("FF_AUTO"):  # 開発用オートプレイ(観察/録画用。本番では未使用)
		_auto = true
		_reset(false)
	elif OS.has_environment("FF_META"):  # 開発用:祭壇プレビュー
		souls = 500
		_open_meta()
	else:
		_refresh_title_rank()


var _auto := false  # 開発用オートプレイフラグ


# ---------------------------------------------------------------- 構築
func _build() -> void:
	bg = Background.new()
	bg.W = W
	bg.H = H
	add_child(bg)

	world = Node2D.new()
	add_child(world)

	# バイオームの色味オーバーレイ(world より上・UIより下)
	var tint_layer := CanvasLayer.new()
	tint_layer.layer = 1
	add_child(tint_layer)
	tint_rect = ColorRect.new()
	tint_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	tint_rect.color = Color(0, 0, 0, 0)
	tint_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tint_layer.add_child(tint_rect)

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
	_build_leaderboard()
	_build_levelup()
	_build_help()
	_build_meta()

	# HUDは最後に追加して最前面に(メダルがパネルに隠れないように)
	hud = Hud.new()
	hud.W = W
	hud.H = H
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(hud)

	# 画面フラッシュ(フィーバー突入=白、被弾=赤)
	flash_rect = ColorRect.new()
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_rect.color = Color(1, 1, 1, 0)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(flash_rect)


func _enter_biome(idx: int) -> void:
	var first := current_biome == -1
	current_biome = idx
	var b = BIOMES[idx]
	_biome_grav = float(b["grav"])
	_biome_spd = float(b["spd"])
	_biome_gap = float(b["gapadd"])
	_biome_saw = float(b["sawmul"])
	_recompute_passives()  # 重力に反映
	if tint_rect:
		create_tween().tween_property(tint_rect, "color", b["tint"], 1.0)
	if not first:
		_floater("〜 %s 〜" % str(b["name"]), Vector2(W * 0.5, H * 0.30), Color(1, 1, 1), 42)
		if str(b["hint"]) != "":
			_floater(str(b["hint"]), Vector2(W * 0.5, H * 0.37), Color(1, 0.95, 0.6), 24)
		sfx.play("score", 1.3)


func _flash(col: Color, a: float) -> void:
	if not flash_rect:
		return
	flash_rect.color = Color(col.r, col.g, col.b, a)
	create_tween().tween_property(flash_rect, "color:a", 0.0, 0.35)


func _hit_stop(t: float) -> void:
	_hitstop = maxf(_hitstop, t)


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
	_mk_label(title_box, "FLAPPY", 210, 74, Color(1, 0.85, 0.25))
	_mk_label(title_box, "FEVER", 284, 86, Color(1, 0.45, 0.35))
	_mk_label(title_box, "コインを集めてゲージMAXでフィーバー！", 392, 21, Color(1, 1, 1, 0.92))
	_mk_label(title_box, "土管スレスレ通過でNICE！ボーナス", 420, 21, Color(1, 1, 1, 0.8))
	var tap := _mk_label(title_box, "タップ／スペースでスタート", 470, 28, Color.WHITE)
	_mk_label(title_box, "ベスト  " + str(best), 516, 24, Color(1, 1, 0.6))
	# ランキング(タイトル上のTOP表示)
	_mk_label(title_box, "★ ランキング ★", 580, 28, Color(1, 0.9, 0.4))
	title_rank = VBoxContainer.new()
	title_rank.position = Vector2(90, 624)
	title_rank.size = Vector2(W - 180, 220)
	title_rank.add_theme_constant_override("separation", 4)
	title_rank.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_box.add_child(title_rank)
	_mk_button(title_box, "魂の祭壇", Vector2(W * 0.5 - 188, 868), Vector2(180, 50), _open_meta)
	_mk_button(title_box, "あそびかた", Vector2(W * 0.5 + 8, 868), Vector2(180, 50), _open_help)
	# 点滅
	var tw := create_tween().set_loops()
	tw.tween_property(tap, "modulate:a", 0.25, 0.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(tap, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE)


func _build_help() -> void:
	help_box = Control.new()
	help_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	help_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(help_box)
	var p := ColorRect.new()
	p.color = Color(0.05, 0.07, 0.12, 0.96)
	p.position = Vector2(28, 96)
	p.size = Vector2(W - 56, 760)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	help_box.add_child(p)
	_mk_label(help_box, "あそびかた", 116, 40, Color(1, 0.9, 0.4))
	var body := Label.new()
	body.position = Vector2(52, 180)
	body.size = Vector2(W - 104, 600)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 21)
	body.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	body.add_theme_constant_override("line_spacing", 6)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.text = "【そうさ】タップ／スペースで羽ばたく\n【もくてき】土管のすき間をくぐってスコアを稼ぐ\n\n" + \
		"◆ コイン：集めてフィーバーゲージを溜める\n" + \
		"◆ コンボ：連続取得で倍率アップ\n" + \
		"◆ ニアミス：土管スレスレ通過でボーナス＆ゲージ大\n" + \
		"◆ フィーバー：ゲージMAXで無敵＆スコア2倍！\n　 突入の直前に強化カードを1枚選べる\n" + \
		"◆ レベルアップ：カードでビルドを構築(2回タップで決定)\n　 組み合わせ次第で…まれに強力な掘り出し物も？\n" + \
		"◆ お宝：危険な場所ほど高得点＆ゲージ大。リスク&リターン\n" + \
		"◆ ノコギリ：当たると一発。無敵や盾で防げる\n" + \
		"◆ バイオーム：進むと地帯が変化(重力・速度・すき間も)\n" + \
		"◆ メダル＆ランキング：スコアで世界と競え！"
	help_box.add_child(body)
	_mk_button(help_box, "とじる", Vector2(W * 0.5 - 80, 786), Vector2(160, 50), _close_help)
	help_box.visible = false


func _open_help() -> void:
	sfx.play("click")
	_help_open = true
	help_box.visible = true


func _close_help() -> void:
	sfx.play("click")
	_help_open = false
	help_box.visible = false


func _build_meta() -> void:
	meta_box = Control.new()
	meta_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	meta_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(meta_box)
	var p := ColorRect.new()
	p.color = Color(0.06, 0.05, 0.12, 0.97)
	p.position = Vector2(24, 80)
	p.size = Vector2(W - 48, 800)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meta_box.add_child(p)
	_mk_label(meta_box, "★ 魂の祭壇 ★", 100, 38, Color(0.7, 0.55, 1.0))
	_mk_label(meta_box, "死んでも遺るソウルで永続強化", 150, 19, Color(1, 1, 1, 0.8))
	meta_souls_label = _mk_label(meta_box, "", 182, 26, Color(0.8, 0.7, 1.0))
	for i in META_DEFS.size():
		var d = META_DEFS[i]
		var y := 232 + i * 112
		var info := Label.new()
		info.position = Vector2(48, y)
		info.size = Vector2(W - 200, 96)
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_theme_font_size_override("font_size", 21)
		info.add_theme_color_override("font_color", Color(1, 1, 1))
		info.mouse_filter = Control.MOUSE_FILTER_IGNORE
		meta_box.add_child(info)
		var btn := _mk_button(meta_box, "", Vector2(W - 152, y + 14), Vector2(120, 64), _buy_meta.bind(i))
		btn.add_theme_font_size_override("font_size", 20)
		meta_rows.append({"def": d, "info": info, "btn": btn})
	_mk_button(meta_box, "とじる", Vector2(W * 0.5 - 80, 812), Vector2(160, 50), _close_meta)
	meta_box.visible = false


func _refresh_meta() -> void:
	meta_souls_label.text = "ソウル: %d" % souls
	for row in meta_rows:
		var d = row["def"]
		var lv: int = int(meta.get(d["id"], 0))
		var mx: int = int(d["max"])
		row["info"].text = "%s  (Lv %d/%d)\n%s" % [str(d["name"]), lv, mx, str(d["desc"])]
		var btn: Button = row["btn"]
		if lv >= mx:
			btn.text = "MAX"
			btn.disabled = true
		else:
			var cost: int = int(d["costs"][lv])
			btn.text = "%d魂" % cost
			btn.disabled = souls < cost


func _buy_meta(i: int) -> void:
	var d = META_DEFS[i]
	var lv: int = int(meta.get(d["id"], 0))
	if lv >= int(d["max"]):
		return
	var cost: int = int(d["costs"][lv])
	if souls < cost:
		sfx.play("hit", 0.8)
		return
	souls -= cost
	meta[d["id"]] = lv + 1
	save_best()
	sfx.play("powerup")
	_refresh_meta()


func _open_meta() -> void:
	sfx.play("click")
	_meta_open = true
	_refresh_meta()
	meta_box.visible = true


func _close_meta() -> void:
	sfx.play("click")
	_meta_open = false
	meta_box.visible = false


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
	_mk_label(over_box, "ゲームオーバー", 326, 50, Color(1, 0.4, 0.35))
	over_medal = _mk_label(over_box, "", 466, 28, Color(1, 1, 1))
	over_score = _mk_label(over_box, "スコア 0", 502, 34, Color.WHITE)
	over_best = _mk_label(over_box, "ベスト 0", 542, 24, Color(1, 1, 0.6))
	over_souls = _mk_label(over_box, "", 574, 22, Color(0.8, 0.7, 1.0))
	over_new = _mk_label(over_box, "★ 自己ベスト更新！ ★", 604, 22, Color(0.4, 1, 0.5))
	over_new.visible = false
	_mk_button(over_box, "ランキングを見る", Vector2(W * 0.5 - 110, 640), Vector2(220, 48), _open_ranking)
	_mk_label(over_box, "タップでリトライ", 712, 26, Color.WHITE)
	over_box.visible = false


func _mk_button(parent: Node, text: String, pos: Vector2, sz: Vector2, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = sz
	b.add_theme_font_size_override("font_size", 24)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


# ---------------------------------------------------------------- ランキングUI
func _build_leaderboard() -> void:
	# 名前入力
	name_box = Control.new()
	name_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	name_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(name_box)
	var np := ColorRect.new()
	np.color = Color(0, 0, 0, 0.66)
	np.position = Vector2(30, 232)
	np.size = Vector2(W - 60, 520)
	np.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_box.add_child(np)
	_mk_label(name_box, "ランキング入り！", 250, 36, Color(1, 0.85, 0.3))
	_mk_label(name_box, "なまえを入れてね(タップ)", 298, 19, Color(1, 1, 1, 0.85))
	name_display = _mk_label(name_box, "", 332, 40, Color.WHITE)
	# 画面内キーボード(OSキーボードに依存しないので全環境で動く)
	var grid := GridContainer.new()
	grid.columns = 7
	grid.position = Vector2(48, 400)
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	name_box.add_child(grid)
	var chars := "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	for i in chars.length():
		var ch := chars[i]
		var b := Button.new()
		b.text = ch
		b.custom_minimum_size = Vector2(58, 50)
		b.add_theme_font_size_override("font_size", 22)
		b.pressed.connect(_name_add.bind(ch))
		grid.add_child(b)
	_mk_button(name_box, "←消す", Vector2(48, 612), Vector2(130, 52), _name_del)
	_mk_button(name_box, "スキップ", Vector2(W - 48 - 130, 612), Vector2(130, 52), _on_skip)
	_mk_button(name_box, "登録する", Vector2(W * 0.5 - 100, 680), Vector2(200, 58), _on_register)
	name_box.visible = false

	# ランキング一覧
	rank_box = Control.new()
	rank_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	rank_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(rank_box)
	var rp := ColorRect.new()
	rp.color = Color(0, 0, 0, 0.62)
	rp.position = Vector2(44, 210)
	rp.size = Vector2(W - 88, 560)
	rp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rank_box.add_child(rp)
	rank_title = _mk_label(rank_box, "★ ランキング ★", 232, 38, Color(1, 0.9, 0.4))
	rank_list = VBoxContainer.new()
	rank_list.position = Vector2(74, 300)
	rank_list.size = Vector2(W - 148, 380)
	rank_list.add_theme_constant_override("separation", 6)
	rank_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rank_box.add_child(rank_list)
	_mk_button(rank_box, "リトライ", Vector2(W * 0.5 - 90, 702), Vector2(180, 56), _on_rank_retry)
	rank_box.visible = false


func _name_add(ch: String) -> void:
	if entry_text.length() >= 10:
		return
	entry_text += ch
	_update_name_display()
	sfx.play("click", 1.4, -8.0)


func _name_del() -> void:
	if entry_text.is_empty():
		return
	entry_text = entry_text.substr(0, entry_text.length() - 1)
	_update_name_display()
	sfx.play("click", 0.9, -8.0)


func _update_name_display() -> void:
	name_display.text = entry_text if not entry_text.is_empty() else "［なまえ］"


# ---------------------------------------------------------------- レベルアップ
func _build_levelup() -> void:
	level_box = Control.new()
	level_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	level_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(level_box)
	var bg2 := ColorRect.new()
	bg2.color = Color(0, 0, 0, 0.5)
	bg2.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	level_box.add_child(bg2)
	_mk_label(level_box, "★ レベルアップ！ ★", 244, 46, Color(1, 0.9, 0.35))
	_mk_label(level_box, "1つ選ぶ", 304, 24, Color(1, 1, 1, 0.85))
	for i in 3:
		var card := Button.new()
		card.position = Vector2(45, 348 + i * 128)
		card.custom_minimum_size = Vector2(W - 90, 116)
		card.size = Vector2(W - 90, 116)
		card.pressed.connect(_on_card.bind(i))
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(16)
		sb.set_border_width_all(3)
		card.add_theme_stylebox_override("normal", sb)
		card.add_theme_stylebox_override("hover", sb)
		card.add_theme_stylebox_override("pressed", sb)
		card.add_theme_stylebox_override("focus", sb)
		level_box.add_child(card)
		var icon := Label.new()
		icon.position = Vector2(14, 24)
		icon.size = Vector2(68, 68)
		icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		icon.add_theme_font_size_override("font_size", 36)
		icon.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.5))
		icon.add_theme_constant_override("outline_size", 5)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(icon)
		var nm := Label.new()
		nm.position = Vector2(92, 16)
		nm.size = Vector2(W - 200, 40)
		nm.add_theme_font_size_override("font_size", 27)
		nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(nm)
		var ds := Label.new()
		ds.position = Vector2(92, 58)
		ds.size = Vector2(W - 200, 50)
		ds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ds.add_theme_font_size_override("font_size", 18)
		ds.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
		ds.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(ds)
		level_cards.append({"btn": card, "sb": sb, "icon": icon, "name": nm, "desc": ds})
	level_hint = _mk_label(level_box, "", 742, 22, Color(1, 1, 1, 0.85))
	level_box.visible = false


func _lv(id: String) -> int:
	return int(ups.get(id, 0))


func _recompute_passives() -> void:
	cur_radius = maxf(11.0, 17.0 - _lv("small") * 1.5)
	# ユニークフラグ
	_u_midas = _lv("u_midas") > 0
	_u_hourglass = _lv("u_hourglass") > 0
	_u_greed = _lv("u_greed") > 0
	_u_glass = _lv("u_glass") > 0
	_u_feverheart = _lv("u_feverheart") > 0
	_u_cloak = _lv("u_cloak") > 0
	_u_aegis = _lv("u_aegis") > 0
	_evo_gold = _lv("evo_gold") > 0 or _lv("u_magnetking") > 0
	_evo_phoenix = _lv("evo_phoenix") > 0 or _lv("u_phoenixheart") > 0
	_evo_dodge = _lv("evo_dodge") > 0
	_evo_drone = _lv("evo_drone") > 0
	_evo_engine = _lv("evo_engine") > 0
	_evo_greed = _lv("evo_greed") > 0
	if bird:
		bird.gravity_mult = (1.0 - _lv("float") * 0.07) * _biome_grav * (0.7 if _u_cloak else 1.0)
		bird.max_fall = Bird.MAX_FALL - _lv("featherfall") * 90.0 - (260.0 if _u_cloak else 0.0)
		# ビルドに応じた見た目(装備が姿に出る)
		bird.deco = {
			"small": _lv("small"),
			"crown": _lv("coin") + _lv("biglover") + (2 if _u_greed else 0),
			"helmet": _lv("shieldregen") > 0 or _u_aegis,
			"cape": _lv("featherfall") + (2 if _u_cloak else 0),
			"goggles": _lv("satellite") > 0,
			"phoenix": _lv("revive") > 0 or _evo_phoenix,
			"gold": _evo_gold or _u_midas,
		}


func _evo_ready(e: Dictionary) -> bool:
	for k in e["req"]:
		if _lv(k) < int(e["req"][k]):
			return false
	return true


func _roll_rarity() -> int:
	var r := randf()
	if r < 0.56:
		return 1  # コモン +1
	if r < 0.86:
		return 2  # アンコモン +2
	if r < 0.97:
		return 3  # レア +3
	return 4      # エピック MAX


func remain_to_max(d: Dictionary) -> int:
	return int(d["max"]) - _lv(str(d["id"]))


func _offer_levelup() -> bool:
	if _leveling or state != PLAY or _pv:
		return false
	# 進化(条件を満たし未取得)を最優先で出す
	var evos: Array = []
	for e in EVO_DEFS:
		if _lv(e["id"]) == 0 and _evo_ready(e):
			evos.append(e)
	# 未取得ユニーク
	var uniq_pool: Array = []
	for u in UNIQUES:
		if _lv(u["id"]) == 0:
			uniq_pool.append(u)
	uniq_pool.shuffle()
	# 通常強化(上限未満)
	var pool: Array = []
	for d in UP_DEFS:
		if _lv(d["id"]) < int(d["max"]):
			pool.append(d)
	pool.shuffle()
	_offered = []
	_offered_qty = []
	_offered_rar = []
	# 1) 進化(前提達成)を最優先で1枠
	if not evos.is_empty():
		evos.shuffle()
		_offered.append(evos[0])
		_offered_qty.append(1)
		_offered_rar.append(5)
	# 2) ユニークを確率でねじ込む(控えめ=トレハン感。「やった！」枠)
	if not uniq_pool.is_empty() and _offered.size() < 3 and randf() < 0.26 + int(meta.get("m_luck", 0)) * 0.07:
		_offered.append(uniq_pool[0])
		_offered_qty.append(1)
		_offered_rar.append(5)
	# 3) 残りは通常強化(アビリティ自体のレア度色で「型」を意識)
	for d in pool:
		if _offered.size() >= 3:
			break
		_offered.append(d)
		_offered_qty.append(1)
		_offered_rar.append(int(d["rar"]))
	if _offered.is_empty():
		return false
	for i in level_cards.size():
		var cd = level_cards[i]
		var btn: Button = cd["btn"]
		if i < _offered.size():
			var d = _offered[i]
			var is_evo: bool = d.has("req")
			var is_uniq: bool = not d.has("req") and not d.has("max")
			var rar: int = _offered_rar[i]
			var sb: StyleBoxFlat = cd["sb"]
			sb.bg_color = RAR_BG[rar]
			sb.border_color = RAR_COLS[rar]
			sb.set_border_width_all(6 if rar >= 5 else 3)
			cd["icon"].add_theme_color_override("font_color", RAR_COLS[rar])
			cd["name"].add_theme_color_override("font_color", RAR_COLS[rar].lightened(0.4))
			if is_uniq:
				cd["desc"].text = "【★UNIQUE★】%s" % str(d["desc"])
			elif is_evo:
				cd["desc"].text = "【進化】%s" % str(d["desc"])
			else:
				cd["desc"].text = "【%s】%s  Lv %d→%d" % [RAR_NAMES[rar], str(d["desc"]), _lv(d["id"]), _lv(d["id"]) + 1]
			cd["icon"].text = str(d["short"])
			cd["name"].text = str(d["name"])
			btn.visible = true
		else:
			btn.visible = false
	_leveling = true
	_pipes_since_level = 0
	_selected_card = -1
	if level_hint:
		level_hint.text = "カードをタップ"
	level_box.visible = true
	sfx.play("powerup", 1.2)
	# 出現直後は誤タップ防止でロック(暗→明で合図)
	_level_lock = true
	for cd in level_cards:
		var b: Button = cd["btn"]
		b.disabled = true
		b.modulate = Color(1, 1, 1, 0.35)
	var tw := create_tween()
	tw.tween_interval(0.38)
	tw.tween_callback(_unlock_cards)
	return true


func _unlock_cards() -> void:
	_level_lock = false
	for cd in level_cards:
		var b: Button = cd["btn"]
		if b.visible:
			b.disabled = false
		create_tween().tween_property(b, "modulate:a", 1.0, 0.15)


func _on_card(i: int) -> void:
	if _level_lock or not _leveling or i >= _offered.size():
		return
	if _selected_card != i:
		# 1タップ目:選択(誤爆防止。緑枠＋他カードを暗く)
		_selected_card = i
		sfx.play("click", 1.2)
		for j in level_cards.size():
			var b: Button = level_cards[j]["btn"]
			if j == i:
				b.modulate = Color(1, 1, 1, 1)
				level_cards[j]["sb"].border_color = Color(0.45, 1.0, 0.55)
			elif b.visible:
				b.modulate = Color(1, 1, 1, 0.4)
		if level_hint:
			level_hint.text = "▶ もう一度タップで決定！"
		return
	# 2タップ目:確定
	var d = _offered[i]
	var is_uniq: bool = not d.has("req") and not d.has("max")
	var is_special: bool = is_uniq or d.has("req")
	var times: int = _offered_qty[i] if i < _offered_qty.size() else 1
	for _k in times:
		if d.has("max") and _lv(str(d["id"])) >= int(d["max"]):
			break
		_apply_upgrade(str(d["id"]))
	_leveling = false
	_selected_card = -1
	level_box.visible = false
	if is_special:
		# ユニーク/進化は「やった！」演出
		sfx.play("fever")
		_hit_stop(0.12)
		_flash(Color(1, 0.85, 0.3), 0.5)
		shake = maxf(shake, 16.0)
		_burst(bird.position, Color(1, 0.85, 0.3), 36, 320.0, 0.8, 5.0)
		_floater("★ %s ★" % ("UNIQUE GET！" if is_uniq else "進化！"), Vector2(W * 0.5, H * 0.38), Color(1, 0.85, 0.3), 40)
		_floater(str(d["name"]), Vector2(W * 0.5, H * 0.45), Color(1, 0.95, 0.5), 30)
	else:
		sfx.play("powerup")
		_floater("%s!" % str(d["name"]), bird.position + Vector2(0, -60), Color(1, 0.9, 0.4), 32)
	# ゲージ満タン由来なら、選択後にフィーバー開始
	if _fever_pending:
		_fever_pending = false
		_start_fever()


func _apply_upgrade(id: String) -> void:
	ups[id] = _lv(id) + 1
	_recompute_passives()
	# 「守りの心得」は取得した瞬間に盾を1枚張る
	if id == "shieldregen":
		shield = true
		bird.shield = true
	# サテライト子機を1機追加
	if id == "satellite":
		_add_satellite()
	# ユニーク:イージスの盾=即シールド
	if id == "u_aegis":
		shield = true
		bird.shield = true
	# ユニーク:サテライト群=一気に2機
	if id == "u_swarm":
		_add_satellite()
		_add_satellite()
	# 進化:ドローン軍団=子機+1
	if id == "evo_drone":
		_add_satellite()


func _add_satellite() -> void:
	var s := Satellite.new()
	s.ang = TAU * satellites.size() / 3.0
	s.orbit = 54.0 + satellites.size() * 6.0
	s.position = bird.position
	world.add_child(s)
	satellites.append(s)


func _do_revive() -> void:
	_revive_count += 1
	bird.velocity = -420.0
	shield = true
	bird.shield = true
	invuln_t = 1.4
	sfx.play("fever")
	shake = maxf(shake, 12.0)
	_burst(bird.position, Color(1, 0.8, 0.3), 30, 300.0, 0.8, 5.0)
	_floater("ふっかつ！", bird.position + Vector2(0, -60), Color(1, 0.85, 0.3), 40)
	if _evo_phoenix and not fever_active:
		_start_fever()  # 不死鳥転生:復活と同時にフィーバー


# ---------------------------------------------------------------- 通信
func _api_base() -> String:
	# 同一オリジンの公開URL。eval を避けるため固定(CSPで unsafe-eval を許可しないため)。
	# 独自ドメインに変えた場合はここを更新。
	return "https://flappy-fever-54519886771.asia-northeast1.run.app"


func _fetch_scores(cb: Callable) -> void:
	var h := HTTPRequest.new()
	add_child(h)
	h.request_completed.connect(func(_r, code, _hd, body):
		var arr: Array = []
		if code == 200:
			var j = JSON.parse_string(body.get_string_from_utf8())
			if typeof(j) == TYPE_DICTIONARY and j.has("scores"):
				arr = j["scores"]
		_last_scores = arr
		h.queue_free()
		cb.call(arr))
	var err := h.request(_api_base() + "/api/scores")
	if err != OK:
		h.queue_free()
		cb.call([])


func _submit_score(pname: String, sc: int, cb: Callable) -> void:
	var h := HTTPRequest.new()
	add_child(h)
	h.request_completed.connect(func(_r, code, _hd, body):
		var arr: Array = []
		if code == 200:
			var j = JSON.parse_string(body.get_string_from_utf8())
			if typeof(j) == TYPE_DICTIONARY and j.has("scores"):
				arr = j["scores"]
		_last_scores = arr
		h.queue_free()
		cb.call(arr))
	var payload := JSON.stringify({"name": pname, "score": sc})
	var err := h.request(_api_base() + "/api/scores", ["Content-Type: application/json"], HTTPClient.METHOD_POST, payload)
	if err != OK:
		h.queue_free()
		cb.call([])


func _qualifies(sc: int, arr: Array) -> bool:
	if sc <= 0:
		return false
	if arr.size() < 10:
		return true
	var last = arr[arr.size() - 1]
	return sc > int(last.get("score", 0))


# ---------------------------------------------------------------- 表示
func _show_name_entry() -> void:
	_modal = true
	hud.show_medal = false
	over_box.visible = false
	rank_box.visible = false
	entry_text = ""
	_update_name_display()
	name_box.visible = true


func _on_register() -> void:
	if not name_box.visible:
		return
	_player_name = entry_text.strip_edges()
	save_best()
	sfx.play("click")
	name_box.visible = false
	_show_ranking_loading()
	_submit_score(_player_name, score, func(arr): _render_ranking(arr))


func _on_skip() -> void:
	sfx.play("click")
	name_box.visible = false
	_modal = false
	over_box.visible = true


func _open_ranking() -> void:
	sfx.play("click")
	_show_ranking_loading()
	_fetch_scores(func(arr): _render_ranking(arr))


func _on_rank_retry() -> void:
	sfx.play("click")
	_reset(false)


func _show_ranking_loading() -> void:
	_modal = true
	hud.show_medal = false
	over_box.visible = false
	name_box.visible = false
	for c in rank_list.get_children():
		c.queue_free()
	rank_box.visible = true
	var l := Label.new()
	l.text = "読み込み中…"
	l.add_theme_font_size_override("font_size", 24)
	l.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	rank_list.add_child(l)


func _render_ranking(arr: Array) -> void:
	for c in rank_list.get_children():
		c.queue_free()
	if arr.is_empty():
		var l := Label.new()
		l.text = "まだ記録がありません"
		l.add_theme_font_size_override("font_size", 22)
		l.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
		rank_list.add_child(l)
		return
	for i in arr.size():
		var e = arr[i]
		var nm := str(e.get("name", "ななし"))
		var sc := int(e.get("score", 0))
		var row := _rank_row(i + 1, nm, sc, 26)
		rank_list.add_child(row)


func _rank_row(rank: int, nm: String, sc: int, fs: int) -> Label:
	var l := Label.new()
	l.text = "%2d.  %-12s  %6d" % [rank, nm, sc]
	l.add_theme_font_size_override("font_size", fs)
	var col := Color(1, 1, 1, 0.92)
	if rank == 1:
		col = Color(1, 0.85, 0.25)
	elif rank == 2:
		col = Color(0.8, 0.85, 0.9)
	elif rank == 3:
		col = Color(0.9, 0.6, 0.35)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _refresh_title_rank() -> void:
	_fetch_scores(func(arr):
		if title_rank == null:
			return
		for c in title_rank.get_children():
			c.queue_free()
		if arr.is_empty():
			var l := Label.new()
			l.text = "まだ記録なし — 一番乗りをねらえ！"
			l.add_theme_font_size_override("font_size", 20)
			l.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			title_rank.add_child(l)
			return
		for i in mini(arr.size(), 5):
			var e = arr[i]
			title_rank.add_child(_rank_row(i + 1, str(e.get("name", "ななし")), int(e.get("score", 0)), 24)))


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
	pipes_passed = 0
	scroll_speed = BASE_SPEED
	fever_gauge = 0.0
	fever_active = false
	fever_time = 0.0
	shield = false
	slowmo_t = 0.0
	magnet_t = 0.0
	invuln_t = 0.0
	shake = 0.0
	_hitstop = 0.0
	_ms_idx = 0
	_beat_best = false
	if flash_rect:
		flash_rect.color = Color(1, 1, 1, 0)
	current_biome = -1
	_biome_grav = 1.0
	_biome_spd = 1.0
	_biome_gap = 0.0
	_biome_saw = 1.0
	if tint_rect:
		tint_rect.color = Color(0, 0, 0, 0)
	spawn_countdown = 200.0

	bird.velocity = 0.0
	bird.alive = true
	bird.angle = 0.0
	bird.position = Vector2(BIRD_X, 420)
	bird.fever = false
	bird.shield = false
	bird.magnet = false

	# ローグライク強化をリセット
	ups.clear()
	_leveling = false
	_fever_pending = false
	_pipes_since_level = 0
	_revive_count = 0
	_regen_count = 0
	_evo_gold = false
	_evo_phoenix = false
	for s in saws:
		s.queue_free()
	saws.clear()
	for s in satellites:
		s.queue_free()
	satellites.clear()
	for g in goblins:
		g.queue_free()
	goblins.clear()
	_boss_active = false
	if _boss:
		_boss.queue_free()
		_boss = null
	_next_boss_at = 3 if OS.has_environment("FF_BOSS") else 40
	if level_box:
		level_box.visible = false
	_recompute_passives()

	score_label.text = "0"
	score_label.visible = not to_title
	multi_label.visible = false
	hud.visible = not to_title
	hud.show_medal = false  # リスタート時に中央メダルを消す
	over_box.visible = false
	name_box.visible = false
	rank_box.visible = false
	_modal = false

	if to_title:
		state = TITLE
		title_box.visible = true
	else:
		# メタ進行(祭壇)の永続強化を開始時に反映
		if int(meta.get("m_coin", 0)) > 0:
			ups["coin"] = int(meta["m_coin"])
		if int(meta.get("m_small", 0)) > 0:
			ups["small"] = int(meta["m_small"])
		_recompute_passives()
		if int(meta.get("m_shield", 0)) > 0:
			shield = true
			bird.shield = true
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
			if _help_open or _meta_open:
				return  # ヘルプ/祭壇 表示中はタップで開始しない
			sfx.play("click")
			_reset(false)
		PLAY:
			if _leveling:
				return  # レベルアップ選択中は羽ばたかない
			bird.flap()
			sfx.play("flap", randf_range(0.92, 1.08))
			_feathers()
		DEAD:
			# 名前入力やランキング表示中はタップでリスタートしない
			if _modal:
				return
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
	if _pv:
		_pv_director(delta)
	_update_shake(delta)

	match state:
		TITLE:
			_update_title(delta)
		PLAY:
			_update_play(delta)
		DEAD:
			_update_dead(delta)

	if _auto:  # 開発用オートプレイ
		if _leveling:
			_on_card(0)  # 1タップ目:選択
			_on_card(0)  # 2タップ目:確定
		elif state == DEAD and dead_cd <= 0.0:
			_reset(false)

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
	if _leveling:
		return  # レベルアップ選択中は世界を止める
	if _hitstop > 0.0:
		_hitstop -= delta  # ヒットストップ(手応え演出で一瞬止める)
		return
	if _auto:  # 開発用オートAI(隙間中心を狙う)
		var tgt := 430.0
		var nx := 1.0e9
		for p in pipes:
			if p.position.x + p.width * 0.5 > bird.position.x and p.position.x < nx:
				nx = p.position.x
				tgt = p.center
		if bird.position.y > tgt and bird.velocity > -120.0:
			bird.flap()
	if _pv:
		_pv_ai()
	var speed_mult := (1.12 if fever_active else 1.0) * (0.5 if slowmo_t > 0.0 else 1.0)
	speed_mult *= 1.0 - _lv("slow") * 0.07  # スロー体質
	speed_mult *= _biome_spd  # バイオームのスピード個性
	if _u_hourglass:
		speed_mult *= 0.85  # 時の砂時計
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
	if bird.position.y > GROUND_Y - cur_radius:
		bird.position.y = GROUND_Y - cur_radius
		_on_hit(true)
		return

	# ボス処理(出現中はパイプを止めて回避アリーナに)
	if _boss_active:
		_boss.tick(delta)
		if _boss.lethal() and not (fever_active or invuln_t > 0.0) and _boss.in_band(bird.position.y):
			_on_hit(false)
			return
		if _boss.done():
			_defeat_boss()
	elif not _pv and pipes_passed >= _next_boss_at:
		_start_boss()

	# 生成(ボス中はパイプを出さない)
	if not _boss_active:
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
	for s in saws:
		s.position.x -= dx
		s.tick(pdelta)

	# サテライト子機:周回＋コイン回収＋ノコギリ破壊
	if not satellites.is_empty():
		_update_satellites(delta)
	# トレジャーゴブリン
	if not goblins.is_empty():
		_update_goblins(delta, dx)

	# マグネット(アイテム中は強力、マグネット体質は常時弱め)
	var mag_radius := 0.0
	var mag_speed := 0.0
	if magnet_t > 0.0:
		mag_radius = 230.0
		mag_speed = 620.0
	var passive := _lv("magnet") * 70.0
	if passive > mag_radius:
		mag_radius = passive
		mag_speed = maxf(mag_speed, 300.0)
	if _evo_gold:  # 黄金旋風:全コイン自動回収
		mag_radius = 9999.0
		mag_speed = maxf(mag_speed, 900.0)
	if mag_radius > 0.0:
		for c in coins:
			if c.position.distance_to(bird.position) < mag_radius:
				c.position = c.position.move_toward(bird.position, mag_speed * delta)

	_check_pipes()
	if state != PLAY:
		return  # 被弾でDEADに移行したらこのフレームの残処理を打ち切る
	_check_saws()
	if state != PLAY:
		return
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

	# 難易度(通過パイプ数で上昇。フィーバーのスコア倍増では跳ねない)
	scroll_speed = BASE_SPEED + minf(pipes_passed * 6.0, 170.0)

	# バイオーム(地帯)切替
	if not _pv:
		var biome := (pipes_passed / BIOME_LEN) % BIOMES.size()
		if biome != current_biome:
			_enter_biome(biome)

	# 節目突破コール
	var crossed := -1
	while _ms_idx < MILESTONES.size() and score >= MILESTONES[_ms_idx]:
		crossed = MILESTONES[_ms_idx]
		_ms_idx += 1
	if crossed > 0:
		_floater("%d点 突破！" % crossed, Vector2(W * 0.5, H * 0.5), Color(1, 0.9, 0.3), 42)
		_flash(Color(1, 1, 1), 0.2)
		sfx.play("score", 1.4)
	# プレイ中の自己ベスト更新を祝う
	if not _beat_best and best > 0 and score > best:
		_beat_best = true
		_floater("★ 自己ベスト更新！ ★", Vector2(W * 0.5, H * 0.44), Color(0.4, 1, 0.5), 36)
		_flash(Color(0.5, 1, 0.6), 0.3)
		sfx.play("fever")

	score_label.text = str(score)
	_update_combo_label()


# ---------------------------------------------------------------- 生成
func _spawn_pipe() -> void:
	var gap := clampf(235.0 - pipes_passed * 2.0, 165.0, 235.0)
	if fever_active:
		gap += 30.0  # フィーバー中は少し楽に
	if not _pv:
		gap += _biome_gap  # バイオームの隙間個性
		if _u_greed:
			gap -= 15.0  # 強欲の王冠(危険)
		if _u_glass:
			gap -= 20.0  # ガラスの大砲(危険)
	if _pv:
		gap = 235.0  # PVは見栄え優先で隙間を一定に
	gap = clampf(gap, 150.0, 320.0)
	# ノコギリ付きパイプ(進んでから登場)。隙間は広めにして公平に
	var has_saw := not _pv and pipes_passed >= 16 and randf() < (0.16 + minf(pipes_passed * 0.003, 0.16)) * _biome_saw
	if has_saw:
		gap += 80.0
	var margin := 90.0
	var lo := gap * 0.5 + margin
	var hi := GROUND_Y - gap * 0.5 - margin
	if _pv:
		# PVは中央寄りに出してAIの上下移動をなめらかに
		lo = maxf(lo, 330.0)
		hi = minf(hi, 600.0)
	var center := randf_range(lo, hi)
	if _pv and _pv_scene == "fever":
		center = 700.0  # 隙間を下に寄せ、無敵の鳥が上の土管を貫通する画に

	var p := Pipe.new()
	p.width = 88.0
	p.gap = gap
	p.base_center = center
	p.center = center
	p.screen_h = H
	p.ground_y = GROUND_Y
	p.position = Vector2(W + 70, 0)

	# 上下に揺れるパイプ(スコアが上がると登場。PVでは安定優先で無効)
	if not _pv and pipes_passed >= 14 and randf() < 0.33:
		p.moving = true
		var room := minf(center - lo, hi - center)
		p.osc_amp = minf(40.0 + score, 110.0)
		p.osc_amp = minf(p.osc_amp, room)
		p.osc_speed = randf_range(1.2, 2.0)
		p.phase = randf_range(0.0, TAU)

	# バイオームに合わせて土管色を変える(PVは時間帯ベース)
	if not _pv and current_biome >= 0:
		p.body_col = BIOMES[current_biome]["pb"]
		p.cap_col = BIOMES[current_biome]["pc"]
	elif _pv:
		var tint := bg.tod
		if tint > 0.5 and tint < 0.92:
			p.body_col = Color(0.30, 0.55, 0.62)
			p.cap_col = Color(0.22, 0.45, 0.52)

	world.add_child(p)
	pipes.append(p)

	# ミッドポイントにコイン or パワーアップ
	var mid_x := W + 70 + SPACING * 0.5
	if _pv:
		_pv_pipe_n += 1
		# 保留中のパワーアップを隙間中心に置く(AIが通過時に確実に取る)
		if _pv_pending_pu >= 0:
			var u := PowerUp.new()
			u.kind = _pv_pending_pu
			u.position = Vector2(W + 70, center)
			world.add_child(u)
			powerups.append(u)
			_pv_pending_pu = -1
		# シーンごとのコイン量
		match _pv_scene:
			"combo":
				_spawn_coins(mid_x, center, gap)
				_spawn_coins(mid_x + 95, center, gap)
			"magnet":
				_pv_spread_coins(mid_x, center)
			"fever":
				pass  # すり抜けを見せたいのでコインは出さない
			_:
				if randf() < 0.7:
					_spawn_coins(mid_x, center, gap)
		return
	# パワーアップ(強運で出やすく)
	if pipes_passed >= 3 and randf() < 0.14 + _lv("luck") * 0.05:
		_spawn_powerup(mid_x, center)
	elif randf() < 0.82:
		_spawn_coins(mid_x, center, gap)
	# でかコイン(隙間の端にハグして出現 → 取りに行くとリスク)
	if randf() < 0.11 + _lv("biglover") * 0.06:
		_spawn_big_coin(center, gap)
	# ノコギリ(隙間を上下にスイープ)
	if has_saw:
		_spawn_saw(center, gap)
	# お宝(あえて危険な位置に。高額＆ゲージ大でレベルアップを誘う)
	if pipes_passed >= 6 and randf() < 0.10 + _lv("biglover") * 0.04:
		_spawn_treasure(center, gap)
	# トレジャーゴブリン(稀。金袋を抱えて逃げる)
	if goblins.is_empty() and pipes_passed >= 10 and randf() < 0.05:
		_spawn_goblin()


func _spawn_coins(x: float, center: float, gap: float) -> void:
	var n := randi_range(3, 5)
	var pattern := randi() % 3  # 0=縦, 1=上アーチ, 2=下アーチ
	var cy := center + randf_range(-gap * 0.2, gap * 0.2)
	for i in n:
		var c := Coin.new()
		c.value = 2 + _lv("coin")
		if _evo_greed:  # 金の亡者:コインが全て巨大化
			c.big = true
			c.value = 12 + _lv("coin") * 2
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


func _spawn_big_coin(center: float, gap: float) -> void:
	# 隙間の上端 or 下端ギリギリに配置(土管に近く、取りに行くと当たるリスク)
	var c := Coin.new()
	c.big = true
	c.value = 18 + _lv("biglover") * 6 + _lv("coin")
	var r := c.radius()
	var top_edge := center - gap * 0.5 + r + 6.0
	var bot_edge := center + gap * 0.5 - r - 6.0
	var y := top_edge if randf() < 0.5 else bot_edge
	c.position = Vector2(W + 70, clampf(y, 90.0, GROUND_Y - 90.0))
	world.add_child(c)
	coins.append(c)


func _spawn_powerup(x: float, center: float) -> void:
	var u := PowerUp.new()
	u.kind = randi() % 3
	u.position = Vector2(x, clampf(center, 100.0, GROUND_Y - 100.0))
	world.add_child(u)
	powerups.append(u)


func _spawn_saw(center: float, gap: float) -> void:
	var s := Saw.new()
	s.lo = center - gap * 0.5 + Saw.RADIUS + 4.0
	s.hi = center + gap * 0.5 - Saw.RADIUS - 4.0
	s.phase = randf_range(0.0, TAU)
	s.speed = randf_range(1.6, 2.4)
	s.position = Vector2(W + 70, center)
	world.add_child(s)
	saws.append(s)


func _spawn_treasure(center: float, gap: float) -> void:
	# あえて危険な場所に出す:地面スレスレ / 天井スレスレ / 土管の角
	var c := Coin.new()
	c.treasure = true
	c.value = 35 + pipes_passed / 2 + _lv("biglover") * 12 + _lv("coin") * 2
	var spot := randi() % 3
	var y := center
	match spot:
		0:
			y = GROUND_Y - 58.0   # 地面ギリギリ(下に突っ込むリスク)
		1:
			y = 64.0              # 天井ギリギリ
		2:
			y = center - gap * 0.5 + c.radius() + 4.0  # 上の土管の角にハグ
	c.position = Vector2(W + 70, clampf(y, 56.0, GROUND_Y - 50.0))
	world.add_child(c)
	coins.append(c)


# ---------------------------------------------------------------- 当たり判定
func _check_pipes() -> void:
	var invincible := fever_active or invuln_t > 0.0
	for p in pipes:
		# スコア(通過)
		if not p.passed and bird.position.x > p.position.x:
			p.passed = true
			pipes_passed += 1
			_pipes_since_level += 1
			# シールド再生(守りの心得 / イージスの盾)
			_regen_count += 1
			var regen_on := _lv("shieldregen") > 0 or _u_aegis
			var regen_int := 8 if _u_aegis else 20 - _lv("shieldregen") * 4
			if regen_on and not shield and _regen_count >= regen_int:
				_regen_count = 0
				shield = true
				bird.shield = true
				_floater("盾 再生", bird.position + Vector2(0, -50), Color(0.6, 0.9, 1), 26)
			var pts := (2 if fever_active else 1) * (2 if _u_glass else 1)
			score += pts
			_add_fever(0.08)
			sfx.play("score", 1.0 + minf(score, 25) * 0.008)
			_floater("+%d" % pts, Vector2(p.position.x, p.gap_top() + p.gap * 0.5), Color.WHITE, 26)
			# ニアミス(達人で判定とボーナスUP)
			var near_win := 30.0 + _lv("near") * 8.0
			var near: float = min(absf(bird.position.y - p.gap_top()), absf(bird.position.y - p.gap_bottom()))
			if near < near_win and bird.alive:
				var nb := (2 + _lv("near")) * (2 if fever_active else 1) * (2 if _u_glass else 1)
				score += nb
				_add_fever(0.07 * (1.0 + _lv("nearfever")))  # 際どい快感
				shake = maxf(shake, 5.0)
				sfx.play("nice")
				_floater("ナイス！ +%d" % nb, bird.position + Vector2(0, -40), Color(0.5, 1, 0.6), 30)
			# フィーバーが長く出ないとき用の保険(15本でレベルアップ)
			if not fever_active and _pipes_since_level >= 15:
				_offer_levelup()
		# 衝突
		if not invincible:
			if _circle_rect(bird.position, cur_radius, p.top_rect()) or _circle_rect(bird.position, cur_radius, p.bottom_rect()):
				_on_hit(false)
				return


func _check_pickups() -> void:
	# 取得時に配列をeraseするため、複製を走査して取りこぼしを防ぐ
	for c in coins.duplicate():
		if c.collected:
			continue
		if bird.position.distance_to(c.position) < Bird.RADIUS + c.radius():
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


func _check_saws() -> void:
	if fever_active or invuln_t > 0.0 or _evo_dodge:
		return
	for s in saws:
		if s.active() and bird.position.distance_to(s.position) < cur_radius + Saw.RADIUS * 0.8:
			_on_hit(false)
			return


func _destroy_saw(s: Saw) -> void:
	saws.erase(s)
	_burst(s.position, Color(0.8, 0.85, 0.9), 18, 240.0, 0.5, 3.5)
	sfx.play("hit", 1.4)
	shake = maxf(shake, 6.0)
	s.queue_free()


func _update_goblins(delta: float, dx: float) -> void:
	for g in goblins.duplicate():
		g.position.x -= dx * 0.92  # 少しゆっくり=画面に長居して誘う
		g.tick(delta)
		# コインを撒いて誘う
		if g.drop_t <= 0.0:
			g.drop_t = 0.34
			var c := Coin.new()
			c.value = 2 + _lv("coin")
			c.position = g.position + Vector2(-6, 8)
			world.add_child(c)
			coins.append(c)
		# 捕獲(報酬は常に有効)
		if bird.position.distance_to(g.position) < cur_radius + Goblin.RADIUS:
			_catch_goblin(g)
		elif g.position.x < -70.0:
			goblins.erase(g)
			g.queue_free()


func _catch_goblin(g: Goblin) -> void:
	goblins.erase(g)
	var reward := (80 + pipes_passed + _lv("biglover") * 15) * (2 if _u_glass else 1)
	score += reward
	_add_fever(0.4)
	sfx.play("powerup")
	sfx.play("coin", 1.3)
	_hit_stop(0.08)
	_flash(Color(1, 0.85, 0.3), 0.4)
	shake = maxf(shake, 12.0)
	_burst(g.position, Color(1, 0.85, 0.3), 32, 300.0, 0.8, 4.5)
	_floater("ゴブリン捕獲！ +%d" % reward, g.position + Vector2(0, -52), Color(1, 0.85, 0.3), 34)
	g.queue_free()


func _start_boss() -> void:
	_boss_active = true
	_boss = Boss.new()
	_boss.W = W
	_boss.H = H
	_boss.ground_y = GROUND_Y
	_boss.attacks_left = 6
	world.add_child(_boss)
	sfx.play("fever")
	_flash(Color(0.7, 0.1, 0.1), 0.45)
	shake = maxf(shake, 16.0)
	_floater("ボス出現！", Vector2(W * 0.5, H * 0.4), Color(1, 0.4, 0.3), 46)
	_floater("レーザーを避けろ！", Vector2(W * 0.5, H * 0.47), Color(1, 1, 1), 24)


func _defeat_boss() -> void:
	_boss_active = false
	if _boss:
		_boss.queue_free()
		_boss = null
	_next_boss_at = pipes_passed + 45
	score += 200 + pipes_passed * 2
	_add_fever(0.5)
	sfx.play("fever")
	_hit_stop(0.12)
	_flash(Color(1, 0.9, 0.4), 0.5)
	shake = maxf(shake, 18.0)
	_burst(bird.position, Color(1, 0.85, 0.3), 40, 320.0, 0.9, 5.0)
	_floater("ボス撃破！", Vector2(W * 0.5, H * 0.4), Color(1, 0.9, 0.3), 46)
	_grant_random_unique()


func _grant_random_unique() -> void:
	var pool: Array = []
	for u in UNIQUES:
		if _lv(u["id"]) == 0:
			pool.append(u)
	if pool.is_empty():
		score += 300  # 全ユニーク所持済みなら大量スコア
		_floater("+300 (全ユニーク所持)", Vector2(W * 0.5, H * 0.48), Color(1, 0.9, 0.4), 30)
		return
	pool.shuffle()
	var u = pool[0]
	_apply_upgrade(str(u["id"]))
	_floater("★ UNIQUE GET！ ★", Vector2(W * 0.5, H * 0.48), Color(1, 0.85, 0.3), 36)
	_floater(str(u["name"]), Vector2(W * 0.5, H * 0.54), Color(1, 0.95, 0.5), 28)


func _spawn_goblin() -> void:
	var g := Goblin.new()
	g.base_y = randf_range(220.0, GROUND_Y - 220.0)
	g.position = Vector2(W + 60, g.base_y)
	g.drop_t = 0.3
	world.add_child(g)
	goblins.append(g)


func _update_satellites(delta: float) -> void:
	var cr := Satellite.COLLECT_R * (1.7 if _evo_drone else 1.0)  # ドローン軍団=回収範囲特大
	for s in satellites:
		s.tick(delta, bird.position)
		if not s.ready_to_act():
			continue
		for c in coins.duplicate():
			if not c.collected and s.position.distance_to(c.position) < cr + c.radius() * 0.5:
				_collect_coin(c)
		for sw in saws.duplicate():
			if sw.active() and s.position.distance_to(sw.position) < cr + Saw.RADIUS * 0.6:
				_destroy_saw(sw)
				s.cool = 0.0 if _evo_drone else 1.5  # 軍団は破壊し放題


# ---------------------------------------------------------------- 取得処理
func _collect_coin(c: Coin) -> void:
	c.collected = true
	combo += 1
	coins_collected += 1
	var mult := minf(1.0 + combo * (0.15 + _lv("combo") * 0.06), 8.0)
	var fmult := 2 if fever_active else 1
	var val := int(round(float(c.value) * mult)) * fmult
	if fever_active and _lv("midas") > 0:
		val *= 2  # ミダスタッチ(能力)
	if _u_midas:
		val *= 2  # ミダスの指輪(ユニーク)
	if _u_greed:
		val = int(round(val * 1.8))  # 強欲の王冠
	if _u_glass:
		val *= 2  # ガラスの大砲(スコア2倍)
	if _evo_gold:
		val = int(round(val * 1.5))  # 黄金旋風
	score += val
	# お宝ほどゲージが大きく溜まる(=危険を冒すほどレベルアップが近づく)
	var fgain := 0.05
	if c.treasure:
		fgain = 0.30
	elif c.big:
		fgain = 0.10
	_add_fever(fgain)
	var pitch := 0.7 if (c.big or c.treasure) else 1.0 + minf(combo, 14) * 0.04
	sfx.play("coin", pitch)
	if c.treasure:
		sfx.play("powerup", 1.0)
	var fs := 40 if c.treasure else (34 if c.big else 24)
	var heavy := c.big or c.treasure
	_burst(c.position, Color(1, 0.85, 0.3), 26 if c.treasure else (18 if c.big else 10), 240.0 if heavy else 160.0, 0.6, 4.5 if heavy else 3.0)
	_floater("+%d" % val, c.position, Color(1, 0.6, 0.2) if c.treasure else Color(1, 0.9, 0.4), fs, 70.0 if heavy else 50.0)
	if heavy:
		shake = maxf(shake, 10.0 if c.treasure else 8.0)
	if c.treasure:
		_hit_stop(0.07)
		_flash(Color(1, 0.85, 0.4), 0.3)
	# ラッキーナンバー:コンボ10ごとの大ボーナス
	if combo % 10 == 0:
		var lucky := _lv("lucky7")
		var bonus := 20 * lucky * fmult
		if bonus > 0:
			score += bonus
			_add_fever(0.05 * lucky)
		_floater("コンボ x%d！%s" % [combo, ("  +%d" % bonus) if bonus > 0 else ""], bird.position + Vector2(0, -70), Color(1, 0.6, 0.2), 36)
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
			_floater("シールド！", bird.position + Vector2(0, -60), Color(0.5, 0.8, 1), 34)
		PowerUp.SLOWMO:
			slowmo_t = 4.0
			_floater("スローモー！", bird.position + Vector2(0, -60), Color(0.8, 0.6, 1), 34)
		PowerUp.MAGNET:
			magnet_t = 6.0
			bird.magnet = true
			_floater("マグネット！", bird.position + Vector2(0, -60), Color(0.4, 0.95, 0.85), 34)
	powerups.erase(u)
	u.queue_free()


# ---------------------------------------------------------------- フィーバー
func _add_fever(a: float) -> void:
	if fever_active or _fever_pending:
		return
	var mult := 1.0 + _lv("fevergain") * 0.25  # フィーバー体質
	if _u_feverheart:
		mult *= 2.0  # フィーバーの心臓
	if _evo_engine:
		mult *= 1.5  # 永久機関
	fever_gauge += a * mult
	if fever_gauge >= 1.0:
		# ゲージ満タン:先にレベルアップを選ばせ、確定後にフィーバー(無敵)へ
		fever_gauge = 1.0
		_fever_pending = true
		var opened := _offer_levelup()
		if not opened and not _leveling:
			_fever_pending = false
			_start_fever()


func _fever_dur() -> float:
	return FEVER_DUR + _lv("feverdur") + (4.0 if _u_feverheart else 0.0) + (6.0 if _evo_engine else 0.0)


func _start_fever() -> void:
	fever_active = true
	fever_time = _fever_dur()
	fever_gauge = 1.0
	bird.fever = true
	sfx.play("fever")
	shake = maxf(shake, 16.0)
	_hit_stop(0.10)
	_flash(Color(1, 1, 1), 0.55)
	_burst(bird.position, Color(1, 0.7, 0.2), 40, 320.0, 0.8, 5.0)
	_floater("フィーバー！！", Vector2(W * 0.5, H * 0.42), Color(1, 0.85, 0.2), 44)


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
		_floater("ガード！", bird.position + Vector2(0, -50), Color(0.6, 0.9, 1), 32)
		return
	_die()


func _die() -> void:
	if state == DEAD:
		return
	# 不死鳥:復活(転生で回数+1。PV中は無効)
	var max_revives := (1 if _lv("revive") > 0 else 0) + (1 if _evo_phoenix else 0)
	if not _pv and _revive_count < max_revives:
		_do_revive()
		return
	state = DEAD
	bird.alive = false
	bird.velocity = -260.0
	combo = 0
	dead_cd = 0.6
	sfx.play("hit")
	sfx.play("die")
	shake = maxf(shake, 20.0)
	_hit_stop(0.12)
	_flash(Color(1, 0.2, 0.15), 0.5)
	_burst(bird.position, Color(1, 0.5, 0.2), 32, 300.0, 0.8, 4.5)
	_burst(bird.position, Color.WHITE, 16, 200.0, 0.6, 3.0)

	# ソウル獲得(メタ進行)
	var earned := int(floor(score / 20.0 * (1.0 + int(meta.get("m_soul", 0)) * 0.25)))
	souls += earned
	var new_best := false
	if score > best:
		best = score
		new_best = true
	save_best()

	multi_label.visible = false
	over_score.text = "スコア  %d" % score
	over_best.text = "ベスト  %d" % best
	over_new.visible = new_best
	over_souls.text = "魂 +%d  (所持 %d)" % [earned, souls]
	var m := _medal(score)
	over_medal.text = ["", "ブロンズメダル", "シルバーメダル", "ゴールドメダル", "プラチナメダル"][m]
	over_medal.add_theme_color_override("font_color", Hud.MEDAL_COLS[m])
	hud.medal = m
	hud.show_medal = m > 0
	over_box.visible = true

	# ランキング:トップ10入りなら名前入力へ(PV中は無効)
	if not _pv:
		var sc := score
		_fetch_scores(func(arr):
			if state == DEAD and not _modal and _qualifies(sc, arr):
				_show_name_entry())


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

	var alive_saws: Array[Saw] = []
	for s in saws:
		if s.position.x < -80.0:
			s.queue_free()
		else:
			alive_saws.append(s)
	saws = alive_saws


# ---------------------------------------------------------------- HUD更新
func _update_hud() -> void:
	hud.fever = fever_gauge
	hud.fever_active = fever_active
	hud.fever_time = fever_time
	hud.fever_max = _fever_dur()
	hud.shield = shield
	hud.slowmo_t = slowmo_t
	hud.magnet_t = magnet_t
	hud.build_list = _build_summary()


func _build_summary() -> Array:
	# 所持アビリティ一覧(HUD右側表示用)
	var out: Array = []
	for d in UP_DEFS:
		var lv := _lv(d["id"])
		if lv > 0:
			out.append({"short": d["short"], "lv": lv, "max": int(d["max"]), "evo": false})
	for e in EVO_DEFS:
		if _lv(e["id"]) > 0:
			out.append({"short": e["short"], "lv": 1, "max": 1, "evo": true})
	for u in UNIQUES:
		if _lv(u["id"]) > 0:
			out.append({"short": u["short"], "lv": 1, "max": 1, "evo": true})
	return out


func _update_combo_label() -> void:
	if fever_active:
		multi_label.text = "フィーバー  x2   (コンボ %d)" % combo
		multi_label.add_theme_color_override("font_color", Color(1, 0.6, 0.2))
		multi_label.visible = true
	elif combo > 1:
		var mult := minf(1.0 + combo * 0.15, 8.0)
		multi_label.text = "コンボ %d   x%.1f" % [combo, mult]
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
			if not f.eof_reached():
				_player_name = f.get_line().strip_edges()
			if not f.eof_reached():
				souls = int(f.get_line())
			if not f.eof_reached():
				var ms := f.get_line().strip_edges()
				for pair in ms.split(",", false):
					var kv := pair.split(":")
					if kv.size() == 2:
						meta[kv[0]] = int(kv[1])


func save_best() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_line(str(best))
		f.store_line(_player_name)
		f.store_line(str(souls))
		var parts: Array = []
		for k in meta:
			parts.append("%s:%d" % [k, int(meta[k])])
		f.store_line(",".join(parts))


# ================================================================ PV(Direct風デモ)
var _pv_wipe: PvWipe

func _pv_setup() -> void:
	_pv = true
	_pv_layer = CanvasLayer.new()
	_pv_layer.layer = 20
	add_child(_pv_layer)

	# シネスコの黒帯(最初は画面外)
	_pv_bar_top = ColorRect.new()
	_pv_bar_top.color = Color(0, 0, 0, 1)
	_pv_bar_top.position = Vector2(0, -90)
	_pv_bar_top.size = Vector2(W, 90)
	_pv_layer.add_child(_pv_bar_top)
	_pv_bar_bot = ColorRect.new()
	_pv_bar_bot.color = Color(0, 0, 0, 1)
	_pv_bar_bot.position = Vector2(0, H)
	_pv_bar_bot.size = Vector2(W, 90)
	_pv_layer.add_child(_pv_bar_bot)

	# 暗転オーバーレイ(最初は真っ黒からスタート)
	_pv_fade = ColorRect.new()
	_pv_fade.color = Color(0.03, 0.04, 0.08, 1)
	_pv_fade.position = Vector2.ZERO
	_pv_fade.size = Vector2(W, H)
	_pv_layer.add_child(_pv_fade)

	# 実況ワイプ(最初は画面右外)
	_pv_wipe = PvWipe.new()
	_pv_wipe.position = Vector2(W + 20, 700)
	_pv_wipe.visible = false
	_pv_layer.add_child(_pv_wipe)

	_reset(false)        # 自動プレイ開始(黒幕の裏で動かしておく)
	_pv_title_card()


func _pv_title_card() -> void:
	_pv_title = Control.new()
	_pv_title.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pv_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pv_layer.add_child(_pv_title)
	_mk_label(_pv_title, "FLAPPY", 320, 78, Color(1, 0.85, 0.25))
	_mk_label(_pv_title, "FEVER", 404, 96, Color(1, 0.45, 0.35))
	_mk_label(_pv_title, "いちばんアツいフラッピー、爆誕。", 552, 26, Color(1, 1, 1, 0.92))
	_pv_title.pivot_offset = Vector2(W * 0.5, H * 0.5)
	_pv_title.scale = Vector2(0.82, 0.82)
	create_tween().tween_property(_pv_title, "scale", Vector2.ONE, 0.7) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _pv_director(delta: float) -> void:
	_pv_t += delta
	# 字幕
	if _pv_cap_idx < PV_CAPS.size() and _pv_t >= float(PV_CAPS[_pv_cap_idx][0]):
		_pv_caption(str(PV_CAPS[_pv_cap_idx][1]))
		_pv_cap_idx += 1
	# シーン遷移
	if _pv_scene_idx < PV_SCENES.size() and _pv_t >= float(PV_SCENES[_pv_scene_idx][0]):
		_pv_enter_scene(str(PV_SCENES[_pv_scene_idx][1]))
		_pv_scene_idx += 1


func _pv_enter_scene(scene_name: String) -> void:
	_pv_scene = scene_name
	if _pv_wipe:
		_pv_wipe.hype = 0.2
	match scene_name:
		"basic":
			_pv_reveal()
		"shield":
			_pv_pending_pu = PowerUp.SHIELD
		"slowmo":
			_pv_pending_pu = PowerUp.SLOWMO
		"magnet":
			_pv_pending_pu = PowerUp.MAGNET
		"fever":
			if _pv_wipe:
				_pv_wipe.hype = 1.0
			if state == PLAY and not fever_active:
				_start_fever()
			fever_time = 8.5  # シーンの間ずっと無敵を維持
		"medal":
			if _pv_wipe:
				_pv_wipe.hype = 0.7
			if fever_active:
				_end_fever()
			if state == PLAY and not _pv_dead_done:
				_pv_dead_done = true
				_die()
		"end":
			_pv_end_card()


func _pv_reveal() -> void:
	var tw := create_tween()
	tw.tween_property(_pv_fade, "modulate:a", 0.0, 0.8)
	tw.parallel().tween_property(_pv_bar_top, "position:y", 0.0, 0.6) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_pv_bar_bot, "position:y", H - 90.0, 0.6) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_pv_title, "modulate:a", 0.0, 0.5)
	if _pv_wipe:
		_pv_wipe.visible = true
		tw.parallel().tween_property(_pv_wipe, "position:x", W - PvWipe.PW - 14.0, 0.6) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _pv_ai() -> void:
	# フィーバー中は上のラインを保ち、上の土管を貫通する画に
	if _pv_scene == "fever":
		if bird.position.y > 400.0 and bird.velocity > -120.0:
			bird.flap()
		return
	# 近いパイプの隙間中心を狙う
	var np: Pipe = null
	var nx := 1.0e9
	for p in pipes:
		if p.position.x + p.width * 0.5 > bird.position.x and p.position.x < nx:
			nx = p.position.x
			np = p
	var target := 430.0
	if np:
		target = np.center
	# シールド入手後はわざと上の土管へ突っ込み、ガードを見せる
	if _pv_scene == "shield" and shield and np:
		target = np.gap_top() - 35.0
	if bird.position.y > target and bird.velocity > -120.0:
		bird.flap()


func _pv_spread_coins(x: float, center: float) -> void:
	# マグネットの実演用に縦へ広くコインを撒く
	for i in 7:
		var c := Coin.new()
		var oy := (float(i) - 3.0) * 58.0
		c.position = Vector2(x + float(i % 2) * 40.0, clampf(center + oy, 130.0, GROUND_Y - 130.0))
		world.add_child(c)
		coins.append(c)


func _pv_caption(text: String) -> void:
	var y := 760.0
	var bar := ColorRect.new()
	bar.color = Color(0, 0, 0, 0.0)
	bar.position = Vector2(20, y - 6)
	bar.size = Vector2(W - 40, 84)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pv_layer.add_child(bar)

	var l := Label.new()
	l.text = text
	l.position = Vector2(20, y)
	l.size = Vector2(W - 40, 72)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 28)
	l.add_theme_color_override("font_color", Color(1, 1, 1))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 9)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.modulate.a = 0.0
	_pv_layer.add_child(l)

	var tw := create_tween()
	tw.tween_property(bar, "color:a", 0.45, 0.35)
	tw.parallel().tween_property(l, "modulate:a", 1.0, 0.35)
	tw.tween_interval(3.6)
	tw.tween_property(bar, "color:a", 0.0, 0.5)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.5)
	tw.tween_callback(bar.queue_free)
	tw.parallel().tween_callback(l.queue_free)


func _pv_end_card() -> void:
	if _pv_wipe:
		_pv_wipe.visible = false
	create_tween().tween_property(_pv_fade, "modulate:a", 0.94, 0.7)
	var card := Control.new()
	card.set_anchors_preset(Control.PRESET_FULL_RECT)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pv_layer.add_child(card)
	_mk_label(card, "FLAPPY", 290, 74, Color(1, 0.85, 0.25))
	_mk_label(card, "FEVER", 368, 94, Color(1, 0.45, 0.35))
	_mk_label(card, "やればやるほどクセになる。", 506, 27, Color(1, 1, 1, 0.95))
	_mk_label(card, "さあ、君は何点とれる？", 548, 27, Color(1, 0.9, 0.5))
	_mk_label(card, "Made with Godot 4", 600, 20, Color(1, 1, 1, 0.5))
	card.pivot_offset = Vector2(W * 0.5, H * 0.5)
	card.scale = Vector2(0.9, 0.9)
	card.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_interval(0.5)
	tw.tween_property(card, "modulate:a", 1.0, 0.7)
	tw.parallel().tween_property(card, "scale", Vector2.ONE, 0.8) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
