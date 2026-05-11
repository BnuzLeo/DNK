extends Node2D

const POOL_SIZE_PLAYER := 150
const POOL_SIZE_ENEMY := 260
const BULLET_LIFETIME := 2.0

var _player_bullets: Array[Area2D] = []
var _enemy_bullets: Array[Area2D] = []
var _active_player := 0
var _active_enemy := 0

signal hit_occurred(pos: Vector2, damage: int, is_kill: bool, is_boss: bool)


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
		_:
			circle.radius = 4.0


func _recycle_bullet(bullet: Area2D, is_player: bool) -> void:
	bullet.set_meta("active", false)
	bullet.visible = false
	bullet.monitoring = false
	bullet.set_meta("boss_split_on_hit", false)
	bullet.set_meta("boss_has_split", false)
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
			area.take_damage(damage)
			var is_kill: bool = not was_dying and area.hp <= 0
			var is_boss: bool = area.max_hp > 50
			hit_occurred.emit(bullet.global_position, damage, is_kill, is_boss)
			if is_kill:
				GameManager.add_kill()
		# 飞镖命中后不回收，继续返回
		if not is_dart:
			_recycle_bullet(bullet, true)
	else:
		_handle_boss_big_snowball_split(bullet, bullet.global_position)
		_recycle_bullet(bullet, false)


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
