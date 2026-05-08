extends Node2D

## 练习生基地 — 游戏大厅

const ROOM_W := 960
const ROOM_H := 640
const WALL_T := 12

var _player: CharacterBody2D
var _portal_pos := Vector2(480, 120)
var _portal_near := false
var _anim_timer := 0.0

# HUD
var _practice_label: Label
var _coin_label: Label


func _ready() -> void:
	GameManager.change_state(GameManager.GameState.LOBBY)
	_create_walls()
	_create_player()
	_create_npcs()
	_create_hud()


func _create_walls() -> void:
	var wall_color := Color(0.25, 0.22, 0.18)
	# 上
	_make_wall(Vector2(ROOM_W / 2, WALL_T / 2), Vector2(ROOM_W, WALL_T))
	# 下
	_make_wall(Vector2(ROOM_W / 2, ROOM_H - WALL_T / 2), Vector2(ROOM_W, WALL_T))
	# 左
	_make_wall(Vector2(WALL_T / 2, ROOM_H / 2), Vector2(WALL_T, ROOM_H))
	# 右
	_make_wall(Vector2(ROOM_W - WALL_T / 2, ROOM_H / 2), Vector2(WALL_T, ROOM_H))


func _make_wall(pos: Vector2, size: Vector2) -> void:
	var wall := StaticBody2D.new()
	wall.position = pos
	wall.collision_layer = 16
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	wall.add_child(shape)
	add_child(wall)


func _create_player() -> void:
	_player = CharacterBody2D.new()
	_player.position = Vector2(480, 450)
	_player.set_script(load("res://scripts/player.gd"))

	var col := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 8.0
	col.shape = circle
	_player.add_child(col)

	var cam := Camera2D.new()
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = ROOM_W
	cam.limit_bottom = ROOM_H
	_player.add_child(cam)

	add_child(_player)


func _create_npcs() -> void:
	var npc_script := load("res://scripts/npc.gd")

	# 坤坤经纪人（属性升级）
	var broker := Area2D.new()
	broker.position = Vector2(240, 300)
	broker.set_script(npc_script)
	var broker_col := CollisionShape2D.new()
	var broker_circle := CircleShape2D.new()
	broker_circle.radius = 40.0
	broker_col.shape = broker_circle
	broker.add_child(broker_col)
	add_child(broker)
	broker.npc_type = "broker"
	broker.display_name = "坤坤经纪人"
	broker.npc_color = Color(1.0, 0.84, 0.0)

	# 鸡哥铁匠（武器商店）
	var smith := Area2D.new()
	smith.position = Vector2(720, 300)
	smith.set_script(npc_script)
	var smith_col := CollisionShape2D.new()
	var smith_circle := CircleShape2D.new()
	smith_circle.radius = 40.0
	smith_col.shape = smith_circle
	smith.add_child(smith_col)
	add_child(smith)
	smith.npc_type = "smith"
	smith.display_name = "鸡哥铁匠"
	smith.npc_color = Color(0.5, 0.6, 0.8)


func _create_hud() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 10
	add_child(canvas)

	_practice_label = Label.new()
	_practice_label.position = Vector2(20, 16)
	_practice_label.add_theme_font_size_override("font_size", 16)
	_practice_label.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	canvas.add_child(_practice_label)

	_coin_label = Label.new()
	_coin_label.position = Vector2(20, 38)
	_coin_label.add_theme_font_size_override("font_size", 16)
	_coin_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
	canvas.add_child(_coin_label)

	var hint := Label.new()
	hint.text = "WASD移动 | E交互"
	hint.position = Vector2(700, 600)
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	canvas.add_child(hint)


func _process(delta: float) -> void:
	_anim_timer += delta
	_practice_label.text = "练习时长: %d" % GameManager.practice_time
	_coin_label.text = "坤币: %d" % GameManager.kun_coins

	# 传送门接近检测
	if _player and is_instance_valid(_player):
		_portal_near = _player.global_position.distance_to(_portal_pos) < 50.0

	queue_redraw()


func _input(event: InputEvent) -> void:
	if GameManager.state != GameManager.GameState.LOBBY:
		return
	if event.is_action_pressed("interact") and _portal_near:
		_player.save_to_game_manager()
		get_tree().change_scene_to_file("res://scenes/Main.tscn")


func _draw() -> void:
	# 地板
	draw_rect(Rect2(WALL_T, WALL_T, ROOM_W - WALL_T * 2, ROOM_H - WALL_T * 2),
		Color(0.13, 0.12, 0.10))

	# 地板装饰线条
	for i in range(0, ROOM_W, 80):
		draw_line(Vector2(i + WALL_T, WALL_T), Vector2(i + WALL_T, ROOM_H - WALL_T),
			Color(0.15, 0.14, 0.12), 1.0)
	for j in range(0, ROOM_H, 80):
		draw_line(Vector2(WALL_T, j + WALL_T), Vector2(ROOM_W - WALL_T, j + WALL_T),
			Color(0.15, 0.14, 0.12), 1.0)

	# 墙壁颜色
	draw_rect(Rect2(0, 0, ROOM_W, WALL_T), Color(0.25, 0.22, 0.18))
	draw_rect(Rect2(0, ROOM_H - WALL_T, ROOM_W, WALL_T), Color(0.25, 0.22, 0.18))
	draw_rect(Rect2(0, 0, WALL_T, ROOM_H), Color(0.25, 0.22, 0.18))
	draw_rect(Rect2(ROOM_W - WALL_T, 0, WALL_T, ROOM_H), Color(0.25, 0.22, 0.18))

	# 传送门
	var pulse := sin(_anim_timer * 3.0) * 0.15 + 0.85
	draw_circle(_portal_pos, 25.0, Color(0.0, 0.7, 1.0, 0.3 * pulse))
	draw_arc(_portal_pos, 25.0, 0, TAU, 32, Color(0.0, 0.85, 1.0, 0.8 * pulse), 3.0)
	draw_arc(_portal_pos, 18.0, 0, TAU, 32, Color(0.3, 0.9, 1.0, 0.5 * pulse), 2.0)
	draw_arc(_portal_pos, 10.0, 0, TAU, 24, Color(0.6, 1.0, 1.0, 0.6 * pulse), 1.5)

	# 传送门文字
	draw_string(ThemeDB.fallback_font, _portal_pos + Vector2(-30, 45), "副本入口",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.0, 0.85, 1.0, pulse))

	# 靠近提示
	if _portal_near:
		draw_string(ThemeDB.fallback_font, _portal_pos + Vector2(-40, 65), "按 E 进入地牢",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1.0, 1.0, 0.6))
