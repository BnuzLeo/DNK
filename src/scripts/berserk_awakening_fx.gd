extends CanvasLayer
class_name BerserkAwakeningFx

const VS := preload("res://scripts/visual_spec.gd")

const AWAKENING_IMAGE_PATH := "res://assets/export/characters/KUN/觉醒.png"
const AWAKENING_MUSIC_PATH := "res://assets/music/dialogue/觉醒music.wav"

const LEFT_MARGIN := 22.0
const ENTRY_DURATION := 0.14
const EXIT_DURATION := 0.16
const FINISH_HOLD := 0.8

var _awakening_group: Node2D
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


func _make_sprite(texture: Texture2D) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = true
	sprite.position = Vector2.ZERO
	sprite.z_index = 1
	return sprite


func _get_focus_position() -> Vector2:
	return Vector2(
		_image_size.x * 0.5 + LEFT_MARGIN,
		VS.VIEWPORT_SIZE.y - _image_size.y * 0.5
	)


func _get_entry_position() -> Vector2:
	return Vector2(-_image_size.x * 0.5 - LEFT_MARGIN, _get_focus_position().y)


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
	tween.finished.connect(_on_intro_finished)


func _on_intro_finished() -> void:
	if _closing:
		return
	_closing = true
	await get_tree().create_timer(FINISH_HOLD).timeout
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_awakening_group, "modulate:a", 0.0, EXIT_DURATION * 0.75)
	tween.tween_property(_awakening_group, "position", _get_exit_position(), EXIT_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await tween.finished
	queue_free()
