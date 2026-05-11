extends Node2D

const ALPHA_THRESHOLD := 0.05
const TILE_OVERLAP_PIXELS := 2.0

var segments: Array[Dictionary] = []
var texture: Texture2D = null
var width := 32.0
var fallback_color := Color(0.72, 0.95, 1.0, 0.76)
var _alpha_bounds_cache: Dictionary = {}


func setup(new_segments: Array[Dictionary], new_texture: Texture2D, new_width: float, color: Color) -> void:
	segments = new_segments
	texture = new_texture
	width = new_width
	fallback_color = color
	visible = not segments.is_empty()
	_rebuild_lines()


func clear() -> void:
	segments.clear()
	visible = false
	_clear_lines()


func _rebuild_lines() -> void:
	_clear_lines()
	if segments.is_empty():
		return
	for i in segments.size():
		var segment: Dictionary = segments[i]
		var start: Vector2 = segment["from"]
		var end: Vector2 = segment["to"]
		if texture == null:
			_add_fallback_line(start, end)
		else:
			_add_textured_segment(start, end)


func _add_textured_segment(start: Vector2, end: Vector2) -> void:
	var delta := end - start
	var length := delta.length()
	if length <= 1.0:
		return
	var bounds := _get_texture_alpha_bounds(texture)
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		_add_fallback_line(start, end)
		return

	var strip := Node2D.new()
	strip.position = start
	strip.rotation = delta.angle()
	add_child(strip)

	var scale_factor := width / bounds.size.y
	var tile_source_width := bounds.size.x
	var tile_width := tile_source_width * scale_factor
	var tile_step := maxf((tile_source_width - TILE_OVERLAP_PIXELS) * scale_factor, 1.0)
	var x := 0.0
	while x < length:
		var source_width := tile_source_width
		var remaining := length - x
		if remaining < tile_width:
			source_width = clampf(ceilf(remaining / scale_factor), 1.0, tile_source_width)

		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.centered = true
		sprite.region_enabled = true
		sprite.region_rect = Rect2(bounds.position, Vector2(source_width, bounds.size.y))
		sprite.position = Vector2(x + source_width * scale_factor * 0.5, 0.0)
		sprite.scale = Vector2.ONE * scale_factor
		strip.add_child(sprite)

		if source_width < tile_source_width:
			break
		x += tile_step


func _add_fallback_line(start: Vector2, end: Vector2) -> void:
	var line := Line2D.new()
	line.points = PackedVector2Array([start, end])
	line.width = width
	line.default_color = fallback_color
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	add_child(line)


func _get_texture_alpha_bounds(source_texture: Texture2D) -> Rect2:
	var cache_key := source_texture.resource_path
	if cache_key.is_empty():
		cache_key = str(source_texture.get_instance_id())
	if _alpha_bounds_cache.has(cache_key):
		return _alpha_bounds_cache[cache_key]

	var image := source_texture.get_image()
	if image == null:
		var fallback_rect := Rect2(Vector2.ZERO, Vector2(source_texture.get_width(), source_texture.get_height()))
		_alpha_bounds_cache[cache_key] = fallback_rect
		return fallback_rect
	if image.is_compressed():
		image.decompress()

	var min_x := image.get_width()
	var min_y := image.get_height()
	var max_x := -1
	var max_y := -1
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a > ALPHA_THRESHOLD:
				min_x = mini(min_x, x)
				min_y = mini(min_y, y)
				max_x = maxi(max_x, x)
				max_y = maxi(max_y, y)
	if max_x < min_x or max_y < min_y:
		var empty_rect := Rect2(Vector2.ZERO, Vector2(source_texture.get_width(), source_texture.get_height()))
		_alpha_bounds_cache[cache_key] = empty_rect
		return empty_rect

	var rect := Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x + 1, max_y - min_y + 1))
	_alpha_bounds_cache[cache_key] = rect
	return rect


func _clear_lines() -> void:
	for child in get_children():
		if child is Node:
			remove_child(child)
			child.queue_free()
