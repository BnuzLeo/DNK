extends Node2D

const STRIPE_SPACING := 52.0
const STRIPE_LENGTH := 18.0
const SPARK_SPACING := 34.0
const END_FLASH_SCALE := 1.6

var segments: Array[Dictionary] = []
var width := 32.0
var beam_color := Color(0.3, 0.95, 1.0, 0.9)
var _time := 0.0


func _ready() -> void:
	var additive_material := CanvasItemMaterial.new()
	additive_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive_material
	set_process(false)


func setup(new_segments: Array[Dictionary], _new_texture: Texture2D, new_width: float, color: Color) -> void:
	segments = new_segments
	width = new_width
	beam_color = color
	visible = not segments.is_empty()
	set_process(visible)
	queue_redraw()


func clear() -> void:
	segments.clear()
	visible = false
	set_process(false)
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	if segments.is_empty():
		return
	var pulse := 0.78 + sin(_time * 18.0) * 0.12
	for i in segments.size():
		var segment: Dictionary = segments[i]
		var start: Vector2 = segment["from"]
		var end: Vector2 = segment["to"]
		_draw_beam_segment(start, end, i, pulse)

		if i == 0:
			_draw_flash(start, width * END_FLASH_SCALE, 0.95)
		_draw_flash(end, width * (0.95 if i == segments.size() - 1 else 0.75), 0.68)


func _draw_beam_segment(start: Vector2, end: Vector2, segment_index: int, pulse: float) -> void:
	var delta := end - start
	var length := delta.length()
	if length <= 1.0:
		return
	var dir := delta / length
	var normal := Vector2(-dir.y, dir.x)
	var glow_color := Color(beam_color.r, beam_color.g, beam_color.b, 0.16 * pulse)
	var mid_color := Color(beam_color.r, beam_color.g, beam_color.b, 0.48 * pulse)
	var edge_color := Color(beam_color.r, beam_color.g, beam_color.b, 0.92)

	draw_line(start, end, glow_color, width * 2.7, true)
	draw_line(start, end, Color(beam_color.r, beam_color.g, beam_color.b, 0.24 * pulse), width * 1.8, true)
	draw_line(start, end, mid_color, width * 0.86, true)
	draw_line(start, end, Color(1.0, 1.0, 1.0, 0.95), width * 0.24, true)
	draw_line(start + normal * width * 0.24, end + normal * width * 0.24, edge_color, maxf(width * 0.05, 1.5), true)
	draw_line(start - normal * width * 0.24, end - normal * width * 0.24, edge_color, maxf(width * 0.05, 1.5), true)

	_draw_flow_stripes(start, dir, normal, length, segment_index)
	_draw_electric_edges(start, dir, normal, length, segment_index)


func _draw_flow_stripes(start: Vector2, dir: Vector2, normal: Vector2, length: float, segment_index: int) -> void:
	var offset := fmod(_time * 220.0 + segment_index * 19.0, STRIPE_SPACING)
	var d := -offset
	while d < length:
		if d > 0.0:
			var center := start + dir * d
			var stripe_start := center - dir * STRIPE_LENGTH * 0.45 - normal * width * 0.18
			var stripe_end := center + dir * STRIPE_LENGTH * 0.45 + normal * width * 0.18
			draw_line(stripe_start, stripe_end, Color(1.0, 1.0, 1.0, 0.58), maxf(width * 0.08, 2.0), true)
		d += STRIPE_SPACING


func _draw_electric_edges(start: Vector2, dir: Vector2, normal: Vector2, length: float, segment_index: int) -> void:
	var points_a := PackedVector2Array()
	var points_b := PackedVector2Array()
	var step_count := maxi(int(length / SPARK_SPACING), 2)
	for i in step_count + 1:
		var ratio := float(i) / float(step_count)
		var d := length * ratio
		var wave := sin(_time * 24.0 + d * 0.08 + segment_index * 1.7) * width * 0.1
		var base := start + dir * d
		points_a.append(base + normal * (width * 0.38 + wave))
		points_b.append(base - normal * (width * 0.38 + wave))
	if points_a.size() >= 2:
		draw_polyline(points_a, Color(0.75, 1.0, 1.0, 0.42), maxf(width * 0.035, 1.0), true)
	if points_b.size() >= 2:
		draw_polyline(points_b, Color(0.75, 1.0, 1.0, 0.34), maxf(width * 0.035, 1.0), true)


func _draw_flash(pos: Vector2, radius: float, alpha: float) -> void:
	var pulse := 0.82 + sin(_time * 20.0) * 0.18
	draw_circle(pos, radius * 0.62 * pulse, Color(beam_color.r, beam_color.g, beam_color.b, alpha * 0.2))
	draw_circle(pos, radius * 0.32 * pulse, Color(beam_color.r, beam_color.g, beam_color.b, alpha * 0.42))
	draw_circle(pos, radius * 0.13 * pulse, Color(1.0, 1.0, 1.0, alpha * 0.86))
