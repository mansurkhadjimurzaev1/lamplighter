class_name Vegetation
extends Node3D
## Деревья, камни, кусты (CC0, Quaternius). Рисуются через MultiMesh:
## сотни объектов за несколько вызовов отрисовки. Разбиты на участки 16×16 м,
## чтобы камера и тени фонаря обрабатывали только ближние.

const CHUNK := 16.0
const BASE := "res://assets/models/nature/"

## Круги, через которые нельзя пройти: Vector3(x, z, радиус)
var colliders: Array[Vector3] = []

var _rng := RandomNumberGenerator.new()
var _forest := FastNoiseLite.new()
var _rock_tex: Texture2D


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
func _load_model(file: String) -> Dictionary:
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
		out_parts.append({mesh = _with_materials(p.mesh, p.node), xf = norm * p.xf})
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
func _with_materials(mesh: Mesh, node: MeshInstance3D) -> Mesh:
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
		m.surface_set_material(i, sm)
	return m


func build(cast_shadows: bool) -> void:
	_rng.seed = 2024
	_forest.seed = 51
	_forest.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_forest.frequency = 0.045
	_forest.fractal_octaves = 3
	_rock_tex = load("res://assets/textures/ground/Rock030_color.jpg")

	var models := {}
	var occupied: Array[Vector3] = []
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
			for c in occupied:
				if Vector2(c.x - x, c.y - z).length() < c.z + radius:
					blocked = true
					break
			if blocked:
				continue
			occupied.append(Vector3(x, z, radius))
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
				mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if (cast_shadows and kind.shadow) else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				add_child(mmi)
