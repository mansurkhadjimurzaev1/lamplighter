class_name Vegetation
extends Node3D
## Деревья, камни, кусты (CC0, Quaternius). Рисуются через MultiMesh:
## сотни объектов за несколько вызовов отрисовки. Разбиты на участки 16×16 м,
## чтобы камера и тени фонаря обрабатывали только ближние.

const CHUNK := 16.0
const BASE := "res://assets/models/nature/"

## Круги, через которые нельзя пройти: Vector3(x, z, радиус)
var colliders: Array[Vector3] = []
## Места, где ничего не растёт (вокруг маяков): Vector3(x, z, радиус)
var exclusions: Array[Vector3] = []

var _rng := RandomNumberGenerator.new()
var _forest := FastNoiseLite.new()
var _rock_tex: Texture2D
var _models := {}
## Занятые места: сетка 4×4 м → список Vector3(x, z, радиус) — быстрая проверка соседей
var _grid := {}
const GRID := 4.0


func _occupied(x: float, z: float, r: float) -> bool:
	var cx := floori(x / GRID)
	var cz := floori(z / GRID)
	for i in range(cx - 1, cx + 2):
		for j in range(cz - 1, cz + 2):
			for c in _grid.get(Vector2i(i, j), []):
				if Vector2(c.x - x, c.y - z).length() < c.z + r:
					return true
	return false


func _occupy(x: float, z: float, r: float) -> void:
	var key := Vector2i(floori(x / GRID), floori(z / GRID))
	if not _grid.has(key):
		_grid[key] = []
	_grid[key].append(Vector3(x, z, r))


func _forest_density(x: float, z: float) -> float:
	return _forest.get_noise_2d(x, z) * 0.5 + 0.5


func _away(x: float, z: float, r: float) -> bool:
	return Vector2(x, z).length() > r


func _kinds() -> Array:
	# files, высота [от, до], количество, радиус столкновения (доля ширины), условие, утопить, наклон, тень
	return [
		{files = ["PineTree_1", "PineTree_2", "PineTree_3", "PineTree_4", "PineTree_5"], h = [5.0, 8.5], count = 150, collide = 0.09, shadow = true,
			where = func(x, z): return _away(x, z, 10.0) and _forest_density(x, z) > 0.45 + _rng.randf() * 0.2},
		{files = ["CommonTree_1", "CommonTree_2", "CommonTree_3", "CommonTree_4"], h = [3.5, 5.5], count = 28, collide = 0.08, shadow = true,
			where = func(x, z): return _away(x, z, 11.0) and _forest_density(x, z) > 0.4 + _rng.randf() * 0.25},
		{files = ["CommonTree_Dead_1", "CommonTree_Dead_3", "BirchTree_Dead_2"], h = [3.5, 5.5], count = 22, collide = 0.07, shadow = true,
			where = func(x, z): return _away(x, z, 8.0) and _forest_density(x, z) < 0.5},
		{files = ["Rock_1", "Rock_2", "Rock_3", "Rock_4", "Rock_5"], h = [0.4, 1.6], count = 70, collide = 0.35, sink = 0.15, tilt = 0.3, shadow = true,
			where = func(x, z): return Terrain.weights_at(x, z).z > 0.25 or Terrain.height_at(x, z) < 0.6},
		{files = ["Rock_Moss_1", "Rock_Moss_2", "Rock_Moss_4", "Rock_Moss_6"], h = [0.5, 1.8], count = 55, collide = 0.35, sink = 0.15, tilt = 0.3, shadow = true,
			where = func(x, z): return _away(x, z, 3.0) and Terrain.weights_at(x, z).x > 0.3},
		{files = ["Bush_1", "Bush_2", "BushBerries_1"], h = [0.6, 1.2], count = 90, collide = 0.0, sink = 0.05, shadow = true,
			where = func(x, z): return _forest_density(x, z) > 0.35 + _rng.randf() * 0.3},
		{files = ["Plant_1", "Plant_2", "Plant_3", "Plant_5"], h = [0.3, 0.7], count = 160, collide = 0.0, shadow = false,
			where = func(x, z): return Terrain.weights_at(x, z).x > 0.5},
		{files = ["TreeStump_Moss", "WoodLog_Moss"], h = [0.4, 0.7], count = 18, collide = 0.3, sink = 0.05, shadow = true,
			where = func(x, z): return _away(x, z, 4.0) and _forest_density(x, z) > 0.4},
		{files = ["Flowers"], h = [0.25, 0.4], count = 40, collide = 0.0, shadow = false,
			where = func(x, z): return Terrain.weights_at(x, z).x > 0.7},
	]


## Разбираем модель на меши с их положением; нормализуем: высота 1, основание на y = 0
func _load_model(file: String, grow := false) -> Dictionary:
	if file.begins_with("PineTree_") and not Args.has("oldpines"):
		if _rock_tex == null:
			_rock_tex = load("res://assets/textures/ground/Rock030_color.jpg")
		return Pine.make(1000 + int(file.get_slice("_", 1)) * 37, _rock_tex)
	var scene: PackedScene = load(BASE + file + ".glb")
	var root := scene.instantiate()
	var parts: Array = []
	var box := AABB()
	var first := true
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var xf := _rel_transform(mi, root)
		var ab: AABB = xf * mi.mesh.get_aabb()
		box = ab if first else box.merge(ab)
		first = false
		parts.append({mesh = mi.mesh, xf = xf, node = mi})
	var norm := Transform3D.IDENTITY.scaled(Vector3.ONE / box.size.y)
	norm = norm * Transform3D(Basis.IDENTITY, -Vector3(box.get_center().x, box.position.y, box.get_center().z))
	var out_parts: Array = []
	for p in parts:
		out_parts.append({mesh = _with_materials(p.mesh, p.node, grow), xf = norm * p.xf})
	root.free()
	return {parts = out_parts, width = maxf(box.size.x, box.size.z) / box.size.y}


func _rel_transform(n: Node3D, root: Node) -> Transform3D:
	var xf := n.transform
	var p := n.get_parent()
	while p != null and p != root:
		if p is Node3D:
			xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf


## Заменяем материалы модели нашим шейдером (с теми же базовыми цветами)
func _with_materials(mesh: Mesh, node: MeshInstance3D, grow := false) -> Mesh:
	var m: Mesh = mesh.duplicate()
	for i in m.get_surface_count():
		var src: Material = node.get_surface_override_material(i)
		if src == null:
			src = mesh.surface_get_material(i)
		var col := Color(0.5, 0.5, 0.5)
		var mname := ""
		if src is BaseMaterial3D:
			col = (src as BaseMaterial3D).albedo_color
		if src != null:
			mname = src.resource_name.to_lower()
		var kind := 0
		if "rock" in mname or "stone" in mname:
			kind = 1
		elif "wood" in mname or "bark" in mname or "trunk" in mname:
			kind = 2
		var sm := ShaderMaterial.new()
		sm.shader = preload("res://shaders/foliage.gdshader")
		sm.set_shader_parameter("albedo", Color(col.r, col.g, col.b))
		sm.set_shader_parameter("kind", kind)
		sm.set_shader_parameter("rock_tex", _rock_tex)
		sm.set_shader_parameter("grow", 1 if grow else 0)
		m.surface_set_material(i, sm)
	return m


func build(cast_shadows: bool) -> void:
	_rng.seed = 2024
	_forest.seed = 51
	_forest.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_forest.frequency = 0.045
	_forest.fractal_octaves = 3
	_rock_tex = load("res://assets/textures/ground/Rock030_color.jpg")

	var models := _models
	for kind in _kinds():
		for f in kind.files:
			if not models.has(f):
				models[f] = _load_model(f)

		# по файлу модели → по участку → список (transform, custom)
		var buckets := {}
		var placed := 0
		var attempts := 0
		while placed < kind.count and attempts < kind.count * 30:
			attempts += 1
			var a := _rng.randf() * TAU
			var d := sqrt(_rng.randf()) * (Terrain.ISLAND_RADIUS + 2.0)
			var x := cos(a) * d
			var z := sin(a) * d
			var h := Terrain.height_at(x, z)
			if h < Terrain.WATER_LEVEL + 0.3:
				continue
			if not kind.where.call(x, z):
				continue
			var file: String = kind.files[_rng.randi() % kind.files.size()]
			var model: Dictionary = models[file]
			var height: float = lerpf(kind.h[0], kind.h[1], _rng.randf())
			var collide: float = kind.collide
			var radius := maxf(0.3, model.width * height * (collide if collide > 0.0 else 0.15))
			var blocked := false
			for ex in exclusions:
				if Vector2(ex.x - x, ex.y - z).length() < ex.z:
					blocked = true
			if blocked or ForestLayout.region_factor(x, z) > 0.3 or ForestLayout.trail_dist(x, z) < 1.8 or _occupied(x, z, radius):
				continue
			_occupy(x, z, radius)
			if collide > 0.0:
				colliders.append(Vector3(x, z, radius))

			var tilt: float = kind.get("tilt", 0.15)
			var n := Terrain.normal_at(x, z)
			var up := (Vector3.UP + n * tilt).normalized()
			var b := Basis(Quaternion(Vector3.UP, up))
			b = b * Basis(Vector3.UP, _rng.randf() * TAU)
			if kind.has("tilt"):
				b = b * Basis.from_euler(Vector3(_rng.randf_range(-0.5, 0.5) * tilt, 0, _rng.randf_range(-0.5, 0.5) * tilt))
			var s := height * _rng.randf_range(0.9, 1.1)
			b = b.scaled(Vector3(s * _rng.randf_range(0.85, 1.15), s, s * _rng.randf_range(0.85, 1.15)))
			var sink: float = kind.get("sink", 0.08)
			var base_y := h - sink * height
			var xf := Transform3D(b, Vector3(x, base_y, z))
			var key := "%s|%d:%d" % [file, floori(x / CHUNK), floori(z / CHUNK)]
			if not buckets.has(key):
				buckets[key] = {file = file, items = []}
			buckets[key].items.append([xf, Color(base_y, s, _rng.randf(), 0.0)])
			placed += 1

		for key in buckets:
			var bucket: Dictionary = buckets[key]
			var model: Dictionary = models[bucket.file]
			for part in model.parts:
				var mm := MultiMesh.new()
				mm.transform_format = MultiMesh.TRANSFORM_3D
				mm.use_custom_data = true
				mm.mesh = part.mesh
				mm.instance_count = bucket.items.size()
				for i in bucket.items.size():
					var it: Array = bucket.items[i]
					mm.set_instance_transform(i, it[0] * part.xf)
					mm.set_instance_custom_data(i, it[1])
				var mmi := MultiMeshInstance3D.new()
				mmi.multimesh = mm
				mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if (cast_shadows and kind.shadow and part.get("shadow", true)) else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				if part.has("range"):
					var rg: Vector2 = part.range
					mmi.visibility_range_begin = rg.x
					if rg.y > 0.0:
						mmi.visibility_range_end = rg.y
				add_child(mmi)


## Цветы, которые распускаются, когда до них доходит волна оживания маяка
func build_bloom(center: Vector3, radius: float, count: int) -> Node3D:
	var root := Node3D.new()
	root.name = "Bloom"
	root.top_level = true
	var rng := RandomNumberGenerator.new()
	rng.seed = int(center.x * 100.0 + center.z)
	var models: Array = [_load_model("Flowers", true)]
	for c in [Color(0.97, 0.95, 0.9), Color(0.98, 0.72, 0.8), Color(0.78, 0.7, 0.95), Color(1.0, 0.88, 0.45), Color(0.7, 0.84, 1.0)]:
		models.append({parts = [{mesh = _flower_mesh(c), xf = Transform3D.IDENTITY}], width = 0.6})
	var buckets: Array = []
	for m in models:
		buckets.append([])
	var placed := 0
	var tries := 0
	while placed < count and tries < count * 20:
		tries += 1
		var a := rng.randf() * TAU
		var d := sqrt(rng.randf()) * radius
		var x := center.x + cos(a) * d
		var z := center.z + sin(a) * d
		var h := Terrain.height_at(x, z)
		if h < 0.4 or Terrain.weights_at(x, z).x < 0.25:
			continue
		if Vector2(x - center.x, z - center.z).length() < 2.2:
			continue
		var blocked := false
		for c in colliders:
			if Vector2(c.x - x, c.y - z).length() < c.z + 0.2:
				blocked = true
				break
		if blocked:
			continue
		var mi := 0 if rng.randf() < 0.3 else 1 + rng.randi() % (models.size() - 1)
		var s := rng.randf_range(0.42, 0.7) if mi > 0 else rng.randf_range(0.45, 0.7)
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s))
		b = b.rotated(Vector3.RIGHT, rng.randf_range(-0.12, 0.12))
		buckets[mi].append([Transform3D(b, Vector3(x, h - 0.02, z)), Color(h - 0.02, s, x, z)])
		placed += 1
	for i in models.size():
		if buckets[i].is_empty():
			continue
		for part in models[i].parts:
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_custom_data = true
			mm.mesh = part.mesh
			mm.instance_count = buckets[i].size()
			for k in buckets[i].size():
				mm.set_instance_transform(k, buckets[i][k][0] * part.xf)
				mm.set_instance_custom_data(k, buckets[i][k][1])
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(mmi)
	return root


## Простой цветок высотой 1: стебель, пять лепестков, серединка
func _flower_mesh(petal: Color) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	_add_surface(mesh, _stem_arrays(), Color(0.2, 0.42, 0.12))
	_add_surface(mesh, _petal_arrays(), petal)
	_add_surface(mesh, _center_arrays(), Color(1.0, 0.78, 0.25))
	return mesh


func _add_surface(mesh: ArrayMesh, verts: PackedVector3Array, col: Color) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for v in verts:
		st.add_vertex(v)
	st.generate_normals()
	st.index()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, st.commit_to_arrays())
	var sm := ShaderMaterial.new()
	sm.shader = preload("res://shaders/foliage.gdshader")
	sm.set_shader_parameter("albedo", col)
	sm.set_shader_parameter("kind", 3)
	sm.set_shader_parameter("grow", 1)
	mesh.surface_set_material(mesh.get_surface_count() - 1, sm)


func _stem_arrays() -> PackedVector3Array:
	var w := 0.035
	var a := PackedVector3Array()
	for side in [Vector3(w, 0, 0), Vector3(0, 0, w)]:
		a.append_array([-side, side, side + Vector3(0, 0.88, 0), -side, side + Vector3(0, 0.88, 0), -side + Vector3(0, 0.88, 0)])
		a.append_array([side, -side, -side + Vector3(0, 0.88, 0), side, -side + Vector3(0, 0.88, 0), side + Vector3(0, 0.88, 0)])
	return a


func _petal_arrays() -> PackedVector3Array:
	var a := PackedVector3Array()
	var c := Vector3(0, 0.9, 0)
	for i in 5:
		var ang := i * TAU / 5.0
		var dir := Vector3(cos(ang), 0.28, sin(ang))
		var side := Vector3(-sin(ang), 0, cos(ang)) * 0.11
		var tip := c + dir * 0.32
		var mid := c + dir * 0.16
		a.append_array([c, mid + side, tip, c, tip, mid - side])
		a.append_array([c, tip, mid + side, c, mid - side, tip])
	return a


func _center_arrays() -> PackedVector3Array:
	var a := PackedVector3Array()
	var c := Vector3(0, 0.95, 0)
	for i in 6:
		var a0 := i * TAU / 6.0
		var a1 := (i + 1) * TAU / 6.0
		a.append_array([c + Vector3(0, 0.03, 0), c + Vector3(cos(a1), 0, sin(a1)) * 0.07, c + Vector3(cos(a0), 0, sin(a0)) * 0.07])
	return a



## Шепчущий лес: высокие ели стеной, подлесок, папоротники, валежник, замшелые камни.
## Тропы и поляны свободны. Деревья в глубине леса — без препятствий для героя
## (там и так можно ходить только по тропам), на опушке — с препятствиями.
func build_forest(cast_shadows: bool) -> void:
	var c := ForestLayout.CENTER
	var R := ForestLayout.RADIUS + 3.0
	var kinds := [
		{files = ["PineTree_1", "PineTree_2", "PineTree_3", "PineTree_4", "PineTree_5"], h = [7.0, 11.0], count = 620, collide = 0.07, gap = 1.6, shadow = true},
		{files = ["CommonTree_1", "CommonTree_3", "CommonTree_4"], h = [6.0, 9.0], count = 50, collide = 0.07, gap = 1.6, shadow = true},
		{files = ["CommonTree_Dead_1", "BirchTree_Dead_2", "CommonTree_Dead_3"], h = [5.0, 8.0], count = 30, collide = 0.06, gap = 1.4, shadow = true},
		{files = ["Rock_Moss_1", "Rock_Moss_2", "Rock_Moss_4", "Rock_Moss_6"], h = [0.6, 2.0], count = 90, collide = 0.35, gap = 0.4, sink = 0.15, tilt = 0.3, shadow = true},
		{files = ["TreeStump_Moss", "WoodLog_Moss"], h = [0.5, 0.9], count = 70, collide = 0.3, gap = 0.4, sink = 0.05, shadow = true},
		{files = ["Bush_1", "Bush_2"], h = [0.8, 1.6], count = 420, collide = 0.0, gap = 0.6, sink = 0.05, shadow = false},
		{files = ["Plant_1", "Plant_2", "Plant_3", "Plant_5"], h = [0.5, 1.1], count = 700, collide = 0.0, gap = 0.15, shadow = false},
	]
	_rng.seed = 777
	for kind in kinds:
		for f in kind.files:
			if not _models.has(f):
				_models[f] = _load_model(f)
		var buckets := {}
		var placed := 0
		var attempts := 0
		while placed < kind.count and attempts < kind.count * 25:
			attempts += 1
			var a := _rng.randf() * TAU
			var d := sqrt(_rng.randf()) * R
			var x := c.x + cos(a) * d
			var z := c.y + sin(a) * d
			var h := Terrain.height_at(x, z)
			if h < Terrain.WATER_LEVEL + 0.3:
				continue
			# у троп и на полянах — пусто; папоротники можно ближе к краю тропы
			if ForestLayout.path_dist(x, z) < kind.gap or ForestLayout.trail_dist(x, z) < 1.8:
				continue
			var file: String = kind.files[_rng.randi() % kind.files.size()]
			var model: Dictionary = _models[file]
			var height: float = lerpf(kind.h[0], kind.h[1], _rng.randf())
			var collide: float = kind.collide
			var radius := maxf(0.25, model.width * height * (collide if collide > 0.0 else 0.12))
			if collide > 0.0 and _occupied(x, z, radius):
				continue
			if collide > 0.0:
				_occupy(x, z, radius)
				if not ForestLayout.in_core(x, z):
					colliders.append(Vector3(x, z, radius))
			var tilt: float = kind.get("tilt", 0.12)
			var n := Terrain.normal_at(x, z)
			var b := Basis(Quaternion(Vector3.UP, (Vector3.UP + n * tilt).normalized()))
			b = b * Basis(Vector3.UP, _rng.randf() * TAU)
			var s := height * _rng.randf_range(0.9, 1.1)
			b = b.scaled(Vector3(s * _rng.randf_range(0.85, 1.15), s, s * _rng.randf_range(0.85, 1.15)))
			var sink: float = kind.get("sink", 0.06)
			var base_y := h - sink * height
			# тени отбрасывают только деревья у троп — в глубине чащи их тени всё равно не видны
			var casts: bool = kind.shadow and ForestLayout.path_dist(x, z) < 4.5
			var key := "%s|%d:%d|%s" % [file, floori(x / CHUNK), floori(z / CHUNK), casts]
			if not buckets.has(key):
				buckets[key] = {file = file, items = [], casts = casts}
			buckets[key].items.append([Transform3D(b, Vector3(x, base_y, z)), Color(base_y, s, _rng.randf(), 0.0)])
			placed += 1
		for key in buckets:
			var bucket: Dictionary = buckets[key]
			for part in _models[bucket.file].parts:
				var mm := MultiMesh.new()
				mm.transform_format = MultiMesh.TRANSFORM_3D
				mm.use_custom_data = true
				mm.mesh = part.mesh
				mm.instance_count = bucket.items.size()
				for i in bucket.items.size():
					mm.set_instance_transform(i, bucket.items[i][0] * part.xf)
					mm.set_instance_custom_data(i, bucket.items[i][1])
				var mmi := MultiMeshInstance3D.new()
				mmi.multimesh = mm
				mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if (cast_shadows and bucket.casts and part.get("shadow", true)) else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				mmi.visibility_range_end = 70.0
				if part.has("range"):
					var rg: Vector2 = part.range
					mmi.visibility_range_begin = rg.x
					if rg.y > 0.0:
						mmi.visibility_range_end = rg.y
				add_child(mmi)



## Топь: мёртвые ивы и деревья на кочках, полузатопленные брёвна, кувшинки на мелководье.
## Цветы кувшинок распускаются, когда до них доходит оживание маяка.
func build_swamp(cast_shadows: bool) -> void:
	var c := SwampLayout.CENTER
	var R := SwampLayout.RADIUS
	_rng.seed = 919
	var kinds := [
		{files = ["Willow_Dead_1", "Willow_Dead_2", "Willow_Dead_3", "Willow_Dead_4", "Willow_Dead_5"], h = [4.0, 7.5], count = 70, collide = 0.06, hmin = -0.25, hmax = 2.0, shadow = true, sink = 0.04},
		{files = ["CommonTree_Dead_2", "CommonTree_Dead_4", "BirchTree_Dead_2"], h = [3.5, 6.0], count = 30, collide = 0.06, hmin = -0.1, hmax = 2.0, shadow = true, sink = 0.04},
		{files = ["WoodLog", "TreeStump_Moss"], h = [0.4, 0.8], count = 30, collide = 0.0, hmin = -0.6, hmax = 0.4, shadow = false, sink = 0.35, tilt = 0.4},
		{files = ["Lilypad"], h = [0.05, 0.12], count = 420, collide = 0.0, hmin = -1.2, hmax = -0.15, shadow = false, water = true},
	]
	for kind in kinds:
		for f in kind.files:
			if not _models.has(f):
				_models[f] = _load_model(f)
		var buckets := {}
		var placed := 0
		var attempts := 0
		while placed < kind.count and attempts < kind.count * 30:
			attempts += 1
			var a := _rng.randf() * TAU
			var d := sqrt(_rng.randf()) * R
			var x := c.x + cos(a) * d
			var z := c.y + sin(a) * d
			var h := Terrain.height_at(x, z)
			if h < kind.hmin or h > kind.hmax:
				continue
			if SwampLayout.walk_dist(x, z) < 1.6 or Vector2(x, z).distance_to(SwampLayout.pier_a()) < 4.0 or Vector2(x, z).distance_to(SwampLayout.pier_b()) < 4.0:
				continue
			if Vector2(x, z).distance_to(SwampLayout.BEACON) < SwampLayout.BEACON_R + 0.5 or Vector2(x, z).distance_to(SwampLayout.HUT) < 3.5 or Vector2(x, z).distance_to(SwampLayout.HOUSE) < 3.5:
				continue
			var file: String = kind.files[_rng.randi() % kind.files.size()]
			var model: Dictionary = _models[file]
			var height: float = lerpf(kind.h[0], kind.h[1], _rng.randf())
			var radius := maxf(0.3, model.width * height * (kind.collide if kind.collide > 0.0 else 0.2))
			if kind.collide > 0.0:
				if _occupied(x, z, radius):
					continue
				_occupy(x, z, radius)
				colliders.append(Vector3(x, z, radius))
			var b := Basis(Vector3.UP, _rng.randf() * TAU)
			var tilt: float = kind.get("tilt", 0.0)
			if tilt > 0.0:
				b = b * Basis.from_euler(Vector3(_rng.randf_range(-tilt, tilt), 0, _rng.randf_range(-tilt, tilt)))
			var s := height
			var base_y: float = h - kind.get("sink", 0.05) * height
			if kind.get("water", false):
				# кувшинка: широкая и плоская, на поверхности воды
				s = _rng.randf_range(0.7, 1.4) / maxf(model.width, 0.01) # ширина s метров, пропорции как у модели
				b = b.scaled(Vector3(s, s, s))
				base_y = 0.01
			else:
				b = b.scaled(Vector3(s, s, s))
			var key := "%s|%d:%d" % [file, floori(x / CHUNK), floori(z / CHUNK)]
			if not buckets.has(key):
				buckets[key] = {file = file, items = []}
			buckets[key].items.append([Transform3D(b, Vector3(x, base_y, z)), Color(base_y, s if not kind.get("water", false) else 0.1, x, z)])
			placed += 1
		for key in buckets:
			var bucket: Dictionary = buckets[key]
			for part in _models[bucket.file].parts:
				var mm := MultiMesh.new()
				mm.transform_format = MultiMesh.TRANSFORM_3D
				mm.use_custom_data = true
				mm.mesh = part.mesh
				mm.instance_count = bucket.items.size()
				for i in bucket.items.size():
					var xf: Transform3D = bucket.items[i][0]
					mm.set_instance_transform(i, xf * part.xf)
					mm.set_instance_custom_data(i, bucket.items[i][1])
				var mmi := MultiMeshInstance3D.new()
				mmi.multimesh = mm
				mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if (cast_shadows and kind.shadow and part.get("shadow", true)) else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				mmi.visibility_range_end = 70.0
				if part.has("range"):
					var rg: Vector2 = part.range
					mmi.visibility_range_begin = rg.x
					if rg.y > 0.0:
						mmi.visibility_range_end = rg.y
				add_child(mmi)
	# цветы кувшинок: распускаются после маяка (grow)
	var flower := _flower_mesh(Color(0.98, 0.78, 0.86))
	var fx: Array = []
	var tries := 0
	while fx.size() < 140 and tries < 5000:
		tries += 1
		var a := _rng.randf() * TAU
		var d := sqrt(_rng.randf()) * R
		var x := c.x + cos(a) * d
		var z := c.y + sin(a) * d
		var h := Terrain.height_at(x, z)
		if h < -1.2 or h > -0.2 or SwampLayout.walk_dist(x, z) < 1.4:
			continue
		var s := _rng.randf_range(0.35, 0.5)
		fx.append([Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s * 1.4, s * 0.35, s * 1.4)), Vector3(x, -0.25, z)), Color(-0.25, s, x, z)])
	var fm := MultiMesh.new()
	fm.transform_format = MultiMesh.TRANSFORM_3D
	fm.use_custom_data = true
	fm.mesh = flower
	fm.instance_count = fx.size()
	for i in fx.size():
		fm.set_instance_transform(i, fx[i][0])
		fm.set_instance_custom_data(i, fx[i][1])
	var fmi := MultiMeshInstance3D.new()
	fmi.multimesh = fm
	fmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(fmi)
