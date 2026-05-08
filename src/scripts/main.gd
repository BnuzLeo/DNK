extends Node2D

## 主场景控制器 - 走廊式房间制地牢 + HUD + 小地图

enum RoomState { INACTIVE, ACTIVE, CLEARED }

# 网格单元格大小（一个格子 = 房间 + 走廊空间）
const CELL_W := 960
const CELL_H := 640
# 房间实际大小（小于单元格，留出走廊空间）
const ROOM_W := 700
const ROOM_H := 400
# 房间在单元格内的偏移（居中）
const ROOM_PAD_X := 130
const ROOM_PAD_Y := 120
# 走廊宽度
const CORRIDOR_W := 80
# 墙壁厚度
const WALL_T := 12
const DOOR_COLLISION_LAYER := 16

const GRID_SIZE := 5
const CENTER := Vector2i(2, 2)

class RoomData:
	var grid_pos: Vector2i
	var state: int = RoomState.INACTIVE
	var enemies: Array[Area2D] = []
	var is_boss: bool = false
	var is_start: bool = false
	var explored: bool = false
	var spawned: bool = false

var _rooms: Dictionary = {}
var _current_room: Vector2i = CENTER
var _game_over := false
var _boss_defeated := false
var _boss_pos: Vector2i = CENTER
var _boss_entry_pos: Vector2i = CENTER
var _portal_active := false
var _portal_pos := Vector2.ZERO
var _doors: Dictionary = {}
var _wall_bodies: Array[StaticBody2D] = []
var _spawn_warning_positions: Array[Vector2] = []
var _spawn_warning_timer := 0.0
var _spawn_warning_room: Vector2i = CENTER

# HUD
var _fps_label: Label
var _kills_label: Label
var _weapon_label: Label
var _hp_bar: ColorRect
var _hp_bar_bg: ColorRect
var _mana_bar: ColorRect
var _mana_bar_bg: ColorRect
var _room_label: Label
var _minimap: Control


func _ready() -> void:
	GameManager.change_state(GameManager.GameState.PLAYING)
	$Player.hp_changed.connect(_on_player_hp_changed)
	$Player.player_died.connect(_on_player_died)

	_generate_floor()
	_create_dungeon()
	_create_hud()
	_create_minimap()

	var start_center := Vector2(CENTER.x * CELL_W + CELL_W / 2, CENTER.y * CELL_H + CELL_H / 2)
	$Player.position = start_center

	_current_room = CENTER
	var room: RoomData = _rooms[CENTER]
	room.explored = true
	_mark_adjacent_explored(CENTER)


# ── 地牢生成 ──────────────────────────────────────────

func _generate_floor() -> void:
	_rooms.clear()
	_doors.clear()
	_boss_defeated = false
	_portal_active = false
	_spawn_warning_positions.clear()
	_spawn_warning_timer = 0.0

	var boss_pos := _random_edge_room()
	_boss_pos = boss_pos
	var path := _generate_path(CENTER, boss_pos)
	_boss_entry_pos = path[path.size() - 2] if path.size() > 1 else CENTER

	for pos in path:
		_rooms[pos] = RoomData.new()
		_rooms[pos].grid_pos = pos
		if pos == boss_pos:
			_rooms[pos].is_boss = true
		if pos == CENTER:
			_rooms[pos].is_start = true

	for pos in path:
		# boss 房间是终点：不从 boss 生成分支，也不在 boss 周围生成额外入口。
		if pos == boss_pos:
			continue
		for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var adj: Vector2i = pos + dir
			if _can_add_branch_room(adj, boss_pos) and randf() < 0.4:
				_rooms[adj] = RoomData.new()
				_rooms[adj].grid_pos = adj


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


func _can_add_branch_room(pos: Vector2i, boss_pos: Vector2i) -> bool:
	if pos in _rooms or not _in_bounds(pos):
		return false
	if pos == boss_pos:
		return false
	if _is_cardinal_neighbor(pos, boss_pos) and pos != _boss_entry_pos:
		return false
	return true


func _is_cardinal_neighbor(a: Vector2i, b: Vector2i) -> bool:
	return absi(a.x - b.x) + absi(a.y - b.y) == 1


func _has_room_connection(from_pos: Vector2i, to_pos: Vector2i) -> bool:
	if from_pos not in _rooms or to_pos not in _rooms or not _is_cardinal_neighbor(from_pos, to_pos):
		return false
	if from_pos == _boss_pos:
		return to_pos == _boss_entry_pos
	if to_pos == _boss_pos:
		return from_pos == _boss_entry_pos
	return true


# ── 物理墙壁 + 门 ──────────────────────────────────────

func _create_dungeon() -> void:
	for pos in _rooms:
		var rx: float = pos.x * CELL_W + ROOM_PAD_X
		var ry: float = pos.y * CELL_H + ROOM_PAD_Y
		var north_pos := Vector2i(pos.x, pos.y - 1)
		var south_pos := Vector2i(pos.x, pos.y + 1)
		var west_pos := Vector2i(pos.x - 1, pos.y)
		var east_pos := Vector2i(pos.x + 1, pos.y)

		# 北墙（含门洞）
		var has_north := _has_room_connection(pos, north_pos)
		if has_north:
			var gap_l: float = rx + ROOM_W / 2 - CORRIDOR_W / 2
			var gap_r: float = rx + ROOM_W / 2 + CORRIDOR_W / 2
			_wall_segment(Vector2(rx, ry), Vector2(gap_l - rx, WALL_T))
			_wall_segment(Vector2(gap_r, ry), Vector2(rx + ROOM_W - gap_r, WALL_T))
		else:
			_wall_segment(Vector2(rx, ry), Vector2(ROOM_W, WALL_T))

		# 南墙（含门洞）
		var has_south := _has_room_connection(pos, south_pos)
		if has_south:
			var gap_l: float = rx + ROOM_W / 2 - CORRIDOR_W / 2
			var gap_r: float = rx + ROOM_W / 2 + CORRIDOR_W / 2
			_wall_segment(Vector2(rx, ry + ROOM_H - WALL_T), Vector2(gap_l - rx, WALL_T))
			_wall_segment(Vector2(gap_r, ry + ROOM_H - WALL_T), Vector2(rx + ROOM_W - gap_r, WALL_T))
		else:
			_wall_segment(Vector2(rx, ry + ROOM_H - WALL_T), Vector2(ROOM_W, WALL_T))

		# 西墙（含门洞）
		var has_west := _has_room_connection(pos, west_pos)
		if has_west:
			var gap_t: float = ry + ROOM_H / 2 - CORRIDOR_W / 2
			var gap_b: float = ry + ROOM_H / 2 + CORRIDOR_W / 2
			_wall_segment(Vector2(rx, ry), Vector2(WALL_T, gap_t - ry))
			_wall_segment(Vector2(rx, gap_b), Vector2(WALL_T, ry + ROOM_H - gap_b))
		else:
			_wall_segment(Vector2(rx, ry), Vector2(WALL_T, ROOM_H))

		# 东墙（含门洞）
		var has_east := _has_room_connection(pos, east_pos)
		if has_east:
			var gap_t: float = ry + ROOM_H / 2 - CORRIDOR_W / 2
			var gap_b: float = ry + ROOM_H / 2 + CORRIDOR_W / 2
			_wall_segment(Vector2(rx + ROOM_W - WALL_T, ry), Vector2(WALL_T, gap_t - ry))
			_wall_segment(Vector2(rx + ROOM_W - WALL_T, gap_b), Vector2(WALL_T, ry + ROOM_H - gap_b))
		else:
			_wall_segment(Vector2(rx + ROOM_W - WALL_T, ry), Vector2(WALL_T, ROOM_H))

		# 走廊墙壁（南走廊、东走廊由当前房间负责绘制）
		if has_south:
			var corr_x: float = pos.x * CELL_W + CELL_W / 2 - CORRIDOR_W / 2
			var corr_y_top: float = ry + ROOM_H
			var corr_y_bot: float = (pos.y + 1) * CELL_H + ROOM_PAD_Y
			var seg_h: float = corr_y_bot - corr_y_top
			_wall_segment(Vector2(corr_x, corr_y_top), Vector2(WALL_T, seg_h))
			_wall_segment(Vector2(corr_x + CORRIDOR_W - WALL_T, corr_y_top), Vector2(WALL_T, seg_h))
			# 转角封口（走廊墙与下一个房间墙壁的交汇处）
			var next_ry: float = (pos.y + 1) * CELL_H + ROOM_PAD_Y
			_wall_segment(Vector2(corr_x, next_ry - WALL_T), Vector2(WALL_T, WALL_T))
			_wall_segment(Vector2(corr_x + CORRIDOR_W - WALL_T, next_ry - WALL_T), Vector2(WALL_T, WALL_T))

		if has_east:
			var corr_y: float = pos.y * CELL_H + CELL_H / 2 - CORRIDOR_W / 2
			var corr_x_left: float = rx + ROOM_W
			var corr_x_right: float = (pos.x + 1) * CELL_W + ROOM_PAD_X
			var seg_w: float = corr_x_right - corr_x_left
			_wall_segment(Vector2(corr_x_left, corr_y), Vector2(seg_w, WALL_T))
			_wall_segment(Vector2(corr_x_left, corr_y + CORRIDOR_W - WALL_T), Vector2(seg_w, WALL_T))
			# 转角封口
			var next_rx: float = (pos.x + 1) * CELL_W + ROOM_PAD_X
			_wall_segment(Vector2(next_rx - WALL_T, corr_y), Vector2(WALL_T, WALL_T))
			_wall_segment(Vector2(next_rx - WALL_T, corr_y + CORRIDOR_W - WALL_T), Vector2(WALL_T, WALL_T))

		# 门（阻挡未清理房间的出口）
		_doors[pos] = {}
		if has_north:
			_doors[pos].n = _create_door(pos, "n")
		if has_south:
			_doors[pos].s = _create_door(pos, "s")
		if has_east:
			_doors[pos].e = _create_door(pos, "e")
		if has_west:
			_doors[pos].w = _create_door(pos, "w")


func _wall_segment(pos: Vector2, sz: Vector2) -> void:
	var body := StaticBody2D.new()
	body.position = pos + sz / 2
	body.collision_layer = 16
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = sz
	shape.shape = rect
	body.add_child(shape)
	add_child(body)
	_wall_bodies.append(body)


func _create_door(room_pos: Vector2i, dir: String) -> StaticBody2D:
	var rx: float = room_pos.x * CELL_W + ROOM_PAD_X
	var ry: float = room_pos.y * CELL_H + ROOM_PAD_Y
	var cx: float = rx + ROOM_W / 2
	var cy: float = ry + ROOM_H / 2
	var door := StaticBody2D.new()
	door.collision_layer = 0
	door.collision_mask = 0

	var shape_node := CollisionShape2D.new()
	var rect := RectangleShape2D.new()

	match dir:
		"n":
			rect.size = Vector2(CORRIDOR_W, WALL_T)
			door.position = Vector2(cx, ry - WALL_T / 2)
		"s":
			rect.size = Vector2(CORRIDOR_W, WALL_T)
			door.position = Vector2(cx, ry + ROOM_H + WALL_T / 2)
		"e":
			rect.size = Vector2(WALL_T, CORRIDOR_W)
			door.position = Vector2(rx + ROOM_W + WALL_T / 2, cy)
		"w":
			rect.size = Vector2(WALL_T, CORRIDOR_W)
			door.position = Vector2(rx - WALL_T / 2, cy)

	shape_node.shape = rect
	door.add_child(shape_node)
	door.add_to_group("doors")
	door.visible = false  # 初始不显示、不碰撞；进入房间后才锁门。
	add_child(door)
	return door


func _set_door_locked(door: StaticBody2D, locked: bool) -> void:
	door.visible = locked
	door.collision_layer = DOOR_COLLISION_LAYER if locked else 0


# ── 房间进入 ──────────────────────────────────────────

## 标记相邻房间为可见（小地图 + 渲染）
func _mark_adjacent_explored(pos: Vector2i) -> void:
	for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var adj: Vector2i = pos + dir
		if _has_room_connection(pos, adj) and not _rooms[adj].explored:
			_rooms[adj].explored = true
	if _minimap:
		_minimap.queue_redraw()


## 玩家真正进入房间内部后触发：关门 → 预警 → 出怪
func _on_player_entered_room(pos: Vector2i) -> void:
	var room: RoomData = _rooms[pos]
	if room.spawned or room.state == RoomState.CLEARED:
		return
	room.spawned = true
	room.state = RoomState.ACTIVE
	# 1) 关门
	_close_doors(pos)
	# 2) 预警 + 出怪
	_start_spawn_warning(pos)
	queue_redraw()
	if _minimap:
		_minimap.queue_redraw()


func _close_doors(pos: Vector2i) -> void:
	if pos not in _doors:
		return
	var locked_any := false
	for key in _doors[pos]:
		var door: StaticBody2D = _doors[pos][key]
		if is_instance_valid(door):
			_set_door_locked(door, true)
			locked_any = true
	if locked_any:
		_show_hint("房门已锁，清理怪物后开启", Color(1.0, 0.8, 0.0))


func _start_spawn_warning(pos: Vector2i) -> void:
	var room: RoomData = _rooms[pos]
	var cx: float = pos.x * CELL_W + CELL_W / 2
	var cy: float = pos.y * CELL_H + CELL_H / 2
	var center := Vector2(cx, cy)

	_spawn_warning_positions.clear()
	_spawn_warning_room = pos
	if room.is_boss:
		_spawn_warning_positions.append(center)
	else:
		var count := 3 + randi() % 4
		for i in count:
			var offset := Vector2(randf_range(-250, 250), randf_range(-150, 150))
			var p := center + offset
			if p.distance_to(center) < 80:
				p = center + offset.normalized() * 120
			_spawn_warning_positions.append(p)

	_spawn_warning_timer = 1.0
	queue_redraw()


# ── 敌人生成 ──────────────────────────────────────────

func _spawn_enemies(room_pos: Vector2i) -> void:
	var room: RoomData = _rooms[room_pos]
	var cx: float = room_pos.x * CELL_W + CELL_W / 2
	var cy: float = room_pos.y * CELL_H + CELL_H / 2
	var center := Vector2(cx, cy)
	var bounds := Rect2(
		Vector2(room_pos.x * CELL_W + ROOM_PAD_X + WALL_T, room_pos.y * CELL_H + ROOM_PAD_Y + WALL_T),
		Vector2(ROOM_W - WALL_T * 2, ROOM_H - WALL_T * 2)
	)

	if room.is_boss:
		_spawn_boss(center, room, bounds)
	else:
		var count := 3 + randi() % 4
		for i in count:
			var offset := Vector2(randf_range(-250, 250), randf_range(-150, 150))
			var pos := center + offset
			if pos.distance_to(center) < 80:
				pos = center + offset.normalized() * 120
			_spawn_enemy(pos, room, bounds)


func _spawn_enemies_with_positions(room_pos: Vector2i) -> void:
	if _spawn_warning_positions.is_empty():
		return
	var room: RoomData = _rooms[room_pos]
	var bounds := Rect2(
		Vector2(room_pos.x * CELL_W + ROOM_PAD_X + WALL_T, room_pos.y * CELL_H + ROOM_PAD_Y + WALL_T),
		Vector2(ROOM_W - WALL_T * 2, ROOM_H - WALL_T * 2)
	)
	if room.is_boss:
		_spawn_boss(_spawn_warning_positions[0], room, bounds)
	else:
		for pos in _spawn_warning_positions:
			_spawn_enemy(pos, room, bounds)


func _spawn_enemy(pos: Vector2, room: RoomData, bounds: Rect2) -> void:
	var enemy_scene: PackedScene = preload("res://scenes/Enemy.tscn")
	var enemy: Area2D = enemy_scene.instantiate()
	enemy.global_position = pos
	enemy.setup($Player)
	enemy.room_bounds = bounds
	add_child(enemy)
	room.enemies.append(enemy)
	enemy.tree_exiting.connect(_on_enemy_died.bind(room))


func _spawn_boss(pos: Vector2, room: RoomData, bounds: Rect2) -> void:
	var enemy_scene: PackedScene = preload("res://scenes/Enemy.tscn")
	var boss: Area2D = enemy_scene.instantiate()
	boss.global_position = pos
	boss.setup($Player)
	boss.max_hp = 100
	boss.hp = 100
	boss.scale = Vector2(2, 2)
	boss.room_bounds = bounds
	add_child(boss)
	room.enemies.append(boss)
	boss.tree_exiting.connect(_on_boss_died.bind(room))


func _on_enemy_died(room: RoomData) -> void:
	room.enemies = room.enemies.filter(func(e): return is_instance_valid(e) and not e._dying)
	if room.enemies.is_empty():
		_room_cleared(room)


func _on_boss_died(room: RoomData) -> void:
	_boss_defeated = true
	room.enemies = room.enemies.filter(func(e): return is_instance_valid(e) and not e._dying)
	if room.enemies.is_empty():
		_room_cleared(room)
	# 在 boss 房间生成传送门
	_portal_active = true
	_portal_pos = Vector2(_boss_pos.x * CELL_W + CELL_W / 2, _boss_pos.y * CELL_H + CELL_H / 2)
	queue_redraw()
	_show_hint("Boss 已击败！按 E 进入传送门", Color(0.0, 0.898, 1.0))


func _room_cleared(room: RoomData) -> void:
	room.state = RoomState.CLEARED
	# 移除该房间的所有门
	if room.grid_pos in _doors:
		for key in _doors[room.grid_pos]:
			var door: StaticBody2D = _doors[room.grid_pos][key]
			if is_instance_valid(door):
				_set_door_locked(door, false)
				door.queue_free()
		_doors[room.grid_pos] = {}
	_show_hint("门已开启", Color(0.0, 1.0, 0.53))
	queue_redraw()
	if _minimap:
		_minimap.queue_redraw()


func _show_hint(text: String, color: Color = Color.WHITE) -> void:
	var label := Label.new()
	label.text = text
	label.position = Vector2(380, 60)
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", color)
	var canvas := CanvasLayer.new()
	canvas.layer = 30
	canvas.add_child(label)
	add_child(canvas)
	await get_tree().create_timer(2.0).timeout
	if is_instance_valid(canvas):
		canvas.queue_free()


# ── 物理更新 ──────────────────────────────────────────

func _physics_process(_delta: float) -> void:
	if GameManager.state != GameManager.GameState.PLAYING:
		return

	var player_pos: Vector2 = $Player.global_position

	# 判断玩家当前所在格子
	var gx := int(floor(player_pos.x / CELL_W))
	var gy := int(floor(player_pos.y / CELL_H))
	var grid_pos := Vector2i(gx, gy)

	# 切换房间：更新探索状态
	if grid_pos != _current_room and grid_pos in _rooms:
		_current_room = grid_pos
		var room: RoomData = _rooms[grid_pos]
		if not room.explored:
			room.explored = true
			queue_redraw()
		_mark_adjacent_explored(grid_pos)

	# 检测玩家是否真正进入房间内部（触发锁门+出怪）
	if _current_room in _rooms:
		var room: RoomData = _rooms[_current_room]
		if not room.spawned:
			var rx: float = _current_room.x * CELL_W + ROOM_PAD_X
			var ry: float = _current_room.y * CELL_H + ROOM_PAD_Y
			if player_pos.x >= rx and player_pos.x <= rx + ROOM_W and \
			   player_pos.y >= ry and player_pos.y <= ry + ROOM_H:
				_on_player_entered_room(_current_room)


# ── HUD ──────────────────────────────────────────────

func _create_hud() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 10
	add_child(canvas)

	_fps_label = Label.new()
	_fps_label.position = Vector2(10, 10)
	_fps_label.add_theme_font_size_override("font_size", 14)
	_fps_label.add_theme_color_override("font_color", Color.WHITE)
	canvas.add_child(_fps_label)

	_kills_label = Label.new()
	_kills_label.position = Vector2(10, 28)
	_kills_label.add_theme_font_size_override("font_size", 14)
	_kills_label.add_theme_color_override("font_color", Color(1.0, 0.53, 0.0))
	canvas.add_child(_kills_label)

	_weapon_label = Label.new()
	_weapon_label.position = Vector2(10, 46)
	_weapon_label.add_theme_font_size_override("font_size", 14)
	_weapon_label.add_theme_color_override("font_color", Color(0.0, 1.0, 0.53))
	canvas.add_child(_weapon_label)

	_room_label = Label.new()
	_room_label.position = Vector2(800, 10)
	_room_label.add_theme_font_size_override("font_size", 16)
	_room_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.0))
	canvas.add_child(_room_label)

	_hp_bar_bg = ColorRect.new()
	_hp_bar_bg.position = Vector2(10, 68)
	_hp_bar_bg.size = Vector2(102, 14)
	_hp_bar_bg.color = Color(0.2, 0.2, 0.2)
	canvas.add_child(_hp_bar_bg)

	_hp_bar = ColorRect.new()
	_hp_bar.position = Vector2(11, 69)
	_hp_bar.size = Vector2(100, 12)
	_hp_bar.color = Color(0.0, 0.8, 0.2)
	canvas.add_child(_hp_bar)

	_mana_bar_bg = ColorRect.new()
	_mana_bar_bg.position = Vector2(10, 86)
	_mana_bar_bg.size = Vector2(102, 10)
	_mana_bar_bg.color = Color(0.2, 0.2, 0.2)
	canvas.add_child(_mana_bar_bg)

	_mana_bar = ColorRect.new()
	_mana_bar.position = Vector2(11, 87)
	_mana_bar.size = Vector2(100, 8)
	_mana_bar.color = Color(0.2, 0.4, 1.0)
	canvas.add_child(_mana_bar)


func _process(delta: float) -> void:
	_fps_label.text = "FPS: %d" % Engine.get_frames_per_second()
	_kills_label.text = "击杀: %d" % GameManager.total_kills
	_weapon_label.text = "武器: %s (Q切换) 蓝: %d" % [
		$Player.get_weapon_name(),
		int($Player.mana)
	]

	var mana_ratio: float = $Player.mana / $Player.MAX_MANA
	_mana_bar.size.x = 100.0 * mana_ratio

	var room: RoomData = _rooms.get(_current_room)
	if room:
		var status := "未触发"
		if room.state == RoomState.ACTIVE:
			status = "战斗中"
		elif room.state == RoomState.CLEARED:
			status = "已清"
		var room_type := " [BOSS]" if room.is_boss else ""
		_room_label.text = "%d,%d%s %s" % [_current_room.x, _current_room.y, room_type, status]

	# 怪物预警倒计时
	if _spawn_warning_timer > 0.0:
		_spawn_warning_timer -= delta
		queue_redraw()
		if _spawn_warning_timer <= 0.0:
			if _spawn_warning_room in _rooms:
				_spawn_enemies_with_positions(_spawn_warning_room)
			_spawn_warning_positions.clear()
			queue_redraw()


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
	overlay.size = Vector2(960, 640)

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
	overlay.size = Vector2(960, 640)

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

	# E 键进入传送门
	if _portal_active and event is InputEventKey and event.pressed and event.keycode == KEY_E:
		if $Player.global_position.distance_to(_portal_pos) < 40.0:
			_portal_active = false
			_game_over = true
			GameManager.change_state(GameManager.GameState.GAME_OVER)
			_show_victory()


# ── 小地图 ────────────────────────────────────────────

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
	var gap := 2.0
	var padding := Vector2(8, 8)
	var total := Vector2(GRID_SIZE, GRID_SIZE) * cell_size + padding * 2

	ctrl.draw_rect(Rect2(Vector2.ZERO, total), Color(0, 0, 0, 0.7))

	# 先画走廊连线
	for pos in _rooms:
		if not _rooms[pos].explored:
			continue
		var r_pos := padding + Vector2(pos) * cell_size
		var room_doors := _get_door_dirs(pos)
		for d in room_doors:
			var adj_pos := Vector2i(pos.x, pos.y)
			match d:
				"n": adj_pos = Vector2i(pos.x, pos.y - 1)
				"s": adj_pos = Vector2i(pos.x, pos.y + 1)
				"e": adj_pos = Vector2i(pos.x + 1, pos.y)
				"w": adj_pos = Vector2i(pos.x - 1, pos.y)
			if _has_room_connection(pos, adj_pos) and _rooms[adj_pos].explored:
				var a_pos := padding + Vector2(adj_pos) * cell_size
				var from := r_pos + cell_size / 2
				var to := a_pos + cell_size / 2
				ctrl.draw_line(from, to, Color(0.25, 0.25, 0.3), gap)

	# 画房间
	for pos in _rooms:
		var room: RoomData = _rooms[pos]
		var r_pos := padding + Vector2(pos) * cell_size

		if not room.explored:
			continue

		var color := Color(0.3, 0.3, 0.35)
		if room.is_boss:
			color = Color(0.6, 0.15, 0.15)
		elif room.state == RoomState.CLEARED:
			color = Color(0.1, 0.5, 0.3)
		elif room.state == RoomState.ACTIVE:
			color = Color(0.5, 0.4, 0.1)

		ctrl.draw_rect(Rect2(r_pos, cell_size), color)

		if pos == _current_room:
			ctrl.draw_rect(Rect2(r_pos - Vector2(1, 1), cell_size + Vector2(2, 2)), Color(1, 1, 0), false, 1.5)


func _get_door_dirs(pos: Vector2i) -> Array[String]:
	var dirs: Array[String] = []
	if pos in _rooms:
		if _has_room_connection(pos, Vector2i(pos.x, pos.y - 1)):
			dirs.append("n")
		if _has_room_connection(pos, Vector2i(pos.x, pos.y + 1)):
			dirs.append("s")
		if _has_room_connection(pos, Vector2i(pos.x + 1, pos.y)):
			dirs.append("e")
		if _has_room_connection(pos, Vector2i(pos.x - 1, pos.y)):
			dirs.append("w")
	return dirs


# ── 房间绘制 ────────────────────────────────────────────

func _get_door_collision_shape(door: StaticBody2D) -> CollisionShape2D:
	for child in door.get_children():
		if child is CollisionShape2D:
			return child as CollisionShape2D
	return null


func _draw_locked_doors() -> void:
	for room_pos in _doors:
		for key in _doors[room_pos]:
			var door: StaticBody2D = _doors[room_pos][key]
			if not is_instance_valid(door) or not door.visible:
				continue
			var collision_shape := _get_door_collision_shape(door)
			if collision_shape == null or not (collision_shape.shape is RectangleShape2D):
				continue
			var rect_shape: RectangleShape2D = collision_shape.shape
			var rect := Rect2(door.position - rect_shape.size / 2, rect_shape.size)
			draw_rect(rect, Color(0.9, 0.65, 0.12))
			draw_rect(rect.grow(-3.0), Color(0.35, 0.18, 0.05))


func _draw() -> void:
	for pos in _rooms:
		var room: RoomData = _rooms[pos]
		if not room.explored:
			continue

		var rx: float = pos.x * CELL_W + ROOM_PAD_X
		var ry: float = pos.y * CELL_H + ROOM_PAD_Y

		# 房间背景
		var bg_color := Color(0.13, 0.14, 0.16)
		if room.is_boss:
			bg_color = Color(0.18, 0.10, 0.10)
		elif room.is_start:
			bg_color = Color(0.10, 0.16, 0.13)
		draw_rect(Rect2(rx, ry, ROOM_W, ROOM_H), bg_color)

		# 走廊（南走廊）
		var south_pos := Vector2i(pos.x, pos.y + 1)
		var has_south := _has_room_connection(pos, south_pos)
		if has_south and _rooms[south_pos].explored:
			var corr_x: float = pos.x * CELL_W + CELL_W / 2 - CORRIDOR_W / 2
			var corr_y_top: float = ry + ROOM_H
			var corr_y_bot: float = (pos.y + 1) * CELL_H + ROOM_PAD_Y
			draw_rect(Rect2(corr_x, corr_y_top, CORRIDOR_W, corr_y_bot - corr_y_top), Color(0.12, 0.13, 0.15))

		# 走廊（东走廊）
		var east_pos := Vector2i(pos.x + 1, pos.y)
		var has_east := _has_room_connection(pos, east_pos)
		if has_east and _rooms[east_pos].explored:
			var corr_y: float = pos.y * CELL_H + CELL_H / 2 - CORRIDOR_W / 2
			var corr_x_left: float = rx + ROOM_W
			var corr_x_right: float = (pos.x + 1) * CELL_W + ROOM_PAD_X
			draw_rect(Rect2(corr_x_left, corr_y, corr_x_right - corr_x_left, CORRIDOR_W), Color(0.12, 0.13, 0.15))

		# 墙壁视觉
		var wall_color := Color(0.35, 0.35, 0.35)
		var has_north := _has_room_connection(pos, Vector2i(pos.x, pos.y - 1))
		var has_west := _has_room_connection(pos, Vector2i(pos.x - 1, pos.y))
		var gap_l: float = rx + ROOM_W / 2 - CORRIDOR_W / 2
		var gap_r: float = rx + ROOM_W / 2 + CORRIDOR_W / 2
		var gap_t: float = ry + ROOM_H / 2 - CORRIDOR_W / 2
		var gap_b: float = ry + ROOM_H / 2 + CORRIDOR_W / 2
		# 北墙
		if has_north:
			draw_rect(Rect2(rx, ry, gap_l - rx, WALL_T), wall_color)
			draw_rect(Rect2(gap_r, ry, rx + ROOM_W - gap_r, WALL_T), wall_color)
		else:
			draw_rect(Rect2(rx, ry, ROOM_W, WALL_T), wall_color)
		# 南墙
		if has_south:
			draw_rect(Rect2(rx, ry + ROOM_H - WALL_T, gap_l - rx, WALL_T), wall_color)
			draw_rect(Rect2(gap_r, ry + ROOM_H - WALL_T, rx + ROOM_W - gap_r, WALL_T), wall_color)
		else:
			draw_rect(Rect2(rx, ry + ROOM_H - WALL_T, ROOM_W, WALL_T), wall_color)
		# 西墙
		if has_west:
			draw_rect(Rect2(rx, ry, WALL_T, gap_t - ry), wall_color)
			draw_rect(Rect2(rx, gap_b, WALL_T, ry + ROOM_H - gap_b), wall_color)
		else:
			draw_rect(Rect2(rx, ry, WALL_T, ROOM_H), wall_color)
		# 东墙
		if has_east:
			draw_rect(Rect2(rx + ROOM_W - WALL_T, ry, WALL_T, gap_t - ry), wall_color)
			draw_rect(Rect2(rx + ROOM_W - WALL_T, gap_b, WALL_T, ry + ROOM_H - gap_b), wall_color)
		else:
			draw_rect(Rect2(rx + ROOM_W - WALL_T, ry, WALL_T, ROOM_H), wall_color)

		# Boss 标记
		if room.is_boss and room.state != RoomState.CLEARED:
			draw_string(ThemeDB.fallback_font, Vector2(rx + ROOM_W / 2 - 30, ry + 40), "BOSS", HORIZONTAL_ALIGNMENT_CENTER, -1, 20, Color(1.0, 0.0, 0.3))

	_draw_locked_doors()

	# 传送门
	if _portal_active:
		draw_circle(_portal_pos, 30.0, Color(0.0, 0.898, 1.0, 0.3))
		draw_arc(_portal_pos, 30.0, 0, TAU, 24, Color(0.0, 0.898, 1.0), 3.0)

	# 怪物出生预警
	if _spawn_warning_timer > 0.0:
		var alpha := clampf(_spawn_warning_timer / 1.0, 0.0, 1.0)
		var flash := sin(_spawn_warning_timer * 12.0) * 0.5 + 0.5
		for wpos in _spawn_warning_positions:
			var c := Color(1.0, 0.2, 0.2, 0.4 * alpha * flash)
			draw_circle(wpos, 14.0, c)
			draw_arc(wpos, 14.0, 0, TAU, 16, Color(1.0, 0.3, 0.3, 0.8 * alpha), 2.0)
