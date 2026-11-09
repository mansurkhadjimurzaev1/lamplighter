class_name Grass
extends Node3D
## Трава: один набор травинок на квадрат 10×10 м, повторённый по всему острову.
## Каждый квадрат рисуется только когда виден (и не дальше ~45 м).

const CHUNK := 10.0


func build(per_m2: float) -> void:
	var blade := _blade_mesh()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = blade
	var count := int(CHUNK * CHUNK * per_m2)
	mm.instance_count = count
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for i in count:
		var b := Basis(Vector3.UP, rng.randf() * TAU)
		b = b.rotated(Vector3.RIGHT, rng.randf_range(-0.12, 0.12))
		b = b.scaled(Vector3(rng.randf_range(0.8, 1.4), rng.randf_range(0.18, 0.46), 1.0))
		mm.set_instance_transform(i, Transform3D(b, Vector3(rng.randf() * CHUNK, 0.0, rng.randf() * CHUNK)))
	# вершины сдвигаются в шейдере по высоте — расширяем рамку видимости
	mm.custom_aabb = AABB(Vector3(-1, -4, -1), Vector3(CHUNK + 2, 14, CHUNK + 2))

	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/grass.gdshader")
	mat.set_shader_parameter("height_map", Terrain.height_tex)
	mat.set_shader_parameter("weight_map", Terrain.weight_tex)
	mat.set_shader_parameter("map_size", Terrain.SIZE)
	mat.set_shader_parameter("map_res", float(Terrain.SEGS + 1))

	var half := Terrain.ISLAND_RADIUS + 8.0
	var x := -half
	while x < half:
		var z := -half
		while z < half:
			# пропускаем квадраты, где вообще нет суши
			if _has_land(x, z):
				var mmi := MultiMeshInstance3D.new()
				mmi.multimesh = mm
				mmi.material_override = mat
				mmi.position = Vector3(x, 0, z)
				mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				mmi.visibility_range_end = 48.0
				add_child(mmi)
			z += CHUNK
		x += CHUNK


func _has_land(x: float, z: float) -> bool:
	for i in 4:
		for j in 4:
			if Terrain.height_at(x + i * CHUNK / 3.0, z + j * CHUNK / 3.0) > 0.25:
				return true
	return false


## Травинка из 3 сегментов, сужается к кончику, слегка изогнута
func _blade_mesh() -> ArrayMesh:
	var segs := 3
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	for i in segs + 1:
		var t := float(i) / segs
		var w := 0.042 * (1.0 - t * 0.9)
		var bend := t * t * 0.12
		if i < segs:
			verts.append(Vector3(-w, t, bend)); uvs.append(Vector2(0, t))
			verts.append(Vector3(w, t, bend)); uvs.append(Vector2(1, t))
		else:
			verts.append(Vector3(0, t, bend)); uvs.append(Vector2(0.5, t))
	var idx := PackedInt32Array()
	for i in segs - 1:
		var a := i * 2
		idx.append_array([a, a + 2, a + 1, a + 1, a + 2, a + 3])
	var last := (segs - 1) * 2
	idx.append_array([last, last + 2, last + 1])
	var normals := PackedVector3Array()
	for v in verts:
		normals.append(Vector3.UP)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m
