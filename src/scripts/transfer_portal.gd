extends AnimatedSprite2D
class_name TransferPortal

const ANIMATION_NAME: String = "idle"
const FRAME_PATHS: Array[String] = [
	"res://assets/export/gui/transfer/transfer_gate_0.png",
	"res://assets/export/gui/transfer/transfer_gate_1.png",
	"res://assets/export/gui/transfer/transfer_gate_2.png",
	"res://assets/export/gui/transfer/transfer_gate_3.png",
	"res://assets/export/gui/transfer/transfer_gate_4.png",
	"res://assets/export/gui/transfer/transfer_gate_5.png",
	"res://assets/export/gui/transfer/transfer_gate_6.png",
	"res://assets/export/gui/transfer/transfer_gate_7.png",
]


func setup(display_size: float) -> void:
	centered = true
	sprite_frames = _build_frames()
	animation = ANIMATION_NAME
	_fit_to_display_size(display_size)
	play(ANIMATION_NAME)


func _build_frames() -> SpriteFrames:
	var frames: SpriteFrames = SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")
	frames.add_animation(ANIMATION_NAME)
	frames.set_animation_loop(ANIMATION_NAME, true)
	frames.set_animation_speed(ANIMATION_NAME, 10.0)
	for path in FRAME_PATHS:
		var texture: Texture2D = load(path) as Texture2D
		if texture != null:
			frames.add_frame(ANIMATION_NAME, texture)
	return frames


func _fit_to_display_size(display_size: float) -> void:
	if sprite_frames == null or sprite_frames.get_frame_count(ANIMATION_NAME) == 0:
		return
	var texture: Texture2D = sprite_frames.get_frame_texture(ANIMATION_NAME, 0)
	if texture == null:
		return
	var max_dim: float = max(float(texture.get_width()), float(texture.get_height()))
	if max_dim <= 0.0:
		return
	scale = Vector2.ONE * (display_size / max_dim)
