extends Area2D

## 敌人 AI — 支持 CHASER / SHOOTER / TANK / SWARM 四种类型

const VS := preload("res://scripts/visual_spec.gd")

signal died

enum EnemyType { CHASER, SHOOTER, TANK, SWARM }

const TYPE_STATS := {
	EnemyType.CHASER:  {"speed": 100.0, "hp": 20, "damage": 1,  "color": Color(1.0, 0.0, 1.0)},
	EnemyType.SHOOTER: {"speed": 80.0,  "hp": 30, "damage": 5,  "color": Color(1.0, 0.6, 0.0)},
	EnemyType.TANK:    {"speed": 50.0,  "hp": 80, "damage": 1,  "color": Color(0.5, 0.5, 0.5)},
	EnemyType.SWARM:   {"speed": 120.0, "hp": 10, "damage": 1,  "color": Color(0.0, 1.0, 0.5)},
}

const CONTACT_COOLDOWN := 1.0
const SHOOT_COOLDOWN_MIN := 1.5
const SHOOT_COOLDOWN_MAX := 2.0
const SHOOT_TELL_TIME := 0.3
const SHOOT_BULLET_SPEED := 300.0
const KEEP_DISTANCE_MIN := 150.0
const KEEP_DISTANCE_MAX := 200.0

const TYPE_ANIMATIONS := {}

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
var _current_animation := ""
var _moving_this_frame := false
var _hit_timer := 0.0

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

	if _flash_timer <= 0.0 and not _shooting:
		_apply_idle_modulate()

	_update_animation()
	queue_redraw()


func _update_movement(delta: float) -> void:
	var start_position := global_position
	var dir := (_player.global_position - global_position).normalized()
	var speed: float = TYPE_STATS[enemy_type].speed * _slow_factor
	_face_direction(dir)

	match enemy_type:
		EnemyType.CHASER:
			global_position += dir * speed * delta

		EnemyType.SHOOTER:
			var dist := global_position.distance_to(_player.global_position)
			if dist < KEEP_DISTANCE_MIN:
				global_position -= dir * speed * delta  # 后退
			elif dist > KEEP_DISTANCE_MAX:
				global_position += dir * speed * delta  # 前进
			# 在范围内不动

		EnemyType.TANK:
			global_position += dir * speed * delta

		EnemyType.SWARM:
			# 群体追踪 + 随机偏移避免重叠
			var offset := Vector2(randf_range(-0.3, 0.3), randf_range(-0.3, 0.3))
			global_position += (dir + offset) * speed * delta
	_moving_this_frame = global_position.distance_squared_to(start_position) > 0.01


func _update_shooting(delta: float) -> void:
	if _shooting:
		_shoot_tell_timer -= delta
		if _shoot_tell_timer <= 0.0:
			_fire_at_player()
			_shooting = false
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


func _fire_at_player() -> void:
	if bullet_pool == null or _player == null:
		return
	var dir := (_player.global_position - global_position).normalized()
	bullet_pool.spawn(
		global_position + dir * (VS.ENEMY_STANDARD_DISPLAY_SIZE * 0.5),
		dir,
		SHOOT_BULLET_SPEED,
		TYPE_STATS[EnemyType.SHOOTER].damage,
		false
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
	if _shooting and _has_animation("tell"):
		_set_animation("tell")
	elif _hit_timer > 0.0 and _has_animation("hit"):
		_set_animation("hit")
	elif _moving_this_frame and _has_animation("move"):
		_set_animation("move")
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
	_set_animation("idle", true)
	_apply_idle_modulate()


func _build_sprite_frames(config: Dictionary) -> SpriteFrames:
	var sprite_frames := SpriteFrames.new()
	sprite_frames.remove_animation("default")
	var frame_size := int(config.get("frame_size", 64))
	var animations: Dictionary = config.get("animations", {})
	for animation_name in animations.keys():
		var animation: Dictionary = animations[animation_name]
		var texture := _load_texture(animation.get("path", ""))
		if texture == null:
			continue
		sprite_frames.add_animation(animation_name)
		sprite_frames.set_animation_speed(animation_name, float(animation.get("fps", 8.0)))
		sprite_frames.set_animation_loop(animation_name, bool(animation.get("loop", true)))
		var frame_count := int(animation.get("frames", 1))
		for frame_index in frame_count:
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(frame_index * frame_size, 0, frame_size, frame_size)
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
	match enemy_type:
		EnemyType.SWARM:
			return VS.ENEMY_SWARM_DISPLAY_SIZE
		EnemyType.TANK:
			return VS.ENEMY_TANK_DISPLAY_SIZE
	return VS.ENEMY_STANDARD_DISPLAY_SIZE


func _face_direction(dir: Vector2) -> void:
	if _sprite != null and dir.length_squared() > 0.001:
		_sprite.rotation = dir.angle()


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
	if _has_animation("dead"):
		modulate = _get_base_modulate()
		_set_animation("dead", true)
		var tween := create_tween()
		tween.tween_interval(_get_animation_duration("dead"))
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
		var stats: Dictionary = TYPE_STATS[enemy_type]
		body.take_damage(stats.damage)
		_contact_cooldown = CONTACT_COOLDOWN


func _on_area_entered(_area: Area2D) -> void:
	pass


func _draw() -> void:
	var radius := VS.ENEMY_STANDARD_DISPLAY_SIZE * 0.5
	match enemy_type:
		EnemyType.SWARM:
			radius = VS.ENEMY_SWARM_DISPLAY_SIZE * 0.5
		EnemyType.TANK:
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
	# 射击 "告诉" 指示器
	if _shooting:
		var tell_ratio := _shoot_tell_timer / SHOOT_TELL_TIME
		draw_arc(Vector2.ZERO, radius + 5.0, 0, TAU * tell_ratio, 16, Color(1.0, 0.3, 0.3, 0.8), 2.0)
