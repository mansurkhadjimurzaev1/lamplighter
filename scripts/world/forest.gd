class_name Forest
extends Node3D
## Шепчущий лес: светящиеся грибы, лунные лучи, светлячки-проводники,
## хижина травника Вейла с костерком и сушилкой для трав.

const GUIDES := 34
const GUIDE_SPEED := 1.15

var hut_node: Node3D # хижина Вейла (дверь — вход в дом)
var _route := PackedVector2Array()
var _route_len := 0.0
var _seg_len: Array[float] = []
var _guides: MultiMesh
var _guide_s: Array[float] = []
var _t := 0.0
var _rng := RandomNumberGenerator.new()
var colliders: Array[Vector3] = []


func build() -> void:
	name = "Forest"
	_rng.seed = 4242
	_mushrooms()
	_beams()
	_guide_fireflies()
	_hut()
	_markers()


func _at(local: Vector2, lift := 0.0) -> Vector3:
	var w := ForestLayout.world(local)
	return Vector3(w.x, Terrain.height_at(w.x, w.y) + lift, w.y)


# ── светящиеся грибы ────────────────────────────────────────

func _mushroom_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg := 7
	# ножка
	for i in seg:
		var a0 := i * TAU / seg
		var a1 := (i + 1) * TAU / seg
		var r := 0.06
		var p := [Vector3(cos(a0) * r, 0, sin(a0) * r), Vector3(cos(a1) * r, 0, sin(a1) * r), Vector3(cos(a1) * r * 0.8, 0.5, sin(a1) * r * 0.8), Vector3(cos(a0) * r * 0.8, 0.5, sin(a0) * r * 0.8)]
		for v in [0, 1, 2, 0, 2, 3]:
			st.set_color(Color(0, 0, 0))
			st.add_vertex(p[v])
	# шляпка — пологий конус
	for i in seg:
		var a0 := i * TAU / seg
		var a1 := (i + 1) * TAU / seg
		var r := 0.24
		var top := Vector3(0, 0.66, 0)
		var p0 := Vector3(cos(a0) * r, 0.48, sin(a0) * r)
		var p1 := Vector3(cos(a1) * r, 0.48, sin(a1) * r)
		for v in [top, p1, p0, Vector3(0, 0.5, 0), p0, p1]:
			st.set_color(Color(1, 0, 0))
			st.add_vertex(v)
	st.generate_normals()
	return st.commit()


func _mushrooms() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _mushroom_mesh()
	var xfs: Array[Transform3D] = []
	var c := ForestLayout.CENTER
	var clusters := 0
	var tries := 0
	while clusters < 120 and tries < 3000:
		tries += 1
		var a := _rng.randf() * TAU
		var d := sqrt(_rng.randf()) * ForestLayout.RADIUS
		var x := c.x + cos(a) * d
		var z := c.y + sin(a) * d
		var pd := ForestLayout.path_dist(x, z)
		if pd < 0.3 or pd > 5.0 or Terrain.height_at(x, z) < 0.5:
			continue
		clusters += 1
		for k in _rng.randi_range(2, 6):
			var px := x + _rng.randf_range(-0.6, 0.6)
			var pz := z + _rng.randf_range(-0.6, 0.6)
			var s := _rng.randf_range(0.4, 0.95)
			var b := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s, s * _rng.randf_range(0.8, 1.3), s))
			b = b.rotated(Vector3(1, 0, 0), _rng.randf_range(-0.2, 0.2))
			xfs.append(Transform3D(b, Vector3(px, Terrain.height_at(px, pz) - 0.02, pz)))
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/mushroom.gdshader")
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


# ── лунные лучи ─────────────────────────────────────────────

func _beams() -> void:
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	q.center_offset = Vector3(0, 0.5, 0)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/beam.gdshader")
	for b in ForestLayout.BEAMS:
		var mi := MeshInstance3D.new()
		mi.mesh = q
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		var base := _at(b, -0.5)
		# луч наклонён — луна светит сбоку
		var basis := Basis(Vector3(0, 0, 1), deg_to_rad(_rng.randf_range(10.0, 18.0))).rotated(Vector3.UP, deg_to_rad(-35.0))
		basis = basis.scaled(Vector3(_rng.randf_range(1.4, 2.6), _rng.randf_range(13.0, 18.0), 1.0))
		mi.global_transform = Transform3D(basis, base)
		mi.custom_aabb = AABB(Vector3(-3, -1, -3), Vector3(6, 22, 6))


# ── светлячки-проводники ─────────────────────────────────────

func _guide_fireflies() -> void:
	_route = ForestLayout.route_points()
	_route_len = 0.0
	for i in _route.size() - 1:
		var l := _route[i].distance_to(_route[i + 1])
		_seg_len.append(l)
		_route_len += l
	_guides = MultiMesh.new()
	_guides.transform_format = MultiMesh.TRANSFORM_3D
	_guides.use_custom_data = true
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	_guides.mesh = q
	_guides.instance_count = GUIDES
	for i in GUIDES:
		_guide_s.append(_route_len * i / GUIDES + _rng.randf() * 1.5)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = _guides
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/guide.gdshader")
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.custom_aabb = AABB(Vector3(-200, -50, -200), Vector3(400, 100, 400))
	add_child(mmi)


func _route_at(s: float) -> Vector3:
	s = fmod(s, _route_len)
	for i in _seg_len.size():
		if s <= _seg_len[i]:
			var p := _route[i].lerp(_route[i + 1], s / _seg_len[i])
			return Vector3(p.x, Terrain.height_at(p.x, p.y), p.y)
		s -= _seg_len[i]
	var e := _route[_route.size() - 1]
	return Vector3(e.x, Terrain.height_at(e.x, e.y), e.y)


## Проводники видны, пока маяк леса не зажжён, и только рядом с героем
func update_forest(dt: float, hero: Vector3, beacon_lit: bool) -> void:
	_t += dt
	for i in GUIDES:
		_guide_s[i] += dt * GUIDE_SPEED * (0.85 + 0.3 * sin(i * 1.7))
		var p := _route_at(_guide_s[i])
		# покачиваются над тропой
		p += Vector3(sin(_t * 1.3 + i) * 0.5, 0.9 + sin(_t * 1.9 + i * 2.3) * 0.35, cos(_t * 1.1 + i) * 0.5)
		var d := Vector2(p.x - hero.x, p.z - hero.z).length()
		var vis := (1.0 - Terrain.ss(7.0, 15.0, d)) * (0.0 if beacon_lit else 1.0)
		# у самого конца пути гаснут
		var s := fmod(_guide_s[i], _route_len)
		vis *= Terrain.ss(0.0, 3.0, s) * (1.0 - Terrain.ss(_route_len - 4.0, _route_len, s))
		_guides.set_instance_transform(i, Transform3D(Basis.IDENTITY, p))
		_guides.set_instance_custom_data(i, Color(vis, float(i) / GUIDES, 0, 0))


# ── хижина травника ─────────────────────────────────────────

func _mat(c: Color, rough := 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m


func _hut() -> void:
	var v := ForestLayout.N["V"]
	var hut := Props.make("village/House_4.glb", 3.8)
	add_child(hut)
	hut_node = hut
	hut.global_position = _at(v + Vector2(-3.2, -1.5), -0.05)
	hut.rotation.y = deg_to_rad(60)
	Props.settle(hut)
	var hp := ForestLayout.world(v + Vector2(-3.2, -1.5))
	colliders.append(Vector3(hp.x, hp.y, 2.0))
	# костерок
	var fire := Node3D.new()
	add_child(fire)
	fire.global_position = _at(v + Vector2(1.0, 1.0))
	for k in 7:
		var st := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.1
		cm.bottom_radius = 0.12
		cm.height = 0.18
		st.mesh = cm
		st.material_override = _mat(Color(0.35, 0.34, 0.33))
		st.position = Vector3(cos(k * TAU / 7) * 0.45, 0.06, sin(k * TAU / 7) * 0.45)
		fire.add_child(st)
	var flames := Fx.flames()
	flames.amount = 20
	flames.scale = Vector3.ONE * 0.55
	flames.position.y = 0.15
	fire.add_child(flames)
	var embers := Fx.embers(10)
	embers.position.y = 0.2
	fire.add_child(embers)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.55, 0.25)
	l.light_energy = 1.8
	l.omni_range = 7.0
	l.position.y = 0.8
	l.light_volumetric_fog_energy = 1.2
	fire.add_child(l)
	var fp := ForestLayout.world(v + Vector2(1.0, 1.0))
	colliders.append(Vector3(fp.x, fp.y, 0.6))
	# сушилка для трав: перекладина на двух жердях, на ней пучки
	var rack := Node3D.new()
	add_child(rack)
	rack.global_position = _at(v + Vector2(2.6, -1.8))
	rack.rotation.y = deg_to_rad(25)
	var wood := _mat(Color(0.3, 0.2, 0.12))
	for sx in [-0.9, 0.9]:
		var pole := MeshInstance3D.new()
		var pm := CylinderMesh.new()
		pm.top_radius = 0.04
		pm.bottom_radius = 0.05
		pm.height = 1.6
		pole.mesh = pm
		pole.material_override = wood
		pole.position = Vector3(sx, 0.8, 0)
		rack.add_child(pole)
	var bar := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(2.0, 0.05, 0.05)
	bar.mesh = bm
	bar.material_override = wood
	bar.position = Vector3(0, 1.55, 0)
	rack.add_child(bar)
	for k in 7:
		var bunch := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.03
		cone.bottom_radius = 0.11
		cone.height = 0.42
		bunch.mesh = cone
		bunch.material_override = _mat([Color(0.3, 0.42, 0.18), Color(0.45, 0.42, 0.2), Color(0.38, 0.3, 0.35)][k % 3])
		bunch.position = Vector3(-0.8 + k * 0.27, 1.3, 0)
		bunch.rotation.x = PI
		rack.add_child(bunch)
	var rp := ForestLayout.world(v + Vector2(2.6, -1.8))
	colliders.append(Vector3(rp.x, rp.y, 0.9))


## Старые знаки у развилок: каменные столбики (верный путь — не по ним, а по светлячкам)
func _markers() -> void:
	for id in ["J1", "J2", "J3"]:
		var m := Props.make("nature/Rock_Moss_2.glb", 1.0)
		add_child(m)
		var p: Vector2 = ForestLayout.N[id] + Vector2(2.6, 1.6)
		m.global_position = _at(p, -0.1)
		m.rotation.y = _rng.randf() * TAU
		Props.settle(m)
