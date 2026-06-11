class_name Music
extends Node
## BGMマネージャ。通常/フィーバー/ボスの3ループをクロスフェードで切り替える。

const TRACKS := {
	"main": "res://sounds/bgm_main.wav",
	"fever": "res://sounds/bgm_fever.wav",
	"boss": "res://sounds/bgm_boss.wav",
}
const BASE_DB := -13.0

var _streams := {}
var _a: AudioStreamPlayer
var _b: AudioStreamPlayer
var _front_is_a := true
var current := ""


func _ready() -> void:
	for key in TRACKS:
		var path: String = TRACKS[key]
		if ResourceLoader.exists(path):
			var s = load(path)
			if s is AudioStreamWAV:
				# ランタイムでループ設定(16bitモノ: 2バイト=1フレーム)
				s.loop_mode = AudioStreamWAV.LOOP_FORWARD
				s.loop_begin = 0
				s.loop_end = s.data.size() / 2
			_streams[key] = s
	_a = AudioStreamPlayer.new()
	_b = AudioStreamPlayer.new()
	for p in [_a, _b]:
		p.bus = "Master"
		p.volume_db = -60.0
		add_child(p)


func play(name: String, fade := 0.7) -> void:
	if current == name or not _streams.has(name):
		return
	current = name
	var front := _a if _front_is_a else _b
	var back := _b if _front_is_a else _a
	_front_is_a = not _front_is_a
	back.stream = _streams[name]
	back.volume_db = -40.0
	back.play()
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(back, "volume_db", BASE_DB, fade)
	tw.tween_property(front, "volume_db", -45.0, fade)
	tw.chain().tween_callback(front.stop)
