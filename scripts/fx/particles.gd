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
		var x := rng.randf_range(Terrain.MIN.x, Terrain.MAX.x)
		var z := rng.randf_range(Terrain.MIN.y, Terrain.MAX.y)
		var h := Terrain.height_at(x, z)
		if h < 0.3:
			continue
		# в руинах замка светлячков нет — там абсолютная тьма
		if CastleLayout.region_factor(x, z) > 0.0:
			continue
		# в лесу светлячков больше, они держатся у троп
		if ForestLayout.in_core(x, z) and ForestLayout.path_dist(x, z) > 2.5:
			continue
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(x, h + 0.4 + rng.randf() * 1.8, z)))
		mm.set_instance_custom_data(i, Color(rng.randf() * 100.0, 0.5 + rng.randf(), rng.randf(), 0))
		i += 1
	mm.visible_instance_count = i
	mm.custom_aabb = AABB(Vector3(Terrain.MIN.x, -10, Terrain.MIN.y), Vector3(Terrain.MAX.x - Terrain.MIN.x, 40, Terrain.MAX.y - Terrain.MIN.y))
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
