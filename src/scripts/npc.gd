extends Area2D

## NPC交互区域 — 靠近后显示"按E交互"，按E打开面板

var npc_type: String = ""
var display_name: String = ""
var npc_color := Color.WHITE
var _player_in_range := false
var _panel_open := false
var _prompt_alpha := 0.0
var _panel_node: Node = null


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_range = true


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_range = false


func _process(delta: float) -> void:
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
		"broker":
			_panel_node = load("res://scripts/upgrade_panel.gd").new()
		"smith":
			_panel_node = load("res://scripts/shop_panel.gd").new()
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


func _draw() -> void:
	# NPC 身体
	var body_size := Vector2(32, 40)
	draw_rect(Rect2(-body_size.x / 2, -body_size.y / 2, body_size.x, body_size.y),
		npc_color.darkened(0.3))
	draw_rect(Rect2(-body_size.x / 2, -body_size.y / 2, body_size.x, body_size.y),
		npc_color, false, 2.0)

	# NPC 头部（圆形）
	draw_circle(Vector2(0, -body_size.y / 2 - 8), 12.0, npc_color.lightened(0.2))
	draw_arc(Vector2(0, -body_size.y / 2 - 8), 12.0, 0, TAU, 20,
		npc_color.darkened(0.1), 2.0)

	# NPC 职业图标
	match npc_type:
		"broker":
			# 星形（经纪人）
			_draw_star(Vector2(0, -2), 8.0, Color(1, 1, 0.6))
		"smith":
			# 锤子（铁匠）
			_draw_hammer(Vector2(0, -2), Color(0.8, 0.85, 1.0))

	# 名字
	var name_size := ThemeDB.fallback_font.get_string_size(display_name,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
	draw_string(ThemeDB.fallback_font, Vector2(-name_size.x / 2, body_size.y / 2 + 16),
		display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, npc_color.lightened(0.4))

	# 交互提示
	if _prompt_alpha > 0.05:
		var prompt_text := "按 E 交互"
		var p_size := ThemeDB.fallback_font.get_string_size(prompt_text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
		var c := Color(1, 1, 0.6, _prompt_alpha)
		draw_string(ThemeDB.fallback_font, Vector2(-p_size.x / 2, body_size.y / 2 + 36),
			prompt_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, c)


func _draw_star(center: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 5:
		var outer_angle := -PI / 2 + i * TAU / 5
		var inner_angle := outer_angle + TAU / 10
		points.append(center + Vector2(cos(outer_angle), sin(outer_angle)) * radius)
		points.append(center + Vector2(cos(inner_angle), sin(inner_angle)) * radius * 0.4)
	draw_colored_polygon(points, color)


func _draw_hammer(center: Vector2, color: Color) -> void:
	# 锤柄
	draw_line(center + Vector2(0, 6), center + Vector2(0, -2), color.darkened(0.3), 3.0)
	# 锤头
	draw_rect(Rect2(center.x - 6, center.y - 8, 12, 6), color)
