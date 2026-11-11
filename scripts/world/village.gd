class_name Village
extends Node3D
## Деревня Тихий Брод: дома с тёплыми окнами и дымом из труб, колодец, кузница,
## мельница, чайхана с самоваром и коврами, хлебная печь, загон с овцами, фонари на столбах.

var colliders: Array[Vector3] = []
var _sheep: Array = [] # {node, anim, target, timer}
var _rng := RandomNumberGenerator.new()
var _lamp_lights: Array[OmniLight3D] = []
## Фонари на столбах: {root, glass, light, lit, k (0..1 — разгорается)}
var lamps: Array = []
## Постройки: {m, p (локально), r (градусы), node, id}
var houses: Array = []
var _t := 0.0
## Звуки ожившей деревни (AudioStreamPlayer3D) — громкость по оживанию места
var _emitters: Array = [] # {player, volume}


func _at(local: Vector2, lift := 0.0) -> Vector3:
	var w := VillageLayout.world(local)
	return Vector3(w.x, Terrain.height_at(w.x, w.y) + lift, w.y)


func build() -> void:
	name = "Village"
	_rng.seed = 1234
	for plot in VillageLayout.plots():
		var n := Props.make("village/%s.glb" % plot.m, plot.h)
		add_child(n)
		n.global_position = _at(plot.p, -0.05)
		n.rotation.y = deg_to_rad(plot.r)
		Props.settle(n)
		_collide_box(n, plot.p, n.get_meta("size"), deg_to_rad(plot.r))
		houses.append({m = plot.m, p = plot.p, r = plot.r, node = n, id = plot.get("id", "")})
		if plot.m.begins_with("House") or plot.m == "Blacksmith" or plot.m == "Inn":
			_chimney(n)
	_pen()
	for l in VillageLayout.LAMPS:
		_lamp(l)
	_oven(VillageLayout.OVEN)
	_forge(VillageLayout.ANVIL)
	_chaikhana()
	_board(VillageLayout.BOARD)


## Круги-препятствия вдоль длинной стороны постройки
func _collide_box(n: Node3D, local: Vector2, size: Vector3, rot: float) -> void:
	var c := VillageLayout.world(local)
	var long := maxf(size.x, size.z)
	var short := minf(size.x, size.z)
	if short < 0.5:
		return
	var axis := Vector2(cos(-rot), sin(-rot)) if size.x >= size.z else Vector2(sin(rot), cos(rot))
	var r := short * 0.45
	var count := maxi(1, int(ceil(long / (r * 1.6))))
	for i in count:
		var t := 0.0 if count == 1 else (float(i) / (count - 1) - 0.5) * (long - short)
		var p := c + axis * t
		colliders.append(Vector3(p.x, p.y, r))


func _chimney(house: Node3D) -> void:
	var size: Vector3 = house.get_meta("size")
	var smoke := Fx.chimney_smoke()
	house.add_child(smoke)
	smoke.position = Vector3(size.x * 0.22, size.y * 0.92, size.z * 0.1)


func _mat(c: Color, rough := 0.9, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


func _glow(c: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	return m


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


func _cyl(parent: Node3D, top: float, bottom: float, h: float, pos: Vector3, mat: Material, segs := 12) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = top
	cm.bottom_radius = bottom
	cm.height = h
	cm.radial_segments = segs
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


func _sphere(parent: Node3D, r: float, pos: Vector3, mat: Material, scale := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	mi.mesh = sm
	mi.material_override = mat
	mi.position = pos
	mi.scale = scale
	parent.add_child(mi)
	return mi


func _light(parent: Node3D, pos: Vector3, energy: float, rng := 8.0, col := Color(1.0, 0.62, 0.3)) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	l.omni_attenuation = 1.2
	l.position = pos
	l.light_volumetric_fog_energy = 0.8
	parent.add_child(l)
	return l


## Фонарь на столбе
func _lamp(local: Vector2) -> void:
	var root := Node3D.new()
	add_child(root)
	root.global_position = _at(local)
	var wood := _mat(Color(0.2, 0.13, 0.08))
	var iron := _mat(Color(0.08, 0.07, 0.07), 0.5, 0.6)
	_cyl(root, 0.06, 0.08, 2.6, Vector3(0, 1.3, 0), wood, 8)
	_box(root, Vector3(0.6, 0.06, 0.06), Vector3(0.25, 2.5, 0), wood)
	_box(root, Vector3(0.2, 0.04, 0.2), Vector3(0.5, 2.38, 0), iron)
	var glass := _box(root, Vector3(0.16, 0.22, 0.16), Vector3(0.5, 2.22, 0), _glow(Color(1.0, 0.62, 0.28), 3.0))
	_box(root, Vector3(0.2, 0.03, 0.2), Vector3(0.5, 2.1, 0), iron)
	var l := _light(root, Vector3(0.5, 2.1, 0), 1.3, 7.5)
	_lamp_lights.append(l)
	lamps.append({root = root, glass = glass, light = l, lit = true, k = 1.0})
	colliders.append(Vector3(root.global_position.x, root.global_position.z, 0.25))


## Фонарь на столбе: погашен (как все эти годы) или зажжён фонарщиком
func set_lamp(i: int, on: bool, instant := false) -> void:
	var lp: Dictionary = lamps[i]
	lp.lit = on
	if instant:
		lp.k = 1.0 if on else 0.0
		_apply_lamp(lp)
	if on and not instant:
		var fl := Fx.burst(24, 1.6)
		lp.root.add_child(fl)
		fl.position = Vector3(0.5, 2.2, 0)
		fl.emitting = true
		get_tree().create_timer(3.0).timeout.connect(fl.queue_free)


func _apply_lamp(lp: Dictionary) -> void:
	var g: MeshInstance3D = lp.glass
	var m := g.material_override as StandardMaterial3D
	if m != null:
		if not lp.has("mat"):
			m = m.duplicate()
			g.material_override = m
			lp.mat = m
		m = lp.mat
		m.albedo_color = Color(0.12, 0.1, 0.09).lerp(Color(1.0, 0.62, 0.28), lp.k)
		m.emission_energy_multiplier = 3.0 * lp.k
	(lp.light as OmniLight3D).visible = lp.k > 0.01


## Мировая позиция фонаря (основание столба)
func lamp_pos(i: int) -> Vector3:
	return (lamps[i].root as Node3D).global_position


## Хлебная печь: глиняный купол с тлеющим жаром внутри
func _oven(local: Vector2) -> void:
	var root := Node3D.new()
	add_child(root)
	root.global_position = _at(local)
	root.rotation.y = deg_to_rad(-140)
	var clay := _mat(Color(0.55, 0.36, 0.24))
	_cyl(root, 0.95, 1.05, 0.5, Vector3(0, 0.25, 0), _mat(Color(0.4, 0.3, 0.24)), 16)
	_sphere(root, 0.9, Vector3(0, 0.5, 0), clay, Vector3(1, 0.85, 1))
	_cyl(root, 0.12, 0.15, 0.4, Vector3(0.25, 1.35, 0), clay, 8)
	_box(root, Vector3(0.5, 0.4, 0.1), Vector3(0, 0.75, 0.86), _glow(Color(1.0, 0.45, 0.12), 3.5))
	_light(root, Vector3(0, 0.8, 1.2), 1.0, 5.0, Color(1.0, 0.5, 0.2))
	var smoke := Fx.chimney_smoke()
	smoke.amount = 14
	smoke.position = Vector3(0.25, 1.6, 0)
	root.add_child(smoke)
	colliders.append(Vector3(root.global_position.x, root.global_position.z, 1.1))


## Горн и наковальня кузнеца
func _forge(local: Vector2) -> void:
	var root := Node3D.new()
	add_child(root)
	root.global_position = _at(local)
	root.rotation.y = deg_to_rad(-90)
	var iron := _mat(Color(0.12, 0.12, 0.13), 0.45, 0.7)
	_box(root, Vector3(0.35, 0.5, 0.3), Vector3(0, 0.25, 0), _mat(Color(0.25, 0.17, 0.1)))
	_box(root, Vector3(0.7, 0.18, 0.28), Vector3(0, 0.6, 0), iron)
	_box(root, Vector3(0.25, 0.08, 0.2), Vector3(0.42, 0.62, 0), iron)
	# каменный горн с углями
	var forge := Node3D.new()
	root.add_child(forge)
	forge.position = Vector3(-1.2, 0, 1.0)
	_box(forge, Vector3(1.1, 0.8, 0.9), Vector3(0, 0.4, 0), _mat(Color(0.3, 0.29, 0.28)))
	_box(forge, Vector3(0.8, 0.06, 0.6), Vector3(0, 0.81, 0), _mat(Color(0.06, 0.05, 0.05)))
	var coal := _mat(Color(0.05, 0.04, 0.04))
	var hot := _glow(Color(1.0, 0.28, 0.05), 1.6)
	for k in 26: # угли: тёмные и тлеющие вперемешку
		var p := Vector3(randf_range(-0.34, 0.34), 0.84, randf_range(-0.24, 0.24))
		_sphere(forge, randf_range(0.03, 0.055), p, hot if randf() < 0.45 else coal, Vector3(1.0, randf_range(0.4, 0.7), randf_range(0.8, 1.2)))
	var embers := Fx.embers(14)
	embers.position = Vector3(0, 0.9, 0)
	forge.add_child(embers)
	_light(forge, Vector3(0, 1.3, 0), 1.6, 6.0, Color(1.0, 0.45, 0.18))
	colliders.append(Vector3(root.global_position.x, root.global_position.z, 0.5))
	var fp := forge.global_position
	colliders.append(Vector3(fp.x, fp.z, 0.7))


## Чайхана: под навесом топчан с ковром, низкий столик, самовар, подушки
func _chaikhana() -> void:
	var root := Node3D.new()
	add_child(root)
	root.global_position = _at(Vector2(-1.0, 11.0))
	var wood := _mat(Color(0.32, 0.2, 0.11))
	# топчан
	_box(root, Vector3(2.4, 0.35, 1.8), Vector3(0, 0.25, 0), wood)
	for x in [-1.1, 1.1]:
		for z in [-0.8, 0.8]:
			_box(root, Vector3(0.1, 0.25, 0.1), Vector3(x, 0.05, z), wood)
	_carpet(root, Vector2(2.3, 1.7), Vector3(0, 0.43, 0), Color(0.55, 0.08, 0.06), Color(0.1, 0.15, 0.4))
	_carpet(root, Vector2(1.6, 1.1), Vector3(0, 0.02, 1.7), Color(0.12, 0.2, 0.45), Color(0.55, 0.12, 0.08))
	# столик
	_box(root, Vector3(0.8, 0.06, 0.6), Vector3(0, 0.62, 0), wood)
	for x in [-0.34, 0.34]:
		for z in [-0.24, 0.24]:
			_box(root, Vector3(0.05, 0.16, 0.05), Vector3(x, 0.52, z), wood)
	# пиалы
	for i in 3:
		_cyl(root, 0.05, 0.035, 0.05, Vector3(-0.2 + i * 0.18, 0.68, 0.1), _mat(Color(0.9, 0.88, 0.8), 0.4), 10)
	# подушки
	for c in [[Vector3(-0.85, 0.5, -0.5), Color(0.6, 0.2, 0.1)], [Vector3(0.85, 0.5, -0.5), Color(0.2, 0.35, 0.3)], [Vector3(-0.85, 0.5, 0.5), Color(0.7, 0.55, 0.2)], [Vector3(0.85, 0.5, 0.5), Color(0.5, 0.15, 0.25)]]:
		_sphere(root, 0.28, c[0], _mat(c[1]), Vector3(1.0, 0.35, 0.8))
	_samovar(root, Vector3(0.0, 0.43, -0.6))
	colliders.append(Vector3(root.global_position.x, root.global_position.z, 1.3))


func _carpet(parent: Node3D, size: Vector2, pos: Vector3, base: Color, accent: Color) -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = size
	mi.mesh = pm
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/carpet.gdshader")
	m.set_shader_parameter("base_col", base)
	m.set_shader_parameter("accent", accent)
	m.set_shader_parameter("size", size)
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)


## Самовар: латунь, кран, трубка, пар
func _samovar(parent: Node3D, pos: Vector3) -> void:
	var root := Node3D.new()
	parent.add_child(root)
	root.position = pos
	var brass := _mat(Color(0.75, 0.52, 0.22), 0.3, 0.9)
	_cyl(root, 0.12, 0.16, 0.08, Vector3(0, 0.04, 0), brass, 14)
	_cyl(root, 0.05, 0.06, 0.1, Vector3(0, 0.12, 0), brass, 10)
	_sphere(root, 0.2, Vector3(0, 0.36, 0), brass, Vector3(1, 1.25, 1))
	_cyl(root, 0.08, 0.12, 0.1, Vector3(0, 0.62, 0), brass, 12)
	_cyl(root, 0.03, 0.03, 0.18, Vector3(0, 0.75, 0), _mat(Color(0.15, 0.12, 0.1), 0.6, 0.5), 8)
	_sphere(root, 0.09, Vector3(0, 0.74, 0), _mat(Color(0.95, 0.92, 0.85), 0.3), Vector3(1, 0.7, 1)) # чайник сверху
	_box(root, Vector3(0.14, 0.03, 0.03), Vector3(0.0, 0.3, 0.22), brass, Vector3(0, PI / 2, 0))
	for s in [-1.0, 1.0]:
		var h := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.05
		tm.outer_radius = 0.07
		h.mesh = tm
		h.material_override = brass
		h.position = Vector3(s * 0.24, 0.45, 0)
		h.rotation = Vector3(0, 0, PI / 2)
		root.add_child(h)
	var steam := Fx.steam()
	steam.position = Vector3(0, 0.9, 0)
	root.add_child(steam)
	_light(root, Vector3(0, 1.4, 0.3), 0.7, 5.0, Color(1.0, 0.7, 0.4))


## Доска объявлений у колодца (на ней — указ короля)
func _board(local: Vector2) -> void:
	var root := Node3D.new()
	add_child(root)
	root.global_position = _at(local)
	root.rotation.y = deg_to_rad(200)
	var wood := _mat(Color(0.25, 0.16, 0.09))
	for x in [-0.6, 0.6]:
		_box(root, Vector3(0.1, 1.9, 0.1), Vector3(x, 0.95, 0), wood)
	_box(root, Vector3(1.4, 0.9, 0.06), Vector3(0, 1.35, 0), wood)
	_box(root, Vector3(0.5, 0.65, 0.01), Vector3(-0.2, 1.38, 0.04), _mat(Color(0.82, 0.76, 0.6)), Vector3(0, 0, 0.05))
	_box(root, Vector3(1.6, 0.08, 0.3), Vector3(0, 1.85, 0), wood)
	colliders.append(Vector3(root.global_position.x, root.global_position.z, 0.5))


## Загон с овцами
func _pen() -> void:
	var c := VillageLayout.PEN_CENTER
	var half := VillageLayout.PEN_SIZE * 0.5
	var corners := [c + Vector2(-half.x, -half.y), c + Vector2(half.x, -half.y), c + Vector2(half.x, half.y), c + Vector2(-half.x, half.y)]
	for i in 4:
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i + 1) % 4]
		var length := a.distance_to(b)
		var n := int(ceil(length / 2.0))
		for k in n:
			if i == 1 and k == n / 2:
				continue # калитка
			var p: Vector2 = a.lerp(b, (k + 0.5) / n)
			var f := Props.make("village/Fence.glb", 0.0, length / n)
			add_child(f)
			f.global_position = _at(p)
			f.rotation.y = -atan2(b.y - a.y, b.x - a.x)
			Props.settle(f)
			var w := VillageLayout.world(p)
			colliders.append(Vector3(w.x, w.y, 0.45))
	var scene: PackedScene = load("res://assets/models/animals/Sheep.fbx")
	for i in 4:
		var s: Node3D = scene.instantiate()
		var holder := Node3D.new()
		holder.add_child(s)
		add_child(holder)
		var box := AABB()
		for mi: MeshInstance3D in s.find_children("*", "MeshInstance3D", true, false):
			box = (holder.global_transform.affine_inverse() * mi.global_transform) * mi.get_aabb()
		s.scale = Vector3.ONE * (1.15 / maxf(box.size.y, 0.001))
		s.position.y = -box.position.y * s.scale.y
		var p := c + Vector2(_rng.randf_range(-half.x + 1, half.x - 1), _rng.randf_range(-half.y + 1, half.y - 1))
		holder.global_position = _at(p)
		holder.rotation.y = _rng.randf() * TAU
		var anim: AnimationPlayer = s.find_children("*", "AnimationPlayer", true, false)[0]
		var idle := anim.get_animation_list()[0]
		for a in anim.get_animation_list():
			if "Idle" in a:
				idle = a
		anim.get_animation(idle).loop_mode = Animation.LOOP_LINEAR
		anim.play(idle)
		anim.speed_scale = _rng.randf_range(0.7, 1.1)
		anim.seek(_rng.randf() * 2.0)
		_sheep.append({node = holder, target = p, timer = _rng.randf_range(2.0, 8.0)})


func _process(dt: float) -> void:
	_t += dt
	# овцы иногда неспешно переходят по загону
	var c := VillageLayout.PEN_CENTER
	var half := VillageLayout.PEN_SIZE * 0.5 - Vector2(0.9, 0.9)
	for s in _sheep:
		s.timer -= dt
		var n: Node3D = s.node
		if s.timer <= 0.0:
			s.timer = _rng.randf_range(4.0, 12.0)
			s.target = c + Vector2(_rng.randf_range(-half.x, half.x), _rng.randf_range(-half.y, half.y))
		var w := VillageLayout.world(s.target)
		var to := Vector2(w.x - n.global_position.x, w.y - n.global_position.z)
		if to.length() > 0.2:
			var step := to.normalized() * minf(to.length(), dt * 0.35)
			n.global_position.x += step.x
			n.global_position.z += step.y
			n.rotation.y = lerp_angle(n.rotation.y, atan2(to.x, to.y), dt * 2.0)
		n.global_position.y = Terrain.height_at(n.global_position.x, n.global_position.z)
	# фонари чуть дрожат
	for i in lamps.size():
		var lp: Dictionary = lamps[i]
		var want := 1.0 if lp.lit else 0.0
		if lp.k != want:
			lp.k = move_toward(lp.k, want, dt * 1.2)
			_apply_lamp(lp)
		_lamp_lights[i].light_energy = 1.3 * lp.k * (0.92 + 0.08 * sin(_t * 7.0 + i * 1.7) * sin(_t * 3.1 + i))
	# голоса ожившей деревни
	for e in _emitters:
		var p: AudioStreamPlayer3D = e.player
		var v := Beacon.restore_at(p.global_position)
		var lv: float = v * e.volume
		if lv > 0.01 and not p.playing:
			p.play(randf() * p.stream.get_length())
		elif lv <= 0.01 and p.playing:
			p.stop()
		p.volume_db = linear_to_db(maxf(lv, 0.0001))


## Звук, привязанный к месту в деревне
func add_emitter(local: Vector2, stream: AudioStreamWAV, volume: float, unit_size := 6.0) -> void:
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.unit_size = unit_size
	p.max_distance = 45.0
	p.volume_db = -80.0
	add_child(p)
	p.global_position = _at(local, 1.5)
	_emitters.append({player = p, volume = volume})
