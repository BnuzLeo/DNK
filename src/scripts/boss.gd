extends Area2D

## Boss 战 — 3阶段 + 扇形/环形弹幕 + 冲刺

enum Phase { P1, P2, P3 }
enum AttackType { FAN, RING, DASH }

const MOVE_SPEED := 60.0
const DASH_SPEED := 400.0
const DASH_DISTANCE := 200.0
const DASH_DAMAGE := 20

const FAN_BULLET_SPEED := 250.0
const RING_BULLET_SPEED := 200.0

const PHASE_CONFIGS := {
	Phase.P1: {
		"fan_count": 3, "fan_spread": deg_to_rad(15.0), "fan_interval": 2.0,
		"ring_count": 0, "ring_interval": 0.0,
		"dash_interval": 0.0, "bullet_speed": 250.0, "damage": 8,
	},
	Phase.P2: {
		"fan_count": 5, "fan_spread": deg_to_rad(10.0), "fan_interval": 1.5,
		"ring_count": 8, "ring_interval": 3.0,
		"dash_interval": 4.0, "bullet_speed": 300.0, "damage": 10,
	},
	Phase.P3: {
		"fan_count": 5, "fan_spread": deg_to_rad(8.0), "fan_interval": 1.0,
		"ring_count": 12, "ring_interval": 2.0,
		"dash_interval": 2.5, "bullet_speed": 350.0, "damage": 12,
	},
}

var max_hp := 500
var hp := 500
var room_bounds := Rect2()
var bullet_pool: Node2D

var _player: CharacterBody2D
var _phase: int = Phase.P1
var _dying := false

# 攻击计时器
var _fan_timer := 0.0
var _ring_timer := 0.0
var _dash_timer := 0.0

# 攻击状态
var _attacking := false
var _attack_type: int = AttackType.FAN
var _tell_timer := 0.0
const TELL_DURATION := 0.3

# 冲刺状态
var _dashing := false
var _dash_dir := Vector2.ZERO
var _dash_traveled := 0.0

# 视觉
var _flash_timer := 0.0
var _base_color := Color(1.0, 0.0, 0.3)


func _ready() -> void:
	collision_layer = 2
	collision_mask = 5
	add_to_group("enemy")
	body_entered.connect(_on_body_entered)

	_fan_timer = PHASE_CONFIGS[Phase.P1].fan_interval
	_ring_timer = PHASE_CONFIGS[Phase.P2].ring_interval
	_dash_timer = PHASE_CONFIGS[Phase.P1].dash_interval


func setup(player: CharacterBody2D, pool: Node2D) -> void:
	_player = player
	bullet_pool = pool


func _physics_process(delta: float) -> void:
	if GameManager.state != GameManager.GameState.PLAYING:
		return
	if _player == null or _dying:
		return

	# 阶段切换
	_update_phase()

	var cfg: Dictionary = PHASE_CONFIGS[_phase]

	# 闪白恢复
	if _flash_timer > 0.0:
		_flash_timer -= delta
		if _flash_timer <= 0.0:
			modulate = _base_color

	# 攻击 "告诉"
	if _attacking:
		_tell_timer -= delta
		# "告诉" 视觉
		var flash := sin(_tell_timer * 30.0) * 0.5 + 0.5
		modulate = _base_color.lerp(Color.WHITE * 3.0, flash)
		if _tell_timer <= 0.0:
			_execute_attack()
			_attacking = false
		queue_redraw()
		return

	# 冲刺中
	if _dashing:
		_dash_dir = (_player.global_position - global_position).normalized()
		var move := _dash_dir * DASH_SPEED * delta
		global_position += move
		_dash_traveled += move.length()
		if _dash_traveled >= DASH_DISTANCE:
			_dashing = false
		# 边界
		_clamp_bounds()
		queue_redraw()
		return

	# 缓慢追踪
	var dir := (_player.global_position - global_position).normalized()
	global_position += dir * MOVE_SPEED * delta
	_clamp_bounds()

	# 攻击计时
	_fan_timer -= delta
	if _fan_timer <= 0.0:
		_start_attack(AttackType.FAN)
		_fan_timer = cfg.fan_interval

	if cfg.ring_count > 0:
		_ring_timer -= delta
		if _ring_timer <= 0.0:
			_start_attack(AttackType.RING)
			_ring_timer = cfg.ring_interval

	if cfg.dash_interval > 0.0:
		_dash_timer -= delta
		if _dash_timer <= 0.0:
			_start_attack(AttackType.DASH)
			_dash_timer = cfg.dash_interval

	queue_redraw()


func _update_phase() -> void:
	var ratio := float(hp) / float(max_hp)
	if ratio <= 0.3:
		_phase = Phase.P3
	elif ratio <= 0.6:
		_phase = Phase.P2
	else:
		_phase = Phase.P1


func _start_attack(type: int) -> void:
	_attacking = true
	_attack_type = type
	_tell_timer = TELL_DURATION


func _execute_attack() -> void:
	if bullet_pool == null or _player == null:
		return
	var cfg: Dictionary = PHASE_CONFIGS[_phase]

	match _attack_type:
		AttackType.FAN:
			_fire_fan(cfg.fan_count, cfg.fan_spread, cfg.bullet_speed, cfg.damage)
		AttackType.RING:
			_fire_ring(cfg.ring_count, cfg.bullet_speed, cfg.damage)
		AttackType.DASH:
			_dashing = true
			_dash_dir = (_player.global_position - global_position).normalized()
			_dash_traveled = 0.0


func _fire_fan(count: int, spread: float, speed: float, damage: int) -> void:
	var aim := (_player.global_position - global_position).normalized()
	var aim_angle := aim.angle()
	var start_angle := aim_angle - (count - 1) * spread / 2.0
	for i in count:
		var angle := start_angle + i * spread
		var dir := Vector2(cos(angle), sin(angle))
		bullet_pool.spawn(
			global_position + dir * 16.0,
			dir,
			speed,
			damage,
			false
		)


func _fire_ring(count: int, speed: float, damage: int) -> void:
	for i in count:
		var angle := i * (TAU / count)
		var dir := Vector2(cos(angle), sin(angle))
		bullet_pool.spawn(
			global_position + dir * 16.0,
			dir,
			speed,
			damage,
			false
		)


func _clamp_bounds() -> void:
	if room_bounds.size != Vector2.ZERO:
		global_position.x = clampf(global_position.x, room_bounds.position.x, room_bounds.end.x)
		global_position.y = clampf(global_position.y, room_bounds.position.y, room_bounds.end.y)


func take_damage(amount: int) -> void:
	if _dying:
		return
	hp -= amount
	_flash_timer = 0.1
	modulate = Color.WHITE * 3.0
	if hp <= 0:
		_die()


func _die() -> void:
	_dying = true
	# 爆炸 + 缩小
	var tween := create_tween()
	tween.set_parallel(false)
	for i in 5:
		tween.tween_property(self, "modulate", Color.WHITE * 3.0, 0.05)
		tween.tween_property(self, "modulate", _base_color, 0.05)
	tween.tween_property(self, "scale", Vector2.ZERO, 0.3).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)


func _on_body_entered(body: Node2D) -> void:
	if _dashing and body.has_method("take_damage"):
		body.take_damage(DASH_DAMAGE)


func _draw() -> void:
	# Boss 身体
	var radius := 24.0
	var col := Color(0.3, 0.7, 1.0) if _dashing else _base_color
	draw_circle(Vector2.ZERO, radius, col)
	draw_arc(Vector2.ZERO, radius, 0, TAU, 32, Color.WHITE, 2.0)

	# 眼睛
	var eye_offset := 10.0
	draw_circle(Vector2(-eye_offset, -6.0), 4.0, Color.WHITE)
	draw_circle(Vector2(eye_offset, -6.0), 4.0, Color.WHITE)

	# 阶段指示器
	var hp_ratio := float(hp) / float(max_hp)
	draw_arc(Vector2.ZERO, radius + 4.0, 0, TAU * hp_ratio, 32, Color(1.0, 0.3, 0.3, 0.8), 3.0)

	# 冲刺拖尾
	if _dashing:
		draw_line(Vector2.ZERO, -_dash_dir * 30.0, Color(1.0, 0.3, 0.3, 0.5), 6.0)
