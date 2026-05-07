## 子弹脚本 — 由对象池管理
extends Area2D

var _direction: Vector2 = Vector2.RIGHT
var _speed: float = 600.0
var _damage: int = 10
var _lifetime: float = 2.0
var _age: float = 0.0

## 激活子弹（由对象池调用）
func activate(direction: Vector2, speed: float, damage: int) -> void:
	_direction = direction.normalized()
	_speed = speed
	_damage = damage
	_age = 0.0

func _physics_process(delta: float) -> void:
	position += _direction * _speed * delta
	_age += delta
	queue_redraw()
	if _age > _lifetime:
		_return_to_pool()

func _return_to_pool() -> void:
	var pool := get_parent() as BulletPool
	if pool:
		pool.recycle(self)

func get_damage() -> int:
	return _damage

func _draw() -> void:
	# 绘制子弹（小圆形，带光晕）
	draw_circle(Vector2.ZERO, 4.0, Color(0, 0.9, 1))  # 核心
	draw_circle(Vector2.ZERO, 6.0, Color(0, 0.9, 1, 0.3))  # 光晕
