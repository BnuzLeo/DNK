extends Area2D

const VS := preload("res://scripts/visual_spec.gd")

const MOVE_SPEED := 120.0
const CONTACT_COOLDOWN := 0.8
const DISPLAY_SCALE_FACTOR := 2.0 / 3.0

const MINION_ANIMATIONS := {
	"frame_size": 120,
	"animations": {
		"idle": {"path": "res://assets/export/enemies/boss/boss_minion_idle_strip8.png", "frames": 8, "fps": 8.0, "loop": true},
		"walk": {"path": "res://assets/export/enemies/boss/boss_minion_walk_strip8.png", "frames": 8, "fps": 8.0, "loop": true},
		"death": {"path": "res://assets/export/enemies/boss/boss_minion_death_strip1.png", "frames": 1, "fps": 1.0, "loop": false},
	},
}

signal died

var max_hp := 18
var hp := 18
var room_bounds := Rect2()

var _player: CharacterBody2D
var _dying := false
var _contact_cooldown := 0.0
var _flash_timer := 0.0
var _sprite: AnimatedSprite2D = null
var _sprite_base_scale := Vector2.ONE
var _current_animation := ""
var _facing := 1.0
var _moving_this_frame := false
var _hit_recoil := Vector2.ZERO
var _hit_squash_timer := 0.0
var _hit_squash_duration := 0.11


func _ready() -> void:
	collision_layer = 2
	collision_mask = 5
	add_to_group("enemy")
	var shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = 14.0 * DISPLAY_SCALE_FACTOR
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)
	_setup_sprite()


func setup(player: CharacterBody2D) -> void:
	_player = player


func _physics_process(delta: float) -> void:
	if GameManager.state != GameManager.GameState.PLAYING:
		return
	if _player == null or _dying:
		return

	_contact_cooldown = max(_contact_cooldown - delta, 0.0)

	if _flash_timer > 0.0:
		_flash_timer -= delta
		if _flash_timer <= 0.0:
			modulate = Color.WHITE
	_update_hit_recoil(delta)

	var start_pos: Vector2 = global_position
	var dir: Vector2 = (_player.global_position - global_position).normalized()
	if dir.length_squared() > 0.001:
		_facing = 1.0 if dir.x >= 0.0 else -1.0
	global_position += dir * MOVE_SPEED * delta
	_resolve_enemy_overlap()
	if room_bounds.size != Vector2.ZERO:
		global_position.x = clampf(global_position.x, room_bounds.position.x, room_bounds.end.x)
		global_position.y = clampf(global_position.y, room_bounds.position.y, room_bounds.end.y)
	_moving_this_frame = global_position.distance_squared_to(start_pos) > 0.01

	_update_animation()


func take_damage(amount: int) -> void:
	if _dying or amount <= 0:
		return
	hp -= amount
	_flash_timer = 0.1
	modulate = Color.WHITE * 3.0
	if hp <= 0:
		_die()


func apply_hit_feedback(direction: Vector2, strength: float = 8.0, projectile_type: String = "") -> void:
	if _dying:
		return
	var dir := direction.normalized()
	if dir == Vector2.ZERO and _player != null:
		dir = (global_position - _player.global_position).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	_hit_recoil += dir * minf(strength, 24.0)
	_hit_squash_duration = 0.15 if projectile_type == "basketball_berserk" or projectile_type == "man_bullet_berserk" else 0.10
	_hit_squash_timer = _hit_squash_duration
	_apply_hit_squash(1.0)


func _update_hit_recoil(delta: float) -> void:
	if _hit_recoil.length_squared() > 0.01:
		global_position += _hit_recoil
		_hit_recoil = _hit_recoil.move_toward(Vector2.ZERO, 170.0 * delta)
	if _hit_squash_timer > 0.0:
		_hit_squash_timer = maxf(_hit_squash_timer - delta, 0.0)
		var ratio := _hit_squash_timer / maxf(_hit_squash_duration, 0.001)
		_apply_hit_squash(ratio)
	elif _sprite != null and _sprite.scale != _sprite_base_scale:
		_sprite.scale = _sprite_base_scale


func _apply_hit_squash(ratio: float) -> void:
	if _sprite == null:
		return
	var punch := sin(ratio * PI)
	_sprite.scale = Vector2(_sprite_base_scale.x * (1.0 + punch * 0.14), _sprite_base_scale.y * (1.0 - punch * 0.09))


func is_dying() -> bool:
	return _dying


func get_separation_radius() -> float:
	return VS.ENEMY_STANDARD_DISPLAY_SIZE * 0.3 * DISPLAY_SCALE_FACTOR


func _die() -> void:
	_dying = true
	died.emit()
	if _has_animation("death"):
		modulate = Color.WHITE
		_set_animation("death", true)
		var tween: Tween = create_tween()
		tween.tween_interval(_get_animation_duration("death"))
		tween.tween_property(self, "scale", Vector2.ZERO, 0.12).set_ease(Tween.EASE_IN)
		tween.tween_callback(queue_free)
		return
	queue_free()


func _on_body_entered(body: Node2D) -> void:
	if _contact_cooldown > 0.0 or not body.has_method("take_damage"):
		return
	body.take_damage(2)
	_contact_cooldown = CONTACT_COOLDOWN


func _resolve_enemy_overlap() -> void:
	var separation: Vector2 = Vector2.ZERO
	var overlaps: int = 0
	var self_radius: float = get_separation_radius()
	for group_name in ["enemy", "chest", "player"]:
		for other in get_tree().get_nodes_in_group(group_name):
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
			var offset: Vector2 = global_position - other_node.global_position
			var min_distance: float = self_radius + float(other.call("get_separation_radius"))
			var dist_sq: float = offset.length_squared()
			if dist_sq >= min_distance * min_distance:
				continue
			var dist: float = sqrt(dist_sq)
			var normal: Vector2 = offset / dist if dist > 0.001 else _get_fallback_separation_dir(other_node)
			separation += normal * ((min_distance - dist) * 0.5)
			overlaps += 1
	if overlaps > 0:
		global_position += separation / float(overlaps)


func _get_fallback_separation_dir(other: Node) -> Vector2:
	var self_bias := float(get_instance_id() & 1) * 2.0 - 1.0
	var other_bias := float(other.get_instance_id() & 1) * 2.0 - 1.0
	var dir := Vector2(self_bias, other_bias).normalized()
	return dir if dir.length_squared() > 0.0 else Vector2.RIGHT


func _setup_sprite() -> void:
	var frames: SpriteFrames = _build_sprite_frames(MINION_ANIMATIONS)
	if frames == null:
		return
	if _sprite == null:
		_sprite = AnimatedSprite2D.new()
		_sprite.centered = true
		_sprite.z_index = 2
		add_child(_sprite)
	_sprite.sprite_frames = frames
	_current_animation = ""
	var frame_size: float = float(MINION_ANIMATIONS.get("frame_size", 120))
	if frame_size > 0.0:
		var scale_factor: float = VS.ENEMY_STANDARD_DISPLAY_SIZE / frame_size * DISPLAY_SCALE_FACTOR
		_sprite.scale = Vector2(scale_factor, scale_factor)
		_sprite_base_scale = _sprite.scale
	_set_animation("idle", true)


func _update_animation() -> void:
	if _sprite == null:
		return
	_sprite.flip_h = _facing < 0.0
	if _dying:
		_set_animation("death")
	elif _moving_this_frame and _has_animation("walk"):
		_set_animation("walk")
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
		return 0.2
	var frame_count: int = _sprite.sprite_frames.get_frame_count(animation_name)
	var fps: float = _sprite.sprite_frames.get_animation_speed(animation_name)
	if fps <= 0.0:
		return 0.2
	return frame_count / fps
