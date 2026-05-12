extends Area2D

## 雪人 Boss — 三阶段：分裂雪球 / 雪花风暴 / 跳跃召唤

const VS := preload("res://scripts/visual_spec.gd")
const SHOCKWAVE_EFFECT := preload("res://scripts/shockwave_effect.gd")
const BOSS_MINION_SCRIPT := preload("res://scripts/boss_minion.gd")

enum Phase { P1, P2, P3 }
enum AttackType { BIG_SNOWBALLS, SNOW_STORM, JUMP_SUMMON }

const MOVE_SPEED := 52.0
const CONTACT_COOLDOWN := 1.0

const PHASE1_TELL := 0.55
const PHASE1_ATTACK_INTERVAL := 2.4
const PHASE1_BIG_COUNT := 4
const PHASE1_BIG_SPREAD := deg_to_rad(14.0)
const PHASE1_BIG_SPEED := 240.0
const PHASE1_BIG_DAMAGE := 0
const PHASE1_SPLIT_COUNT := 10
const PHASE1_SPLIT_SPEED := 290.0
const PHASE1_SPLIT_DAMAGE := 5

const PHASE2_TELL := 0.9
const PHASE2_ATTACK_INTERVAL := 4.8
const PHASE2_STORM_DURATION := 2.6
const PHASE2_STORM_EMIT_INTERVAL := 0.055
const PHASE2_STORM_ROTATE_SPEED := 5.8
const PHASE2_STORM_SPEED := 260.0
const PHASE2_STORM_DAMAGE := 4
const PHASE2_STORM_STREAMS := 3

const PHASE3_TELL := 0.6
const PHASE3_ATTACK_INTERVAL := 5.8
const PHASE3_JUMP_COUNT := 2
const PHASE3_JUMP_DURATION := 0.42
const PHASE3_JUMP_ARC_HEIGHT := 72.0
const PHASE3_LAND_DAMAGE := 12
const PHASE3_SUMMON_COUNT := 3
const PHASE3_SUMMON_RADIUS := 120.0
const PHASE3_SHOCKWAVE_HEIGHT := 128.0
const PHASE_ENV_SNOW_COUNT := 26
const PHASE_ENV_CRACK_COUNT := 10

const YELLOW_SHOCKWAVE_SHEET := "res://assets/export/effects/shockwave_yellow_sheet.png"

const BOSS_ANIMATIONS := {
	"frame_size": 120,
	"animations": {
		"idle": {"path": "res://assets/export/enemies/boss/boss_snowman_idle_strip8.png", "frames": 8, "fps": 8.0, "loop": true},
		"tell": {"path": "res://assets/export/enemies/boss/boss_snowman_idle_strip8.png", "frames": 8, "fps": 12.0, "loop": true},
		"jump": {"path": "res://assets/export/enemies/boss/boss_snowman_idle_strip8.png", "frames": 8, "fps": 10.0, "loop": true},
		"death": {"path": "res://assets/export/enemies/boss/boss_snowman_death_strip1.png", "frames": 1, "fps": 1.0, "loop": false},
	},
}

var max_hp := 500
var hp := 500
var max_armor := 0
var armor := 0
var room_bounds := Rect2()
var bullet_pool: Node2D
var room_ref = null

var _player: CharacterBody2D
var _phase: int = Phase.P1
var _dying := false
var _contact_cooldown := 0.0

var _attack_timer := PHASE1_ATTACK_INTERVAL
var _attacking := false
var _attack_type: int = AttackType.BIG_SNOWBALLS
var _tell_timer := 0.0

var _storm_active := false
var _storm_timer := 0.0
var _storm_emit_timer := 0.0
var _storm_angle := 0.0

var _jump_active := false
var _jump_step := 0
var _jump_timer := 0.0
var _jump_from := Vector2.ZERO
var _jump_to := Vector2.ZERO
var _jump_land_cooldown := 0.0

var _flash_timer := 0.0
var _sprite: AnimatedSprite2D = null
var _current_animation := ""
var _phase_visual_time := 0.0


func _ready() -> void:
	collision_layer = 2
	collision_mask = 5
	add_to_group("enemy")
	body_entered.connect(_on_body_entered)
	_setup_sprite()


func setup(player: CharacterBody2D, pool: Node2D, room_data = null) -> void:
	_player = player
	bullet_pool = pool
	room_ref = room_data


func _physics_process(delta: float) -> void:
	if GameManager.state != GameManager.GameState.PLAYING:
		return
	if _player == null or _dying:
		return

	_update_phase()
	_phase_visual_time += delta
	queue_redraw()
	_contact_cooldown = max(_contact_cooldown - delta, 0.0)
	_jump_land_cooldown = max(_jump_land_cooldown - delta, 0.0)

	if _flash_timer > 0.0:
		_flash_timer -= delta
		if _flash_timer <= 0.0:
			_apply_idle_modulate()

	if _storm_active:
		_update_snow_storm(delta)
		return

	if _jump_active:
		_update_jump(delta)
		return

	if _attacking:
		_update_attack_tell(delta)
		return

	_move_toward_player(delta)
	_update_attack_cycle(delta)
	_update_animation()


func _update_phase() -> void:
	var ratio: float = float(hp) / float(max_hp)
	var next_phase: int = Phase.P1
	if ratio <= 0.3:
		next_phase = Phase.P3
	elif ratio <= 0.6:
		next_phase = Phase.P2
	if next_phase != _phase:
		_phase = next_phase
		_phase_visual_time = 0.0
		_create_phase_transition_effect()


func _move_toward_player(delta: float) -> void:
	var dir: Vector2 = (_player.global_position - global_position).normalized()
	if dir.length_squared() > 0.001:
		_face_direction(dir)
	global_position += dir * MOVE_SPEED * delta
	_resolve_actor_overlap()
	_clamp_bounds()


func _update_attack_cycle(delta: float) -> void:
	_attack_timer -= delta
	if _attack_timer > 0.0:
		return
	match _phase:
		Phase.P1:
			_begin_attack(AttackType.BIG_SNOWBALLS, PHASE1_TELL, PHASE1_ATTACK_INTERVAL)
		Phase.P2:
			_begin_attack(AttackType.SNOW_STORM, PHASE2_TELL, PHASE2_ATTACK_INTERVAL)
		Phase.P3:
			_begin_attack(AttackType.JUMP_SUMMON, PHASE3_TELL, PHASE3_ATTACK_INTERVAL)


func _begin_attack(type: int, tell_duration: float, next_interval: float) -> void:
	_attacking = true
	_attack_type = type
	_tell_timer = tell_duration
	_attack_timer = next_interval
	_set_animation("tell", true)


func _update_attack_tell(delta: float) -> void:
	_tell_timer -= delta
	var flash: float = sin(_tell_timer * 28.0) * 0.5 + 0.5
	modulate = _get_base_modulate().lerp(Color.WHITE * 3.0, flash)
	_set_animation("tell")
	if _tell_timer > 0.0:
		return
	_attacking = false
	match _attack_type:
		AttackType.BIG_SNOWBALLS:
			_throw_big_snowballs()
		AttackType.SNOW_STORM:
			_start_snow_storm()
		AttackType.JUMP_SUMMON:
			_start_jump_summon()
	_apply_idle_modulate()


func _throw_big_snowballs() -> void:
	if bullet_pool == null or _player == null:
		return
	var aim: Vector2 = (_player.global_position - global_position).normalized()
	var aim_angle: float = aim.angle()
	var start_angle: float = aim_angle - (PHASE1_BIG_COUNT - 1) * PHASE1_BIG_SPREAD * 0.5
	for i in PHASE1_BIG_COUNT:
		var angle: float = start_angle + i * PHASE1_BIG_SPREAD
		var dir: Vector2 = Vector2(cos(angle), sin(angle))
		var spawn_pos: Vector2 = global_position + dir * (VS.BOSS_DISPLAY_SIZE * 0.55)
		bullet_pool.spawn(
			spawn_pos,
			dir,
			PHASE1_BIG_SPEED,
			PHASE1_BIG_DAMAGE,
			false,
			false,
			0.0,
			"boss_big_snowball"
		)
		_mark_big_snowball(bullet_pool, spawn_pos, dir)


func _mark_big_snowball(pool: Node2D, pos: Vector2, dir: Vector2) -> void:
	for bullet in pool.get_children():
		if not (bullet is Area2D):
			continue
		var bullet_area: Area2D = bullet as Area2D
		if bullet_area == null:
			continue
		if not bullet_area.get_meta("active", false):
			continue
		if bullet_area.get_meta("projectile_type", "") != "boss_big_snowball":
			continue
		if bullet_area.global_position.distance_squared_to(pos) > 1.0:
			continue
		var current_dir: Vector2 = bullet_area.get_meta("direction", Vector2.ZERO)
		if current_dir.distance_squared_to(dir) > 0.0001:
			continue
		bullet_area.set_meta("boss_split_on_hit", true)
		bullet_area.set_meta("boss_has_split", false)
		break


func _start_snow_storm() -> void:
	_storm_active = true
	_storm_timer = PHASE2_STORM_DURATION
	_storm_emit_timer = 0.0
	_storm_angle = (_player.global_position - global_position).angle()
	_set_animation("tell", true)


func _update_snow_storm(delta: float) -> void:
	_storm_timer -= delta
	_storm_emit_timer -= delta
	_storm_angle += PHASE2_STORM_ROTATE_SPEED * delta
	_set_animation("tell")
	if _flash_timer <= 0.0:
		modulate = Color(0.85, 0.95, 1.0).lerp(Color.WHITE, sin(_storm_timer * 18.0) * 0.5 + 0.5)

	while _storm_emit_timer <= 0.0 and _storm_timer > 0.0:
		_emit_snow_storm_volley()
		_storm_emit_timer += PHASE2_STORM_EMIT_INTERVAL

	if _storm_timer > 0.0:
		return
	_storm_active = false
	_apply_idle_modulate()
	_update_animation()


func _emit_snow_storm_volley() -> void:
	if bullet_pool == null:
		return
	for stream in PHASE2_STORM_STREAMS:
		var angle: float = _storm_angle + stream * (TAU / float(PHASE2_STORM_STREAMS))
		var dir: Vector2 = Vector2(cos(angle), sin(angle))
		bullet_pool.spawn(
			global_position + dir * (VS.BOSS_DISPLAY_SIZE * 0.58),
			dir,
			PHASE2_STORM_SPEED,
			PHASE2_STORM_DAMAGE,
			false,
			false,
			0.0,
			"boss_small_snowball"
		)


func _start_jump_summon() -> void:
	_jump_active = true
	_jump_step = 0
	_begin_next_jump()


func _begin_next_jump() -> void:
	if _jump_step >= PHASE3_JUMP_COUNT:
		_jump_active = false
		_apply_idle_modulate()
		_update_animation()
		return
	_jump_from = global_position
	var player_offset: Vector2 = _player.global_position - global_position
	var target_dir: Vector2 = player_offset.normalized() if player_offset.length_squared() > 0.001 else Vector2.DOWN
	_jump_to = global_position + target_dir * min(player_offset.length(), 120.0)
	if room_bounds.size != Vector2.ZERO:
		_jump_to.x = clampf(_jump_to.x, room_bounds.position.x, room_bounds.end.x)
		_jump_to.y = clampf(_jump_to.y, room_bounds.position.y, room_bounds.end.y)
	_jump_timer = PHASE3_JUMP_DURATION
	_set_animation("jump", true)


func _update_jump(delta: float) -> void:
	_jump_timer -= delta
	var progress: float = clampf(1.0 - _jump_timer / PHASE3_JUMP_DURATION, 0.0, 1.0)
	var arc: float = sin(progress * PI) * PHASE3_JUMP_ARC_HEIGHT
	global_position = _jump_from.lerp(_jump_to, progress) + Vector2(0.0, -arc)
	_face_direction((_jump_to - _jump_from).normalized())
	_set_animation("jump")
	if _jump_timer > 0.0:
		return
	global_position = _jump_to
	_resolve_actor_overlap()
	_clamp_bounds()
	_create_landing_shockwave()
	_damage_on_landing()
	_summon_minions()
	_jump_step += 1
	_begin_next_jump()


func _create_landing_shockwave() -> void:
	var parent: Node = get_parent()
	if parent == null:
		return
	var effect = SHOCKWAVE_EFFECT.new()
	effect.global_position = global_position
	parent.add_child(effect)
	effect.setup(YELLOW_SHOCKWAVE_SHEET, Color(1.0, 0.88, 0.3, 0.95), PHASE3_SHOCKWAVE_HEIGHT)


func _create_phase_transition_effect() -> void:
	var parent: Node = get_parent()
	if parent == null:
		return
	var effect = SHOCKWAVE_EFFECT.new()
	effect.global_position = global_position
	parent.add_child(effect)
	match _phase:
		Phase.P2:
			effect.setup(YELLOW_SHOCKWAVE_SHEET, Color(0.62, 0.9, 1.0, 0.88), 150.0)
		Phase.P3:
			effect.setup(YELLOW_SHOCKWAVE_SHEET, Color(1.0, 0.72, 0.3, 0.95), 176.0)
		_:
			effect.setup(YELLOW_SHOCKWAVE_SHEET, Color(0.86, 0.95, 1.0, 0.75), 128.0)


func _damage_on_landing() -> void:
	if _player == null or _jump_land_cooldown > 0.0:
		return
	if global_position.distance_to(_player.global_position) <= 72.0:
		_player.take_damage(PHASE3_LAND_DAMAGE)
	_jump_land_cooldown = 0.2


func _summon_minions() -> void:
	if room_ref == null:
		return
	var parent: Node = get_parent()
	if parent == null:
		return
	for i in PHASE3_SUMMON_COUNT:
		var angle: float = TAU * float(i) / float(PHASE3_SUMMON_COUNT)
		var offset: Vector2 = Vector2(cos(angle), sin(angle)) * PHASE3_SUMMON_RADIUS
		var minion: Area2D = Area2D.new()
		minion.set_script(BOSS_MINION_SCRIPT)
		minion.global_position = global_position + offset
		minion.set("room_bounds", room_bounds)
		parent.add_child(minion)
		minion.call("setup", _player)
		room_ref.enemies.append(minion)
		minion.connect("died", Callable(parent, "_on_enemy_died").bind(minion, room_ref))


func split_big_snowball_at(position: Vector2) -> void:
	if bullet_pool == null:
		return
	for i in PHASE1_SPLIT_COUNT:
		var angle: float = TAU * float(i) / float(PHASE1_SPLIT_COUNT)
		var dir: Vector2 = Vector2(cos(angle), sin(angle))
		bullet_pool.spawn(
			position + dir * 12.0,
			dir,
			PHASE1_SPLIT_SPEED,
			PHASE1_SPLIT_DAMAGE,
			false,
			false,
			0.0,
			"boss_small_snowball"
		)


func _clamp_bounds() -> void:
	if room_bounds.size == Vector2.ZERO:
		return
	global_position.x = clampf(global_position.x, room_bounds.position.x, room_bounds.end.x)
	global_position.y = clampf(global_position.y, room_bounds.position.y, room_bounds.end.y)


func take_damage(amount: int) -> void:
	if _dying or amount <= 0:
		return
	var remaining: int = amount
	if armor > 0:
		var absorbed: int = mini(armor, remaining)
		armor -= absorbed
		remaining -= absorbed
	if remaining > 0:
		hp -= remaining
	_flash_timer = 0.1
	modulate = Color.WHITE * 3.0
	if hp <= 0:
		_die()


func is_dying() -> bool:
	return _dying


func get_separation_radius() -> float:
	return VS.BOSS_DISPLAY_SIZE * 0.55


func _resolve_actor_overlap() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var self_radius := get_separation_radius()
	var separation := Vector2.ZERO
	var overlaps := 0
	for group_name in ["enemy", "chest", "player"]:
		for other in tree.get_nodes_in_group(group_name):
			if other == self or not is_instance_valid(other):
				continue
			if not other.has_method("get_separation_radius"):
				continue
			if other.has_method("is_dying") and bool(other.call("is_dying")):
				continue
			if other.has_method("is_solid_actor") and not bool(other.call("is_solid_actor")):
				continue
			var other_node := other as Node2D
			if other_node == null:
				continue
			var other_radius := float(other.call("get_separation_radius"))
			var min_distance := self_radius + other_radius
			var offset := global_position - other_node.global_position
			var dist_sq := offset.length_squared()
			if dist_sq >= min_distance * min_distance:
				continue
			var dist := sqrt(dist_sq)
			var normal := offset / dist if dist > 0.001 else _get_fallback_separation_dir(other_node)
			separation += normal * ((min_distance - dist) * 0.5)
			overlaps += 1
	if overlaps > 0:
		global_position += separation / float(overlaps)


func _get_fallback_separation_dir(other: Node) -> Vector2:
	var self_bias := float(get_instance_id() & 1) * 2.0 - 1.0
	var other_bias := float(other.get_instance_id() & 1) * 2.0 - 1.0
	var dir := Vector2(self_bias, other_bias).normalized()
	return dir if dir.length_squared() > 0.0 else Vector2.RIGHT


func _die() -> void:
	_dying = true
	if _has_animation("death"):
		modulate = _get_base_modulate()
		_set_animation("death", true)
		var tween: Tween = create_tween()
		tween.tween_interval(_get_animation_duration("death"))
		tween.tween_property(self, "scale", Vector2.ZERO, 0.18).set_ease(Tween.EASE_IN)
		tween.tween_callback(queue_free)
		return
	queue_free()


func _get_base_modulate() -> Color:
	return Color.WHITE if _sprite != null else Color(1.0, 0.0, 0.3)


func _apply_idle_modulate() -> void:
	modulate = _get_base_modulate()


func _setup_sprite() -> void:
	var frames: SpriteFrames = _build_sprite_frames(BOSS_ANIMATIONS)
	if frames == null:
		return
	if _sprite == null:
		_sprite = AnimatedSprite2D.new()
		_sprite.centered = true
		_sprite.z_index = 2
		add_child(_sprite)
	_sprite.sprite_frames = frames
	_current_animation = ""
	var frame_size: float = float(BOSS_ANIMATIONS.get("frame_size", 120))
	if frame_size > 0.0:
		var scale_factor: float = VS.BOSS_DISPLAY_SIZE * 1.7 / frame_size
		_sprite.scale = Vector2(scale_factor, scale_factor)
	_set_animation("idle", true)
	_apply_idle_modulate()


func _update_animation() -> void:
	if _sprite == null:
		return
	if _dying:
		_set_animation("death")
	elif _jump_active:
		_set_animation("jump")
	elif _attacking or _storm_active:
		_set_animation("tell")
	else:
		_set_animation("idle")


func _build_sprite_frames(config: Dictionary) -> SpriteFrames:
	var sprite_frames: SpriteFrames = SpriteFrames.new()
	sprite_frames.remove_animation("default")
	var frame_size: int = int(config.get("frame_size", 120))
	var animations: Dictionary = config.get("animations", {})
	for animation_name in animations.keys():
		var animation: Dictionary = animations[animation_name]
		var texture: Texture2D = _load_texture(String(animation.get("path", "")))
		if texture == null:
			continue
		sprite_frames.add_animation(animation_name)
		sprite_frames.set_animation_speed(animation_name, float(animation.get("fps", 8.0)))
		sprite_frames.set_animation_loop(animation_name, bool(animation.get("loop", true)))
		var frame_count: int = int(animation.get("frames", 1))
		for frame_index in frame_count:
			var atlas: AtlasTexture = AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(frame_index * frame_size, 0, frame_size, frame_size)
			sprite_frames.add_frame(animation_name, atlas)
	if not sprite_frames.has_animation("idle"):
		return null
	return sprite_frames


func _load_texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	var texture: Texture2D = load(path) as Texture2D
	if texture != null:
		return texture
	var image: Image = Image.new()
	var absolute_path: String = ProjectSettings.globalize_path(path)
	if image.load(absolute_path) != OK:
		return null
	return ImageTexture.create_from_image(image)


func _face_direction(dir: Vector2) -> void:
	if _sprite == null or dir.length_squared() <= 0.001:
		return
	_sprite.flip_h = dir.x < 0.0


func _has_animation(animation_name: String) -> bool:
	return _sprite != null and _sprite.sprite_frames != null and _sprite.sprite_frames.has_animation(animation_name)


func _set_animation(animation_name: String, restart: bool = false) -> void:
	if _sprite == null or _sprite.sprite_frames == null:
		return
	var next_animation: String = animation_name if _sprite.sprite_frames.has_animation(animation_name) else "idle"
	if _current_animation == next_animation and not restart:
		return
	_current_animation = next_animation
	_sprite.play(next_animation)


func _get_animation_duration(animation_name: String) -> float:
	if not _has_animation(animation_name):
		return 0.3
	var frame_count: int = _sprite.sprite_frames.get_frame_count(animation_name)
	var fps: float = _sprite.sprite_frames.get_animation_speed(animation_name)
	if fps <= 0.0:
		return 0.3
	return frame_count / fps


func _on_body_entered(body: Node2D) -> void:
	if _contact_cooldown > 0.0 or not body.has_method("take_damage"):
		return
	body.take_damage(8 if _phase < Phase.P3 else 12)
	_contact_cooldown = CONTACT_COOLDOWN


func _draw() -> void:
	if room_bounds.size == Vector2.ZERO:
		return
	var top_left: Vector2 = to_local(room_bounds.position)
	var bottom_right: Vector2 = to_local(room_bounds.end)
	var room_rect: Rect2 = Rect2(top_left, bottom_right - top_left)
	match _phase:
		Phase.P1:
			_draw_phase_one_environment(room_rect)
		Phase.P2:
			_draw_phase_two_environment(room_rect)
		Phase.P3:
			_draw_phase_three_environment(room_rect)


func _draw_phase_one_environment(room_rect: Rect2) -> void:
	draw_rect(room_rect, Color(0.65, 0.9, 1.0, 0.08), true)
	for i in PHASE_ENV_SNOW_COUNT:
		var x: float = room_rect.position.x + fmod(_phase_visual_time * 18.0 + float(i * 47), room_rect.size.x)
		var y: float = room_rect.position.y + fmod(_phase_visual_time * 34.0 + float(i * 83), room_rect.size.y)
		var radius: float = 1.2 + float(i % 3) * 0.45
		draw_circle(Vector2(x, y), radius, Color(0.9, 0.97, 1.0, 0.42))


func _draw_phase_two_environment(room_rect: Rect2) -> void:
	draw_rect(room_rect, Color(0.2, 0.62, 0.95, 0.14), true)
	var pulse: float = sin(_phase_visual_time * 7.0) * 0.5 + 0.5
	for i in 8:
		var radius: float = 42.0 + float(i) * 28.0 + pulse * 10.0
		var start_angle: float = _phase_visual_time * 3.4 + float(i) * 0.7
		draw_arc(Vector2.ZERO, radius, start_angle, start_angle + PI * 1.35, 42, Color(0.78, 0.95, 1.0, 0.22), 2.2)
	for i in 10:
		var offset: float = fmod(_phase_visual_time * 90.0 + float(i * 72), room_rect.size.x + room_rect.size.y)
		var from: Vector2 = room_rect.position + Vector2(offset - room_rect.size.y, 0.0)
		var to: Vector2 = from + Vector2(room_rect.size.y, room_rect.size.y)
		draw_line(from, to, Color(0.82, 0.96, 1.0, 0.16), 2.0)


func _draw_phase_three_environment(room_rect: Rect2) -> void:
	draw_rect(room_rect, Color(0.06, 0.12, 0.18, 0.18), true)
	var pulse: float = sin(_phase_visual_time * 9.0) * 0.5 + 0.5
	draw_circle(Vector2.ZERO, 54.0 + pulse * 18.0, Color(1.0, 0.78, 0.28, 0.08))
	draw_arc(Vector2.ZERO, 82.0 + pulse * 24.0, 0.0, TAU, 52, Color(1.0, 0.74, 0.18, 0.26), 3.0)
	for i in PHASE_ENV_CRACK_COUNT:
		var angle: float = float(i) * TAU / float(PHASE_ENV_CRACK_COUNT) + sin(_phase_visual_time * 2.0) * 0.08
		var length: float = 86.0 + float((i * 19) % 70)
		var start: Vector2 = Vector2(cos(angle), sin(angle)) * 34.0
		var end: Vector2 = Vector2(cos(angle), sin(angle)) * length
		draw_line(start, end, Color(1.0, 0.82, 0.38, 0.22), 2.0)
