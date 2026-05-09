extends Area2D

const VS := preload("res://scripts/visual_spec.gd")

func _draw() -> void:
	if not visible:
		return
	var is_player: bool = get_meta("is_player", true)
	var is_dart: bool = get_meta("is_dart", false)

	if is_dart:
		# 飞镖：菱形，Neon Orange
		var color := Color(1.0, 0.53, 0.0)
		var half := VS.DART_DISPLAY_SIZE * 0.5
		var pts := PackedVector2Array([
			Vector2(half.x, 0), Vector2(0, -half.y), Vector2(-half.x, 0), Vector2(0, half.y)
		])
		draw_colored_polygon(pts, color)
		draw_polyline(pts + PackedVector2Array([pts[0]]), Color.WHITE, 1.0)
	else:
		var color := Color(0.0, 0.898, 1.0) if is_player else Color(1.0, 0.0, 1.0)
		var radius := VS.PROJECTILE_DISPLAY_SIZE * 0.5
		draw_circle(Vector2.ZERO, radius, color)
		draw_circle(Vector2.ZERO, radius + 2.0, Color(color.r, color.g, color.b, 0.3))
