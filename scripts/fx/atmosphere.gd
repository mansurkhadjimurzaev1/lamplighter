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
	env.glow_enabled = true
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
