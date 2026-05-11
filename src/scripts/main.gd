extends Node2D

## 主场景控制器 - 走廊式房间制地牢 + HUD + 小地图

const VS := preload("res://scripts/visual_spec.gd")
const SHOCKWAVE_EFFECT := preload("res://scripts/shockwave_effect.gd")
const GUI_STATUS_BAR := preload("res://assets/export/gui/状态栏.png")
const GUI_SKILL_FRAME := preload("res://assets/export/gui/技能框.png")
const GUI_ATTACK_LOGO := preload("res://assets/export/gui/攻击logo.png")
const BASKETBALL_HEAD_NORMAL_1_PATH := "res://assets/export/weapon/weapon_01/2.png"
const BASKETBALL_HEAD_NORMAL_2_PATH := "res://assets/export/weapon/weapon_01/3.png"
const BASKETBALL_HEAD_BERSERK_PATH := "res://assets/export/weapon/weapon_01/dunk.png"
const BASKETBALL_HIT_EFFECT := preload("res://scripts/basketball_hit_effect.gd")
const BASKETBALL_BERSERK_HIT_EFFECT := preload("res://scripts/basketball_berserk_hit_effect.gd")
const MAN_NORMAL_HIT_EFFECT := preload("res://scripts/man_normal_hit_effect.gd")
const MAN_BERSERK_EXPLOSION_PATH := "res://assets/export/weapon/weapon_02/狂暴模式爆炸.png"
const EXPLOSION_EFFECT_SCRIPT := preload("res://scripts/explosion_effect.gd")
const ICE_FLOOR_TILES := [
	preload("res://assets/export/map/冰封篮球场/地砖_01.png"),
	preload("res://assets/export/map/冰封篮球场/地砖_02.png"),
	preload("res://assets/export/map/冰封篮球场/地砖_03.png"),
	preload("res://assets/export/map/冰封篮球场/地砖_04.png"),
	preload("res://assets/export/map/冰封篮球场/地砖_05.png")
]
const ICE_WALL_TILES := [
	preload("res://assets/export/map/冰封篮球场/墙壁_01.png"),
	preload("res://assets/export/map/冰封篮球场/墙壁_02.png")
]
const STATUS_SCALE := 1.73
const STATUS_POS := Vector2(24.0, 20.0)
const STATUS_FILL_W := 59.0 * STATUS_SCALE
const STATUS_FILL_H := 5.5 * STATUS_SCALE
const ACTION_FRAME_SIZE := Vector2(50.67, 50.67)
const ACTION_CONTROL_SIZE := Vector2(50.67, 78.0)
const ACTION_ROW_Y := 530.0
const ACTION_Q_X := 646.0
const ACTION_J_X := 716.0
const ACTION_K_X := 786.0
const ACTION_L_X := 856.0
const ACTION_KEY_Y := 55.0
const ACTION_KEY_COLOR := Color(0.78, 0.88, 0.94)
const BLUE_SHOCKWAVE_SHEET := "res://assets/export/effects/shockwave_blue_sheet.png"
const YELLOW_SHOCKWAVE_SHEET := "res://assets/export/effects/shockwave_yellow_sheet.png"
const DUNGEON_PORTAL_INTERACT_RADIUS := 58.0

enum RoomState { INACTIVE, ACTIVE, CLEARED }

# 网格单元格大小（一个格子 = 房间 + 走廊空间）
const CELL_W := int(VS.CELL_SIZE.x)
const CELL_H := int(VS.CELL_SIZE.y)
# 房间实际大小（小于单元格，留出走廊空间）
const ROOM_W := int(VS.ROOM_SIZE.x)
const ROOM_H := int(VS.ROOM_SIZE.y)
# 房间在单元格内的偏移（居中）
const ROOM_PAD_X := int(VS.ROOM_PADDING.x)
const ROOM_PAD_Y := int(VS.ROOM_PADDING.y)
# 走廊宽度
const CORRIDOR_W := int(VS.CORRIDOR_WIDTH)
# 墙壁厚度
const WALL_T := int(VS.WALL_THICKNESS)
const DOOR_COLLISION_LAYER := 16
const MAP_TILE_SIZE := 32.0

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
var _current_floor := 1
var _rooms_cleared := 0
var _total_rooms := 0
var _boss_pos: Vector2i = CENTER
var _boss_entry_pos: Vector2i = CENTER
var _portal_active := false
var _portal_pos := Vector2.ZERO
var _start_portal_pos := Vector2.ZERO
var _start_portal_sprite: TransferPortal
var _boss_portal_sprite: TransferPortal
var _return_portal_near := false
var _doors: Dictionary = {}
var _wall_bodies: Array[StaticBody2D] = []
var _spawn_warning_positions: Array[Vector2] = []
var _spawn_warning_timer := 0.0
var _spawn_warning_room: Vector2i = CENTER

# 摄像机 + 打击反馈
var _cam_mgr: CameraManager
var _hit_stop_until := 0
var _damage_numbers: Array[Dictionary] = []
const MAX_DAMAGE_NUMBERS := 20
var _basketball_texture_cache: Dictionary = {}

# Boss 血条
var _boss_hp_bar_bg: ColorRect
var _boss_hp_bar: ColorRect
var _boss_hp_label: Label
var _boss_ref: Area2D

# 复活系统
var _revive_canvas: CanvasLayer
var _revive_countdown_label: Label
var _revive_timer := 0.0
var _pause_canvas: CanvasLayer

# HUD
var _fps_label: Label
var _kills_label: Label
var _weapon_label: Label
var _hp_bar: ColorRect
var _hp_bar_bg: ColorRect
var _hp_text: Label
var _shield_bar: ColorRect
var _shield_bar_bg: ColorRect
var _shield_text: Label
var _mana_bar: ColorRect
var _mana_bar_bg: ColorRect
var _mana_text: Label
var _dash_icon: Control
var _berserk_icon: Control
var _attack_icon: Control
var _switch_icon: Control
var _minimap: Control
var _buff_bar: Control
var _practice_label: Label
var _practice_panel: Control
var _coin_label: Label
var _hud_frame: Control
var _coin_panel: Control
var _pause_button: Control
var _bag_button: Control
var _invincible_test_button: Button
var _equipment_panel: Node = null

# 提示消息系统
var _active_hints: Array[CanvasLayer] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameManager.change_state(GameManager.GameState.PLAYING)
	$Player.hp_changed.connect(_on_player_hp_changed)
	$Player.player_died.connect(_on_player_died)
	$Player.player_hit.connect(_on_player_hit)

	_generate_floor()
	_create_dungeon()
	_create_hud()
	_create_minimap()

	# 摄像机系统
	_cam_mgr = CameraManager.new()
	_cam_mgr.setup($Player/Camera2D, VS.CAMERA_MAIN_BASE_OFFSET)

	# 打击反馈信号
	$BulletPool.hit_occurred.connect(_on_bullet_hit_feedback)

	var start_center := Vector2(CENTER.x * CELL_W + CELL_W / 2, CENTER.y * CELL_H + CELL_H / 2)
	$Player.position = start_center
	_create_start_portal(start_center)

	_current_room = CENTER
	var room: RoomData = _rooms[CENTER]
	room.explored = true
	_mark_adjacent_explored(CENTER)

	# 初始摄像机边界
	_update_camera_bounds(CENTER)
	_play_player_spawn_warning($Player)


func _create_transfer_portal(pos: Vector2, display_size: float, node_name: String) -> TransferPortal:
	var portal: TransferPortal = TransferPortal.new()
	portal.name = node_name
	portal.position = pos
	portal.z_index = 5
	portal.setup(display_size)
	add_child(portal)
	return portal


func _create_start_portal(start_center: Vector2) -> void:
	_start_portal_pos = start_center + Vector2(0, -92)
	_start_portal_sprite = _create_transfer_portal(_start_portal_pos, VS.PORTAL_DUNGEON_DISPLAY_SIZE * 2.5, "StartReturnPortal")


func _show_boss_return_portal(pos: Vector2) -> void:
	_portal_pos = pos
	_portal_active = true
	if _boss_portal_sprite != null and is_instance_valid(_boss_portal_sprite):
		_boss_portal_sprite.queue_free()
	_boss_portal_sprite = _create_transfer_portal(_portal_pos, VS.PORTAL_DUNGEON_DISPLAY_SIZE * 2.5, "BossReturnPortal")


# ── 地牢生成 ──────────────────────────────────────────

func _generate_floor() -> void:
	_rooms.clear()
	_doors.clear()
	_boss_defeated = false
	_portal_active = false
	_return_portal_near = false
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

	_rooms_cleared = 0
	_total_rooms = _rooms.size()


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
	# 0) 清除上一个房间残留的子弹
	$BulletPool.clear_all()

	# 起始房间：不刷怪，直接放武器选择宝箱
	if room.is_start:
		room.state = RoomState.CLEARED
		_rooms_cleared += 1
		_spawn_weapon_chest(pos)
		queue_redraw()
		if _minimap:
			_minimap.queue_redraw()
		return

	room.state = RoomState.ACTIVE
	# 1) 关门
	_close_doors(pos)
	# 2) 放置障碍物和陷阱
	_spawn_room_objects(pos)
	# 3) 预警 + 出怪
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

func _update_camera_bounds(pos: Vector2i) -> void:
	var rx: float = pos.x * CELL_W + ROOM_PAD_X
	var ry: float = pos.y * CELL_H + ROOM_PAD_Y
	_cam_mgr.set_room_bounds(Rect2(rx, ry, ROOM_W, ROOM_H))


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
		var bonus := _get_floor_enemy_bonus()
		for i in bonus:
			var offset := Vector2(randf_range(-200, 200), randf_range(-120, 120))
			var p := center + offset
			if p.distance_to(center) < 80:
				p = center + offset.normalized() * 120
			_spawn_warning_positions.append(p)

	_spawn_warning_timer = 1.0
	for warning_pos in _spawn_warning_positions:
		_play_spawn_warning_effect(warning_pos)
	queue_redraw()


func _play_spawn_warning_effect(pos: Vector2) -> void:
	var effect = SHOCKWAVE_EFFECT.new()
	effect.global_position = pos
	add_child(effect)
	effect.setup(YELLOW_SHOCKWAVE_SHEET, Color(1.0, 0.78, 0.1, 0.9), 120.0)


func _play_player_spawn_warning(player: CharacterBody2D) -> void:
	player.visible = false
	player.set_physics_process(false)
	player.set_process_input(false)
	var effect = SHOCKWAVE_EFFECT.new()
	effect.global_position = player.global_position
	add_child(effect)
	effect.setup(BLUE_SHOCKWAVE_SHEET, Color(0.25, 0.65, 1.0, 0.9), 150.0, Callable(self, "_finish_player_spawn_warning").bind(player))


func _finish_player_spawn_warning(player: CharacterBody2D) -> void:
	if player == null or not is_instance_valid(player):
		return
	player.visible = true
	player.set_physics_process(true)
	player.set_process_input(true)


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
			_spawn_enemy(pos, room, bounds, _random_enemy_type())


func _spawn_enemy(pos: Vector2, room: RoomData, bounds: Rect2, type: int = 0) -> void:
	var enemy_scene: PackedScene = preload("res://scenes/Enemy.tscn")
	var enemy: Area2D = enemy_scene.instantiate()
	enemy.global_position = pos
	enemy.setup($Player, type, $BulletPool)
	# 楼层血量倍率
	var hp_mult := _get_floor_hp_multiplier()
	enemy.max_hp = int(enemy.max_hp * hp_mult)
	enemy.hp = int(enemy.hp * hp_mult)
	enemy.room_bounds = bounds
	add_child(enemy)
	room.enemies.append(enemy)
	enemy.died.connect(_on_enemy_died.bind(enemy, room))


func _random_enemy_type() -> int:
	var roll := randf()
	if roll < 0.50:
		return 0  # CHASER
	elif roll < 0.78:
		return 1  # SHOOTER
	else:
		return 2  # TANK


func _spawn_boss(pos: Vector2, room: RoomData, bounds: Rect2) -> void:
	var boss_scene: PackedScene = preload("res://scenes/Boss.tscn")
	var boss: Area2D = boss_scene.instantiate()
	boss.global_position = pos
	boss.setup($Player, $BulletPool, room)
	# 楼层血量倍率
	var hp_mult := _get_floor_hp_multiplier()
	boss.max_hp = int(boss.max_hp * hp_mult)
	boss.hp = int(boss.hp * hp_mult)
	boss.room_bounds = bounds
	add_child(boss)
	room.enemies.append(boss)
	boss.tree_exiting.connect(_on_boss_died.bind(room))
	# 显示 Boss 血条
	_show_boss_hp(boss)


func _on_enemy_died(_enemy: Area2D, room: RoomData) -> void:
	room.enemies = room.enemies.filter(func(e): return is_instance_valid(e) and not e._dying)
	if room.enemies.is_empty():
		_room_cleared(room)


func _on_boss_died(room: RoomData) -> void:
	_boss_defeated = true
	room.enemies = room.enemies.filter(func(e): return is_instance_valid(e) and not e._dying)
	if room.enemies.is_empty():
		_room_cleared(room)
	# 在 boss 房间生成传送门
	_show_boss_return_portal(Vector2(_boss_pos.x * CELL_W + CELL_W / 2, _boss_pos.y * CELL_H + CELL_H / 2))
	queue_redraw()
	_show_hint("Boss 已击败！按 E 返回基地", Color(0.0, 0.898, 1.0))


func _room_cleared(room: RoomData) -> void:
	room.state = RoomState.CLEARED
	_rooms_cleared += 1
	_show_hint("房间已清理！", Color(0.0, 1.0, 0.53))
	# 延迟 0.5 秒后开门
	await get_tree().create_timer(0.5).timeout
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


func _spawn_chest(pos: Vector2) -> void:
	var chest_scene: PackedScene = preload("res://scenes/Chest.tscn")
	var chest: Area2D = chest_scene.instantiate()
	chest.position = pos
	add_child(chest)


func _spawn_weapon_chest(room_pos: Vector2i) -> void:
	var chest_scene: PackedScene = preload("res://scenes/Chest.tscn")
	var chest: Area2D = chest_scene.instantiate()
	var cx: float = room_pos.x * CELL_W + CELL_W / 2.0
	var cy: float = room_pos.y * CELL_H + CELL_H / 2.0
	chest.position = Vector2(cx, cy)
	chest.is_weapon_choice = true
	add_child(chest)


# ── 房间物件生成 ──────────────────────────────────────────

var _room_objects: Dictionary = {}  # {Vector2i: Array[Node]}

func _spawn_room_objects(grid_pos: Vector2i) -> void:
	# 起始房间和 Boss 房不放物件
	var room: RoomData = _rooms[grid_pos]
	if room.is_start or room.is_boss:
		return

	var occupied: Array[Vector2] = []
	var rx: float = grid_pos.x * CELL_W + ROOM_PAD_X + WALL_T + 20
	var ry: float = grid_pos.y * CELL_H + ROOM_PAD_Y + WALL_T + 20
	var rw: float = ROOM_W - WALL_T * 2 - 40
	var rh: float = ROOM_H - WALL_T * 2 - 40
	var center := Vector2(grid_pos.x * CELL_W + CELL_W / 2.0, grid_pos.y * CELL_H + CELL_H / 2.0)

	var objects: Array[Node] = []

	# 木箱 2-5 个（可破坏掩体，30% 掉宝箱）
	var crate_count := 2 + randi() % 4
	for i in crate_count:
		var pos := _random_room_pos(rx, ry, rw, rh, center, 80.0, occupied, 40.0)
		if pos == Vector2.ZERO:
			continue
		var crate: StaticBody2D = load("res://scripts/obstacle.gd").new()
		crate.position = pos
		crate.setup(self)
		add_child(crate)
		objects.append(crate)
		occupied.append(pos)

	_room_objects[grid_pos] = objects


func _random_room_pos(rx: float, ry: float, rw: float, rh: float,
		center: Vector2, avoid_radius: float,
		occupied: Array[Vector2], min_dist: float) -> Vector2:
	for _attempt in 20:
		var pos := Vector2(
			randf_range(rx, rx + rw),
			randf_range(ry, ry + rh)
		)
		# 避开房间中心
		if pos.distance_to(center) < avoid_radius:
			continue
		# 避开门口区域（墙的缺口）
		var door_center_x := rx + rw / 2.0
		var door_center_y := ry + rh / 2.0
		if absf(pos.x - door_center_x) < 50 and pos.y < ry + 30:
			continue
		if absf(pos.x - door_center_x) < 50 and pos.y > ry + rh - 30:
			continue
		if absf(pos.y - door_center_y) < 50 and pos.x < rx + 30:
			continue
		if absf(pos.y - door_center_y) < 50 and pos.x > rx + rw - 30:
			continue
		# 避开已有物体
		var too_close := false
		for op in occupied:
			if pos.distance_to(op) < min_dist:
				too_close = true
				break
		if too_close:
			continue
		return pos
	return Vector2.ZERO


func _next_floor() -> void:
	# 清除所有子弹
	$BulletPool.clear_all()
	# 清除残留敌人
	for pos_key in _rooms:
		var rdata: RoomData = _rooms[pos_key]
		for e in rdata.enemies:
			if is_instance_valid(e):
				e.queue_free()
	# 清除墙壁
	for wb in _wall_bodies:
		if is_instance_valid(wb):
			wb.queue_free()
	_wall_bodies.clear()
	# 清除门
	for pos_key in _doors:
		for key in _doors[pos_key]:
			var door: StaticBody2D = _doors[pos_key][key]
			if is_instance_valid(door):
				door.queue_free()
	_doors.clear()
	# 清除房间物件
	for pos_key in _room_objects:
		for obj in _room_objects[pos_key]:
			if is_instance_valid(obj):
				obj.queue_free()
	_room_objects.clear()
	# 隐藏 Boss 血条
	if _boss_hp_bar_bg != null and is_instance_valid(_boss_hp_bar_bg):
		_boss_hp_bar_bg.queue_free()
		_boss_hp_bar_bg = null
	if _boss_hp_bar != null and is_instance_valid(_boss_hp_bar):
		_boss_hp_bar.queue_free()
		_boss_hp_bar = null
	if _boss_hp_label != null and is_instance_valid(_boss_hp_label):
		_boss_hp_label.queue_free()
		_boss_hp_label = null
	_boss_ref = null

	# 下一层
	_current_floor += 1
	_game_over = false
	_generate_floor()
	_create_dungeon()

	# 玩家回到起始房间
	var start_center := Vector2(CENTER.x * CELL_W + CELL_W / 2, CENTER.y * CELL_H + CELL_H / 2)
	$Player.position = start_center
	_current_room = CENTER
	var room: RoomData = _rooms[CENTER]
	room.explored = true
	_mark_adjacent_explored(CENTER)
	_update_camera_bounds(CENTER)

	# 恢复部分生命
	var heal := int($Player.MAX_HP * 0.3)
	$Player.hp = mini($Player.hp + heal, $Player.MAX_HP)
	$Player.hp_changed.emit($Player.hp, $Player.MAX_HP)

	_show_hint("第 %d 层" % _current_floor, Color(1.0, 0.84, 0.0))
	queue_redraw()
	if _minimap:
		_minimap.queue_redraw()


func _get_floor_enemy_bonus() -> int:
	## 根据当前楼层返回额外敌人数量
	return int((_current_floor - 1) * 0.5)


func _get_floor_hp_multiplier() -> float:
	## 根据当前楼层返回敌人血量倍率
	return 1.0 + (_current_floor - 1) * 0.2


func _show_hint(text: String, color: Color = Color.WHITE) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(200, 30)

	var canvas := CanvasLayer.new()
	canvas.layer = 30
	canvas.add_child(label)
	add_child(canvas)

	_active_hints.append(canvas)
	_reposition_hints()

	# 淡出后移除
	await get_tree().create_timer(1.8).timeout
	if not is_instance_valid(canvas):
		return
	var tween := create_tween()
	tween.tween_property(label, "modulate:a", 0.0, 0.3)
	await tween.finished
	_active_hints.erase(canvas)
	if is_instance_valid(canvas):
		canvas.queue_free()
	_reposition_hints()


func _reposition_hints() -> void:
	var base_y := 55
	for i in _active_hints.size():
		var canvas: CanvasLayer = _active_hints[i]
		if not is_instance_valid(canvas):
			continue
		for child in canvas.get_children():
			if child is Label:
				var target_y := base_y + i * 32
				child.position = Vector2(380, target_y)


# ── 物理更新 ──────────────────────────────────────────

func _physics_process(_delta: float) -> void:
	if GameManager.state != GameManager.GameState.PLAYING:
		return

	var player_pos: Vector2 = $Player.global_position

	# 判断玩家当前所在格子
	var gx := int(floor(player_pos.x / CELL_W))
	var gy := int(floor(player_pos.y / CELL_H))
	var grid_pos := Vector2i(gx, gy)

	# 切换房间：更新探索状态 + 摄像机边界
	if grid_pos != _current_room and grid_pos in _rooms:
		_current_room = grid_pos
		var room: RoomData = _rooms[grid_pos]
		if not room.explored:
			room.explored = true
			queue_redraw()
		_mark_adjacent_explored(grid_pos)
		_update_camera_bounds(grid_pos)

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
	canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(canvas)

	_fps_label = Label.new()
	_fps_label.visible = false
	canvas.add_child(_fps_label)

	_kills_label = Label.new()
	_kills_label.visible = false
	canvas.add_child(_kills_label)

	_hud_frame = Control.new()
	_hud_frame.position = STATUS_POS
	_hud_frame.size = Vector2(79, 39) * STATUS_SCALE
	_hud_frame.z_index = 2
	_hud_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_frame.draw.connect(_draw_stats_frame)
	canvas.add_child(_hud_frame)

	_hp_bar_bg = ColorRect.new()
	_hp_bar_bg.position = STATUS_POS + Vector2(15, 4) * STATUS_SCALE
	_hp_bar_bg.size = Vector2(STATUS_FILL_W, STATUS_FILL_H)
	_hp_bar_bg.z_index = 0
	_hp_bar_bg.color = Color(0.08, 0.04, 0.03, 0.55)
	canvas.add_child(_hp_bar_bg)

	_hp_bar = ColorRect.new()
	_hp_bar.position = _hp_bar_bg.position
	_hp_bar.size = _hp_bar_bg.size
	_hp_bar.z_index = 0
	_hp_bar.color = Color(0.88, 0.07, 0.15)
	canvas.add_child(_hp_bar)

	_hp_text = _make_hud_value_label(STATUS_POS + Vector2(60, 3), Color.WHITE)
	_hp_text.z_index = 1
	canvas.add_child(_hp_text)

	_shield_bar_bg = ColorRect.new()
	_shield_bar_bg.position = STATUS_POS + Vector2(15, 16) * STATUS_SCALE
	_shield_bar_bg.size = Vector2(STATUS_FILL_W, STATUS_FILL_H)
	_shield_bar_bg.z_index = 0
	_shield_bar_bg.color = Color(0.06, 0.07, 0.08, 0.55)
	canvas.add_child(_shield_bar_bg)

	_shield_bar = ColorRect.new()
	_shield_bar.position = _shield_bar_bg.position
	_shield_bar.size = _shield_bar_bg.size
	_shield_bar.z_index = 0
	_shield_bar.color = Color(0.78, 0.85, 0.9)
	canvas.add_child(_shield_bar)

	_shield_text = _make_hud_value_label(STATUS_POS + Vector2(60, 34), Color.WHITE)
	_shield_text.z_index = 1
	canvas.add_child(_shield_text)

	_mana_bar_bg = ColorRect.new()
	_mana_bar_bg.position = STATUS_POS + Vector2(15, 28) * STATUS_SCALE
	_mana_bar_bg.size = Vector2(STATUS_FILL_W, STATUS_FILL_H)
	_mana_bar_bg.z_index = 0
	_mana_bar_bg.color = Color(0.04, 0.05, 0.12, 0.55)
	canvas.add_child(_mana_bar_bg)

	_mana_bar = ColorRect.new()
	_mana_bar.position = _mana_bar_bg.position
	_mana_bar.size = _mana_bar_bg.size
	_mana_bar.z_index = 0
	_mana_bar.color = Color(0.22, 0.33, 0.9)
	canvas.add_child(_mana_bar)

	_mana_text = _make_hud_value_label(STATUS_POS + Vector2(60, 65), Color.WHITE)
	_mana_text.z_index = 1
	canvas.add_child(_mana_text)

	_weapon_label = Label.new()
	_weapon_label.visible = false
	canvas.add_child(_weapon_label)

	_practice_panel = Control.new()
	_practice_panel.position = Vector2(656, 16)
	_practice_panel.size = Vector2(144, 36)
	_practice_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_practice_panel.draw.connect(_draw_practice_panel)
	canvas.add_child(_practice_panel)

	_practice_label = Label.new()
	_practice_label.position = Vector2(694, 18)
	_practice_label.size = Vector2(96, 22)
	_practice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_practice_label.add_theme_font_size_override("font_size", 18)
	_practice_label.add_theme_color_override("font_color", Color.WHITE)
	canvas.add_child(_practice_label)

	_coin_panel = Control.new()
	_coin_panel.position = Vector2(814, 16)
	_coin_panel.size = Vector2(96, 36)
	_coin_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_coin_panel.draw.connect(_draw_coin_panel)
	canvas.add_child(_coin_panel)

	_coin_label = Label.new()
	_coin_label.position = Vector2(846, 18)
	_coin_label.size = Vector2(56, 22)
	_coin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_coin_label.add_theme_font_size_override("font_size", 18)
	_coin_label.add_theme_color_override("font_color", Color.WHITE)
	canvas.add_child(_coin_label)

	_pause_button = Control.new()
	_pause_button.position = Vector2(924, 14)
	_pause_button.size = Vector2(28, 36)
	_pause_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause_button.draw.connect(_draw_pause_button)
	_pause_button.gui_input.connect(_on_pause_button_input)
	canvas.add_child(_pause_button)

	_bag_button = Control.new()
	_bag_button.position = Vector2(622, 14)
	_bag_button.size = Vector2(28, 36)
	_bag_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_bag_button.draw.connect(_draw_bag_button)
	_bag_button.gui_input.connect(_on_bag_button_input)
	canvas.add_child(_bag_button)

	_invincible_test_button = Button.new()
	_invincible_test_button.text = "无敌测试"
	_invincible_test_button.position = Vector2(410, 16)
	_invincible_test_button.size = Vector2(88, 30)
	_invincible_test_button.focus_mode = Control.FOCUS_NONE
	_invincible_test_button.add_theme_font_size_override("font_size", 15)
	_invincible_test_button.pressed.connect(_on_invincible_test_pressed)
	canvas.add_child(_invincible_test_button)

	var boss_test_button := Button.new()
	boss_test_button.text = "Boss测试"
	boss_test_button.position = Vector2(514, 16)
	boss_test_button.size = Vector2(88, 30)
	boss_test_button.focus_mode = Control.FOCUS_NONE
	boss_test_button.add_theme_font_size_override("font_size", 15)
	boss_test_button.pressed.connect(_on_boss_test_pressed)
	canvas.add_child(boss_test_button)

	_attack_icon = Control.new()
	_attack_icon.position = Vector2(ACTION_J_X, ACTION_ROW_Y)
	_attack_icon.size = ACTION_CONTROL_SIZE
	_attack_icon.mouse_filter = Control.MOUSE_FILTER_STOP
	_attack_icon.draw.connect(_draw_attack_icon)
	_attack_icon.gui_input.connect(_on_action_button_input.bind("shoot"))
	canvas.add_child(_attack_icon)

	_switch_icon = Control.new()
	_switch_icon.position = Vector2(ACTION_Q_X, ACTION_ROW_Y)
	_switch_icon.size = ACTION_CONTROL_SIZE
	_switch_icon.mouse_filter = Control.MOUSE_FILTER_STOP
	_switch_icon.draw.connect(_draw_switch_icon)
	_switch_icon.gui_input.connect(_on_action_button_input.bind("switch_weapon"))
	canvas.add_child(_switch_icon)

	_dash_icon = Control.new()
	_dash_icon.position = Vector2(ACTION_K_X, ACTION_ROW_Y)
	_dash_icon.size = ACTION_CONTROL_SIZE
	_dash_icon.mouse_filter = Control.MOUSE_FILTER_STOP
	_dash_icon.draw.connect(_draw_dash_icon)
	_dash_icon.gui_input.connect(_on_action_button_input.bind("dash"))
	canvas.add_child(_dash_icon)

	_berserk_icon = Control.new()
	_berserk_icon.position = Vector2(ACTION_L_X, ACTION_ROW_Y)
	_berserk_icon.size = ACTION_CONTROL_SIZE
	_berserk_icon.mouse_filter = Control.MOUSE_FILTER_STOP
	_berserk_icon.draw.connect(_draw_berserk_icon)
	_berserk_icon.gui_input.connect(_on_action_button_input.bind("berserk"))
	canvas.add_child(_berserk_icon)

	# Buff 状态栏
	_buff_bar = Control.new()
	_buff_bar.position = Vector2(182, 22)
	_buff_bar.size = Vector2(130, 28)
	_buff_bar.draw.connect(_draw_buff_bar)
	canvas.add_child(_buff_bar)


func _make_hud_value_label(pos: Vector2, color: Color) -> Label:
	var label := Label.new()
	label.position = pos
	label.size = Vector2(96, 16)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	return label


func _draw_stats_frame() -> void:
	_hud_frame.draw_texture_rect(GUI_STATUS_BAR, Rect2(Vector2.ZERO, _hud_frame.size), false)


func _draw_practice_panel() -> void:
	var r := Rect2(Vector2.ZERO, _practice_panel.size)
	_practice_panel.draw_rect(r, Color(0.22, 0.22, 0.24))
	_practice_panel.draw_rect(r.grow(-3), Color(0.34, 0.34, 0.36))
	_practice_panel.draw_circle(Vector2(20, 18), 8.0, Color(1.0, 0.86, 0.12))
	_practice_panel.draw_arc(Vector2(20, 18), 8.0, 0, TAU, 18, Color(0.25, 0.12, 0.02), 2.0)


func _draw_coin_panel() -> void:
	var r := Rect2(Vector2.ZERO, _coin_panel.size)
	_coin_panel.draw_rect(r, Color(0.22, 0.22, 0.24))
	_coin_panel.draw_rect(r.grow(-3), Color(0.34, 0.34, 0.36))
	_coin_panel.draw_circle(Vector2(18, 18), 8.0, Color(1.0, 0.86, 0.12))
	_coin_panel.draw_arc(Vector2(18, 18), 8.0, 0, TAU, 18, Color(0.25, 0.12, 0.02), 2.0)


func _draw_pause_button() -> void:
	var r := Rect2(Vector2.ZERO, _pause_button.size)
	_pause_button.draw_rect(r, Color(0.36, 0.28, 0.18))
	_pause_button.draw_rect(r.grow(-3), Color(0.64, 0.49, 0.29))
	_pause_button.draw_rect(r.grow(-8), Color(0.73, 0.58, 0.36))
	_pause_button.draw_rect(Rect2(7, 8, 5, 20), Color(0.38, 0.28, 0.16))
	_pause_button.draw_rect(Rect2(16, 8, 5, 20), Color(0.38, 0.28, 0.16))


func _draw_bag_button() -> void:
	var r := Rect2(Vector2.ZERO, _bag_button.size)
	_bag_button.draw_rect(r, Color(0.30, 0.24, 0.16))
	_bag_button.draw_rect(r.grow(-3), Color(0.59, 0.46, 0.28))
	_bag_button.draw_rect(Rect2(7, 10, 14, 14), Color(0.79, 0.66, 0.42))
	_bag_button.draw_rect(Rect2(9, 7, 10, 5), Color(0.79, 0.66, 0.42))
	_bag_button.draw_arc(Vector2(14, 11), 4.0, PI, TAU, 10, Color(0.35, 0.22, 0.10), 1.5)
	_draw_button_key(_bag_button, "B", Color(0.98, 0.90, 0.62))


func _draw_button_key(ctrl: Control, key: String, color: Color = Color.WHITE) -> void:
	var font := ThemeDB.fallback_font
	var font_size := 16
	var text_size := font.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var pos := (ctrl.size - text_size) / 2.0
	ctrl.draw_string(font, pos + Vector2(0, text_size.y), key, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _draw_action_key(ctrl: Control, key: String, color: Color = Color.WHITE) -> void:
	var font: Font = ThemeDB.fallback_font
	var font_size: int = 14
	var text_size: Vector2 = font.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var x: float = (ACTION_FRAME_SIZE.x - text_size.x) * 0.5
	var pos: Vector2 = Vector2(x, ACTION_KEY_Y + text_size.y)
	ctrl.draw_string(font, pos + Vector2(1, 1), key, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0, 0, 0, 0.8))
	ctrl.draw_string(font, pos, key, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _draw_attack_icon() -> void:
	var player := $Player
	_attack_icon.draw_texture_rect(GUI_SKILL_FRAME, Rect2(Vector2.ZERO, ACTION_FRAME_SIZE), false)
	var logo_size: Vector2 = Vector2(28, 28)
	var logo_rect: Rect2 = Rect2((ACTION_FRAME_SIZE - logo_size) * 0.5, logo_size)
	_attack_icon.draw_texture_rect(GUI_ATTACK_LOGO, logo_rect, false)
	var prompt_active: bool = bool(player.call("should_show_attack_tap_prompt")) and bool(player.call("is_berserk_active"))
	if prompt_active:
		_draw_basketball_tap_prompt(_attack_icon, float(player.call("get_attack_tap_prompt_flash_ratio")))
	_draw_action_key(_attack_icon, "J", Color(1.0, 0.94, 0.62) if prompt_active else ACTION_KEY_COLOR)


func _draw_switch_icon() -> void:
	_switch_icon.draw_texture_rect(GUI_SKILL_FRAME, Rect2(Vector2.ZERO, ACTION_FRAME_SIZE), false)
	_draw_action_key(_switch_icon, "Q", ACTION_KEY_COLOR)


func _draw_dash_icon() -> void:
	var center: Vector2 = ACTION_FRAME_SIZE / 2.0
	_dash_icon.draw_texture_rect(GUI_SKILL_FRAME, Rect2(Vector2.ZERO, ACTION_FRAME_SIZE), false)
	var dash_cd: float = $Player._dash_cooldown
	if dash_cd > 0.0:
		var cd_ratio: float = clampf(dash_cd / $Player.DASH_COOLDOWN, 0.0, 1.0)
		var radius: float = ACTION_FRAME_SIZE.x * 0.36
		var points := PackedVector2Array()
		points.append(center)
		var segments := 24
		var sweep: float = TAU * cd_ratio
		for i in segments + 1:
			var angle: float = -PI / 2 + sweep * i / segments
			points.append(center + Vector2(cos(angle), sin(angle)) * radius)
		if points.size() >= 3:
			_dash_icon.draw_colored_polygon(points, Color(0, 0, 0, 0.55))
	_draw_action_key(_dash_icon, "K", ACTION_KEY_COLOR)


func _draw_berserk_icon() -> void:
	_berserk_icon.draw_texture_rect(GUI_SKILL_FRAME, Rect2(Vector2.ZERO, ACTION_FRAME_SIZE), false)
	_draw_action_key(_berserk_icon, "L", ACTION_KEY_COLOR)


func _draw_basketball_tap_prompt(ctrl: Control, flash_ratio: float) -> void:
	var center := ACTION_FRAME_SIZE * 0.5
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.014)
	var alpha := 0.18 + 0.28 * pulse + 0.28 * flash_ratio
	var radius := 18.0 + 3.0 * pulse + 6.0 * flash_ratio
	ctrl.draw_arc(center, radius, 0.0, TAU, 32, Color(1.0, 0.34, 0.08, alpha), 2.8)
	ctrl.draw_arc(center, radius - 4.0, 0.0, TAU, 28, Color(1.0, 0.86, 0.22, alpha * 0.7), 1.4)
	ctrl.draw_circle(center + Vector2(0.0, -4.0), 9.0 + 3.0 * flash_ratio, Color(1.0, 0.38, 0.1, 0.16 + 0.12 * pulse))
	ctrl.draw_line(center + Vector2(16.0, -7.0), center + Vector2(22.0, -12.0), Color(1.0, 0.82, 0.38, alpha), 2.0)
	ctrl.draw_line(center + Vector2(22.0, -12.0), center + Vector2(19.0, -12.0), Color(1.0, 0.82, 0.38, alpha), 2.0)
	ctrl.draw_line(center + Vector2(22.0, -12.0), center + Vector2(22.0, -9.0), Color(1.0, 0.82, 0.38, alpha), 2.0)


func _draw_buff_bar() -> void:
	var buffs: Dictionary = $Player.get_active_buffs()
	var x := 0
	for type in buffs:
		var info: Dictionary = $Player.BUFF_INFO[type]
		var stacks: int = buffs[type].stacks
		var time_left: float = buffs[type].time
		var color: Color = info.color
		var icon: String = info.icon
		var panel_w := 28
		var center := Vector2(x + 14, 14)
		_buff_bar.draw_circle(center, 13.0, Color(0.2, 0.13, 0.08, 0.75))
		_buff_bar.draw_arc(center, 13.0, 0, TAU, 18, color.darkened(0.25), 2.0)
		_buff_bar.draw_string(ThemeDB.fallback_font, Vector2(x + 8, 19), icon, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, color)
		# 层数
		if stacks > 1:
			_buff_bar.draw_string(ThemeDB.fallback_font, Vector2(x + 16, 26), "%d" % stacks, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color.WHITE)
		# 时间条
		var time_ratio := clampf(time_left / 30.0, 0.0, 1.0)
		_buff_bar.draw_rect(Rect2(x + 3, 25, 22 * time_ratio, 2), color)
		x += panel_w + 5


func _on_action_button_input(event: InputEvent, action: String) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_emit_virtual_action(action, event.pressed)
	elif event is InputEventScreenTouch:
		_emit_virtual_action(action, event.pressed)


func _emit_virtual_action(action: String, pressed: bool) -> void:
	var input_event := InputEventAction.new()
	input_event.action = action
	input_event.pressed = pressed
	Input.parse_input_event(input_event)


func _on_pause_button_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_toggle_pause_from_hud()
	elif event is InputEventScreenTouch and event.pressed:
		_toggle_pause_from_hud()


func _on_bag_button_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_open_equipment_panel()
	elif event is InputEventScreenTouch and event.pressed:
		_open_equipment_panel()


func _on_invincible_test_pressed() -> void:
	var enabled := not bool($Player.call("is_test_invincible"))
	$Player.call("set_test_invincible", enabled)
	if _invincible_test_button != null:
		_invincible_test_button.text = "无敌ON" if enabled else "无敌测试"
	_show_hint("测试无敌：开启" if enabled else "测试无敌：关闭", Color(0.45, 0.9, 1.0))


func _on_boss_test_pressed() -> void:
	if GameManager.state == GameManager.GameState.PAUSED:
		_hide_pause_menu()
		GameManager.change_state(GameManager.GameState.PLAYING)
	if GameManager.state != GameManager.GameState.PLAYING:
		return
	_jump_to_boss_room_for_test()


func _jump_to_boss_room_for_test() -> void:
	if _boss_pos not in _rooms:
		return
	$BulletPool.clear_all()
	_clear_non_boss_test_enemies()
	_open_all_doors_for_test()

	_current_room = _boss_pos
	var boss_room: RoomData = _rooms[_boss_pos]
	boss_room.explored = true
	_mark_adjacent_explored(_boss_pos)

	var boss_center := Vector2(_boss_pos.x * CELL_W + CELL_W / 2, _boss_pos.y * CELL_H + CELL_H / 2)
	$Player.global_position = boss_center + Vector2(0.0, 120.0)
	$Player.visible = true
	$Player.set_physics_process(true)
	$Player.set_process_input(true)

	_update_camera_bounds(_boss_pos)
	_on_player_entered_room(_boss_pos)
	_show_hint("测试：已进入 Boss 房间", Color(1.0, 0.84, 0.0))
	queue_redraw()
	if _minimap:
		_minimap.queue_redraw()


func _clear_non_boss_test_enemies() -> void:
	for room_pos in _rooms:
		if room_pos == _boss_pos:
			continue
		var room: RoomData = _rooms[room_pos]
		for enemy in room.enemies:
			if is_instance_valid(enemy):
				enemy.queue_free()
		room.enemies.clear()
		if room.state == RoomState.ACTIVE:
			room.state = RoomState.CLEARED


func _open_all_doors_for_test() -> void:
	for room_pos in _doors:
		for key in _doors[room_pos]:
			var door: StaticBody2D = _doors[room_pos][key]
			if is_instance_valid(door):
				_set_door_locked(door, false)


func _toggle_pause_from_hud() -> void:
	if GameManager.state == GameManager.GameState.PLAYING:
		GameManager.change_state(GameManager.GameState.PAUSED)
		_show_pause_menu()
	elif GameManager.state == GameManager.GameState.PAUSED:
		_hide_pause_menu()
		GameManager.change_state(GameManager.GameState.PLAYING)


func _show_boss_hp(boss: Area2D) -> void:
	_boss_ref = boss
	var canvas := CanvasLayer.new()
	canvas.layer = 15
	add_child(canvas)

	_boss_hp_bar_bg = ColorRect.new()
	_boss_hp_bar_bg.position = Vector2(230, 590)
	_boss_hp_bar_bg.size = VS.BOSS_HP_FRAME_SIZE
	_boss_hp_bar_bg.color = Color(0.15, 0.15, 0.15)
	canvas.add_child(_boss_hp_bar_bg)

	_boss_hp_bar = ColorRect.new()
	_boss_hp_bar.position = Vector2(231, 591)
	_boss_hp_bar.size = VS.BOSS_HP_FILL_SIZE
	_boss_hp_bar.color = Color(1.0, 0.0, 0.3)
	canvas.add_child(_boss_hp_bar)

	_boss_hp_label = Label.new()
	_boss_hp_label.position = Vector2(430, 592)
	_boss_hp_label.add_theme_font_size_override("font_size", 12)
	_boss_hp_label.add_theme_color_override("font_color", Color.WHITE)
	canvas.add_child(_boss_hp_label)


func _process(delta: float) -> void:
	var state := GameManager.state
	_fps_label.text = "FPS: %d" % Engine.get_frames_per_second()
	_kills_label.text = ""
	_practice_label.text = str(GameManager.practice_time)
	_coin_label.text = str(GameManager.kun_coins)

	_hp_text.text = "%d/%d" % [$Player.hp, $Player.MAX_HP]
	_shield_text.text = "%d/%d" % [$Player.armor, $Player.max_armor]
	_mana_text.text = "%d/%d" % [int($Player.mana), int($Player.MAX_MANA)]

	var mana_ratio: float = $Player.mana / $Player.MAX_MANA
	_mana_bar.size.x = STATUS_FILL_W * clampf(mana_ratio, 0.0, 1.0)
	var hp_ratio: float = float($Player.hp) / float($Player.MAX_HP)
	_hp_bar.size.x = STATUS_FILL_W * clampf(hp_ratio, 0.0, 1.0)
	_hp_bar.color = Color(0.88, 0.07, 0.15)
	var armor_ratio := 0.0 if $Player.max_armor <= 0 else float($Player.armor) / float($Player.max_armor)
	_shield_bar.size.x = STATUS_FILL_W * clampf(armor_ratio, 0.0, 1.0)
	_shield_bar.visible = $Player.max_armor > 0
	_shield_bar_bg.visible = $Player.max_armor > 0
	_shield_text.visible = $Player.max_armor > 0

	# 技能图标刷新
	if _attack_icon:
		_attack_icon.queue_redraw()
	if _switch_icon:
		_switch_icon.queue_redraw()
	if _dash_icon:
		_dash_icon.queue_redraw()
	if _berserk_icon:
		_berserk_icon.queue_redraw()

	# Buff 状态栏刷新
	if _buff_bar:
		_buff_bar.queue_redraw()

	# Boss 血条更新
	if _boss_ref != null and is_instance_valid(_boss_ref) and _boss_hp_bar != null:
		var boss_ratio: float = float(_boss_ref.hp) / float(_boss_ref.max_hp)
		_boss_hp_bar.size.x = VS.BOSS_HP_FILL_SIZE.x * clampf(boss_ratio, 0.0, 1.0)
		_boss_hp_label.text = "BOSS  %d / %d" % [_boss_ref.hp, _boss_ref.max_hp]
	elif _boss_hp_bar_bg != null and (_boss_ref == null or not is_instance_valid(_boss_ref)):
		_boss_hp_bar_bg.visible = false
		_boss_hp_bar.visible = false
		_boss_hp_label.visible = false

	# 命中停顿（使用真实时间，不受 time_scale 影响）
	if _hit_stop_until > 0 and Time.get_ticks_msec() >= _hit_stop_until:
		_hit_stop_until = 0
		Engine.time_scale = 1.0

	# 摄像机震动
	if _cam_mgr:
		_cam_mgr.update(delta)

	# 复活倒计时（真实时间，不受暂停影响）
	if state == GameManager.GameState.REVIVING:
		_revive_timer -= delta
		if _revive_countdown_label != null:
			_revive_countdown_label.text = str(ceil(_revive_timer))
		if _revive_timer <= 0.0:
			_hide_revive_ui()
			_game_over = true
			GameManager.change_state(GameManager.GameState.GAME_OVER)
			_show_game_over()

	if state != GameManager.GameState.PLAYING:
		return

	var near_return_portal: bool = $Player.global_position.distance_to(_start_portal_pos) < DUNGEON_PORTAL_INTERACT_RADIUS
	if _portal_active:
		near_return_portal = near_return_portal or $Player.global_position.distance_to(_portal_pos) < DUNGEON_PORTAL_INTERACT_RADIUS
	if near_return_portal != _return_portal_near:
		_return_portal_near = near_return_portal
		queue_redraw()

	# 怪物预警倒计时
	if _spawn_warning_timer > 0.0:
		_spawn_warning_timer -= delta
		queue_redraw()
		if _spawn_warning_timer <= 0.0:
			if _spawn_warning_room in _rooms:
				_spawn_enemies_with_positions(_spawn_warning_room)
			_spawn_warning_positions.clear()
			queue_redraw()

	# 伤害飘字更新
	_update_damage_numbers(delta)


func _on_player_hit() -> void:
	if _cam_mgr:
		_cam_mgr.shake(4.0, 0.15)


func _on_player_hp_changed(current: int, max_hp: int) -> void:
	var ratio := float(current) / float(max_hp)
	_hp_bar.size.x = STATUS_FILL_W * ratio
	if ratio > 0.3:
		_hp_bar.color = Color(0.0, 0.8, 0.2).lerp(Color(1.0, 0.0, 0.0), 1.0 - ratio)
	else:
		_hp_bar.color = Color(1.0, 0.0, 0.0)


func _on_player_died() -> void:
	if GameManager.revive_coins > 0:
		GameManager.change_state(GameManager.GameState.REVIVING)
		_revive_timer = 10.0
		_show_revive_ui()
	else:
		GameManager.restore_lobby_weapons()
		_game_over = true
		GameManager.change_state(GameManager.GameState.GAME_OVER)
		_show_game_over()


func _show_game_over() -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.size = VS.VIEWPORT_SIZE

	var canvas := CanvasLayer.new()
	canvas.layer = 40
	add_child(canvas)
	canvas.add_child(overlay)

	var label := Label.new()
	label.text = "游戏结束\n击杀: %d\n\n按 R 返回基地" % GameManager.total_kills
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.position = Vector2(380, 240)
	canvas.add_child(label)


func _show_victory() -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.size = VS.VIEWPORT_SIZE

	var canvas := CanvasLayer.new()
	canvas.layer = 40
	add_child(canvas)
	canvas.add_child(overlay)

	var label := Label.new()
	label.text = "通关！\n击杀: %d\n\n按 R 返回基地" % GameManager.total_kills
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.0))
	label.position = Vector2(380, 240)
	canvas.add_child(label)


# ── 去色效果 ──────────────────────────────────────────

# ── 复活系统 ──────────────────────────────────────────

func _show_revive_ui() -> void:
	if _revive_canvas != null:
		_revive_canvas.queue_free()
	_revive_canvas = CanvasLayer.new()
	_revive_canvas.layer = 28
	add_child(_revive_canvas)

	# 半透明背景
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.6)
	bg.size = VS.VIEWPORT_SIZE
	_revive_canvas.add_child(bg)

	# 弹框面板
	var panel := ColorRect.new()
	panel.color = Color(0.12, 0.12, 0.15)
	panel.position = Vector2(330, 220)
	panel.size = Vector2(300, 200)
	_revive_canvas.add_child(panel)

	# 标题
	var title := Label.new()
	title.text = "是否复活？"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
	title.position = Vector2(380, 235)
	_revive_canvas.add_child(title)

	# 倒计时
	_revive_countdown_label = Label.new()
	_revive_countdown_label.text = "10"
	_revive_countdown_label.add_theme_font_size_override("font_size", 48)
	_revive_countdown_label.add_theme_color_override("font_color", Color(1.0, 0.41, 0.71))
	_revive_countdown_label.position = Vector2(455, 280)
	_revive_canvas.add_child(_revive_countdown_label)

	# 提示
	var hint := Label.new()
	hint.text = "点击复活 / ESC 放弃"
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	hint.position = Vector2(385, 360)
	_revive_canvas.add_child(hint)


func _hide_revive_ui() -> void:
	if _revive_canvas != null:
		_revive_canvas.queue_free()
		_revive_canvas = null


func _do_revive() -> void:
	GameManager.revive_coins -= 1
	_hide_revive_ui()
	# 清除所有子弹
	$BulletPool.clear_all()
	# 恢复玩家
	$Player.hp = int($Player.MAX_HP * 0.5)
	$Player.armor = $Player.max_armor
	$Player.hp_changed.emit($Player.hp, $Player.MAX_HP)
	$Player._invuln_timer = 1.5
	# 重新生成当前房间的敌人
	var room: RoomData = _rooms.get(_current_room)
	if room and room.state == RoomState.ACTIVE:
		# 清除残留敌人
		for e in room.enemies:
			if is_instance_valid(e):
				e.queue_free()
		room.enemies.clear()
		room.spawned = false
		room.state = RoomState.INACTIVE
	GameManager.change_state(GameManager.GameState.PLAYING)
	_play_player_spawn_warning($Player)
	_show_hint("已复活！", Color(1.0, 0.84, 0.0))


func _input(event: InputEvent) -> void:
	# 复活状态
	if GameManager.state == GameManager.GameState.REVIVING:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_do_revive()
			return
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			# ESC 放弃复活
			_hide_revive_ui()
			_game_over = true
			GameManager.change_state(GameManager.GameState.GAME_OVER)
			_show_game_over()
			return

	# 暂停
	if GameManager.state == GameManager.GameState.PLAYING:
		if event is InputEventKey and event.pressed and (event.keycode == KEY_ESCAPE or event.keycode == KEY_P):
			GameManager.change_state(GameManager.GameState.PAUSED)
			_show_pause_menu()
			return
	elif GameManager.state == GameManager.GameState.PAUSED:
		if event is InputEventKey and event.pressed and (event.keycode == KEY_ESCAPE or event.keycode == KEY_P):
			_hide_pause_menu()
			GameManager.change_state(GameManager.GameState.PLAYING)
			return

	if GameManager.state == GameManager.GameState.PLAYING and event is InputEventKey and event.pressed and event.keycode == KEY_B:
		get_viewport().set_input_as_handled()
		_open_equipment_panel()
		return

	if _game_over and event is InputEventKey and event.pressed and event.keycode == KEY_R:
		GameManager.restore_lobby_weapons()
		GameManager.return_to_lobby()

	# E 键进入传送门
	if GameManager.state == GameManager.GameState.PLAYING and event.is_action_pressed("interact"):
		if $Player.global_position.distance_to(_start_portal_pos) < DUNGEON_PORTAL_INTERACT_RADIUS:
			GameManager.restore_lobby_weapons()
			GameManager.return_to_lobby()
			return
		if _portal_active and $Player.global_position.distance_to(_portal_pos) < DUNGEON_PORTAL_INTERACT_RADIUS:
			_portal_active = false
			GameManager.restore_lobby_weapons()
			GameManager.add_dungeon_clear()
			GameManager.return_to_lobby()
			return


# ── 暂停菜单 ──────────────────────────────────────────

func _show_pause_menu() -> void:
	if _pause_canvas != null:
		return
	_pause_canvas = CanvasLayer.new()
	_pause_canvas.layer = 35
	_pause_canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_pause_canvas)

	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.size = VS.VIEWPORT_SIZE
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause_canvas.add_child(overlay)

	var label := Label.new()
	label.text = "已暂停"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.position = Vector2(380, 230)
	_pause_canvas.add_child(label)

	# 继续按钮
	var continue_btn := Label.new()
	continue_btn.text = "[ ESC / P 继续 ]"
	continue_btn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	continue_btn.add_theme_font_size_override("font_size", 20)
	continue_btn.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
	continue_btn.position = Vector2(400, 310)
	continue_btn.size = Vector2(160, 30)
	continue_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	continue_btn.gui_input.connect(_on_pause_continue_input)
	_pause_canvas.add_child(continue_btn)

	# 返回基地按钮
	var lobby_btn := Label.new()
	lobby_btn.text = "[ 返回基地 ]"
	lobby_btn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lobby_btn.add_theme_font_size_override("font_size", 20)
	lobby_btn.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3))
	lobby_btn.position = Vector2(400, 360)
	lobby_btn.size = Vector2(160, 30)
	lobby_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	lobby_btn.gui_input.connect(_on_pause_lobby_input)
	_pause_canvas.add_child(lobby_btn)


func _hide_pause_menu() -> void:
	if _pause_canvas != null:
		_pause_canvas.queue_free()
		_pause_canvas = null


func _open_equipment_panel() -> void:
	if _equipment_panel != null or GameManager.state != GameManager.GameState.PLAYING:
		return
	GameManager.change_state(GameManager.GameState.PAUSED)
	_equipment_panel = load("res://scripts/equipment_panel.gd").new()
	_equipment_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	_equipment_panel.tree_exiting.connect(func():
		_equipment_panel = null
		if GameManager.state == GameManager.GameState.PAUSED and _pause_canvas == null:
			GameManager.change_state(GameManager.GameState.PLAYING)
	)
	add_child(_equipment_panel)
	_equipment_panel.show_panel($Player)


func _on_pause_continue_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_hide_pause_menu()
		GameManager.change_state(GameManager.GameState.PLAYING)


func _on_pause_lobby_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_hide_pause_menu()
		GameManager.restore_lobby_weapons()
		GameManager.return_to_lobby()


# ── 打击反馈 ──────────────────────────────────────────

func _on_bullet_hit_feedback(pos: Vector2, damage: int, is_kill: bool, is_boss: bool, projectile_type: String) -> void:
	if projectile_type == "basketball":
		_spawn_basketball_hit_fx(pos)
		var normal_path := BASKETBALL_HEAD_NORMAL_1_PATH if randi() % 2 == 0 else BASKETBALL_HEAD_NORMAL_2_PATH
		_spawn_basketball_hit_icon(pos, _load_basketball_texture(normal_path), false)
	elif projectile_type == "basketball_berserk":
		_spawn_basketball_berserk_hit_fx(pos)
		_spawn_basketball_hit_icon(pos, _load_basketball_texture(BASKETBALL_HEAD_BERSERK_PATH), true)
		trigger_hit_stop(5, 14.0, 0.32)
		spawn_damage_number(pos, damage, Color(1.0, 0.26, 0.08), 18)
		return
	elif projectile_type == "man_bullet":
		_spawn_man_hit_fx(pos, false)
	elif projectile_type == "man_bullet_berserk":
		_spawn_man_hit_fx(pos, true)
	if is_kill:
		trigger_hit_stop(3, 1.0, 0.05)
		spawn_damage_number(pos, damage, Color(1.0, 0.53, 0.0), 16)
	elif is_boss:
		trigger_hit_stop(2, 5.0, 0.2)
		spawn_damage_number(pos, damage, Color(1.0, 0.41, 0.71), 14)
	else:
		trigger_hit_stop(1, 2.0, 0.1)
		spawn_damage_number(pos, damage)


func _spawn_basketball_hit_icon(pos: Vector2, texture: Texture2D, is_berserk: bool) -> void:
	if texture == null:
		return
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = true
	sprite.global_position = pos + Vector2(0.0, -46.0)
	sprite.z_index = 130
	var display_size := 54.0 if is_berserk else 42.0
	var max_dim := maxf(float(texture.get_width()), float(texture.get_height()))
	if max_dim > 0.0:
		sprite.scale = Vector2.ONE * (display_size / max_dim)
	add_child(sprite)
	var tween := sprite.create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "global_position:y", sprite.global_position.y - (20.0 if is_berserk else 12.0), 0.46)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.46)
	tween.tween_property(sprite, "scale", sprite.scale * (1.22 if is_berserk else 1.08), 0.46)
	tween.chain().tween_callback(sprite.queue_free)


func _spawn_basketball_hit_fx(pos: Vector2) -> void:
	var effect := BASKETBALL_HIT_EFFECT.new()
	add_child(effect)
	effect.global_position = pos
	effect.setup(42.0)
	if effect.sprite_frames != null and effect.sprite_frames.get_frame_count("explode") > 0:
		return
	effect.queue_free()
	var fallback := EXPLOSION_EFFECT_SCRIPT.new()
	add_child(fallback)
	fallback.global_position = pos
	fallback.setup(0.26, 26.0)


func _spawn_basketball_berserk_hit_fx(pos: Vector2) -> void:
	var effect := BASKETBALL_BERSERK_HIT_EFFECT.new()
	add_child(effect)
	effect.global_position = pos + Vector2(0.0, -24.0)
	effect.setup(118.0)
	if effect.sprite_frames != null and effect.sprite_frames.get_frame_count("explode") > 0:
		return
	effect.queue_free()
	var fallback := EXPLOSION_EFFECT_SCRIPT.new()
	add_child(fallback)
	fallback.global_position = pos
	fallback.setup(0.34, 54.0)


func _spawn_man_hit_fx(pos: Vector2, is_berserk: bool) -> void:
	if is_berserk:
		var texture := _load_basketball_texture(MAN_BERSERK_EXPLOSION_PATH)
		if texture != null:
			var sprite := Sprite2D.new()
			sprite.texture = texture
			sprite.centered = true
			sprite.global_position = pos
			sprite.z_index = 98
			var max_dim := maxf(float(texture.get_width()), float(texture.get_height()))
			if max_dim > 0.0:
				sprite.scale = Vector2.ONE * (54.0 / max_dim)
			add_child(sprite)
			var tween := sprite.create_tween()
			tween.set_parallel(true)
			tween.tween_property(sprite, "scale", sprite.scale * 1.35, 0.24)
			tween.tween_property(sprite, "modulate:a", 0.0, 0.24)
			tween.tween_callback(sprite.queue_free)
			return
		var fallback := EXPLOSION_EFFECT_SCRIPT.new()
		add_child(fallback)
		fallback.global_position = pos
		fallback.setup(0.28, 58.0)
		return
	var effect := MAN_NORMAL_HIT_EFFECT.new()
	add_child(effect)
	effect.global_position = pos
	effect.setup(46.0)
	if effect.sprite_frames != null and effect.sprite_frames.get_frame_count("explode") > 0:
		return
	effect.queue_free()
	var fallback := EXPLOSION_EFFECT_SCRIPT.new()
	add_child(fallback)
	fallback.global_position = pos
	fallback.setup(0.24, 38.0)


func _load_basketball_texture(path: String) -> Texture2D:
	if _basketball_texture_cache.has(path):
		return _basketball_texture_cache[path]
	var texture := load(path) as Texture2D
	_basketball_texture_cache[path] = texture
	return texture


func trigger_hit_stop(frames: int, shake_intensity: float = 0.0, shake_duration: float = 0.0) -> void:
	var duration_ms: int = int(frames * (1000.0 / 60.0))
	var until: int = Time.get_ticks_msec() + duration_ms
	if until > _hit_stop_until:
		_hit_stop_until = until
		Engine.time_scale = 0.05
	if shake_intensity > 0.0 and _cam_mgr:
		_cam_mgr.shake(shake_intensity, shake_duration)


func spawn_damage_number(pos: Vector2, amount: int, color: Color = Color.WHITE, font_size: int = 12) -> void:
	if _damage_numbers.size() >= MAX_DAMAGE_NUMBERS:
		var oldest: Dictionary = _damage_numbers[0]
		if is_instance_valid(oldest.node):
			oldest.node.queue_free()
		_damage_numbers.remove_at(0)

	var label := Label.new()
	label.text = str(amount)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.position = pos + Vector2(randf_range(-10.0, 10.0), -16.0)
	label.z_index = 100
	add_child(label)
	_damage_numbers.append({"node": label, "alpha": 1.0, "base_color": color})


func _update_damage_numbers(delta: float) -> void:
	var i := _damage_numbers.size() - 1
	while i >= 0:
		var entry: Dictionary = _damage_numbers[i]
		var label: Label = entry.node
		if not is_instance_valid(label):
			_damage_numbers.remove_at(i)
			i -= 1
			continue
		label.position.y -= 30.0 * delta
		entry.alpha -= 2.0 * delta
		if entry.alpha <= 0.0:
			label.queue_free()
			_damage_numbers.remove_at(i)
		else:
			var c: Color = entry.base_color
			c.a = entry.alpha
			label.add_theme_color_override("font_color", c)
		i -= 1


# ── 小地图 ────────────────────────────────────────────

func _create_minimap() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 20
	add_child(canvas)

	var minimap_control := Control.new()
	minimap_control.position = Vector2(856, 178)
	minimap_control.size = Vector2(84, 116)
	minimap_control.name = "Minimap"
	minimap_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	minimap_control.draw.connect(_draw_minimap.bind(minimap_control))
	canvas.add_child(minimap_control)
	_minimap = minimap_control


func _draw_minimap(ctrl: Control) -> void:
	if _rooms.is_empty():
		return

	var cell_size := Vector2(10, 10)
	var gap := 1.5
	var padding := Vector2(17, 22)
	var total := Vector2(GRID_SIZE, GRID_SIZE) * cell_size + padding * 2

	ctrl.draw_rect(Rect2(Vector2(22, 4), Vector2(16, 24)), Color(0.32, 0.34, 0.36))
	ctrl.draw_rect(Rect2(Vector2(29, 28), Vector2(2, 18)), Color(0.92, 0.94, 0.96))
	ctrl.draw_rect(Rect2(Vector2(17, 44), Vector2(28, 28)), Color(0.92, 0.94, 0.96))
	ctrl.draw_rect(Rect2(Vector2(21, 48), Vector2(20, 20)), Color(0.12, 0.16, 0.17))

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
				ctrl.draw_line(from, to, Color(0.78, 0.82, 0.84), gap)

	# 画房间
	for pos in _rooms:
		var room: RoomData = _rooms[pos]
		var r_pos := padding + Vector2(pos) * cell_size

		if not room.explored:
			continue

		var color := Color(0.42, 0.45, 0.48)
		if room.is_boss:
			color = Color(0.7, 0.16, 0.15)
		elif room.state == RoomState.CLEARED:
			color = Color(0.08, 0.85, 0.28)
		elif room.state == RoomState.ACTIVE:
			color = Color(0.7, 0.62, 0.15)

		ctrl.draw_rect(Rect2(r_pos, cell_size), color)

		if pos == _current_room:
			ctrl.draw_rect(Rect2(r_pos - Vector2(3, 3), cell_size + Vector2(6, 6)), Color.WHITE, false, 2.0)


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


func _stable_tile_index(tile_x: int, tile_y: int, seed: int, count: int) -> int:
	var value := tile_x * 73856093 + tile_y * 19349663 + seed * 83492791
	return posmod(value, count)


func _draw_tiled_textures(rect: Rect2, textures: Array, seed: int, tint: Color = Color.WHITE, align_to_rect: bool = false) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0 or textures.is_empty():
		return

	var origin := rect.position if align_to_rect else Vector2.ZERO
	var start_x := int(floor((rect.position.x - origin.x) / MAP_TILE_SIZE))
	var start_y := int(floor((rect.position.y - origin.y) / MAP_TILE_SIZE))
	var end_x := int(ceil((rect.end.x - origin.x) / MAP_TILE_SIZE))
	var end_y := int(ceil((rect.end.y - origin.y) / MAP_TILE_SIZE))

	for tile_x in range(start_x, end_x):
		for tile_y in range(start_y, end_y):
			var tile_rect := Rect2(
				origin + Vector2(tile_x * MAP_TILE_SIZE, tile_y * MAP_TILE_SIZE),
				Vector2(MAP_TILE_SIZE, MAP_TILE_SIZE)
			)
			var clipped := tile_rect.intersection(rect)
			if clipped.size.x <= 0.0 or clipped.size.y <= 0.0:
				continue
			var texture: Texture2D = textures[_stable_tile_index(tile_x, tile_y, seed, textures.size())]
			var source_scale := Vector2(
				float(texture.get_width()) / MAP_TILE_SIZE,
				float(texture.get_height()) / MAP_TILE_SIZE
			)
			var source_rect := Rect2(
				(clipped.position - tile_rect.position) * source_scale,
				clipped.size * source_scale
			)
			draw_texture_rect_region(texture, clipped, source_rect, tint)


func _draw_floor_tiles(rect: Rect2, room: RoomData, seed: int) -> void:
	var tint := Color.WHITE
	if room.is_start:
		tint = Color(1.0, 1.0, 1.0)
	elif room.is_boss:
		tint = Color(0.88, 0.95, 1.0)
	_draw_tiled_textures(rect, ICE_FLOOR_TILES, seed, tint)


func _draw_corridor_tiles(rect: Rect2, seed: int) -> void:
	_draw_tiled_textures(rect, ICE_FLOOR_TILES, seed, Color(0.94, 0.98, 1.0))


func _draw_wall_tiles(rect: Rect2, seed: int) -> void:
	_draw_tiled_textures(rect, ICE_WALL_TILES, seed, Color(0.96, 0.99, 1.0), true)


func _draw_room_corner_tiles(rx: float, ry: float, seed: int) -> void:
	_draw_wall_tiles(Rect2(rx - MAP_TILE_SIZE, ry - MAP_TILE_SIZE, MAP_TILE_SIZE, MAP_TILE_SIZE), seed)
	_draw_wall_tiles(Rect2(rx + ROOM_W, ry - MAP_TILE_SIZE, MAP_TILE_SIZE, MAP_TILE_SIZE), seed + 1)
	_draw_wall_tiles(Rect2(rx - MAP_TILE_SIZE, ry + ROOM_H, MAP_TILE_SIZE, MAP_TILE_SIZE), seed + 2)
	_draw_wall_tiles(Rect2(rx + ROOM_W, ry + ROOM_H, MAP_TILE_SIZE, MAP_TILE_SIZE), seed + 3)


func _draw() -> void:
	for pos in _rooms:
		var room: RoomData = _rooms[pos]
		if not room.explored:
			continue

		var rx: float = pos.x * CELL_W + ROOM_PAD_X
		var ry: float = pos.y * CELL_H + ROOM_PAD_Y

		# 房间背景
		_draw_floor_tiles(Rect2(rx, ry, ROOM_W, ROOM_H), room, 100 + pos.x * 17 + pos.y * 31)

		# 走廊（南走廊）
		var south_pos := Vector2i(pos.x, pos.y + 1)
		var has_south := _has_room_connection(pos, south_pos)
		if has_south and _rooms[south_pos].explored:
			var corr_x: float = pos.x * CELL_W + CELL_W / 2 - CORRIDOR_W / 2
			var corr_y_top: float = ry + ROOM_H
			var corr_y_bot: float = (pos.y + 1) * CELL_H + ROOM_PAD_Y
			var corr_h: float = corr_y_bot - corr_y_top
			_draw_corridor_tiles(Rect2(corr_x, corr_y_top, CORRIDOR_W, corr_h), 300 + pos.x * 17 + pos.y * 31)
			_draw_wall_tiles(Rect2(corr_x - MAP_TILE_SIZE, corr_y_top, MAP_TILE_SIZE, corr_h), 600 + pos.x * 17 + pos.y * 31)
			_draw_wall_tiles(Rect2(corr_x + CORRIDOR_W, corr_y_top, MAP_TILE_SIZE, corr_h), 610 + pos.x * 17 + pos.y * 31)
			var next_ry: float = (pos.y + 1) * CELL_H + ROOM_PAD_Y
			_draw_wall_tiles(Rect2(corr_x - MAP_TILE_SIZE, next_ry - MAP_TILE_SIZE, MAP_TILE_SIZE, MAP_TILE_SIZE), 620 + pos.x * 17 + pos.y * 31)
			_draw_wall_tiles(Rect2(corr_x + CORRIDOR_W, next_ry - MAP_TILE_SIZE, MAP_TILE_SIZE, MAP_TILE_SIZE), 630 + pos.x * 17 + pos.y * 31)

		# 走廊（东走廊）
		var east_pos := Vector2i(pos.x + 1, pos.y)
		var has_east := _has_room_connection(pos, east_pos)
		if has_east and _rooms[east_pos].explored:
			var corr_y: float = pos.y * CELL_H + CELL_H / 2 - CORRIDOR_W / 2
			var corr_x_left: float = rx + ROOM_W
			var corr_x_right: float = (pos.x + 1) * CELL_W + ROOM_PAD_X
			var corr_w: float = corr_x_right - corr_x_left
			_draw_corridor_tiles(Rect2(corr_x_left, corr_y, corr_w, CORRIDOR_W), 400 + pos.x * 17 + pos.y * 31)
			_draw_wall_tiles(Rect2(corr_x_left, corr_y - MAP_TILE_SIZE, corr_w, MAP_TILE_SIZE), 700 + pos.x * 17 + pos.y * 31)
			_draw_wall_tiles(Rect2(corr_x_left, corr_y + CORRIDOR_W, corr_w, MAP_TILE_SIZE), 710 + pos.x * 17 + pos.y * 31)
			var next_rx: float = (pos.x + 1) * CELL_W + ROOM_PAD_X
			_draw_wall_tiles(Rect2(next_rx - MAP_TILE_SIZE, corr_y - MAP_TILE_SIZE, MAP_TILE_SIZE, MAP_TILE_SIZE), 720 + pos.x * 17 + pos.y * 31)
			_draw_wall_tiles(Rect2(next_rx - MAP_TILE_SIZE, corr_y + CORRIDOR_W, MAP_TILE_SIZE, MAP_TILE_SIZE), 730 + pos.x * 17 + pos.y * 31)

		# 墙壁视觉
		var has_north := _has_room_connection(pos, Vector2i(pos.x, pos.y - 1))
		var has_west := _has_room_connection(pos, Vector2i(pos.x - 1, pos.y))
		var gap_l: float = rx + ROOM_W / 2 - CORRIDOR_W / 2
		var gap_r: float = rx + ROOM_W / 2 + CORRIDOR_W / 2
		var gap_t: float = ry + ROOM_H / 2 - CORRIDOR_W / 2
		var gap_b: float = ry + ROOM_H / 2 + CORRIDOR_W / 2
		# 北墙
		if has_north:
			_draw_wall_tiles(Rect2(rx, ry - MAP_TILE_SIZE, gap_l - rx, MAP_TILE_SIZE), 800 + pos.x * 17 + pos.y * 31)
			_draw_wall_tiles(Rect2(gap_r, ry - MAP_TILE_SIZE, rx + ROOM_W - gap_r, MAP_TILE_SIZE), 810 + pos.x * 17 + pos.y * 31)
		else:
			_draw_wall_tiles(Rect2(rx, ry - MAP_TILE_SIZE, ROOM_W, MAP_TILE_SIZE), 820 + pos.x * 17 + pos.y * 31)
		# 南墙
		if has_south:
			_draw_wall_tiles(Rect2(rx, ry + ROOM_H, gap_l - rx, MAP_TILE_SIZE), 830 + pos.x * 17 + pos.y * 31)
			_draw_wall_tiles(Rect2(gap_r, ry + ROOM_H, rx + ROOM_W - gap_r, MAP_TILE_SIZE), 840 + pos.x * 17 + pos.y * 31)
		else:
			_draw_wall_tiles(Rect2(rx, ry + ROOM_H, ROOM_W, MAP_TILE_SIZE), 850 + pos.x * 17 + pos.y * 31)
		# 西墙
		if has_west:
			_draw_wall_tiles(Rect2(rx - MAP_TILE_SIZE, ry, MAP_TILE_SIZE, gap_t - ry), 860 + pos.x * 17 + pos.y * 31)
			_draw_wall_tiles(Rect2(rx - MAP_TILE_SIZE, gap_b, MAP_TILE_SIZE, ry + ROOM_H - gap_b), 870 + pos.x * 17 + pos.y * 31)
		else:
			_draw_wall_tiles(Rect2(rx - MAP_TILE_SIZE, ry, MAP_TILE_SIZE, ROOM_H), 880 + pos.x * 17 + pos.y * 31)
		# 东墙
		if has_east:
			_draw_wall_tiles(Rect2(rx + ROOM_W, ry, MAP_TILE_SIZE, gap_t - ry), 890 + pos.x * 17 + pos.y * 31)
			_draw_wall_tiles(Rect2(rx + ROOM_W, gap_b, MAP_TILE_SIZE, ry + ROOM_H - gap_b), 900 + pos.x * 17 + pos.y * 31)
		else:
			_draw_wall_tiles(Rect2(rx + ROOM_W, ry, MAP_TILE_SIZE, ROOM_H), 910 + pos.x * 17 + pos.y * 31)
		_draw_room_corner_tiles(rx, ry, 920 + pos.x * 17 + pos.y * 31)

		# Boss 标记
		if room.is_boss and room.state != RoomState.CLEARED:
			draw_string(ThemeDB.fallback_font, Vector2(rx + ROOM_W / 2 - 30, ry + 40), "BOSS", HORIZONTAL_ALIGNMENT_CENTER, -1, 20, Color(1.0, 0.0, 0.3))

	_draw_locked_doors()

	# 传送门提示
	if is_instance_valid($Player):
		if $Player.global_position.distance_to(_start_portal_pos) < DUNGEON_PORTAL_INTERACT_RADIUS:
			draw_string(ThemeDB.fallback_font, _start_portal_pos + Vector2(-34, -100), "按 E 交互", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1.0, 1.0, 0.6))
		if _portal_active and $Player.global_position.distance_to(_portal_pos) < DUNGEON_PORTAL_INTERACT_RADIUS:
			draw_string(ThemeDB.fallback_font, _portal_pos + Vector2(-34, -100), "按 E 交互", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1.0, 1.0, 0.6))

	# 怪物出生预警由黄色震荡波节点播放。
