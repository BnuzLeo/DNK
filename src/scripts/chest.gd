extends Area2D

## 宝箱 — 触碰后打开，掉落武器或限时 Buff
## is_weapon_choice = true 时为起始房间的 3 选 1 武器宝箱

const VS := preload("res://scripts/visual_spec.gd")

signal opened(reward_type: String, reward_key: String)

const START_SUPPLY_WEAPON_KEYS := ["chicken_foot", "jntm"]
const START_SUPPLY_WEAPON_ICONS := {
	"chicken_foot": "res://assets/export/weapon/weapon_02/瓦克恩冲锋枪.png",
	"jntm": "res://assets/export/weapon/weapon_03/飞熊军激光炮.png",
}
const GOLD_CHEST_FRAME_PATHS := [
	"res://assets/export/decoration/gold_chest_idle_frames/gold_chest_idle_00.png",
	"res://assets/export/decoration/gold_chest_idle_frames/gold_chest_idle_01.png",
	"res://assets/export/decoration/gold_chest_idle_frames/gold_chest_idle_02.png",
	"res://assets/export/decoration/gold_chest_idle_frames/gold_chest_idle_03.png",
	"res://assets/export/decoration/gold_chest_idle_frames/gold_chest_idle_04.png",
	"res://assets/export/decoration/gold_chest_idle_frames/gold_chest_idle_05.png",
	"res://assets/export/decoration/gold_chest_idle_frames/gold_chest_idle_06.png",
]
const GOLD_CHEST_DISPLAY_SIZE := 58.0
const GOLD_CHEST_FRAME_TIME := 0.12

var _opened := false
var _bounce_timer := 0.0
var _reward_type := ""  # "weapon" or "buff"
var _reward_key := ""
var _reward_name := ""
var _near_player: Node = null
var _gold_chest_frames: Array[Texture2D] = []
var _gold_frame_index := 0
var _gold_frame_timer := 0.0

var is_weapon_choice := false  # 起始房间 3 选 1 模式
var is_start_supply := false

const BUFF_DURATION_MIN := 20.0
const BUFF_DURATION_MAX := 40.0


func _ready() -> void:
	collision_layer = 32  # PICKUP 层
	collision_mask = 1    # 碰撞玩家
	add_to_group("chest")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if is_start_supply:
		_load_gold_chest_frames()
		_configure_start_supply_collision()
		set_process_input(true)
	elif not is_weapon_choice:
		_pick_reward()
	_bounce_timer = randf() * TAU


func _pick_reward() -> void:
	var player: Node = get_tree().get_first_node_in_group("player")
	if player == null:
		_pick_buff()
		return

	# 如果玩家还有未获得的武器，40% 概率掉武器
	var missing_weapons: Array = []
	for key in player.WEAPONS:
		if not player.has_weapon(key):
			missing_weapons.append(key)

	if not missing_weapons.is_empty() and randf() < 0.4:
		_reward_type = "weapon"
		_reward_key = missing_weapons[randi() % missing_weapons.size()]
		_reward_name = player.WEAPONS[_reward_key].name
	else:
		_pick_buff()


func _pick_buff() -> void:
	_reward_type = "buff"
	var types := [0, 1, 2, 3]
	_reward_key = str(types[randi() % types.size()])
	var buff_type: int = int(_reward_key)
	_reward_name = get_buff_display_name(buff_type)


func get_buff_display_name(type: int) -> String:
	match type:
		0: return "回蓝强化"
		1: return "移速强化"
		2: return "复活币"
		3: return "弹道强化"
		_: return "未知"


func is_solid_actor() -> bool:
	return not _opened


func get_separation_radius() -> float:
	return 30.0 if is_start_supply else 18.0


func _physics_process(delta: float) -> void:
	_bounce_timer += delta * 3.0
	if is_start_supply and not _gold_chest_frames.is_empty():
		_gold_frame_timer += delta
		if _gold_frame_timer >= GOLD_CHEST_FRAME_TIME:
			_gold_frame_timer = fmod(_gold_frame_timer, GOLD_CHEST_FRAME_TIME)
			_gold_frame_index = (_gold_frame_index + 1) % _gold_chest_frames.size()
	queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	if _opened:
		return
	if not body.is_in_group("player"):
		return
	if is_start_supply:
		_near_player = body
		return
	_opened = true

	if is_weapon_choice:
		_show_weapon_choice(body)
	else:
		_give_reward(body)


func _on_body_exited(body: Node2D) -> void:
	if body == _near_player:
		_near_player = null


func _input(event: InputEvent) -> void:
	if not is_start_supply or _opened:
		return
	if _near_player == null or not is_instance_valid(_near_player):
		return
	if GameManager.state != GameManager.GameState.PLAYING:
		return
	if event.is_action_pressed("interact"):
		_opened = true
		get_viewport().set_input_as_handled()
		_give_start_supply(_near_player)


func _give_reward(player: Node) -> void:
	if _reward_type == "weapon":
		player.add_weapon(_reward_key)
	else:
		var buff_type: int = int(_reward_key)
		var duration := randf_range(BUFF_DURATION_MIN, BUFF_DURATION_MAX)
		player.add_buff(buff_type, duration)
		if buff_type == 2:  # REVIVE
			GameManager.revive_coins += 1
			GameManager.post_message("获得复活币 +1", Color(1.0, 0.84, 0.0))

	opened.emit(_reward_type, _reward_key)
	_spawn_label()
	# 闪烁 3 次后缩小消失
	var tween := create_tween()
	tween.set_parallel(false)
	for i in 3:
		tween.tween_property(self, "modulate", Color(1, 1, 1, 0.2), 0.06)
		tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.06)
	tween.tween_property(self, "scale", Vector2.ZERO, 0.15).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)


func _give_start_supply(player: Node) -> void:
	var candidates: Array[String] = []
	for key in START_SUPPLY_WEAPON_KEYS:
		if not player.has_weapon(key):
			candidates.append(key)
	if candidates.is_empty():
		candidates = START_SUPPLY_WEAPON_KEYS.duplicate()
	candidates.shuffle()

	var key: String = candidates[0]
	var added: bool = player.add_weapon(key)
	if not added:
		for i in player._weapon_keys.size():
			if player._weapon_keys[i] == key:
				player._weapon_index = i
				GameManager.player_data.weapon_index = i
				break

	var weapon_name: String = player.WEAPONS[key].name
	var icon := load(START_SUPPLY_WEAPON_ICONS[key]) as Texture2D
	if icon != null and player.has_method("queue_head_banner"):
		player.queue_head_banner(icon)
	_show_scene_hint("获得补给：%s" % weapon_name, Color(0.0, 0.898, 1.0))
	_show_scene_hint("按 Q 可以切换武器", Color(1.0, 0.94, 0.62))
	opened.emit("weapon", key)

	var tween := create_tween()
	tween.set_parallel(false)
	for i in 3:
		tween.tween_property(self, "modulate", Color(1, 1, 1, 0.25), 0.06)
		tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.06)
	tween.tween_property(self, "scale", Vector2.ZERO, 0.18).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)


func _show_scene_hint(text: String, color: Color) -> void:
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("_show_message_hint"):
		scene.call("_show_message_hint", text, color)
	elif scene != null and scene.has_method("_show_hint"):
		scene.call("_show_hint", text, color)


func _load_gold_chest_frames() -> void:
	_gold_chest_frames.clear()
	for path in GOLD_CHEST_FRAME_PATHS:
		var texture := load(path) as Texture2D
		if texture != null:
			_gold_chest_frames.append(texture)


func _configure_start_supply_collision() -> void:
	var shape_node := get_node_or_null("CollisionShape") as CollisionShape2D
	if shape_node == null:
		return
	var circle := shape_node.shape as CircleShape2D
	if circle != null:
		circle.radius = 46.0


# ── 武器 3 选 1 ──────────────────────────────────────────

func _show_weapon_choice(player: Node) -> void:
	GameManager.change_state(GameManager.GameState.PAUSED)

	var all_keys: Array = player.WEAPONS.keys()
	# 排除已有的，优先选未拥有的
	var candidates: Array = []
	for key in all_keys:
		if not player.has_weapon(key):
			candidates.append(key)
	# 如果不够 3 个，补上已有的
	if candidates.size() < 3:
		for key in all_keys:
			if key not in candidates:
				candidates.append(key)
			if candidates.size() >= 3:
				break
	candidates.shuffle()
	var options: Array = candidates.slice(0, mini(3, candidates.size()))

	var canvas := CanvasLayer.new()
	canvas.layer = 29
	add_child(canvas)

	# 半透明背景
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.65)
	bg.size = VS.VIEWPORT_SIZE
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	canvas.add_child(bg)

	# 标题
	var title := Label.new()
	title.text = "选择初始武器"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(330, 80)
	title.size = Vector2(300, 40)
	canvas.add_child(title)

	# 三个武器面板
	var panel_w := int(VS.WEAPON_CHOICE_CARD_SIZE.x)
	var panel_h := int(VS.WEAPON_CHOICE_CARD_SIZE.y)
	var gap := 20
	var total_w := panel_w * 3 + gap * 2
	var start_x := (VS.VIEWPORT_SIZE.x - total_w) / 2
	var start_y := 140

	for i in options.size():
		var key: String = options[i]
		var weapon: Dictionary = player.WEAPONS[key]
		var px := start_x + i * (panel_w + gap)
		_create_weapon_panel(canvas, weapon, key, player, Vector2(px, start_y), Vector2(panel_w, panel_h))


func _create_weapon_panel(canvas: CanvasLayer, weapon: Dictionary, key: String, player: Node, pos: Vector2, sz: Vector2) -> void:
	var panel := PanelContainer.new()
	panel.position = pos
	panel.size = sz

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.15)
	style.border_color = Color(0.0, 0.898, 1.0)
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	# 武器名
	var name_label := Label.new()
	name_label.text = weapon.name
	name_label.add_theme_font_size_override("font_size", 24)
	name_label.add_theme_color_override("font_color", Color(0.0, 0.898, 1.0))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_label)

	# 武器类型
	var type_label := Label.new()
	type_label.text = _get_weapon_type_text(weapon)
	type_label.add_theme_font_size_override("font_size", 14)
	type_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(type_label)

	# 属性
	var stats := []
	stats.append_array(_get_weapon_stats(weapon))

	for stat in stats:
		var stat_label := Label.new()
		stat_label.text = stat
		stat_label.add_theme_font_size_override("font_size", 16)
		stat_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		stat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(stat_label)

	# 已拥有标记
	if player.has_weapon(key):
		var owned := Label.new()
		owned.text = "[ 已拥有 ]"
		owned.add_theme_font_size_override("font_size", 14)
		owned.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))
		owned.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(owned)

	panel.gui_input.connect(_on_weapon_panel_input.bind(key, player, canvas))
	panel.mouse_entered.connect(func():
		style.bg_color = Color(0.2, 0.2, 0.25)
		style.border_color = Color(0.3, 1.0, 1.0)
	)
	panel.mouse_exited.connect(func():
		style.bg_color = Color(0.12, 0.12, 0.15)
		style.border_color = Color(0.0, 0.898, 1.0)
	)

	canvas.add_child(panel)


func _on_weapon_panel_input(event: InputEvent, key: String, player: Node, canvas: CanvasLayer) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var added: bool = player.add_weapon(key)
		var weapon_name: String = player.WEAPONS[key].name
		if added:
			_show_pick_label(weapon_name, Color(0.0, 0.898, 1.0))
		else:
			# 已有武器，切换到该武器
			for i in player._weapon_keys.size():
				if player._weapon_keys[i] == key:
					player._weapon_index = i
					break
			_show_pick_label(weapon_name + " (切换)", Color(0.5, 0.5, 0.5))
		canvas.queue_free()
		GameManager.change_state(GameManager.GameState.PLAYING)
		var tween := create_tween()
		tween.tween_property(self, "scale", Vector2.ZERO, 0.2).set_ease(Tween.EASE_IN)
		tween.tween_callback(queue_free)


func _get_weapon_type_text(weapon: Dictionary) -> String:
	match weapon.type:
		"basketball":
			return "投射"
		"room_blast":
			return "全屏"
		"rooster":
			return "追击"
		"man_gun":
			return "锁定枪械"
		"laser_gun":
			return "持续激光"
	return "武器"


func _get_weapon_stats(weapon: Dictionary) -> Array[String]:
	match weapon.type:
		"basketball":
			return [
				"伤害: %d" % weapon.damage,
				"普通: 散弹%d发 %.2fs" % [weapon.count, weapon.cooldown],
				"狂暴: 连点全场投篮",
				"蓝耗: 0",
			]
		"room_blast":
			return [
				"伤害: %d / 全房间" % weapon.damage,
				"普通: %.1fs" % weapon.cooldown,
				"狂暴: 3次 间隔%.1fs" % weapon.berserk_interval,
				"蓝耗: 0",
			]
		"rooster":
			return [
				"伤害: %d" % weapon.damage,
				"普通: 1只 CD%.1fs" % weapon.cooldown,
				"狂暴: %d只 CD%.1fs" % [weapon.berserk_count, weapon.berserk_cooldown],
				"蓝耗: 0",
			]
		"man_gun":
			return [
				"伤害: %d / 范围%d" % [weapon.damage, weapon.aoe_damage],
				"普通: 最近锁定 CD%.1fs" % weapon.cooldown,
				"狂暴: 全体锁定 CD%.1fs" % weapon.berserk_cooldown,
				"蓝耗: 0",
			]
		"laser_gun":
			return [
				"伤害: %d / 跳" % weapon.damage,
				"普通: 按住直线持续激光",
				"狂暴: 折射2次",
				"蓝耗: 0",
			]
	return ["伤害: %d" % weapon.damage]


func _show_pick_label(text: String, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", color)
	label.position = global_position + Vector2(-20, -30)
	label.z_index = 100
	get_tree().current_scene.add_child(label)
	var tween := create_tween()
	tween.tween_property(label, "position:y", label.position.y - 30, 0.8)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.8)
	tween.tween_callback(label.queue_free)


func _spawn_label() -> void:
	var label := Label.new()
	label.text = _reward_name
	label.add_theme_font_size_override("font_size", 16)
	var color := Color(1.0, 0.84, 0.0) if _reward_type == "weapon" else Color(0.3, 0.8, 1.0)
	label.add_theme_color_override("font_color", color)
	label.position = global_position + Vector2(-20, -30)
	label.z_index = 100
	get_tree().current_scene.add_child(label)
	var tween := create_tween()
	tween.tween_property(label, "position:y", label.position.y - 30, 0.8)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.8)
	tween.tween_callback(label.queue_free)


func _draw() -> void:
	var y_off := sin(_bounce_timer) * 3.0
	var base := Vector2(0, y_off)
	if is_start_supply and not _gold_chest_frames.is_empty():
		var texture := _gold_chest_frames[_gold_frame_index]
		var size := Vector2(GOLD_CHEST_DISPLAY_SIZE, GOLD_CHEST_DISPLAY_SIZE)
		draw_texture_rect(texture, Rect2(base - size * 0.5, size), false)
		if not _opened:
			var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.01)
			draw_arc(base, GOLD_CHEST_DISPLAY_SIZE * 0.42 + pulse * 3.0, 0.0, TAU, 32, Color(1.0, 0.84, 0.0, 0.35 + pulse * 0.2), 2.0)
			if _near_player != null and is_instance_valid(_near_player):
				draw_string(ThemeDB.fallback_font, Vector2(-48, -GOLD_CHEST_DISPLAY_SIZE * 0.5 - 18), "按 E 获取补给", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1.0, 1.0, 0.6))
		return
	var col_body := Color(0.2, 0.55, 0.7) if is_weapon_choice else Color(0.55, 0.35, 0.1)
	var col_lid := Color(0.25, 0.7, 0.9) if is_weapon_choice else Color(0.7, 0.45, 0.15)
	var col_lock := Color(0.0, 0.898, 1.0) if is_weapon_choice else Color(1.0, 0.84, 0.0)
	var size := VS.CHEST_DISPLAY_SIZE
	# 箱体
	draw_rect(Rect2(base + Vector2(-size * 0.44, -size * 0.18), Vector2(size * 0.88, size * 0.56)), col_body)
	# 箱盖
	draw_rect(Rect2(base + Vector2(-size * 0.5, -size * 0.38), Vector2(size, size * 0.24)), col_lid)
	# 锁扣
	draw_rect(Rect2(base + Vector2(-size * 0.12, -size * 0.3), Vector2(size * 0.24, size * 0.16)), col_lock)
	# 高光
	draw_rect(Rect2(base + Vector2(-size * 0.34, -size * 0.12), Vector2(size * 0.08, size * 0.32)), col_lid.lightened(0.3).darkened(0.2))
