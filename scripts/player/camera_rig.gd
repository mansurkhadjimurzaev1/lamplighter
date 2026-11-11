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
## Вид от первого лица (тестовый режим, клавиша V)
var first_person := false
var look_yaw := deg_to_rad(20.0)
var look_pitch := deg_to_rad(-8.0)
var _bob := 0.0
const EYE := 1.42
const MOUSE_SENS := 0.0022


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
	_lead = Vector3.ZERO
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


## Куда смотрит игрок (для мини-карты и направления ходьбы)
func view_yaw() -> float:
	return look_yaw if first_person else yaw


func enter_first_person() -> void:
	first_person = true
	look_yaw = yaw
	look_pitch = deg_to_rad(-8.0)
	fov = 70.0
	near = 0.05


func leave_first_person() -> void:
	first_person = false
	fov = 40.0
	near = 0.3


func mouse_look(rel: Vector2) -> void:
	look_yaw -= rel.x * MOUSE_SENS
	look_pitch = clampf(look_pitch - rel.y * MOUSE_SENS, deg_to_rad(-75.0), deg_to_rad(65.0))


## Глаза героя: лёгкое покачивание шага, плавное следование по высоте
func follow_fp(dt: float, hero_pos: Vector3, walk: float, step_dist: float) -> void:
	_bob = lerpf(_bob, walk, 1.0 - exp(-dt * 6.0))
	var ph := step_dist * PI / 0.62
	var bob := Vector3(cos(ph) * 0.018, absf(sin(ph)) * 0.045 - 0.02, 0) * _bob
	var b := Basis.from_euler(Vector3(look_pitch, look_yaw, sin(ph) * 0.006 * _bob))
	var want := hero_pos + Vector3(0, EYE, 0) + b * Vector3(bob.x, 0, 0) + Vector3(0, bob.y, 0)
	# по высоте — мягко (ступени, кочки), по плоскости — сразу
	var y := lerpf(global_position.y, want.y, 1.0 - exp(-dt * 14.0)) if absf(global_position.y - want.y) < 1.5 else want.y
	global_transform = Transform3D(b, Vector3(want.x, y, want.z))
	_focus = hero_pos + Vector3(0, 0.6, 0) # чтобы обычная камера потом не «прыгала» издалека


## Точка, где висит фонарь в правой руке (в кадре — справа снизу)
func fp_lantern_pivot() -> Vector3:
	var b := Basis.from_euler(Vector3(look_pitch * 0.35, look_yaw, 0))
	return global_position + b * Vector3(0.40, -0.66, -0.72)
