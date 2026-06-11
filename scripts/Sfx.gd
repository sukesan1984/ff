class_name Sfx
extends Node
## 効果音マネージャ。AudioStreamPlayerをプールして使い回す。

var _players: Array[AudioStreamPlayer] = []
var _idx := 0
var _streams := {}

const FILES := {
	"flap": "res://sounds/flap.wav",
	"score": "res://sounds/score.wav",
	"coin": "res://sounds/coin.wav",
	"nice": "res://sounds/nice.wav",
	"powerup": "res://sounds/powerup.wav",
	"shield": "res://sounds/shield.wav",
	"hit": "res://sounds/hit.wav",
	"die": "res://sounds/die.wav",
	"fever": "res://sounds/fever.wav",
	"click": "res://sounds/click.wav",
}


func _ready() -> void:
	for key in FILES:
		var path: String = FILES[key]
		if ResourceLoader.exists(path):
			_streams[key] = load(path)
	for i in 16:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)


func play(name: String, pitch := 1.0, volume_db := 0.0) -> void:
	if not _streams.has(name):
		return
	var p := _players[_idx]
	_idx = (_idx + 1) % _players.size()
	p.stream = _streams[name]
	p.pitch_scale = clampf(pitch, 0.1, 4.0)
	p.volume_db = volume_db
	p.play()
