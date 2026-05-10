extends Area2D

## 敌人 AI — 支持 CHASER / SHOOTER / TANK 三种类型

const VS := preload("res://scripts/visual_spec.gd")
const CHASER_WEAPON_TEXTURE := preload("res://assets/export/enemies/chaser/电能矿工电棍.png")
const TANK_WEAPON_TEXTURE := preload("res://assets/export/enemies/tank/矿工电钻.png")

signal died

enum EnemyType { CHASER, SHOOTER, TANK }
enum TankState { CHASE, AIM, CHARGE, RECOVER }

const TYPE_STATS := {
	EnemyType.CHASER:  {"speed": 100.0, "hp": 20, "damage": 2,  "color": Color(1.0, 0.0, 1.0)},
	EnemyType.SHOOTER: {"speed": 80.0,  "hp": 30, "damage": 5,  "color": Color(1.0, 0.6, 0.0)},
	EnemyType.TANK:    {"speed": 58.0,  "hp": 80, "damage": 8,  "color": Color(0.5, 0.5, 0.5)},
}

const CONTACT_COOLDOWN := 1.0
const CHASER_ATTACK_RANGE := 46.0
const CHASER_ATTACK_TIME := 0.34
const CHASER_ATTACK_HIT_TIME := 0.18
const CHASER_ATTACK_COOLDOWN := 0.8
const SHOOT_COOLDOWN_MIN := 1.5
const SHOOT_COOLDOWN_MAX := 2.0
const SHOOT_TELL_TIME := 0.3
const SHOOT_BULLET_SPEED := 300.0
const KEEP_DISTANCE_MIN := 150.0
const KEEP_DISTANCE_MAX := 200.0
const TANK_AIM_RANGE := 300.0
const TANK_AIM_TIME := 0.7
const TANK_CHARGE_TIME := 0.48
const TANK_CHARGE_SPEED := 520.0
const TANK_RECOVER_TIME := 0.35
const TANK_CHARGE_COOLDOWN := 2.2
const TANK_AFTERIMAGE_INTERVAL := 0.045

const TYPE_ANIMATIONS := {
	EnemyType.CHASER: {
		"frame_size": 120,
		"animations": {
			"idle": {"path": "res://assets/export/enemies/chaser/electric_miner_idle_strip2.png", "frames": 2, "fps": 4.0, "loop": true},
			"walk": {"path": "res://assets/export/enemies/chaser/electric_miner_walk_strip4.png", "frames": 4, "fps": 8.0, "loop": true},
			"shoot": {"paths": [
				"res://assets/export/enemies/chaser/attack/01.png",
				"res://assets/export/enemies/chaser/attack/02.png",
				"res://assets/export/enemies/chaser/attack/03.png",
				"res://assets/export/enemies/chaser/attack/04.png"
			], "fps": 16.0, "loop": false},
			"death": {"path": "res://assets/export/enemies/chaser/电能矿工死亡.png", "frames": 1, "fps": 1.0, "loop": false},
		},
	},
	EnemyType.SHOOTER: {
		"frame_size": 120,
		"animations": {
			"idle": {"path": "res://assets/export/enemies/shooter/enemy_shooter_snow_ape_idle_strip8.png", "frames": 8, "fps": 8.0, "loop": true},
			"walk": {"path": "res://assets/export/enemies/shooter/enemy_shooter_snow_ape_walk_strip8.png", "frames": 8, "fps": 8.0, "loop": true},
			"shoot": {"path": "res://assets/export/enemies/shooter/enemy_shooter_snow_ape_shoot_strip8.png", "frames": 8, "fps": 18.0, "loop": false},
			"death": {"path": "res://assets/export/enemies/shooter/enemy_shooter_snow_ape_death_strip1.png", "frames": 1, "fps": 1.0, "loop": false},
		},
	},
	EnemyType.TANK: {
		"frame_size": 120,
		"animations": {
			"idle": {"path": "res://assets/export/enemies/tank/christmas_miner_idle_strip2.png", "frames": 2, "fps": 4.0, "loop": true},
			"walk": {"path": "res://assets/export/enemies/tank/christmas_miner_walk_strip4.png", "frames": 4, "fps": 8.0, "loop": true},
			"death": {"path": "res://assets/export/enemies/tank/矿工圣诞节死亡.png", "frames": 1, "fps": 1.0, "loop": false},
		},
	},
}

var enemy_type: int = EnemyType.CHASER
var max_hp := 20
var hp := 20
var max_armor := 0
var armor := 0
var room_bounds := Rect2()
var bullet_pool: Node2D  # 由 main.gd 传入

var _flash_timer := 0.0
var _player: CharacterBody2D
var _contact_cooldown := 0.0
var _dying := false
var _spawn_invuln_timer := 0.0
var _sprite: AnimatedSprite2D = null
var _weapon_sprite: Sprite2D = null
var _archer_facing := 1.0
var _current_animation := ""
var _moving_this_frame := false
var _hit_timer := 0.0
var _sprite_action_timer := 0.0
var _melee_attack_timer := 0.0
var _melee_attack_hit_done := false
var _melee_attack_cooldown := 0.0
var _tank_state: int = TankState.CHASE
var _tank_state_timer := 0.0
var _tank_charge_cooldown := 0.0
var _tank_charge_dir := Vector2.RIGHT
var _tank_afterimage_timer := 0.0

# 射击
var _shoot_timer := 0.0
var _shoot_tell_timer := 0.0
var _shooting := false

# 冰冻/减速
var _slow_factor := 1.0
var _slow_timer := 0.0
var _freeze_stacks := 0.0
var _frozen := false
var _freeze_timer := 0.0


func _ready() -> void:
	collision_layer = 2
	collision_mask = 5
	add_to_group("enemy")
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

	_spawn_invuln_timer = 0.5
	_shoot_timer = randf_range(SHOOT_COOLDOWN_MIN, SHOOT_COOLDOWN_MAX)
	_setup_sprite()


func setup(player: CharacterBody2D, type: int = EnemyType.CHASER, pool: Node2D = null) -> void:
	_player = player
	if not TYPE_STATS.has(type):
		type = EnemyType.CHASER
	enemy_type = type
	bullet_pool = pool
	var stats: Dictionary = TYPE_STATS[type]
	max_hp = stats.hp
	hp = stats.hp
	max_armor = int(stats.get("armor", 0))
	armor = max_armor
	if is_inside_tree():
		_setup_sprite()


func _physics_process(delta: float) -> void:
	if GameManager.state != GameManager.GameState.PLAYING:
		return
	if _player == null or _dying:
		return

	# 生成无敌
	if _spawn_invuln_timer > 0.0:
		_spawn_invuln_timer -= delta

	if _hit_timer > 0.0:
		_hit_timer -= delta
	if _sprite_action_timer > 0.0:
		_sprite_action_timer -= delta
	if _melee_attack_cooldown > 0.0:
		_melee_attack_cooldown -= delta
	if _melee_attack_timer > 0.0:
		_update_melee_attack(delta)
	if _tank_charge_cooldown > 0.0:
		_tank_charge_cooldown -= delta

	# 减速计时
	if _slow_timer > 0.0:
		_slow_timer -= delta
		if _slow_timer <= 0.0:
			_slow_factor = 1.0

	# 冰冻计时
	if _frozen:
		_freeze_timer -= delta
		if _freeze_timer <= 0.0:
			_frozen = false
			_freeze_stacks = 0
			_apply_idle_modulate()

	# 冰冻状态不移动/射击
	if _frozen:
		_apply_idle_modulate()
		_set_animation("idle")
		_update_weapon_visual()
		queue_redraw()
		return

	# 射击 "告诉" + 射击
	if enemy_type == EnemyType.SHOOTER:
		_update_shooting(delta)

	# 移动
	_update_movement(delta)

	# 边界限制
	if room_bounds.size != Vector2.ZERO:
		global_position.x = clampf(global_position.x, room_bounds.position.x, room_bounds.end.x)
		global_position.y = clampf(global_position.y, room_bounds.position.y, room_bounds.end.y)

	# 接触伤害冷却
	_contact_cooldown -= delta

	# 闪白恢复
	if _flash_timer > 0.0:
		_flash_timer -= delta
		if _flash_timer <= 0.0:
			_apply_idle_modulate()

	if _flash_timer <= 0.0 and not _shooting and not (enemy_type == EnemyType.TANK and _tank_state == TankState.AIM):
		_apply_idle_modulate()

	_update_animation()
	_update_weapon_visual()
	queue_redraw()


func _update_melee_attack(delta: float) -> void:
	_melee_attack_timer -= delta
	if not _melee_attack_hit_done and _melee_attack_timer <= CHASER_ATTACK_TIME - CHASER_ATTACK_HIT_TIME:
		_melee_attack_hit_done = true
		if _player != null and global_position.distance_to(_player.global_position) <= CHASER_ATTACK_RANGE + 18.0:
			_player.take_damage(TYPE_STATS[EnemyType.CHASER].damage)
	if _melee_attack_timer <= 0.0:
		_melee_attack_timer = 0.0


func _start_melee_attack() -> void:
	_melee_attack_timer = CHASER_ATTACK_TIME
	_melee_attack_hit_done = false
	_melee_attack_cooldown = CHASER_ATTACK_COOLDOWN
	_sprite_action_timer = CHASER_ATTACK_TIME
	if _has_animation("shoot"):
		_set_animation("shoot", true)


func _update_movement(delta: float) -> void:
	var start_position := global_position
	var dir := (_player.global_position - global_position).normalized()
	var speed: float = TYPE_STATS[enemy_type].speed * _slow_factor
	_face_direction(dir)

	match enemy_type:
		EnemyType.CHASER:
			var dist := global_position.distance_to(_player.global_position)
			if _melee_attack_timer > 0.0:
				pass
			elif dist <= CHASER_ATTACK_RANGE and _melee_attack_cooldown <= 0.0:
				_start_melee_attack()
			else:
				global_position += dir * speed * delta

		EnemyType.SHOOTER:
			var dist := global_position.distance_to(_player.global_position)
			if dist < KEEP_DISTANCE_MIN:
				global_position -= dir * speed * delta  # 后退
			elif dist > KEEP_DISTANCE_MAX:
				global_position += dir * speed * delta  # 前进
			# 在范围内不动

		EnemyType.TANK:
			_update_tank_behavior(delta, dir, speed)
	_moving_this_frame = global_position.distance_squared_to(start_position) > 0.01


func _update_tank_behavior(delta: float, dir: Vector2, speed: float) -> void:
	match _tank_state:
		TankState.CHASE:
			if global_position.distance_to(_player.global_position) <= TANK_AIM_RANGE and _tank_charge_cooldown <= 0.0:
				_tank_state = TankState.AIM
				_tank_state_timer = TANK_AIM_TIME
				_tank_charge_dir = dir
				_sprite_action_timer = TANK_AIM_TIME
			else:
				global_position += dir * speed * delta

		TankState.AIM:
			_tank_state_timer -= delta
			_tank_charge_dir = (_player.global_position - global_position).normalized()
			_face_direction(_tank_charge_dir)
			var flash := sin(_tank_state_timer * 34.0) * 0.5 + 0.5
			modulate = _get_base_modulate().lerp(Color(1.0, 0.86, 0.35), flash)
			if _tank_state_timer <= 0.0:
				_tank_state = TankState.CHARGE
				_tank_state_timer = TANK_CHARGE_TIME
				_tank_afterimage_timer = 0.0
				_spawn_tank_afterimage()

		TankState.CHARGE:
			_tank_state_timer -= delta
			global_position += _tank_charge_dir * TANK_CHARGE_SPEED * _slow_factor * delta
			_face_direction(_tank_charge_dir)
			_sprite_action_timer = max(_sprite_action_timer, 0.08)
			_tank_afterimage_timer -= delta
			if _tank_afterimage_timer <= 0.0:
				_tank_afterimage_timer = TANK_AFTERIMAGE_INTERVAL
				_spawn_tank_afterimage()
			if _tank_state_timer <= 0.0:
				_tank_state = TankState.RECOVER
				_tank_state_timer = TANK_RECOVER_TIME
				_tank_charge_cooldown = TANK_CHARGE_COOLDOWN

		TankState.RECOVER:
			_tank_state_timer -= delta
			if _tank_state_timer <= 0.0:
				_tank_state = TankState.CHASE


func _update_shooting(delta: float) -> void:
	if _shooting:
		_shoot_tell_timer -= delta
		if _shoot_tell_timer <= 0.0:
			_fire_at_player()
			_shooting = false
			_sprite_action_timer = 0.18
			_shoot_timer = randf_range(SHOOT_COOLDOWN_MIN, SHOOT_COOLDOWN_MAX)
		else:
			# "告诉" 期间闪烁
			var flash := sin(_shoot_tell_timer * 30.0) * 0.5 + 0.5
			modulate = _get_base_modulate().lerp(Color.WHITE * 3.0, flash)
		return

	_shoot_timer -= delta
	if _shoot_timer <= 0.0:
		_shooting = true
		_shoot_tell_timer = SHOOT_TELL_TIME
		_sprite_action_timer = SHOOT_TELL_TIME


func _fire_at_player() -> void:
	if bullet_pool == null or _player == null:
		return
	var dir := (_player.global_position - global_position).normalized()
	bullet_pool.spawn(
		global_position + dir * (_get_display_size() * 0.5),
		dir,
		SHOOT_BULLET_SPEED,
		TYPE_STATS[EnemyType.SHOOTER].damage,
		false,
		false,
		0.0,
		"snowball"
	)


func _get_base_color() -> Color:
	return TYPE_STATS[enemy_type].color


func _get_base_modulate() -> Color:
	return Color.WHITE if _sprite != null else _get_base_color()


func _apply_idle_modulate() -> void:
	var color := Color(0.3, 0.7, 1.0) if _frozen else _get_base_modulate()
	if _sprite != null and _spawn_invuln_timer > 0.0:
		color.a = sin(_spawn_invuln_timer * 20.0) * 0.3 + 0.5
	modulate = color


func _update_animation() -> void:
	if _sprite == null:
		return
	if _dying:
		_set_animation("death")
	elif enemy_type == EnemyType.TANK and _tank_state == TankState.CHARGE and _has_animation("walk"):
		_set_animation("walk")
	elif (_shooting or _sprite_action_timer > 0.0) and _has_animation("shoot"):
		_set_animation("shoot")
	elif _hit_timer > 0.0 and _has_animation("hit"):
		_set_animation("hit")
	elif _moving_this_frame and _has_animation("walk"):
		_set_animation("walk")
	else:
		_set_animation("idle")


func _setup_sprite() -> void:
	var config: Dictionary = TYPE_ANIMATIONS.get(enemy_type, {})
	if config.is_empty():
		if _sprite != null:
			_sprite.queue_free()
			_sprite = null
		return
	var frames := _build_sprite_frames(config)
	if frames == null:
		return
	if _sprite == null:
		_sprite = AnimatedSprite2D.new()
		_sprite.centered = true
		_sprite.z_index = 2
		add_child(_sprite)
	_sprite.sprite_frames = frames
	_current_animation = ""
	var display_size := _get_display_size()
	var frame_size := float(config.get("frame_size", 64))
	if frame_size > 0.0:
		var scale_factor: float = display_size / frame_size
		_sprite.scale = Vector2(scale_factor, scale_factor)
	_setup_weapon_sprite()
	_set_animation("idle", true)
	_apply_idle_modulate()
	_update_weapon_visual()


func _setup_weapon_sprite() -> void:
	var texture: Texture2D = null
	match enemy_type:
		EnemyType.CHASER:
			texture = CHASER_WEAPON_TEXTURE
		EnemyType.TANK:
			texture = TANK_WEAPON_TEXTURE
		_:
			texture = null
	if texture == null:
		if _weapon_sprite != null:
			_weapon_sprite.queue_free()
			_weapon_sprite = null
		return
	if _weapon_sprite == null:
		_weapon_sprite = Sprite2D.new()
		_weapon_sprite.centered = true
		_weapon_sprite.z_index = 3
		add_child(_weapon_sprite)
	_weapon_sprite.texture = texture


func _update_weapon_visual() -> void:
	if _weapon_sprite == null:
		return
	_weapon_sprite.visible = not _dying and not _frozen
	if not _weapon_sprite.visible:
		return
	var facing := _archer_facing
	_weapon_sprite.flip_h = facing < 0.0
	match enemy_type:
		EnemyType.CHASER:
			var swing := 0.0
			if _melee_attack_timer > 0.0:
				swing = clampf(1.0 - _melee_attack_timer / CHASER_ATTACK_TIME, 0.0, 1.0)
			_weapon_sprite.scale = Vector2(0.36, 0.36)
			_weapon_sprite.position = Vector2(facing * (23.0 + 8.0 * swing), 5.0 - 5.0 * sin(swing * PI))
			_weapon_sprite.rotation = facing * lerpf(-0.62, 0.92, swing)

		EnemyType.TANK:
			var thrust := 0.0
			if _tank_state == TankState.AIM:
				thrust = sin(_tank_state_timer * 32.0) * 0.08
			elif _tank_state == TankState.CHARGE:
				thrust = 0.35
			_weapon_sprite.scale = Vector2(0.58, 0.58)
			_weapon_sprite.position = Vector2(facing * (26.0 + 18.0 * thrust), 4.0)
			_weapon_sprite.rotation = facing * (0.04 * sin(Time.get_ticks_msec() * 0.04) if _tank_state == TankState.CHARGE else 0.0)

		_:
			_weapon_sprite.visible = false


func _spawn_tank_afterimage() -> void:
	if _sprite == null or _sprite.sprite_frames == null:
		return
	var frame_texture := _sprite.sprite_frames.get_frame_texture(_sprite.animation, _sprite.frame)
	if frame_texture == null:
		return
	var parent := get_parent()
	if parent == null:
		return
	var ghost := Sprite2D.new()
	ghost.texture = frame_texture
	ghost.centered = true
	ghost.scale = _sprite.scale
	ghost.flip_h = _sprite.flip_h
	ghost.z_index = _sprite.z_index - 1
	ghost.modulate = Color(0.48, 0.9, 1.0, 0.42)
	parent.add_child(ghost)
	ghost.global_position = global_position
	var tween := ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, 0.22)
	tween.tween_callback(ghost.queue_free)

	if _weapon_sprite != null and _weapon_sprite.visible:
		var weapon_ghost := Sprite2D.new()
		weapon_ghost.texture = _weapon_sprite.texture
		weapon_ghost.centered = true
		weapon_ghost.scale = _weapon_sprite.scale
		weapon_ghost.flip_h = _weapon_sprite.flip_h
		weapon_ghost.rotation = _weapon_sprite.rotation
		weapon_ghost.z_index = _weapon_sprite.z_index - 1
		weapon_ghost.modulate = Color(0.48, 0.9, 1.0, 0.34)
		parent.add_child(weapon_ghost)
		weapon_ghost.global_position = global_position + _weapon_sprite.position
		var weapon_tween := weapon_ghost.create_tween()
		weapon_tween.tween_property(weapon_ghost, "modulate:a", 0.0, 0.22)
		weapon_tween.tween_callback(weapon_ghost.queue_free)


func _build_sprite_frames(config: Dictionary) -> SpriteFrames:
	var sprite_frames := SpriteFrames.new()
	sprite_frames.remove_animation("default")
	var frame_size := int(config.get("frame_size", 64))
	var animations: Dictionary = config.get("animations", {})
	for animation_name in animations.keys():
		var animation: Dictionary = animations[animation_name]
		var animation_frame_size := int(animation.get("frame_size", frame_size))
		var frame_paths: Array = animation.get("paths", [])
		sprite_frames.add_animation(animation_name)
		sprite_frames.set_animation_speed(animation_name, float(animation.get("fps", 8.0)))
		sprite_frames.set_animation_loop(animation_name, bool(animation.get("loop", true)))
		if not frame_paths.is_empty():
			for path in frame_paths:
				var texture := _load_texture(String(path))
				if texture == null:
					continue
				sprite_frames.add_frame(animation_name, texture)
			continue
		var texture := _load_texture(animation.get("path", ""))
		if texture == null:
			continue
		var frame_count := int(animation.get("frames", 1))
		for frame_index in frame_count:
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(frame_index * animation_frame_size, 0, animation_frame_size, animation_frame_size)
			sprite_frames.add_frame(animation_name, atlas)
	if not sprite_frames.has_animation("idle"):
		return null
	return sprite_frames


func _load_texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	var texture := load(path) as Texture2D
	if texture != null:
		return texture
	var image := Image.new()
	if image.load(path) != OK:
		return null
	return ImageTexture.create_from_image(image)


func _get_display_size() -> float:
	return VS.ENEMY_TANK_DISPLAY_SIZE if enemy_type == EnemyType.TANK else VS.ENEMY_STANDARD_DISPLAY_SIZE


func _face_direction(dir: Vector2) -> void:
	if dir.length_squared() <= 0.001:
		return
	if absf(dir.x) > 0.05:
		_archer_facing = 1.0 if dir.x >= 0.0 else -1.0
	if _sprite != null:
		_sprite.rotation = 0.0
		_sprite.flip_h = _archer_facing < 0.0


func _has_animation(animation_name: String) -> bool:
	return _sprite != null and _sprite.sprite_frames != null and _sprite.sprite_frames.has_animation(animation_name)


func _set_animation(animation_name: String, restart: bool = false) -> void:
	if _sprite == null or _sprite.sprite_frames == null:
		return
	var next_animation := animation_name
	if not _sprite.sprite_frames.has_animation(next_animation):
		next_animation = "idle"
	if _current_animation == next_animation and not restart:
		return
	_current_animation = next_animation
	_sprite.play(next_animation)


func _get_animation_duration(animation_name: String) -> float:
	if not _has_animation(animation_name):
		return 0.2
	var frame_count := _sprite.sprite_frames.get_frame_count(animation_name)
	var fps := _sprite.sprite_frames.get_animation_speed(animation_name)
	if fps <= 0.0:
		return 0.2
	return frame_count / fps


func take_damage(amount: int) -> void:
	if _dying or _spawn_invuln_timer > 0.0 or amount <= 0:
		return
	if _frozen:
		amount = int(amount * 1.5)
	var remaining := amount
	if armor > 0:
		var absorbed := mini(armor, remaining)
		armor -= absorbed
		remaining -= absorbed
	if remaining > 0:
		hp -= remaining
	_flash_timer = 0.1
	_hit_timer = 0.16
	modulate = Color.WHITE * 3.0
	if hp <= 0:
		_die()
	elif _has_animation("hit"):
		_set_animation("hit", true)


func apply_slow(factor: float, duration: float) -> void:
	_slow_factor = min(_slow_factor, factor)
	_slow_timer = max(_slow_timer, duration)


func add_freeze_stack(amount: float) -> void:
	_freeze_stacks += amount
	if _freeze_stacks >= 10.0 and not _frozen:
		_frozen = true
		_freeze_timer = 3.0
		_slow_factor = 0.0
		_apply_idle_modulate()


func _die() -> void:
	_dying = true
	died.emit()
	if _has_animation("death"):
		modulate = _get_base_modulate()
		_set_animation("death", true)
		var tween := create_tween()
		tween.tween_interval(_get_animation_duration("death"))
		tween.tween_property(self, "scale", Vector2.ZERO, 0.12).set_ease(Tween.EASE_IN)
		tween.tween_callback(queue_free)
		return
	# 闪烁 3 次 + 缩小消失
	var base_col := _get_base_modulate()
	var tween := create_tween()
	tween.set_parallel(false)
	for i in 3:
		tween.tween_property(self, "modulate", Color.WHITE * 3.0, 0.033)
		tween.tween_property(self, "modulate", base_col, 0.033)
	tween.tween_property(self, "scale", Vector2.ZERO, 0.2).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)


func _on_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage") and _contact_cooldown <= 0.0 and _spawn_invuln_timer <= 0.0:
		if enemy_type == EnemyType.CHASER:
			_start_melee_attack()
			_contact_cooldown = CONTACT_COOLDOWN
			return
		if enemy_type == EnemyType.TANK and _tank_state != TankState.CHARGE:
			return
		var stats: Dictionary = TYPE_STATS[enemy_type]
		body.take_damage(stats.damage)
		if _has_animation("shoot"):
			_sprite_action_timer = 0.22
			_set_animation("shoot", true)
		_contact_cooldown = CONTACT_COOLDOWN


func _on_area_entered(_area: Area2D) -> void:
	pass


func _draw() -> void:
	var radius := VS.ENEMY_STANDARD_DISPLAY_SIZE * 0.5
	if enemy_type == EnemyType.TANK:
		radius = VS.ENEMY_TANK_DISPLAY_SIZE * 0.5
	if _sprite == null:
		var color := Color(0.3, 0.7, 1.0) if _frozen else _get_base_color()
		# 生成无敌闪烁
		if _spawn_invuln_timer > 0.0:
			var flash := sin(_spawn_invuln_timer * 20.0) * 0.3 + 0.5
			color.a = flash
		draw_circle(Vector2.ZERO, radius, color)
		draw_arc(Vector2.ZERO, radius, 0, TAU, 24, Color.WHITE, 1.5)
	if _slow_factor < 1.0 and not _frozen:
		draw_arc(Vector2.ZERO, radius + 3.0, 0, TAU * _slow_factor, 16, Color(0.3, 0.7, 1.0, 0.5), 2.0)
	# 射击读条
	if _shooting:
		var tell_ratio := _shoot_tell_timer / SHOOT_TELL_TIME
		var bar_size := Vector2(40.0, 5.0)
		var bar_pos := Vector2(-bar_size.x * 0.5, -radius - 13.0)
		draw_rect(Rect2(bar_pos, bar_size), Color(0.08, 0.08, 0.08, 0.75), true)
		draw_rect(Rect2(bar_pos, Vector2(bar_size.x * (1.0 - tell_ratio), bar_size.y)), Color(1.0, 0.25, 0.18, 0.95), true)
		draw_rect(Rect2(bar_pos, bar_size), Color(1.0, 0.9, 0.75, 0.9), false, 1.0)
