extends Area2D

## 危险地面 — 岩浆/毒池
## 不阻挡移动，玩家和怪物踩上去持续扣血

const DAMAGE_INTERVAL := 0.5
const DAMAGE := 2

var _anim_timer := 0.0
var _entities_inside: Array[Node2D] = []
var _tick_timers: Dictionary = {}  # {Node2D: float}


func _ready() -> void:
	collision_layer = 0
	# 检测玩家(layer 1) + 敌人(layer 2)
	collision_mask = 3
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)


func _on_body_entered(body: Node2D) -> void:
	_add_entity(body)


func _on_body_exited(body: Node2D) -> void:
	_remove_entity(body)


func _on_area_entered(area: Area2D) -> void:
	_add_entity(area)


func _on_area_exited(area: Area2D) -> void:
	_remove_entity(area)


func _add_entity(entity: Node2D) -> void:
	if entity not in _entities_inside:
		_entities_inside.append(entity)
		_tick_timers[entity] = 0.0
		_damage_entity(entity)


func _remove_entity(entity: Node2D) -> void:
	_entities_inside.erase(entity)
	_tick_timers.erase(entity)


func _physics_process(delta: float) -> void:
	_anim_timer += delta

	var to_remove: Array[Node2D] = []
	for entity in _entities_inside:
		if not is_instance_valid(entity):
			to_remove.append(entity)
			continue
		_tick_timers[entity] = _tick_timers.get(entity, 0.0) + delta
		if _tick_timers[entity] >= DAMAGE_INTERVAL:
			_tick_timers[entity] -= DAMAGE_INTERVAL
			_damage_entity(entity)

	for entity in to_remove:
		_remove_entity(entity)

	queue_redraw()


func _damage_entity(entity: Node2D) -> void:
	if entity.has_method("take_damage"):
		entity.take_damage(DAMAGE)


func _draw() -> void:
	# 脉冲颜色（岩浆 / 毒池）
	var pulse := sin(_anim_timer * 3.0) * 0.15 + 0.85
	var base_color := Color(0.8, 0.3, 0.05, 0.6 * pulse)  # 橙红岩浆
	var glow_color := Color(1.0, 0.5, 0.1, 0.3 * pulse)

	# 底色
	draw_rect(Rect2(-25, -18, 50, 36), base_color)
	# 高光波纹
	var wave_offset := sin(_anim_timer * 2.0) * 8.0
	draw_rect(Rect2(-20 + wave_offset, -12, 15, 6), glow_color)
	draw_rect(Rect2(5 - wave_offset, 2, 12, 5), glow_color)
	# 边缘
	draw_rect(Rect2(-25, -18, 50, 36), Color(1.0, 0.4, 0.1, 0.4 * pulse), false, 1.5)
