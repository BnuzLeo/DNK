extends Node2D

const BASKETBALL_SLAM_EFFECT := preload("res://scripts/basketball_slam_effect.gd")
const POOL_SIZE_PLAYER := 220
const POOL_SIZE_ENEMY := 260
const BULLET_LIFETIME := 2.0

var _player_bullets: Array[Area2D] = []
var _enemy_bullets: Array[Area2D] = []
var _active_player := 0
var _active_enemy := 0

signal hit_occurred(pos: Vector2, damage: int, is_kill: bool, is_boss: bool, projectile_type: String)


func _ready() -> void:
	for i in POOL_SIZE_PLAYER:
		var bullet := _create_bullet(true)
		bullet.visible = false
		add_child(bullet)
		_player_bullets.append(bullet)
	for i in POOL_SIZE_ENEMY:
		var bullet := _create_bullet(false)
		bullet.visible = false
		add_child(bullet)
		_enemy_bullets.append(bullet)


func _create_bullet(is_player: bool) -> Area2D:
	var bullet := Area2D.new()
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 4.0
	shape.shape = circle
	bullet.add_child(shape)

	if is_player:
		bullet.collision_layer = 4
		bullet.collision_mask = 2
	else:
		bullet.collision_layer = 8
		bullet.collision_mask = 1

	bullet.set_script(load("res://scripts/bullet.gd"))

	# 初始化 meta
	bullet.set_meta("direction", Vector2.ZERO)
	bullet.set_meta("speed", 0.0)
	bullet.set_meta("damage", 0)
	bullet.set_meta("is_player", is_player)
	bullet.set_meta("age", 0.0)
	bullet.set_meta("active", false)
	bullet.set_meta("is_dart", false)
	bullet.set_meta("projectile_type", "")
	bullet.set_meta("max_distance", 0.0)
	bullet.set_meta("traveled", 0.0)
	bullet.set_meta("returning", false)
	bullet.set_meta("boss_split_on_hit", false)
	bullet.set_meta("boss_has_split", false)
	bullet.set_meta("target_enemy", null)
	bullet.set_meta("target_position", Vector2.ZERO)
	bullet.set_meta("visual_lob_height", 0.0)
	bullet.set_meta("visual_lob_progress", 0.0)
	bullet.set_meta("spin_speed", 0.0)
	bullet.set_meta("aoe_radius", 0.0)
	bullet.set_meta("aoe_damage", 0)

	bullet.area_entered.connect(_on_bullet_hit.bind(bullet))
	bullet.body_entered.connect(_on_bullet_body_hit.bind(bullet))
	return bullet


func spawn(pos: Vector2, dir: Vector2, speed: float, damage: int,
		is_player: bool, is_dart: bool = false, max_distance: float = 0.0,
		projectile_type: String = "") -> void:
	var pool := _player_bullets if is_player else _enemy_bullets
	var count := _active_player if is_player else _active_enemy

	if count >= pool.size():
		return

	for bullet in pool:
		if not bullet.get_meta("active", false):
			_activate_bullet(bullet, pos, dir, speed, damage, is_player, is_dart, max_distance, projectile_type)
			if is_player:
				_active_player += 1
			else:
				_active_enemy += 1
			break


func spawn_targeted_basketball(pos: Vector2, target: Area2D, target_position: Vector2,
		speed: float, damage: int, lob_height: float) -> void:
	var pool := _player_bullets
	if _active_player >= pool.size():
		return
	for bullet in pool:
		if bullet.get_meta("active", false):
			continue
		var dir := (target_position - pos).normalized()
		if dir == Vector2.ZERO:
			dir = Vector2.RIGHT
		_activate_bullet(bullet, pos, dir, speed, damage, true, false, 0.0, "basketball_berserk")
		bullet.set_meta("target_enemy", target if is_instance_valid(target) else null)
		bullet.set_meta("target_position", target_position)
		bullet.set_meta("visual_lob_height", lob_height)
		bullet.set_meta("visual_lob_progress", 0.0)
		bullet.set_meta("spin_speed", 16.0)
		_active_player += 1
		break


func spawn_man_bullet(pos: Vector2, dir: Vector2, speed: float, damage: int,
		berserk: bool, aoe_radius: float, aoe_damage: int) -> void:
	var projectile_type := "man_bullet_berserk" if berserk else "man_bullet"
	var pool := _player_bullets
	if _active_player >= pool.size():
		return
	for bullet in pool:
		if bullet.get_meta("active", false):
			continue
		_activate_bullet(bullet, pos, dir.normalized(), speed, damage, true, false, 0.0, projectile_type)
		bullet.set_meta("aoe_radius", aoe_radius)
		bullet.set_meta("aoe_damage", aoe_damage)
		_active_player += 1
		break


func spawn_basketball_slam(target: Area2D, target_position: Vector2, damage: int) -> void:
	var parent := get_tree().current_scene
	if parent == null:
		parent = self
	var slam := BASKETBALL_SLAM_EFFECT.new()
	parent.add_child(slam)
	slam.setup(target, target_position, damage)
	slam.impact.connect(_on_basketball_slam_impact)


func _on_basketball_slam_impact(pos: Vector2, damage: int, is_kill: bool, is_boss: bool, projectile_type: String) -> void:
	hit_occurred.emit(pos, damage, is_kill, is_boss, projectile_type)


func _activate_bullet(bullet: Area2D, pos: Vector2, dir: Vector2, speed: float,
		damage: int, is_player: bool, is_dart: bool, max_distance: float,
		projectile_type: String) -> void:
	bullet.global_position = pos
	bullet.set_meta("direction", dir)
	bullet.set_meta("speed", speed)
	bullet.set_meta("damage", damage)
	bullet.set_meta("is_player", is_player)
	bullet.set_meta("age", 0.0)
	bullet.set_meta("active", true)
	bullet.set_meta("is_dart", is_dart)
	bullet.set_meta("projectile_type", projectile_type)
	bullet.set_meta("max_distance", max_distance)
	bullet.set_meta("traveled", 0.0)
	bullet.set_meta("returning", false)
	bullet.set_meta("boss_split_on_hit", false)
	bullet.set_meta("boss_has_split", false)
	bullet.set_meta("target_enemy", null)
	bullet.set_meta("target_position", Vector2.ZERO)
	bullet.set_meta("visual_lob_height", 0.0)
	bullet.set_meta("visual_lob_progress", 0.0)
	bullet.set_meta("spin_speed", 0.0)
	bullet.set_meta("aoe_radius", 0.0)
	bullet.set_meta("aoe_damage", 0)
	bullet.rotation = dir.angle()
	_apply_projectile_collision_radius(bullet, projectile_type)
	bullet.visible = true
	bullet.monitoring = true
	bullet.monitorable = false
	bullet.queue_redraw()


func _apply_projectile_collision_radius(bullet: Area2D, projectile_type: String) -> void:
	var shape_node := bullet.get_child(0) as CollisionShape2D
	if shape_node == null or not (shape_node.shape is CircleShape2D):
		return
	var circle := shape_node.shape as CircleShape2D
	match projectile_type:
		"boss_big_snowball":
			circle.radius = 11.0
		"boss_small_snowball", "snowball":
			circle.radius = 6.0
		"basketball":
			circle.radius = 7.0
		"basketball_berserk":
			circle.radius = 8.0
		"man_bullet":
			circle.radius = 16.0
		"man_bullet_berserk":
			circle.radius = 20.0
		_:
			circle.radius = 4.0


func _recycle_bullet(bullet: Area2D, is_player: bool) -> void:
	bullet.set_meta("active", false)
	bullet.visible = false
	bullet.monitoring = false
	bullet.set_meta("boss_split_on_hit", false)
	bullet.set_meta("boss_has_split", false)
	bullet.set_meta("target_enemy", null)
	bullet.set_meta("target_position", Vector2.ZERO)
	bullet.set_meta("visual_lob_height", 0.0)
	bullet.set_meta("visual_lob_progress", 0.0)
	bullet.set_meta("spin_speed", 0.0)
	bullet.set_meta("aoe_radius", 0.0)
	bullet.set_meta("aoe_damage", 0)
	if is_player:
		_active_player -= 1
	else:
		_active_enemy -= 1


func _physics_process(delta: float) -> void:
	if GameManager.state != GameManager.GameState.PLAYING and GameManager.state != GameManager.GameState.LOBBY:
		return

	for bullet in _player_bullets:
		if bullet.get_meta("active", false):
			_update_bullet(bullet, delta, true)
	for bullet in _enemy_bullets:
		if bullet.get_meta("active", false):
			_update_bullet(bullet, delta, false)


func _update_bullet(bullet: Area2D, delta: float, is_player: bool) -> void:
	var projectile_type: String = bullet.get_meta("projectile_type", "")
	if is_player and projectile_type == "basketball_berserk":
		_update_basketball_berserk(bullet, delta)
		return
	var dir: Vector2 = bullet.get_meta("direction")
	var speed: float = bullet.get_meta("speed")
	var move_vec: Vector2 = dir * speed * delta
	var old_pos: Vector2 = bullet.global_position
	var new_pos: Vector2 = old_pos + move_vec

	# 子弹撞墙检测（射线查询）
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(old_pos, new_pos, 16)
	query.collide_with_areas = false
	var result := space.intersect_ray(query)
	if result:
		var collider: Object = result.get("collider")
		if not is_player:
			var hit_position: Vector2 = result.get("position", bullet.global_position)
			_handle_boss_big_snowball_split(bullet, hit_position)
		if collider and collider.has_method("take_damage"):
			var damage: int = bullet.get_meta("damage")
			collider.take_damage(damage)
		_recycle_bullet(bullet, is_player)
		return

	bullet.global_position = new_pos
	bullet.queue_redraw()

	var age: float = bullet.get_meta("age") + delta
	bullet.set_meta("age", age)

	# 飞镖回旋逻辑
	if bullet.get_meta("is_dart", false):
		var traveled: float = bullet.get_meta("traveled") + move_vec.length()
		bullet.set_meta("traveled", traveled)
		var max_dist: float = bullet.get_meta("max_distance", 300.0)

		if not bullet.get_meta("returning") and traveled >= max_dist:
			# 开始返回
			bullet.set_meta("returning", true)
			bullet.set_meta("direction", -dir)
			bullet.rotation = (-dir).angle()
		elif bullet.get_meta("returning"):
			# 检查是否回到玩家附近
			var player_nodes := get_tree().get_nodes_in_group("player")
			if player_nodes.size() > 0:
				var player_pos: Vector2 = player_nodes[0].global_position
				if bullet.global_position.distance_to(player_pos) < 20.0:
					_recycle_bullet(bullet, is_player)
					return

	if age >= BULLET_LIFETIME:
		_recycle_bullet(bullet, is_player)
		return

	var pos := bullet.global_position
	var floor_max_x: float = 5 * 960 + 50
	var floor_max_y: float = 5 * 640 + 50
	if pos.x < -50.0 or pos.x > floor_max_x or pos.y < -50.0 or pos.y > floor_max_y:
		_recycle_bullet(bullet, is_player)


func _update_basketball_berserk(bullet: Area2D, delta: float) -> void:
	var speed: float = bullet.get_meta("speed")
	var old_pos: Vector2 = bullet.global_position
	var target_pos: Vector2 = _resolve_basketball_target(bullet)
	var dir: Vector2 = target_pos - old_pos
	if dir.length_squared() < 0.0001:
		dir = bullet.get_meta("direction", Vector2.RIGHT)
	dir = dir.normalized()
	var move_vec: Vector2 = dir * speed * delta
	var new_pos := old_pos + move_vec
	if new_pos.distance_squared_to(old_pos) > old_pos.distance_squared_to(target_pos):
		new_pos = target_pos

	var age: float = bullet.get_meta("age") + delta
	bullet.set_meta("age", age)
	var arc_progress := clampf(bullet.get_meta("visual_lob_progress", 0.0) + delta * 1.8, 0.0, 1.0)
	bullet.set_meta("visual_lob_progress", arc_progress)
	bullet.set_meta("direction", dir)
	bullet.rotation = dir.angle() + age * float(bullet.get_meta("spin_speed", 0.0))
	bullet.global_position = new_pos
	bullet.queue_redraw()

	if age >= BULLET_LIFETIME:
		_recycle_bullet(bullet, true)
		return

	if bullet.global_position.distance_squared_to(target_pos) <= 16.0:
		_recycle_bullet(bullet, true)


func _resolve_basketball_target(bullet: Area2D) -> Vector2:
	var target := bullet.get_meta("target_enemy", null) as Area2D
	if target != null and is_instance_valid(target):
		if "_dying" not in target or not target._dying:
			var pos: Vector2 = target.global_position
			bullet.set_meta("target_position", pos)
			return pos
	var fallback_target := _find_closest_enemy(bullet.global_position)
	if fallback_target != null:
		bullet.set_meta("target_enemy", fallback_target)
		var pos: Vector2 = fallback_target.global_position
		bullet.set_meta("target_position", pos)
		return pos
	return bullet.get_meta("target_position", bullet.global_position + bullet.get_meta("direction", Vector2.RIGHT) * 200.0)


func _find_closest_enemy(origin: Vector2) -> Area2D:
	var best_enemy: Area2D = null
	var best_dist := INF
	for enemy in get_tree().get_nodes_in_group("enemy"):
		var enemy_area := enemy as Area2D
		if enemy_area == null or not is_instance_valid(enemy_area):
			continue
		if not enemy_area.has_method("take_damage"):
			continue
		if "_dying" in enemy_area and enemy_area._dying:
			continue
		var dist := origin.distance_squared_to(enemy_area.global_position)
		if dist < best_dist:
			best_dist = dist
			best_enemy = enemy_area
	return best_enemy


func _on_bullet_body_hit(body: Node2D, bullet: Area2D) -> void:
	var is_player_bullet: bool = bullet.get_meta("is_player")
	var damage: int = bullet.get_meta("damage")

	if is_player_bullet:
		# 玩家子弹击中可破坏障碍物
		if body.has_method("take_damage") and body.has_method("setup"):
			body.take_damage(damage)
			_recycle_bullet(bullet, true)
		return

	# 敌人子弹击中玩家或障碍物
	_handle_boss_big_snowball_split(bullet, bullet.global_position)
	if body.has_method("take_damage"):
		body.take_damage(damage)
	_recycle_bullet(bullet, false)


func _on_bullet_hit(area: Area2D, bullet: Area2D) -> void:
	var is_player: bool = bullet.get_meta("is_player")
	var damage: int = bullet.get_meta("damage")
	var is_dart: bool = bullet.get_meta("is_dart", false)

	if is_player:
		if area.has_method("take_damage"):
			var was_dying: bool = "_dying" in area and area._dying
			var hit_dir: Vector2 = bullet.get_meta("direction", Vector2.RIGHT)
			area.take_damage(damage)
			var is_kill: bool = not was_dying and area.hp <= 0
			var is_boss: bool = area.max_hp > 50
			var projectile_type: String = bullet.get_meta("projectile_type", "")
			var hit_pos: Vector2 = area.global_position
			if area.has_method("apply_hit_feedback"):
				var knock_strength := _get_projectile_hit_strength(projectile_type, is_kill, is_boss)
				area.call("apply_hit_feedback", hit_dir, knock_strength, projectile_type)
			if projectile_type == "man_bullet" or projectile_type == "man_bullet_berserk":
				_apply_man_aoe_damage(hit_pos, area, int(bullet.get_meta("aoe_damage", damage)), float(bullet.get_meta("aoe_radius", 0.0)))
			hit_occurred.emit(hit_pos, damage, is_kill, is_boss, projectile_type)
			if is_kill:
				GameManager.add_kill()
		# 飞镖命中后不回收，继续返回
		if not is_dart:
			_recycle_bullet(bullet, true)
	else:
		_handle_boss_big_snowball_split(bullet, bullet.global_position)
		_recycle_bullet(bullet, false)


func _apply_man_aoe_damage(center: Vector2, primary: Area2D, amount: int, radius: float) -> void:
	if radius <= 0.0 or amount <= 0:
		return
	var radius_sq := radius * radius
	for enemy in get_tree().get_nodes_in_group("enemy"):
		var enemy_area := enemy as Area2D
		if enemy_area == null or enemy_area == primary or not is_instance_valid(enemy_area):
			continue
		if not enemy_area.has_method("take_damage"):
			continue
		if "_dying" in enemy_area and enemy_area._dying:
			continue
		if center.distance_squared_to(enemy_area.global_position) > radius_sq:
			continue
		var was_dying: bool = "_dying" in enemy_area and enemy_area._dying
		enemy_area.take_damage(amount)
		if enemy_area.has_method("apply_hit_feedback"):
			var dir := (enemy_area.global_position - center).normalized()
			if dir == Vector2.ZERO:
				dir = Vector2.RIGHT.rotated(randf() * TAU)
			enemy_area.call("apply_hit_feedback", dir, 8.0, "man_bullet_aoe")
		if not was_dying and "hp" in enemy_area and enemy_area.hp <= 0:
			GameManager.add_kill()


func _get_projectile_hit_strength(projectile_type: String, is_kill: bool, is_boss: bool) -> float:
	var strength := 7.0
	match projectile_type:
		"basketball":
			strength = 11.0
		"basketball_berserk":
			strength = 22.0
		"man_bullet":
			strength = 13.0
		"man_bullet_berserk":
			strength = 18.0
	if is_boss:
		strength *= 0.38
	if is_kill:
		strength *= 1.35
	return strength


func _handle_boss_big_snowball_split(bullet: Area2D, hit_position: Vector2) -> void:
	if not bullet.get_meta("boss_split_on_hit", false) or bullet.get_meta("boss_has_split", false):
		return
	var parent := get_parent()
	if parent == null:
		return
	var boss_node := parent.get_node_or_null("Boss")
	if boss_node == null or not boss_node.has_method("split_big_snowball_at"):
		return
	bullet.set_meta("boss_has_split", true)
	boss_node.call("split_big_snowball_at", hit_position)


func clear_all() -> void:
	for bullet in _player_bullets:
		if bullet.get_meta("active", false):
			_recycle_bullet(bullet, true)
	for bullet in _enemy_bullets:
		if bullet.get_meta("active", false):
			_recycle_bullet(bullet, false)


func get_stats() -> Dictionary:
	return {
		"active_player": _active_player,
		"active_enemy": _active_enemy,
		"total_player": POOL_SIZE_PLAYER,
		"total_enemy": POOL_SIZE_ENEMY,
	}
