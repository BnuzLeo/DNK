extends CharacterBody2D

## 玩家控制器 - 元气骑士风格
## WASD 移动 + J 键射击，射击方向为面朝方向

const VS := preload("res://scripts/visual_spec.gd")
const ROOSTER_PROJECTILE := preload("res://scripts/rooster_projectile.gd")
const BERSERK_AWAKENING_FX := preload("res://scripts/berserk_awakening_fx.gd")
const LASER_VISUAL_SCRIPT := preload("res://scripts/laser_visual.gd")
const PLAYER_SPRITE_PATH := "res://assets/export/effects/sprite.webp"
const PLAYER_SPRITE_FRAME_SIZE := Vector2i(192, 208)
const PLAYER_SPRITE_FRAME_COUNTS := [6, 8, 8, 4, 5, 8, 6, 6, 6]
const PLAYER_SPRITE_DISPLAY_HEIGHT := 88.0
const PLAYER_SEPARATION_RADIUS := 22.0
const MAN_GUN_TEXTURE_PATH := "res://assets/export/weapon/weapon_02/瓦克恩冲锋枪.png"
const MAN_GUN_NORMAL_FRAME_PATHS: Array[String] = [MAN_GUN_TEXTURE_PATH]
const MAN_GUN_BERSERK_FRAME_PATHS: Array[String] = [MAN_GUN_TEXTURE_PATH]
const LASER_GUN_TEXTURE_PATH := "res://assets/export/weapon/weapon_03/飞熊军激光炮.png"
const LASER_GUN_NORMAL_FRAME_PATHS: Array[String] = [LASER_GUN_TEXTURE_PATH]
const LASER_GUN_BERSERK_FRAME_PATHS: Array[String] = [LASER_GUN_TEXTURE_PATH]

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
const HEAD_BANNER_DISPLAY_SIZE := 52.0
const HEAD_BANNER_OFFSET := Vector2(0.0, -60.0)
const HEAD_BANNER_DURATION := 0.42
const BASKETBALL_PROMPT_FLASH_DURATION := 0.65
const BASKETBALL_AUTO_J_COUNT := 5
const BASKETBALL_AUTO_J_INTERVAL := 0.2
const MAN_GUN_DIRECTION_STEP := PI / 4.0
const MAN_GUN_SCALE_NORMAL := 0.42 * 1.5
const MAN_GUN_SCALE_BERSERK := 0.46 * 1.5
const MAN_GUN_CENTER_X_OFFSET := 9.0
const MAN_GUN_CENTER_Y_OFFSET := PLAYER_SPRITE_DISPLAY_HEIGHT / 3.0
const MAN_GUN_TEXTURE_CENTER_X := 60.0
const MAN_GUN_MUZZLE_SOURCE_X := 109.0
const LASER_GUN_SCALE := 0.86
const LASER_GUN_TEXTURE_CENTER_X := 44.0
const LASER_GUN_MUZZLE_SOURCE_X := 82.0
const LASER_MAX_DISTANCE := 900.0
const LASER_WIDTH := 32.0
const LASER_DAMAGE_WIDTH := 42.0
const LASER_DAMAGE_INTERVAL := 0.12
const LASER_WALL_MASK := 16
const LASER_MIN_HIT_DISTANCE := 6.0
const LASER_REFLECT_ANGLE := PI / 3.0

const WEAPONS := {
	"basketball": {
		"cooldown": 0.42, "damage": 3, "count": 5, "spread": 0.52,
		"speed": 690.0, "mana": 0, "name": "篮球", "type": "basketball",
		"berserk_cooldown": 0.0, "berserk_damage": 9
	},
	"jntm": {
		"cooldown": 0.0, "damage": 2, "mana": 0, "name": "大族激光",
		"type": "laser_gun", "berserk_damage": 3, "berserk_cooldown": 0.0
	},
	"chicken_foot": {
		"cooldown": 0.5, "damage": 8, "mana": 0,
		"name": "真正的MAN", "type": "man_gun", "speed": 780.0,
		"lock_range": 430.0, "aoe_radius": 76.0, "aoe_damage": 5,
		"berserk_cooldown": 0.3, "berserk_damage": 9, "berserk_speed": 920.0,
		"berserk_aoe_radius": 92.0, "berserk_aoe_damage": 6
	},
}

var hp := MAX_HP
var mana := MAX_MANA
var _fire_cooldown := 0.0
var _facing := Vector2.RIGHT
var _weapon_index := 0
var _weapon_keys := ["basketball"]
var _invuln_timer := 0.0
var _test_invincible := false
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
var _weapon_sprite: AnimatedSprite2D = null
var _weapon_anim_mode := ""
var _weapon_aim_dir := Vector2.RIGHT
var _laser_visual: Node2D = null
var _laser_segments: Array[Dictionary] = []
var _laser_damage_timer := 0.0

# 闪避状态
var _dash_timer := 0.0
var _dash_cooldown := 0.0
var _dash_dir := Vector2.ZERO
var _dash_afterimage_timer := 0.0
var _dash_invuln_visual_timer := 0.0
var _basketball_prompt_flash_timer := 0.0
var _basketball_auto_j_remaining := 0
var _basketball_auto_j_timer := 0.0
var _head_banner_active: Sprite2D = null
var _queued_head_banner: Texture2D = null

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
	_setup_carried_weapon_sprite()


func _physics_process(delta: float) -> void:
	var s := GameManager.state
	if s != GameManager.GameState.PLAYING and s != GameManager.GameState.LOBBY:
		return

	# 无敌时间
	if _test_invincible:
		_invuln_timer = max(_invuln_timer, 999999.0)
	elif _invuln_timer > 0.0:
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
	if _basketball_prompt_flash_timer > 0.0:
		_basketball_prompt_flash_timer = maxf(_basketball_prompt_flash_timer - delta, 0.0)
	if _basketball_auto_j_remaining > 0:
		_update_basketball_auto_j(delta)

	# 闪避中 —— 高速移动 + 无敌，不接受其他输入
	if _dash_timer > 0.0:
		if _weapon_keys[_weapon_index] in WEAPONS and WEAPONS[_weapon_keys[_weapon_index]].get("type", "") == "laser_gun":
			_clear_laser_visual()
		_dash_timer -= delta
		velocity = _dash_dir * DASH_SPEED
		_invuln_timer = max(_invuln_timer, DASH_INVULN)
		_dash_invuln_visual_timer = max(_dash_invuln_visual_timer, _dash_timer)
		move_and_slide()
		_resolve_solid_actor_overlaps()
		_last_move_input = _dash_dir
		_update_sprite_animation(delta)
		_update_dash_afterimages(delta)
		_update_carried_weapon_visual()
		modulate = Color.WHITE
		queue_redraw()
		return

	# 无敌闪烁（闪避后延续的无敌时间）
	if _dash_invuln_visual_timer > 0.0:
		_dash_invuln_visual_timer -= delta
		modulate = Color.WHITE
	elif _test_invincible:
		var pulse := sin(Time.get_ticks_msec() * 0.012) * 0.18 + 0.82
		modulate = Color(0.65, 0.95, 1.0, pulse)
	elif _invuln_timer > 0.0:
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
		_update_facing_from_input(dash_input)
		_last_move_input = _dash_dir
		_dash_afterimage_timer = 0.0
		_dash_invuln_visual_timer = DASH_INVULN
		_spawn_dash_afterimage()
		_update_sprite_animation(delta)
		_update_carried_weapon_visual()
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
	_resolve_solid_actor_overlaps()
	_last_move_input = input

	# 面朝方向只跟随左右输入，纯上下移动不改变朝向
	_update_facing_from_input(input)
	_weapon_aim_dir = _get_preview_weapon_aim_dir()
	_update_laser_gun(delta)

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
	if _is_basketball_tap_berserk(weapon):
		if Input.is_action_just_pressed("shoot"):
			_fire_weapon(weapon, true)
	elif weapon.get("type", "") == "laser_gun":
		pass
	elif Input.is_action_pressed("shoot") and _fire_cooldown <= 0.0:
		_fire_weapon(weapon)

	if _berserk_flash_timer > 0.0:
		_berserk_flash_timer -= delta
	_update_sprite_animation(delta)
	_update_carried_weapon_visual()
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
	var previous_type: String = WEAPONS[_weapon_keys[_weapon_index]].get("type", "")
	_weapon_index = (_weapon_index + 1) % _weapon_keys.size()
	GameManager.player_data.weapon_index = _weapon_index
	var next_type: String = WEAPONS[_weapon_keys[_weapon_index]].get("type", "")
	if previous_type == "laser_gun" and next_type != "laser_gun":
		_clear_laser_visual()


func _trigger_berserk() -> void:
	var was_active := _berserk_active
	if GameManager.state == GameManager.GameState.LOBBY:
		_berserk_active = not _berserk_active
		_berserk_timer = 0.0
	else:
		_berserk_active = true
		_berserk_timer = BERSERK_DURATION
	_berserk_flash_timer = 0.25
	if not was_active and _berserk_active:
		_play_berserk_awakening_fx()
	if _berserk_active and _weapon_keys[_weapon_index] == "basketball":
		_start_basketball_auto_j()


func _play_berserk_awakening_fx() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	for node in get_tree().get_nodes_in_group("berserk_awaken_fx"):
		if is_instance_valid(node):
			node.queue_free()
	var fx := BERSERK_AWAKENING_FX.new()
	scene.add_child(fx)


func _get_weapon_cooldown(weapon: Dictionary) -> float:
	if _berserk_active:
		return weapon.get("berserk_cooldown", weapon.cooldown)
	return weapon.cooldown


func get_fire_cooldown_ratio() -> float:
	if _weapon_keys.is_empty():
		return 0.0
	var weapon: Dictionary = WEAPONS[_weapon_keys[_weapon_index]]
	var max_cooldown := _get_weapon_cooldown(weapon)
	if max_cooldown <= 0.0 or _fire_cooldown <= 0.0:
		return 0.0
	return clampf(_fire_cooldown / max_cooldown, 0.0, 1.0)


func _fire_weapon(weapon: Dictionary, ignore_cooldown: bool = false) -> void:
	var mana_cost: float = weapon.get("mana", 0)
	if mana < mana_cost:
		return
	if not ignore_cooldown and _fire_cooldown > 0.0:
		return
	mana -= mana_cost
	_activate_weapon(weapon)
	if weapon.get("type", "") != "man_gun":
		_sprite_action_timer = 0.22
	_fire_cooldown = 0.0 if ignore_cooldown else _get_weapon_cooldown(weapon)


func _activate_weapon(weapon: Dictionary) -> void:
	match weapon.type:
		"basketball":
			_shoot_basketball(weapon)
		"room_blast":
			_start_room_blast(weapon)
		"rooster":
			_spawn_roosters(weapon)
		"man_gun":
			_shoot_man_gun(weapon)
		"laser_gun":
			pass


func _shoot_basketball(weapon: Dictionary) -> void:
	if bullet_pool == null:
		return
	if _is_basketball_tap_berserk(weapon):
		_shoot_basketball_berserk(weapon)
		return
	var count: int = weapon.get("count", 1) + get_buff_stacks(BuffType.BULLET)
	var spread: float = weapon.get("spread", 0.0)
	var speed: float = weapon.get("speed", 620.0)
	var damage: int = weapon.damage + damage_bonus
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


func _shoot_basketball_berserk(weapon: Dictionary) -> void:
	if bullet_pool == null:
		return
	_trigger_basketball_prompt_flash()
	var damage: int = weapon.get("berserk_damage", weapon.damage) + damage_bonus
	var targets: Array[Area2D] = _get_basketball_berserk_targets()
	if targets.is_empty():
		return
	var enemy: Area2D = targets[randi() % targets.size()]
	bullet_pool.call("spawn_basketball_slam", enemy, enemy.global_position, damage)


func _get_basketball_berserk_targets() -> Array[Area2D]:
	var targets: Array[Area2D] = []
	for enemy in get_tree().get_nodes_in_group("enemy"):
		var enemy_area := enemy as Area2D
		if enemy_area == null or not is_instance_valid(enemy_area):
			continue
		if not enemy_area.has_method("take_damage"):
			continue
		if "_dying" in enemy_area and enemy_area._dying:
			continue
		targets.append(enemy_area)
	targets.sort_custom(func(a: Area2D, b: Area2D) -> bool:
		return global_position.distance_squared_to(a.global_position) < global_position.distance_squared_to(b.global_position)
	)
	return targets


func _is_basketball_tap_berserk(weapon: Dictionary) -> bool:
	return weapon.get("type", "") == "basketball" and _berserk_active


func _trigger_basketball_prompt_flash() -> void:
	_basketball_prompt_flash_timer = BASKETBALL_PROMPT_FLASH_DURATION


func _start_basketball_auto_j() -> void:
	_basketball_auto_j_remaining = BASKETBALL_AUTO_J_COUNT
	_basketball_auto_j_timer = 0.0
	_update_basketball_auto_j(0.0)


func _update_basketball_auto_j(delta: float) -> void:
	if _weapon_keys[_weapon_index] != "basketball" or not _berserk_active:
		_basketball_auto_j_remaining = 0
		return
	_basketball_auto_j_timer -= delta
	while _basketball_auto_j_remaining > 0 and _basketball_auto_j_timer <= 0.0:
		_fire_weapon(WEAPONS["basketball"], true)
		_basketball_auto_j_remaining -= 1
		_basketball_auto_j_timer += BASKETBALL_AUTO_J_INTERVAL


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


func _shoot_man_gun(weapon: Dictionary) -> void:
	if bullet_pool == null:
		return
	var targets: Array[Area2D] = _get_man_targets(weapon)
	if targets.is_empty():
		var dir := _snap_man_gun_dir(_weapon_aim_dir)
		if dir == Vector2.ZERO:
			dir = _facing
		_weapon_aim_dir = dir
		var muzzle_pos := _get_man_muzzle_position()
		_spawn_man_bullet(muzzle_pos, dir, weapon)
		return
	for enemy in targets:
		if enemy == null or not is_instance_valid(enemy):
			continue
		var dir := _snap_man_gun_dir(enemy.global_position - global_position)
		if dir == Vector2.ZERO:
			dir = _facing
		_weapon_aim_dir = dir
		var muzzle_pos := _get_man_muzzle_position()
		_spawn_man_bullet(muzzle_pos, dir, weapon)


func _spawn_man_bullet(muzzle_pos: Vector2, dir: Vector2, weapon: Dictionary) -> void:
	var damage: int = (weapon.get("berserk_damage", weapon.damage) if _berserk_active else weapon.damage) + damage_bonus
	var speed: float = weapon.get("berserk_speed", weapon.speed) if _berserk_active else weapon.speed
	var radius: float = weapon.get("berserk_aoe_radius", weapon.aoe_radius) if _berserk_active else weapon.aoe_radius
	var aoe_damage: int = (weapon.get("berserk_aoe_damage", weapon.aoe_damage) if _berserk_active else weapon.aoe_damage) + damage_bonus
	bullet_pool.call("spawn_man_bullet", muzzle_pos, dir, speed, damage, _berserk_active, radius, aoe_damage)


func _update_laser_gun(delta: float) -> void:
	var weapon: Dictionary = WEAPONS[_weapon_keys[_weapon_index]]
	if weapon.get("type", "") != "laser_gun" or not Input.is_action_pressed("shoot"):
		_clear_laser_visual()
		_laser_damage_timer = 0.0
		return
	var dir := _snap_man_gun_dir(_weapon_aim_dir)
	if dir == Vector2.ZERO:
		dir = _facing
	_weapon_aim_dir = dir
	_laser_segments = _build_laser_segments(_get_laser_muzzle_position(), dir, 2 if _berserk_active else 0)
	_update_laser_visual()
	_laser_damage_timer -= delta
	if _laser_damage_timer <= 0.0:
		_laser_damage_timer += LASER_DAMAGE_INTERVAL
		_apply_laser_damage(weapon)


func _build_laser_segments(origin: Vector2, dir: Vector2, bounces: int) -> Array[Dictionary]:
	var segments: Array[Dictionary] = []
	var start := origin
	var current_dir := dir.normalized()
	var remaining := LASER_MAX_DISTANCE
	var space := get_world_2d().direct_space_state
	var query_params := PhysicsRayQueryParameters2D.new()
	query_params.collision_mask = LASER_WALL_MASK
	query_params.collide_with_areas = false
	query_params.collide_with_bodies = true
	var excluded_rids: Array[RID] = [get_rid()]
	query_params.exclude = excluded_rids

	var reflections := 0
	var safety_casts := 0
	while reflections <= bounces and safety_casts < bounces + 8:
		safety_casts += 1
		if remaining <= 1.0 or current_dir == Vector2.ZERO:
			break
		var ray_end := start + current_dir * remaining
		query_params.from = start
		query_params.to = ray_end
		var hit := space.intersect_ray(query_params)
		if not hit.is_empty():
			var hit_pos: Vector2 = hit.get("position", ray_end)
			var hit_distance := start.distance_to(hit_pos)
			if hit_distance < LASER_MIN_HIT_DISTANCE:
				start = hit_pos + current_dir * LASER_MIN_HIT_DISTANCE
				remaining -= LASER_MIN_HIT_DISTANCE
				continue
			segments.append({"from": start, "to": hit_pos})
			remaining -= hit_distance
			if reflections >= bounces:
				break
			var normal: Vector2 = hit.get("normal", Vector2.ZERO)
			if normal == Vector2.ZERO:
				break
			current_dir = _get_laser_reflect_dir(current_dir, normal)
			start = hit_pos + current_dir * 3.0
			reflections += 1
		else:
			segments.append({"from": start, "to": ray_end})
			break
	return segments


func _get_laser_reflect_dir(incoming_dir: Vector2, normal: Vector2) -> Vector2:
	var safe_normal := normal.normalized()
	if safe_normal == Vector2.ZERO:
		return incoming_dir.bounce(normal).normalized()
	var tangent := Vector2(-safe_normal.y, safe_normal.x)
	var side := 1.0 if incoming_dir.dot(tangent) >= 0.0 else -1.0
	return safe_normal.rotated(side * LASER_REFLECT_ANGLE).normalized()


func _apply_laser_damage(weapon: Dictionary) -> void:
	if _laser_segments.is_empty():
		return
	var damage: int = (weapon.get("berserk_damage", weapon.damage) if _berserk_active else weapon.damage) + damage_bonus
	var hit_enemies: Array[Area2D] = []
	for enemy in _get_alive_enemies():
		for segment in _laser_segments:
			var a: Vector2 = segment["from"]
			var b: Vector2 = segment["to"]
			if _distance_to_laser_segment(enemy.global_position, a, b) <= LASER_DAMAGE_WIDTH * 0.5:
				hit_enemies.append(enemy)
				break
	for enemy in hit_enemies:
		_deal_damage_to_enemy(enemy, damage)


func _distance_to_laser_segment(point: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var len_sq := ab.length_squared()
	if len_sq <= 0.0001:
		return point.distance_to(a)
	var t := clampf((point - a).dot(ab) / len_sq, 0.0, 1.0)
	return point.distance_to(a + ab * t)


func _update_laser_visual() -> void:
	_ensure_laser_visual()
	if _laser_visual == null or not is_instance_valid(_laser_visual):
		return
	var color := Color(0.12, 0.92, 1.0, 0.95) if not _berserk_active else Color(0.86, 0.18, 1.0, 1.0)
	_laser_visual.call("setup", _laser_segments, null, LASER_WIDTH, color)


func _clear_laser_visual() -> void:
	if _laser_segments.is_empty() and (_laser_visual == null or not _laser_visual.visible):
		return
	_laser_segments.clear()
	if _laser_visual != null:
		_laser_visual.call("clear")


func _get_man_targets(weapon: Dictionary) -> Array[Area2D]:
	var enemies := _get_alive_enemies()
	if _berserk_active:
		return enemies
	var closest: Area2D = null
	var lock_range: float = weapon.get("lock_range", 430.0)
	var closest_dist := lock_range * lock_range
	for enemy in enemies:
		var dist := global_position.distance_squared_to(enemy.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest = enemy
	var targets: Array[Area2D] = []
	if closest != null:
		targets.append(closest)
	return targets


func _get_alive_enemies() -> Array[Area2D]:
	var enemies: Array[Area2D] = []
	for enemy in get_tree().get_nodes_in_group("enemy"):
		var enemy_area := enemy as Area2D
		if enemy_area == null or not is_instance_valid(enemy_area):
			continue
		if not enemy_area.has_method("take_damage"):
			continue
		if "_dying" in enemy_area and enemy_area._dying:
			continue
		enemies.append(enemy_area)
	return enemies


func _get_preview_weapon_aim_dir() -> Vector2:
	var weapon: Dictionary = WEAPONS[_weapon_keys[_weapon_index]]
	var weapon_type: String = weapon.get("type", "")
	if weapon_type != "man_gun" and weapon_type != "laser_gun":
		return _facing
	if weapon_type == "laser_gun":
		return _snap_man_gun_dir(_facing)
	var targets := _get_man_targets(weapon)
	if targets.is_empty():
		return _snap_man_gun_dir(_facing)
	var dir := _snap_man_gun_dir(targets[0].global_position - global_position)
	return dir if dir != Vector2.ZERO else _snap_man_gun_dir(_facing)


func _update_facing_from_input(input: Vector2) -> void:
	if absf(input.x) <= 0.1:
		if absf(input.y) <= 0.1:
			return
	var snapped_dir := _snap_man_gun_dir(input)
	if snapped_dir != Vector2.ZERO:
		_facing = snapped_dir


func _snap_man_gun_dir(dir: Vector2) -> Vector2:
	if dir.length_squared() <= 0.0001:
		return Vector2.ZERO
	var angle := dir.angle()
	var snapped_angle: float = roundf(angle / MAN_GUN_DIRECTION_STEP) * MAN_GUN_DIRECTION_STEP
	return Vector2.RIGHT.rotated(snapped_angle)


func _get_man_muzzle_position() -> Vector2:
	var dir := _snap_man_gun_dir(_weapon_aim_dir)
	if dir == Vector2.ZERO:
		dir = _facing
	return global_position + _get_man_gun_center_offset(dir) + dir * _get_man_gun_muzzle_distance()


func _get_man_gun_muzzle_distance() -> float:
	var scale_factor := MAN_GUN_SCALE_BERSERK if _berserk_active else MAN_GUN_SCALE_NORMAL
	return (MAN_GUN_MUZZLE_SOURCE_X - MAN_GUN_TEXTURE_CENTER_X) * scale_factor


func _get_man_gun_center_offset(dir: Vector2) -> Vector2:
	var horizontal := 0.0
	if dir.x > 0.1:
		horizontal = MAN_GUN_CENTER_X_OFFSET
	elif dir.x < -0.1:
		horizontal = -MAN_GUN_CENTER_X_OFFSET
	return Vector2(horizontal, MAN_GUN_CENTER_Y_OFFSET)


func _get_laser_muzzle_position() -> Vector2:
	var dir := _snap_man_gun_dir(_weapon_aim_dir)
	if dir == Vector2.ZERO:
		dir = _facing
	return global_position + _get_man_gun_center_offset(dir) + dir * _get_laser_gun_muzzle_distance()


func _get_laser_gun_muzzle_distance() -> float:
	return (LASER_GUN_MUZZLE_SOURCE_X - LASER_GUN_TEXTURE_CENTER_X) * LASER_GUN_SCALE


func take_damage(amount: int) -> void:
	if _test_invincible or _invuln_timer > 0.0 or amount <= 0:
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


func set_test_invincible(enabled: bool) -> void:
	_test_invincible = enabled
	if enabled:
		_invuln_timer = max(_invuln_timer, 999999.0)
	else:
		if _invuln_timer > 10.0:
			_invuln_timer = 0.0
		modulate = Color.WHITE
	queue_redraw()


func is_test_invincible() -> bool:
	return _test_invincible


func get_weapon_name() -> String:
	return WEAPONS[_weapon_keys[_weapon_index]].name


func get_separation_radius() -> float:
	return PLAYER_SEPARATION_RADIUS


func _resolve_solid_actor_overlaps() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var self_radius := get_separation_radius()
	var separation := Vector2.ZERO
	var overlaps := 0
	for group_name in ["enemy", "chest"]:
		for other in tree.get_nodes_in_group(group_name):
			if other == self or not is_instance_valid(other):
				continue
			if not other.has_method("get_separation_radius"):
				continue
			if other.has_method("is_dying") and bool(other.call("is_dying")):
				continue
			if other.has_method("is_solid_actor") and not bool(other.call("is_solid_actor")):
				continue
			var other_node := other as Node2D
			if other_node == null:
				continue
			var other_radius := float(other.call("get_separation_radius"))
			if other_radius <= 0.0:
				continue
			var min_distance := self_radius + other_radius
			var offset := global_position - other_node.global_position
			var dist_sq := offset.length_squared()
			if dist_sq >= min_distance * min_distance:
				continue
			var dist := sqrt(dist_sq)
			var normal := offset / dist if dist > 0.001 else _get_actor_fallback_separation_dir(other_node)
			separation += normal * (min_distance - dist)
			overlaps += 1
	if overlaps > 0:
		move_and_collide(separation / float(overlaps))


func _get_actor_fallback_separation_dir(other: Node) -> Vector2:
	var self_bias := float(get_instance_id() & 1) * 2.0 - 1.0
	var other_bias := float(other.get_instance_id() & 1) * 2.0 - 1.0
	var dir := Vector2(self_bias, other_bias).normalized()
	return dir if dir.length_squared() > 0.0 else Vector2.RIGHT


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
	_sync_sprite_flip()


func _setup_carried_weapon_sprite() -> void:
	_weapon_sprite = AnimatedSprite2D.new()
	_weapon_sprite.centered = true
	_weapon_sprite.z_index = 4
	_weapon_sprite.visible = false
	add_child(_weapon_sprite)
	_update_carried_weapon_visual()


func _ensure_laser_visual() -> void:
	if _laser_visual == null or not is_instance_valid(_laser_visual):
		_laser_visual = LASER_VISUAL_SCRIPT.new()
		_laser_visual.name = "LaserVisual"
		_laser_visual.visible = false
	var target_parent: Node = get_tree().current_scene
	if target_parent == null:
		target_parent = get_parent()
	if target_parent == null:
		return
	if _laser_visual.get_parent() != target_parent:
		var old_parent := _laser_visual.get_parent()
		if old_parent != null:
			old_parent.remove_child(_laser_visual)
		target_parent.add_child(_laser_visual)
	_laser_visual.set_as_top_level(false)
	_laser_visual.position = Vector2.ZERO
	_laser_visual.z_as_relative = false
	_laser_visual.z_index = 30


func _update_carried_weapon_visual() -> void:
	if _weapon_sprite == null:
		return
	var weapon: Dictionary = WEAPONS[_weapon_keys[_weapon_index]]
	var weapon_type: String = weapon.get("type", "")
	if weapon_type != "man_gun" and weapon_type != "laser_gun":
		_weapon_sprite.visible = false
		return
	var mode := _get_carried_weapon_anim_mode(weapon_type)
	if _weapon_anim_mode != mode:
		_weapon_anim_mode = mode
		_weapon_sprite.sprite_frames = _build_carried_weapon_frames(_get_carried_weapon_frame_paths(weapon_type), mode)
		_weapon_sprite.animation = mode
		_weapon_sprite.play(mode)
	_weapon_sprite.visible = true
	var dir := _snap_man_gun_dir(_weapon_aim_dir)
	if dir == Vector2.ZERO:
		dir = _facing
	_weapon_sprite.position = _get_man_gun_center_offset(dir)
	var angle := dir.angle()
	_weapon_sprite.flip_h = dir.x < 0.0
	_weapon_sprite.rotation = angle - PI if _weapon_sprite.flip_h else angle
	_weapon_sprite.scale = Vector2.ONE * _get_carried_weapon_scale(weapon_type)


func _get_carried_weapon_anim_mode(weapon_type: String) -> String:
	if weapon_type == "laser_gun":
		return "laser_berserk" if _berserk_active else "laser_normal"
	return "man_berserk" if _berserk_active else "man_normal"


func _get_carried_weapon_frame_paths(weapon_type: String) -> Array[String]:
	if weapon_type == "laser_gun":
		return LASER_GUN_BERSERK_FRAME_PATHS if _berserk_active else LASER_GUN_NORMAL_FRAME_PATHS
	return MAN_GUN_BERSERK_FRAME_PATHS if _berserk_active else MAN_GUN_NORMAL_FRAME_PATHS


func _get_carried_weapon_scale(weapon_type: String) -> float:
	if weapon_type == "laser_gun":
		return LASER_GUN_SCALE
	return MAN_GUN_SCALE_BERSERK if _berserk_active else MAN_GUN_SCALE_NORMAL


func _should_play_berserk_attack_frames() -> bool:
	var weapon: Dictionary = WEAPONS[_weapon_keys[_weapon_index]]
	var weapon_type: String = weapon.get("type", "")
	return weapon_type != "laser_gun" and weapon_type != "man_gun"


func _build_carried_weapon_frames(paths: Array[String], anim_name: String) -> SpriteFrames:
	var frames := SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")
	frames.add_animation(anim_name)
	frames.set_animation_loop(anim_name, true)
	frames.set_animation_speed(anim_name, 12.0)
	for path in paths:
		var texture := load(path) as Texture2D
		if texture != null:
			frames.add_frame(anim_name, texture)
	return frames


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
		if _berserk_active and _should_play_berserk_attack_frames():
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
	_sync_sprite_flip()


func _sync_sprite_flip() -> void:
	if _sprite == null:
		return
	# 跑步左右帧本身已经分开；只有站立/非方向性动作需要按朝向镜像。
	if _sprite_anim == PlayerSpriteAnim.RUN_LEFT or _sprite_anim == PlayerSpriteAnim.RUN_RIGHT:
		_sprite.flip_h = false
	else:
		_sprite.flip_h = _facing.x < 0.0


func _update_dash_afterimages(delta: float) -> void:
	_dash_afterimage_timer -= delta
	if _dash_afterimage_timer > 0.0:
		return
	_dash_afterimage_timer = 0.035
	_spawn_dash_afterimage()


func _spawn_dash_afterimage() -> void:
	if _sprite == null:
		return
	var parent := get_parent()
	if parent == null:
		return
	var ghost := Sprite2D.new()
	ghost.texture = _sprite.texture
	ghost.region_enabled = true
	ghost.region_rect = _sprite.region_rect
	ghost.centered = true
	ghost.flip_h = _sprite.flip_h
	ghost.global_position = global_position
	ghost.global_rotation = _sprite.global_rotation
	ghost.scale = _sprite.global_scale
	ghost.z_index = _sprite.z_index - 1
	ghost.modulate = Color(0.4, 0.85, 1.0, 0.42)
	parent.add_child(ghost)
	var tween := ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, 0.22)
	tween.parallel().tween_property(ghost, "scale", ghost.scale * 1.08, 0.22)
	tween.tween_callback(ghost.queue_free)


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


func should_show_attack_tap_prompt() -> bool:
	return _weapon_keys[_weapon_index] == "basketball" and _berserk_active


func get_attack_tap_prompt_flash_ratio() -> float:
	if BASKETBALL_PROMPT_FLASH_DURATION <= 0.0:
		return 0.0
	return clampf(_basketball_prompt_flash_timer / BASKETBALL_PROMPT_FLASH_DURATION, 0.0, 1.0)


func get_all_weapon_keys() -> Array:
	return WEAPONS.keys()


func queue_head_banner(texture: Texture2D) -> void:
	if texture == null:
		return
	if _head_banner_active != null and is_instance_valid(_head_banner_active):
		_queued_head_banner = texture
		return
	_show_head_banner(texture)


func _show_head_banner(texture: Texture2D) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = true
	sprite.position = HEAD_BANNER_OFFSET
	sprite.z_index = 120
	var max_dim := maxf(float(texture.get_width()), float(texture.get_height()))
	if max_dim > 0.0:
		sprite.scale = Vector2.ONE * (HEAD_BANNER_DISPLAY_SIZE / max_dim)
	add_child(sprite)
	_head_banner_active = sprite
	var tween := sprite.create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "position:y", HEAD_BANNER_OFFSET.y - 14.0, HEAD_BANNER_DURATION)
	tween.tween_property(sprite, "modulate:a", 0.0, HEAD_BANNER_DURATION)
	tween.tween_property(sprite, "scale", sprite.scale * 1.05, HEAD_BANNER_DURATION)
	tween.chain().tween_callback(Callable(self, "_finish_head_banner").bind(sprite))


func _finish_head_banner(sprite: Sprite2D) -> void:
	if sprite != null and is_instance_valid(sprite):
		sprite.queue_free()
	if _head_banner_active == sprite:
		_head_banner_active = null
	if _queued_head_banner != null:
		var next_texture := _queued_head_banner
		_queued_head_banner = null
		_show_head_banner(next_texture)


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
