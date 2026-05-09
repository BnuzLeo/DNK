extends Node

## 天赋树面板 — 练习生基地专属

var _canvas: CanvasLayer
var _player: Node
var _anim_timer := 0.0
var _status_msg := ""
var _status_timer := 0.0

# 天赋节点定义
# { key, name, desc, max_level, costs[], values[], pos, color }
var _nodes: Array[Dictionary] = []
var _node_levels: Dictionary = {}  # {key: current_level}

const BRANCH_COLORS := {
	"hp":    Color(0.2, 0.8, 0.3),
	"speed": Color(0.3, 0.7, 1.0),
	"mana":  Color(0.6, 0.4, 1.0),
}

# 连线定义 [from_key, to_key]
var _connections: Array[Array] = []


func _init() -> void:
	_define_tree()


func _define_tree() -> void:
	# ── 中心节点 ──
	_nodes.append({
		"key": "core", "name": "基础强化", "desc": "全属性+1",
		"max_level": 5, "costs": [5, 15, 30, 60, 120],
		"values": ["+1", "+2", "+3", "+4", "+5"],
		"pos": Vector2(480, 180), "color": Color(1.0, 0.9, 0.5),
		"branch": "core", "parent": "",
	})

	# ── 生命分支（左）──
	_nodes.append({
		"key": "hp_max", "name": "生命强化", "desc": "最大生命+3",
		"max_level": 5, "costs": [8, 20, 40, 80, 160],
		"values": ["+3", "+6", "+9", "+12", "+15"],
		"pos": Vector2(260, 270), "color": BRANCH_COLORS.hp,
		"branch": "hp", "parent": "core",
	})
	_nodes.append({
		"key": "hp_regen", "name": "生命回复", "desc": "每秒回复生命",
		"max_level": 3, "costs": [15, 40, 100],
		"values": ["0.5/秒", "1.0/秒", "2.0/秒"],
		"pos": Vector2(160, 370), "color": BRANCH_COLORS.hp,
		"branch": "hp", "parent": "hp_max",
	})
	_nodes.append({
		"key": "shield", "name": "护盾", "desc": "开局获得护盾",
		"max_level": 3, "costs": [20, 50, 120],
		"values": ["+2", "+5", "+10"],
		"pos": Vector2(360, 370), "color": BRANCH_COLORS.hp,
		"branch": "hp", "parent": "hp_max",
	})

	# ── 速度分支（中）──
	_nodes.append({
		"key": "spd_up", "name": "疾行", "desc": "移动速度+8",
		"max_level": 5, "costs": [8, 20, 40, 80, 160],
		"values": ["+8", "+16", "+24", "+32", "+40"],
		"pos": Vector2(480, 290), "color": BRANCH_COLORS.speed,
		"branch": "speed", "parent": "core",
	})
	_nodes.append({
		"key": "dash_cd", "name": "闪避精通", "desc": "闪避冷却-0.5秒",
		"max_level": 3, "costs": [20, 50, 120],
		"values": ["-0.5s", "-1.0s", "-2.0s"],
		"pos": Vector2(480, 400), "color": BRANCH_COLORS.speed,
		"branch": "speed", "parent": "spd_up",
	})

	# ── 法力分支（右）──
	_nodes.append({
		"key": "mana_max", "name": "法力扩展", "desc": "最大法力+10",
		"max_level": 5, "costs": [8, 20, 40, 80, 160],
		"values": ["+10", "+20", "+30", "+40", "+50"],
		"pos": Vector2(700, 270), "color": BRANCH_COLORS.mana,
		"branch": "mana", "parent": "core",
	})
	_nodes.append({
		"key": "mana_regen", "name": "法力涌动", "desc": "法力回复+0.5/秒",
		"max_level": 3, "costs": [15, 40, 100],
		"values": ["+0.5", "+1.0", "+2.0"],
		"pos": Vector2(600, 370), "color": BRANCH_COLORS.mana,
		"branch": "mana", "parent": "mana_max",
	})
	_nodes.append({
		"key": "dmg_up", "name": "火力增幅", "desc": "武器伤害+1",
		"max_level": 3, "costs": [25, 60, 150],
		"values": ["+1", "+2", "+4"],
		"pos": Vector2(800, 370), "color": BRANCH_COLORS.mana,
		"branch": "mana", "parent": "mana_max",
	})

	# 连线
	_connections = [
		["core", "hp_max"],
		["hp_max", "hp_regen"],
		["hp_max", "shield"],
		["core", "spd_up"],
		["spd_up", "dash_cd"],
		["core", "mana_max"],
		["mana_max", "mana_regen"],
		["mana_max", "dmg_up"],
	]


var _status_label: Label


func _process(delta: float) -> void:
	if _status_timer > 0.0:
		_status_timer -= delta
		if _status_timer <= 0.0:
			_status_msg = ""
			if _status_label:
				_status_label.text = ""


func show_panel(player: Node) -> void:
	_player = player
	process_mode = Node.PROCESS_MODE_ALWAYS
	_canvas = CanvasLayer.new()
	_canvas.layer = 29
	add_child(_canvas)
	_load_levels()
	_build_ui()


func _load_levels() -> void:
	var data: Dictionary = GameManager.player_data
	_node_levels = {}
	for node_def in _nodes:
		var key: String = node_def.key
		_node_levels[key] = data.get("talent_%s" % key, 0)


func _save_levels() -> void:
	for key in _node_levels:
		GameManager.player_data["talent_%s" % key] = _node_levels[key]


func _build_ui() -> void:
	for child in _canvas.get_children():
		child.queue_free()

	# 遮罩（IGNORE 让鼠标事件穿透到 _unhandled_input 处理节点点击）
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.75)
	bg.size = Vector2(960, 640)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(bg)

	# 标题
	var title := Label.new()
	title.text = "天赋树"
	title.position = Vector2(430, 60)
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	_canvas.add_child(title)

	# 练习时长
	var pt_label := Label.new()
	pt_label.text = "练习时长: %d" % GameManager.practice_time
	pt_label.position = Vector2(680, 70)
	pt_label.add_theme_font_size_override("font_size", 16)
	pt_label.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	_canvas.add_child(pt_label)

	# 重置按钮
	var reset_btn := Label.new()
	reset_btn.text = "[ 重置天赋 ]"
	reset_btn.position = Vector2(200, 70)
	reset_btn.add_theme_font_size_override("font_size", 16)
	reset_btn.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	reset_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	reset_btn.gui_input.connect(_on_reset_input)
	_canvas.add_child(reset_btn)

	# 关闭
	var close_btn := Label.new()
	close_btn.text = "ESC 关闭"
	close_btn.position = Vector2(440, 590)
	close_btn.add_theme_font_size_override("font_size", 14)
	close_btn.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	_canvas.add_child(close_btn)

	# 状态提示
	_status_label = Label.new()
	_status_label.text = _status_msg
	_status_label.position = Vector2(350, 560)
	_status_label.add_theme_font_size_override("font_size", 15)
	_status_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.3))
	_canvas.add_child(_status_label)

	# 绘制连线和节点
	var tree_draw := Control.new()
	tree_draw.size = Vector2(960, 640)
	tree_draw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tree_draw.draw.connect(_draw_tree)
	_canvas.add_child(tree_draw)


func _draw_tree() -> void:
	# 画连线
	for conn in _connections:
		var from_node := _find_node(conn[0])
		var to_node := _find_node(conn[1])
		if from_node and to_node:
			var from_level: int = _node_levels.get(from_node.key, 0)
			var line_color: Color = from_node.color.darkened(0.3) if from_level > 0 else Color(0.2, 0.2, 0.25)
			_canvas.get_child(-1).draw_line(from_node.pos, to_node.pos, line_color, 3.0)

	# 画节点
	for node_def in _nodes:
		_draw_node(node_def)


func _draw_node(node_def: Dictionary) -> void:
	var key: String = node_def.key
	var level: int = _node_levels.get(key, 0)
	var max_lv: int = node_def.max_level
	var pos: Vector2 = node_def.pos
	var color: Color = node_def.color
	var is_max := level >= max_lv
	var parent_key: String = node_def.parent
	var parent_unlocked: bool = parent_key == "" or _node_levels.get(parent_key, 0) > 0

	# 节点圆圈
	var radius := 22.0
	var draw_color: Color
	if level > 0:
		draw_color = color.lerp(Color.WHITE, 0.2) if is_max else color
	else:
		draw_color = color.darkened(0.6) if parent_unlocked else Color(0.15, 0.15, 0.15)

	# 背景
	var node_ctrl := _canvas.get_child(-1)  # tree_draw control
	node_ctrl.draw_circle(pos, radius, draw_color.darkened(0.4))
	node_ctrl.draw_arc(pos, radius, 0, TAU, 24, color if level > 0 else Color(0.3, 0.3, 0.3), 2.5)

	# 已升级的填充
	if level > 0:
		var fill_ratio := float(level) / float(max_lv)
		var fill_pts := PackedVector2Array()
		fill_pts.append(pos)
		var sweep := TAU * fill_ratio
		for i in 13:
			var a := -PI / 2 + sweep * i / 12.0
			fill_pts.append(pos + Vector2(cos(a), sin(a)) * (radius - 3))
		node_ctrl.draw_colored_polygon(fill_pts, color.lerp(Color.WHITE, 0.3))

	# 名字
	var name_size := ThemeDB.fallback_font.get_string_size(node_def.name,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
	node_ctrl.draw_string(ThemeDB.fallback_font, pos + Vector2(-name_size.x / 2, radius + 14),
		node_def.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.9, 0.9, 0.9))

	# 等级
	var lv_text := "%d/%d" % [level, max_lv]
	var lv_size := ThemeDB.fallback_font.get_string_size(lv_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11)
	node_ctrl.draw_string(ThemeDB.fallback_font, pos + Vector2(-lv_size.x / 2, 4),
		lv_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.9))


func _find_node(key: String) -> Dictionary:
	for n in _nodes:
		if n.key == key:
			return n
	return {}


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_save_levels()
		_apply_talents()
		_close()
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		var click_pos: Vector2 = event.position
		for node_def in _nodes:
			if click_pos.distance_to(node_def.pos) < 25.0:
				_try_upgrade(node_def)
				break


func _try_upgrade(node_def: Dictionary) -> void:
	var key: String = node_def.key
	var level: int = _node_levels.get(key, 0)
	var max_lv: int = node_def.max_level
	var parent_key: String = node_def.parent

	# 检查前置
	if parent_key != "" and _node_levels.get(parent_key, 0) <= 0:
		var parent_def := _find_node(parent_key)
		_show_status("需要先学习: %s" % parent_def.name)
		return

	# 检查是否满级
	if level >= max_lv:
		_show_status("已满级")
		return

	# 检查费用
	var costs: Array = node_def.costs
	var cost: int = costs[level]
	if GameManager.practice_time < cost:
		_show_status("练习时长不足 (需要%d)" % cost)
		return

	# 购买
	GameManager.practice_time -= cost
	_node_levels[key] = level + 1
	_save_levels()
	_apply_talents()
	_build_ui()


func _show_status(msg: String) -> void:
	_status_msg = msg
	_status_timer = 2.0
	if _status_label:
		_status_label.text = msg


func _on_reset_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# 退还所有花费
		var refund := 0
		for node_def in _nodes:
			var key: String = node_def.key
			var level: int = _node_levels.get(key, 0)
			var costs: Array = node_def.costs
			for i in level:
				refund += costs[i]
			_node_levels[key] = 0
		GameManager.practice_time += refund
		_save_levels()
		_apply_talents()
		_build_ui()


func _apply_talents() -> void:
	if _player and is_instance_valid(_player):
		_player._load_from_game_manager()


func _close() -> void:
	if _canvas:
		_canvas.queue_free()
	queue_free()
