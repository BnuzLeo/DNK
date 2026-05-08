extends CharacterBody2D

## 玩家控制器 - 元气骑士风格
## WASD 移动 + J 键射击，射击方向为面朝方向

const SPEED := 180.0
const MAX_HP := 10
const MAX_MANA := 50.0
const MANA_REGEN := 3.0

const WEAPONS := {
	"pistol": {
		"cooldown": 0.18, "damage": 4, "count": 1, "spread": 0.0,
		"speed": 600.0, "mana": 0, "name": "小手枪", "type": "bullet"
	},
	"shotgun": {
		"cooldown": 0.75, "damage": 5, "count": 6, "spread": 0.5,
		"speed": 500.0, "mana": 2, "name": "散弹枪", "type": "bullet"
	},
	"gatling": {
		"cooldown": 0.05, "damage": 2, "count": 1, "spread": 0.0,
		"speed": 700.0, "mana": 1, "name": "加特林", "type": "bullet"
	},
	"freeze": {
		"cooldown": 0.0, "damage": 1, "count": 0, "spread": 0.0,
		"speed": 0.0, "mana_per_sec": 4, "name": "冰冻喷射器", "type": "spray",
		"range": 100.0, "angle": 0.6
	},
	"dart": {
		"cooldown": 0.45, "damage": 8, "count": 1, "spread": 0.0,
		"speed": 400.0, "mana": 0, "name": "飞镖", "type": "dart",
		"max_distance": 300.0
	},
}

var hp := MAX_HP
var mana := MAX_MANA
var _fire_cooldown := 0.0
var _facing := Vector2.RIGHT
var _weapon_index := 0
var _weapon_keys := ["pistol", "shotgun", "gatling", "freeze", "dart"]
var _freeze_firing := false
var _invuln_timer := 0.0

signal hp_changed(current: int, max_hp: int)
signal player_died
signal player_hit

@onready var bullet_pool: Node2D = $"../BulletPool"


func _ready() -> void:
	collision_layer = 1
	collision_mask = 16  # 碰撞墙壁和门（layer 5）
	add_to_group("player")


func _physics_process(delta: float) -> void:
	if GameManager.state != GameManager.GameState.PLAYING:
		return

	# 无敌时间
	if _invuln_timer > 0.0:
		_invuln_timer -= delta

	# 移动 - 8方向
	var input := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	)
	if input.length() > 1.0:
		input = input.normalized()
	velocity = input * SPEED
	move_and_slide()

	# 面朝方向 = 最后移动方向
	if input.length() > 0.1:
		_facing = input.normalized()

	# 武器切换
	if Input.is_action_just_pressed("switch_weapon"):
		_weapon_index = (_weapon_index + 1) % _weapon_keys.size()
		_freeze_firing = false

	# 蓝量恢复
	mana = min(mana + MANA_REGEN * delta, MAX_MANA)

	# 射击
	_fire_cooldown -= delta
	var weapon: Dictionary = WEAPONS[_weapon_keys[_weapon_index]]

	if weapon.type == "spray":
		# 冰冻喷射器：持续按住J键
		_freeze_firing = Input.is_action_pressed("shoot") and mana > 0
		if _freeze_firing:
			var cost: float = weapon.mana_per_sec * delta
			mana -= cost
			if mana <= 0:
				mana = 0
				_freeze_firing = false
			_spray_freeze(weapon, delta)
		queue_redraw()
		return

	if Input.is_action_pressed("shoot") and _fire_cooldown <= 0.0:
		var mana_cost: float = weapon.mana
		if mana >= mana_cost:
			mana -= mana_cost
			_fire_cooldown = weapon.cooldown
			if weapon.type == "dart":
				_shoot_dart(weapon)
			else:
				_shoot(weapon)

	queue_redraw()


func _shoot(weapon: Dictionary) -> void:
	if bullet_pool == null:
		return
	var count: int = weapon.count
	var spread: float = weapon.spread
	for i in count:
		var angle_offset := 0.0
		if count > 1:
			angle_offset = spread * (float(i) / (count - 1) - 0.5)
		var dir := _facing.rotated(angle_offset)
		bullet_pool.spawn(
			global_position + dir * 14.0,
			dir,
			weapon.speed,
			weapon.damage,
			true,
			false
		)


func _shoot_dart(weapon: Dictionary) -> void:
	if bullet_pool == null:
		return
	bullet_pool.spawn(
		global_position + _facing * 14.0,
		_facing,
		weapon.speed,
		weapon.damage,
		true,
		true,
		weapon.max_distance
	)


func _spray_freeze(weapon: Dictionary, delta: float) -> void:
	var spray_range: float = weapon.range
	var spray_angle: float = weapon.angle
	var enemies := get_tree().get_nodes_in_group("enemy")
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var to_enemy: Vector2 = enemy.global_position - global_position
		var dist: float = to_enemy.length()
		if dist > spray_range:
			continue
		var angle_diff: float = absf(_facing.angle_to(to_enemy.normalized()))
		if angle_diff < spray_angle:
			if enemy.has_method("take_damage"):
				enemy.take_damage(weapon.damage * delta * 10)
			if enemy.has_method("apply_slow"):
				enemy.apply_slow(0.5, 2.0)
				if enemy.has_method("add_freeze_stack"):
					enemy.add_freeze_stack(delta * 5)


func take_damage(amount: int) -> void:
	if _invuln_timer > 0.0:
		return
	hp -= amount
	hp_changed.emit(hp, MAX_HP)
	player_hit.emit()
	_invuln_timer = 0.5
	if hp <= 0:
		player_died.emit()


func get_weapon_name() -> String:
	return WEAPONS[_weapon_keys[_weapon_index]].name


func _draw() -> void:
	# 小三角形角色
	var angle := _facing.angle()
	var size := 10.0
	var points := PackedVector2Array()
	points.append(Vector2(cos(angle), sin(angle)) * size)
	points.append(Vector2(cos(angle + 2.5), sin(angle + 2.5)) * size * 0.65)
	points.append(Vector2(cos(angle - 2.5), sin(angle - 2.5)) * size * 0.65)

	# 无敌闪烁
	if _invuln_timer > 0.0 and int(_invuln_timer * 10) % 2 == 0:
		return

	draw_colored_polygon(points, Color(0.0, 0.898, 1.0))
	draw_polyline(points + PackedVector2Array([points[0]]), Color.WHITE, 1.5)

	# 冰冻喷射器视觉
	if _freeze_firing:
		var weapon: Dictionary = WEAPONS["freeze"]
		var spray_range: float = weapon.range
		var spray_angle: float = weapon.angle
		var cone := PackedVector2Array()
		cone.append(Vector2.ZERO)
		var segments := 12
		for i in segments + 1:
			var a := angle - spray_angle + (spray_angle * 2.0 * i / segments)
			cone.append(Vector2(cos(a), sin(a)) * spray_range)
		draw_colored_polygon(cone, Color(0.3, 0.7, 1.0, 0.2))
