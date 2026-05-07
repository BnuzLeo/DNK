## 主场景脚本 — 管理敌人生成、UI 显示、性能统计
extends Node2D

@export var enemy_count: int = 20
@export var room_width: float = 960.0
@export var room_height: float = 640.0
@export var spawn_interval: float = 0.5

var _enemy_script: Script
var _spawn_timer: float = 0.0
var _enemies_spawned: int = 0
var _fps_label: Label
var _stats_label: Label
var _player: CharacterBody2D
var _bullet_pool: BulletPool

func _ready() -> void:
	_player = $Player as CharacterBody2D
	_bullet_pool = $BulletPool as BulletPool
	_enemy_script = load("res://enemy.gd")

	# 创建 FPS 显示
	_fps_label = Label.new()
	_fps_label.position = Vector2(10, 10)
	_fps_label.add_theme_color_override("font_color", Color.WHITE)
	_fps_label.add_theme_font_size_override("font_size", 16)
	add_child(_fps_label)

	# 创建统计显示
	_stats_label = Label.new()
	_stats_label.position = Vector2(10, 30)
	_stats_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	_stats_label.add_theme_font_size_override("font_size", 14)
	add_child(_stats_label)

	# 创建房间边界视觉
	queue_redraw()

func _draw() -> void:
	# 绘制房间边界
	var rect := Rect2(0, 0, room_width, room_height)
	draw_rect(rect, Color(0.1, 0.1, 0.18))  # Concrete Dark
	draw_rect(rect, Color(0.3, 0.3, 0.4), false, 2.0)  # 边框

func _process(delta: float) -> void:
	# FPS 显示
	_fps_label.text = "FPS: %d | 帧时间: %.1fms" % [Engine.get_frames_per_second(), delta * 1000]

	# 统计显示
	var stats := _bullet_pool.get_stats()
	var current_enemy_count := get_tree().get_nodes_in_group("enemy").size()
	_stats_label.text = "子弹: %d/%d | 敌人: %d | 已发射: %d" % [
		stats.active, stats.pool_size, current_enemy_count, stats.total_spawned
	]

	# 敌人生成
	if _enemies_spawned < enemy_count:
		_spawn_timer -= delta
		if _spawn_timer <= 0:
			_spawn_enemy()
			_spawn_timer = spawn_interval

func _spawn_enemy() -> void:
	var enemy := Area2D.new()
	enemy.set_script(_enemy_script)
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 12.0
	collision.shape = shape
	enemy.add_child(collision)

	# 在房间边缘随机位置生成
	var side := randi() % 4
	match side:
		0: enemy.position = Vector2(randf() * room_width, -20)  # 上
		1: enemy.position = Vector2(randf() * room_width, room_height + 20)  # 下
		2: enemy.position = Vector2(-20, randf() * room_height)  # 左
		3: enemy.position = Vector2(room_width + 20, randf() * room_height)  # 右
	add_child(enemy)
	_enemies_spawned += 1
