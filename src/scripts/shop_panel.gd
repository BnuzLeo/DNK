extends Node

## 卡皮巴拉 — 武器商店面板

const SHOP_PANEL_SCENE := preload("res://scenes/ui/WeaponShopPanel.tscn")
const WEAPON_ICON_PATHS := {
	"jntm": "res://assets/export/weapon/weapon_03/飞熊军激光炮.png",
	"chicken_foot": "res://assets/export/weapon/weapon_02/瓦克恩冲锋枪.png",
}
const SHOP_ROW_PATHS := {
	"jntm": "WeaponRows/JntmRow",
	"chicken_foot": "WeaponRows/ChickenFootRow",
}
const BUY_BUTTON_ENABLED_TEXTURE := preload("res://assets/export/gui/ui_button_primary.png")
const BUY_BUTTON_DISABLED_TEXTURE := preload("res://assets/export/gui/ui_button_disabled.png")

var _canvas: CanvasLayer
var _player: Node
var _weapon_icon_cache: Dictionary = {}

const SHOP_WEAPONS := ["jntm", "chicken_foot"]


func show_panel(player: Node) -> void:
	_player = player
	process_mode = Node.PROCESS_MODE_ALWAYS
	_canvas = CanvasLayer.new()
	_canvas.layer = 29
	_canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_canvas)
	_build_ui()


func _build_ui() -> void:
	for child in _canvas.get_children():
		child.queue_free()

	var shell := SHOP_PANEL_SCENE.instantiate() as Control
	_canvas.add_child(shell)
	var close_button := shell.get_node("CloseButton") as Button
	close_button.pressed.connect(GameAudio.play_button)
	close_button.pressed.connect(_close)
	var currency := shell.get_node("CoinLabel") as Label
	currency.text = "%d" % GameManager.kun_coins

	for key in SHOP_WEAPONS:
		_populate_weapon_row(shell, key)


func _populate_weapon_row(shell: Control, key: String) -> void:
	if not SHOP_ROW_PATHS.has(key):
		return
	var row := shell.get_node_or_null(String(SHOP_ROW_PATHS[key])) as Control
	if row == null:
		return

	var weapon: Dictionary = _player.WEAPONS[key]
	var price: int = GameManager.WEAPON_COSTS[key]
	var owned: bool = key in GameManager.player_data.owned_weapons
	var can_buy: bool = not owned and GameManager.kun_coins >= price

	var weapon_icon := row.get_node("WeaponIcon") as TextureRect
	weapon_icon.texture = _get_weapon_icon(key)

	var name_label := row.get_node("NameLabel") as Label
	name_label.text = weapon.name

	var type_text := ""
	match weapon.type:
		"basketball": type_text = "投射"
		"room_blast": type_text = "全屏"
		"rooster": type_text = "追击"
		"man_gun": type_text = "锁定枪械"
		"laser_gun": type_text = "持续激光"
		_: type_text = "武器"
	var type_label := row.get_node("TypeLabel") as Label
	type_label.text = "[%s]" % type_text

	var stats_label := row.get_node("StatsLabel") as Label
	stats_label.text = _get_weapon_stats_text(weapon)

	var price_label := row.get_node("PriceLabel") as Label
	price_label.text = "坤币: %d" % price
	price_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0) if can_buy else Color(0.5, 0.3, 0.3))
	price_label.visible = not owned

	(row.get_node("OwnedIcon") as Control).visible = owned
	(row.get_node("OwnedLabel") as Control).visible = owned

	var buy_button := row.get_node("BuyButton") as Control
	buy_button.visible = not owned
	_configure_buy_button(buy_button, key, can_buy)


func _buy_weapon(key: String) -> void:
	if GameManager.purchase_weapon(key):
		_build_ui()


func _get_weapon_icon(key: String) -> Texture2D:
	if not WEAPON_ICON_PATHS.has(key):
		return null
	if _weapon_icon_cache.has(key):
		return _weapon_icon_cache[key]
	var texture := load(String(WEAPON_ICON_PATHS[key])) as Texture2D
	_weapon_icon_cache[key] = texture
	return texture


func _configure_buy_button(button: Control, key: String, enabled: bool) -> void:
	button.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	button.modulate = Color.WHITE if enabled else Color(0.45, 0.45, 0.45, 0.85)

	var background := button.get_node("Background") as TextureRect
	background.texture = BUY_BUTTON_ENABLED_TEXTURE if enabled else BUY_BUTTON_DISABLED_TEXTURE

	var text_label := button.get_node("Text") as Label
	text_label.text = "购买"
	text_label.add_theme_color_override("font_color", Color(0.98, 0.92, 0.68) if enabled else Color(0.55, 0.55, 0.55))

	if enabled:
		button.gui_input.connect(_on_buy_button_input.bind(key))


func _on_buy_button_input(event: InputEvent, key: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		GameAudio.play_button()
		_buy_weapon(key)


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


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		_close()


func _close() -> void:
	if _canvas:
		_canvas.queue_free()
	queue_free()
