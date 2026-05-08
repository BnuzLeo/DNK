extends Area2D

## 敌人 AI — 支持 CHASER / SHOOTER / TANK / SWARM 四种类型

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

var enemy_type: int = EnemyType.CHASER
var max_hp := 20
var hp := 20
var room_bounds := Rect2()
var bullet_pool: Node2D  # 由 main.gd 传入

var _flash_timer := 0.0
var _player: CharacterBody2D
var _contact_cooldown := 0.0
var _dying := false

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

	_shoot_timer = randf_range(SHOOT_COOLDOWN_MIN, SHOOT_COOLDOWN_MAX)


func setup(player: CharacterBody2D, type: int = EnemyType.CHASER, pool: Node2D = null) -> void:
	_player = player
	enemy_type = type
	bullet_pool = pool
	var stats: Dictionary = TYPE_STATS[type]
	max_hp = stats.hp
	hp = stats.hp


func _physics_process(delta: float) -> void:
	if GameManager.state != GameManager.GameState.PLAYING:
		return
	if _player == null:
		return

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
			modulate = _get_base_color()

	# 冰冻状态不移动/射击
	if _frozen:
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
			if _frozen:
				modulate = Color(0.3, 0.7, 1.0)
			else:
				modulate = _get_base_color()

	queue_redraw()


func _update_movement(delta: float) -> void:
	var dir := (_player.global_position - global_position).normalized()
	var speed: float = TYPE_STATS[enemy_type].speed * _slow_factor

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
			modulate = _get_base_color().lerp(Color.WHITE * 3.0, flash)
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
		global_position + dir * 12.0,
		dir,
		SHOOT_BULLET_SPEED,
		TYPE_STATS[EnemyType.SHOOTER].damage,
		false
	)


func _get_base_color() -> Color:
	return TYPE_STATS[enemy_type].color


func take_damage(amount: int) -> void:
	if _dying:
		return
	if _frozen:
		amount = int(amount * 1.5)
	hp -= amount
	_flash_timer = 0.1
	modulate = Color.WHITE * 3.0
	if hp <= 0:
		_die()


func apply_slow(factor: float, duration: float) -> void:
	_slow_factor = min(_slow_factor, factor)
	_slow_timer = max(_slow_timer, duration)


func add_freeze_stack(amount: float) -> void:
	_freeze_stacks += amount
	if _freeze_stacks >= 10.0 and not _frozen:
		_frozen = true
		_freeze_timer = 3.0
		_slow_factor = 0.0
		modulate = Color(0.3, 0.7, 1.0)


func _die() -> void:
	_dying = true
	# 闪烁 3 次 + 缩小消失
	var base_col := _get_base_color()
	var tween := create_tween()
	tween.set_parallel(false)
	for i in 3:
		tween.tween_property(self, "modulate", Color.WHITE * 3.0, 0.033)
		tween.tween_property(self, "modulate", base_col, 0.033)
	tween.tween_property(self, "scale", Vector2.ZERO, 0.2).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)


func _on_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage") and _contact_cooldown <= 0.0:
		var stats: Dictionary = TYPE_STATS[enemy_type]
		body.take_damage(stats.damage)
		_contact_cooldown = CONTACT_COOLDOWN


func _on_area_entered(_area: Area2D) -> void:
	pass


func _draw() -> void:
	var radius := 6.0 if enemy_type == EnemyType.SWARM else 8.0
	var color := Color(0.3, 0.7, 1.0) if _frozen else _get_base_color()
	draw_circle(Vector2.ZERO, radius, color)
	draw_arc(Vector2.ZERO, radius, 0, TAU, 24, Color.WHITE, 1.5)
	if _slow_factor < 1.0 and not _frozen:
		draw_arc(Vector2.ZERO, radius + 3.0, 0, TAU * _slow_factor, 16, Color(0.3, 0.7, 1.0, 0.5), 2.0)
	# 射击 "告诉" 指示器
	if _shooting:
		var tell_ratio := _shoot_tell_timer / SHOOT_TELL_TIME
		draw_arc(Vector2.ZERO, radius + 5.0, 0, TAU * tell_ratio, 16, Color(1.0, 0.3, 0.3, 0.8), 2.0)
