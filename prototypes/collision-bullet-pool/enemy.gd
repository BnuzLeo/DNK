## 敌人脚本 — 追踪玩家，被子弹命中时受伤
extends Area2D

@export var move_speed: float = 80.0
@export var max_hp: int = 30
@export var collision_damage: int = 5

var _current_hp: int
var _player: CharacterBody2D
var _flash_timer: float = 0.0

func _ready() -> void:
	_current_hp = max_hp
	_player = get_node("../Player") as CharacterBody2D
	# 设置碰撞层（敌人在第2层，检测第3层玩家子弹）
	collision_layer = 2
	collision_mask = 4  # 检测 player_bullet (layer 3)
	add_to_group("enemy")
	# 随机初始颜色偏移（区分个体）
	modulate = Color(1, 0, 1)  # Neon Magenta

func _physics_process(delta: float) -> void:
	# 追踪玩家
	if _player and is_instance_valid(_player):
		var direction := (_player.global_position - global_position).normalized()
		position += direction * move_speed * delta

	# 闪白衰减
	if _flash_timer > 0:
		_flash_timer -= delta
		if _flash_timer <= 0:
			modulate = Color(1, 0, 1)
	queue_redraw()

func take_damage(amount: int) -> void:
	_current_hp -= amount
	# 闪白 1 帧
	modulate = Color.WHITE
	_flash_timer = 0.016  # ~1帧 @60fps
	if _current_hp <= 0:
		die()

func die() -> void:
	# 简单死亡：从场景移除（实际应用对象池回收）
	queue_free()

func _on_area_entered(area: Area2D) -> void:
	# 被子弹命中
	if area.has_method("get_damage"):
		take_damage(area.get_damage())

func _draw() -> void:
	# 绘制敌人（圆形）
	var color := modulate if _flash_timer > 0 else Color(1, 0, 1)
	draw_circle(Vector2.ZERO, 12.0, color)
	draw_arc(Vector2.ZERO, 12.0, 0, TAU, 24, Color.WHITE, 1.0)
