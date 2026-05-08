extends Area2D

const SPEED := 80.0
const CONTACT_DAMAGE := 1
const CONTACT_COOLDOWN := 1.0

var max_hp := 20
var hp := 20
var room_bounds := Rect2()
var _flash_timer := 0.0
var _player: CharacterBody2D
var _contact_cooldown := 0.0
var _dying := false

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


func setup(player: CharacterBody2D) -> void:
	_player = player


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
			modulate = Color.WHITE

	# 冰冻状态不移动
	if _frozen:
		queue_redraw()
		return

	# 追击（受减速影响）
	var dir := (_player.global_position - global_position).normalized()
	global_position += dir * SPEED * _slow_factor * delta

	# 边界限制（房间范围内）
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
				modulate = Color.WHITE

	queue_redraw()


func take_damage(amount: int) -> void:
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
	queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage") and _contact_cooldown <= 0.0:
		body.take_damage(CONTACT_DAMAGE)
		_contact_cooldown = CONTACT_COOLDOWN


func _on_area_entered(_area: Area2D) -> void:
	pass


func _draw() -> void:
	var color := Color(0.3, 0.7, 1.0) if _frozen else Color(1.0, 0.0, 1.0)
	draw_circle(Vector2.ZERO, 8.0, color)
	draw_arc(Vector2.ZERO, 8.0, 0, TAU, 24, Color.WHITE, 1.5)
	if _slow_factor < 1.0 and not _frozen:
		draw_arc(Vector2.ZERO, 11.0, 0, TAU * _slow_factor, 16, Color(0.3, 0.7, 1.0, 0.5), 2.0)
