extends Node2D

const VS := preload("res://scripts/visual_spec.gd")

const TITLE_STINGER_PATH := "res://assets/music/dialogue/真的是你啊.MP3"
const VIDEO_PATH := "res://assets/export/start/开场视频.ogv"
const KUN_PARALLAX_RANGE := Vector2(36.0, 24.0)
const SKIP_HOLD_TIME := 1.0

@onready var _bg: TextureRect = $Background
@onready var _kun: TextureRect = $KunParallax
@onready var _title_root: Control = $Overlay/TitleRoot
@onready var _start_button: Button = $Overlay/TitleRoot/StartButton
@onready var _lobby_test_button: Button = $Overlay/TitleRoot/LobbyTestButton
@onready var _dungeon_test_button: Button = $Overlay/TitleRoot/DungeonTestButton
@onready var _video_overlay: CanvasLayer = $VideoOverlay
@onready var _video_root: Control = $VideoOverlay/VideoRoot
@onready var _video_player: VideoStreamPlayer = $VideoOverlay/VideoRoot/VideoPlayer
@onready var _skip_hint: Label = $VideoOverlay/VideoRoot/SkipHint
@onready var _skip_bar_bg: ColorRect = $VideoOverlay/VideoRoot/SkipBarBg
@onready var _skip_bar_fill: ColorRect = $VideoOverlay/VideoRoot/SkipBarFill

var _mouse_ratio := Vector2.ZERO
var _video_started := false
var _starting := false
var _skip_hold := 0.0
var _title_stinger: AudioStreamPlayer
var _impact_flash: ColorRect
var _impact_band: ColorRect


func _ready() -> void:
	GameManager.change_state(GameManager.GameState.MAIN_MENU)
	_start_button.pressed.connect(_on_start_pressed)
	_lobby_test_button.pressed.connect(_go_to_lobby)
	_dungeon_test_button.pressed.connect(_go_to_dungeon)
	_video_player.finished.connect(_on_video_finished)
	_video_overlay.visible = false
	_setup_feedback_nodes()
	_update_title_style()
	_update_skip_progress(0.0)
	_play_title_stinger()


func _process(delta: float) -> void:
	_update_kun_parallax(delta)
	if not _video_started:
		return
	if Input.is_key_pressed(KEY_SPACE):
		_skip_hold = min(_skip_hold + delta, SKIP_HOLD_TIME)
		_update_skip_progress(_skip_hold / SKIP_HOLD_TIME)
		if _skip_hold >= SKIP_HOLD_TIME:
			_finish_video_and_enter_lobby()
	else:
		if _skip_hold > 0.0:
			_skip_hold = max(_skip_hold - delta * 2.5, 0.0)
			_update_skip_progress(_skip_hold / SKIP_HOLD_TIME)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var pos: Vector2 = event.position
		_mouse_ratio = Vector2(
			clampf((pos.x / VS.VIEWPORT_SIZE.x) * 2.0 - 1.0, -1.0, 1.0),
			clampf((pos.y / VS.VIEWPORT_SIZE.y) * 2.0 - 1.0, -1.0, 1.0)
		)
	elif not _video_started and not _starting and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER:
			_on_start_pressed()


func _update_kun_parallax(delta: float) -> void:
	var target := Vector2(-KUN_PARALLAX_RANGE.x * _mouse_ratio.x, -KUN_PARALLAX_RANGE.y * _mouse_ratio.y)
	_kun.position = _kun.position.lerp(target, clampf(delta * 5.0, 0.0, 1.0))


func _update_title_style() -> void:
	_skip_hint.label_settings = _make_label_settings(16, Color(1.0, 0.94, 0.74), Color(0.05, 0.05, 0.06, 0.9), 2)


func _make_label_settings(font_size: int, font_color: Color, shadow_color: Color, shadow_size: int) -> LabelSettings:
	var settings := LabelSettings.new()
	settings.font_size = font_size
	settings.font_color = font_color
	settings.shadow_color = shadow_color
	settings.shadow_size = shadow_size
	return settings


func _setup_feedback_nodes() -> void:
	_bg.pivot_offset = VS.VIEWPORT_SIZE * 0.5
	_kun.pivot_offset = VS.VIEWPORT_SIZE * 0.5
	_start_button.pivot_offset = _start_button.size * 0.5
	_lobby_test_button.pivot_offset = _lobby_test_button.size * 0.5
	_dungeon_test_button.pivot_offset = _dungeon_test_button.size * 0.5

	_impact_flash = ColorRect.new()
	_impact_flash.size = VS.VIEWPORT_SIZE
	_impact_flash.color = Color(1.0, 0.86, 0.45, 0.0)
	_impact_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_impact_flash.visible = false
	$Overlay.add_child(_impact_flash)

	_impact_band = ColorRect.new()
	_impact_band.position = Vector2(-VS.VIEWPORT_SIZE.x, VS.VIEWPORT_SIZE.y * 0.5 - 36.0)
	_impact_band.size = Vector2(VS.VIEWPORT_SIZE.x, 72.0)
	_impact_band.color = Color(1.0, 0.72, 0.24, 0.0)
	_impact_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_impact_band.visible = false
	$Overlay.add_child(_impact_band)


func _play_title_stinger() -> void:
	var stream := _load_audio_stream(TITLE_STINGER_PATH)
	if stream == null:
		return
	_title_stinger = AudioStreamPlayer.new()
	_title_stinger.bus = "Master"
	_title_stinger.volume_db = 0.0
	_title_stinger.stream = stream
	add_child(_title_stinger)
	_title_stinger.play()


func _load_audio_stream(path: String) -> AudioStream:
	var stream := load(path) as AudioStream
	if stream != null:
		return stream
	var absolute_path := ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(absolute_path):
		return null
	var ext := path.get_extension().to_lower()
	if ext == "wav":
		return AudioStreamWAV.load_from_file(absolute_path)
	if ext == "mp3":
		return AudioStreamMP3.load_from_file(absolute_path)
	return null


func _on_start_pressed() -> void:
	if _video_started or _starting:
		return
	_starting = true
	_start_button.disabled = true
	await _play_start_feedback()
	if _title_stinger != null and _title_stinger.playing:
		_title_stinger.stop()
	_video_started = true
	_starting = false
	_title_root.visible = false
	_video_overlay.visible = true
	_skip_hold = 0.0
	_update_skip_progress(0.0)
	_load_and_play_video()


func _go_to_lobby() -> void:
	if _video_started or _starting:
		return
	GameManager.change_state(GameManager.GameState.LOBBY)
	get_tree().change_scene_to_file("res://scenes/Lobby.tscn")


func _go_to_dungeon() -> void:
	if _video_started or _starting:
		return
	GameManager.change_state(GameManager.GameState.PLAYING)
	get_tree().change_scene_to_file("res://scenes/Main.tscn")


func _play_start_feedback() -> void:
	_impact_flash.visible = true
	_impact_band.visible = true
	_impact_flash.color.a = 0.0
	_impact_band.color.a = 0.0
	_impact_band.position.x = -VS.VIEWPORT_SIZE.x

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_start_button, "scale", Vector2(0.92, 0.92), 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_start_button, "scale", Vector2(1.08, 1.08), 0.12).set_delay(0.06).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_start_button, "modulate:a", 0.0, 0.18).set_delay(0.14)
	tween.tween_property(_bg, "scale", Vector2(1.035, 1.035), 0.34).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_kun, "scale", Vector2(1.085, 1.085), 0.34).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_kun, "modulate", Color(1.18, 1.12, 0.98, 1.0), 0.16)
	tween.tween_property(_impact_flash, "color:a", 0.42, 0.05)
	tween.tween_property(_impact_flash, "color:a", 0.0, 0.24).set_delay(0.05)
	tween.tween_property(_impact_band, "color:a", 0.34, 0.06)
	tween.tween_property(_impact_band, "color:a", 0.0, 0.24).set_delay(0.08)
	tween.tween_property(_impact_band, "position:x", VS.VIEWPORT_SIZE.x, 0.30).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tween.finished


func _load_and_play_video() -> void:
	var stream := load(VIDEO_PATH) as VideoStream
	if stream == null:
		var absolute_path := ProjectSettings.globalize_path(VIDEO_PATH)
		if not FileAccess.file_exists(absolute_path):
			_finish_video_and_enter_lobby()
			return
		var theora_stream := VideoStreamTheora.new()
		theora_stream.file = VIDEO_PATH
		stream = theora_stream
	_video_player.stream = stream
	_video_player.play()


func _on_video_finished() -> void:
	_finish_video_and_enter_lobby()


func _finish_video_and_enter_lobby() -> void:
	if not _video_started:
		return
	_video_started = false
	if _video_player.is_playing():
		_video_player.stop()
	GameManager.change_state(GameManager.GameState.LOBBY)
	get_tree().change_scene_to_file("res://scenes/Lobby.tscn")


func _update_skip_progress(ratio: float) -> void:
	var clamped := clampf(ratio, 0.0, 1.0)
	var full_width := _skip_bar_bg.size.x - 4.0
	_skip_bar_fill.size.x = full_width * clamped
