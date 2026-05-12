extends CanvasLayer
class_name BerserkAwakeningFx

const VS := preload("res://scripts/visual_spec.gd")

const AWAKENING_IMAGE_PATH := "res://assets/export/characters/KUN/觉醒.png"
const AWAKENING_MUSIC_PATH := "res://assets/music/dialogue/觉醒music.wav"
const ENABLE_DIALOGUE_AUDIO := false

const ENTRY_DURATION := 0.14
const EXIT_DURATION := 0.16
const FINISH_HOLD := 0.8
const ENTRY_FX_OVERHANG := Vector2(132.0, 38.0)

var _awakening_group: Node2D
var _entry_fx: Control
var _main_sprite: Sprite2D
var _image_size := Vector2.ZERO
var _closing := false


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("berserk_awaken_fx")
	_build_scene()
	_play_intro()


func _build_scene() -> void:
	var texture := _load_texture(AWAKENING_IMAGE_PATH)
	if texture == null:
		queue_free()
		return
	_image_size = texture.get_size()

	_awakening_group = Node2D.new()
	_awakening_group.position = _get_entry_position()
	_awakening_group.modulate.a = 0.0
	add_child(_awakening_group)

	_entry_fx = _make_entry_fx()
	_awakening_group.add_child(_entry_fx)

	_main_sprite = _make_sprite(texture)
	_awakening_group.add_child(_main_sprite)


func _load_texture(path: String) -> Texture2D:
	var texture := load(path) as Texture2D
	if texture != null:
		return texture
	var image := Image.new()
	if image.load(path) != OK:
		return null
	return ImageTexture.create_from_image(image)


func _load_music_stream() -> AudioStream:
	if not ENABLE_DIALOGUE_AUDIO:
		return null
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
	if not ENABLE_DIALOGUE_AUDIO:
		return
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


func _make_sprite(texture: Texture2D) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = true
	sprite.position = Vector2.ZERO
	sprite.z_index = 1
	return sprite


func _make_entry_fx() -> Control:
	var ctrl := Control.new()
	ctrl.position = -_image_size * 0.5 - ENTRY_FX_OVERHANG
	ctrl.size = _image_size + ENTRY_FX_OVERHANG * 2.0
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.z_index = 0
	ctrl.modulate.a = 0.0
	ctrl.draw.connect(_draw_entry_fx.bind(ctrl))
	return ctrl


func _draw_entry_fx(ctrl: Control) -> void:
	var center_y := ctrl.size.y * 0.5
	for i in range(8):
		var y := center_y - 86.0 + i * 22.0
		var x := 10.0 + i * 9.0
		var length := ctrl.size.x * (0.74 - i * 0.035)
		var thickness := 3.0 + float(i % 3)
		var color := Color(0.90, 0.97, 1.0, 0.28 - i * 0.018)
		var points := PackedVector2Array([
			Vector2(x, y),
			Vector2(x + length, y - 15.0),
			Vector2(x + length + 58.0, y - 15.0 + thickness),
			Vector2(x + 42.0, y + thickness)
		])
		ctrl.draw_polygon(points, PackedColorArray([color, color, color, color]))

	var gold := Color(1.0, 0.82, 0.28, 0.42)
	ctrl.draw_polygon(
		PackedVector2Array([
			Vector2(44.0, center_y + 38.0),
			Vector2(ctrl.size.x - 34.0, center_y - 30.0),
			Vector2(ctrl.size.x - 4.0, center_y - 18.0),
			Vector2(74.0, center_y + 52.0)
		]),
		PackedColorArray([gold, gold, gold, gold])
	)
	ctrl.draw_rect(Rect2(28.0, center_y - 4.0, ctrl.size.x - 44.0, 5.0), Color(1.0, 1.0, 1.0, 0.32))
	ctrl.draw_rect(Rect2(0.0, center_y + 14.0, ctrl.size.x * 0.62, 3.0), Color(0.52, 0.78, 1.0, 0.30))


func _get_focus_position() -> Vector2:
	return Vector2(
		_image_size.x * 0.5,
		VS.VIEWPORT_SIZE.y - _image_size.y * 0.5
	)


func _get_entry_position() -> Vector2:
	return Vector2(-_image_size.x * 0.5, _get_focus_position().y)


func _get_exit_position() -> Vector2:
	return _get_entry_position()


func _play_intro() -> void:
	if _awakening_group == null or _main_sprite == null:
		return
	_play_awakening_music()

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_awakening_group, "modulate:a", 1.0, 0.06)
	tween.tween_property(_awakening_group, "position", _get_focus_position(), ENTRY_DURATION).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_property(_entry_fx, "modulate:a", 1.0, 0.035)
	tween.tween_property(_entry_fx, "scale:x", 0.68, ENTRY_DURATION).from(1.24).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_property(_entry_fx, "position:x", _entry_fx.position.x + 82.0, ENTRY_DURATION).from(_entry_fx.position.x - 68.0).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.finished.connect(_on_intro_finished)


func _on_intro_finished() -> void:
	if _closing:
		return
	_closing = true
	_fade_entry_fx()
	await get_tree().create_timer(FINISH_HOLD).timeout
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_awakening_group, "modulate:a", 0.0, EXIT_DURATION * 0.75)
	tween.tween_property(_awakening_group, "position", _get_exit_position(), EXIT_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await tween.finished
	queue_free()


func _fade_entry_fx() -> void:
	if _entry_fx == null:
		return
	var tween := create_tween()
	tween.tween_property(_entry_fx, "modulate:a", 0.0, 0.12)
