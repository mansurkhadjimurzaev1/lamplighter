class_name Fx
extends RefCounted
## Заготовки частиц: огонь, искры, вспышка, пыльца, дым.

static func _gradient(stops: Array) -> GradientTexture1D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(stops.map(func(s): return s[0]))
	g.colors = PackedColorArray(stops.map(func(s): return s[1]))
	var t := GradientTexture1D.new()
	t.gradient = g
	return t


static func _curve(points: Array) -> CurveTexture:
	var c := Curve.new()
	for p in points:
		c.add_point(Vector2(p[0], p[1]))
	var t := CurveTexture.new()
	t.curve = c
	return t


static func _particles(amount: int, lifetime: float, pm: ParticleProcessMaterial, size: float, shader: String, intensity := 3.0, softness := 1.0) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = lifetime
	p.process_material = pm
	p.local_coords = false
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var mat := ShaderMaterial.new()
	mat.shader = load(shader)
	if shader.ends_with("glow.gdshader"):
		mat.set_shader_parameter("intensity", intensity)
		mat.set_shader_parameter("softness", softness)
	q.material = mat
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-30, -10, -30), Vector3(60, 40, 60))
	return p


## Пламя в чаше маяка
static func flames() -> GPUParticles3D:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.35
	pm.direction = Vector3.UP
	pm.spread = 12.0
	pm.initial_velocity_min = 0.8
	pm.initial_velocity_max = 1.8
	pm.gravity = Vector3(0, 1.2, 0)
	pm.scale_min = 0.7
	pm.scale_max = 1.3
	pm.scale_curve = _curve([[0.0, 0.6], [0.25, 1.0], [1.0, 0.0]])
	pm.color_ramp = _gradient([[0.0, Color(1.0, 0.78, 0.4, 0.9)], [0.25, Color(1.0, 0.5, 0.12, 0.8)], [0.65, Color(0.85, 0.2, 0.04, 0.45)], [1.0, Color(0.3, 0.05, 0.0, 0.0)]])
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.6
	pm.turbulence_noise_scale = 2.0
	return _particles(56, 1.1, pm, 0.6, "res://shaders/particle_glow.gdshader", 1.6)


## Искры, летящие вверх от огня
static func embers(amount := 26) -> GPUParticles3D:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.4
	pm.direction = Vector3.UP
	pm.spread = 25.0
	pm.initial_velocity_min = 1.5
	pm.initial_velocity_max = 3.5
	pm.gravity = Vector3(0, 0.3, 0)
	pm.damping_min = 0.5
	pm.damping_max = 1.0
	pm.scale_curve = _curve([[0.0, 1.0], [1.0, 0.0]])
	pm.color_ramp = _gradient([[0.0, Color(1.0, 0.85, 0.4, 1.0)], [1.0, Color(1.0, 0.35, 0.05, 0.0)]])
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 1.5
	return _particles(amount, 2.6, pm, 0.07, "res://shaders/particle_glow.gdshader", 5.0, 0.6)


## Вспышка-сноп искр (одноразовый)
static func burst(amount := 160, speed := 7.0) -> GPUParticles3D:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.3
	pm.direction = Vector3.UP
	pm.spread = 75.0
	pm.initial_velocity_min = speed * 0.4
	pm.initial_velocity_max = speed
	pm.gravity = Vector3(0, -3.5, 0)
	pm.damping_min = 0.8
	pm.damping_max = 1.6
	pm.scale_curve = _curve([[0.0, 1.0], [1.0, 0.0]])
	pm.color_ramp = _gradient([[0.0, Color(1.0, 0.95, 0.75, 1.0)], [0.5, Color(1.0, 0.65, 0.2, 0.9)], [1.0, Color(1.0, 0.3, 0.05, 0.0)]])
	var p := _particles(amount, 2.2, pm, 0.09, "res://shaders/particle_glow.gdshader", 6.0, 0.5)
	p.one_shot = true
	p.explosiveness = 0.95
	p.emitting = false
	return p


## Пыльца и лепестки, медленно парящие в ожившей области
static func pollen(radius: float) -> GPUParticles3D:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(radius, 2.5, radius)
	pm.direction = Vector3.UP
	pm.spread = 60.0
	pm.initial_velocity_min = 0.05
	pm.initial_velocity_max = 0.25
	pm.gravity = Vector3(0, 0.04, 0)
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.4
	pm.turbulence_noise_scale = 6.0
	pm.scale_min = 0.6
	pm.scale_max = 1.4
	pm.scale_curve = _curve([[0.0, 0.0], [0.2, 1.0], [0.8, 1.0], [1.0, 0.0]])
	pm.color_ramp = _gradient([[0.0, Color(1.0, 0.95, 0.8, 0.0)], [0.2, Color(1.0, 0.92, 0.75, 0.8)], [0.8, Color(1.0, 0.85, 0.9, 0.6)], [1.0, Color(1.0, 0.9, 0.8, 0.0)]])
	var p := _particles(220, 9.0, pm, 0.07, "res://shaders/particle_glow.gdshader", 1.6)
	p.visibility_aabb = AABB(Vector3(-radius - 2, -6, -radius - 2), Vector3(radius * 2 + 4, 14, radius * 2 + 4))
	return p


## Тёмный дым вокруг Тени
static func smoke(amount := 22) -> GPUParticles3D:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.35
	pm.direction = Vector3.UP
	pm.spread = 40.0
	pm.initial_velocity_min = 0.1
	pm.initial_velocity_max = 0.4
	pm.gravity = Vector3(0, 0.35, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.2
	pm.scale_curve = _curve([[0.0, 0.3], [0.4, 1.0], [1.0, 1.4]])
	pm.color_ramp = _gradient([[0.0, Color(0.3, 0, 0, 0.0)], [0.25, Color(0.6, 0, 0, 0.55)], [1.0, Color(0.9, 0, 0, 0.0)]])
	return _particles(amount, 2.0, pm, 0.7, "res://shaders/particle_smoke.gdshader")


## Клуб дыма при рассеивании Тени (одноразовый)
static func smoke_burst() -> GPUParticles3D:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.5
	pm.direction = Vector3.UP
	pm.spread = 90.0
	pm.initial_velocity_min = 0.4
	pm.initial_velocity_max = 1.4
	pm.gravity = Vector3(0, 0.6, 0)
	pm.damping_min = 0.5
	pm.damping_max = 1.0
	pm.scale_curve = _curve([[0.0, 0.5], [1.0, 1.8]])
	pm.color_ramp = _gradient([[0.0, Color(0.2, 0, 0, 0.7)], [1.0, Color(0.8, 0, 0, 0.0)]])
	var p := _particles(40, 2.2, pm, 0.9, "res://shaders/particle_smoke.gdshader")
	p.one_shot = true
	p.explosiveness = 0.85
	p.emitting = false
	return p
