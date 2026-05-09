extends Node

## 装备管理面板 — 装备槽 + 背包 + 槽位解锁

const VS := preload("res://scripts/visual_spec.gd")

var _canvas: CanvasLayer
var _player: Node
var _selected_slot := -1  # 当前选中的装备槽索引
var _eq_draw: Control
var _bp_draw: Control
var _drag_draw: Control
var _drag_weapon_key := ""
var _drag_start_pos := Vector2.ZERO
var _drag_current_pos := Vector2.ZERO
var _drag_active := false

# 解锁确认对话框
var _confirm_open := false
var _confirm_slot := -1
var _confirm_yes_rect := Rect2()
var _confirm_no_rect := Rect2()

const SLOT_W := VS.SLOT_SIZE.x
const SLOT_H := VS.SLOT_SIZE.y
const SLOT_GAP := 12.0
const PANEL_SIZE := VS.VIEWPORT_SIZE
const EQUIPPED_AREA_POS := Vector2(80.0, 140.0)
const BACKPACK_AREA_POS := Vector2(80.0, 305.0)
const SLOT_OFFSET := Vector2(20.0, 10.0)
const DRAG_THRESHOLD := 6.0


func show_panel(player: Node) -> void:
	_player = player
	_selected_slot = 0
	if _player != null:
		_selected_slot = clampi(_player._weapon_index, 0, maxi(GameManager.player_data.equipped_weapons.size() - 1, 0))
	process_mode = Node.PROCESS_MODE_ALWAYS
	_canvas = CanvasLayer.new()
	_canvas.layer = 29
	_canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_canvas)
	_build_ui()


func _build_ui() -> void:
	for child in _canvas.get_children():
		child.queue_free()
	_eq_draw = null
	_bp_draw = null
	_drag_draw = null

	# 遮罩
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.7)
	bg.size = PANEL_SIZE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(bg)

	# 面板背景
	var panel := ColorRect.new()
	panel.color = Color(0.1, 0.1, 0.13)
	panel.position = Vector2(80, 60)
	panel.size = Vector2(800, 520)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(panel)
	panel.draw.connect(func():
		panel.draw_rect(Rect2(Vector2.ZERO, panel.size), Color(0.3, 0.6, 0.4), false, 2.0)
	)

	# 标题
	var title := Label.new()
	title.text = "装备管理"
	title.position = Vector2(420, 75)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.3, 0.9, 0.5))
	_canvas.add_child(title)

	# 装备槽标题
	var eq_label := Label.new()
	eq_label.text = "装备槽（Q键切换武器）"
	eq_label.position = Vector2(110, 115)
	eq_label.add_theme_font_size_override("font_size", 16)
	eq_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	_canvas.add_child(eq_label)

	# 绘制装备槽
	var eq_draw := Control.new()
	eq_draw.size = Vector2(800, 120)
	eq_draw.position = EQUIPPED_AREA_POS
	eq_draw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	eq_draw.draw.connect(_draw_equipped_slots)
	_canvas.add_child(eq_draw)
	_eq_draw = eq_draw

	# 背包标题
	var bp_label := Label.new()
	bp_label.text = "背包（未装备）"
	bp_label.position = Vector2(110, 280)
	bp_label.add_theme_font_size_override("font_size", 16)
	bp_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	_canvas.add_child(bp_label)

	# 绘制背包
	var bp_draw := Control.new()
	bp_draw.size = Vector2(800, 200)
	bp_draw.position = BACKPACK_AREA_POS
	bp_draw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bp_draw.draw.connect(_draw_backpack)
	_canvas.add_child(bp_draw)
	_bp_draw = bp_draw

	# 关闭提示
	var close_hint := Label.new()
	close_hint.text = "ESC / B 关闭"
	close_hint.position = Vector2(400, 555)
	close_hint.add_theme_font_size_override("font_size", 14)
	close_hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	_canvas.add_child(close_hint)

	var input_layer := Control.new()
	input_layer.size = PANEL_SIZE
	input_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	input_layer.gui_input.connect(_on_panel_input)
	_canvas.add_child(input_layer)

	_drag_draw = Control.new()
	_drag_draw.size = PANEL_SIZE
	_drag_draw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drag_draw.draw.connect(_draw_drag_preview)
	_canvas.add_child(_drag_draw)

	# 解锁确认对话框
	if _confirm_open:
		_build_confirm_dialog()


func _draw_equipped_slots() -> void:
	var data: Dictionary = GameManager.player_data
	var equipped: Array = data.equipped_weapons
	var max_slots: int = data.max_weapon_slots
	var base_x := 20.0
	var base_y := 10.0

	var ctrl := _eq_draw
	if ctrl == null:
		return

	for i in range(5):
		var x := base_x + i * (SLOT_W + SLOT_GAP)
		var rect := Rect2(x, base_y, SLOT_W, SLOT_H)
		var is_drop_target := _drag_weapon_key != "" and _get_equipped_slot_at(_drag_current_pos) == i

		if i >= max_slots:
			# 锁定槽位
			ctrl.draw_rect(rect, Color(0.08, 0.08, 0.08))
			ctrl.draw_rect(rect, Color(0.3, 0.3, 0.3), false, 1.5)
			var lock_text := "锁定"
			var next_slot := i + 1
			if next_slot in GameManager.SLOT_UNLOCK_COSTS:
				lock_text = "%d坤币" % GameManager.SLOT_UNLOCK_COSTS[next_slot]
			var lt_size := ThemeDB.fallback_font.get_string_size(lock_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
			ctrl.draw_string(ThemeDB.fallback_font, Vector2(x + (SLOT_W - lt_size.x) / 2, base_y + SLOT_H / 2 + 5), lock_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.5, 0.4, 0.3))
			if is_drop_target:
				ctrl.draw_rect(rect, Color(0.7, 0.4, 0.2), false, 3.0)
			continue

		if i < equipped.size():
			# 有武器
			var key: String = equipped[i]
			var weapon: Dictionary = _player.WEAPONS[key]
			var is_selected := i == _selected_slot
			var border_color := Color(0.3, 0.9, 0.5) if is_selected else Color(0.3, 0.5, 0.7)
			ctrl.draw_rect(rect, Color(0.12, 0.15, 0.12))
			ctrl.draw_rect(rect, border_color, false, 2.0 if is_selected else 1.0)
			# 武器名
			var name_size := ThemeDB.fallback_font.get_string_size(weapon.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 15)
			ctrl.draw_string(ThemeDB.fallback_font, Vector2(x + (SLOT_W - name_size.x) / 2, base_y + 30), weapon.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.9, 0.9, 0.9))
			# 伤害
			var dmg_text := "伤害:%d" % (weapon.damage + _player.damage_bonus)
			var dmg_size := ThemeDB.fallback_font.get_string_size(dmg_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
			ctrl.draw_string(ThemeDB.fallback_font, Vector2(x + (SLOT_W - dmg_size.x) / 2, base_y + 50), dmg_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.6, 0.7, 0.8))
			# 类型
			var type_text := ""
			match weapon.type:
				"basketball": type_text = "投射"
				"room_blast": type_text = "全屏"
				"rooster": type_text = "追击"
				_: type_text = "武器"
			var ts_size := ThemeDB.fallback_font.get_string_size(type_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11)
			ctrl.draw_string(ThemeDB.fallback_font, Vector2(x + (SLOT_W - ts_size.x) / 2, base_y + 66), type_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.5, 0.5, 0.5))
			# 槽位编号
			ctrl.draw_string(ThemeDB.fallback_font, Vector2(x + 4, base_y + 14), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.4, 0.4, 0.4))
		else:
			# 空槽
			ctrl.draw_rect(rect, Color(0.08, 0.1, 0.08))
			ctrl.draw_rect(rect, Color(0.2, 0.3, 0.2), false, 1.0)
			var empty_text := "空槽"
			var et_size := ThemeDB.fallback_font.get_string_size(empty_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
			ctrl.draw_string(ThemeDB.fallback_font, Vector2(x + (SLOT_W - et_size.x) / 2, base_y + SLOT_H / 2 + 5), empty_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.3, 0.3, 0.3))
			ctrl.draw_string(ThemeDB.fallback_font, Vector2(x + 4, base_y + 14), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.4, 0.4, 0.4))
		if is_drop_target:
			ctrl.draw_rect(rect, Color(0.95, 0.8, 0.25), false, 3.0)


func _draw_backpack() -> void:
	var backpack := _get_backpack_weapons()
	var ctrl := _bp_draw
	if ctrl == null:
		return

	if backpack.is_empty():
		var empty_text := "没有未装备的武器"
		var et_size := ThemeDB.fallback_font.get_string_size(empty_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
		ctrl.draw_string(ThemeDB.fallback_font, Vector2((800 - et_size.x) / 2, 60), empty_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.4, 0.4, 0.4))
		return

	var base_x := 20.0
	var base_y := 10.0
	for i in backpack.size():
		var key: String = backpack[i]
		var weapon: Dictionary = _player.WEAPONS[key]
		var x := base_x + i * (SLOT_W + SLOT_GAP)
		var rect := Rect2(x, base_y, SLOT_W, SLOT_H)
		var is_dragging_this := key == _drag_weapon_key

		ctrl.draw_rect(rect, Color(0.08, 0.07, 0.1) if is_dragging_this else Color(0.12, 0.1, 0.15))
		ctrl.draw_rect(rect, Color(0.6, 0.5, 0.85) if is_dragging_this else Color(0.4, 0.3, 0.6), false, 2.0 if is_dragging_this else 1.0)

		# 武器名
		var name_size := ThemeDB.fallback_font.get_string_size(weapon.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 15)
		ctrl.draw_string(ThemeDB.fallback_font, Vector2(x + (SLOT_W - name_size.x) / 2, base_y + 30), weapon.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.9, 0.9, 0.9))

		# 伤害
		var dmg_text := "伤害:%d" % (weapon.damage + _player.damage_bonus)
		var dmg_size := ThemeDB.fallback_font.get_string_size(dmg_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
		ctrl.draw_string(ThemeDB.fallback_font, Vector2(x + (SLOT_W - dmg_size.x) / 2, base_y + 50), dmg_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.6, 0.7, 0.8))

		# 类型
		var type_text := ""
		match weapon.type:
			"basketball": type_text = "投射"
			"room_blast": type_text = "全屏"
			"rooster": type_text = "追击"
			_: type_text = "武器"
		var ts_size := ThemeDB.fallback_font.get_string_size(type_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11)
		ctrl.draw_string(ThemeDB.fallback_font, Vector2(x + (SLOT_W - ts_size.x) / 2, base_y + 66), type_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.5, 0.5, 0.5))


func _draw_drag_preview() -> void:
	if _drag_draw == null or _drag_weapon_key == "" or not _drag_active:
		return
	if _player == null or not _player.WEAPONS.has(_drag_weapon_key):
		return
	var weapon: Dictionary = _player.WEAPONS[_drag_weapon_key]
	var rect := Rect2(_drag_current_pos - Vector2(SLOT_W, SLOT_H) * 0.5, Vector2(SLOT_W, SLOT_H))
	_drag_draw.draw_rect(rect, Color(0.16, 0.12, 0.22, 0.85))
	_drag_draw.draw_rect(rect, Color(0.95, 0.8, 0.25), false, 2.0)
	var name_size := ThemeDB.fallback_font.get_string_size(weapon.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 15)
	_drag_draw.draw_string(ThemeDB.fallback_font, Vector2(rect.position.x + (SLOT_W - name_size.x) / 2, rect.position.y + 34), weapon.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.95, 0.95, 0.95))


func _on_panel_input(event: InputEvent) -> void:
	if _confirm_open:
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed:
			_handle_panel_mouse_pressed(mouse_event.position)
		else:
			_handle_panel_mouse_released(mouse_event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _drag_weapon_key != "":
		var motion_event := event as InputEventMouseMotion
		_drag_current_pos = motion_event.position
		if _drag_current_pos.distance_to(_drag_start_pos) >= DRAG_THRESHOLD:
			_drag_active = true
		_queue_panel_redraw()
		get_viewport().set_input_as_handled()


func _handle_panel_mouse_pressed(click_pos: Vector2) -> void:
	var backpack_index := _get_backpack_index_at(click_pos)
	if backpack_index >= 0:
		var backpack := _get_backpack_weapons()
		_drag_weapon_key = backpack[backpack_index]
		_drag_start_pos = click_pos
		_drag_current_pos = click_pos
		_drag_active = false
		_queue_panel_redraw()
		return

	var slot_index := _get_equipped_slot_at(click_pos)
	if slot_index < 0:
		return

	var data: Dictionary = GameManager.player_data
	var equipped: Array = data.equipped_weapons
	var max_slots: int = data.max_weapon_slots

	if slot_index >= max_slots:
		_open_unlock_confirm(slot_index)
		return

	if slot_index < equipped.size():
		_unequip_slot(slot_index)
		_build_ui()


func _handle_panel_mouse_released(release_pos: Vector2) -> void:
	if _drag_weapon_key == "":
		return

	var key := _drag_weapon_key
	var was_dragging := _drag_active
	_clear_drag()

	var slot_index := _get_equipped_slot_at(release_pos)
	if slot_index >= 0:
		var max_slots: int = GameManager.player_data.max_weapon_slots
		if slot_index >= max_slots:
			_open_unlock_confirm(slot_index)
			return
		if _equip_weapon_to_slot(key, slot_index):
			_build_ui()
			return

	if not was_dragging and _equip_weapon_to_first_available(key):
		_build_ui()
	else:
		_queue_panel_redraw()


func _get_backpack_weapons() -> Array:
	var data: Dictionary = GameManager.player_data
	var owned: Array = data.owned_weapons
	var equipped: Array = data.equipped_weapons
	var backpack: Array = []
	for key in owned:
		if key not in equipped:
			backpack.append(key)
	return backpack


func _get_backpack_index_at(panel_pos: Vector2) -> int:
	var backpack := _get_backpack_weapons()
	var base := BACKPACK_AREA_POS + SLOT_OFFSET
	for i in backpack.size():
		var rect := Rect2(base + Vector2(i * (SLOT_W + SLOT_GAP), 0.0), Vector2(SLOT_W, SLOT_H))
		if rect.has_point(panel_pos):
			return i
	return -1


func _get_equipped_slot_at(panel_pos: Vector2) -> int:
	var base := EQUIPPED_AREA_POS + SLOT_OFFSET
	for i in range(5):
		var rect := Rect2(base + Vector2(i * (SLOT_W + SLOT_GAP), 0.0), Vector2(SLOT_W, SLOT_H))
		if rect.has_point(panel_pos):
			return i
	return -1


func _equip_weapon_to_first_available(key: String) -> bool:
	var equipped: Array = GameManager.player_data.equipped_weapons
	var max_slots: int = GameManager.player_data.max_weapon_slots
	var target_slot := equipped.size() if equipped.size() < max_slots else _selected_slot
	if target_slot < 0 or target_slot >= max_slots:
		target_slot = 0
	return _equip_weapon_to_slot(key, target_slot)


func _equip_weapon_to_slot(key: String, slot_index: int) -> bool:
	if _player == null or not _player.WEAPONS.has(key):
		return false
	var max_slots: int = GameManager.player_data.max_weapon_slots
	if slot_index < 0 or slot_index >= max_slots:
		return false

	var equipped: Array = GameManager.player_data.equipped_weapons.duplicate()
	if key in equipped:
		equipped.erase(key)
		if slot_index > equipped.size():
			slot_index = equipped.size()

	if slot_index < equipped.size():
		equipped[slot_index] = key
	elif equipped.size() < max_slots:
		equipped.append(key)
	else:
		return false

	GameManager.player_data.equipped_weapons = equipped
	_selected_slot = clampi(slot_index, 0, maxi(equipped.size() - 1, 0))
	_sync_player_weapons()
	return true


func _unequip_slot(slot_index: int) -> bool:
	var equipped: Array = GameManager.player_data.equipped_weapons.duplicate()
	if slot_index < 0 or slot_index >= equipped.size():
		return false
	if equipped.size() <= 1:
		return false
	equipped.remove_at(slot_index)
	GameManager.player_data.equipped_weapons = equipped
	_selected_slot = clampi(slot_index, 0, maxi(equipped.size() - 1, 0))
	_sync_player_weapons()
	return true


func _sync_player_weapons() -> void:
	if _player == null:
		return
	_player._weapon_keys = GameManager.player_data.equipped_weapons.duplicate()
	_player._weapon_index = clampi(_selected_slot, 0, maxi(_player._weapon_keys.size() - 1, 0))
	GameManager.player_data.weapon_index = _player._weapon_index


func _clear_drag() -> void:
	_drag_weapon_key = ""
	_drag_start_pos = Vector2.ZERO
	_drag_current_pos = Vector2.ZERO
	_drag_active = false


func _queue_panel_redraw() -> void:
	if _eq_draw:
		_eq_draw.queue_redraw()
	if _bp_draw:
		_bp_draw.queue_redraw()
	if _drag_draw:
		_drag_draw.queue_redraw()


func _open_unlock_confirm(_slot_index: int) -> void:
	var max_slots: int = GameManager.player_data.max_weapon_slots
	if max_slots >= 5:
		return
	_clear_drag()
	_confirm_open = true
	_confirm_slot = max_slots
	_build_ui()


func _on_confirm_input(event: InputEvent) -> void:
	if not _confirm_open:
		return
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var click_pos: Vector2 = event.position
	if _confirm_yes_rect.has_point(click_pos):
		if GameManager.unlock_weapon_slot():
			_confirm_open = false
			_confirm_slot = -1
		_build_ui()
	elif _confirm_no_rect.has_point(click_pos):
		_confirm_open = false
		_confirm_slot = -1
		_build_ui()
	get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if _canvas and event is InputEventKey and event.pressed and (event.keycode == KEY_ESCAPE or event.keycode == KEY_B):
		get_viewport().set_input_as_handled()
		_close()


func _close() -> void:
	if _canvas:
		_canvas.queue_free()
	queue_free()


func _build_confirm_dialog() -> void:
	var next_slot: int = _confirm_slot + 1
	var cost: int = GameManager.SLOT_UNLOCK_COSTS.get(next_slot, 0)
	var can_afford: bool = GameManager.kun_coins >= cost

	# 遮罩层
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.5)
	overlay.size = PANEL_SIZE
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(overlay)

	# 对话框背景
	var dlg_w := 320.0
	var dlg_h := 160.0
	var dlg_x := (960.0 - dlg_w) / 2.0
	var dlg_y := (640.0 - dlg_h) / 2.0
	var dlg := ColorRect.new()
	dlg.color = Color(0.1, 0.1, 0.14)
	dlg.position = Vector2(dlg_x, dlg_y)
	dlg.size = Vector2(dlg_w, dlg_h)
	dlg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(dlg)
	dlg.draw.connect(func():
		dlg.draw_rect(Rect2(Vector2.ZERO, dlg.size), Color(0.4, 0.5, 0.7), false, 2.0)
	)

	# 标题
	var title := Label.new()
	title.text = "解锁槽位"
	title.position = Vector2(dlg_x + 110, dlg_y + 15)
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	_canvas.add_child(title)

	# 提示文字
	var msg := Label.new()
	msg.text = "是否花费 %d 坤币解锁第 %d 个槽位？" % [cost, next_slot]
	msg.position = Vector2(dlg_x + 40, dlg_y + 50)
	msg.add_theme_font_size_override("font_size", 14)
	var msg_color := Color(0.8, 0.8, 0.8) if can_afford else Color(0.8, 0.3, 0.3)
	msg.add_theme_color_override("font_color", msg_color)
	_canvas.add_child(msg)

	# 当前坤币
	var coin_info := Label.new()
	coin_info.text = "当前坤币: %d" % GameManager.kun_coins
	coin_info.position = Vector2(dlg_x + 40, dlg_y + 75)
	coin_info.add_theme_font_size_override("font_size", 13)
	coin_info.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
	_canvas.add_child(coin_info)

	# 按钮区域
	var btn_w := 100.0
	var btn_h := 36.0
	var btn_y := dlg_y + 110.0
	var yes_x := dlg_x + 50.0
	var no_x := dlg_x + dlg_w - btn_w - 50.0

	_confirm_yes_rect = Rect2(yes_x, btn_y, btn_w, btn_h)
	_confirm_no_rect = Rect2(no_x, btn_y, btn_w, btn_h)

	# 按钮背景
	var yes_bg := ColorRect.new()
	yes_bg.position = Vector2(yes_x, btn_y)
	yes_bg.size = Vector2(btn_w, btn_h)
	yes_bg.color = Color(0.1, 0.2, 0.1) if can_afford else Color(0.12, 0.12, 0.12)
	yes_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(yes_bg)

	var no_bg := ColorRect.new()
	no_bg.position = Vector2(no_x, btn_y)
	no_bg.size = Vector2(btn_w, btn_h)
	no_bg.color = Color(0.2, 0.1, 0.1)
	no_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(no_bg)

	# 确认按钮
	var yes_btn := Label.new()
	yes_btn.text = "[ 确认 ]"
	yes_btn.position = Vector2(yes_x + 25, btn_y + 10)
	yes_btn.add_theme_font_size_override("font_size", 16)
	var yes_color := Color(0.0, 0.9, 0.4) if can_afford else Color(0.4, 0.4, 0.4)
	yes_btn.add_theme_color_override("font_color", yes_color)
	yes_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(yes_btn)

	# 取消按钮
	var no_btn := Label.new()
	no_btn.text = "[ 取消 ]"
	no_btn.position = Vector2(no_x + 25, btn_y + 10)
	no_btn.add_theme_font_size_override("font_size", 16)
	no_btn.add_theme_color_override("font_color", Color(0.7, 0.5, 0.5))
	no_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(no_btn)

	var confirm_input := Control.new()
	confirm_input.size = PANEL_SIZE
	confirm_input.mouse_filter = Control.MOUSE_FILTER_STOP
	confirm_input.gui_input.connect(_on_confirm_input)
	_canvas.add_child(confirm_input)
