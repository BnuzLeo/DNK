extends Node2D

## 练习生基地 — 游戏大厅

const VS := preload("res://scripts/visual_spec.gd")
const SHOCKWAVE_EFFECT := preload("res://scripts/shockwave_effect.gd")
const LOBBY_MUSIC := preload("res://assets/music/dialogue/鸡你太美.wav")
const BULLET_POOL_SCRIPT := preload("res://scripts/bullet_pool.gd")
const PLAYER_SCRIPT := preload("res://scripts/player.gd")
const EQUIPMENT_PANEL_SCRIPT := preload("res://scripts/equipment_panel.gd")

const BLUE_SHOCKWAVE_SHEET := "res://assets/export/effects/shockwave_blue_sheet.png"
const GUI_STATUS_BAR := preload("res://assets/export/gui/状态栏.png")
const GUI_SKILL_FRAME := preload("res://assets/export/gui/技能框.png")
const GUI_ATTACK_LOGO := preload("res://assets/export/gui/攻击logo.png")
const STATUS_SCALE := 1.73
const STATUS_POS := Vector2(24.0, 20.0)
const STATUS_FILL_W := 59.0 * STATUS_SCALE
const STATUS_FILL_H := 5.5 * STATUS_SCALE
const ACTION_FRAME_SIZE := Vector2(50.67, 50.67)
const ACTION_CONTROL_SIZE := Vector2(50.67, 78.0)
const ACTION_ROW_Y := 530.0
const ACTION_Q_X := 646.0
const ACTION_J_X := 716.0
const ACTION_K_X := 786.0
const ACTION_L_X := 856.0
const ACTION_KEY_Y := 55.0
const ACTION_KEY_COLOR := Color(0.78, 0.88, 0.94)
const PLAYER_TOP_Z_INDEX := 1000

const ROOM_W := int(VS.VIEWPORT_SIZE.x)
const ROOM_H := int(VS.VIEWPORT_SIZE.y)
const WALL_T := int(VS.WALL_THICKNESS)

var _player: CharacterBody2D
var _bullet_pool: Node2D
var _portal_pos := Vector2(480, 120)
var _portal_near := false
var _portal_sprite: TransferPortal
var _anim_timer := 0.0
var _lobby_music: AudioStreamPlayer

# HUD
var _practice_label: Label
var _coin_label: Label
var _fps_label: Label
var _kills_label: Label
var _weapon_label: Label
var _hp_bar: ColorRect
var _hp_bar_bg: ColorRect
var _hp_text: Label
var _shield_bar: ColorRect
var _shield_bar_bg: ColorRect
var _shield_text: Label
var _mana_bar: ColorRect
var _mana_bar_bg: ColorRect
var _mana_text: Label
var _dash_icon: Control
var _berserk_icon: Control
var _attack_icon: Control
var _switch_icon: Control
var _buff_bar: Control
var _hud_frame: Control
var _coin_panel: Control
var _practice_panel: Control
var _bag_button: Control

# 地图选择
var _map_select_open := false
var _map_select_canvas: CanvasLayer
var _current_map_index := 0
var _map_names := ["冰封篮球场", "练习生雨林", "流量和爆炸"]
var _map_cards: Array[Control] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameManager.change_state(GameManager.GameState.LOBBY)
	_start_lobby_music()
	_create_walls()
	_setup_lobby_object_collisions()
	_create_bullet_pool()
	_create_player()
	_setup_npcs()
	_setup_lobby_portal()
	_create_hud()


func _start_lobby_music() -> void:
	_lobby_music = AudioStreamPlayer.new()
	_lobby_music.bus = "Master"
	_lobby_music.volume_db = -4.0
	_lobby_music.stream = LOBBY_MUSIC
	_lobby_music.finished.connect(_replay_lobby_music)
	add_child(_lobby_music)
	_lobby_music.play()


func _replay_lobby_music() -> void:
	if _lobby_music != null and is_instance_valid(_lobby_music):
		_lobby_music.play()


func _setup_lobby_portal() -> void:
	_portal_sprite = get_node_or_null("LobbyPortal") as TransferPortal
	if _portal_sprite == null:
		_portal_sprite = TransferPortal.new()
		_portal_sprite.name = "LobbyPortal"
		_portal_sprite.position = _portal_pos
		add_child(_portal_sprite)
	_portal_pos = _portal_sprite.position
	_portal_sprite.z_index = 5
	_portal_sprite.setup(VS.PORTAL_LOBBY_DISPLAY_SIZE * 2.5)


func _create_walls() -> void:
	_make_wall(Vector2(ROOM_W / 2.0, WALL_T / 2.0), Vector2(ROOM_W, WALL_T))
	_make_wall(Vector2(ROOM_W / 2.0, ROOM_H - WALL_T / 2.0), Vector2(ROOM_W, WALL_T))
	_make_wall(Vector2(WALL_T / 2.0, ROOM_H / 2.0), Vector2(WALL_T, ROOM_H))
	_make_wall(Vector2(ROOM_W - WALL_T / 2.0, ROOM_H / 2.0), Vector2(WALL_T, ROOM_H))


func _make_wall(pos: Vector2, size: Vector2) -> void:
	var wall := StaticBody2D.new()
	wall.position = pos
	wall.collision_layer = 16
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	wall.add_child(shape)
	add_child(wall)


func _setup_lobby_object_collisions() -> void:
	var objects_root: Node = get_node_or_null("LobbyObjects")
	if objects_root == null:
		return
	var old_collisions_root: Node = get_node_or_null("GeneratedLobbyObjectCollisions")
	if old_collisions_root != null:
		remove_child(old_collisions_root)
		old_collisions_root.queue_free()
	var collisions_root: Node2D = Node2D.new()
	collisions_root.name = "GeneratedLobbyObjectCollisions"
	add_child(collisions_root)
	for object_node in objects_root.get_children():
		var sprite: Sprite2D = object_node as Sprite2D
		if sprite == null or sprite.texture == null:
			continue
		var texture_size: Vector2 = Vector2(sprite.texture.get_size())
		var scale_abs: Vector2 = Vector2(maxf(absf(sprite.scale.x), 0.001), maxf(absf(sprite.scale.y), 0.001))
		var display_size: Vector2 = texture_size * scale_abs
		var footprint_h: float = clampf(display_size.y * 0.22, 16.0, 50.0)
		var footprint_w: float = clampf(display_size.x * 0.68, 20.0, maxf(20.0, display_size.x * 0.9))
		var footprint_size: Vector2 = Vector2(footprint_w, footprint_h)
		var offset: Vector2 = _get_lobby_object_collision_offset(sprite, display_size, footprint_h)

		var body: StaticBody2D = StaticBody2D.new()
		body.name = "%sCollision" % sprite.name
		body.collision_layer = 16
		body.collision_mask = 0
		var shape: CollisionShape2D = CollisionShape2D.new()
		var rect: RectangleShape2D = RectangleShape2D.new()
		rect.size = footprint_size
		shape.position = offset
		shape.shape = rect
		body.add_child(shape)
		collisions_root.add_child(body)
		body.global_position = sprite.global_position


func _get_lobby_object_collision_offset(sprite: Sprite2D, texture_size: Vector2, footprint_h: float) -> Vector2:
	if sprite.centered:
		return Vector2(0.0, texture_size.y * 0.5 - footprint_h * 0.5)
	return Vector2(texture_size.x * 0.5, texture_size.y - footprint_h * 0.5)


func _get_portal_position() -> Vector2:
	if _portal_sprite != null and is_instance_valid(_portal_sprite):
		return _portal_sprite.global_position
	return _portal_pos


func _create_bullet_pool() -> void:
	_bullet_pool = Node2D.new()
	_bullet_pool.name = "BulletPool"
	_bullet_pool.set_script(BULLET_POOL_SCRIPT)
	add_child(_bullet_pool)


func _create_player() -> void:
	_player = CharacterBody2D.new()
	_player.position = Vector2(480, 450)
	_player.z_index = PLAYER_TOP_Z_INDEX
	_player.set_script(PLAYER_SCRIPT)

	var col := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 16.0
	col.shape = circle
	_player.add_child(col)

	var cam := Camera2D.new()
	cam.offset = VS.CAMERA_LOBBY_BASE_OFFSET
	cam.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = VS.CAMERA_SMOOTH_SPEED
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = ROOM_W
	cam.limit_bottom = ROOM_H
	_player.add_child(cam)

	add_child(_player)
	_play_player_spawn_warning(_player)


func _play_player_spawn_warning(player: CharacterBody2D) -> void:
	player.visible = false
	player.set_physics_process(false)
	player.set_process_input(false)
	var effect = SHOCKWAVE_EFFECT.new()
	effect.global_position = player.global_position
	add_child(effect)
	effect.setup(BLUE_SHOCKWAVE_SHEET, Color(0.25, 0.65, 1.0, 0.9), 150.0, Callable(self, "_finish_player_spawn_warning").bind(player))


func _finish_player_spawn_warning(player: CharacterBody2D) -> void:
	if player == null or not is_instance_valid(player):
		return
	player.visible = true
	player.set_physics_process(true)
	player.set_process_input(true)


func _setup_npcs() -> void:
	_setup_npc(get_node_or_null("LobbyNPCs/Broker") as Area2D, "broker", "尖叫鸡", Color(0.9, 0.7, 0.2))
	_setup_npc(get_node_or_null("LobbyNPCs/Smith") as Area2D, "smith", "卡皮巴拉", Color(0.5, 0.6, 0.8))


func _setup_npc(npc: Area2D, type: String, label: String, color: Color) -> void:
	if npc == null:
		return
	npc.set("npc_type", type)
	npc.set("display_name", label)
	npc.set("npc_color", color)
	if npc.get_node_or_null("InteractionCollision") == null:
		var collision: CollisionShape2D = CollisionShape2D.new()
		collision.name = "InteractionCollision"
		var circle: CircleShape2D = CircleShape2D.new()
		circle.radius = 40.0
		collision.shape = circle
		npc.add_child(collision)

var _hud_canvas: CanvasLayer
var _equipment_panel: Node = null


func _create_hud() -> void:
	_hud_canvas = CanvasLayer.new()
	_hud_canvas.layer = 10
	_hud_canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_hud_canvas)

	_fps_label = Label.new()
	_fps_label.visible = false
	_hud_canvas.add_child(_fps_label)

	_kills_label = Label.new()
	_kills_label.visible = false
	_hud_canvas.add_child(_kills_label)

	_hud_frame = Control.new()
	_hud_frame.position = STATUS_POS
	_hud_frame.size = Vector2(79, 39) * STATUS_SCALE
	_hud_frame.z_index = 2
	_hud_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_frame.draw.connect(_draw_stats_frame)
	_hud_canvas.add_child(_hud_frame)

	_hp_bar_bg = ColorRect.new()
	_hp_bar_bg.position = STATUS_POS + Vector2(15, 4) * STATUS_SCALE
	_hp_bar_bg.size = Vector2(STATUS_FILL_W, STATUS_FILL_H)
	_hp_bar_bg.z_index = 0
	_hp_bar_bg.color = Color(0.08, 0.04, 0.03, 0.55)
	_hud_canvas.add_child(_hp_bar_bg)

	_hp_bar = ColorRect.new()
	_hp_bar.position = _hp_bar_bg.position
	_hp_bar.size = _hp_bar_bg.size
	_hp_bar.z_index = 0
	_hp_bar.color = Color(0.88, 0.07, 0.15)
	_hud_canvas.add_child(_hp_bar)

	_hp_text = _make_hud_value_label(STATUS_POS + Vector2(60, 3), Color.WHITE)
	_hp_text.z_index = 1
	_hud_canvas.add_child(_hp_text)

	_shield_bar_bg = ColorRect.new()
	_shield_bar_bg.position = STATUS_POS + Vector2(15, 16) * STATUS_SCALE
	_shield_bar_bg.size = Vector2(STATUS_FILL_W, STATUS_FILL_H)
	_shield_bar_bg.z_index = 0
	_shield_bar_bg.color = Color(0.06, 0.07, 0.08, 0.55)
	_hud_canvas.add_child(_shield_bar_bg)

	_shield_bar = ColorRect.new()
	_shield_bar.position = _shield_bar_bg.position
	_shield_bar.size = _shield_bar_bg.size
	_shield_bar.z_index = 0
	_shield_bar.color = Color(0.78, 0.85, 0.9)
	_hud_canvas.add_child(_shield_bar)

	_shield_text = _make_hud_value_label(STATUS_POS + Vector2(60, 34), Color.WHITE)
	_shield_text.z_index = 1
	_hud_canvas.add_child(_shield_text)

	_mana_bar_bg = ColorRect.new()
	_mana_bar_bg.position = STATUS_POS + Vector2(15, 28) * STATUS_SCALE
	_mana_bar_bg.size = Vector2(STATUS_FILL_W, STATUS_FILL_H)
	_mana_bar_bg.z_index = 0
	_mana_bar_bg.color = Color(0.04, 0.05, 0.12, 0.55)
	_hud_canvas.add_child(_mana_bar_bg)

	_mana_bar = ColorRect.new()
	_mana_bar.position = _mana_bar_bg.position
	_mana_bar.size = _mana_bar_bg.size
	_mana_bar.z_index = 0
	_mana_bar.color = Color(0.22, 0.33, 0.9)
	_hud_canvas.add_child(_mana_bar)

	_mana_text = _make_hud_value_label(STATUS_POS + Vector2(60, 65), Color.WHITE)
	_mana_text.z_index = 1
	_hud_canvas.add_child(_mana_text)

	_weapon_label = Label.new()
	_weapon_label.visible = false
	_hud_canvas.add_child(_weapon_label)

	_practice_panel = Control.new()
	_practice_panel.position = Vector2(656, 16)
	_practice_panel.size = Vector2(144, 36)
	_practice_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_practice_panel.draw.connect(_draw_practice_panel)
	_hud_canvas.add_child(_practice_panel)

	_practice_label = Label.new()
	_practice_label.position = Vector2(694, 18)
	_practice_label.size = Vector2(96, 22)
	_practice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_practice_label.add_theme_font_size_override("font_size", 18)
	_practice_label.add_theme_color_override("font_color", Color.WHITE)
	_hud_canvas.add_child(_practice_label)

	_coin_panel = Control.new()
	_coin_panel.position = Vector2(814, 16)
	_coin_panel.size = Vector2(96, 36)
	_coin_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_coin_panel.draw.connect(_draw_coin_panel)
	_hud_canvas.add_child(_coin_panel)

	_coin_label = Label.new()
	_coin_label.position = Vector2(846, 18)
	_coin_label.size = Vector2(56, 22)
	_coin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_coin_label.add_theme_font_size_override("font_size", 18)
	_coin_label.add_theme_color_override("font_color", Color.WHITE)
	_hud_canvas.add_child(_coin_label)

	_bag_button = Control.new()
	_bag_button.position = Vector2(622, 14)
	_bag_button.size = Vector2(28, 36)
	_bag_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_bag_button.draw.connect(_draw_bag_button)
	_bag_button.gui_input.connect(_on_bag_button_input)
	_hud_canvas.add_child(_bag_button)

	_attack_icon = Control.new()
	_attack_icon.position = Vector2(ACTION_J_X, ACTION_ROW_Y)
	_attack_icon.size = ACTION_CONTROL_SIZE
	_attack_icon.mouse_filter = Control.MOUSE_FILTER_STOP
	_attack_icon.draw.connect(_draw_attack_icon)
	_attack_icon.gui_input.connect(_on_action_button_input.bind("shoot"))
	_hud_canvas.add_child(_attack_icon)

	_switch_icon = Control.new()
	_switch_icon.position = Vector2(ACTION_Q_X, ACTION_ROW_Y)
	_switch_icon.size = ACTION_CONTROL_SIZE
	_switch_icon.mouse_filter = Control.MOUSE_FILTER_STOP
	_switch_icon.draw.connect(_draw_switch_icon)
	_switch_icon.gui_input.connect(_on_action_button_input.bind("switch_weapon"))
	_hud_canvas.add_child(_switch_icon)

	_dash_icon = Control.new()
	_dash_icon.position = Vector2(ACTION_K_X, ACTION_ROW_Y)
	_dash_icon.size = ACTION_CONTROL_SIZE
	_dash_icon.mouse_filter = Control.MOUSE_FILTER_STOP
	_dash_icon.draw.connect(_draw_dash_icon)
	_dash_icon.gui_input.connect(_on_action_button_input.bind("dash"))
	_hud_canvas.add_child(_dash_icon)

	_berserk_icon = Control.new()
	_berserk_icon.position = Vector2(ACTION_L_X, ACTION_ROW_Y)
	_berserk_icon.size = ACTION_CONTROL_SIZE
	_berserk_icon.mouse_filter = Control.MOUSE_FILTER_STOP
	_berserk_icon.draw.connect(_draw_berserk_icon)
	_berserk_icon.gui_input.connect(_on_action_button_input.bind("berserk"))
	_hud_canvas.add_child(_berserk_icon)

	_buff_bar = Control.new()
	_buff_bar.position = Vector2(182, 22)
	_buff_bar.size = Vector2(130, 28)
	_buff_bar.draw.connect(_draw_buff_bar)
	_hud_canvas.add_child(_buff_bar)


func _process(delta: float) -> void:
	_anim_timer += delta

	if _player and is_instance_valid(_player):
		_hp_text.text = "%d/%d" % [_player.hp, _player.MAX_HP]
		_shield_text.text = "%d/%d" % [_player.armor, _player.max_armor]
		_mana_text.text = "%d/%d" % [int(_player.mana), int(_player.MAX_MANA)]

		var mana_ratio: float = _player.mana / _player.MAX_MANA
		_mana_bar.size.x = STATUS_FILL_W * clampf(mana_ratio, 0.0, 1.0)
		var hp_ratio: float = float(_player.hp) / float(_player.MAX_HP)
		_hp_bar.size.x = STATUS_FILL_W * clampf(hp_ratio, 0.0, 1.0)
		_hp_bar.color = Color(0.88, 0.07, 0.15)
		var armor_ratio := 0.0 if _player.max_armor <= 0 else float(_player.armor) / float(_player.max_armor)
		_shield_bar.size.x = STATUS_FILL_W * clampf(armor_ratio, 0.0, 1.0)
		_shield_bar.visible = _player.max_armor > 0
		_shield_bar_bg.visible = _player.max_armor > 0
		_shield_text.visible = _player.max_armor > 0
		_portal_near = _player.global_position.distance_to(_get_portal_position()) < 50.0

		if _attack_icon:
			_attack_icon.queue_redraw()
		if _switch_icon:
			_switch_icon.queue_redraw()
		if _dash_icon:
			_dash_icon.queue_redraw()
		if _berserk_icon:
			_berserk_icon.queue_redraw()
		if _buff_bar:
			_buff_bar.queue_redraw()
		if _bag_button:
			_bag_button.queue_redraw()

	_fps_label.text = "FPS: %d" % Engine.get_frames_per_second()
	_kills_label.text = ""
	_practice_label.text = str(GameManager.practice_time)
	_coin_label.text = str(GameManager.kun_coins)

	queue_redraw()

	if _player and is_instance_valid(_player):
		_portal_near = _player.global_position.distance_to(_get_portal_position()) < 50.0

	queue_redraw()


func _make_hud_value_label(pos: Vector2, color: Color) -> Label:
	var label := Label.new()
	label.position = pos
	label.size = Vector2(96, 16)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	return label


func _draw_stats_frame() -> void:
	_hud_frame.draw_texture_rect(GUI_STATUS_BAR, Rect2(Vector2.ZERO, _hud_frame.size), false)


func _draw_practice_panel() -> void:
	var r := Rect2(Vector2.ZERO, _practice_panel.size)
	_practice_panel.draw_rect(r, Color(0.22, 0.22, 0.24))
	_practice_panel.draw_rect(r.grow(-3), Color(0.34, 0.34, 0.36))
	_practice_panel.draw_circle(Vector2(20, 18), 8.0, Color(1.0, 0.86, 0.12))
	_practice_panel.draw_arc(Vector2(20, 18), 8.0, 0, TAU, 18, Color(0.25, 0.12, 0.02), 2.0)


func _draw_coin_panel() -> void:
	var r := Rect2(Vector2.ZERO, _coin_panel.size)
	_coin_panel.draw_rect(r, Color(0.22, 0.22, 0.24))
	_coin_panel.draw_rect(r.grow(-3), Color(0.34, 0.34, 0.36))
	_coin_panel.draw_circle(Vector2(18, 18), 8.0, Color(1.0, 0.86, 0.12))
	_coin_panel.draw_arc(Vector2(18, 18), 8.0, 0, TAU, 18, Color(0.25, 0.12, 0.02), 2.0)


func _draw_bag_button() -> void:
	var r := Rect2(Vector2.ZERO, _bag_button.size)
	_bag_button.draw_rect(r, Color(0.30, 0.24, 0.16))
	_bag_button.draw_rect(r.grow(-3), Color(0.59, 0.46, 0.28))
	_bag_button.draw_rect(Rect2(7, 10, 14, 14), Color(0.79, 0.66, 0.42))
	_bag_button.draw_rect(Rect2(9, 7, 10, 5), Color(0.79, 0.66, 0.42))
	_bag_button.draw_arc(Vector2(14, 11), 4.0, PI, TAU, 10, Color(0.35, 0.22, 0.10), 1.5)
	_draw_button_key(_bag_button, "B", Color(0.98, 0.90, 0.62))


func _draw_button_key(ctrl: Control, key: String, color: Color = Color.WHITE) -> void:
	var font := ThemeDB.fallback_font
	var font_size := 16
	var text_size := font.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var pos := (ctrl.size - text_size) / 2.0
	ctrl.draw_string(font, pos + Vector2(0, text_size.y), key, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _draw_action_key(ctrl: Control, key: String, color: Color = Color.WHITE) -> void:
	var font: Font = ThemeDB.fallback_font
	var font_size: int = 14
	var text_size: Vector2 = font.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var x: float = (ACTION_FRAME_SIZE.x - text_size.x) * 0.5
	var pos: Vector2 = Vector2(x, ACTION_KEY_Y + text_size.y)
	ctrl.draw_string(font, pos + Vector2(1, 1), key, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0, 0, 0, 0.8))
	ctrl.draw_string(font, pos, key, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _draw_attack_icon() -> void:
	var center: Vector2 = ACTION_FRAME_SIZE / 2.0
	_attack_icon.draw_texture_rect(GUI_SKILL_FRAME, Rect2(Vector2.ZERO, ACTION_FRAME_SIZE), false)
	var logo_size: Vector2 = Vector2(28, 28)
	var logo_rect: Rect2 = Rect2((ACTION_FRAME_SIZE - logo_size) * 0.5, logo_size)
	_attack_icon.draw_texture_rect(GUI_ATTACK_LOGO, logo_rect, false)
	var attack_cd_ratio: float = float(_player.call("get_fire_cooldown_ratio"))
	if attack_cd_ratio > 0.0:
		_draw_action_cooldown_overlay(_attack_icon, center, attack_cd_ratio)
	_draw_action_key(_attack_icon, "J", ACTION_KEY_COLOR)


func _draw_switch_icon() -> void:
	_switch_icon.draw_texture_rect(GUI_SKILL_FRAME, Rect2(Vector2.ZERO, ACTION_FRAME_SIZE), false)
	_draw_action_key(_switch_icon, "Q", ACTION_KEY_COLOR)


func _draw_dash_icon() -> void:
	var center: Vector2 = ACTION_FRAME_SIZE / 2.0
	_dash_icon.draw_texture_rect(GUI_SKILL_FRAME, Rect2(Vector2.ZERO, ACTION_FRAME_SIZE), false)
	var dash_cd: float = _player._dash_cooldown
	if dash_cd > 0.0:
		var cd_ratio: float = clampf(dash_cd / _player.DASH_COOLDOWN, 0.0, 1.0)
		_draw_action_cooldown_overlay(_dash_icon, center, cd_ratio)
	_draw_action_key(_dash_icon, "K", ACTION_KEY_COLOR)


func _draw_action_cooldown_overlay(ctrl: Control, center: Vector2, cd_ratio: float) -> void:
	var radius: float = ACTION_FRAME_SIZE.x * 0.36
	var points := PackedVector2Array()
	points.append(center)
	var segments := 24
	var sweep: float = TAU * cd_ratio
	for i in segments + 1:
		var angle: float = -PI / 2 + sweep * i / segments
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	if points.size() >= 3:
		ctrl.draw_colored_polygon(points, Color(0, 0, 0, 0.55))


func _draw_berserk_icon() -> void:
	_berserk_icon.draw_texture_rect(GUI_SKILL_FRAME, Rect2(Vector2.ZERO, ACTION_FRAME_SIZE), false)
	_draw_action_key(_berserk_icon, "L", ACTION_KEY_COLOR)


func _draw_buff_bar() -> void:
	var buffs: Dictionary = _player.get_active_buffs()
	var x := 0
	for type in buffs:
		var info: Dictionary = _player.BUFF_INFO[type]
		var stacks: int = buffs[type].stacks
		var time_left: float = buffs[type].time
		var color: Color = info.color
		var icon: String = info.icon
		var panel_w := 28
		var center := Vector2(x + 14, 14)
		_buff_bar.draw_circle(center, 13.0, Color(0.2, 0.13, 0.08, 0.75))
		_buff_bar.draw_arc(center, 13.0, 0, TAU, 18, color.darkened(0.25), 2.0)
		_buff_bar.draw_string(ThemeDB.fallback_font, Vector2(x + 8, 19), icon, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, color)
		if stacks > 1:
			_buff_bar.draw_string(ThemeDB.fallback_font, Vector2(x + 16, 26), "%d" % stacks, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color.WHITE)
		var time_ratio := clampf(time_left / 30.0, 0.0, 1.0)
		_buff_bar.draw_rect(Rect2(x + 3, 25, 22 * time_ratio, 2), color)
		x += panel_w + 5


func _on_action_button_input(event: InputEvent, action: String) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_emit_virtual_action(action, event.pressed)
	elif event is InputEventScreenTouch:
		_emit_virtual_action(action, event.pressed)


func _on_bag_button_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_open_equipment_panel()
	elif event is InputEventScreenTouch and event.pressed:
		_open_equipment_panel()


func _emit_virtual_action(action: String, pressed: bool) -> void:
	var input_event := InputEventAction.new()
	input_event.action = action
	input_event.pressed = pressed
	Input.parse_input_event(input_event)


func _input(event: InputEvent) -> void:
	# 地图选择界面的输入
	if _map_select_open:
		if event is InputEventKey and event.pressed:
			get_viewport().set_input_as_handled()
			if event.keycode == KEY_ESCAPE:
				_close_map_select()
		return

	if GameManager.state != GameManager.GameState.LOBBY:
		return

	# B键打开装备背包
	if event is InputEventKey and event.pressed and event.keycode == KEY_B:
		get_viewport().set_input_as_handled()
		_open_equipment_panel()
		return

	# 副本入口 — 打开地图选择
	if event.is_action_pressed("interact") and _portal_near and not _map_select_open:
		_open_map_select()
		return


# ── 地图选择 ──────────────────────────────────────────

func _open_map_select() -> void:
	_map_select_open = true
	_current_map_index = 0
	GameManager.change_state(GameManager.GameState.PAUSED)
	_map_select_canvas = CanvasLayer.new()
	_map_select_canvas.layer = 29
	_map_select_canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_map_select_canvas)

	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0)
	bg.size = VS.VIEWPORT_SIZE
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_map_select_canvas.add_child(bg)

	var window_size := VS.VIEWPORT_SIZE * 0.70
	var window_pos := (VS.VIEWPORT_SIZE - window_size) * 0.5
	var window := Control.new()
	window.position = window_pos
	window.size = window_size
	window.clip_contents = true
	window.mouse_filter = Control.MOUSE_FILTER_STOP
	window.draw.connect(_draw_map_select_backdrop.bind(window))
	_map_select_canvas.add_child(window)

	var title := Label.new()
	title.text = "关卡模式"
	title.position = Vector2((window_size.x - 180.0) * 0.5, 14)
	title.size = Vector2(180, 42)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 2)
	window.add_child(title)

	var close_button := Button.new()
	close_button.text = "X"
	close_button.position = Vector2(window_size.x - 48, 14)
	close_button.size = Vector2(34, 34)
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.add_theme_font_size_override("font_size", 22)
	close_button.add_theme_color_override("font_color", Color.WHITE)
	close_button.add_theme_stylebox_override("normal", _make_flat_style(Color(0.72, 0.04, 0.12), Color(0.18, 0.0, 0.02), 0, 3))
	close_button.add_theme_stylebox_override("hover", _make_flat_style(Color(0.95, 0.08, 0.16), Color(0.22, 0.0, 0.02), 0, 3))
	close_button.add_theme_stylebox_override("pressed", _make_flat_style(Color(0.48, 0.02, 0.08), Color(0.10, 0.0, 0.02), 0, 3))
	close_button.pressed.connect(_close_map_select)
	window.add_child(close_button)

	var tab_size := Vector2(96, 58)
	var card_size := Vector2(156, 216)
	var card_gap := 14.0
	var group_gap := 18.0
	var card_y := 82.0
	var content_w := tab_size.x + group_gap + card_size.x * 3.0 + card_gap * 2.0
	var content_x := (window_size.x - content_w) * 0.5
	var card_start_x := content_x + tab_size.x + group_gap
	var tabs_h := tab_size.y * 3.0 + 10.0 * 2.0
	var tab_start_y := card_y + (card_size.y - tabs_h) * 0.5

	var modes := [
		{"name": "关卡模式", "selected": true, "locked": false},
		{"name": "赛季模式", "selected": false, "locked": true},
		{"name": "古迹战场", "selected": false, "locked": true},
	]
	for i in modes.size():
		var tab := Control.new()
		tab.position = Vector2(content_x, tab_start_y + i * (tab_size.y + 10.0))
		tab.size = tab_size
		tab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tab.draw.connect(_draw_mode_tab.bind(tab, String(modes[i].name), bool(modes[i].selected), bool(modes[i].locked), i))
		window.add_child(tab)

	_map_cards.clear()
	for i in _map_names.size():
		var card := Control.new()
		card.position = Vector2(card_start_x + i * (card_size.x + card_gap), card_y)
		card.size = card_size
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.draw.connect(_draw_map_card.bind(card, i))
		window.add_child(card)
		_map_cards.append(card)

	var start_button := Button.new()
	start_button.text = "开始游玩"
	start_button.position = Vector2((window_size.x - 180.0) * 0.5, 318)
	start_button.size = Vector2(180, 38)
	start_button.focus_mode = Control.FOCUS_NONE
	start_button.add_theme_font_size_override("font_size", 22)
	start_button.add_theme_color_override("font_color", Color.WHITE)
	start_button.add_theme_stylebox_override("normal", _make_flat_style(Color(0.16, 0.78, 0.02), Color(0.02, 0.18, 0.0), 0, 3))
	start_button.add_theme_stylebox_override("hover", _make_flat_style(Color(0.22, 0.94, 0.04), Color(0.02, 0.20, 0.0), 0, 3))
	start_button.add_theme_stylebox_override("pressed", _make_flat_style(Color(0.10, 0.52, 0.02), Color(0.0, 0.12, 0.0), 0, 3))
	start_button.pressed.connect(_enter_dungeon)
	window.add_child(start_button)

	_refresh_map_cards()


func _draw_map_card(card: Control, index: int) -> void:
	var w := card.size.x
	var h := card.size.y
	var available := index == 0

	var bg_color := Color(0.08, 0.095, 0.13, 0.97) if available else Color(0.01, 0.012, 0.018, 0.91)
	card.draw_rect(Rect2(Vector2.ZERO, card.size), bg_color)
	card.draw_rect(Rect2(Vector2(4, 4), card.size - Vector2(8, 8)), Color(0.11, 0.125, 0.16, 0.55) if available else Color(0, 0, 0, 0.45), false, 2.0)
	_draw_corner_caps(card, Rect2(Vector2.ZERO, card.size), available)

	var star_col := Color(0.92, 0.93, 0.94) if available else Color(0.18, 0.18, 0.20)
	if index == 2:
		star_col = Color(0.78, 0.58, 0.12)
	_draw_star(card, Vector2(22, 25), 11.0, star_col)

	var map_name: String = _map_names[index]
	var title_color := Color.WHITE if available else Color(0.28, 0.28, 0.30)
	card.draw_string(ThemeDB.fallback_font, Vector2(42, 32), map_name, HORIZONTAL_ALIGNMENT_LEFT, w - 50, 18, title_color)

	var divider_y := 48.0
	card.draw_line(Vector2(14, divider_y), Vector2(w - 14, divider_y), Color(0.15, 0.17, 0.22, 0.8), 2.0)

	var thumb_rect := Rect2(18, 70, w - 36, 92)
	if available:
		card.draw_string(ThemeDB.fallback_font, Vector2(24, 65), "已有记录: I-I", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.86, 0.88, 0.90))
		_draw_frozen_court_thumbnail(card, thumb_rect)
	else:
		card.draw_rect(thumb_rect, Color(0.02, 0.025, 0.035, 0.95))
		_draw_frozen_court_thumbnail(card, thumb_rect)
		card.draw_rect(Rect2(Vector2.ZERO, card.size), Color(0, 0, 0, 0.62))
		_draw_lock(card, Vector2(w * 0.5, h * 0.48), 36.0)
		var req := "敬请期待"
		var req_size := ThemeDB.fallback_font.get_string_size(req, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
		card.draw_string(ThemeDB.fallback_font, Vector2((w - req_size.x) * 0.5, h - 42), req, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.74, 0.74, 0.74))
		var desc := "敬请期待"
		card.draw_string(ThemeDB.fallback_font, Vector2(18, h - 18), desc, HORIZONTAL_ALIGNMENT_LEFT, w - 36, 11, Color(0.30, 0.30, 0.34))


func _draw_map_select_backdrop(ctrl: Control) -> void:
	var size := ctrl.size
	ctrl.draw_rect(Rect2(Vector2.ZERO, size), Color(0.035, 0.06, 0.075, 1.0))
	var stripe_h := size.y / 12.0
	for i in range(12):
		var t := float(i) / 11.0
		var col := Color(0.05 + t * 0.04, 0.12 + t * 0.12, 0.16 + t * 0.16, 0.24)
		ctrl.draw_rect(Rect2(0, i * stripe_h, size.x, stripe_h), col)
	ctrl.draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.18))
	ctrl.draw_rect(Rect2(Vector2.ZERO, size), Color(0.74, 0.84, 0.90, 0.95), false, 2.0)


func _draw_mode_tab(ctrl: Control, label: String, selected: bool, locked: bool, index: int) -> void:
	var rect := Rect2(Vector2.ZERO, ctrl.size)
	var base := Color(0.04, 0.18, 0.18, 0.96) if selected else Color(0.03, 0.14 + 0.03 * index, 0.19 + 0.02 * index, 0.92)
	if locked:
		base = Color(0.025, 0.03, 0.04, 0.94)
	ctrl.draw_rect(rect, base)
	ctrl.draw_rect(rect, Color(0.94, 0.73, 0.18) if selected else Color(0.02, 0.03, 0.04), false, 2.0)
	ctrl.draw_rect(Rect2(4, 4, rect.size.x - 8, rect.size.y - 8), Color(0.06, 0.34, 0.30, 0.55) if selected else Color(0.06, 0.20, 0.28, 0.50))
	if locked:
		ctrl.draw_rect(Rect2(4, 4, rect.size.x - 8, rect.size.y - 8), Color(0, 0, 0, 0.34))
	var court := Rect2(10, 8, rect.size.x - 20, 28)
	ctrl.draw_rect(court, Color(0.08, 0.45, 0.35) if selected else Color(0.05, 0.28, 0.34))
	ctrl.draw_line(court.position + Vector2(court.size.x * 0.5, 0), court.position + Vector2(court.size.x * 0.5, court.size.y), Color(0.6, 0.95, 0.85, 0.45), 1.0)
	if locked:
		_draw_lock(ctrl, court.get_center(), 14.0)
	elif index == 1:
		_draw_small_demon(ctrl, court.get_center() + Vector2(-10, 0))
		ctrl.draw_circle(court.get_center() + Vector2(16, -2), 8, Color(0.2, 0.9, 1.0, 0.7))
	else:
		_draw_chibi_player(ctrl, court.get_center() + Vector2(-8, 4))
		_draw_basketball(ctrl, court.get_center() + Vector2(18, 3), 5.0)
	if locked:
		var coming_size := ThemeDB.fallback_font.get_string_size("敬请期待", HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
		ctrl.draw_string(ThemeDB.fallback_font, Vector2((rect.size.x - coming_size.x) * 0.5, rect.size.y - 19), "敬请期待", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.72, 0.72, 0.76))
	var text_size := ThemeDB.fallback_font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
	var text_color := Color.WHITE if not locked else Color(0.66, 0.66, 0.70)
	ctrl.draw_string(ThemeDB.fallback_font, Vector2((rect.size.x - text_size.x) * 0.5, rect.size.y - 4), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, text_color)


func _draw_frozen_court_thumbnail(card: Control, rect: Rect2) -> void:
	card.draw_rect(rect, Color(0.04, 0.15, 0.18))
	card.draw_rect(rect.grow(-6), Color(0.06, 0.38, 0.34))
	card.draw_line(Vector2(rect.position.x + rect.size.x * 0.5, rect.position.y + 8), Vector2(rect.position.x + rect.size.x * 0.5, rect.end.y - 8), Color(0.5, 0.9, 0.95, 0.65), 2.0)
	card.draw_arc(rect.get_center(), 22, -PI * 0.5, PI * 0.5, 20, Color(0.65, 0.95, 1.0, 0.5), 2.0)
	card.draw_arc(rect.get_center(), 22, PI * 0.5, PI * 1.5, 20, Color(0.65, 0.95, 1.0, 0.5), 2.0)
	for i in range(5):
		var x := rect.position.x + 12 + i * ((rect.size.x - 24.0) / 4.0)
		card.draw_line(Vector2(x, rect.position.y + 12), Vector2(x + 12, rect.position.y + 28), Color(0.75, 0.95, 1.0, 0.23), 1.0)
		card.draw_line(Vector2(x + 8, rect.end.y - 20), Vector2(x + 23, rect.end.y - 8), Color(0.75, 0.95, 1.0, 0.18), 1.0)
	_draw_chibi_player(card, rect.position + Vector2(rect.size.x * 0.32, rect.size.y * 0.56))
	_draw_chibi_player(card, rect.position + Vector2(rect.size.x * 0.62, rect.size.y * 0.58))
	_draw_chibi_player(card, rect.position + Vector2(rect.size.x * 0.48, rect.size.y * 0.80))
	_draw_basketball(card, rect.position + Vector2(rect.size.x * 0.50, rect.size.y * 0.54), 5.0)
	for p in [rect.position + Vector2(rect.size.x * 0.22, rect.size.y * 0.22), rect.position + Vector2(rect.size.x * 0.78, rect.size.y * 0.30), rect.position + Vector2(rect.size.x * 0.84, rect.size.y * 0.75)]:
		card.draw_circle(p, 3.0, Color(0.65, 0.95, 1.0, 0.9))


func _draw_corner_caps(ctrl: Control, rect: Rect2, bright: bool) -> void:
	var col := Color(0.28, 0.32, 0.42) if bright else Color(0.12, 0.13, 0.16)
	var s := 28.0
	ctrl.draw_colored_polygon(PackedVector2Array([rect.position, rect.position + Vector2(s, 0), rect.position]), col)
	ctrl.draw_rect(Rect2(rect.position, Vector2(s, 5)), col)
	ctrl.draw_rect(Rect2(rect.position, Vector2(5, s)), col)
	ctrl.draw_rect(Rect2(rect.end - Vector2(s, 5), Vector2(s, 5)), col)
	ctrl.draw_rect(Rect2(rect.end - Vector2(5, s), Vector2(5, s)), col)
	ctrl.draw_rect(Rect2(rect.position.x, rect.end.y - 5, s, 5), col)
	ctrl.draw_rect(Rect2(rect.position.x, rect.end.y - s, 5, s), col)
	ctrl.draw_rect(Rect2(rect.end.x - s, rect.position.y, s, 5), col)
	ctrl.draw_rect(Rect2(rect.end.x - 5, rect.position.y, 5, s), col)


func _draw_star(ctrl: Control, center: Vector2, radius: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(10):
		var r := radius if i % 2 == 0 else radius * 0.43
		var a := -PI * 0.5 + float(i) * PI / 5.0
		pts.append(center + Vector2(cos(a), sin(a)) * r)
	ctrl.draw_colored_polygon(pts, color)
	ctrl.draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0, 0, 0, 0.65), 1.0)


func _draw_lock(ctrl: Control, center: Vector2, size: float) -> void:
	var body := Rect2(center.x - size * 0.45, center.y - size * 0.08, size * 0.9, size * 0.65)
	ctrl.draw_arc(center + Vector2(0, -size * 0.08), size * 0.28, PI, TAU, 18, Color(0.86, 0.86, 0.82), size * 0.14)
	ctrl.draw_rect(body, Color(0.86, 0.86, 0.80))
	ctrl.draw_rect(body.grow(-5), Color(0.96, 0.96, 0.90))
	ctrl.draw_circle(center + Vector2(0, size * 0.20), size * 0.07, Color(0.18, 0.18, 0.17))
	ctrl.draw_rect(Rect2(center.x - size * 0.025, center.y + size * 0.20, size * 0.05, size * 0.16), Color(0.18, 0.18, 0.17))


func _draw_basketball(ctrl: Control, pos: Vector2, radius: float) -> void:
	ctrl.draw_circle(pos, radius, Color(0.92, 0.42, 0.08))
	ctrl.draw_arc(pos, radius, -PI * 0.45, PI * 0.45, 12, Color(0.18, 0.08, 0.03), 1.0)
	ctrl.draw_line(pos + Vector2(0, -radius), pos + Vector2(0, radius), Color(0.18, 0.08, 0.03), 1.0)


func _draw_chibi_player(ctrl: Control, pos: Vector2) -> void:
	ctrl.draw_circle(pos + Vector2(0, -10), 8.0, Color(0.96, 0.82, 0.56))
	ctrl.draw_rect(Rect2(pos.x - 7, pos.y - 2, 14, 17), Color(0.18, 0.18, 0.22))
	ctrl.draw_circle(pos + Vector2(-4, -10), 1.5, Color.BLACK)
	ctrl.draw_circle(pos + Vector2(4, -10), 1.5, Color.BLACK)
	ctrl.draw_rect(Rect2(pos.x - 9, pos.y + 10, 6, 9), Color(0.85, 0.85, 0.88))
	ctrl.draw_rect(Rect2(pos.x + 3, pos.y + 10, 6, 9), Color(0.85, 0.85, 0.88))


func _draw_small_demon(ctrl: Control, pos: Vector2) -> void:
	ctrl.draw_circle(pos, 11.0, Color(0.36, 0.08, 0.58))
	ctrl.draw_colored_polygon(PackedVector2Array([pos + Vector2(-8, -6), pos + Vector2(-15, -17), pos + Vector2(-2, -10)]), Color(0.60, 0.12, 0.78))
	ctrl.draw_colored_polygon(PackedVector2Array([pos + Vector2(8, -6), pos + Vector2(15, -17), pos + Vector2(2, -10)]), Color(0.60, 0.12, 0.78))
	ctrl.draw_circle(pos + Vector2(-4, -1), 2.0, Color(0.1, 0, 0))
	ctrl.draw_circle(pos + Vector2(4, -1), 2.0, Color(0.1, 0, 0))


func _make_flat_style(fill: Color, border: Color, radius: int = 0, border_width: int = 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style


func _refresh_map_cards() -> void:
	if _map_cards.is_empty():
		return
	for i in _map_cards.size():
		_map_cards[i].queue_redraw()


func _close_map_select() -> void:
	_map_select_open = false
	if _map_select_canvas:
		_map_select_canvas.queue_free()
		_map_select_canvas = null
	if GameManager.state == GameManager.GameState.PAUSED:
		GameManager.change_state(GameManager.GameState.LOBBY)


func _open_equipment_panel() -> void:
	if _equipment_panel:
		return
	GameManager.change_state(GameManager.GameState.PAUSED)
	_equipment_panel = EQUIPMENT_PANEL_SCRIPT.new()
	_equipment_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	_equipment_panel.tree_exiting.connect(func():
		_equipment_panel = null
		if GameManager.state == GameManager.GameState.PAUSED:
			GameManager.change_state(GameManager.GameState.LOBBY)
	)
	add_child(_equipment_panel)
	_equipment_panel.show_panel(_player)


func _enter_dungeon() -> void:
	_map_select_open = false
	if _map_select_canvas:
		_map_select_canvas.queue_free()
	GameManager.save_lobby_weapons()
	_player.save_to_game_manager()
	get_tree().change_scene_to_file("res://scenes/Main.tscn")


func _draw() -> void:
	if _portal_near and not _map_select_open:
		draw_string(ThemeDB.fallback_font, _get_portal_position() + Vector2(-34, -76), "按 E 交互",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1.0, 1.0, 0.6))
