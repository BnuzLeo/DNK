extends Area2D

## Boss 战 — 3阶段 + 扇形/环形弹幕 + 冲刺

const VS := preload("res://scripts/visual_spec.gd")

enum Phase { P1, P2, P3 }
enum AttackType { FAN, RING, DASH }

const MOVE_SPEED := 60.0
const DASH_SPEED := 400.0
const DASH_DISTANCE := 200.0
const DASH_DAMAGE := 20

const FAN_BULLET_SPEED := 250.0
const RING_BULLET_SPEED := 200.0
const BOSS_ANIMATIONS := {}

const PHASE_CONFIGS := {
	Phase.P1: {
		"fan_count": 3, "fan_spread": deg_to_rad(15.0), "fan_interval": 2.0,
		"ring_count": 0, "ring_interval": 0.0,
		"dash_interval": 0.0, "bullet_speed": 250.0, "damage": 8,
	},
	Phase.P2: {
		"fan_count": 5, "fan_spread": deg_to_rad(10.0), "fan_interval": 1.5,
		"ring_count": 8, "ring_interval": 3.0,
		"dash_interval": 4.0, "bullet_speed": 300.0, "damage": 10,
	},
	Phase.P3: {
		"fan_count": 5, "fan_spread": deg_to_rad(8.0), "fan_interval": 1.0,
		"ring_count": 12, "ring_interval": 2.0,
		"dash_interval": 2.5, "bullet_speed": 350.0, "damage": 12,
	},
}

var max_hp := 500
var hp := 500
var max_armor := 0
var armor := 0
var room_bounds := Rect2()
var bullet_pool: Node2D

var _player: CharacterBody2D
var _phase: int = Phase.P1
var _dying := false

# 攻击计时器
var _fan_timer := 0.0
var _ring_timer := 0.0
var _dash_timer := 0.0

# 攻击状态
var _attacking := false
var _attack_type: int = AttackType.FAN
var _tell_timer := 0.0
const TELL_DURATION := 0.3

# 冲刺状态
var _dashing := false
var _dash_dir := Vector2.ZERO
var _dash_traveled := 0.0

# 视觉
var _flash_timer := 0.0
var _base_color := Color(1.0, 0.0, 0.3)
var _sprite: AnimatedSprite2D = null
var _current_animation := ""


func _ready() -> void:
	collision_layer = 2
	collision_mask = 5
	add_to_group("enemy")
	body_entered.connect(_on_body_entered)

	_fan_timer = PHASE_CONFIGS[Phase.P1].fan_interval
	_ring_timer = PHASE_CONFIGS[Phase.P2].ring_interval
	_dash_timer = PHASE_CONFIGS[Phase.P1].dash_interval
	_setup_sprite()


func setup(player: CharacterBody2D, pool: Node2D) -> void:
	_player = player
	bullet_pool = pool


func _physics_process(delta: float) -> void:
	if GameManager.state != GameManager.GameState.PLAYING:
		return
	if _player == null or _dying:
		return

	# 阶段切换
	_update_phase()

	var cfg: Dictionary = PHASE_CONFIGS[_phase]

	# 闪白恢复
	if _flash_timer > 0.0:
		_flash_timer -= delta
		if _flash_timer <= 0.0:
			_apply_idle_modulate()

	# 攻击 "告诉"
	if _attacking:
		_set_animation("tell")
		_tell_timer -= delta
		# "告诉" 视觉
		var flash := sin(_tell_timer * 30.0) * 0.5 + 0.5
		modulate = _get_base_modulate().lerp(Color.WHITE * 3.0, flash)
		if _tell_timer <= 0.0:
			_execute_attack()
			_attacking = false
		queue_redraw()
		return

	# 冲刺中
	if _dashing:
		_set_animation("dash")
		_dash_dir = (_player.global_position - global_position).normalized()
		_face_direction(_dash_dir)
		var move := _dash_dir * DASH_SPEED * delta
		global_position += move
		_dash_traveled += move.length()
		if _dash_traveled >= DASH_DISTANCE:
			_dashing = false
		# 边界
		_clamp_bounds()
		if _flash_timer <= 0.0:
			modulate = Color(0.3, 0.7, 1.0) if _sprite != null else _base_color
		queue_redraw()
		return

	# 缓慢追踪
	_set_animation("idle")
	var dir := (_player.global_position - global_position).normalized()
	_face_direction(dir)
	global_position += dir * MOVE_SPEED * delta
	_clamp_bounds()

	# 攻击计时
	_fan_timer -= delta
	if _fan_timer <= 0.0:
		_start_attack(AttackType.FAN)
		_fan_timer = cfg.fan_interval

	if cfg.ring_count > 0:
		_ring_timer -= delta
		if _ring_timer <= 0.0:
			_start_attack(AttackType.RING)
			_ring_timer = cfg.ring_interval

	if cfg.dash_interval > 0.0:
		_dash_timer -= delta
		if _dash_timer <= 0.0:
			_start_attack(AttackType.DASH)
			_dash_timer = cfg.dash_interval

	if _flash_timer <= 0.0:
		_apply_idle_modulate()
	queue_redraw()


func _update_phase() -> void:
	var ratio := float(hp) / float(max_hp)
	if ratio <= 0.3:
		_phase = Phase.P3
	elif ratio <= 0.6:
		_phase = Phase.P2
	else:
		_phase = Phase.P1


func _start_attack(type: int) -> void:
	_attacking = true
	_attack_type = type
	_tell_timer = TELL_DURATION


func _execute_attack() -> void:
	if bullet_pool == null or _player == null:
		return
	var cfg: Dictionary = PHASE_CONFIGS[_phase]

	match _attack_type:
		AttackType.FAN:
			_fire_fan(cfg.fan_count, cfg.fan_spread, cfg.bullet_speed, cfg.damage)
		AttackType.RING:
			_fire_ring(cfg.ring_count, cfg.bullet_speed, cfg.damage)
		AttackType.DASH:
			_dashing = true
			_dash_dir = (_player.global_position - global_position).normalized()
			_dash_traveled = 0.0


func _fire_fan(count: int, spread: float, speed: float, damage: int) -> void:
	var aim := (_player.global_position - global_position).normalized()
	var aim_angle := aim.angle()
	var start_angle := aim_angle - (count - 1) * spread / 2.0
	for i in count:
		var angle := start_angle + i * spread
		var dir := Vector2(cos(angle), sin(angle))
		bullet_pool.spawn(
			global_position + dir * (VS.BOSS_DISPLAY_SIZE * 0.5),
			dir,
			speed,
			damage,
			false
		)


func _fire_ring(count: int, speed: float, damage: int) -> void:
	for i in count:
		var angle := i * (TAU / count)
		var dir := Vector2(cos(angle), sin(angle))
		bullet_pool.spawn(
			global_position + dir * (VS.BOSS_DISPLAY_SIZE * 0.5),
			dir,
			speed,
			damage,
			false
		)


func _clamp_bounds() -> void:
	if room_bounds.size != Vector2.ZERO:
		global_position.x = clampf(global_position.x, room_bounds.position.x, room_bounds.end.x)
		global_position.y = clampf(global_position.y, room_bounds.position.y, room_bounds.end.y)


func take_damage(amount: int) -> void:
	if _dying or amount <= 0:
		return
	var remaining := amount
	if armor > 0:
		var absorbed := mini(armor, remaining)
		armor -= absorbed
		remaining -= absorbed
	if remaining > 0:
		hp -= remaining
	_flash_timer = 0.1
	modulate = Color.WHITE * 3.0
	if hp <= 0:
		_die()


func _die() -> void:
	_dying = true
	if _has_animation("dead"):
		modulate = _get_base_modulate()
		_set_animation("dead", true)
		var tween := create_tween()
		tween.tween_interval(_get_animation_duration("dead"))
		tween.tween_property(self, "scale", Vector2.ZERO, 0.18).set_ease(Tween.EASE_IN)
		tween.tween_callback(queue_free)
		return
	# 爆炸 + 缩小
	var base_col := _get_base_modulate()
	var tween := create_tween()
	tween.set_parallel(false)
	for i in 5:
		tween.tween_property(self, "modulate", Color.WHITE * 3.0, 0.05)
		tween.tween_property(self, "modulate", base_col, 0.05)
	tween.tween_property(self, "scale", Vector2.ZERO, 0.3).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)


func _get_base_modulate() -> Color:
	return Color.WHITE if _sprite != null else _base_color


func _apply_idle_modulate() -> void:
	modulate = _get_base_modulate()


func _setup_sprite() -> void:
	var frames := _build_sprite_frames(BOSS_ANIMATIONS)
	if frames == null:
		if _sprite != null:
			_sprite.queue_free()
			_sprite = null
		return
	if _sprite == null:
		_sprite = AnimatedSprite2D.new()
		_sprite.centered = true
		_sprite.z_index = 2
		add_child(_sprite)
	_sprite.sprite_frames = frames
	_current_animation = ""
	var frame_size := float(BOSS_ANIMATIONS.get("frame_size", 128))
	if frame_size > 0.0:
		var scale_factor: float = VS.BOSS_DISPLAY_SIZE / frame_size
		_sprite.scale = Vector2(scale_factor, scale_factor)
	_set_animation("idle", true)
	_apply_idle_modulate()


func _build_sprite_frames(config: Dictionary) -> SpriteFrames:
	var sprite_frames := SpriteFrames.new()
	sprite_frames.remove_animation("default")
	var frame_size := int(config.get("frame_size", 128))
	var animations: Dictionary = config.get("animations", {})
	for animation_name in animations.keys():
		var animation: Dictionary = animations[animation_name]
		var texture := _load_texture(animation.get("path", ""))
		if texture == null:
			continue
		sprite_frames.add_animation(animation_name)
		sprite_frames.set_animation_speed(animation_name, float(animation.get("fps", 8.0)))
		sprite_frames.set_animation_loop(animation_name, bool(animation.get("loop", true)))
		var frame_count := int(animation.get("frames", 1))
		for frame_index in frame_count:
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(frame_index * frame_size, 0, frame_size, frame_size)
			sprite_frames.add_frame(animation_name, atlas)
	if not sprite_frames.has_animation("idle"):
		return null
	return sprite_frames


func _load_texture(path: String) -> Texture2D:
	var texture := load(path) as Texture2D
	if texture != null:
		return texture
	var image := Image.new()
	if image.load(path) != OK:
		return null
	return ImageTexture.create_from_image(image)


func _face_direction(dir: Vector2) -> void:
	if _sprite != null and dir.length_squared() > 0.001:
		_sprite.rotation = dir.angle()


func _has_animation(animation_name: String) -> bool:
	return _sprite != null and _sprite.sprite_frames != null and _sprite.sprite_frames.has_animation(animation_name)


func _set_animation(animation_name: String, restart: bool = false) -> void:
	if _sprite == null or _sprite.sprite_frames == null:
		return
	var next_animation := animation_name
	if not _sprite.sprite_frames.has_animation(next_animation):
		next_animation = "idle"
	if _current_animation == next_animation and not restart:
		return
	_current_animation = next_animation
	_sprite.play(next_animation)


func _get_animation_duration(animation_name: String) -> float:
	if not _has_animation(animation_name):
		return 0.3
	var frame_count := _sprite.sprite_frames.get_frame_count(animation_name)
	var fps := _sprite.sprite_frames.get_animation_speed(animation_name)
	if fps <= 0.0:
		return 0.3
	return frame_count / fps


func _on_body_entered(body: Node2D) -> void:
	if _dashing and body.has_method("take_damage"):
		body.take_damage(DASH_DAMAGE)


func _draw() -> void:
	# Boss 身体
	var radius := VS.BOSS_DISPLAY_SIZE * 0.5
	if _sprite == null:
		var col := Color(0.3, 0.7, 1.0) if _dashing else _base_color
		draw_circle(Vector2.ZERO, radius, col)
		draw_arc(Vector2.ZERO, radius, 0, TAU, 32, Color.WHITE, 2.0)

		# 眼睛
		var eye_offset := radius * 0.42
		draw_circle(Vector2(-eye_offset, -radius * 0.25), 5.0, Color.WHITE)
		draw_circle(Vector2(eye_offset, -radius * 0.25), 5.0, Color.WHITE)

	# 阶段指示器
	var hp_ratio := float(hp) / float(max_hp)
	draw_arc(Vector2.ZERO, radius + 4.0, 0, TAU * hp_ratio, 32, Color(1.0, 0.3, 0.3, 0.8), 3.0)

	# 冲刺拖尾
	if _dashing:
		draw_line(Vector2.ZERO, -_dash_dir * (VS.BOSS_DISPLAY_SIZE * 0.65), Color(1.0, 0.3, 0.3, 0.5), 6.0)
