extends CharacterBody2D

## 玩家控制器 - 元气骑士风格
## WASD 移动 + J 键射击，射击方向为面朝方向

const VS := preload("res://scripts/visual_spec.gd")
const ROOSTER_PROJECTILE := preload("res://scripts/rooster_projectile.gd")
const PLAYER_SPRITE_PATH := "res://assets/export/characters/sprite.webp"
const PLAYER_SPRITE_FRAME_SIZE := Vector2i(192, 208)
const PLAYER_SPRITE_FRAME_COUNTS := [6, 8, 8, 4, 5, 8, 6, 6, 6]
const PLAYER_SPRITE_DISPLAY_HEIGHT := 88.0

enum PlayerSpriteAnim { IDLE, RUN_RIGHT, RUN_LEFT, WAVE, JUMP, FAIL, WAIT, DANCE, INSPECT }

var SPEED := 180.0
var MAX_HP := 10
var MAX_MANA := 50.0
var MANA_REGEN := 3.0

# 基础值（升级计算用）
const BASE_SPEED := 180.0
const BASE_MAX_HP := 10
const BASE_MAX_MANA := 50.0
const BASE_MANA_REGEN := 3.0
const BASE_ARMOR := 5
const HP_PER_LEVEL := 2
const SPEED_PER_LEVEL := 10.0
const MANA_PER_LEVEL := 10.0
const REGEN_PER_LEVEL := 0.5

# 闪避技能
const DASH_SPEED := 500.0
const DASH_DURATION := 0.25
const DASH_COOLDOWN := 5.0
const DASH_INVULN := 0.5
const BERSERK_DURATION := 5.0
const BERSERK_COLOR := Color(1.0, 0.25, 0.08)

const WEAPONS := {
	"basketball": {
		"cooldown": 0.18, "damage": 4, "count": 1, "spread": 0.0,
		"speed": 620.0, "mana": 0, "name": "篮球", "type": "basketball",
		"berserk_cooldown": 0.05, "berserk_damage": 2, "berserk_spread": 0.08,
		"berserk_speed": 760.0
	},
	"jntm": {
		"cooldown": 3.0, "damage": 18, "mana": 0, "name": "鸡你太美",
		"type": "room_blast", "berserk_hits": 3, "berserk_interval": 3.0,
		"berserk_cooldown": 9.0
	},
	"chicken_foot": {
		"cooldown": 1.0, "damage": 8, "count": 1, "mana": 0,
		"name": "漏出鸡脚", "type": "rooster", "speed": 320.0, "lifetime": 6.0,
		"monitor_range": 180.0,
		"berserk_count": 10, "berserk_cooldown": 3.0
	},
}

var hp := MAX_HP
var mana := MAX_MANA
var _fire_cooldown := 0.0
var _facing := Vector2.RIGHT
var _weapon_index := 0
var _weapon_keys := ["basketball"]
var _invuln_timer := 0.0
var _berserk_active := false
var _berserk_timer := 0.0
var _berserk_flash_timer := 0.0
var _room_blast_pending := 0
var _room_blast_timer := 0.0
var _room_blast_interval := 0.0
var _room_blast_damage := 0
var _sprite: Sprite2D = null
var _sprite_anim := PlayerSpriteAnim.IDLE
var _sprite_frame := 0
var _sprite_timer := 0.0
var _sprite_idle_timer := 0.0
var _sprite_action_timer := 0.0
var _last_move_input := Vector2.ZERO

# 闪避状态
var _dash_timer := 0.0
var _dash_cooldown := 0.0
var _dash_dir := Vector2.ZERO

# Buff 系统
enum BuffType { MANA_REGEN, SPEED, REVIVE, BULLET }
const BUFF_INFO := {
	BuffType.MANA_REGEN: {"name": "回蓝", "color": Color(0.2, 0.4, 1.0), "icon": "◆"},
	BuffType.SPEED:      {"name": "移速", "color": Color(0.0, 0.9, 0.4), "icon": "»"},
	BuffType.REVIVE:     {"name": "复活", "color": Color(1.0, 0.84, 0.0), "icon": "★"},
	BuffType.BULLET:     {"name": "弹道", "color": Color(1.0, 0.4, 0.7), "icon": "†"},
}
# {BuffType: {"time": float, "stacks": int}}
var _active_buffs: Dictionary = {}

signal hp_changed(current: int, max_hp: int)
signal player_died
signal player_hit

var bullet_pool: Node2D


var max_armor := 0
var armor := 0
var hp_regen_rate := 0.0
var damage_bonus := 0
var _talent_dash_cd_reduction := 0.0
var _pending_weapon_switch := false


func _load_from_game_manager() -> void:
	var data: Dictionary = GameManager.player_data
	var hp_level: int = data.get("upgrade_hp_level", 0)
	var spd_level: int = data.get("upgrade_speed_level", 0)
	var mana_level: int = data.get("upgrade_mana_level", 0)
	var regen_level: int = data.get("upgrade_regen_level", 0)

	# 天赋等级
	var t_core: int = data.get("talent_core", 0)
	var t_hp_max: int = data.get("talent_hp_max", 0)
	var t_hp_regen: int = data.get("talent_hp_regen", 0)
	var t_shield: int = data.get("talent_shield", 0)
	var t_spd_up: int = data.get("talent_spd_up", 0)
	var t_dash_cd: int = data.get("talent_dash_cd", 0)
	var t_mana_max: int = data.get("talent_mana_max", 0)
	var t_mana_regen: int = data.get("talent_mana_regen", 0)
	var t_dmg_up: int = data.get("talent_dmg_up", 0)

	# 核心天赋：每级全属性+1
	var core_bonus := t_core

	# 计算属性（升级 + 天赋）
	MAX_HP = BASE_MAX_HP + hp_level * HP_PER_LEVEL + t_hp_max * 3 + core_bonus
	SPEED = BASE_SPEED + spd_level * SPEED_PER_LEVEL + t_spd_up * 8 + core_bonus
	MAX_MANA = BASE_MAX_MANA + mana_level * MANA_PER_LEVEL + t_mana_max * 10 + core_bonus
	MANA_REGEN = BASE_MANA_REGEN + regen_level * REGEN_PER_LEVEL + t_mana_regen * 0.5 + core_bonus * 0.1

	# 天赋：生命回复
	var hp_regen_vals := [0.0, 0.5, 1.0, 2.0]
	hp_regen_rate = hp_regen_vals[t_hp_regen] if t_hp_regen < hp_regen_vals.size() else 0.0

	# 天赋：护盾
	var shield_vals := [0, 2, 5, 10]
	max_armor = BASE_ARMOR + (shield_vals[t_shield] if t_shield < shield_vals.size() else 0)
	armor = max_armor

	# 天赋：闪避冷却
	_talent_dash_cd_reduction = t_dash_cd * 0.5

	# 天赋：伤害加成
	var dmg_vals := [0, 1, 2, 4]
	damage_bonus = dmg_vals[t_dmg_up] if t_dmg_up < dmg_vals.size() else 0

	_weapon_keys.clear()
	for key in data.get("equipped_weapons", ["basketball"]):
		if key in WEAPONS:
			_weapon_keys.append(key)
	if _weapon_keys.is_empty():
		_weapon_keys.append("basketball")
	_weapon_index = data.get("weapon_index", 0)
	if _weapon_index < 0 or _weapon_index >= _weapon_keys.size():
		_weapon_index = 0

	hp = MAX_HP
	mana = MAX_MANA


func save_to_game_manager() -> void:
	GameManager.player_data.weapon_index = _weapon_index


func _ready() -> void:
	collision_layer = 1
	collision_mask = 48  # 碰撞墙壁(layer 4) + 拾取(layer 5)
	add_to_group("player")
	bullet_pool = get_node_or_null("../BulletPool")
	_load_from_game_manager()
	_setup_sprite()


func _physics_process(delta: float) -> void:
	var s := GameManager.state
	if s != GameManager.GameState.PLAYING and s != GameManager.GameState.LOBBY:
		return

	# 无敌时间
	if _invuln_timer > 0.0:
		_invuln_timer -= delta

	# 闪避冷却
	if s != GameManager.GameState.LOBBY and _dash_cooldown > 0.0:
		_dash_cooldown -= delta
	elif s == GameManager.GameState.LOBBY:
		_dash_cooldown = 0.0

	# 副本内狂暴持续时间
	if s == GameManager.GameState.PLAYING and _berserk_active and _berserk_timer > 0.0:
		_berserk_timer -= delta
		if _berserk_timer <= 0.0:
			_berserk_active = false
			_berserk_timer = 0.0

	# 闪避中 —— 高速移动 + 无敌，不接受其他输入
	if _dash_timer > 0.0:
		_dash_timer -= delta
		velocity = _dash_dir * DASH_SPEED
		_invuln_timer = max(_invuln_timer, DASH_INVULN)
		move_and_slide()
		_last_move_input = _dash_dir
		_update_sprite_animation(delta)
		# 半透明 + 闪烁
		var blink := sin(_dash_timer * 40.0) * 0.3 + 0.5
		modulate = Color(1, 1, 1, blink)
		queue_redraw()
		return

	# 无敌闪烁（闪避后延续的无敌时间）
	if _invuln_timer > 0.0:
		var blink := sin(_invuln_timer * 20.0) * 0.4 + 0.6
		modulate = Color(1, 1, 1, blink)
	else:
		modulate = Color(1, 1, 1, 1)

	# Buff 计时
	_update_buffs(delta)
	_update_room_blast_combo(delta)

	# 闪避输入（Shift）
	if Input.is_action_just_pressed("dash") and _dash_cooldown <= 0.0:
		_dash_timer = DASH_DURATION
		_dash_cooldown = 0.0 if s == GameManager.GameState.LOBBY else DASH_COOLDOWN - _talent_dash_cd_reduction
		# 有移动输入就用移动方向，否则用朝向
		var dash_input := Vector2(
			Input.get_axis("move_left", "move_right"),
			Input.get_axis("move_up", "move_down")
		)
		_dash_dir = dash_input.normalized() if dash_input.length() > 0.1 else _facing
		_last_move_input = _dash_dir
		_update_sprite_animation(delta)
		return

	# 移动 - 8方向
	var input := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	)
	if input.length() > 1.0:
		input = input.normalized()
	var move_speed: float = SPEED * (1.0 + get_buff_stacks(BuffType.SPEED) * 0.2)
	velocity = input * move_speed
	move_and_slide()
	_last_move_input = input

	# 面朝方向 = 最后移动方向
	if input.length() > 0.1:
		_facing = input.normalized()

	# 武器切换
	if _pending_weapon_switch:
		_pending_weapon_switch = false
		_cycle_weapon()

	# 蓝量恢复
	var regen: float = MANA_REGEN * (1.0 + get_buff_stacks(BuffType.MANA_REGEN) * 0.5)
	mana = min(mana + regen * delta, MAX_MANA)

	# 生命回复（天赋）
	if hp_regen_rate > 0.0 and hp < MAX_HP:
		hp = mini(hp + int(hp_regen_rate * delta * 10), MAX_HP)

	# 射击
	_fire_cooldown -= delta
	var weapon: Dictionary = WEAPONS[_weapon_keys[_weapon_index]]

	if Input.is_action_pressed("shoot") and _fire_cooldown <= 0.0:
		var mana_cost: float = weapon.get("mana", 0)
		if mana >= mana_cost:
			mana -= mana_cost
			_fire_cooldown = _get_weapon_cooldown(weapon)
			_activate_weapon(weapon)
			_sprite_action_timer = 0.22

	if _berserk_flash_timer > 0.0:
		_berserk_flash_timer -= delta
	_update_sprite_animation(delta)
	queue_redraw()


func _input(event: InputEvent) -> void:
	if GameManager.state != GameManager.GameState.PLAYING and GameManager.state != GameManager.GameState.LOBBY:
		return
	if event is InputEventKey and event.echo:
		return
	if event.is_action_pressed("switch_weapon") or (event is InputEventKey and event.pressed and event.keycode == KEY_Q):
		_pending_weapon_switch = true
	elif event.is_action_pressed("berserk"):
		_trigger_berserk()


func _cycle_weapon() -> void:
	if _weapon_keys.size() <= 1:
		return
	_weapon_index = (_weapon_index + 1) % _weapon_keys.size()
	GameManager.player_data.weapon_index = _weapon_index


func _trigger_berserk() -> void:
	if GameManager.state == GameManager.GameState.LOBBY:
		_berserk_active = not _berserk_active
		_berserk_timer = 0.0
	else:
		_berserk_active = true
		_berserk_timer = BERSERK_DURATION
	_berserk_flash_timer = 0.25


func _get_weapon_cooldown(weapon: Dictionary) -> float:
	if _berserk_active:
		return weapon.get("berserk_cooldown", weapon.cooldown)
	return weapon.cooldown


func _activate_weapon(weapon: Dictionary) -> void:
	match weapon.type:
		"basketball":
			_shoot_basketball(weapon)
		"room_blast":
			_start_room_blast(weapon)
		"rooster":
			_spawn_roosters(weapon)


func _shoot_basketball(weapon: Dictionary) -> void:
	if bullet_pool == null:
		return
	var count: int = weapon.get("count", 1) + get_buff_stacks(BuffType.BULLET)
	var spread: float = weapon.get("spread", 0.0)
	var speed: float = weapon.get("speed", 620.0)
	var damage: int = weapon.damage + damage_bonus
	if _berserk_active:
		spread = weapon.get("berserk_spread", spread)
		speed = weapon.get("berserk_speed", speed)
		damage = weapon.get("berserk_damage", weapon.damage) + damage_bonus
	for i in count:
		var angle_offset := 0.0
		if count > 1:
			angle_offset = spread * (float(i) / (count - 1) - 0.5)
		var dir := _facing.rotated(angle_offset)
		bullet_pool.spawn(
			global_position + dir * (VS.PLAYER_DISPLAY_SIZE * 0.5),
			dir,
			speed,
			damage,
			true,
			false,
			0.0,
			"basketball"
		)


func _start_room_blast(weapon: Dictionary) -> void:
	var hits: int = weapon.get("berserk_hits", 1) if _berserk_active else 1
	_room_blast_damage = weapon.damage + damage_bonus
	_room_blast_interval = weapon.get("berserk_interval", weapon.cooldown)
	_room_blast_pending = maxi(hits - 1, 0)
	_room_blast_timer = _room_blast_interval
	_deal_room_blast(_room_blast_damage)


func _update_room_blast_combo(delta: float) -> void:
	if _room_blast_pending <= 0:
		return
	if GameManager.state != GameManager.GameState.PLAYING and GameManager.state != GameManager.GameState.LOBBY:
		return
	_room_blast_timer -= delta
	if _room_blast_timer > 0.0:
		return
	_deal_room_blast(_room_blast_damage)
	_room_blast_pending -= 1
	if _room_blast_pending > 0:
		_room_blast_timer += _room_blast_interval


func _deal_room_blast(amount: int) -> void:
	var targets := _get_current_room_enemies()
	for enemy in targets:
		_deal_damage_to_enemy(enemy, amount)
	_show_room_blast_fx(amount, targets.size())


func _get_current_room_enemies() -> Array:
	var enemies_in_room: Array = []
	var player_cell := Vector2i(
		int(floor(global_position.x / VS.CELL_SIZE.x)),
		int(floor(global_position.y / VS.CELL_SIZE.y))
	)
	var enemies := get_tree().get_nodes_in_group("enemy")
	for enemy in enemies:
		if not is_instance_valid(enemy) or not enemy.has_method("take_damage"):
			continue
		if "_dying" in enemy and enemy._dying:
			continue
		var enemy_cell := Vector2i(
			int(floor(enemy.global_position.x / VS.CELL_SIZE.x)),
			int(floor(enemy.global_position.y / VS.CELL_SIZE.y))
		)
		if enemy_cell == player_cell:
			enemies_in_room.append(enemy)
	return enemies_in_room


func _deal_damage_to_enemy(enemy: Node, amount: int) -> void:
	var was_dying: bool = "_dying" in enemy and enemy._dying
	enemy.take_damage(amount)
	if not was_dying and "hp" in enemy and enemy.hp <= 0:
		GameManager.add_kill()
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("spawn_damage_number"):
		var color := BERSERK_COLOR if _berserk_active else Color(1.0, 0.84, 0.0)
		scene.spawn_damage_number(enemy.global_position, amount, color, 16)


func _show_room_blast_fx(amount: int, target_count: int) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var canvas := CanvasLayer.new()
	canvas.layer = 31
	scene.add_child(canvas)

	var flash := ColorRect.new()
	flash.color = Color(1.0, 0.35, 0.08, 0.16) if _berserk_active else Color(1.0, 0.84, 0.0, 0.12)
	flash.size = VS.VIEWPORT_SIZE
	canvas.add_child(flash)

	var label := Label.new()
	label.text = "鸡你太美!  %d" % amount
	if target_count <= 0:
		label.text = "鸡你太美!"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 28 if _berserk_active else 22)
	label.add_theme_color_override("font_color", BERSERK_COLOR if _berserk_active else Color(1.0, 0.9, 0.35))
	label.position = Vector2(330, 105)
	label.size = Vector2(300, 40)
	canvas.add_child(label)

	var tween := create_tween()
	tween.tween_property(flash, "modulate:a", 0.0, 0.18)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.35)
	tween.tween_callback(canvas.queue_free)


func _spawn_roosters(weapon: Dictionary) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var count: int = weapon.get("berserk_count", weapon.get("count", 1)) if _berserk_active else weapon.get("count", 1)
	var damage: int = weapon.damage + damage_bonus
	var speed: float = weapon.get("speed", 280.0)
	var lifetime: float = weapon.get("lifetime", 4.0)
	var monitor_range: float = weapon.get("monitor_range", 180.0)
	var placement_radius := 14.0 if count > 1 else 0.0

	for i in count:
		var dir := _facing.normalized()
		var spawn_pos := global_position
		if count > 1:
			var angle := TAU * float(i) / float(count)
			dir = Vector2(cos(angle), sin(angle))
			spawn_pos += dir * placement_radius
		var projectile: Area2D = ROOSTER_PROJECTILE.new()
		scene.add_child(projectile)
		projectile.setup(spawn_pos, dir, damage, speed, lifetime, monitor_range, _berserk_active)


func take_damage(amount: int) -> void:
	if _invuln_timer > 0.0 or amount <= 0:
		return
	var remaining := amount
	if armor > 0:
		var absorbed := mini(armor, remaining)
		armor -= absorbed
		remaining -= absorbed
	if remaining > 0:
		hp -= remaining
		hp_changed.emit(hp, MAX_HP)
	player_hit.emit()
	_invuln_timer = 0.5
	if hp <= 0:
		player_died.emit()


func get_weapon_name() -> String:
	return WEAPONS[_weapon_keys[_weapon_index]].name


func _setup_sprite() -> void:
	var texture := load(PLAYER_SPRITE_PATH) as Texture2D
	if texture == null:
		var image := Image.new()
		var err := image.load(PLAYER_SPRITE_PATH)
		if err != OK:
			return
		texture = ImageTexture.create_from_image(image)

	_sprite = Sprite2D.new()
	_sprite.texture = texture
	_sprite.region_enabled = true
	_sprite.centered = true
	_sprite.z_index = 2
	var sprite_scale := PLAYER_SPRITE_DISPLAY_HEIGHT / float(PLAYER_SPRITE_FRAME_SIZE.y)
	_sprite.scale = Vector2(sprite_scale, sprite_scale)
	add_child(_sprite)
	_apply_sprite_frame()


func _update_sprite_animation(delta: float) -> void:
	if _sprite == null:
		return

	if _sprite_action_timer > 0.0:
		_sprite_action_timer -= delta

	var moving := _last_move_input.length() > 0.1
	var next_anim := PlayerSpriteAnim.IDLE
	if hp <= 0:
		next_anim = PlayerSpriteAnim.FAIL
	elif _dash_timer > 0.0:
		next_anim = PlayerSpriteAnim.JUMP
	elif _sprite_action_timer > 0.0 and not moving:
		next_anim = PlayerSpriteAnim.WAVE
	elif moving:
		_sprite_idle_timer = 0.0
		var horizontal := _last_move_input.x
		if absf(horizontal) < 0.05:
			horizontal = _facing.x
		next_anim = PlayerSpriteAnim.RUN_LEFT if horizontal < 0.0 else PlayerSpriteAnim.RUN_RIGHT
	else:
		_sprite_idle_timer += delta
		if _berserk_active:
			next_anim = PlayerSpriteAnim.DANCE
		elif _sprite_idle_timer > 8.0:
			next_anim = PlayerSpriteAnim.INSPECT
		elif _sprite_idle_timer > 4.0:
			next_anim = PlayerSpriteAnim.WAIT
		else:
			next_anim = PlayerSpriteAnim.IDLE

	if next_anim != _sprite_anim:
		_sprite_anim = next_anim
		_sprite_frame = 0
		_sprite_timer = 0.0
		_apply_sprite_frame()
		return

	_sprite_timer += delta
	var frame_time := _get_sprite_frame_time(_sprite_anim)
	if _sprite_timer >= frame_time:
		_sprite_timer = fmod(_sprite_timer, frame_time)
		var frame_count: int = PLAYER_SPRITE_FRAME_COUNTS[_sprite_anim]
		_sprite_frame = (_sprite_frame + 1) % frame_count
		_apply_sprite_frame()


func _get_sprite_frame_time(anim: int) -> float:
	match anim:
		PlayerSpriteAnim.RUN_RIGHT, PlayerSpriteAnim.RUN_LEFT:
			return 0.09
		PlayerSpriteAnim.WAVE, PlayerSpriteAnim.JUMP:
			return 0.12
		PlayerSpriteAnim.DANCE:
			return 0.10
		PlayerSpriteAnim.FAIL:
			return 0.16
	return 0.18


func _apply_sprite_frame() -> void:
	if _sprite == null:
		return
	var frame_count: int = PLAYER_SPRITE_FRAME_COUNTS[_sprite_anim]
	_sprite_frame = clampi(_sprite_frame, 0, frame_count - 1)
	_sprite.region_rect = Rect2(
		Vector2(_sprite_frame * PLAYER_SPRITE_FRAME_SIZE.x, _sprite_anim * PLAYER_SPRITE_FRAME_SIZE.y),
		Vector2(PLAYER_SPRITE_FRAME_SIZE)
	)


func _draw() -> void:
	# 小三角形角色
	var angle := _facing.angle()
	var size := VS.PLAYER_DISPLAY_SIZE * 0.5
	if _sprite == null:
		var points := PackedVector2Array()
		points.append(Vector2(cos(angle), sin(angle)) * size)
		points.append(Vector2(cos(angle + 2.5), sin(angle + 2.5)) * size * 0.65)
		points.append(Vector2(cos(angle - 2.5), sin(angle - 2.5)) * size * 0.65)

		# 无敌闪烁
		if _invuln_timer > 0.0 and int(_invuln_timer * 10) % 2 == 0:
			return

		draw_colored_polygon(points, Color(0.0, 0.898, 1.0))
		draw_polyline(points + PackedVector2Array([points[0]]), Color.WHITE, 1.5)

	if _berserk_active:
		var pulse := sin(Time.get_ticks_msec() * 0.018) * 0.18 + 0.72
		draw_arc(Vector2.ZERO, size + 5.0, 0, TAU, 28, Color(BERSERK_COLOR.r, BERSERK_COLOR.g, BERSERK_COLOR.b, pulse), 2.0)
		if _berserk_flash_timer > 0.0:
			draw_circle(Vector2.ZERO, size + 8.0, Color(1.0, 0.35, 0.1, 0.18))


# ── 武器管理 ──────────────────────────────────────────

func add_weapon(key: String) -> bool:
	## 添加武器到循环列表，返回是否成功（已有则失败）
	if key not in WEAPONS or key in _weapon_keys:
		return false
	_weapon_keys.append(key)
	return true


func has_weapon(key: String) -> bool:
	return key in _weapon_keys


func is_berserk_active() -> bool:
	return _berserk_active


func get_all_weapon_keys() -> Array:
	return WEAPONS.keys()


# ── Buff 系统 ──────────────────────────────────────────

func add_buff(type: int, duration: float) -> void:
	if type in _active_buffs:
		_active_buffs[type].time += duration
		_active_buffs[type].stacks += 1
	else:
		_active_buffs[type] = {"time": duration, "stacks": 1}


func get_buff_stacks(type: int) -> int:
	if type in _active_buffs:
		return _active_buffs[type].stacks
	return 0


func get_active_buffs() -> Dictionary:
	return _active_buffs


func _update_buffs(delta: float) -> void:
	var expired: Array = []
	for type in _active_buffs:
		_active_buffs[type].time -= delta
		if _active_buffs[type].time <= 0.0:
			expired.append(type)
	for type in expired:
		_active_buffs.erase(type)
