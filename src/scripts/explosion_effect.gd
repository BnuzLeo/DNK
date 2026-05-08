extends Node2D

## 炸药桶爆炸视觉效果

var _duration := 0.4
var _radius := 100.0
var _timer := 0.0


func setup(duration: float, radius: float) -> void:
	_duration = duration
	_radius = radius


func _process(delta: float) -> void:
	_timer += delta
	if _timer >= _duration:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var progress := _timer / _duration
	var alpha := 1.0 - progress

	# 扩散圈
	var current_radius := _radius * progress
	draw_arc(Vector2.ZERO, current_radius, 0, TAU, 24,
		Color(1.0, 0.6, 0.1, alpha * 0.8), 3.0)

	# 内圈闪光
	if progress < 0.3:
		var flash_alpha := 1.0 - progress / 0.3
		draw_circle(Vector2.ZERO, 20 * (1.0 - progress), Color(1.0, 0.9, 0.5, flash_alpha))

	# 碎片粒子（随机方向短线）
	for i in 8:
		var angle := i * TAU / 8 + progress * 2.0
		var dist := 15.0 + _radius * 0.5 * progress
		var p := Vector2(cos(angle), sin(angle)) * dist
		draw_circle(p, 2.0 * alpha, Color(1.0, 0.5, 0.1, alpha))
