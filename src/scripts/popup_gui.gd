extends RefCounted
class_name PopupGui

const VS := preload("res://scripts/visual_spec.gd")

const PANEL_SIZE := Vector2(750.0, 500.0)
const HEADER_SIZE := Vector2(750.0, 64.0)
const BACKGROUND_PATH := "res://assets/export/gui/ui_popup_panel.png"
const HEADER_PATH := "res://assets/export/gui/ui_popup_header.png"
const CLOSE_BUTTON_PATH := "res://assets/export/gui/ui_close_button.png"
const CONFIRM_BUTTON_PATH := "res://assets/export/gui/ui_button_primary.png"
const NORMAL_BUTTON_PATH := "res://assets/export/gui/ui_button_secondary.png"
const DISABLED_BUTTON_PATH := "res://assets/export/gui/ui_button_disabled.png"
const POPUP_PANEL_SCENE := preload("res://scenes/ui/PopupPanel.tscn")
const POPUP_TITLE_SCENE := preload("res://scenes/ui/PopupTitle.tscn")
const POPUP_BUTTON_SCENE := preload("res://scenes/ui/PopupButton.tscn")


static func panel_position() -> Vector2:
	return (VS.VIEWPORT_SIZE - PANEL_SIZE) * 0.5


static func add_overlay(parent: Node, mouse_filter: int = Control.MOUSE_FILTER_STOP) -> ColorRect:
	var overlay := ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.72)
	overlay.size = VS.VIEWPORT_SIZE
	overlay.mouse_filter = mouse_filter
	parent.add_child(overlay)
	return overlay


static func add_panel(parent: Node) -> TextureRect:
	var panel := POPUP_PANEL_SCENE.instantiate() as TextureRect
	panel.texture = load_texture(BACKGROUND_PATH)
	panel.position = panel_position()
	panel.size = PANEL_SIZE
	panel.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	panel.stretch_mode = TextureRect.STRETCH_SCALE
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(panel)
	return panel


static func add_title(parent: Node, text: String, icon_path: String = "") -> Label:
	var title_size := HEADER_SIZE
	var pos := panel_position() + Vector2(0.0, 0.0)

	var title_root := POPUP_TITLE_SCENE.instantiate() as Control
	title_root.position = pos
	title_root.size = title_size
	parent.add_child(title_root)

	var icon := title_root.get_node("Icon") as TextureRect
	if icon_path != "":
		icon.texture = load_texture(icon_path)
		icon.visible = true
	else:
		icon.visible = false

	var label := title_root.get_node("TitleLabel") as Label
	label.text = text
	return label


static func add_close_button(parent: Node, pressed: Callable) -> Control:
	var texture := load_texture(CLOSE_BUTTON_PATH)
	var size := texture.get_size() if texture != null else Vector2(43.0, 45.0)
	var pos := panel_position() + Vector2(PANEL_SIZE.x - size.x - 18.0, 16.0)
	return add_image_button(parent, pos, size, texture, "", pressed)


static func add_normal_button(parent: Node, pos: Vector2, text: String, pressed: Callable, enabled: bool = true) -> Control:
	var texture := load_texture(NORMAL_BUTTON_PATH if enabled else DISABLED_BUTTON_PATH)
	var size := texture.get_size() if texture != null else Vector2(135.0, 67.0)
	return add_image_button(parent, pos, size, texture, text, pressed, enabled)


static func add_confirm_button(parent: Node, pos: Vector2, text: String, pressed: Callable, enabled: bool = true) -> Control:
	var texture := load_texture(CONFIRM_BUTTON_PATH if enabled else DISABLED_BUTTON_PATH)
	var size := texture.get_size() if texture != null else Vector2(136.0, 66.0)
	return add_image_button(parent, pos, size, texture, text, pressed, enabled)


static func load_texture(path: String) -> Texture2D:
	var texture := load(path) as Texture2D
	if texture != null:
		return texture
	var image := Image.new()
	if image.load(path) != OK:
		return null
	return ImageTexture.create_from_image(image)


static func add_image_button(
	parent: Node,
	pos: Vector2,
	size: Vector2,
	texture: Texture2D,
	text: String,
	pressed: Callable,
	enabled: bool = true
) -> Control:
	var button := POPUP_BUTTON_SCENE.instantiate() as Control
	button.position = pos
	button.size = size
	button.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	button.modulate = Color.WHITE if enabled else Color(0.45, 0.45, 0.45, 0.85)
	parent.add_child(button)

	var image := button.get_node("Background") as TextureRect
	image.texture = texture
	image.size = size

	var label := button.get_node("Text") as Label
	label.size = size
	if text != "":
		label.text = text
		label.add_theme_color_override("font_color", Color(0.98, 0.92, 0.68) if enabled else Color(0.55, 0.55, 0.55))
		label.visible = true
	else:
		label.visible = false

	if enabled:
		button.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				GameAudio.play_button()
				pressed.call()
		)

	return button
