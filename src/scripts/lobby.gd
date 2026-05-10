extends Node2D

## 练习生基地 — 游戏大厅

const VS := preload("res://scripts/visual_spec.gd")

const LOBBY_MUSIC_PATH := "res://assets/music/鸡你太美.wav"
const GUI_STATUS_BAR := preload("res://assets/export/gui/状态栏.png")
const GUI_SKILL_FRAME := preload("res://assets/export/gui/技能框.png")
const GUI_ATTACK_LOGO := preload("res://assets/export/gui/攻击logo.png")
const STATUS_SCALE := 1.73
const STATUS_FILL_W := 59.0 * STATUS_SCALE
const STATUS_FILL_H := 5.5 * STATUS_SCALE
const ACTION_FRAME_SIZE := Vector2(50.67, 50.67)
const ACTION_CONTROL_SIZE := Vector2(50.67, 78.0)
const ACTION_ROW_Y := 552.0
const ACTION_Q_X := 646.0
const ACTION_J_X := 716.0
const ACTION_K_X := 786.0
const ACTION_L_X := 856.0
const ACTION_KEY_Y := 55.0
const ACTION_KEY_COLOR := Color(0.78, 0.88, 0.94)

const ROOM_W := int(VS.VIEWPORT_SIZE.x)
const ROOM_H := int(VS.VIEWPORT_SIZE.y)
const WALL_T := int(VS.WALL_THICKNESS)

var _player: CharacterBody2D
var _bullet_pool: Node2D
var _portal_pos := Vector2(480, 120)
var _portal_near := false
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
var _map_names := ["废弃矿洞", "敬请期待", "敬请期待"]
var _map_cards: Array[Control] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameManager.change_state(GameManager.GameState.LOBBY)
	_start_lobby_music()
	_create_walls()
	_create_bullet_pool()
	_create_player()
	_create_npcs()
	_create_hud()


func _start_lobby_music() -> void:
	var stream := _load_audio_stream(LOBBY_MUSIC_PATH)
	if stream == null:
		return
	_lobby_music = AudioStreamPlayer.new()
	_lobby_music.bus = "Master"
	_lobby_music.volume_db = -4.0
	_lobby_music.stream = stream
	_lobby_music.finished.connect(_replay_lobby_music)
	add_child(_lobby_music)
	_lobby_music.play()


func _replay_lobby_music() -> void:
	if _lobby_music != null and is_instance_valid(_lobby_music):
		_lobby_music.play()


func _load_audio_stream(path: String) -> AudioStream:
	var stream := load(path) as AudioStream
	if stream != null:
		return stream
	var absolute_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(absolute_path):
		return AudioStreamWAV.load_from_file(absolute_path)
	return null


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


func _create_bullet_pool() -> void:
	_bullet_pool = Node2D.new()
	_bullet_pool.name = "BulletPool"
	_bullet_pool.set_script(load("res://scripts/bullet_pool.gd"))
	add_child(_bullet_pool)


func _create_player() -> void:
	_player = CharacterBody2D.new()
	_player.position = Vector2(480, 450)
	_player.set_script(load("res://scripts/player.gd"))

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


func _create_npcs() -> void:
	var npc_script := load("res://scripts/npc.gd")

	# 尖叫鸡（天赋树）— 左侧
	var broker := Area2D.new()
	broker.position = Vector2(240, 320)
	broker.set_script(npc_script)
	var broker_col := CollisionShape2D.new()
	var broker_circle := CircleShape2D.new()
	broker_circle.radius = 40.0
	broker_col.shape = broker_circle
	broker.add_child(broker_col)
	add_child(broker)
	broker.npc_type = "broker"
	broker.display_name = "尖叫鸡"
	broker.npc_color = Color(0.9, 0.7, 0.2)

	# 卡皮巴拉（武器商店）— 右侧
	var smith := Area2D.new()
	smith.position = Vector2(720, 320)
	smith.set_script(npc_script)
	var smith_col := CollisionShape2D.new()
	var smith_circle := CircleShape2D.new()
	smith_circle.radius = 40.0
	smith_col.shape = smith_circle
	smith.add_child(smith_col)
	add_child(smith)
	smith.npc_type = "smith"
	smith.display_name = "卡皮巴拉"
	smith.npc_color = Color(0.5, 0.6, 0.8)

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
	_hud_frame.position = Vector2(12, 4)
	_hud_frame.size = Vector2(79, 39) * STATUS_SCALE
	_hud_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_frame.draw.connect(_draw_stats_frame)
	_hud_canvas.add_child(_hud_frame)

	_hp_bar_bg = ColorRect.new()
	_hp_bar_bg.position = Vector2(12, 4) + Vector2(15, 4) * STATUS_SCALE
	_hp_bar_bg.size = Vector2(STATUS_FILL_W, STATUS_FILL_H)
	_hp_bar_bg.color = Color(0.08, 0.04, 0.03, 0.55)
	_hud_canvas.add_child(_hp_bar_bg)

	_hp_bar = ColorRect.new()
	_hp_bar.position = _hp_bar_bg.position
	_hp_bar.size = _hp_bar_bg.size
	_hp_bar.color = Color(0.88, 0.07, 0.15)
	_hud_canvas.add_child(_hp_bar)

	_hp_text = _make_hud_value_label(Vector2(72, 7), Color.WHITE)
	_hud_canvas.add_child(_hp_text)

	_shield_bar_bg = ColorRect.new()
	_shield_bar_bg.position = Vector2(12, 4) + Vector2(15, 16) * STATUS_SCALE
	_shield_bar_bg.size = Vector2(STATUS_FILL_W, STATUS_FILL_H)
	_shield_bar_bg.color = Color(0.06, 0.07, 0.08, 0.55)
	_hud_canvas.add_child(_shield_bar_bg)

	_shield_bar = ColorRect.new()
	_shield_bar.position = _shield_bar_bg.position
	_shield_bar.size = _shield_bar_bg.size
	_shield_bar.color = Color(0.78, 0.85, 0.9)
	_hud_canvas.add_child(_shield_bar)

	_shield_text = _make_hud_value_label(Vector2(72, 38), Color.WHITE)
	_hud_canvas.add_child(_shield_text)

	_mana_bar_bg = ColorRect.new()
	_mana_bar_bg.position = Vector2(12, 4) + Vector2(15, 28) * STATUS_SCALE
	_mana_bar_bg.size = Vector2(STATUS_FILL_W, STATUS_FILL_H)
	_mana_bar_bg.color = Color(0.04, 0.05, 0.12, 0.55)
	_hud_canvas.add_child(_mana_bar_bg)

	_mana_bar = ColorRect.new()
	_mana_bar.position = _mana_bar_bg.position
	_mana_bar.size = _mana_bar_bg.size
	_mana_bar.color = Color(0.22, 0.33, 0.9)
	_hud_canvas.add_child(_mana_bar)

	_mana_text = _make_hud_value_label(Vector2(72, 69), Color.WHITE)
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
		_portal_near = _player.global_position.distance_to(_portal_pos) < 50.0

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
		_portal_near = _player.global_position.distance_to(_portal_pos) < 50.0

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
	_attack_icon.draw_texture_rect(GUI_SKILL_FRAME, Rect2(Vector2.ZERO, ACTION_FRAME_SIZE), false)
	var logo_size: Vector2 = Vector2(28, 28)
	var logo_rect: Rect2 = Rect2((ACTION_FRAME_SIZE - logo_size) * 0.5, logo_size)
	_attack_icon.draw_texture_rect(GUI_ATTACK_LOGO, logo_rect, false)
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
		var radius: float = ACTION_FRAME_SIZE.x * 0.36
		var points := PackedVector2Array()
		points.append(center)
		var segments := 24
		var sweep: float = TAU * cd_ratio
		for i in segments + 1:
			var angle: float = -PI / 2 + sweep * i / segments
			points.append(center + Vector2(cos(angle), sin(angle)) * radius)
		if points.size() >= 3:
			_dash_icon.draw_colored_polygon(points, Color(0, 0, 0, 0.55))
	_draw_action_key(_dash_icon, "K", ACTION_KEY_COLOR)


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
			match event.keycode:
				KEY_A, KEY_LEFT:
					_current_map_index = (_current_map_index - 1 + _map_names.size()) % _map_names.size()
					_refresh_map_cards()
				KEY_D, KEY_RIGHT:
					_current_map_index = (_current_map_index + 1) % _map_names.size()
					_refresh_map_cards()
				KEY_E:
					if _current_map_index == 0:
						_enter_dungeon()
					else:
						pass  # 敬请期待
				KEY_ESCAPE:
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
	GameManager.change_state(GameManager.GameState.PAUSED)
	_map_select_canvas = CanvasLayer.new()
	_map_select_canvas.layer = 29
	_map_select_canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_map_select_canvas)

	# 半透明遮罩
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.65)
	bg.size = VS.VIEWPORT_SIZE
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_map_select_canvas.add_child(bg)

	# 标题
	var title := Label.new()
	title.text = "选择副本"
	title.position = Vector2(410, 50)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	_map_select_canvas.add_child(title)

	# 三张地图卡片
	_map_cards.clear()
	var card_w := VS.MAP_CARD_SIZE.x
	var card_h := VS.MAP_CARD_SIZE.y
	var card_gap := 30.0
	var total_w := card_w * 3 + card_gap * 2
	var start_x := (VS.VIEWPORT_SIZE.x - total_w) / 2.0
	var card_y := 110.0

	for i in _map_names.size():
		var card := Control.new()
		card.position = Vector2(start_x + i * (card_w + card_gap), card_y)
		card.size = Vector2(card_w, card_h)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.draw.connect(_draw_map_card.bind(card, i))
		_map_select_canvas.add_child(card)
		_map_cards.append(card)

	# AD 切换提示
	var switch_hint := Label.new()
	switch_hint.text = "< A          D >"
	switch_hint.position = Vector2(380, 380)
	switch_hint.add_theme_font_size_override("font_size", 18)
	switch_hint.add_theme_color_override("font_color", Color(0.5, 0.7, 1.0))
	switch_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	switch_hint.size = Vector2(200, 30)
	_map_select_canvas.add_child(switch_hint)

	# 进入按钮
	var enter_btn := Label.new()
	enter_btn.text = "[ 按 E 进入 ]"
	enter_btn.position = Vector2(400, 420)
	enter_btn.add_theme_font_size_override("font_size", 20)
	enter_btn.add_theme_color_override("font_color", Color(0.0, 0.9, 0.4))
	_map_select_canvas.add_child(enter_btn)

	# 关闭提示
	var close_hint := Label.new()
	close_hint.text = "ESC 返回"
	close_hint.position = Vector2(430, 460)
	close_hint.add_theme_font_size_override("font_size", 14)
	close_hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	_map_select_canvas.add_child(close_hint)

	_refresh_map_cards()


func _draw_map_card(card: Control, index: int) -> void:
	var w := card.size.x
	var h := card.size.y
	var is_selected := index == _current_map_index
	var available := index == 0

	# 卡片背景
	var bg_color := Color(0.12, 0.13, 0.18) if is_selected else Color(0.08, 0.08, 0.10)
	card.draw_rect(Rect2(Vector2.ZERO, card.size), bg_color)

	# 缩略图区域
	var thumb_rect := Rect2(8, 8, w - 16, h - 80)
	if available:
		_draw_mine_thumbnail(card, thumb_rect)
	else:
		# 未开放 — 暗色 + 锁
		card.draw_rect(thumb_rect, Color(0.06, 0.06, 0.08))
		var lock_text := "?"
		var lock_size := ThemeDB.fallback_font.get_string_size(lock_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 32)
		card.draw_string(ThemeDB.fallback_font, thumb_rect.position + Vector2((thumb_rect.size.x - lock_size.x) / 2, thumb_rect.size.y / 2 + 10), lock_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color(0.3, 0.3, 0.3))

	# 地图名
	var name_color := Color(1.0, 1.0, 1.0) if available else Color(0.4, 0.4, 0.4)
	var map_name: String = _map_names[index]
	var name_size := ThemeDB.fallback_font.get_string_size(map_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
	card.draw_string(ThemeDB.fallback_font, Vector2((w - name_size.x) / 2, h - 42), map_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, name_color)

	# 状态标签
	if available:
		var status_text := "可进入"
		var st_size := ThemeDB.fallback_font.get_string_size(status_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
		card.draw_string(ThemeDB.fallback_font, Vector2((w - st_size.x) / 2, h - 20), status_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.0, 0.9, 0.4))
	else:
		var status_text := "敬请期待"
		var st_size := ThemeDB.fallback_font.get_string_size(status_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
		card.draw_string(ThemeDB.fallback_font, Vector2((w - st_size.x) / 2, h - 20), status_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.5, 0.3, 0.3))

	# 选中边框
	if is_selected:
		var border_color := Color(0.3, 0.7, 1.0) if available else Color(0.4, 0.4, 0.5)
		card.draw_rect(Rect2(Vector2.ZERO, card.size), border_color, false, 2.5)


func _draw_mine_thumbnail(card: Control, rect: Rect2) -> void:
	# 废弃矿洞缩略图：深色洞穴 + 矿石
	card.draw_rect(rect, Color(0.08, 0.07, 0.06))

	# 洞穴顶部轮廓
	var ceiling := PackedVector2Array()
	ceiling.append(Vector2(rect.position.x, rect.position.y))
	var segments := 12
	for i in segments + 1:
		var t := float(i) / float(segments)
		var x := rect.position.x + t * rect.size.x
		var y := rect.position.y + 15.0 + sin(t * 4.0 + 1.2) * 12.0 + sin(t * 7.0) * 6.0
		ceiling.append(Vector2(x, y))
	ceiling.append(Vector2(rect.position.x + rect.size.x, rect.position.y))
	card.draw_colored_polygon(ceiling, Color(0.15, 0.12, 0.10))

	# 地面
	var ground_y := rect.position.y + rect.size.y - 20.0
	card.draw_rect(Rect2(rect.position.x, ground_y, rect.size.x, 20.0), Color(0.12, 0.10, 0.08))

	# 矿石晶体（散落在地面和墙壁上）
	var crystal_colors := [Color(0.2, 0.6, 1.0), Color(0.8, 0.2, 0.6), Color(0.1, 0.9, 0.3), Color(1.0, 0.7, 0.1)]
	var crystal_positions := [
		Vector2(rect.position.x + 30, ground_y - 8),
		Vector2(rect.position.x + 80, ground_y - 5),
		Vector2(rect.position.x + 130, ground_y - 10),
		Vector2(rect.position.x + 15, rect.position.y + 30),
		Vector2(rect.position.x + rect.size.x - 20, rect.position.y + 40),
		Vector2(rect.position.x + 60, ground_y - 6),
	]
	for ci in crystal_positions:
		var col: Color = crystal_colors[int(ci.x) % crystal_colors.size()]
		var pts := PackedVector2Array()
		pts.append(ci + Vector2(0, -8))
		pts.append(ci + Vector2(4, 0))
		pts.append(ci + Vector2(0, 3))
		pts.append(ci + Vector2(-4, 0))
		card.draw_colored_polygon(pts, col)
		card.draw_colored_polygon(pts, col.lightened(0.4))

	# 坑道木桩支撑
	var wood := Color(0.35, 0.22, 0.10)
	card.draw_rect(Rect2(rect.position.x + 40, rect.position.y + 25, 4, rect.size.y - 50), wood)
	card.draw_rect(Rect2(rect.position.x + rect.size.x - 45, rect.position.y + 30, 4, rect.size.y - 55), wood)
	# 横梁
	card.draw_rect(Rect2(rect.position.x + 38, rect.position.y + 23, 12, 4), wood.lightened(0.15))
	card.draw_rect(Rect2(rect.position.x + rect.size.x - 47, rect.position.y + 28, 12, 4), wood.lightened(0.15))

	# 灯光（中间偏上）
	var light_pos := Vector2(rect.position.x + rect.size.x / 2, rect.position.y + 20)
	card.draw_circle(light_pos, 3.0, Color(1.0, 0.85, 0.4))
	# 光晕
	for r: float in [12.0, 20.0, 30.0]:
		var a: float = 0.15 - r * 0.004
		card.draw_circle(light_pos, r, Color(1.0, 0.85, 0.3, a))


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
	_equipment_panel = load("res://scripts/equipment_panel.gd").new()
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
	# 地板
	draw_rect(Rect2(WALL_T, WALL_T, ROOM_W - WALL_T * 2, ROOM_H - WALL_T * 2),
		Color(0.13, 0.12, 0.10))

	# 地板装饰线条
	for i in range(0, ROOM_W, 80):
		draw_line(Vector2(i + WALL_T, WALL_T), Vector2(i + WALL_T, ROOM_H - WALL_T),
			Color(0.15, 0.14, 0.12), 1.0)
	for j in range(0, ROOM_H, 80):
		draw_line(Vector2(WALL_T, j + WALL_T), Vector2(ROOM_W - WALL_T, j + WALL_T),
			Color(0.15, 0.14, 0.12), 1.0)

	# 墙壁
	draw_rect(Rect2(0, 0, ROOM_W, WALL_T), Color(0.25, 0.22, 0.18))
	draw_rect(Rect2(0, ROOM_H - WALL_T, ROOM_W, WALL_T), Color(0.25, 0.22, 0.18))
	draw_rect(Rect2(0, 0, WALL_T, ROOM_H), Color(0.25, 0.22, 0.18))
	draw_rect(Rect2(ROOM_W - WALL_T, 0, WALL_T, ROOM_H), Color(0.25, 0.22, 0.18))

	# 传送门
	var pulse := sin(_anim_timer * 3.0) * 0.15 + 0.85
	var portal_radius := VS.PORTAL_LOBBY_DISPLAY_SIZE * 0.5
	draw_circle(_portal_pos, portal_radius, Color(0.0, 0.7, 1.0, 0.3 * pulse))
	draw_arc(_portal_pos, portal_radius, 0, TAU, 32, Color(0.0, 0.85, 1.0, 0.8 * pulse), 3.0)
	draw_arc(_portal_pos, portal_radius * 0.72, 0, TAU, 32, Color(0.3, 0.9, 1.0, 0.5 * pulse), 2.0)
	draw_arc(_portal_pos, portal_radius * 0.4, 0, TAU, 24, Color(0.6, 1.0, 1.0, 0.6 * pulse), 1.5)

	# 传送门文字
	draw_string(ThemeDB.fallback_font, _portal_pos + Vector2(-30, 45), "副本入口",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.0, 0.85, 1.0, pulse))

	# 靠近提示
	if _portal_near and not _map_select_open:
		draw_string(ThemeDB.fallback_font, _portal_pos + Vector2(-40, 65), "按 E 选择副本",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1.0, 1.0, 0.6))
