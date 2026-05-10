extends Area2D

## 追击投射物：先在脚下警戒，敌人进入范围且没有墙体阻挡后冲锋。

const VS := preload("res://scripts/visual_spec.gd")

const WALL_MASK := 16
const HIT_RADIUS := 10.0

enum RoosterState { WATCHING, CHARGING }

var _damage := 8
var _speed := 280.0
var _lifetime := 4.0
var _monitor_range := 180.0
var _age := 0.0
var _velocity := Vector2.ZERO
var _facing := Vector2.RIGHT
var _target: Area2D = null
var _berserk := false
var _state := RoosterState.WATCHING


func setup(pos: Vector2, dir: Vector2, damage: int, speed: float, lifetime: float,
		monitor_range: float, berserk: bool) -> void:
	global_position = pos
	_facing = dir.normalized() if dir.length_squared() > 0.01 else Vector2.RIGHT
	_damage = damage
	_speed = speed
	_lifetime = lifetime
	_monitor_range = monitor_range
	_berserk = berserk
	rotation = _facing.angle()


func _ready() -> void:
	collision_layer = 4
	collision_mask = 2
	monitorable = false
	monitoring = true

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = HIT_RADIUS
	shape.shape = circle
	add_child(shape)

	area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
	if GameManager.state != GameManager.GameState.PLAYING and GameManager.state != GameManager.GameState.LOBBY:
		return

	_age += delta
	if _age >= _lifetime:
		queue_free()
		return

	match _state:
		RoosterState.WATCHING:
			_target = _find_target_in_monitor_range()
			if _is_valid_target(_target):
				_start_charge(_target)
		RoosterState.CHARGING:
			_update_charge(delta)

	queue_redraw()


func _start_charge(target: Area2D) -> void:
	_state = RoosterState.CHARGING
	_target = target
	var to_target := target.global_position - global_position
	if to_target.length_squared() > 0.01:
		_facing = to_target.normalized()
	_velocity = _facing * _speed


func _update_charge(delta: float) -> void:
	if not _is_valid_target(_target):
		_target = _find_target_in_monitor_range()
		if not _is_valid_target(_target):
			_state = RoosterState.WATCHING
			_velocity = Vector2.ZERO
			return

	var to_target := _target.global_position - global_position
	if to_target.length_squared() > 0.01:
		var desired := to_target.normalized() * _speed
		_velocity = _velocity.lerp(desired, clampf(delta * 10.0, 0.0, 1.0))

	var old_pos := global_position
	var new_pos := old_pos + _velocity * delta
	var wall_hit := _intersect_wall(old_pos, new_pos)
	if wall_hit:
		queue_free()
		return

	global_position = new_pos
	if _velocity.length_squared() > 0.01:
		rotation = _velocity.angle()
		_facing = _velocity.normalized()


func _find_target_in_monitor_range() -> Area2D:
	var nearest: Area2D = null
	var nearest_dist := INF
	var max_dist_sq := _monitor_range * _monitor_range
	for node in get_tree().get_nodes_in_group("enemy"):
		if not _is_valid_target(node):
			continue
		var dist := global_position.distance_squared_to(node.global_position)
		if dist <= max_dist_sq and dist < nearest_dist and _has_clear_path_to(node):
			nearest_dist = dist
			nearest = node
	return nearest


func _is_valid_target(node: Node) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	if not node.has_method("take_damage"):
		return false
	if "_dying" in node and node._dying:
		return false
	return true


func _has_clear_path_to(node: Node2D) -> bool:
	return not _intersect_wall(global_position, node.global_position)


func _intersect_wall(from: Vector2, to: Vector2) -> bool:
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(from, to, WALL_MASK)
	query.collide_with_areas = false
	return not space.intersect_ray(query).is_empty()


func _on_area_entered(area: Area2D) -> void:
	if not _is_valid_target(area):
		return
	var was_dying: bool = "_dying" in area and area._dying
	area.take_damage(_damage)
	if not was_dying and "hp" in area and area.hp <= 0:
		GameManager.add_kill()

	var scene := get_tree().current_scene
	if scene != null and scene.has_method("spawn_damage_number"):
		var color := Color(1.0, 0.25, 0.08) if _berserk else Color(1.0, 0.75, 0.2)
		scene.spawn_damage_number(area.global_position, _damage, color, 14)

	queue_free()


func _draw() -> void:
	var body := Color(1.0, 0.85, 0.2) if _berserk else Color(0.9, 0.45, 0.15)
	var comb := Color(1.0, 0.05, 0.05)
	var wing := Color(0.85, 0.75, 0.55)

	if _state == RoosterState.WATCHING:
		draw_arc(Vector2.ZERO, _monitor_range, 0, TAU, 64, Color(1.0, 0.75, 0.2, 0.12), 1.0)
	draw_circle(Vector2.ZERO, 8.0, body)
	draw_circle(Vector2(6.0, -3.0), 5.0, body.lightened(0.2))
	draw_circle(Vector2(9.0, -7.0), 2.5, comb)
	draw_line(Vector2(-2.0, 0.0), Vector2(-10.0, -6.0), wing, 3.0)
	draw_line(Vector2(-2.0, 2.0), Vector2(-10.0, 6.0), wing, 3.0)
	draw_circle(Vector2(8.0, -4.0), 1.2, Color.BLACK)
	if _berserk:
		draw_arc(Vector2.ZERO, 12.0, 0, TAU, 20, Color(1.0, 0.25, 0.08, 0.7), 1.5)
