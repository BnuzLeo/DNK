extends Area2D

const VS := preload("res://scripts/visual_spec.gd")
const SNOWBALL_TEXTURE := preload("res://assets/export/projectiles/snowball.png")
const BOSS_BIG_SNOWBALL_TEXTURE := preload("res://assets/export/enemies/boss/雪人武器-大型雪球.png")
const BOSS_SMALL_SNOWBALL_TEXTURE := preload("res://assets/export/enemies/boss/雪人武器-雪球.png")
const BASKETBALL_NORMAL_PATH := "res://assets/export/weapon/weapon_01/普通模式.png"
const BASKETBALL_BERSERK_PATH := "res://assets/export/weapon/weapon_01/狂暴模式.png"
const MAN_BULLET_NORMAL_PATH := "res://assets/export/weapon/weapon_02/普通模型子弹.png"
const MAN_BULLET_BERSERK_PATH := "res://assets/export/weapon/weapon_02/狂暴模式子弹.png"

var _basketball_normal_texture: Texture2D = null
var _basketball_berserk_texture: Texture2D = null
var _man_bullet_normal_texture: Texture2D = null
var _man_bullet_berserk_texture: Texture2D = null

func _draw() -> void:
	if not visible:
		return
	var is_player: bool = get_meta("is_player", true)
	var is_dart: bool = get_meta("is_dart", false)
	var projectile_type: String = get_meta("projectile_type", "")

	if projectile_type == "basketball":
		_draw_basketball(_get_basketball_normal_texture(), Vector2(22.0, 22.0), Color(1.0, 0.72, 0.22, 0.25), Color(1.0, 0.48, 0.08, 0.25))
	elif projectile_type == "basketball_berserk":
		var lob_height: float = float(get_meta("visual_lob_height", 0.0))
		var progress: float = clampf(float(get_meta("visual_lob_progress", 0.0)), 0.0, 1.0)
		var visual_y := -sin(progress * PI) * lob_height
		draw_circle(Vector2(0.0, 6.0), 5.5, Color(0.0, 0.0, 0.0, 0.22))
		_draw_basketball(_get_basketball_berserk_texture(), Vector2(28.0, 28.0), Color(1.0, 0.24, 0.08, 0.30), Color(1.0, 0.58, 0.18, 0.34), Vector2(0.0, visual_y))
	elif projectile_type == "man_bullet":
		_draw_man_bullet(_get_man_bullet_normal_texture(), Vector2(30.0, 30.0), Color(0.25, 0.85, 1.0, 0.24))
	elif projectile_type == "man_bullet_berserk":
		_draw_man_bullet(_get_man_bullet_berserk_texture(), Vector2(38.0, 38.0), Color(1.0, 0.28, 0.08, 0.34))
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


func _draw_basketball(texture: Texture2D, size: Vector2, glow: Color, trail: Color, offset: Vector2 = Vector2.ZERO) -> void:
	draw_circle(offset, maxf(size.x, size.y) * 0.52, trail)
	draw_circle(offset, maxf(size.x, size.y) * 0.42, glow)
	if texture != null:
		draw_texture_rect(texture, Rect2(offset - size * 0.5, size), false)


func _draw_man_bullet(texture: Texture2D, size: Vector2, glow: Color) -> void:
	draw_line(Vector2(-22.0, 0.0), Vector2(-8.0, 0.0), glow, 4.0)
	draw_circle(Vector2.ZERO, maxf(size.x, size.y) * 0.46, glow)
	if texture != null:
		draw_texture_rect(texture, Rect2(-size * 0.5, size), false)


func _get_basketball_normal_texture() -> Texture2D:
	if _basketball_normal_texture == null:
		_basketball_normal_texture = load(BASKETBALL_NORMAL_PATH) as Texture2D
	return _basketball_normal_texture


func _get_basketball_berserk_texture() -> Texture2D:
	if _basketball_berserk_texture == null:
		_basketball_berserk_texture = load(BASKETBALL_BERSERK_PATH) as Texture2D
	return _basketball_berserk_texture


func _get_man_bullet_normal_texture() -> Texture2D:
	if _man_bullet_normal_texture == null:
		_man_bullet_normal_texture = load(MAN_BULLET_NORMAL_PATH) as Texture2D
	return _man_bullet_normal_texture


func _get_man_bullet_berserk_texture() -> Texture2D:
	if _man_bullet_berserk_texture == null:
		_man_bullet_berserk_texture = load(MAN_BULLET_BERSERK_PATH) as Texture2D
	return _man_bullet_berserk_texture
