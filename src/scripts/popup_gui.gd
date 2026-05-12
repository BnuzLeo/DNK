extends RefCounted
class_name PopupGui

const VS := preload("res://scripts/visual_spec.gd")

const PANEL_SIZE := Vector2(750.0, 500.0)
const BACKGROUND_PATH := "res://assets/export/gui/background.png"
const TITLE_PATH := "res://assets/export/gui/title.png"
const CLOSE_BUTTON_PATH := "res://assets/export/gui/close-btn.png"
const CONFIRM_BUTTON_PATH := "res://assets/export/gui/confirm-btn.png"
const NORMAL_BUTTON_PATH := "res://assets/export/gui/normal-btn.png"


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
	var panel := TextureRect.new()
	panel.texture = load_texture(BACKGROUND_PATH)
	panel.position = panel_position()
	panel.size = PANEL_SIZE
	panel.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	panel.stretch_mode = TextureRect.STRETCH_SCALE
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(panel)
	return panel


static func add_title(parent: Node, text: String) -> Label:
	var texture := load_texture(TITLE_PATH)
	var title_size := texture.get_size() if texture != null else Vector2(262.0, 60.0)
	var pos := panel_position() + Vector2((PANEL_SIZE.x - title_size.x) * 0.5, 10.0)

	var title_bg := TextureRect.new()
	title_bg.texture = texture
	title_bg.position = pos
	title_bg.size = title_size
	title_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(title_bg)

	var label := Label.new()
	label.text = text
	label.position = pos
	label.size = title_size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color(0.98, 0.9, 0.55))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


static func add_close_button(parent: Node, pressed: Callable) -> Control:
	var texture := load_texture(CLOSE_BUTTON_PATH)
	var size := texture.get_size() if texture != null else Vector2(43.0, 45.0)
	var pos := panel_position() + Vector2(PANEL_SIZE.x - size.x - 18.0, 16.0)
	return add_image_button(parent, pos, size, texture, "", pressed)


static func add_normal_button(parent: Node, pos: Vector2, text: String, pressed: Callable, enabled: bool = true) -> Control:
	var texture := load_texture(NORMAL_BUTTON_PATH)
	var size := texture.get_size() if texture != null else Vector2(135.0, 67.0)
	return add_image_button(parent, pos, size, texture, text, pressed, enabled)


static func add_confirm_button(parent: Node, pos: Vector2, text: String, pressed: Callable, enabled: bool = true) -> Control:
	var texture := load_texture(CONFIRM_BUTTON_PATH)
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
	var button := Control.new()
	button.position = pos
	button.size = size
	button.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	button.modulate = Color.WHITE if enabled else Color(0.45, 0.45, 0.45, 0.85)
	parent.add_child(button)

	var image := TextureRect.new()
	image.texture = texture
	image.size = size
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_SCALE
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(image)

	if text != "":
		var label := Label.new()
		label.text = text
		label.size = size
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 18)
		label.add_theme_color_override("font_color", Color(0.98, 0.92, 0.68) if enabled else Color(0.55, 0.55, 0.55))
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(label)

	if enabled:
		button.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				pressed.call()
		)

	return button
