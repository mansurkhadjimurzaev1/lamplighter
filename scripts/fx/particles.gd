class_name Particles
extends RefCounted
## Светлячки над островом и пыль в свете фонаря (MultiMesh из квадратиков).


static func _quad_multimesh(count: int) -> MultiMesh:
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = q
	mm.instance_count = count
	return mm


static func fireflies(count: int) -> MultiMeshInstance3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var mm := _quad_multimesh(count)
	var i := 0
	var tries := 0
	while i < count and tries < count * 50:
		tries += 1
		var a := rng.randf() * TAU
		var d := sqrt(rng.randf()) * Terrain.ISLAND_RADIUS
		var x := cos(a) * d
		var z := sin(a) * d
		var h := Terrain.height_at(x, z)
		if h < 0.3:
			continue
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(x, h + 0.4 + rng.randf() * 1.8, z)))
		mm.set_instance_custom_data(i, Color(rng.randf() * 100.0, 0.5 + rng.randf(), rng.randf(), 0))
		i += 1
	mm.visible_instance_count = i
	mm.custom_aabb = AABB(Vector3(-60, -10, -60), Vector3(120, 30, 120))
	return _instance(mm, "res://shaders/fireflies.gdshader")


static func dust(count: int) -> MultiMeshInstance3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = 17
	var mm := _quad_multimesh(count)
	for i in count:
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(rng.randf(), rng.randf(), rng.randf()) * 5.0))
		mm.set_instance_custom_data(i, Color(rng.randf() * 100.0, rng.randf(), rng.randf(), 0))
	mm.custom_aabb = AABB(Vector3(-500, -100, -500), Vector3(1000, 200, 1000)) # следует за фонарём — не отсекаем
	return _instance(mm, "res://shaders/dust.gdshader")


static func _instance(mm: MultiMesh, shader_path: String) -> MultiMeshInstance3D:
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var mat := ShaderMaterial.new()
	mat.shader = load(shader_path)
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mmi
