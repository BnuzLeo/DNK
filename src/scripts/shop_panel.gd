extends Node

## 卡皮巴拉 — 武器商店面板

const PopupGui := preload("res://scripts/popup_gui.gd")
const SHOP_PANEL_SCENE := preload("res://scenes/ui/WeaponShopPanel.tscn")

var _canvas: CanvasLayer
var _player: Node
var _panel_origin := Vector2.ZERO

const SHOP_WEAPONS := ["jntm", "chicken_foot"]


func show_panel(player: Node) -> void:
	_player = player
	process_mode = Node.PROCESS_MODE_ALWAYS
	_canvas = CanvasLayer.new()
	_canvas.layer = 29
	add_child(_canvas)
	_build_ui()


func _build_ui() -> void:
	for child in _canvas.get_children():
		child.queue_free()

	var shell := SHOP_PANEL_SCENE.instantiate() as Control
	_canvas.add_child(shell)
	_panel_origin = (shell.get_node("Panel") as Control).global_position
	var close_button := shell.get_node("CloseButton") as Button
	close_button.pressed.connect(GameAudio.play_button)
	close_button.pressed.connect(_close)
	var currency := shell.get_node("CoinLabel") as Label
	currency.text = "%d" % GameManager.kun_coins

	# 武器列表
	var y_offset := _panel_origin.y + 128.0
	for key in SHOP_WEAPONS:
		_create_weapon_row(key, y_offset)
		y_offset += 95.0


func _create_weapon_row(key: String, y: float) -> void:
	var weapon: Dictionary = _player.WEAPONS[key]
	var price: int = GameManager.WEAPON_COSTS[key]
	var owned: bool = key in GameManager.player_data.owned_weapons
	var can_buy: bool = not owned and GameManager.kun_coins >= price
	var left_x := _panel_origin.x + 58.0
	var action_x := _panel_origin.x + 558.0

	var slot_bg := TextureRect.new()
	slot_bg.texture = PopupGui.load_texture("res://assets/export/gui/ui_popup_slot.png")
	slot_bg.position = Vector2(left_x - 10.0, y - 14.0)
	slot_bg.size = Vector2(96.0, 96.0)
	slot_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	slot_bg.stretch_mode = TextureRect.STRETCH_SCALE
	slot_bg.modulate = Color(1, 1, 1, 0.72)
	_canvas.add_child(slot_bg)

	# 武器名
	var name_label := Label.new()
	name_label.text = weapon.name
	name_label.position = Vector2(left_x + 108.0, y)
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	_canvas.add_child(name_label)

	# 武器类型
	var type_text := ""
	match weapon.type:
		"basketball": type_text = "投射"
		"room_blast": type_text = "全屏"
		"rooster": type_text = "追击"
		"man_gun": type_text = "锁定枪械"
		"laser_gun": type_text = "持续激光"
		_: type_text = "武器"
	var type_label := Label.new()
	type_label.text = "[%s]" % type_text
	type_label.position = Vector2(left_x + 258.0, y + 3.0)
	type_label.add_theme_font_size_override("font_size", 14)
	type_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	_canvas.add_child(type_label)

	# 属性
	var stats_text := _get_weapon_stats_text(weapon)
	var stats_label := Label.new()
	stats_label.text = stats_text
	stats_label.position = Vector2(left_x + 108.0, y + 30.0)
	stats_label.add_theme_font_size_override("font_size", 13)
	stats_label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
	_canvas.add_child(stats_label)

	# 价格/状态
	if owned:
		var owned_icon := TextureRect.new()
		owned_icon.texture = PopupGui.load_texture("res://assets/export/gui/icon_owned.png")
		owned_icon.position = Vector2(action_x + 16.0, y + 17.0)
		owned_icon.size = Vector2(32, 32)
		owned_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		owned_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_canvas.add_child(owned_icon)

		var owned_label := Label.new()
		owned_label.text = "已拥有"
		owned_label.position = Vector2(action_x + 54.0, y + 22.0)
		owned_label.add_theme_font_size_override("font_size", 16)
		owned_label.add_theme_color_override("font_color", Color(0.0, 0.9, 0.4))
		_canvas.add_child(owned_label)
	else:
		var price_label := Label.new()
		price_label.text = "坤币: %d" % price
		price_label.position = Vector2(action_x + 28.0, y - 18.0)
		price_label.add_theme_font_size_override("font_size", 14)
		var price_color := Color(1.0, 0.84, 0.0) if can_buy else Color(0.5, 0.3, 0.3)
		price_label.add_theme_color_override("font_color", price_color)
		_canvas.add_child(price_label)

		PopupGui.add_confirm_button(_canvas, Vector2(action_x, y + 16.0), "购买", Callable(self, "_buy_weapon").bind(key), can_buy)

	# 分割线
	var sep := ColorRect.new()
	sep.color = Color(0.2, 0.2, 0.25)
	sep.position = Vector2(left_x + 108.0, y + 78.0)
	sep.size = Vector2(635.0, 1.0)
	_canvas.add_child(sep)


func _buy_weapon(key: String) -> void:
	if GameManager.purchase_weapon(key):
		_build_ui()


func _on_buy_input(event: InputEvent, key: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if GameManager.purchase_weapon(key):
			_build_ui()


func _get_weapon_stats_text(weapon: Dictionary) -> String:
	match weapon.type:
		"basketball":
			return "伤害:%d  普通:%d发散弹/%.2fs  狂暴:连点全场投篮" % [weapon.damage, weapon.count, weapon.cooldown]
		"room_blast":
			return "全房间伤害:%d  CD:%.1fs  狂暴:3次/%.1fs" % [weapon.damage, weapon.cooldown, weapon.berserk_interval]
		"rooster":
			return "伤害:%d  CD:%.1fs  狂暴:%d只/CD%.1fs" % [weapon.damage, weapon.cooldown, weapon.berserk_count, weapon.berserk_cooldown]
		"man_gun":
			return "伤害:%d  CD:%.1fs  狂暴:全体锁定/CD%.1fs" % [weapon.damage, weapon.cooldown, weapon.berserk_cooldown]
		"laser_gun":
			return "伤害:%d/跳  按住持续激光  狂暴:墙体折射2次" % weapon.damage
	return "伤害:%d" % weapon.damage


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
