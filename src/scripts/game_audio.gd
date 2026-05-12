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
const SHOOT := "res://assets/music/音效/fx_show_up #310028.wav"
const PLAYER_DEAD := "res://assets/music/dialogue/你干嘛.wav"
const DUNGEON_BGM := "res://assets/music/音效/bgm_1Low #310032.wav"

var _cache: Dictionary = {}
var _last_played_msec: Dictionary = {}
var _lobby_music_player: AudioStreamPlayer = null
var _dungeon_bgm_player: AudioStreamPlayer = null


func play_lobby_entry() -> void:
	start_lobby_music()


func start_lobby_music() -> void:
	stop_dungeon_bgm()
	if _lobby_music_player != null and is_instance_valid(_lobby_music_player):
		if not _lobby_music_player.playing:
			_lobby_music_player.play()
		return
	_lobby_music_player = _create_loop_player(LOBBY_ENTRY, -4.0)


func stop_lobby_music() -> void:
	if _lobby_music_player != null and is_instance_valid(_lobby_music_player):
		_lobby_music_player.stop()
		_lobby_music_player.queue_free()
	_lobby_music_player = null


func start_dungeon_bgm() -> void:
	stop_lobby_music()
	if _dungeon_bgm_player != null and is_instance_valid(_dungeon_bgm_player):
		if not _dungeon_bgm_player.playing:
			_dungeon_bgm_player.play()
		return
	_dungeon_bgm_player = _create_loop_player(DUNGEON_BGM, -8.0)


func stop_dungeon_bgm() -> void:
	if _dungeon_bgm_player != null and is_instance_valid(_dungeon_bgm_player):
		_dungeon_bgm_player.stop()
		_dungeon_bgm_player.queue_free()
	_dungeon_bgm_player = null


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


func play_shoot() -> void:
	play_sfx(SHOOT, -8.0, 0.08)


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


func _create_loop_player(path: String, volume_db: float) -> AudioStreamPlayer:
	var stream := _get_stream(path)
	if stream == null:
		return null
	var player := AudioStreamPlayer.new()
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	player.bus = "Master"
	player.stream = stream
	player.volume_db = volume_db
	add_child(player)
	player.finished.connect(func() -> void:
		if player != null and is_instance_valid(player):
			player.play()
	)
	player.play()
	return player


func _get_stream(path: String) -> AudioStream:
	if _cache.has(path):
		return _cache[path] as AudioStream
	var stream := load(path) as AudioStream
	if stream != null:
		_cache[path] = stream
	return stream
