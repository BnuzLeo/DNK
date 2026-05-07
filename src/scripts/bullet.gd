extends Area2D

func _draw() -> void:
	if not visible:
		return
	var is_player: bool = get_meta("is_player", true)
	var is_dart: bool = get_meta("is_dart", false)

	if is_dart:
		# 飞镖：菱形，Neon Orange
		var color := Color(1.0, 0.53, 0.0)
		var pts := PackedVector2Array([
			Vector2(6, 0), Vector2(0, -4), Vector2(-6, 0), Vector2(0, 4)
		])
		draw_colored_polygon(pts, color)
		draw_polyline(pts + PackedVector2Array([pts[0]]), Color.WHITE, 1.0)
	else:
		var color := Color(0.0, 0.898, 1.0) if is_player else Color(1.0, 0.0, 1.0)
		draw_circle(Vector2.ZERO, 4.0, color)
		draw_circle(Vector2.ZERO, 6.0, Color(color.r, color.g, color.b, 0.3))
