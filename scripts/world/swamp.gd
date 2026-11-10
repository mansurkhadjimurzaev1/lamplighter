class_name Swamp
extends Node3D
## Топь: тёмная вода с отражениями, гнилые мостки, камыши, зелёная дымка,
## блуждающие огни над трясинами, хижина паромщика, лодка, стрекозы после маяка.

const WISP_FAR := 14.0

var colliders: Array[Vector3] = []
var probe: ReflectionProbe
var boat: Node3D
var boat_at_a := true
var _rng := RandomNumberGenerator.new()
var _wisps: Array = [] # {node, light, home, r, pos, fade, hidden}
var _t := 0.0
var _ferry_t := -1.0
var _ferry_from := Vector3.ZERO
var _ferry_to := Vector3.ZERO
var _probe_refresh := 0


func build() -> void:
	name = "Swamp"
	_rng.seed = 909
	_water()
	_boardwalks()
	_reeds()
	_mist()
	_wisps_build()
	_hut()
	_boat_build()
	_dragonflies()
	probe = ReflectionProbe.new()
	probe.size = Vector3(SwampLayout.RADIUS * 2.0 + 8.0, 14.0, SwampLayout.RADIUS * 2.0 + 8.0)
	probe.box_projection = true
	probe.update_mode = ReflectionProbe.UPDATE_ONCE
	probe.max_distance = 60.0
	probe.intensity = 0.9
	add_child(probe)
	probe.global_position = Vector3(SwampLayout.CENTER.x, 4.0, SwampLayout.CENTER.y)


func _h(p: Vector2) -> float:
	return Terrain.height_at(p.x, p.y)


func _mat(c: Color, rough := 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m


# ── вода ────────────────────────────────────────────────────

func _water() -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	var R := SwampLayout.RADIUS + 3.0
	pm.size = Vector2(R * 2.0, R * 2.0)
	pm.subdivide_width = 8
	pm.subdivide_depth = 8
	mi.mesh = pm
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.04
	var tex := NoiseTexture2D.new()
	tex.width = 256
	tex.height = 256
	tex.seamless = true
	tex.as_normal_map = true
	tex.bump_strength = 3.0
	tex.noise = noise
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/swamp_water.gdshader")
	mat.set_shader_parameter("ripple", tex)
	if Args.has("norings"):
		mat.set_shader_parameter("rings_on", 0.0)
	Terrain.apply_map(mat)
	var bogs := []
	for b in SwampLayout.BOGS:
		bogs.append(Vector4(b[0].x, b[0].y, b[1], 0))
	mat.set_shader_parameter("bogs", bogs)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.global_position = Vector3(SwampLayout.CENTER.x, Terrain.WATER_LEVEL, SwampLayout.CENTER.y)
	# круг: за краем топи — обычная вода
	mat.set_shader_parameter("swamp", Vector3(SwampLayout.CENTER.x, SwampLayout.CENTER.y, SwampLayout.RADIUS + 2.0))


# ── мостки ──────────────────────────────────────────────────

func _boardwalks() -> void:
	var planks: Array[Transform3D] = []
	var posts: Array[Transform3D] = []
	for path in [SwampLayout.WALK, SwampLayout.WALK2]:
		for i in path.size() - 1:
			var a: Vector2 = path[i]
			var b: Vector2 = path[i + 1]
			var len := a.distance_to(b)
			var dir := (b - a).normalized()
			var yaw := atan2(dir.x, dir.y)
			var n := int(len / 0.42)
			for k in n:
				var p := a + dir * (k + 0.5) * len / n
				var gap := false
				for g in SwampLayout.GAPS:
					if p.distance_to(g) < 0.9:
						gap = true
				# прогнившие доски: часть выпала, часть перекошена
				if gap and _rng.randf() < 0.7:
					continue
				if _rng.randf() < 0.06:
					continue
				var y := SwampLayout.deck_height(p.x, p.y) - 0.04
				var basis := Basis(Vector3.UP, yaw)
				basis = basis.rotated(basis.z, _rng.randf_range(-0.06, 0.06) + (0.25 if gap else 0.0))
				basis = basis.rotated(Vector3.UP, _rng.randf_range(-0.05, 0.05))
				planks.append(Transform3D(basis.scaled(Vector3(_rng.randf_range(0.9, 1.1), 1, 1)), Vector3(p.x, y, p.y)))
				if k % 5 == 0:
					var side := Vector2(dir.y, -dir.x) * (SwampLayout.WALK_HALF + 0.05)
					for sgn in [-1.0, 1.0]:
						var pp: Vector2 = p + side * sgn
						var top := y + 0.25
						var bottom := Terrain.height_at(pp.x, pp.y) - 0.3
						var hgt := top - bottom
						posts.append(Transform3D(Basis.IDENTITY.rotated(Vector3(1, 0, 0), _rng.randf_range(-0.08, 0.08)).scaled(Vector3(1, hgt, 1)), Vector3(pp.x, bottom + hgt * 0.5, pp.y)))
	var wood := _mat(Color(0.2, 0.15, 0.1), 0.85)
	var pb := BoxMesh.new()
	pb.size = Vector3(SwampLayout.WALK_HALF * 2.0 + 0.2, 0.06, 0.36)
	_multi(pb, wood, planks, true)
	var cm := CylinderMesh.new()
	cm.top_radius = 0.07
	cm.bottom_radius = 0.08
	cm.height = 1.0
	cm.radial_segments = 6
	_multi(cm, _mat(Color(0.14, 0.11, 0.08)), posts, false)
	# причалы: широкие настилы у лодки
	for pier in [SwampLayout.pier_a(), SwampLayout.pier_b()]:
		var pl: Array[Transform3D] = []
		var to_other: Vector2 = (SwampLayout.pier_b() if pier == SwampLayout.pier_a() else SwampLayout.pier_a()) - pier
		var yaw := atan2(to_other.x, to_other.y)
		for k in 6:
			var p: Vector2 = pier + to_other.normalized() * (k * 0.42 - 0.6)
			pl.append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(1.4, 1, 1)), Vector3(p.x, maxf(_h(p) + 0.2, 0.32) - 0.04, p.y)))
		_multi(pb, wood, pl, true)


func _multi(mesh: Mesh, mat: Material, xfs: Array[Transform3D], shadows: bool) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


# ── камыши и рогоз ──────────────────────────────────────────

func _reeds() -> void:
	var blades: Array[Transform3D] = []
	var heads: Array[Transform3D] = []
	var tries := 0
	while blades.size() < 2600 and tries < 40000:
		tries += 1
		var a := _rng.randf() * TAU
		var d := sqrt(_rng.randf()) * SwampLayout.RADIUS
		var x := SwampLayout.CENTER.x + cos(a) * d
		var z := SwampLayout.CENTER.y + sin(a) * d
		var h := Terrain.height_at(x, z)
		if h < -0.7 or h > 0.25 or SwampLayout.walk_dist(x, z) < 1.3 or SwampLayout.bog_at(x, z) > 0.2:
			continue
		# пучок
		for k in _rng.randi_range(3, 7):
			var px := x + _rng.randf_range(-0.4, 0.4)
			var pz := z + _rng.randf_range(-0.4, 0.4)
			var hh := _rng.randf_range(1.0, 1.9)
			var b := Basis(Vector3.UP, _rng.randf() * TAU).rotated(Vector3(1, 0, 0), _rng.randf_range(-0.15, 0.15))
			var base := Vector3(px, minf(Terrain.height_at(px, pz), 0.0) - 0.1, pz)
			blades.append(Transform3D(b.scaled(Vector3(1, hh, 1)), base))
			if _rng.randf() < 0.25:
				heads.append(Transform3D(b, base + b.y * hh * 0.85))
	var blade := PrismMesh.new()
	blade.size = Vector3(0.05, 1.0, 0.02)
	blade.left_to_right = 0.5
	var reed_mat := _mat(Color(0.28, 0.32, 0.16))
	reed_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var xf_blades: Array[Transform3D] = []
	for t in blades:
		xf_blades.append(t * Transform3D(Basis.IDENTITY, Vector3(0, 0.5, 0)))
	_multi(blade, reed_mat, xf_blades, false)
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.035
	cyl.bottom_radius = 0.035
	cyl.height = 0.22
	cyl.radial_segments = 6
	_multi(cyl, _mat(Color(0.3, 0.17, 0.08)), heads, false)


# ── дымка ───────────────────────────────────────────────────

func _mist() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	mm.mesh = q
	var n := 160 if Quality.level != "low" else 70
	mm.instance_count = n
	for i in n:
		var a := _rng.randf() * TAU
		var d := sqrt(_rng.randf()) * (SwampLayout.RADIUS - 2.0)
		var x := SwampLayout.CENTER.x + cos(a) * d
		var z := SwampLayout.CENTER.y + sin(a) * d
		var s := _rng.randf_range(4.0, 8.0)
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3(s, s, s)), Vector3(x, maxf(Terrain.height_at(x, z), 0.0) + _rng.randf_range(0.4, 1.4), z)))
		mm.set_instance_custom_data(i, Color(_rng.randf() * 100.0, 0, 0, 0))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/mist.gdshader")
	Terrain.apply_map(mat)
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.custom_aabb = AABB(Vector3(-SwampLayout.RADIUS - 10, -5, -SwampLayout.RADIUS - 10) + Vector3(SwampLayout.CENTER.x, 0, SwampLayout.CENTER.y), Vector3(SwampLayout.RADIUS * 2 + 20, 15, SwampLayout.RADIUS * 2 + 20))
	add_child(mmi)


# ── блуждающие огни ─────────────────────────────────────────

func _wisps_build() -> void:
	for b in SwampLayout.BOGS:
		var node := Node3D.new()
		add_child(node)
		var glow := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(2.4, 2.4)
		glow.mesh = q
		var gm := ShaderMaterial.new()
		gm.shader = load("res://shaders/particle_glow.gdshader")
		gm.set_shader_parameter("intensity", 2.5)
		gm.set_shader_parameter("tint", Vector3(1.0, 0.75, 0.4))
		glow.material_override = gm
		glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(glow)
		var fl := Fx.flames()
		fl.amount = 18
		fl.scale = Vector3.ONE * 0.45
		fl.emitting = true
		node.add_child(fl)
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.7, 0.35)
		light.light_energy = 2.0
		light.omni_range = 9.0
		light.light_volumetric_fog_energy = 4.0
		node.add_child(light)
		var home: Vector2 = b[0]
		_wisps.append({node = node, glow = gm, light = light, home = home, r = b[1], pos = home, fade = 1.0, hidden = 0.0, flames = fl})


## Огни: издали — как огонь маяка; ближе — уплывают в трясину; в трясине — гаснут
func _update_wisps(dt: float, hero: Vector2, lit: bool) -> void:
	for w in _wisps:
		var node: Node3D = w.node
		if lit:
			w.fade = move_toward(w.fade, 0.0, dt * 0.5) # после маяка болотный газ рассеивается
		elif w.hidden > 0.0:
			w.hidden -= dt
			w.fade = move_toward(w.fade, 0.0, dt * 2.0)
			if w.hidden <= 0.0:
				w.pos = w.home
		else:
			var d: float = hero.distance_to(w.pos)
			var want: Vector2 = w.home
			if d < 7.0:
				# отплывает от героя вглубь трясины — заманивает
				var away: Vector2 = (w.pos - hero).normalized()
				want = w.home + away * w.r * 0.4
			w.pos = w.pos.lerp(want, 1.0 - exp(-dt * 0.6))
			var target_fade := lerpf(0.55, 1.0, Terrain.ss(4.0, WISP_FAR, d))
			w.fade = move_toward(w.fade, target_fade, dt)
			# герой вошёл в трясину — огонь гаснет, оставляя одного в темноте
			if SwampLayout.bog_at(hero.x, hero.y) > 0.5 and hero.distance_to(w.home) < w.r + 2.0:
				w.hidden = 12.0
		var p: Vector2 = w.pos
		node.global_position = Vector3(p.x, 1.6 + sin(_t * 1.3 + p.x) * 0.25, p.y)
		w.glow.set_shader_parameter("intensity", 2.5 * w.fade * (0.85 + 0.15 * sin(_t * 9.0 + p.y)))
		w.light.light_energy = 2.0 * w.fade
		w.light.visible = w.fade > 0.02
		w.flames.visible = w.fade > 0.3
		node.visible = w.fade > 0.01


# ── хижина паромщика ────────────────────────────────────────

func _hut() -> void:
	var p := SwampLayout.HUT + Vector2(-1.5, 1.5)
	var hut := Props.make("village/House_3.glb", 4.2)
	add_child(hut)
	hut.global_position = Vector3(p.x, _h(p) - 0.1, p.y)
	hut.rotation.y = deg_to_rad(-120)
	Props.settle(hut)
	colliders.append(Vector3(p.x, p.y, 2.0))
	for k in 3:
		var q := SwampLayout.HUT + Vector2(1.8 + k * 0.6, 2.8 - k * 0.3)
		var b := Props.make("village/Barrel.glb", 0.85)
		add_child(b)
		b.global_position = Vector3(q.x, _h(q), q.y)
		b.rotation.y = _rng.randf() * TAU
		Props.settle(b)
	colliders.append(Vector3(SwampLayout.HUT.x + 2.4, SwampLayout.HUT.y + 2.5, 0.8))
	# сеть на жердях
	var net := MeshInstance3D.new()
	var nm := QuadMesh.new()
	nm.size = Vector2(2.2, 1.2)
	net.mesh = nm
	var netmat := _mat(Color(0.35, 0.3, 0.22, 0.75))
	netmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	netmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	net.material_override = netmat
	add_child(net)
	var np := SwampLayout.HUT + Vector2(-3.5, -2.0)
	net.global_position = Vector3(np.x, _h(np) + 1.0, np.y)
	net.rotation.y = 0.6
	# гнилушка в банке у двери — зеленоватый свет (паромщик бережёт масло)
	var jar := MeshInstance3D.new()
	var jm := SphereMesh.new()
	jm.radius = 0.1
	jm.height = 0.2
	jar.mesh = jm
	var jmat := _mat(Color(0.5, 0.95, 0.6))
	jmat.emission_enabled = true
	jmat.emission = Color(0.4, 0.9, 0.55)
	jmat.emission_energy_multiplier = 3.0
	jar.material_override = jmat
	add_child(jar)
	var jp := SwampLayout.HUT + Vector2(0.4, 0.6)
	jar.global_position = Vector3(jp.x, _h(jp) + 1.0, jp.y)
	var jl := OmniLight3D.new()
	jl.light_color = Color(0.5, 0.95, 0.6)
	jl.light_energy = 0.7
	jl.omni_range = 4.0
	jar.add_child(jl)


# ── лодка ───────────────────────────────────────────────────

func _boat_build() -> void:
	boat = Node3D.new()
	add_child(boat)
	var wood := _mat(Color(0.26, 0.18, 0.11))
	var dark := _mat(Color(0.16, 0.11, 0.07))
	var parts := [
		[Vector3(1.0, 0.08, 3.0), Vector3(0, 0.05, 0), wood, Vector3.ZERO],
		[Vector3(0.08, 0.35, 3.0), Vector3(0.52, 0.2, 0), dark, Vector3(0, 0, -0.25)],
		[Vector3(0.08, 0.35, 3.0), Vector3(-0.52, 0.2, 0), dark, Vector3(0, 0, 0.25)],
		[Vector3(1.0, 0.35, 0.08), Vector3(0, 0.2, -1.5), dark, Vector3(0.3, 0, 0)],
		[Vector3(0.7, 0.3, 0.08), Vector3(0, 0.25, 1.52), dark, Vector3(-0.5, 0, 0)],
		[Vector3(0.9, 0.05, 0.25), Vector3(0, 0.28, 0.3), wood, Vector3.ZERO],
	]
	for p in parts:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = p[0]
		mi.mesh = bm
		mi.material_override = p[2]
		mi.position = p[1]
		mi.rotation = p[3]
		boat.add_child(mi)
	_place_boat(true)


func _boat_spot(at_a: bool) -> Transform3D:
	var pier := SwampLayout.pier_a() if at_a else SwampLayout.pier_b()
	var other := SwampLayout.pier_b() if at_a else SwampLayout.pier_a()
	var dir := (other - pier).normalized()
	var p := pier + dir * 1.9
	return Transform3D(Basis(Vector3.UP, atan2(dir.x, dir.y)), Vector3(p.x, -0.02, p.y))


func _place_boat(at_a: bool) -> void:
	boat_at_a = at_a
	boat.global_transform = _boat_spot(at_a)


func reset_boat() -> void:
	_ferry_t = -1.0
	_place_boat(true)


## Место кормщика в лодке и место пассажира
func stern() -> Vector3:
	return boat.global_transform * Vector3(0, 0.12, -1.0)


func seat() -> Vector3:
	return boat.global_transform * Vector3(0, 0.12, 0.7)


func start_ferry() -> void:
	_ferry_from = _boat_spot(boat_at_a).origin
	_ferry_to = _boat_spot(not boat_at_a).origin
	_ferry_t = 0.0


func ferrying() -> bool:
	return _ferry_t >= 0.0


## Где высадиться после переправы
func landing() -> Vector3:
	var pier := SwampLayout.pier_a() if boat_at_a else SwampLayout.pier_b()
	var other := SwampLayout.pier_b() if boat_at_a else SwampLayout.pier_a()
	var p := pier - (other - pier).normalized() * 0.6
	return Vector3(p.x, maxf(Terrain.height_at(p.x, p.y) + 0.2, 0.32), p.y)


const FERRY_TIME := 7.0


func _update_ferry(dt: float) -> void:
	if _ferry_t < 0.0:
		return
	_ferry_t += dt
	var u := clampf(_ferry_t / FERRY_TIME, 0.0, 1.0)
	var e := u * u * (3.0 - 2.0 * u)
	var p := _ferry_from.lerp(_ferry_to, e)
	var dir := (_ferry_to - _ferry_from).normalized()
	boat.global_position = p + Vector3(0, sin(_ferry_t * 2.0) * 0.03, 0)
	boat.rotation = Vector3(sin(_ferry_t * 1.6) * 0.03, atan2(dir.x, dir.z), sin(_ferry_t * 1.3) * 0.04)
	if u >= 1.0:
		_ferry_t = -1.0
		_place_boat(not boat_at_a)


# ── стрекозы ────────────────────────────────────────────────

func _dragonflies() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	mm.mesh = q
	var homes: Array[Vector3] = []
	var tries := 0
	while homes.size() < 30 and tries < 2000:
		tries += 1
		var a := _rng.randf() * TAU
		var d := sqrt(_rng.randf()) * SwampLayout.RADIUS
		var x := SwampLayout.CENTER.x + cos(a) * d
		var z := SwampLayout.CENTER.y + sin(a) * d
		var h := Terrain.height_at(x, z)
		if h < -1.0 or h > 0.3:
			continue
		homes.append(Vector3(x, 0.0, z))
	mm.instance_count = homes.size()
	for i in homes.size():
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, homes[i]))
		mm.set_instance_custom_data(i, Color(_rng.randf(), _rng.randf(), 0, 0))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/dragonfly.gdshader")
	Terrain.apply_map(mat)
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.custom_aabb = AABB(Vector3(SwampLayout.CENTER.x - 50, -5, SwampLayout.CENTER.y - 50), Vector3(100, 10, 100))
	add_child(mmi)


func update_swamp(dt: float, hero: Vector3, lit: bool) -> void:
	_t += dt
	_update_wisps(dt, Vector2(hero.x, hero.z), lit)
	_update_ferry(dt)
	# после рассвета — обновить отражения один раз
	if lit and _probe_refresh == 0:
		_probe_refresh = 1
	if _probe_refresh == 1:
		probe.update_mode = ReflectionProbe.UPDATE_ALWAYS
		_probe_refresh = 2
	elif _probe_refresh == 2:
		probe.update_mode = ReflectionProbe.UPDATE_ONCE
		_probe_refresh = 3
