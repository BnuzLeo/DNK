extends Node

const LOBBY_ENTRY := "res://assets/music/dialogue/鸡你太美.wav"
const BUTTON_CLICK := "res://assets/music/音效/fx_btn1 #310034.wav"
const BERSERK_VOICE := "res://assets/music/dialogue/觉醒music.wav"
const BOSS_PHASE := "res://assets/music/音效/fx_boss15_angry.wav"
const BOSS_DEAD := "res://assets/music/音效/fx_boss15_dead.wav"
const BOX_DESTROY := "res://assets/music/音效/fx_box_destroy #310026.wav"
const COIN := "res://assets/music/音效/fx_coin #310024.wav"
const DOOR := "res://assets/music/音效/fx_door #310031.wav"
const ENERGY := "res://assets/music/音效/fx_energy #310029.wav"
const SWITCH := "res://assets/music/音效/fx_switch #310025.wav"
const DASH := "res://assets/music/音效/fx_sword2 #310027.wav"
const HIT := "res://assets/music/音效/fx_show_up #310028.wav"
const PLAYER_DEAD := "res://assets/music/dialogue/你干嘛.wav"

var _cache: Dictionary = {}
var _last_played_msec: Dictionary = {}


func play_lobby_entry() -> void:
	play_voice(LOBBY_ENTRY)


func play_button() -> void:
	play_sfx(BUTTON_CLICK, -5.0, 0.025)


func play_berserk() -> void:
	play_voice(BERSERK_VOICE)


func play_boss_phase() -> void:
	play_sfx(BOSS_PHASE, -2.0)


func play_boss_dead() -> void:
	play_sfx(BOSS_DEAD, -2.0)


func play_box_destroy() -> void:
	play_sfx(BOX_DESTROY, -3.0)


func play_coin() -> void:
	play_sfx(COIN, -3.0)


func play_door() -> void:
	play_sfx(DOOR, -4.0, 0.08)


func play_energy() -> void:
	play_sfx(ENERGY, -3.0)


func play_switch() -> void:
	play_sfx(SWITCH, -3.0, 0.04)


func play_dash() -> void:
	play_sfx(DASH, -4.0, 0.04)


func play_hit() -> void:
	play_sfx(HIT, -8.0, 0.025)


func play_player_dead() -> void:
	play_voice(PLAYER_DEAD)


func play_voice(path: String, volume_db: float = -2.0) -> void:
	_play(path, volume_db, 1.0, 0.0)


func play_sfx(path: String, volume_db: float = 0.0, throttle_seconds: float = 0.0) -> void:
	_play(path, volume_db, 1.0, throttle_seconds)


func _play(path: String, volume_db: float, pitch_scale: float, throttle_seconds: float) -> void:
	if throttle_seconds > 0.0:
		var now := Time.get_ticks_msec()
		var last := int(_last_played_msec.get(path, -1000000))
		if now - last < int(throttle_seconds * 1000.0):
			return
		_last_played_msec[path] = now

	var stream := _get_stream(path)
	if stream == null:
		return

	var player := AudioStreamPlayer.new()
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	player.bus = "Master"
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func _get_stream(path: String) -> AudioStream:
	if _cache.has(path):
		return _cache[path] as AudioStream
	var stream := load(path) as AudioStream
	if stream != null:
		_cache[path] = stream
	return stream
