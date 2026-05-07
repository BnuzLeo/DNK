extends Node2D

# 房间状态
enum RoomState { INACTIVE, ACTIVE, CLEARED }

const CELL_SIZE := Vector2(960, 640)
const WALL_T := 16.0
const DOOR_W := 64.0
const DOOR_GAP := 180.0
const GRID_SIZE := 5
const CENTER := Vector2i(2, 2)
const SPAWN_INTERVAL := 0.8

# 房间数据
class RoomData:
	var grid_pos: Vector2i
	var state: int = RoomState.INACTIVE
	var enemies: Array[Area2D] = []
	var is_boss: bool = false
	var is_start: bool = false
	var explored: bool = false

var _rooms: Dictionary = {}  # Vector2i → RoomData
var _current_room: Vector2i = CENTER
var _game_over := false
var _boss_defeated := false
var _spawn_queue: Array = []
var _spawn_timer := 0.0

# 房间连接（哪些方向有门）
var _doors: Dictionary = {}  # Vector2i → {n:bool, s:bool, e:bool, w:bool}

# 门区域
var _door_n: Area2D
var _door_s: Area2D
var _door_e: Area2D
var _door_w: Area2D

# HUD
var _fps_label: Label
var _stats_label: Label
var _kills_label: Label
var _weapon_label: Label
var _hp_bar: ColorRect
var _hp_bar_bg: ColorRect
var _mana_bar: ColorRect
var _mana_bar_bg: ColorRect
var _room_label: Label
var _minimap: Control

@onready var cam: Camera2D = $Camera2D


func _ready() -> void:
	GameManager.change_state(GameManager.GameState.PLAYING)
	$Player.hp_changed.connect(_on_player_hp_changed)
	$Player.player_died.connect(_on_player_died)

	_generate_floor()
	_create_hud()
	_create_minimap()

	# 玩家出生在起点房间中心
	var start_center: Vector2 = Vector2(CENTER) * CELL_SIZE + CELL_SIZE / 2
	$Player.position = start_center
	cam.position = start_center

	_enter_room(CENTER)
	_update_camera_limits()


func _generate_floor() -> void:
	_rooms.clear()
	_doors.clear()
	_boss_defeated = false

	# 确定 Boss 房间位置（随机边缘）
	var boss_pos := _random_edge_room()

	# 从中心到 Boss 生成一条路径
	var path := _generate_path(CENTER, boss_pos)

	# 路径上的房间都激活
	for pos in path:
		_rooms[pos] = RoomData.new()
		_rooms[pos].grid_pos = pos
		if pos == boss_pos:
			_rooms[pos].is_boss = true
		if pos == CENTER:
			_rooms[pos].is_start = true

	# 路径之外加几个随机房间增加探索感
	for pos in path:
		for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var adj: Vector2i = pos + dir
			if adj not in _rooms and _in_bounds(adj) and randf() < 0.4:
				_rooms[adj] = RoomData.new()
				_rooms[adj].grid_pos = adj

	# 生成门连接
	for pos in _rooms:
		_doors[pos] = {"n": false, "s": false, "e": false, "w": false}
	for pos in _rooms:
		if Vector2i(pos.x, pos.y - 1) in _rooms:
			_doors[pos].n = true
		if Vector2i(pos.x, pos.y + 1) in _rooms:
			_doors[pos].s = true
		if Vector2i(pos.x + 1, pos.y) in _rooms:
			_doors[pos].e = true
		if Vector2i(pos.x - 1, pos.y) in _rooms:
			_doors[pos].w = true


func _random_edge_room() -> Vector2i:
	var edges: Array[Vector2i] = []
	for x in range(GRID_SIZE):
		for y in range(GRID_SIZE):
			if x == 0 or x == GRID_SIZE - 1 or y == 0 or y == GRID_SIZE - 1:
				if Vector2i(x, y) != CENTER:
					edges.append(Vector2i(x, y))
	return edges[randi() % edges.size()]


func _generate_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = [from]
	var current := from
	while current != to:
		var dx := signi(to.x - current.x)
		var dy := signi(to.y - current.y)
		# 随机选择水平或垂直移动
		if randf() < 0.5 and dx != 0:
			current.x += dx
		elif dy != 0:
			current.y += dy
		else:
			current.x += dx
		if current not in path:
			path.append(current)
	return path


func _in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < GRID_SIZE and pos.y >= 0 and pos.y < GRID_SIZE


func _enter_room(pos: Vector2i) -> void:
	_current_room = pos
	var room: RoomData = _rooms[pos]

	if not room.explored:
		room.explored = true
		room.state = RoomState.ACTIVE
		_spawn_enemies(pos)
		queue_redraw()
		if _minimap:
			_minimap.queue_redraw()


func _spawn_enemies(room_pos: Vector2i) -> void:
	var room: RoomData = _rooms[room_pos]
	var room_origin: Vector2 = Vector2(room_pos) * CELL_SIZE
	var center: Vector2 = room_origin + CELL_SIZE / 2

	if room.is_boss:
		_spawn_boss(center, room, room_origin)
	else:
		var count := 3 + randi() % 4
		for i in count:
			var offset := Vector2(randf_range(-300, 300), randf_range(-200, 200))
			var pos := center + offset
			if pos.distance_to(center) < 80:
				pos = center + offset.normalized() * 120
			_spawn_enemy(pos, room, room_origin)


func _spawn_enemy(pos: Vector2, room: RoomData, origin: Vector2) -> void:
	var enemy_scene: PackedScene = preload("res://scenes/Enemy.tscn")
	var enemy: Area2D = enemy_scene.instantiate()
	enemy.global_position = pos
	enemy.setup($Player)
	enemy.room_origin = origin
	add_child(enemy)
	room.enemies.append(enemy)
	enemy.tree_exiting.connect(_on_enemy_died.bind(room))


func _spawn_boss(pos: Vector2, room: RoomData, origin: Vector2) -> void:
	var enemy_scene: PackedScene = preload("res://scenes/Enemy.tscn")
	var boss: Area2D = enemy_scene.instantiate()
	boss.global_position = pos
	boss.setup($Player)
	boss.max_hp = 100
	boss.hp = 100
	boss.scale = Vector2(2, 2)
	boss.room_origin = origin
	add_child(boss)
	room.enemies.append(boss)
	boss.tree_exiting.connect(_on_boss_died.bind(room))


func _on_enemy_died(room: RoomData) -> void:
	room.enemies = room.enemies.filter(func(e): return is_instance_valid(e))
	if room.enemies.is_empty():
		_room_cleared(room)


func _on_boss_died(room: RoomData) -> void:
	_boss_defeated = true
	room.enemies = room.enemies.filter(func(e): return is_instance_valid(e))
	if room.enemies.is_empty():
		_room_cleared(room)
	# 显示传送门提示
	_show_portal_hint()


func _room_cleared(room: RoomData) -> void:
	room.state = RoomState.CLEARED
	queue_redraw()
	if _minimap:
		_minimap.queue_redraw()


func _show_portal_hint() -> void:
	var label := Label.new()
	label.text = "Boss 已击败！回到起点传送门离开"
	label.position = Vector2(300, 40)
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(1.0, 0.53, 0.0))
	var canvas := CanvasLayer.new()
	canvas.layer = 30
	canvas.add_child(label)
	add_child(canvas)
	# 3 秒后消失
	await get_tree().create_timer(3.0).timeout
	if is_instance_valid(canvas):
		canvas.queue_free()


func _update_camera_limits() -> void:
	# 摄像机限制为整个已探索楼层区域
	var min_x := 999999.0
	var min_y := 999999.0
	var max_x := -999999.0
	var max_y := -999999.0
	for pos in _rooms:
		var room: RoomData = _rooms[pos]
		if room.explored:
			var o: Vector2 = Vector2(pos) * CELL_SIZE
			min_x = minf(min_x, o.x)
			min_y = minf(min_y, o.y)
			max_x = maxf(max_x, o.x + CELL_SIZE.x)
			max_y = maxf(max_y, o.y + CELL_SIZE.y)
	cam.limit_left = int(min_x)
	cam.limit_top = int(min_y)
	cam.limit_right = int(max_x)
	cam.limit_bottom = int(max_y)


func _physics_process(_delta: float) -> void:
	if GameManager.state != GameManager.GameState.PLAYING:
		return

	var player_pos: Vector2 = $Player.global_position

	# 根据玩家位置判断当前房间
	var gx := int(floor(player_pos.x / CELL_SIZE.x))
	var gy := int(floor(player_pos.y / CELL_SIZE.y))
	var grid_pos := Vector2i(gx, gy)

	if grid_pos != _current_room and grid_pos in _rooms:
		_current_room = grid_pos
		var room: RoomData = _rooms[grid_pos]
		if not room.explored:
			room.explored = true
			room.state = RoomState.ACTIVE
			_spawn_enemies(grid_pos)
			_update_camera_limits()
			queue_redraw()
			if _minimap:
				_minimap.queue_redraw()
		elif room.state == RoomState.CLEARED:
			queue_redraw()
			if _minimap:
				_minimap.queue_redraw()

	# 边界碰撞：未清空的房间，敌人存在时不能穿过门
	var origin: Vector2 = Vector2(_current_room) * CELL_SIZE
	var margin := 16.0
	var door_zone := DOOR_GAP / 2
	var can_exit: bool = _rooms[_current_room].state == RoomState.CLEARED
	var doors: Dictionary = _doors[_current_room]
	var cx := origin.x + CELL_SIZE.x / 2
	var cy := origin.y + CELL_SIZE.y / 2

	# 上边界
	if player_pos.y < origin.y + margin:
		if can_exit and doors.n and absf(player_pos.x - cx) < door_zone:
			pass  # 可以通过
		else:
			$Player.position.y = origin.y + margin
	# 下边界
	if player_pos.y > origin.y + CELL_SIZE.y - margin:
		if can_exit and doors.s and absf(player_pos.x - cx) < door_zone:
			pass
		else:
			$Player.position.y = origin.y + CELL_SIZE.y - margin
	# 左边界
	if player_pos.x < origin.x + margin:
		if can_exit and doors.w and absf(player_pos.y - cy) < door_zone:
			pass
		else:
			$Player.position.x = origin.x + margin
	# 右边界
	if player_pos.x > origin.x + CELL_SIZE.x - margin:
		if can_exit and doors.e and absf(player_pos.y - cy) < door_zone:
			pass
		else:
			$Player.position.x = origin.x + CELL_SIZE.x - margin

	# 摄像机跟随玩家
	cam.position = player_pos

	# 传送门：Boss 已击败，回到起点
	if _boss_defeated and _current_room == CENTER:
		var room: RoomData = _rooms[CENTER]
		if room.state == RoomState.CLEARED:
			GameManager.change_state(GameManager.GameState.GAME_OVER)
			_show_victory()

func _create_hud() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 10
	add_child(canvas)

	_fps_label = Label.new()
	_fps_label.position = Vector2(10, 10)
	_fps_label.add_theme_font_size_override("font_size", 14)
	_fps_label.add_theme_color_override("font_color", Color.WHITE)
	canvas.add_child(_fps_label)

	_stats_label = Label.new()
	_stats_label.position = Vector2(10, 30)
	_stats_label.add_theme_font_size_override("font_size", 14)
	_stats_label.add_theme_color_override("font_color", Color.WHITE)
	canvas.add_child(_stats_label)

	_kills_label = Label.new()
	_kills_label.position = Vector2(10, 50)
	_kills_label.add_theme_font_size_override("font_size", 14)
	_kills_label.add_theme_color_override("font_color", Color(1.0, 0.53, 0.0))
	canvas.add_child(_kills_label)

	_weapon_label = Label.new()
	_weapon_label.position = Vector2(10, 70)
	_weapon_label.add_theme_font_size_override("font_size", 14)
	_weapon_label.add_theme_color_override("font_color", Color(0.0, 1.0, 0.53))
	canvas.add_child(_weapon_label)

	_room_label = Label.new()
	_room_label.position = Vector2(800, 10)
	_room_label.add_theme_font_size_override("font_size", 16)
	_room_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.0))
	canvas.add_child(_room_label)

	# 血条
	_hp_bar_bg = ColorRect.new()
	_hp_bar_bg.position = Vector2(10, 94)
	_hp_bar_bg.size = Vector2(102, 14)
	_hp_bar_bg.color = Color(0.2, 0.2, 0.2)
	canvas.add_child(_hp_bar_bg)

	_hp_bar = ColorRect.new()
	_hp_bar.position = Vector2(11, 95)
	_hp_bar.size = Vector2(100, 12)
	_hp_bar.color = Color(0.0, 0.8, 0.2)
	canvas.add_child(_hp_bar)

	# 蓝条
	_mana_bar_bg = ColorRect.new()
	_mana_bar_bg.position = Vector2(10, 112)
	_mana_bar_bg.size = Vector2(102, 10)
	_mana_bar_bg.color = Color(0.2, 0.2, 0.2)
	canvas.add_child(_mana_bar_bg)

	_mana_bar = ColorRect.new()
	_mana_bar.position = Vector2(11, 113)
	_mana_bar.size = Vector2(100, 8)
	_mana_bar.color = Color(0.2, 0.4, 1.0)
	canvas.add_child(_mana_bar)


func _process(_delta: float) -> void:
	_fps_label.text = "FPS: %d" % Engine.get_frames_per_second()

	var pool := $BulletPool
	if pool:
		var stats: Dictionary = pool.get_stats()
		_stats_label.text = "子弹: %d/%d (玩家) %d/%d (敌人)" % [
			stats.active_player, stats.total_player,
			stats.active_enemy, stats.total_enemy
		]

	_kills_label.text = "击杀: %d" % GameManager.total_kills
	_weapon_label.text = "武器: %s (Q切换) 蓝: %d/%d" % [
		$Player.get_weapon_name(),
		int($Player.mana),
		int($Player.MAX_MANA)
	]

	var mana_ratio: float = $Player.mana / $Player.MAX_MANA
	_mana_bar.size.x = 100.0 * mana_ratio

	# 房间信息
	var room: RoomData = _rooms.get(_current_room)
	if room:
		var status := "已清" if room.state == RoomState.CLEARED else "战斗中"
		var room_type := " [BOSS]" if room.is_boss else ""
		_room_label.text = "%d,%d%s %s" % [_current_room.x, _current_room.y, room_type, status]


func _on_player_hp_changed(current: int, max_hp: int) -> void:
	var ratio := float(current) / float(max_hp)
	_hp_bar.size.x = 100.0 * ratio
	if ratio > 0.3:
		_hp_bar.color = Color(0.0, 0.8, 0.2).lerp(Color(1.0, 0.0, 0.0), 1.0 - ratio)
	else:
		_hp_bar.color = Color(1.0, 0.0, 0.0)


func _on_player_died() -> void:
	_game_over = true
	GameManager.change_state(GameManager.GameState.GAME_OVER)
	_show_game_over()


func _show_game_over() -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.size = CELL_SIZE

	var canvas := CanvasLayer.new()
	canvas.layer = 40
	add_child(canvas)
	canvas.add_child(overlay)

	var label := Label.new()
	label.text = "游戏结束\n击杀: %d\n\n按 R 重新开始" % GameManager.total_kills
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.position = Vector2(380, 240)
	canvas.add_child(label)


func _show_victory() -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.size = CELL_SIZE

	var canvas := CanvasLayer.new()
	canvas.layer = 40
	add_child(canvas)
	canvas.add_child(overlay)

	var label := Label.new()
	label.text = "通关！\n击杀: %d\n\n按 R 再来一局" % GameManager.total_kills
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.0))
	label.position = Vector2(380, 240)
	canvas.add_child(label)


func _input(event: InputEvent) -> void:
	if _game_over and event is InputEventKey and event.pressed and event.keycode == KEY_R:
		GameManager.restart_game()


func _create_minimap() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 20
	add_child(canvas)

	var minimap_control := Control.new()
	minimap_control.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	minimap_control.offset_left = -150
	minimap_control.offset_top = 10
	minimap_control.offset_right = -10
	minimap_control.offset_bottom = 130
	minimap_control.name = "Minimap"
	minimap_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	minimap_control.draw.connect(_draw_minimap.bind(minimap_control))
	canvas.add_child(minimap_control)
	_minimap = minimap_control


func _draw_minimap(ctrl: Control) -> void:
	if _rooms.is_empty():
		return

	var cell_size := Vector2(20, 16)
	var padding := Vector2(8, 8)
	var total := Vector2(GRID_SIZE, GRID_SIZE) * cell_size + padding * 2

	# 背景
	ctrl.draw_rect(Rect2(Vector2.ZERO, total), Color(0, 0, 0, 0.7))

	for pos in _rooms:
		var room: RoomData = _rooms[pos]
		var r_pos := padding + Vector2(pos) * cell_size

		if not room.explored:
			# 未探索：暗灰
			ctrl.draw_rect(Rect2(r_pos, cell_size), Color(0.2, 0.2, 0.2, 0.5))
			continue

		# 已探索房间颜色
		var color := Color(0.3, 0.3, 0.35)
		if room.is_boss:
			color = Color(0.6, 0.15, 0.15)
		elif room.state == RoomState.CLEARED:
			color = Color(0.1, 0.5, 0.3)
		elif room.state == RoomState.ACTIVE:
			color = Color(0.5, 0.4, 0.1)

		ctrl.draw_rect(Rect2(r_pos, cell_size), color)

		# 当前房间高亮
		if pos == _current_room:
			ctrl.draw_rect(Rect2(r_pos - Vector2(1, 1), cell_size + Vector2(2, 2)), Color(1, 1, 0), false, 1.5)

		# 门连接线
		var doors: Dictionary = _doors[pos]
		var door_color := Color(0.0, 0.8, 0.4, 0.6)
		if doors.n:
			ctrl.draw_rect(Rect2(r_pos + Vector2(cell_size.x / 2 - 2, -3), Vector2(4, 3)), door_color)
		if doors.s:
			ctrl.draw_rect(Rect2(r_pos + Vector2(cell_size.x / 2 - 2, cell_size.y), Vector2(4, 3)), door_color)
		if doors.e:
			ctrl.draw_rect(Rect2(r_pos + Vector2(cell_size.x, cell_size.y / 2 - 2), Vector2(3, 4)), door_color)
		if doors.w:
			ctrl.draw_rect(Rect2(r_pos + Vector2(-3, cell_size.y / 2 - 2), Vector2(3, 4)), door_color)


func _draw() -> void:
	# 绘制所有房间（在世界坐标中）
	for pos in _rooms:
		var room: RoomData = _rooms[pos]
		var origin: Vector2 = Vector2(pos) * CELL_SIZE

		# 未探索的房间不绘制
		if not room.explored:
			continue

		# 房间背景
		var bg_color := Color(0.13, 0.14, 0.16)
		if room.is_boss:
			bg_color = Color(0.18, 0.10, 0.10)
		elif room.is_start:
			bg_color = Color(0.10, 0.16, 0.13)
		draw_rect(Rect2(origin, CELL_SIZE), bg_color)

		# 墙壁
		var wall_color := Color(0.35, 0.35, 0.35)
		draw_rect(Rect2(origin, Vector2(CELL_SIZE.x, WALL_T)), wall_color)
		draw_rect(Rect2(Vector2(origin.x, origin.y + CELL_SIZE.y - WALL_T), Vector2(CELL_SIZE.x, WALL_T)), wall_color)
		draw_rect(Rect2(origin, Vector2(WALL_T, CELL_SIZE.y)), wall_color)
		draw_rect(Rect2(Vector2(origin.x + CELL_SIZE.x - WALL_T, origin.y), Vector2(WALL_T, CELL_SIZE.y)), wall_color)

		# 门
		var door_color := Color(0.0, 0.4, 0.2, 0.3)
		if room.state == RoomState.CLEARED:
			door_color = Color(0.0, 1.0, 0.53, 0.6)

		var doors: Dictionary = _doors[pos]
		var cx := origin.x + CELL_SIZE.x / 2
		var cy := origin.y + CELL_SIZE.y / 2

		if doors.n:
			draw_rect(Rect2(Vector2(cx - DOOR_GAP / 2, origin.y), Vector2(DOOR_GAP, WALL_T)), door_color)
		if doors.s:
			draw_rect(Rect2(Vector2(cx - DOOR_GAP / 2, origin.y + CELL_SIZE.y - WALL_T), Vector2(DOOR_GAP, WALL_T)), door_color)
		if doors.e:
			draw_rect(Rect2(Vector2(origin.x + CELL_SIZE.x - WALL_T, cy - DOOR_GAP / 2), Vector2(WALL_T, DOOR_GAP)), door_color)
		if doors.w:
			draw_rect(Rect2(Vector2(origin.x, cy - DOOR_GAP / 2), Vector2(WALL_T, DOOR_GAP)), door_color)

		# Boss 房标记
		if room.is_boss and room.state != RoomState.CLEARED:
			draw_string(ThemeDB.fallback_font, origin + Vector2(CELL_SIZE.x / 2 - 30, 40), "BOSS", HORIZONTAL_ALIGNMENT_CENTER, -1, 20, Color(1.0, 0.0, 0.3))

	# 传送门（Boss 击败后在起点显示）
	if _boss_defeated and CENTER in _rooms:
		var portal_pos: Vector2 = Vector2(CENTER) * CELL_SIZE + CELL_SIZE / 2
		draw_circle(portal_pos, 30.0, Color(0.0, 0.898, 1.0, 0.3))
		draw_arc(portal_pos, 30.0, 0, TAU, 24, Color(0.0, 0.898, 1.0), 3.0)
