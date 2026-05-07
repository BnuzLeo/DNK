## 子弹对象池 — 核心性能测试组件
## 管理 250+ 子弹的复用，避免频繁实例化/销毁
class_name BulletPool
extends Node2D

## 池大小配置
@export var pool_size: int = 250

## 子弹脚本
var _bullet_script: Script
## 可用子弹队列
var _available: Array[Area2D] = []
## 活跃子弹列表
var _active: Array[Area2D] = []
## 统计
var _spawn_count: int = 0
var _recycle_count: int = 0

func _ready() -> void:
	_bullet_script = load("res://bullet.gd")
	# 预填充池
	for i in pool_size:
		var bullet := _create_bullet()
		bullet.visible = false
		bullet.set_process(false)
		bullet.set_physics_process(false)
		add_child(bullet)
		_available.append(bullet)

func _create_bullet() -> Area2D:
	var area := Area2D.new()
	area.set_script(_bullet_script)
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 4.0
	collision.shape = shape
	area.add_child(collision)
	# 设置碰撞层（玩家子弹在第3层）
	area.collision_layer = 4
	area.collision_mask = 2  # 检测敌人 (layer 2)
	# 连接碰撞信号
	area.area_entered.connect(_on_bullet_hit.bind(area))
	return area

func _on_bullet_hit(hit_area: Area2D, bullet: Area2D) -> void:
	if hit_area.is_in_group("enemy"):
		# 对敌人造成伤害
		if hit_area.has_method("take_damage") and bullet.has_method("get_damage"):
			hit_area.take_damage(bullet.get_damage())
		recycle(bullet)

## 从池中获取一颗子弹
func spawn(pos: Vector2, direction: Vector2, speed: float, damage: int) -> Area2D:
	if _available.is_empty():
		# 池已满，回收最老的活跃子弹
		if not _active.is_empty():
			_recycle(_active[0])
		else:
			return null

	var bullet: Area2D = _available.pop_back()
	bullet.global_position = pos
	bullet.visible = true
	bullet.set_process(true)
	bullet.set_physics_process(true)

	# 初始化子弹参数
	if bullet.has_method("activate"):
		bullet.activate(direction, speed, damage)

	_active.append(bullet)
	_spawn_count += 1
	return bullet

## 回收子弹到池中
func recycle(bullet: Area2D) -> void:
	if bullet in _active:
		_recycle(bullet)

func _recycle(bullet: Area2D) -> void:
	bullet.visible = false
	bullet.set_process(false)
	bullet.set_physics_process(false)
	_active.erase(bullet)
	_available.append(bullet)
	_recycle_count += 1

## 回收所有活跃子弹
func recycle_all() -> void:
	while not _active.is_empty():
		_recycle(_active[0])

## 获取统计信息
func get_stats() -> Dictionary:
	return {
		"pool_size": pool_size,
		"active": _active.size(),
		"available": _available.size(),
		"total_spawned": _spawn_count,
		"total_recycled": _recycle_count,
	}
