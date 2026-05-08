extends StaticBody2D

## 木箱 — 可破坏障碍物，30% 概率掉落宝箱

var hp := 3
var _flash_timer := 0.0
var _dying := false
var _main: Node = null


func setup(main: Node = null) -> void:
	_main = main
	hp = 3
	collision_layer = 16  # 同墙壁，阻挡移动和子弹
	collision_mask = 0

	# 必须手动添加碰撞形状，否则 StaticBody2D 没有实际碰撞体
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(24, 24)
	shape.shape = rect
	add_child(shape)


func _process(delta: float) -> void:
	if _flash_timer > 0.0:
		_flash_timer -= delta
		if _flash_timer <= 0.0:
			modulate = Color(1, 1, 1, 1)
	queue_redraw()


func take_damage(amount: int) -> void:
	if _dying:
		return
	hp -= amount
	_flash_timer = 0.1
	modulate = Color(5, 5, 5, 1)
	if hp <= 0:
		_die()


func _die() -> void:
	_dying = true
	# 30% 概率掉宝箱
	if _main and randf() < 0.3:
		_main._spawn_chest(global_position)
	# 闪烁 + 缩小消失
	var tween := create_tween()
	tween.set_parallel(false)
	for i in 3:
		tween.tween_property(self, "modulate", Color(5, 5, 5, 1), 0.04)
		tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.04)
	tween.tween_property(self, "scale", Vector2.ZERO, 0.15).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)


func _draw() -> void:
	# 棕色木箱
	draw_rect(Rect2(-12, -12, 24, 24), Color(0.55, 0.35, 0.15))
	draw_rect(Rect2(-12, -12, 24, 24), Color(0.7, 0.45, 0.2), false, 1.5)
	# 木纹
	draw_line(Vector2(-10, -3), Vector2(10, -3), Color(0.4, 0.25, 0.1), 1.0)
	draw_line(Vector2(-10, 4), Vector2(10, 4), Color(0.4, 0.25, 0.1), 1.0)
	# 铁钉
	draw_circle(Vector2(-8, -8), 1.5, Color(0.7, 0.7, 0.7))
	draw_circle(Vector2(8, -8), 1.5, Color(0.7, 0.7, 0.7))
	draw_circle(Vector2(-8, 8), 1.5, Color(0.7, 0.7, 0.7))
	draw_circle(Vector2(8, 8), 1.5, Color(0.7, 0.7, 0.7))
