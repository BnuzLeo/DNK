extends Node2D

signal impact(pos: Vector2, damage: int, is_kill: bool, is_boss: bool, projectile_type: String)

const BASKETBALL_BERSERK_PATH := "res://assets/export/weapon/weapon_01/狂暴模式.png"
const PROJECTILE_TYPE := "basketball_berserk"
const WARNING_DURATION := 0.42
const FALL_DURATION := 0.48
const FALL_START_OFFSET := Vector2(-780.0, -780.0)
const IMPACT_RADIUS := 34.0
const BALL_DISPLAY_SIZE := 56.0

var _target: Area2D = null
var _target_position := Vector2.ZERO
var _damage := 0
var _timer := 0.0
var _impact_done := false
var _texture: Texture2D = null


func setup(target: Area2D, target_position: Vector2, damage: int) -> void:
	_target = target if is_instance_valid(target) else null
	_target_position = target_position
	_damage = damage
	global_position = _target_position
	z_index = 97
	_texture = load(BASKETBALL_BERSERK_PATH) as Texture2D
	queue_redraw()


func _process(delta: float) -> void:
	_timer += delta
	if _target != null and is_instance_valid(_target):
		if "_dying" not in _target or not _target._dying:
			_target_position = _target.global_position
			global_position = _target_position
	queue_redraw()
	if not _impact_done and _timer >= WARNING_DURATION + FALL_DURATION:
		_do_impact()
		return
	if _impact_done and _timer >= WARNING_DURATION + FALL_DURATION + 0.05:
		queue_free()


func _do_impact() -> void:
	_impact_done = true
	var damage_target := _resolve_damage_target()
	var is_kill := false
	var is_boss := false
	if damage_target != null:
		var was_dying: bool = "_dying" in damage_target and damage_target._dying
		var old_hp: int = damage_target.hp if "hp" in damage_target else 1
		is_boss = damage_target.max_hp > 50 if "max_hp" in damage_target else false
		damage_target.take_damage(_damage)
		if damage_target.has_method("apply_hit_feedback"):
			damage_target.call("apply_hit_feedback", Vector2.DOWN, 7.0, PROJECTILE_TYPE)
		is_kill = not was_dying and old_hp > 0 and "hp" in damage_target and damage_target.hp <= 0
		if is_kill:
			GameManager.add_kill()
	impact.emit(global_position, _damage, is_kill, is_boss, PROJECTILE_TYPE)


func _resolve_damage_target() -> Area2D:
	if _target != null and is_instance_valid(_target):
		if "_dying" not in _target or not _target._dying:
			return _target
	var best: Area2D = null
	var best_dist := IMPACT_RADIUS * IMPACT_RADIUS
	for enemy in get_tree().get_nodes_in_group("enemy"):
		var enemy_area := enemy as Area2D
		if enemy_area == null or not is_instance_valid(enemy_area):
			continue
		if not enemy_area.has_method("take_damage"):
			continue
		if "_dying" in enemy_area and enemy_area._dying:
			continue
		var dist := global_position.distance_squared_to(enemy_area.global_position)
		if dist <= best_dist:
			best_dist = dist
			best = enemy_area
	return best


func _draw() -> void:
	if _impact_done:
		return
	var center := Vector2.ZERO
	var warning_progress := clampf(_timer / WARNING_DURATION, 0.0, 1.0)
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.028)
	var warning_radius := lerpf(16.0, IMPACT_RADIUS, warning_progress)
	draw_circle(center, warning_radius, Color(1.0, 0.24, 0.06, 0.10 + 0.06 * pulse))
	draw_arc(center, warning_radius, 0.0, TAU, 40, Color(1.0, 0.36, 0.08, 0.72), 2.4)
	draw_arc(center, warning_radius * 0.55, 0.0, TAU, 32, Color(1.0, 0.86, 0.22, 0.54), 1.4)
	draw_line(Vector2(-warning_radius, 0.0), Vector2(warning_radius, 0.0), Color(1.0, 0.62, 0.16, 0.42), 1.2)
	draw_line(Vector2(0.0, -warning_radius), Vector2(0.0, warning_radius), Color(1.0, 0.62, 0.16, 0.42), 1.2)
	if _timer < WARNING_DURATION:
		return

	var fall_t := clampf((_timer - WARNING_DURATION) / FALL_DURATION, 0.0, 1.0)
	var eased := fall_t * fall_t * fall_t
	var ball_center := FALL_START_OFFSET.lerp(Vector2.ZERO, eased)
	var path_dir := (-FALL_START_OFFSET).normalized()
	var path_normal := Vector2(-path_dir.y, path_dir.x)
	var trail_start := ball_center - path_dir * lerpf(150.0, 56.0, fall_t)
	var pulse_alpha := 0.18 + 0.38 * fall_t
	draw_circle(Vector2(0.0, 8.0), lerpf(8.0, 18.0, fall_t), Color(0.0, 0.0, 0.0, 0.18 + fall_t * 0.20))
	draw_line(trail_start, ball_center, Color(1.0, 0.33, 0.06, pulse_alpha), 7.0)
	draw_line(trail_start + path_normal * 8.0, ball_center + path_normal * 3.0, Color(1.0, 0.88, 0.30, pulse_alpha * 0.72), 2.6)
	draw_line(trail_start - path_normal * 8.0, ball_center - path_normal * 3.0, Color(1.0, 0.62, 0.12, pulse_alpha * 0.52), 2.0)
	for i in 4:
		var after_t := clampf(fall_t - float(i + 1) * 0.055, 0.0, 1.0)
		if after_t <= 0.0:
			continue
		var after_eased := after_t * after_t * after_t
		var after_center := FALL_START_OFFSET.lerp(Vector2.ZERO, after_eased)
		var after_size := BALL_DISPLAY_SIZE * (0.82 - float(i) * 0.12)
		var after_alpha := 0.20 - float(i) * 0.035
		draw_circle(after_center, after_size * 0.36, Color(1.0, 0.30, 0.06, after_alpha))
	for i in 3:
		var ring_center := ball_center - path_dir * (24.0 + float(i) * 22.0)
		var ring_radius := 9.0 + float(i) * 5.0 + 8.0 * (1.0 - fall_t)
		draw_arc(ring_center, ring_radius, 0.0, TAU, 24, Color(1.0, 0.66, 0.12, (0.30 - float(i) * 0.07) * fall_t), 1.8)
	if _texture != null:
		var size := Vector2(BALL_DISPLAY_SIZE, BALL_DISPLAY_SIZE)
		draw_texture_rect(_texture, Rect2(ball_center - size * 0.5, size), false)
	else:
		draw_circle(ball_center, BALL_DISPLAY_SIZE * 0.5, Color(1.0, 0.36, 0.08))
