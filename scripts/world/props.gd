class_name Props
extends RefCounted
## Загрузка построек и вещей (CC0, Quaternius) с нашим материалом:
## каменные стены — текстура камня, дерево — волокна, окна — тёплый свет.

const BASE := "res://assets/models/"

static var _rock_tex: Texture2D
static var _cache := {} # путь → {parts, size}


## Модель как узел: высота = h (или ширина = w), основание на y = 0, центр по x/z в 0
static func make(path: String, h := 0.0, w := 0.0) -> Node3D:
	if _rock_tex == null:
		_rock_tex = load("res://assets/textures/ground/Rock030_color.jpg")
	if not _cache.has(path):
		_cache[path] = _load(path)
	var data: Dictionary = _cache[path]
	var size: Vector3 = data.size
	var s := h / size.y if h > 0.0 else w / maxf(size.x, size.z)
	var root := Node3D.new()
	root.name = path.get_file().get_basename()
	for p in data.parts:
		var mi := MeshInstance3D.new()
		mi.mesh = p.mesh
		mi.transform = Transform3D.IDENTITY.scaled(Vector3.ONE * s) * p.xf
		root.add_child(mi)
	root.set_meta("height", size.y * s)
	root.set_meta("size", size * s)
	return root


## После установки на место — сообщаем материалу высоту основания (для затенения у земли)
static func settle(n: Node3D) -> void:
	var h: float = n.get_meta("height", 1.0)
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		(mi as GeometryInstance3D).set_instance_shader_parameter("base_h", Vector2(n.global_position.y, h))


static func _load(path: String) -> Dictionary:
	var scene: PackedScene = load(BASE + path)
	var root := scene.instantiate()
	var parts: Array = []
	var box := AABB()
	var first := true
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		var xf := _rel(mi, root)
		var ab: AABB = xf * mi.mesh.get_aabb()
		box = ab if first else box.merge(ab)
		first = false
		parts.append({mesh = _convert(mi), xf = xf})
	var norm := Transform3D(Basis.IDENTITY, -Vector3(box.get_center().x, box.position.y, box.get_center().z))
	for p in parts:
		p.xf = norm * p.xf
	root.free()
	return {parts = parts, size = box.size}


static func _rel(n: Node3D, root: Node) -> Transform3D:
	var xf := n.transform
	var p := n.get_parent()
	while p != null and p != root:
		if p is Node3D:
			xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf


static func _convert(mi: MeshInstance3D) -> Mesh:
	var m: Mesh = mi.mesh.duplicate()
	for i in m.get_surface_count():
		var src: Material = mi.get_surface_override_material(i)
		if src == null:
			src = mi.mesh.surface_get_material(i)
		var col := Color(0.5, 0.5, 0.5)
		var mname := ""
		if src is BaseMaterial3D:
			col = (src as BaseMaterial3D).albedo_color
		if src != null:
			mname = src.resource_name.to_lower()
		var kind := 0
		if "window" in mname or "glass" in mname:
			kind = 5
		elif "stone" in mname or "rock" in mname:
			kind = 1
		elif "wood" in mname:
			kind = 2
		var sm := ShaderMaterial.new()
		sm.shader = preload("res://shaders/foliage.gdshader")
		sm.set_shader_parameter("albedo", Color(col.r, col.g, col.b))
		sm.set_shader_parameter("kind", kind)
		sm.set_shader_parameter("wind_sway", false)
		sm.set_shader_parameter("rock_tex", _rock_tex)
		m.surface_set_material(i, sm)
	return m


## Перед выходом из игры — отпустить ресурсы (иначе движок падает при закрытии)
static func clear() -> void:
	_cache.clear()
	_rock_tex = null
