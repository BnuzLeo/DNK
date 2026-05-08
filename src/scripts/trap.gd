extends Area2D

## 地刺陷阱 — 玩家踩上去持续受伤

const DAMAGE_INTERVAL := 0.5
const DAMAGE := 1

var _tick_timer := 0.0
var _player_on := false
var _player: Node = null
var _anim_timer := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1  # 检测玩家
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_on = true
		_player = body
		_tick_timer = 0.0  # 立即触发一次伤害
		_damage_player()


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_on = false
		_player = null


func _physics_process(delta: float) -> void:
	_anim_timer += delta
	if _player_on and _player != null:
		_tick_timer += delta
		if _tick_timer >= DAMAGE_INTERVAL:
			_tick_timer -= DAMAGE_INTERVAL
			_damage_player()
	queue_redraw()


func _damage_player() -> void:
	if _player != null and _player.has_method("take_damage"):
		_player.take_damage(DAMAGE)


func _draw() -> void:
	# 脉冲效果
	var pulse := sin(_anim_timer * 4.0) * 0.2 + 0.8
	var color := Color(1.0, 0.2, 0.2, pulse)
	var warn_color := Color(1.0, 0.4, 0.1, pulse * 0.5)

	# 地刺三角形
	var spikes := PackedVector2Array()
	spikes.append(Vector2(0, -10))
	spikes.append(Vector2(-8, 8))
	spikes.append(Vector2(8, 8))
	draw_colored_polygon(spikes, color)

	# 内部高光
	var inner := PackedVector2Array()
	inner.append(Vector2(0, -5))
	inner.append(Vector2(-4, 5))
	inner.append(Vector2(4, 5))
	draw_colored_polygon(inner, warn_color)

	# 外圈警告
	draw_arc(Vector2.ZERO, 12, 0, TAU, 16, Color(1.0, 0.3, 0.2, 0.3 * pulse), 1.5)
