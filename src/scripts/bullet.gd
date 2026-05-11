extends Area2D

const VS := preload("res://scripts/visual_spec.gd")
const SNOWBALL_TEXTURE := preload("res://assets/export/projectiles/snowball.png")
const BOSS_BIG_SNOWBALL_TEXTURE := preload("res://assets/export/enemies/boss/雪人武器-大型雪球.png")
const BOSS_SMALL_SNOWBALL_TEXTURE := preload("res://assets/export/enemies/boss/雪人武器-雪球.png")

func _draw() -> void:
	if not visible:
		return
	var is_player: bool = get_meta("is_player", true)
	var is_dart: bool = get_meta("is_dart", false)
	var projectile_type: String = get_meta("projectile_type", "")

	if projectile_type == "basketball":
		var radius := VS.PROJECTILE_DISPLAY_SIZE * 0.58
		draw_circle(Vector2.ZERO, radius, Color(0.95, 0.45, 0.08))
		draw_arc(Vector2.ZERO, radius, -PI * 0.45, PI * 0.45, 12, Color(0.18, 0.08, 0.03), 1.2)
		draw_arc(Vector2.ZERO, radius, PI * 0.55, PI * 1.45, 12, Color(0.18, 0.08, 0.03), 1.2)
		draw_line(Vector2(0, -radius), Vector2(0, radius), Color(0.18, 0.08, 0.03), 1.2)
		draw_line(Vector2(-radius, 0), Vector2(radius, 0), Color(0.18, 0.08, 0.03), 1.2)
		draw_circle(Vector2.ZERO, radius + 2.0, Color(1.0, 0.45, 0.05, 0.25))
	elif projectile_type == "arrow":
		var shaft := Color(0.72, 0.48, 0.25)
		var tip := Color(0.9, 0.9, 0.82)
		draw_line(Vector2(-14.0, 0.0), Vector2(11.0, 0.0), shaft, 2.0)
		draw_colored_polygon(PackedVector2Array([Vector2(16.0, 0.0), Vector2(8.0, -4.0), Vector2(8.0, 4.0)]), tip)
		draw_line(Vector2(-14.0, 0.0), Vector2(-19.0, -4.0), Color(0.85, 0.85, 0.85), 1.2)
		draw_line(Vector2(-14.0, 0.0), Vector2(-19.0, 4.0), Color(0.85, 0.85, 0.85), 1.2)
	elif projectile_type == "snowball":
		var snowball_size := Vector2(18.0, 18.0)
		draw_texture_rect(SNOWBALL_TEXTURE, Rect2(-snowball_size * 0.5, snowball_size), false)
	elif projectile_type == "boss_big_snowball":
		var big_size := Vector2(30.0, 28.0)
		draw_texture_rect(BOSS_BIG_SNOWBALL_TEXTURE, Rect2(-big_size * 0.5, big_size), false)
	elif projectile_type == "boss_small_snowball":
		var small_size := Vector2(18.0, 20.0)
		draw_texture_rect(BOSS_SMALL_SNOWBALL_TEXTURE, Rect2(-small_size * 0.5, small_size), false)
	elif is_dart:
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
