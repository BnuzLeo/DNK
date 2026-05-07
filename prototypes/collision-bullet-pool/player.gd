## 玩家脚本 — WASD 移动 + 鼠标瞄准射击
extends CharacterBody2D

@export var move_speed: float = 200.0
@export var fire_rate: float = 10.0  # 每秒射击次数
@export var bullet_speed: float = 600.0
@export var bullet_damage: int = 10

var _shoot_cooldown: float = 0.0
var _bullet_pool: BulletPool

func _ready() -> void:
	# 查找子弹池
	_bullet_pool = get_node("../BulletPool") as BulletPool
	# 设置碰撞层（玩家在第1层）
	collision_layer = 1
	collision_mask = 0

func _physics_process(delta: float) -> void:
	# 移动
	var input_dir := Vector2.ZERO
	if Input.is_action_pressed("move_up"):
		input_dir.y -= 1
	if Input.is_action_pressed("move_down"):
		input_dir.y += 1
	if Input.is_action_pressed("move_left"):
		input_dir.x -= 1
	if Input.is_action_pressed("move_right"):
		input_dir.x += 1
	velocity = input_dir.normalized() * move_speed
	move_and_slide()

	# 射击冷却
	_shoot_cooldown -= delta

	# 射击（按住持续射击）
	if Input.is_action_pressed("shoot") and _shoot_cooldown <= 0.0:
		_shoot()
		_shoot_cooldown = 1.0 / fire_rate

func _shoot() -> void:
	if not _bullet_pool:
		return
	var mouse_pos := get_global_mouse_position()
	var direction := (mouse_pos - global_position).normalized()
	if direction.length() < 0.1:
		return
	_bullet_pool.spawn(global_position, direction, bullet_speed, bullet_damage)

func _draw() -> void:
	# 绘制玩家（三角形，朝向鼠标方向）
	var mouse_pos := get_global_mouse_position()
	var angle := (mouse_pos - global_position).angle()
	var points := PackedVector2Array([
		Vector2(14, 0).rotated(angle),
		Vector2(-10, -8).rotated(angle),
		Vector2(-10, 8).rotated(angle),
	])
	draw_colored_polygon(points, Color(0, 0.9, 1))  # Neon Cyan
	draw_polyline(points, Color.WHITE, 1.5)

func _process(_delta: float) -> void:
	queue_redraw()
