extends Area2D

## NPC交互区域 — 靠近后显示"按E交互"，按E打开面板

const VS := preload("res://scripts/visual_spec.gd")

const NPC_ANIMATIONS := {
	"broker": {
		"path": "res://assets/export/characters/npc/尖叫鸡_sheet.png",
		"frames": 7,
		"fps": 20.0,
		"frame_size": Vector2i(96, 96),
	},
	"smith": {
		"path": "res://assets/export/characters/npc/卡皮巴拉_sheet.png",
		"frames": 8,
		"fps": 16.0,
		"frame_size": Vector2i(96, 96),
	},
}

var npc_type: String = ""
var display_name: String = ""
var npc_color := Color.WHITE
var _player_in_range := false
var _panel_open := false
var _prompt_alpha := 0.0
var _panel_node: Node = null
var _sprite: AnimatedSprite2D = null
var _sprite_type := ""


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_setup_sprite()


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_range = true


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_range = false


func _process(delta: float) -> void:
	if _sprite_type != npc_type:
		_setup_sprite()
	var target := 1.0 if _player_in_range else 0.0
	_prompt_alpha = lerpf(_prompt_alpha, target, delta * 8.0)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not _player_in_range or _panel_open:
		return
	if GameManager.state != GameManager.GameState.LOBBY:
		return
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_open_panel()


func _open_panel() -> void:
	_panel_open = true
	GameManager.change_state(GameManager.GameState.PAUSED)
	match npc_type:
		"smith":
			_panel_node = load("res://scripts/shop_panel.gd").new()
		"broker":
			_panel_node = load("res://scripts/talent_tree_panel.gd").new()
	if _panel_node:
		_panel_node.tree_exiting.connect(_on_panel_closed)
		get_tree().current_scene.add_child(_panel_node)
		if _panel_node.has_method("show_panel"):
			_panel_node.show_panel(_player_in_range_node())


func _player_in_range_node() -> Node:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0]
	return null


func _on_panel_closed() -> void:
	_panel_open = false
	if GameManager.state == GameManager.GameState.PAUSED:
		GameManager.change_state(GameManager.GameState.LOBBY)


func _setup_sprite() -> void:
	var config: Dictionary = NPC_ANIMATIONS.get(npc_type, {})
	if config.is_empty():
		if _sprite != null:
			_sprite.queue_free()
			_sprite = null
		_sprite_type = npc_type
		return
	var texture := _load_texture(config.get("path", ""))
	if texture == null:
		return
	if _sprite == null:
		_sprite = AnimatedSprite2D.new()
		_sprite.centered = true
		_sprite.z_index = 1
		add_child(_sprite)
	_sprite_type = npc_type
	_sprite.sprite_frames = _build_sprite_frames(texture, config)
	_sprite.flip_h = npc_type == "smith"
	_sprite.play("idle")
	var frame_size: Vector2i = config.get("frame_size", Vector2i(96, 96))
	if frame_size.y > 0:
		var scale_factor: float = VS.NPC_DISPLAY_HEIGHT / float(frame_size.y)
		_sprite.scale = Vector2(scale_factor, scale_factor)
		# Keep the existing interaction text positions below the NPC feet.
		_sprite.position = Vector2(0.0, -18.0)


func _build_sprite_frames(texture: Texture2D, config: Dictionary) -> SpriteFrames:
	var sprite_frames := SpriteFrames.new()
	sprite_frames.remove_animation("default")
	sprite_frames.add_animation("idle")
	sprite_frames.set_animation_speed("idle", float(config.get("fps", 12.0)))
	sprite_frames.set_animation_loop("idle", true)
	var frame_size: Vector2i = config.get("frame_size", Vector2i(96, 96))
	var frame_count := int(config.get("frames", 1))
	for frame_index in frame_count:
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(frame_index * frame_size.x, 0, frame_size.x, frame_size.y)
		sprite_frames.add_frame("idle", atlas)
	return sprite_frames


func _load_texture(path: String) -> Texture2D:
	var texture := load(path) as Texture2D
	if texture != null:
		return texture
	var image := Image.new()
	if image.load(path) != OK:
		return null
	return ImageTexture.create_from_image(image)


func _draw_fallback_body() -> void:
	# ── 人形角色绘制 ──
	# 肤色
	var skin := Color(0.9, 0.75, 0.6)
	# 衣服颜色
	var shirt := npc_color.darkened(0.2)
	var pants := Color(0.25, 0.2, 0.15)
	# 头发
	var hair := Color(0.15, 0.1, 0.05)

	# 头部
	draw_circle(Vector2(0, -28), 10.0, skin)
	draw_arc(Vector2(0, -28), 10.0, 0, TAU, 20, skin.darkened(0.2), 1.5)
	# 头发（半圆顶部）
	var hair_pts := PackedVector2Array()
	for i in 13:
		var a := PI + i * PI / 12.0
		hair_pts.append(Vector2(cos(a), sin(a)) * 10.5)
	hair_pts.append(Vector2(10.5, -28))
	hair_pts.append(Vector2(-10.5, -28))
	draw_colored_polygon(hair_pts, hair)

	# 眼睛
	draw_circle(Vector2(-4, -29), 1.5, Color(0.1, 0.05, 0.0))
	draw_circle(Vector2(4, -29), 1.5, Color(0.1, 0.05, 0.0))

	# 身体（躯干）
	draw_rect(Rect2(-10, -18, 20, 22), shirt)
	# 围裙（铁匠专属）
	if npc_type == "smith":
		var apron := Color(0.45, 0.3, 0.15)
		draw_rect(Rect2(-8, -10, 16, 18), apron)
		draw_rect(Rect2(-8, -10, 16, 18), apron.darkened(0.3), false, 1.0)
		# 围裙带子
		draw_line(Vector2(-8, -8), Vector2(-14, -12), apron, 2.0)
		draw_line(Vector2(8, -8), Vector2(14, -12), apron, 2.0)

	# 手臂
	draw_line(Vector2(-10, -14), Vector2(-16, 0), skin, 3.0)
	draw_line(Vector2(10, -14), Vector2(16, 0), skin, 3.0)
	# 手
	draw_circle(Vector2(-16, 0), 3.0, skin)
	draw_circle(Vector2(16, 0), 3.0, skin)

	# 腿
	draw_line(Vector2(-5, 4), Vector2(-6, 18), pants, 4.0)
	draw_line(Vector2(5, 4), Vector2(6, 18), pants, 4.0)
	# 鞋子
	draw_rect(Rect2(-9, 16, 7, 5), Color(0.2, 0.15, 0.1))
	draw_rect(Rect2(3, 16, 7, 5), Color(0.2, 0.15, 0.1))

	# 铁匠锤子（右手持锤）
	if npc_type == "smith":
		var hammer_color := Color(0.5, 0.5, 0.55)
		var handle_color := Color(0.55, 0.35, 0.15)
		# 锤柄
		draw_line(Vector2(16, 0), Vector2(22, -12), handle_color, 3.0)
		# 锤头
		draw_rect(Rect2(18, -18, 10, 8), hammer_color)
		draw_rect(Rect2(18, -18, 10, 8), hammer_color.darkened(0.3), false, 1.0)

	# 经纪人特征：领带 + 剪贴板
	if npc_type == "broker":
		# 领带
		var tie := Color(0.8, 0.2, 0.2)
		var tie_pts := PackedVector2Array()
		tie_pts.append(Vector2(-2, -18))
		tie_pts.append(Vector2(2, -18))
		tie_pts.append(Vector2(4, -4))
		tie_pts.append(Vector2(0, 0))
		tie_pts.append(Vector2(-4, -4))
		draw_colored_polygon(tie_pts, tie)
		# 剪贴板（左手持）
		var board := Color(0.55, 0.45, 0.25)
		draw_rect(Rect2(-24, -10, 12, 16), board)
		draw_rect(Rect2(-24, -10, 12, 16), board.darkened(0.3), false, 1.0)
		# 纸张
		draw_rect(Rect2(-22, -8, 8, 11), Color(0.95, 0.95, 0.9))
		# 文字线条
		for line_i in 3:
			draw_line(Vector2(-21, -5 + line_i * 3), Vector2(-16, -5 + line_i * 3), Color(0.3, 0.3, 0.3), 1.0)
		# 夹子
		draw_rect(Rect2(-20, -12, 4, 3), Color(0.7, 0.7, 0.7))


func _draw() -> void:
	if _sprite == null:
		_draw_fallback_body()

	# 名字
	var name_size := ThemeDB.fallback_font.get_string_size(display_name,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
	draw_string(ThemeDB.fallback_font, Vector2(-name_size.x / 2, 36),
		display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, npc_color.lightened(0.4))

	# 交互提示
	if _prompt_alpha > 0.05:
		var prompt_text := "按 E 交互"
		var p_size := ThemeDB.fallback_font.get_string_size(prompt_text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
		var c := Color(1, 1, 0.6, _prompt_alpha)
		draw_string(ThemeDB.fallback_font, Vector2(-p_size.x / 2, 56),
			prompt_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, c)
