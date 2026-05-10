extends CanvasLayer
class_name BerserkAwakeningFx

const VS := preload("res://scripts/visual_spec.gd")

const FRAME_PATHS := [
	"res://assets/export/characters/KUN/觉醒/觉醒_000.png",
	"res://assets/export/characters/KUN/觉醒/觉醒_001.png",
	"res://assets/export/characters/KUN/觉醒/觉醒_002.png",
	"res://assets/export/characters/KUN/觉醒/觉醒_003.png",
	"res://assets/export/characters/KUN/觉醒/觉醒_004.png",
	"res://assets/export/characters/KUN/觉醒/觉醒_005.png",
	"res://assets/export/characters/KUN/觉醒/觉醒_006.png",
	"res://assets/export/characters/KUN/觉醒/觉醒_007.png",
]
const AWAKENING_MUSIC_PATH := "res://assets/music/觉醒music.wav"

const ANIMATION_NAME := "awakening"
const DISPLAY_SIZE := Vector2(426.0, 240.0)
const STAGE_SIZE := Vector2(960.0, 300.0)
const PLAY_FPS := 14.0
const ENTRY_DURATION := 0.22
const EXIT_DURATION := 0.26
const FINISH_HOLD := 0.08

var _stage: Control
var _speed_lines: Control
var _shine: Control
var _shadow_sprite: AnimatedSprite2D
var _glow_sprite: AnimatedSprite2D
var _main_sprite: AnimatedSprite2D
var _closing := false


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("berserk_awaken_fx")
	_build_scene()
	_play_intro()


func _build_scene() -> void:
	var frames := _build_frames()
	if frames == null:
		queue_free()
		return

	_stage = Control.new()
	_stage.position = Vector2(0.0, (VS.VIEWPORT_SIZE.y - STAGE_SIZE.y) * 0.5)
	_stage.size = STAGE_SIZE
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.draw.connect(_draw_stage.bind(_stage))
	add_child(_stage)

	_speed_lines = Control.new()
	_speed_lines.position = _stage.position
	_speed_lines.size = STAGE_SIZE
	_speed_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_speed_lines.modulate.a = 0.0
	_speed_lines.draw.connect(_draw_speed_lines.bind(_speed_lines))
	add_child(_speed_lines)

	_shine = Control.new()
	_shine.position = _stage.position
	_shine.size = STAGE_SIZE
	_shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shine.modulate.a = 0.0
	_shine.draw.connect(_draw_shine.bind(_shine))
	add_child(_shine)

	_shadow_sprite = _make_sprite(frames, Vector2(0.0, 18.0), Color(0.0, 0.0, 0.0, 0.32), 1.03)
	_glow_sprite = _make_sprite(frames, Vector2.ZERO, Color(1.0, 0.54, 0.16, 0.38), 1.05, true)
	_main_sprite = _make_sprite(frames, Vector2.ZERO, Color.WHITE, 1.0)
	_main_sprite.animation_finished.connect(_on_main_animation_finished)

	add_child(_shadow_sprite)
	add_child(_glow_sprite)
	add_child(_main_sprite)


func _build_frames() -> SpriteFrames:
	var sprite_frames := SpriteFrames.new()
	sprite_frames.remove_animation("default")
	sprite_frames.add_animation(ANIMATION_NAME)
	sprite_frames.set_animation_speed(ANIMATION_NAME, PLAY_FPS)
	sprite_frames.set_animation_loop(ANIMATION_NAME, false)
	for path in FRAME_PATHS:
		var texture := _load_texture(path)
		if texture != null:
			sprite_frames.add_frame(ANIMATION_NAME, texture)
	if sprite_frames.get_frame_count(ANIMATION_NAME) <= 0:
		return null
	return sprite_frames


func _load_texture(path: String) -> Texture2D:
	var texture := load(path) as Texture2D
	if texture != null:
		return texture
	var image := Image.new()
	if image.load(path) != OK:
		return null
	return ImageTexture.create_from_image(image)


func _load_music_stream() -> AudioStream:
	var stream := load(AWAKENING_MUSIC_PATH) as AudioStream
	if stream != null:
		return stream
	var absolute_path := ProjectSettings.globalize_path(AWAKENING_MUSIC_PATH)
	if FileAccess.file_exists(absolute_path):
		return AudioStreamWAV.load_from_file(absolute_path)
	if FileAccess.file_exists(AWAKENING_MUSIC_PATH):
		return AudioStreamWAV.load_from_file(AWAKENING_MUSIC_PATH)
	return null


func _play_awakening_music() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	for node in get_tree().get_nodes_in_group("berserk_awaken_music"):
		if is_instance_valid(node):
			node.queue_free()
	var stream := _load_music_stream()
	if stream == null:
		push_warning("Awakening music failed to load: %s" % AWAKENING_MUSIC_PATH)
		return
	var player := AudioStreamPlayer.new()
	player.bus = "Master"
	player.volume_db = 2.0
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	player.stream = stream
	player.finished.connect(player.queue_free)
	player.add_to_group("berserk_awaken_music")
	scene.add_child(player)
	player.play()


func _make_sprite(
	frames: SpriteFrames,
	offset: Vector2,
	color: Color,
	scale_multiplier: float,
	additive: bool = false
) -> AnimatedSprite2D:
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = frames
	sprite.animation = ANIMATION_NAME
	sprite.centered = true
	sprite.position = _get_entry_position() + offset
	sprite.modulate = color
	sprite.scale = Vector2.ONE * scale_multiplier
	if additive:
		var material := CanvasItemMaterial.new()
		material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		sprite.material = material
	return sprite


func _get_focus_position() -> Vector2:
	return Vector2(VS.VIEWPORT_SIZE.x * 0.5, VS.VIEWPORT_SIZE.y * 0.5)


func _get_entry_position() -> Vector2:
	return Vector2(-DISPLAY_SIZE.x * 0.5 - 48.0, _get_focus_position().y)


func _get_exit_position() -> Vector2:
	return Vector2(VS.VIEWPORT_SIZE.x + DISPLAY_SIZE.x * 0.5 + 56.0, _get_focus_position().y)


func _play_intro() -> void:
	_play_awakening_music()

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_speed_lines, "modulate:a", 1.0, 0.08)
	tween.tween_property(_shine, "modulate:a", 1.0, 0.12)
	tween.tween_property(_shadow_sprite, "modulate:a", 1.0, 0.08)
	tween.tween_property(_glow_sprite, "modulate:a", 1.0, 0.08)
	tween.tween_property(_main_sprite, "modulate:a", 1.0, 0.08)
	tween.tween_property(_shadow_sprite, "position", _get_focus_position() + Vector2(0.0, 18.0), ENTRY_DURATION).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_property(_glow_sprite, "position", _get_focus_position(), ENTRY_DURATION).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_property(_main_sprite, "position", _get_focus_position(), ENTRY_DURATION).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)

	_shadow_sprite.play(ANIMATION_NAME)
	_glow_sprite.play(ANIMATION_NAME)
	_main_sprite.play(ANIMATION_NAME)


func _on_main_animation_finished() -> void:
	if _closing:
		return
	_closing = true
	await get_tree().create_timer(FINISH_HOLD).timeout
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_speed_lines, "modulate:a", 0.0, EXIT_DURATION)
	tween.tween_property(_shine, "modulate:a", 0.0, EXIT_DURATION)
	tween.tween_property(_shadow_sprite, "modulate:a", 0.0, EXIT_DURATION * 0.75)
	tween.tween_property(_glow_sprite, "modulate:a", 0.0, EXIT_DURATION * 0.65)
	tween.tween_property(_main_sprite, "modulate:a", 0.0, EXIT_DURATION * 0.78)
	tween.tween_property(_shadow_sprite, "position", _get_exit_position() + Vector2(0.0, 18.0), EXIT_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(_glow_sprite, "position", _get_exit_position(), EXIT_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(_main_sprite, "position", _get_exit_position(), EXIT_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await tween.finished
	queue_free()


func _draw_stage(ctrl: Control) -> void:
	var rect := Rect2(Vector2.ZERO, STAGE_SIZE)
	ctrl.draw_rect(rect, Color(0.06, 0.05, 0.08, 0.14))
	ctrl.draw_rect(Rect2(0.0, 24.0, STAGE_SIZE.x, 14.0), Color(1.0, 0.52, 0.18, 0.05))
	ctrl.draw_rect(Rect2(0.0, STAGE_SIZE.y - 38.0, STAGE_SIZE.x, 14.0), Color(1.0, 0.52, 0.18, 0.05))
	ctrl.draw_rect(Rect2(0.0, STAGE_SIZE.y * 0.5 - 52.0, STAGE_SIZE.x, 104.0), Color(1.0, 0.64, 0.22, 0.045))
	ctrl.draw_rect(Rect2(0.0, STAGE_SIZE.y * 0.5 - 2.0, STAGE_SIZE.x, 4.0), Color(1.0, 0.90, 0.62, 0.10))


func _draw_speed_lines(ctrl: Control) -> void:
	var center := Vector2(STAGE_SIZE.x * 0.5, STAGE_SIZE.y * 0.5)
	for i in range(6):
		var y := center.y - 82.0 + i * 28.0
		var left_x := 58.0 + i * 10.0
		var width := 250.0 - i * 20.0
		ctrl.draw_rect(Rect2(left_x, y, width, 3.0), Color(1.0, 0.74, 0.34, 0.085 - i * 0.008))
	for i in range(6):
		var y := center.y - 75.0 + i * 26.0
		var right_x := STAGE_SIZE.x - 210.0 + i * 12.0
		var width := 140.0 - i * 12.0
		ctrl.draw_rect(Rect2(right_x, y, width, 2.0), Color(1.0, 0.92, 0.70, 0.075 - i * 0.008))
	ctrl.draw_rect(Rect2(0.0, center.y - 36.0, STAGE_SIZE.x, 72.0), Color(1.0, 0.50, 0.14, 0.025))


func _draw_shine(ctrl: Control) -> void:
	var center := Vector2(STAGE_SIZE.x * 0.5 + 24.0, STAGE_SIZE.y * 0.5 - 8.0)
	ctrl.draw_circle(center, 96.0, Color(1.0, 0.82, 0.56, 0.055))
	ctrl.draw_circle(center + Vector2(26.0, 0.0), 42.0, Color(1.0, 0.95, 0.84, 0.08))
	ctrl.draw_rect(Rect2(center.x - 220.0, center.y - 7.0, 440.0, 14.0), Color(1.0, 0.84, 0.56, 0.06))
	ctrl.draw_rect(Rect2(center.x - 320.0, center.y - 1.5, 640.0, 3.0), Color(1.0, 0.95, 0.84, 0.09))
