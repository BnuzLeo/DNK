extends Node

## 坤坤经纪人 — 属性升级面板

var _canvas: CanvasLayer
var _player: Node
var _rows: Array[Dictionary] = []

const STAT_DEFS := [
	{"key": "hp",    "name": "生命值",   "icon": "♥", "color": Color(0.2, 0.8, 0.3)},
	{"key": "speed", "name": "移动速度", "icon": "»", "color": Color(0.3, 0.7, 1.0)},
	{"key": "mana",  "name": "法力值",   "icon": "◆", "color": Color(0.4, 0.4, 1.0)},
	{"key": "regen", "name": "法力回复", "icon": "↻", "color": Color(0.5, 0.8, 1.0)},
]


func show_panel(player: Node) -> void:
	_player = player
	_canvas = CanvasLayer.new()
	_canvas.layer = 29
	add_child(_canvas)
	_build_ui()


func _build_ui() -> void:
	# 清除旧UI
	for child in _canvas.get_children():
		child.queue_free()
	_rows.clear()

	# 半透明遮罩
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.65)
	bg.size = Vector2(960, 640)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.add_child(bg)

	# 面板背景
	var panel := ColorRect.new()
	panel.color = Color(0.1, 0.1, 0.12)
	panel.position = Vector2(180, 80)
	panel.size = Vector2(600, 480)
	_canvas.add_child(panel)
	panel.draw.connect(_draw_panel_border.bind(panel))

	# 标题
	var title := Label.new()
	title.text = "坤坤经纪人 - 属性升级"
	title.position = Vector2(200, 95)
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
	_canvas.add_child(title)

	# 货币显示
	var currency := Label.new()
	currency.text = "练习时长: %d" % GameManager.practice_time
	currency.position = Vector2(560, 100)
	currency.add_theme_font_size_override("font_size", 16)
	currency.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	currency.name = "CurrencyLabel"
	_canvas.add_child(currency)

	# 属性行
	var y_offset := 150.0
	for stat_def in STAT_DEFS:
		_create_stat_row(stat_def, y_offset)
		y_offset += 80.0

	# 关闭按钮
	var close_btn := Label.new()
	close_btn.text = "[ 关闭 (ESC) ]"
	close_btn.position = Vector2(420, 530)
	close_btn.add_theme_font_size_override("font_size", 16)
	close_btn.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	close_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	close_btn.gui_input.connect(_on_close_input)
	_canvas.add_child(close_btn)


func _draw_panel_border(panel: ColorRect) -> void:
	panel.draw_rect(Rect2(Vector2.ZERO, panel.size), Color(0.8, 0.7, 0.2), false, 2.0)


func _create_stat_row(stat_def: Dictionary, y: float) -> void:
	var key: String = stat_def.key
	var level: int = GameManager.player_data.get("upgrade_%s_level" % key, 0)
	var cost: int = GameManager.get_upgrade_cost(key)
	var can_buy: bool = GameManager.can_afford_upgrade(key)
	var maxed: bool = cost < 0

	# 属性名 + 图标
	var name_label := Label.new()
	name_label.text = "%s %s" % [stat_def.icon, stat_def.name]
	name_label.position = Vector2(210, y)
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", stat_def.color)
	_canvas.add_child(name_label)

	# 等级
	var level_label := Label.new()
	level_label.text = "Lv.%d" % level
	level_label.position = Vector2(370, y)
	level_label.add_theme_font_size_override("font_size", 16)
	level_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	_canvas.add_child(level_label)

	# 当前值
	var value_text := _get_stat_value_text(key)
	var value_label := Label.new()
	value_label.text = value_text
	value_label.position = Vector2(370, y + 22)
	value_label.add_theme_font_size_override("font_size", 14)
	value_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	_canvas.add_child(value_label)

	# 费用/按钮
	if maxed:
		var maxed_label := Label.new()
		maxed_label.text = "已满级"
		maxed_label.position = Vector2(560, y + 8)
		maxed_label.add_theme_font_size_override("font_size", 16)
		maxed_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		_canvas.add_child(maxed_label)
	else:
		var cost_label := Label.new()
		cost_label.text = "消耗: %d" % cost
		cost_label.position = Vector2(530, y + 2)
		cost_label.add_theme_font_size_override("font_size", 14)
		var cost_color := Color(0.4, 0.8, 1.0) if can_buy else Color(0.5, 0.3, 0.3)
		cost_label.add_theme_color_override("font_color", cost_color)
		_canvas.add_child(cost_label)

		var btn := Label.new()
		btn.text = "[ 升级 ]"
		btn.position = Vector2(530, y + 24)
		btn.add_theme_font_size_override("font_size", 16)
		var btn_color := Color(0.0, 0.9, 0.4) if can_buy else Color(0.4, 0.4, 0.4)
		btn.add_theme_color_override("font_color", btn_color)
		if can_buy:
			btn.mouse_filter = Control.MOUSE_FILTER_STOP
			btn.gui_input.connect(_on_buy_input.bind(key))
		_canvas.add_child(btn)

	_rows.append({
		"key": key, "level": level, "cost": cost,
		"name_label": name_label, "level_label": level_label,
		"value_label": value_label,
	})


func _get_stat_value_text(key: String) -> String:
	var level: int = GameManager.player_data.get("upgrade_%s_level" % key, 0)
	match key:
		"hp":
			return "当前: %d" % (10 + level * 2)
		"speed":
			return "当前: %d" % int(180 + level * 10)
		"mana":
			return "当前: %d" % int(50 + level * 10)
		"regen":
			return "当前: %.1f/秒" % (3.0 + level * 0.5)
	return ""


func _refresh_ui() -> void:
	_build_ui()


func _on_buy_input(event: InputEvent, stat: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if GameManager.purchase_upgrade(stat):
			if _player:
				_player._load_from_game_manager()
			_refresh_ui()
		else:
			# 练习时长不足的反馈
			pass


func _on_close_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_close()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		_close()


func _close() -> void:
	if _canvas:
		_canvas.queue_free()
	queue_free()
