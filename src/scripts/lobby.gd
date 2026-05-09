extends Node2D

## 练习生基地 — 游戏大厅

const VS := preload("res://scripts/visual_spec.gd")

const ROOM_W := int(VS.VIEWPORT_SIZE.x)
const ROOM_H := int(VS.VIEWPORT_SIZE.y)
const WALL_T := int(VS.WALL_THICKNESS)

var _player: CharacterBody2D
var _portal_pos := Vector2(480, 120)
var _portal_near := false
var _anim_timer := 0.0

# HUD
var _practice_label: Label
var _coin_label: Label

# 地图选择
var _map_select_open := false
var _map_select_canvas: CanvasLayer
var _current_map_index := 0
var _map_names := ["废弃矿洞", "敬请期待", "敬请期待"]
var _map_cards: Array[Control] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameManager.change_state(GameManager.GameState.LOBBY)
	_create_walls()
	_create_player()
	_create_npcs()
	_create_hud()


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

	# 坤坤经纪人（天赋树）— 左侧
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
	broker.display_name = "坤坤经纪人"
	broker.npc_color = Color(0.9, 0.7, 0.2)

	# 鸡哥铁匠（武器商店）— 右侧
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
	smith.display_name = "一个真正的man"
	smith.npc_color = Color(0.5, 0.6, 0.8)



var _hp_bar_bg: ColorRect
var _hp_bar: ColorRect
var _hp_label: Label
var _mana_bar_bg: ColorRect
var _mana_bar: ColorRect
var _hud_canvas: CanvasLayer
var _equipment_panel: Node = null


func _create_hud() -> void:
	_hud_canvas = CanvasLayer.new()
	_hud_canvas.layer = 10
	add_child(_hud_canvas)

	# ── 第一行：HP 条 + 练习时长 ──
	# HP 背景
	_hp_bar_bg = ColorRect.new()
	_hp_bar_bg.position = Vector2(20, 14)
	_hp_bar_bg.size = VS.HP_FRAME_SIZE
	_hp_bar_bg.color = Color(0.2, 0.2, 0.2)
	_hud_canvas.add_child(_hp_bar_bg)

	# HP 填充
	_hp_bar = ColorRect.new()
	_hp_bar.position = Vector2(21, 15)
	_hp_bar.size = VS.HP_FILL_SIZE
	_hp_bar.color = Color(0.0, 0.8, 0.2)
	_hud_canvas.add_child(_hp_bar)

	# HP 数值
	_hp_label = Label.new()
	_hp_label.position = Vector2(128, 14)
	_hp_label.add_theme_font_size_override("font_size", 14)
	_hp_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	_hud_canvas.add_child(_hp_label)

	# 练习时长（HP 右侧）
	_practice_label = Label.new()
	_practice_label.position = Vector2(210, 14)
	_practice_label.add_theme_font_size_override("font_size", 14)
	_practice_label.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	_hud_canvas.add_child(_practice_label)

	# ── 第二行：MP 条 + 坤币 ──
	# MP 背景
	_mana_bar_bg = ColorRect.new()
	_mana_bar_bg.position = Vector2(20, 32)
	_mana_bar_bg.size = VS.MANA_FRAME_SIZE
	_mana_bar_bg.color = Color(0.2, 0.2, 0.2)
	_hud_canvas.add_child(_mana_bar_bg)

	# MP 填充
	_mana_bar = ColorRect.new()
	_mana_bar.position = Vector2(21, 33)
	_mana_bar.size = VS.MANA_FILL_SIZE
	_mana_bar.color = Color(0.2, 0.4, 1.0)
	_hud_canvas.add_child(_mana_bar)

	# 坤币（MP 右侧）
	_coin_label = Label.new()
	_coin_label.position = Vector2(210, 30)
	_coin_label.add_theme_font_size_override("font_size", 14)
	_coin_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
	_hud_canvas.add_child(_coin_label)

	# 操作提示
	var hint := Label.new()
	hint.text = "WASD移动 | E交互 | B背包 | 地牢中U狂暴"
	hint.position = Vector2(700, 600)
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	_hud_canvas.add_child(hint)


func _process(delta: float) -> void:
	_anim_timer += delta

	if _player and is_instance_valid(_player):
		# HP 条
		var hp_ratio: float = float(_player.hp) / float(_player.MAX_HP)
		_hp_bar.size.x = VS.HP_FILL_SIZE.x * clampf(hp_ratio, 0.0, 1.0)
		if hp_ratio > 0.3:
			_hp_bar.color = Color(0.0, 0.8, 0.2).lerp(Color(1.0, 0.0, 0.0), 1.0 - hp_ratio)
		else:
			_hp_bar.color = Color(1.0, 0.0, 0.0)
		_hp_label.text = "%d/%d" % [_player.hp, _player.MAX_HP]

		# MP 条
		var mana_ratio: float = _player.mana / _player.MAX_MANA
		_mana_bar.size.x = VS.MANA_FILL_SIZE.x * clampf(mana_ratio, 0.0, 1.0)

		_portal_near = _player.global_position.distance_to(_portal_pos) < 50.0

	# 货币
	_practice_label.text = "练习时长: %d" % GameManager.practice_time
	_coin_label.text = "坤币: %d" % GameManager.kun_coins

	queue_redraw()

	if _player and is_instance_valid(_player):
		_portal_near = _player.global_position.distance_to(_portal_pos) < 50.0

	queue_redraw()


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
