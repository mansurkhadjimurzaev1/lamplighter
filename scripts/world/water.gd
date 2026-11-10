class_name Water
extends MeshInstance3D
## Вода вокруг острова


func build() -> void:
	name = "Water"
	var plane := PlaneMesh.new()
	plane.size = Vector2(500, 500)
	mesh = plane
	position = Vector3(0, Terrain.WATER_LEVEL, -30)
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
	Terrain.apply_map(mat)
	mat.set_shader_parameter("swamp", Vector3(SwampLayout.CENTER.x, SwampLayout.CENTER.y, SwampLayout.RADIUS + 2.0))
	material_override = mat
