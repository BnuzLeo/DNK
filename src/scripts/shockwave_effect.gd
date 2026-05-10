extends Node2D

const FRAME_COUNT := 9
const FRAME_SIZE := Vector2(130.0, 161.0)
const DEFAULT_FPS := 14.0

var _sprite: AnimatedSprite2D
var _fallback_color := Color(0.3, 0.7, 1.0, 0.8)
var _elapsed := 0.0
var _duration := 0.65
var _callback: Callable
var _callback_called := false


func setup(sheet_path: String, tint: Color, display_height: float = 140.0, callback: Callable = Callable()) -> void:
	_fallback_color = tint
	_callback = callback
	_duration = float(FRAME_COUNT) / DEFAULT_FPS
	var frames := _build_frames(sheet_path)
	if frames != null:
		_sprite = AnimatedSprite2D.new()
		_sprite.sprite_frames = frames
		_sprite.animation = "shockwave"
		_sprite.centered = true
		_sprite.z_index = 20
		_sprite.scale = Vector2.ONE * (display_height / FRAME_SIZE.y)
		add_child(_sprite)
		_sprite.play("shockwave")
	var tween := create_tween()
	tween.tween_interval(_duration)
	tween.tween_callback(_finish)


func _process(delta: float) -> void:
	_elapsed += delta
	if _sprite == null:
		queue_redraw()


func _build_frames(sheet_path: String) -> SpriteFrames:
	var texture := _load_texture(sheet_path)
	if texture == null:
		return null
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	frames.add_animation("shockwave")
	frames.set_animation_speed("shockwave", DEFAULT_FPS)
	frames.set_animation_loop("shockwave", false)
	for i in FRAME_COUNT:
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(Vector2(FRAME_SIZE.x * i, 0.0), FRAME_SIZE)
		frames.add_frame("shockwave", atlas)
	return frames


func _load_texture(path: String) -> Texture2D:
	var texture := load(path) as Texture2D
	if texture != null:
		return texture
	var image := Image.new()
	var absolute_path := ProjectSettings.globalize_path(path)
	if image.load(absolute_path) != OK:
		return null
	return ImageTexture.create_from_image(image)


func _finish() -> void:
	if not _callback_called and _callback.is_valid():
		_callback_called = true
		_callback.call()
	queue_free()


func _draw() -> void:
	if _sprite != null:
		return
	var progress := clampf(_elapsed / _duration, 0.0, 1.0)
	var radius := lerpf(10.0, 70.0, progress)
	var alpha := 1.0 - progress
	draw_circle(Vector2.ZERO, radius, Color(_fallback_color.r, _fallback_color.g, _fallback_color.b, 0.12 * alpha))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 36, Color(_fallback_color.r, _fallback_color.g, _fallback_color.b, 0.9 * alpha), 4.0)
	draw_arc(Vector2.ZERO, radius * 0.62, 0.0, TAU, 28, Color.WHITE, 1.5 * alpha)
