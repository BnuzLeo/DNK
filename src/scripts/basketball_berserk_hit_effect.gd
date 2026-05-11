extends AnimatedSprite2D

const ANIMATION_NAME := "explode"
const FRAME_PATHS: Array[String] = [
	"res://assets/export/weapon/weapon_01/berserk_explosion_frames/berserk_explosion_00.png",
	"res://assets/export/weapon/weapon_01/berserk_explosion_frames/berserk_explosion_01.png",
	"res://assets/export/weapon/weapon_01/berserk_explosion_frames/berserk_explosion_02.png",
	"res://assets/export/weapon/weapon_01/berserk_explosion_frames/berserk_explosion_03.png",
	"res://assets/export/weapon/weapon_01/berserk_explosion_frames/berserk_explosion_04.png",
	"res://assets/export/weapon/weapon_01/berserk_explosion_frames/berserk_explosion_05.png",
	"res://assets/export/weapon/weapon_01/berserk_explosion_frames/berserk_explosion_06.png",
	"res://assets/export/weapon/weapon_01/berserk_explosion_frames/berserk_explosion_07.png",
	"res://assets/export/weapon/weapon_01/berserk_explosion_frames/berserk_explosion_08.png",
]


func setup(display_height: float = 118.0) -> void:
	centered = true
	z_index = 98
	sprite_frames = _build_frames()
	animation = ANIMATION_NAME
	_fit_to_height(display_height)
	animation_finished.connect(queue_free)
	play(ANIMATION_NAME)


func _build_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")
	frames.add_animation(ANIMATION_NAME)
	frames.set_animation_loop(ANIMATION_NAME, false)
	frames.set_animation_speed(ANIMATION_NAME, 22.0)
	for path in FRAME_PATHS:
		var texture := load(path) as Texture2D
		if texture != null:
			frames.add_frame(ANIMATION_NAME, texture)
	return frames


func _fit_to_height(display_height: float) -> void:
	if sprite_frames == null or sprite_frames.get_frame_count(ANIMATION_NAME) <= 0:
		return
	var texture := sprite_frames.get_frame_texture(ANIMATION_NAME, 0)
	if texture == null or texture.get_height() <= 0:
		return
	scale = Vector2.ONE * (display_height / float(texture.get_height()))
