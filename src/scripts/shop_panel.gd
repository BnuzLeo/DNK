extends Node

## 鸡哥铁匠 — 武器商店面板

var _canvas: CanvasLayer
var _player: Node

const SHOP_WEAPONS := ["shotgun", "gatling", "freeze", "dart"]


func show_panel(player: Node) -> void:
	_player = player
	_canvas = CanvasLayer.new()
	_canvas.layer = 29
	add_child(_canvas)
	_build_ui()


func _build_ui() -> void:
	for child in _canvas.get_children():
		child.queue_free()

	# 半透明遮罩
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.65)
	bg.size = Vector2(960, 640)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.add_child(bg)

	# 面板背景
	var panel := ColorRect.new()
	panel.color = Color(0.1, 0.1, 0.12)
	panel.position = Vector2(130, 60)
	panel.size = Vector2(700, 520)
	_canvas.add_child(panel)
	panel.draw.connect(_draw_panel_border.bind(panel))

	# 标题
	var title := Label.new()
	title.text = "鸡哥铁匠 - 武器商店"
	title.position = Vector2(160, 75)
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.5, 0.6, 0.8))
	_canvas.add_child(title)

	# 货币
	var currency := Label.new()
	currency.text = "坤币: %d" % GameManager.kun_coins
	currency.position = Vector2(620, 80)
	currency.add_theme_font_size_override("font_size", 16)
	currency.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
	currency.name = "CoinLabel"
	_canvas.add_child(currency)

	# 武器列表
	var y_offset := 120.0
	for key in SHOP_WEAPONS:
		_create_weapon_row(key, y_offset)
		y_offset += 95.0

	# 关闭按钮
	var close_btn := Label.new()
	close_btn.text = "[ 关闭 (ESC) ]"
	close_btn.position = Vector2(440, 550)
	close_btn.add_theme_font_size_override("font_size", 16)
	close_btn.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	close_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	close_btn.gui_input.connect(_on_close_input)
	_canvas.add_child(close_btn)


func _draw_panel_border(panel: ColorRect) -> void:
	panel.draw_rect(Rect2(Vector2.ZERO, panel.size), Color(0.3, 0.4, 0.7), false, 2.0)


func _create_weapon_row(key: String, y: float) -> void:
	var weapon: Dictionary = _player.WEAPONS[key]
	var price: int = GameManager.WEAPON_COSTS[key]
	var owned: bool = _player.has_weapon(key)
	var can_buy: bool = not owned and GameManager.kun_coins >= price

	# 武器名
	var name_label := Label.new()
	name_label.text = weapon.name
	name_label.position = Vector2(160, y)
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	_canvas.add_child(name_label)

	# 武器类型
	var type_text := ""
	match weapon.type:
		"bullet": type_text = "射击"
		"spray": type_text = "喷射"
		"dart": type_text = "飞镖"
	var type_label := Label.new()
	type_label.text = "[%s]" % type_text
	type_label.position = Vector2(300, y + 3)
	type_label.add_theme_font_size_override("font_size", 14)
	type_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	_canvas.add_child(type_label)

	# 属性
	var stats_text := "伤害:%d" % weapon.damage
	if weapon.type == "bullet" or weapon.type == "dart":
		if weapon.count > 1:
			stats_text += "  弹数:%d" % weapon.count
		stats_text += "  CD:%.2fs" % weapon.cooldown
	if weapon.has("mana") and weapon.mana > 0:
		stats_text += "  蓝耗:%d" % weapon.mana
	if weapon.has("mana_per_sec"):
		stats_text += "  蓝耗:%d/秒" % weapon.mana_per_sec
	var stats_label := Label.new()
	stats_label.text = stats_text
	stats_label.position = Vector2(160, y + 26)
	stats_label.add_theme_font_size_override("font_size", 13)
	stats_label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
	_canvas.add_child(stats_label)

	# 价格/状态
	if owned:
		var owned_label := Label.new()
		owned_label.text = "[ 已拥有 ]"
		owned_label.position = Vector2(600, y + 8)
		owned_label.add_theme_font_size_override("font_size", 16)
		owned_label.add_theme_color_override("font_color", Color(0.0, 0.9, 0.4))
		_canvas.add_child(owned_label)
	else:
		var price_label := Label.new()
		price_label.text = "坤币: %d" % price
		price_label.position = Vector2(600, y)
		price_label.add_theme_font_size_override("font_size", 14)
		var price_color := Color(1.0, 0.84, 0.0) if can_buy else Color(0.5, 0.3, 0.3)
		price_label.add_theme_color_override("font_color", price_color)
		_canvas.add_child(price_label)

		var btn := Label.new()
		btn.text = "[ 购买 ]"
		btn.position = Vector2(600, y + 24)
		btn.add_theme_font_size_override("font_size", 16)
		var btn_color := Color(0.0, 0.9, 0.4) if can_buy else Color(0.4, 0.4, 0.4)
		btn.add_theme_color_override("font_color", btn_color)
		if can_buy:
			btn.mouse_filter = Control.MOUSE_FILTER_STOP
			btn.gui_input.connect(_on_buy_input.bind(key))
		_canvas.add_child(btn)

	# 分割线
	var sep := ColorRect.new()
	sep.color = Color(0.2, 0.2, 0.25)
	sep.position = Vector2(160, y + 75)
	sep.size = Vector2(640, 1)
	_canvas.add_child(sep)


func _on_buy_input(event: InputEvent, key: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if GameManager.purchase_weapon(key):
			if _player:
				_player.add_weapon(key)
			_build_ui()
		else:
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
