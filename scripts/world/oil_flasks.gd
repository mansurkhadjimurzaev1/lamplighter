class_name OilFlasks
extends Node3D
## Светящиеся флаконы масла, разбросанные по миру. Подбираются при подходе.

signal picked(index: int)

const PICK_RADIUS := 1.1

var _items: Array = [] # {node, index, base_y, taken}
var _sparkle: GPUParticles3D
var _t := 0.0


func build(count: int, colliders: Array[Vector3], avoid: Array[Vector3], taken: Array) -> void:
	name = "OilFlasks"
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.85, 0.9, 1.0, 0.35)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.05
	glass.metallic_specular = 1.0
	var oil := StandardMaterial3D.new()
	oil.albedo_color = Color(1.0, 0.7, 0.25)
	oil.emission_enabled = true
	oil.emission = Color(1.0, 0.6, 0.18)
	oil.emission_energy_multiplier = 4.0
	var cork := StandardMaterial3D.new()
	cork.albedo_color = Color(0.45, 0.3, 0.18)
	cork.roughness = 1.0

	var i := 0
	var tries := 0
	var placed: Array[Vector3] = []
	while i < count and tries < 4000:
		tries += 1
		var a := rng.randf() * TAU
		var d := sqrt(rng.randf()) * (Terrain.ISLAND_RADIUS - 4.0)
		var x := cos(a) * d
		var z := sin(a) * d
		var h := Terrain.height_at(x, z)
		if h < 0.5 or Vector2(x, z - 4.0).length() < 7.0:
			continue
		var ok := true
		for c in colliders + avoid:
			if Vector2(c.x - x, c.y - z).length() < c.z + 1.2:
				ok = false
				break
		for p in placed:
			if Vector2(p.x - x, p.z - z).length() < 9.0:
				ok = false
				break
		if not ok:
			continue
		placed.append(Vector3(x, h, z))
		var node := Node3D.new()
		node.position = Vector3(x, h + 0.35, z)
		add_child(node)
		_part(node, _sphere(0.11), glass, Vector3(0, 0, 0))
		_part(node, _sphere(0.085), oil, Vector3(0, -0.012, 0))
		_part(node, _cyl(0.035, 0.045, 0.12), glass, Vector3(0, 0.14, 0))
		_part(node, _cyl(0.038, 0.034, 0.05), cork, Vector3(0, 0.215, 0))
		# мягкий ореол, чтобы флакон было видно издалека во тьме
		var halo := Fx.embers(6)
		(halo.process_material as ParticleProcessMaterial).emission_sphere_radius = 0.18
		(halo.process_material as ParticleProcessMaterial).initial_velocity_max = 0.3
		(halo.process_material as ParticleProcessMaterial).gravity = Vector3(0, 0.25, 0)
		halo.position = Vector3.ZERO
		node.add_child(halo)
		var taken_already := taken.has(i)
		node.visible = not taken_already
		_items.append({node = node, index = i, base_y = h + 0.35, taken = taken_already})
		i += 1

	_sparkle = Fx.burst(40, 2.5)
	add_child(_sparkle)


func _sphere(r: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 12
	m.rings = 6
	return m


func _cyl(top: float, bottom: float, h: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = h
	m.radial_segments = 10
	return m


func _part(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


## Возвращает true, если что-то подобрали
func update_flasks(dt: float, hero_pos: Vector3) -> bool:
	_t += dt
	var got := false
	for it in _items:
		if it.taken:
			continue
		var n: Node3D = it.node
		n.position.y = it.base_y + sin(_t * 1.6 + it.index) * 0.06
		n.rotation.y += dt * 0.6
		if Vector2(n.position.x - hero_pos.x, n.position.z - hero_pos.z).length() < PICK_RADIUS:
			it.taken = true
			n.visible = false
			_sparkle.global_position = n.global_position
			_sparkle.restart()
			_sparkle.emitting = true
			picked.emit(it.index)
			got = true
	return got


func taken_indices() -> Array:
	var out := []
	for it in _items:
		if it.taken:
			out.append(it.index)
	return out
