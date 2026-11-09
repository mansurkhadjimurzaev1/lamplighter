class_name CameraRig
extends Camera3D
## Камера сверху под углом ~50°, плавно следует за героем
## и чуть «заглядывает» вперёд по ходу движения.

var pitch := deg_to_rad(50.0)
var yaw := deg_to_rad(20.0)
var _focus := Vector3.ZERO
var _lead := Vector3.ZERO
## Кинематографичный отъезд (зажигание маяка): 1 — обычно
var zoom := 1.0
var _zoom_now := 1.0
var _pitch_base := deg_to_rad(50.0)


func setup() -> void:
	name = "Camera"
	fov = 40.0
	near = 0.3
	far = 160.0


func _distance() -> float:
	var vs := get_viewport().get_visible_rect().size
	return 16.0 if vs.x < vs.y else 12.5 # в портретной ориентации (телефон) — дальше


func snap(target: Vector3) -> void:
	_focus = target
	_apply()


func follow(dt: float, target: Vector3, velocity: Vector3) -> void:
	_zoom_now = lerpf(_zoom_now, zoom, 1.0 - exp(-dt * 0.8))
	pitch = _pitch_base + deg_to_rad(10.0) * (_zoom_now - 1.0)
	_lead = _lead.lerp(velocity * 0.6, 1.0 - exp(-dt * 1.5))
	var want := target + _lead + Vector3(0, 0.6, 0)
	_focus = _focus.lerp(want, 1.0 - exp(-dt * 3.2))
	_apply()


func _apply() -> void:
	var d := _distance() * _zoom_now
	var off := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * d
	global_position = _focus + off
	look_at(_focus, Vector3.UP)
