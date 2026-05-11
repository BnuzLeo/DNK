extends AnimatedSprite2D

const ANIMATION_NAME := "explode"
const FRAME_PATHS: Array[String] = [
	"res://assets/export/weapon/weapon_02/普通模式爆炸/explosion_00.png",
	"res://assets/export/weapon/weapon_02/普通模式爆炸/explosion_01.png",
	"res://assets/export/weapon/weapon_02/普通模式爆炸/explosion_02.png",
	"res://assets/export/weapon/weapon_02/普通模式爆炸/explosion_03.png",
	"res://assets/export/weapon/weapon_02/普通模式爆炸/explosion_04.png",
	"res://assets/export/weapon/weapon_02/普通模式爆炸/explosion_05.png",
	"res://assets/export/weapon/weapon_02/普通模式爆炸/explosion_06.png",
	"res://assets/export/weapon/weapon_02/普通模式爆炸/explosion_07.png",
	"res://assets/export/weapon/weapon_02/普通模式爆炸/explosion_08.png",
	"res://assets/export/weapon/weapon_02/普通模式爆炸/explosion_09.png",
	"res://assets/export/weapon/weapon_02/普通模式爆炸/explosion_10.png",
]


func setup(display_width: float = 46.0) -> void:
	centered = true
	z_index = 96
	sprite_frames = _build_frames()
	animation = ANIMATION_NAME
	_fit_to_width(display_width)
	animation_finished.connect(queue_free)
	play(ANIMATION_NAME)


func _build_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")
	frames.add_animation(ANIMATION_NAME)
	frames.set_animation_loop(ANIMATION_NAME, false)
	frames.set_animation_speed(ANIMATION_NAME, 24.0)
	for path in FRAME_PATHS:
		var texture := load(path) as Texture2D
		if texture != null:
			frames.add_frame(ANIMATION_NAME, texture)
	return frames


func _fit_to_width(display_width: float) -> void:
	if sprite_frames == null or sprite_frames.get_frame_count(ANIMATION_NAME) <= 0:
		return
	var texture := sprite_frames.get_frame_texture(ANIMATION_NAME, 0)
	if texture == null or texture.get_width() <= 0:
		return
	scale = Vector2.ONE * (display_width / float(texture.get_width()))
