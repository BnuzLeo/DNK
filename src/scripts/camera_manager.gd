extends RefCounted
class_name CameraManager

## 屏幕震动 + 房间边界管理
## 持有 Camera2D 引用，管理 shake offset 和 limit

var _camera: Camera2D
var _shake_intensity := 0.0
var _shake_duration_ms := 0
var _shake_until_ms := 0
var _shake_exponential := false


func setup(camera: Camera2D) -> void:
	_camera = camera
	_camera.position_smoothing_enabled = true
	_camera.position_smoothing_speed = 8.0
	_camera.offset = Vector2.ZERO
	_camera.limit_smoothed = true


func set_room_bounds(room_rect: Rect2) -> void:
	if _camera == null:
		return
	var vp_size: Vector2 = _camera.get_viewport_rect().size
	var half_vp := vp_size / 2.0
	_camera.limit_left = int(room_rect.position.x - half_vp.x)
	_camera.limit_right = int(room_rect.end.x + half_vp.x)
	_camera.limit_top = int(room_rect.position.y - half_vp.y)
	_camera.limit_bottom = int(room_rect.end.y + half_vp.y)


func shake(intensity: float, duration: float, exponential: bool = false) -> void:
	if intensity <= _shake_intensity:
		return
	var duration_ms := int(duration * 1000.0)
	var until := Time.get_ticks_msec() + duration_ms
	_shake_intensity = intensity
	_shake_duration_ms = duration_ms
	_shake_until_ms = until
	_shake_exponential = exponential


func update(_delta: float) -> void:
	if _camera == null:
		return
	if _shake_until_ms > 0:
		var now := Time.get_ticks_msec()
		if now >= _shake_until_ms:
			_camera.offset = Vector2.ZERO
			_shake_intensity = 0.0
			_shake_until_ms = 0
		else:
			var remaining_ms: float = float(_shake_until_ms - now)
			var ratio := remaining_ms / float(_shake_duration_ms)
			if _shake_exponential:
				ratio = ratio * ratio
			var offset_dir := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
			_camera.offset = offset_dir * _shake_intensity * ratio
