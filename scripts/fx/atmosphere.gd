class_name Atmosphere
extends RefCounted
## Ночь под Пеленой: окружение (туман, свечение, тон-маппинг), лунный свет,
## финальная цветокоррекция.


static func environment() -> WorldEnvironment:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.027, 0.039, 0.1)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.22, 0.27, 0.55)
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.0
	# свечение огня
	env.glow_enabled = not Args.has("noglow")
	env.glow_intensity = 0.9
	env.glow_strength = 1.0
	env.glow_bloom = 0.02
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	# туман
	env.fog_enabled = true
	env.fog_light_color = Color(0.04, 0.05, 0.13)
	env.fog_density = 0.03
	env.fog_aerial_perspective = 0.0
	if Quality.volumetric_fog:
		# объёмный туман: свет фонаря видно в воздухе
		env.volumetric_fog_enabled = true
		env.volumetric_fog_density = 0.008
		env.volumetric_fog_albedo = Color(0.7, 0.75, 0.9)
		env.volumetric_fog_length = 40.0
		env.volumetric_fog_ambient_inject = 0.05
	if Quality.ssao:
		env.ssao_enabled = true
		env.ssao_radius = 1.2
		env.ssao_intensity = 1.6
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.05
	env.adjustment_saturation = 0.95
	var we := WorldEnvironment.new()
	we.environment = env
	return we


static func moon() -> DirectionalLight3D:
	var m := DirectionalLight3D.new()
	m.light_color = Color(0.52, 0.58, 0.9)
	m.light_energy = 0.42
	m.rotation = Vector3(deg_to_rad(-55), deg_to_rad(-35), 0)
	m.shadow_enabled = false
	m.light_volumetric_fog_energy = 0.3
	return m


## Слой с финальной цветокоррекцией; возвращает материал (для затемнения)
static func grade_layer(parent: Node) -> ShaderMaterial:
	var layer := CanvasLayer.new()
	layer.layer = 1
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/grade.gdshader")
	rect.material = mat
	layer.add_child(rect)
	parent.add_child(layer)
	return mat


## Атмосфера вокруг героя: dawn — насколько ожило место (0..1), forest / swamp — насколько глубоко в лесу / топи.
## Лес — гуще и холоднее туман; топь — зелёная дымка у воды. После маяка всё переходит в рассвет.
static func set_dawn(we: WorldEnvironment, d: float, forest := 0.0, swamp := 0.0, mountain := 0.0, castle := 0.0) -> void:
	var env := we.environment
	var night_amb := Color(0.22, 0.27, 0.55).lerp(Color(0.16, 0.28, 0.36), forest).lerp(Color(0.2, 0.3, 0.22), swamp)
	var night_fog := Color(0.04, 0.05, 0.13).lerp(Color(0.03, 0.07, 0.08), forest).lerp(Color(0.05, 0.09, 0.04), swamp)
	var day_amb := Color(0.78, 0.66, 0.6).lerp(Color(0.62, 0.72, 0.55), forest).lerp(Color(0.7, 0.72, 0.58), swamp)
	var day_fog := Color(0.42, 0.33, 0.36).lerp(Color(0.38, 0.42, 0.33), forest).lerp(Color(0.48, 0.46, 0.36), swamp)
	# горы: ночь холодная, голубая; рассвет — морозно-розовый
	night_amb = night_amb.lerp(Color(0.3, 0.36, 0.62), mountain)
	night_fog = night_fog.lerp(Color(0.08, 0.1, 0.18), mountain)
	day_amb = day_amb.lerp(Color(0.85, 0.75, 0.78), mountain)
	day_fog = day_fog.lerp(Color(0.62, 0.58, 0.66), mountain)
	# замок: абсолютная тьма — почти нет рассеянного света, туман чёрный
	night_amb = night_amb.lerp(Color(0.12, 0.12, 0.22), castle)
	night_fog = night_fog.lerp(Color(0.0, 0.0, 0.01), castle)
	env.ambient_light_color = night_amb.lerp(day_amb, d)
	env.ambient_light_energy = lerpf(lerpf(lerpf(0.75, 0.55, forest), 0.7, swamp), lerpf(1.05, 0.95, forest), d)
	env.fog_light_color = night_fog.lerp(day_fog, d)
	env.fog_density = lerpf(lerpf(lerpf(0.03, 0.05, forest), 0.045, swamp), lerpf(0.016, 0.024, maxf(forest, swamp)), d)
	env.background_color = Color(0.027, 0.039, 0.1).lerp(Color(0.0, 0.0, 0.01), castle).lerp(Color(0.38, 0.29, 0.33), d)
	env.ambient_light_energy *= lerpf(1.0, 0.12, castle * (1.0 - d))
	env.fog_density = lerpf(env.fog_density, 0.07, castle * (1.0 - d))
	env.adjustment_saturation = lerpf(0.95, 1.08, d)
	if env.volumetric_fog_enabled:
		env.volumetric_fog_density = lerpf(lerpf(lerpf(0.008, 0.02, forest), 0.022, swamp), 0.006, d)
		env.volumetric_fog_albedo = Color(0.7, 0.75, 0.9).lerp(Color(0.6, 0.85, 0.8), forest).lerp(Color(0.6, 0.85, 0.5), swamp)
