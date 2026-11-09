class_name Lantern
extends Node3D
## Фонарь: латунный каркас, стекло, живой огонёк и тёплый свет с тенями.
## Висит на ручке и раскачивается как маятник, когда герой идёт.

var light: OmniLight3D
var _body := Node3D.new()
var _flame: MeshInstance3D
var _flame_mat: StandardMaterial3D
var _noise := FastNoiseLite.new()
var _swing := Vector2.ZERO
var _swing_vel := Vector2.ZERO
var _last_pos := Vector3.ZERO
var _last_vel := Vector3.ZERO
var _has_last := false
var _t := 0.0
const BASE_ENERGY := 4.5


func build(shadows: bool) -> void:
	name = "Lantern"
	_noise.seed = 5
	_noise.frequency = 1.0
	add_child(_body)

	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color(0.42, 0.29, 0.15)
	brass.metallic = 0.85
	brass.roughness = 0.38
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.16, 0.12, 0.09)
	dark.metallic = 0.6
	dark.roughness = 0.55

	var handle_mesh := TorusMesh.new()
	handle_mesh.inner_radius = 0.048
	handle_mesh.outer_radius = 0.062
	_add_part(handle_mesh, dark, Vector3(0, -0.04, 0), Vector3(PI / 2, 0, 0))
	var cap := CylinderMesh.new()
	cap.top_radius = 0.0; cap.bottom_radius = 0.085; cap.height = 0.07; cap.radial_segments = 8
	_add_part(cap, brass, Vector3(0, -0.125, 0))
	var ring := CylinderMesh.new()
	ring.top_radius = 0.085; ring.bottom_radius = 0.085; ring.height = 0.015; ring.radial_segments = 8
	_add_part(ring, brass, Vector3(0, -0.165, 0))
	var base := CylinderMesh.new()
	base.top_radius = 0.075; base.bottom_radius = 0.09; base.height = 0.035; base.radial_segments = 8
	_add_part(base, brass, Vector3(0, -0.36, 0))
	for i in 4:
		var a := i * TAU / 4.0 + PI / 4.0
		var bar := BoxMesh.new()
		bar.size = Vector3(0.01, 0.18, 0.01)
		_add_part(bar, dark, Vector3(cos(a) * 0.072, -0.255, sin(a) * 0.072))

	var glass := CylinderMesh.new()
	glass.top_radius = 0.066; glass.bottom_radius = 0.066; glass.height = 0.18; glass.radial_segments = 12
	glass.cap_top = false; glass.cap_bottom = false
	var glass_mat := StandardMaterial3D.new()
	glass_mat.albedo_color = Color(1.0, 0.76, 0.48, 0.45)
	glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_mat.emission_enabled = true
	glass_mat.emission = Color(1.0, 0.54, 0.16)
	glass_mat.emission_energy_multiplier = 1.4
	glass_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_add_part(glass, glass_mat, Vector3(0, -0.255, 0))

	# огонёк — очень яркий, светится через glow
	var flame_mesh := SphereMesh.new()
	flame_mesh.radius = 0.022; flame_mesh.height = 0.044
	_flame_mat = StandardMaterial3D.new()
	_flame_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flame_mat.albedo_color = Color(1.0, 0.6, 0.25)
	_flame_mat.emission_enabled = true
	_flame_mat.emission = Color(1.0, 0.55, 0.2)
	_flame_mat.emission_energy_multiplier = 12.0
	_flame = _add_part(flame_mesh, _flame_mat, Vector3(0, -0.26, 0))

	light = OmniLight3D.new()
	light.light_color = Color(1.0, 0.62, 0.3)
	light.light_energy = BASE_ENERGY
	light.omni_range = 14.0
	light.omni_attenuation = 0.9
	light.position = Vector3(0, -0.24, 0)
	light.shadow_enabled = shadows
	light.shadow_bias = 0.05
	light.shadow_normal_bias = 1.0
	light.light_size = 0.06 # мягкие края теней
	light.light_volumetric_fog_energy = 1.4
	_body.add_child(light)

	# слабый отсвет фонаря на лицо и плечи героя (без теней, дешёвый)
	var fill := OmniLight3D.new()
	fill.light_color = Color(1.0, 0.6, 0.3)
	fill.light_energy = 0.9
	fill.omni_range = 1.6
	fill.omni_attenuation = 1.5
	fill.position = Vector3(-0.15, 0.55, 0.15)
	fill.light_volumetric_fog_energy = 0.0
	add_child(fill)


func _add_part(m: Mesh, mat: Material, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF # свет внутри — тени от самого фонаря не нужны
	_body.add_child(mi)
	return mi


## pivot_world — точка в руке героя
func update_lantern(dt: float, pivot_world: Vector3) -> void:
	_t += dt
	dt = maxf(dt, 0.001)
	var vel := (pivot_world - _last_pos) / dt if _has_last else Vector3.ZERO
	var acc := ((vel - _last_vel) / dt).limit_length(40.0) if _has_last else Vector3.ZERO
	_last_pos = pivot_world
	_last_vel = vel
	_has_last = true

	var k := 38.0
	var damp := 3.2
	_swing_vel.x += (-k * _swing.x - damp * _swing_vel.x - acc.z * 0.6) * dt
	_swing_vel.y += (-k * _swing.y - damp * _swing_vel.y + acc.x * 0.6) * dt
	_swing += _swing_vel * dt
	_swing = _swing.limit_length(0.6)
	global_position = pivot_world
	_body.rotation = Vector3(_swing.x, 0, _swing.y)

	# мерцание: медленное «дыхание» + быстрая дрожь пламени
	var slow := _noise.get_noise_2d(_t * 0.7, 0.3)
	var fast := _noise.get_noise_2d(_t * 9.0, 4.1) * 0.6 + _noise.get_noise_2d(_t * 23.0, 8.7) * 0.4
	var f := 1.0 + slow * 0.12 + fast * 0.12
	light.light_energy = BASE_ENERGY * f
	_flame.scale = Vector3(1.0 + fast * 0.15, 1.9 + fast * 0.5 + slow * 0.2, 1.0 + fast * 0.15)
	_flame_mat.emission_energy_multiplier = 12.0 * f
	light.position = Vector3(fast * 0.006, -0.24 + slow * 0.005, _noise.get_noise_2d(_t * 11.0, 2.0) * 0.006)


func light_world_position() -> Vector3:
	return light.global_position
