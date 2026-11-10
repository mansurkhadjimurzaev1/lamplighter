class_name Mountains
extends Node3D
## Горы: каменная лестница, жаровни, обсерватория Ансара (башня, медный купол и телескоп,
## астролябии, звёздные карты, книги), снегопад.

const WARM_RADIUS := 4.8

var colliders: Array[Vector3] = []
var braziers: Array = [] # {pos: Vector3, lit: bool, flames, embers, light, index}
var snow: GPUParticles3D
var _snow_mat: ShaderMaterial
var _rng := RandomNumberGenerator.new()
var _rock_tex: Texture2D
var _stone: ShaderMaterial
var _t := 0.0


func build() -> void:
	name = "Mountains"
	_rng.seed = 313
	_rock_tex = load("res://assets/textures/ground/Rock030_color.jpg")
	_stone = ShaderMaterial.new()
	_stone.shader = load("res://shaders/stone.gdshader")
	_stone.set_shader_parameter("rock_tex", _rock_tex)
	_stone.set_shader_parameter("center", Vector3(MountainLayout.OBS.x, 0, MountainLayout.OBS.y))
	_stone.set_shader_parameter("base_y", MountainLayout.PEAK)
	_steps()
	_braziers()
	_observatory()
	_snowfall()


func _h(p: Vector2) -> float:
	return Terrain.height_at(p.x, p.y)


func _mat(c: Color, rough := 0.9, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


func _mesh(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot := Vector3.ZERO, scale := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.scale = scale
	parent.add_child(mi)
	return mi


func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


func _cyl(top: float, bottom: float, h: float, segs := 12) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = segs
	return c


# ── каменные ступени ────────────────────────────────────────

func _steps() -> void:
	var xfs: Array[Transform3D] = []
	var st := MountainLayout.STAIRS
	for path in [st.slice(2), MountainLayout.RIDGE]:
		for i in path.size() - 1:
			var a: Vector2 = path[i]
			var b: Vector2 = path[i + 1]
			var len := a.distance_to(b)
			var dir := (b - a).normalized()
			var n := int(len / 0.75)
			for k in n:
				var p := a + dir * (k + 0.5) * len / n
				var y := _h(p)
				var basis := Basis(Vector3.UP, atan2(dir.x, dir.y)).rotated(Vector3.UP, _rng.randf_range(-0.04, 0.04))
				xfs.append(Transform3D(basis.scaled(Vector3(_rng.randf_range(0.95, 1.05), 1, 1)), Vector3(p.x, y - 0.1, p.y)))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _box(Vector3(MountainLayout.PATH_HALF * 2.0, 0.24, 0.7))
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	# ступени: светлый камень, припорошенный снегом
	var mat := _mat(Color(1.0, 0.98, 1.0), 0.9)
	mat.albedo_texture = _rock_tex
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3(0.6, 0.6, 0.6)
	mmi.material_override = mat
	add_child(mmi)
	# снег на ступенях — у дальнего края каждой (ближе к стене), неровно
	var caps: Array[Transform3D] = []
	for t in xfs:
		caps.append(t * Transform3D(Basis.IDENTITY.scaled(Vector3(_rng.randf_range(0.7, 0.95), 1, _rng.randf_range(0.4, 0.7))), Vector3(_rng.randf_range(-0.15, 0.15), 0.13, 0.1)))
	var cm := MultiMesh.new()
	cm.transform_format = MultiMesh.TRANSFORM_3D
	cm.mesh = _box(Vector3(MountainLayout.PATH_HALF * 2.0, 0.04, 0.7))
	cm.instance_count = caps.size()
	for i in caps.size():
		cm.set_instance_transform(i, caps[i])
	var cmi := MultiMeshInstance3D.new()
	cmi.multimesh = cm
	cmi.material_override = _mat(Color(0.82, 0.86, 0.94), 0.6)
	cmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(cmi)


# ── жаровни ─────────────────────────────────────────────────

func _braziers() -> void:
	var iron := _mat(Color(0.1, 0.09, 0.09), 0.5, 0.6)
	var spots := MountainLayout.brazier_spots()
	for i in spots.size():
		# жаровня стоит на уступе сбоку от ступеней — не загораживает проход
		var p: Vector2 = spots[i]
		var root := Node3D.new()
		add_child(root)
		root.global_position = Vector3(p.x, _h(p), p.y)
		for k in 3: # треножник
			var a := k * TAU / 3.0
			_mesh(root, _cyl(0.03, 0.04, 1.0, 6), iron, Vector3(cos(a) * 0.22, 0.45, sin(a) * 0.22), Vector3(sin(a) * 0.25, 0, -cos(a) * 0.25))
		_mesh(root, _cyl(0.42, 0.2, 0.28, 12), iron, Vector3(0, 0.98, 0))
		var coal := _mesh(root, _cyl(0.38, 0.38, 0.04, 12), _mat(Color(0.08, 0.07, 0.07)), Vector3(0, 1.1, 0))
		var flames := Fx.flames()
		flames.amount = 26
		flames.scale = Vector3.ONE * 0.6
		flames.position = Vector3(0, 1.15, 0)
		flames.emitting = false
		root.add_child(flames)
		var embers := Fx.embers(10)
		embers.position = Vector3(0, 1.2, 0)
		embers.emitting = false
		root.add_child(embers)
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.55, 0.25)
		light.light_energy = 0.0
		light.omni_range = 7.0
		light.position = Vector3(0, 1.6, 0)
		light.light_volumetric_fog_energy = 1.5
		light.visible = false
		root.add_child(light)
		braziers.append({pos = root.global_position, lit = false, flames = flames, embers = embers, light = light, coal = coal, index = i})


func light_brazier(i: int) -> void:
	var b: Dictionary = braziers[i]
	if b.lit:
		return
	b.lit = true
	b.flames.emitting = true
	b.embers.emitting = true
	b.light.visible = true
	(b.coal as MeshInstance3D).material_override = _glow(Color(1.0, 0.35, 0.08), 2.0)


func _glow(c: Color, e: float) -> StandardMaterial3D:
	var m := _mat(c)
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = e
	return m


## 0..1 — насколько тепло от горящих жаровен
func warmth(p: Vector3) -> float:
	var best := 0.0
	for b in braziers:
		if b.lit:
			var d := Vector2(p.x - b.pos.x, p.z - b.pos.z).length()
			best = maxf(best, 1.0 - Terrain.ss(WARM_RADIUS * 0.6, WARM_RADIUS, d))
	return best


func nearest_unlit(p: Vector3, r := 2.8) -> int:
	for b in braziers:
		if not b.lit and Vector2(p.x - b.pos.x, p.z - b.pos.z).length() < r:
			return b.index
	return -1


# ── обсерватория ────────────────────────────────────────────

func _observatory() -> void:
	var c := MountainLayout.OBS
	var base_y := _h(c)
	var root := Node3D.new()
	add_child(root)
	var tower_pos := c + Vector2(-2.6, -2.2)
	root.global_position = Vector3(tower_pos.x, base_y, tower_pos.y)
	# башня
	_mesh(root, _cyl(2.6, 2.9, 0.6, 18), _stone, Vector3(0, 0.3, 0))
	_mesh(root, _cyl(2.3, 2.5, 6.0, 18), _stone, Vector3(0, 3.3, 0))
	_mesh(root, _cyl(2.6, 2.4, 0.4, 18), _stone, Vector3(0, 6.4, 0))
	# медный купол с щелью
	var copper := _mat(Color(0.62, 0.36, 0.2), 0.35, 0.85)
	var verdigris := _mat(Color(0.32, 0.55, 0.48), 0.6, 0.4)
	var dome := SphereMesh.new()
	dome.radius = 2.35
	dome.height = 4.7
	dome.is_hemisphere = true
	dome.radial_segments = 24
	_mesh(root, dome, copper, Vector3(0, 6.6, 0))
	_mesh(root, _box(Vector3(0.7, 2.2, 2.6)), _mat(Color(0.05, 0.05, 0.08)), Vector3(0, 7.8, 1.1), Vector3(-0.5, 0, 0))
	_mesh(root, _cyl(0.05, 0.05, 1.4, 8), verdigris, Vector3(0, 9.2, 0))
	# телескоп: медная труба из щели купола
	var tube := Node3D.new()
	root.add_child(tube)
	tube.position = Vector3(0, 8.0, 0.9)
	tube.rotation = Vector3(-0.85, 0.25, 0)
	_mesh(tube, _cyl(0.32, 0.26, 4.2, 14), copper, Vector3(0, 1.9, 0))
	_mesh(tube, _cyl(0.36, 0.36, 0.2, 14), verdigris, Vector3(0, 0.6, 0))
	_mesh(tube, _cyl(0.36, 0.36, 0.2, 14), verdigris, Vector3(0, 3.2, 0))
	_mesh(tube, _cyl(0.38, 0.32, 0.3, 14), _mat(Color(0.75, 0.8, 0.95), 0.05, 0.3), Vector3(0, 4.1, 0))
	# окна — тёплый свет
	for k in 4:
		var a := k * TAU / 4.0 + 0.4
		var w := _mesh(root, _box(Vector3(0.5, 1.0, 0.1)), _glow(Color(1.0, 0.6, 0.28), 2.2), Vector3(cos(a) * 2.42, 3.8, sin(a) * 2.42), Vector3(0, -a + PI / 2, 0))
		w.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var door := _mesh(root, _box(Vector3(1.1, 2.0, 0.1)), _mat(Color(0.25, 0.15, 0.08)), Vector3(0, 1.6, 2.42))
	door.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var wl := OmniLight3D.new()
	wl.light_color = Color(1.0, 0.6, 0.3)
	wl.light_energy = 1.2
	wl.omni_range = 7.0
	wl.position = Vector3(0, 2.0, 3.2)
	root.add_child(wl)
	colliders.append(Vector3(tower_pos.x, tower_pos.y, 2.9))

	# терраса: стол с книгами и картами, астролябии, мольберт с картой
	var wood := _mat(Color(0.3, 0.19, 0.1))
	var terrace := Node3D.new()
	add_child(terrace)
	var tp := c + Vector2(2.4, 1.6)
	terrace.global_position = Vector3(tp.x, base_y, tp.y)
	terrace.rotation.y = 0.5
	_mesh(terrace, _box(Vector3(2.0, 0.08, 1.0)), wood, Vector3(0, 0.82, 0))
	for x in [-0.9, 0.9]:
		for z in [-0.4, 0.4]:
			_mesh(terrace, _box(Vector3(0.08, 0.8, 0.08)), wood, Vector3(x, 0.4, z))
	# книги стопками
	var book_cols := [Color(0.45, 0.12, 0.08), Color(0.15, 0.25, 0.4), Color(0.3, 0.35, 0.15), Color(0.5, 0.35, 0.15), Color(0.25, 0.12, 0.2)]
	for stack in 2:
		var y := 0.86
		for k in _rng.randi_range(3, 5):
			var th := _rng.randf_range(0.05, 0.09)
			_mesh(terrace, _box(Vector3(0.34, th, 0.25)), _mat(book_cols[(k + stack * 2) % book_cols.size()]), Vector3(-0.65 + stack * 0.4, y + th * 0.5, -0.2), Vector3(0, _rng.randf_range(-0.2, 0.2), 0))
			y += th
	# раскрытая карта на столе
	_chart(terrace, Vector3(0.35, 0.87, 0.05), Vector2(0.8, 0.6), Vector3(-PI / 2, 0, 0.1), 3.0)
	# свеча-лампа на столе
	_mesh(terrace, _cyl(0.04, 0.05, 0.16, 8), _mat(Color(0.9, 0.86, 0.75)), Vector3(0.8, 0.94, -0.3))
	var cl := OmniLight3D.new()
	cl.light_color = Color(1.0, 0.65, 0.35)
	cl.light_energy = 0.8
	cl.omni_range = 4.0
	cl.position = Vector3(0.8, 1.15, -0.3)
	terrace.add_child(cl)
	var flame := _mesh(terrace, SphereMesh.new(), _glow(Color(1.0, 0.7, 0.3), 8.0), Vector3(0.8, 1.06, -0.3), Vector3.ZERO, Vector3(0.03, 0.06, 0.03))
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	colliders.append(Vector3(tp.x, tp.y, 1.1))
	# мольберт с большой звёздной картой
	var easel := Node3D.new()
	add_child(easel)
	var ep := c + Vector2(-0.5, 4.2)
	easel.global_position = Vector3(ep.x, base_y, ep.y)
	easel.rotation.y = 0.9
	for x in [-0.45, 0.45]:
		_mesh(easel, _box(Vector3(0.06, 1.8, 0.06)), wood, Vector3(x, 0.9, 0), Vector3(0.12, 0, 0))
	_mesh(easel, _box(Vector3(0.06, 1.7, 0.06)), wood, Vector3(0, 0.85, -0.35), Vector3(-0.25, 0, 0))
	_chart(easel, Vector3(0, 1.25, 0.08), Vector2(1.1, 1.1), Vector3(0.12, 0, 0), 7.0)
	colliders.append(Vector3(ep.x, ep.y, 0.6))
	# астролябии на подставках
	for k in 2:
		var ap: Vector2 = c + [Vector2(3.6, -1.6), Vector2(1.0, -3.6)][k]
		var astro := Node3D.new()
		add_child(astro)
		astro.global_position = Vector3(ap.x, base_y, ap.y)
		_mesh(astro, _cyl(0.05, 0.12, 1.0, 8), _mat(Color(0.2, 0.15, 0.1), 0.6, 0.5), Vector3(0, 0.5, 0))
		var rings := Node3D.new()
		astro.add_child(rings)
		rings.position = Vector3(0, 1.45, 0)
		rings.set_meta("spin", 0.15 + k * 0.1)
		for r in 3:
			var t := TorusMesh.new()
			t.inner_radius = 0.38 - r * 0.09
			t.outer_radius = 0.42 - r * 0.09
			t.rings = 24
			_mesh(rings, t, copper if r != 1 else verdigris, Vector3.ZERO, Vector3(PI / 2 + r * 0.7, r * 0.9, 0))
		_mesh(rings, SphereMesh.new(), _mat(Color(0.75, 0.55, 0.25), 0.3, 0.9), Vector3.ZERO, Vector3.ZERO, Vector3.ONE * 0.12)
		colliders.append(Vector3(ap.x, ap.y, 0.4))
		_astros.append(rings)


var _astros: Array[Node3D] = []


func _chart(parent: Node3D, pos: Vector3, size: Vector2, rot: Vector3, seed_value: float) -> void:
	var q := QuadMesh.new()
	q.size = size
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/star_chart.gdshader")
	m.set_shader_parameter("seed", seed_value)
	_mesh(parent, q, m, pos, rot)


# ── снег ────────────────────────────────────────────────────

func _snowfall() -> void:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(16, 1, 12)
	pm.direction = Vector3(0.6, -1, 0.2)
	pm.spread = 15.0
	pm.initial_velocity_min = 1.5
	pm.initial_velocity_max = 3.0
	pm.gravity = Vector3(1.6, -1.2, 0.3) # ледяной ветер сносит снег
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 1.2
	pm.turbulence_noise_scale = 4.0
	pm.scale_min = 0.5
	pm.scale_max = 1.3
	snow = GPUParticles3D.new()
	snow.amount = 1400 if Quality.level == "high" else (800 if Quality.level == "medium" else 400)
	snow.lifetime = 5.0
	snow.preprocess = 4.0
	snow.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.08, 0.08)
	_snow_mat = ShaderMaterial.new()
	_snow_mat.shader = load("res://shaders/snow.gdshader")
	q.material = _snow_mat
	snow.draw_pass_1 = q
	snow.visibility_aabb = AABB(Vector3(-25, -20, -25), Vector3(50, 40, 50))
	snow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	snow.emitting = false
	add_child(snow)


func update_mountains(dt: float, hero: Vector3, region: float, restored: float) -> void:
	_t += dt
	for r in _astros:
		r.rotation.y += dt * float(r.get_meta("spin"))
	for b in braziers:
		if b.lit:
			b.light.light_energy = 2.0 * (0.9 + 0.1 * sin(_t * 9.0 + b.index) * sin(_t * 5.3 + b.index * 2.0))
	# снегопад вокруг героя (после маяка — лишь редкие снежинки)
	var amount := region * lerpf(1.0, 0.2, restored)
	snow.emitting = amount > 0.02
	snow.global_position = hero + Vector3(-4.0, 9.0, -2.0)
	_snow_mat.set_shader_parameter("amount", amount)
