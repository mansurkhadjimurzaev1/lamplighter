class_name Water
extends MeshInstance3D
## Вода вокруг острова


func build() -> void:
	name = "Water"
	var plane := PlaneMesh.new()
	plane.size = Vector2(400, 400)
	mesh = plane
	position.y = Terrain.WATER_LEVEL
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.03
	var tex := NoiseTexture2D.new()
	tex.width = 256
	tex.height = 256
	tex.seamless = true
	tex.as_normal_map = true
	tex.bump_strength = 4.0
	tex.noise = noise

	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/water.gdshader")
	mat.set_shader_parameter("ripple", tex)
	mat.set_shader_parameter("height_map", Terrain.height_tex)
	mat.set_shader_parameter("map_size", Terrain.SIZE)
	mat.set_shader_parameter("map_res", float(Terrain.SEGS + 1))
	material_override = mat
