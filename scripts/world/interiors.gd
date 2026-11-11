class_name Interiors
extends Node3D
## Дома, в которые можно войти (E у двери): укрытие от волн Пелены, тепло очага, тишина.
## Комнаты строятся далеко за северным краем мира (z ≈ −420) — оттуда мир не виден.
## Вид сверху: потолок и ближние стены прячутся (разрез, как кукольный домик);
## от первого лица видна вся комната.

const ORIGIN := Vector3(0, 0, -420)
const SIZE := Vector2(7.2, 5.6) # ширина (x) × глубина (z)
const WALL_H := 2.8
const STEP := 26.0 # расстояние между комнатами

## Комнаты: {id, title, theme, door_out (мир, снаружи у двери), out_yaw, center, rect, exit_in, cut[], fires[]}
var rooms: Array = []
var colliders: Array[Vector3] = []
var current := -1
var _t := 0.0
var _wood: ShaderMaterial
var _wall: ShaderMaterial
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	name = "Interiors"
	_rng.seed = 77


## door_world — точка у двери снаружи (там герой появится, выйдя); out_dir — куда смотрит дверь
func add_room(id: String, title: String, theme: String, door_world: Vector3, out_dir: Vector2) -> void:
	var i := rooms.size()
	var c := ORIGIN + Vector3(i * STEP, 0, 0)
	var root := Node3D.new()
	root.name = "Room_" + id
	add_child(root)
	root.global_position = c
	var r := {id = id, title = title, theme = theme, door_out = door_world, out_yaw = atan2(out_dir.x, out_dir.y),
		center = c, root = root, cut = [], fires = [],
		rect = Rect2(c.x - SIZE.x * 0.5 + 0.4, c.z - SIZE.y * 0.5 + 0.4, SIZE.x - 0.8, SIZE.y - 0.8),
		exit_in = c + Vector3(0, 0, SIZE.y * 0.5 - 0.75)}
	rooms.append(r)
	_shell(r)
	match theme:
		"elder": _elder(r)
		"lia": _lia(r)
		"herbal": _herbal(r)
		"fisher": _fisher(r)
		"study": _study(r)


# ── материалы и простые формы ───────────────────────────────

func _mat(col: Color, rough := 0.85, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic = metal
	return m


func _glow(col: Color, energy: float) -> StandardMaterial3D:
	var m := _mat(col)
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = energy
	return m


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
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


func _sphere(parent: Node3D, rad: float, pos: Vector3, mat: Material, sc := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = rad
	sm.height = rad * 2.0
	mi.mesh = sm
	mi.material_override = mat
	mi.position = pos
	mi.scale = sc
	parent.add_child(mi)
	return mi


func _prop(parent: Node3D, path: String, h: float, pos: Vector3, yaw := 0.0) -> Node3D:
	var n := Props.make(path, h)
	parent.add_child(n)
	n.position = pos
	n.rotation.y = yaw
	return n


func _block(r: Dictionary, local: Vector2, rad: float) -> void:
	var c: Vector3 = r.center
	colliders.append(Vector3(c.x + local.x, c.z + local.y, rad))


# ── коробка комнаты: пол, стены, потолок с балками, окна, очаг ────

func _shell(r: Dictionary) -> void:
	var root: Node3D = r.root
	if _wood == null:
		_wood = ShaderMaterial.new()
		_wood.shader = load("res://shaders/interior_wood.gdshader")
		_wall = ShaderMaterial.new()
		_wall.shader = load("res://shaders/interior_wall.gdshader")
		_wall.set_shader_parameter("stone_tex", load("res://assets/textures/ground/Rock030_color.jpg"))
		_wall.set_shader_parameter("height", WALL_H)
	var hx := SIZE.x * 0.5
	var hz := SIZE.y * 0.5
	var t := 0.25
	_box(root, Vector3(SIZE.x + 0.6, 0.2, SIZE.y + 0.6), Vector3(0, -0.1, 0), _wood)
	# тьма вокруг — чтобы сверху не было видно пустоты под домом
	var void_m := _mat(Color(0.0, 0.0, 0.0), 1.0)
	_box(root, Vector3(60, 0.1, 60), Vector3(0, -1.2, 0), void_m)
	var back := _box(root, Vector3(SIZE.x + t * 2, WALL_H, t), Vector3(0, WALL_H * 0.5, -hz - t * 0.5), _wall)
	var left := _box(root, Vector3(t, WALL_H, SIZE.y), Vector3(-hx - t * 0.5, WALL_H * 0.5, 0), _wall)
	var right := _box(root, Vector3(t, WALL_H, SIZE.y), Vector3(hx + t * 0.5, WALL_H * 0.5, 0), _wall)
	# передняя стена с дверным проёмом посередине
	var door_w := 1.3
	var seg := (SIZE.x - door_w) * 0.5 + t
	var fl := _box(root, Vector3(seg, WALL_H, t), Vector3(-hx - t + seg * 0.5, WALL_H * 0.5, hz + t * 0.5), _wall)
	var fr := _box(root, Vector3(seg, WALL_H, t), Vector3(hx + t - seg * 0.5, WALL_H * 0.5, hz + t * 0.5), _wall)
	var lintel := _box(root, Vector3(door_w, WALL_H - 2.1, t), Vector3(0, 2.1 + (WALL_H - 2.1) * 0.5, hz + t * 0.5), _wall)
	# дверь приоткрыта — за ней ночь
	var dark := _mat(Color(0.02, 0.03, 0.07), 1.0)
	var outside := _box(root, Vector3(door_w, 2.1, 0.05), Vector3(0, 1.05, hz + t + 0.4), _glow(Color(0.05, 0.07, 0.16), 0.6))
	var dw := _mat(Color(0.3, 0.19, 0.1))
	var door := _box(root, Vector3(0.08, 2.0, door_w * 0.95), Vector3(-door_w * 0.5 + 0.05, 1.0, hz + t + door_w * 0.45), dw)
	_box(root, Vector3(door_w + 0.2, 0.12, 0.35), Vector3(0, 2.12, hz + t * 0.5), dw)
	r.cut = [fl, fr, lintel, outside, door, right]
	# коврик у порога
	_box(root, Vector3(1.1, 0.02, 0.6), Vector3(0, 0.01, hz - 0.5), _mat(Color(0.35, 0.28, 0.18)))
	# потолок и балки
	var ceil := _box(root, Vector3(SIZE.x + t * 2, 0.12, SIZE.y + t * 2), Vector3(0, WALL_H + 0.06, 0), _mat(Color(0.2, 0.13, 0.08)))
	r.cut.append(ceil)
	for k in 4:
		var bx := -hx + (k + 0.5) * SIZE.x / 4.0
		var beam := _box(root, Vector3(0.18, 0.2, SIZE.y), Vector3(bx, WALL_H - 0.1, 0), _mat(Color(0.24, 0.15, 0.08)))
		r.cut.append(beam)
	# окна: ночная синева за стеклом
	for side in [-1.0, 1.0]:
		var w := _box(root, Vector3(0.06, 0.8, 0.9), Vector3(side * (hx + 0.02), 1.6, -0.6), _glow(Color(0.12, 0.18, 0.4), 0.8))
		_box(root, Vector3(0.1, 0.06, 1.0), Vector3(side * (hx + 0.02), 1.6, -0.6), dw)
		_box(root, Vector3(0.1, 0.9, 0.06), Vector3(side * (hx + 0.02), 1.6, -0.6), dw)
		if side > 0.0:
			r.cut.append(w)
	var _unused := [back, left]
	# очаг у задней стены
	_hearth(r, Vector3(-hx + 1.4, 0, -hz + 0.45))


func _hearth(r: Dictionary, pos: Vector3) -> void:
	var root: Node3D = r.root
	var stone := _mat(Color(0.42, 0.38, 0.35), 0.95)
	var h := Node3D.new()
	root.add_child(h)
	h.position = pos
	_box(h, Vector3(1.6, 0.25, 0.9), Vector3(0, 0.12, 0.05), stone)
	_box(h, Vector3(0.3, 1.2, 0.7), Vector3(-0.65, 0.85, -0.05), stone)
	_box(h, Vector3(0.3, 1.2, 0.7), Vector3(0.65, 0.85, -0.05), stone)
	_box(h, Vector3(1.6, 0.3, 0.8), Vector3(0, 1.55, -0.05), stone)
	_box(h, Vector3(1.0, 1.1, 0.5), Vector3(0, 2.25, -0.2), stone) # дымоход
	_box(h, Vector3(1.0, 0.9, 0.1), Vector3(0, 0.75, -0.35), _mat(Color(0.05, 0.03, 0.02), 1.0)) # закопчённая глубина
	for k in 3:
		var lg := _cyl(h, 0.07, 0.07, 0.7, Vector3(-0.15 + k * 0.15, 0.32, 0.0), _mat(Color(0.25, 0.15, 0.08)), 8)
		lg.rotation = Vector3(0, 0.3 * (k - 1), PI / 2)
	var fl := Fx.flames()
	fl.amount = 22
	fl.scale = Vector3.ONE * 0.5
	fl.position = Vector3(0, 0.35, 0.0)
	fl.emitting = true
	h.add_child(fl)
	var em := Fx.embers(10)
	em.position = Vector3(0, 0.45, 0)
	em.emitting = true
	h.add_child(em)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.55, 0.25)
	l.light_energy = 1.7
	l.omni_range = 8.5
	l.position = Vector3(0, 0.8, 0.6)
	l.shadow_enabled = Quality.shadows
	h.add_child(l)
	r.fires.append(l)
	_block(r, Vector2(pos.x, pos.z), 0.8)


func _candle(r: Dictionary, pos: Vector3, energy := 0.7) -> void:
	var root: Node3D = r.root
	_cyl(root, 0.03, 0.035, 0.14, pos + Vector3(0, 0.07, 0), _mat(Color(0.92, 0.88, 0.75)), 8)
	_sphere(root, 0.025, pos + Vector3(0, 0.17, 0), _glow(Color(1.0, 0.7, 0.3), 6.0), Vector3(1, 1.6, 1))
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.65, 0.32)
	l.light_energy = energy
	l.omni_range = 3.5
	l.position = pos + Vector3(0, 0.3, 0)
	root.add_child(l)
	r.fires.append(l)


func _rug(r: Dictionary, size: Vector2, pos: Vector3, base: Color, accent: Color) -> void:
	var root: Node3D = r.root
	_box(root, Vector3(size.x, 0.02, size.y), pos + Vector3(0, 0.012, 0), _mat(base, 1.0))
	_box(root, Vector3(size.x - 0.3, 0.022, size.y - 0.3), pos + Vector3(0, 0.014, 0), _mat(accent, 1.0))
	_box(root, Vector3(size.x - 0.6, 0.024, size.y - 0.6), pos + Vector3(0, 0.016, 0), _mat(base.lightened(0.15), 1.0))


func _table(r: Dictionary, pos: Vector3, size := Vector2(1.6, 0.9), h := 0.75) -> void:
	var root: Node3D = r.root
	_box(root, Vector3(size.x, 0.07, size.y), pos + Vector3(0, h, 0), _wood)
	var leg := _mat(Color(0.28, 0.18, 0.1))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_box(root, Vector3(0.08, h, 0.08), pos + Vector3(sx * (size.x * 0.5 - 0.1), h * 0.5, sz * (size.y * 0.5 - 0.1)), leg)
	_block(r, Vector2(pos.x, pos.z), maxf(size.x, size.y) * 0.5)


func _shelf(r: Dictionary, pos: Vector3, yaw: float, books := false) -> void:
	var root: Node3D = r.root
	var s := Node3D.new()
	root.add_child(s)
	s.position = pos
	s.rotation.y = yaw
	var w := _mat(Color(0.3, 0.19, 0.1))
	for k in 3:
		_box(s, Vector3(1.4, 0.05, 0.32), Vector3(0, 0.5 + k * 0.55, 0), w)
	_box(s, Vector3(0.05, 1.7, 0.32), Vector3(-0.7, 0.85, 0), w)
	_box(s, Vector3(0.05, 1.7, 0.32), Vector3(0.7, 0.85, 0), w)
	var cols := [Color(0.5, 0.15, 0.1), Color(0.15, 0.25, 0.4), Color(0.3, 0.35, 0.15), Color(0.55, 0.42, 0.2), Color(0.25, 0.12, 0.2)]
	for k in 3:
		var x := -0.6
		while x < 0.6:
			if books:
				var bw := _rng.randf_range(0.05, 0.1)
				var bh := _rng.randf_range(0.25, 0.4)
				_box(s, Vector3(bw, bh, 0.22), Vector3(x + bw * 0.5, 0.53 + k * 0.55 + bh * 0.5, 0), _mat(cols[_rng.randi() % cols.size()]))
				x += bw + 0.01
			else:
				var jr := _rng.randf_range(0.06, 0.1)
				var jh := _rng.randf_range(0.14, 0.26)
				var jc: Color = [Color(0.6, 0.45, 0.3), Color(0.3, 0.4, 0.35), Color(0.75, 0.7, 0.6)][_rng.randi() % 3]
				_cyl(s, jr * 0.8, jr, jh, Vector3(x + jr, 0.53 + k * 0.55 + jh * 0.5, 0), _mat(jc, 0.5), 10)
				x += jr * 2.0 + _rng.randf_range(0.04, 0.12)


func _bed(r: Dictionary, pos: Vector3, yaw: float, blanket: Color) -> void:
	var root: Node3D = r.root
	var b := Node3D.new()
	root.add_child(b)
	b.position = pos
	b.rotation.y = yaw
	_box(b, Vector3(1.0, 0.3, 2.0), Vector3(0, 0.15, 0), _mat(Color(0.3, 0.19, 0.1)))
	_box(b, Vector3(0.95, 0.12, 1.95), Vector3(0, 0.36, 0), _mat(Color(0.8, 0.75, 0.62), 1.0))
	_box(b, Vector3(0.98, 0.1, 1.3), Vector3(0, 0.45, 0.3), _mat(blanket, 1.0))
	_sphere(b, 0.22, Vector3(0, 0.48, -0.7), _mat(Color(0.88, 0.84, 0.74), 1.0), Vector3(1.6, 0.5, 1.0))
	_block(r, Vector2(pos.x, pos.z) + Vector2(0, -0.45).rotated(-yaw), 0.6)
	_block(r, Vector2(pos.x, pos.z) + Vector2(0, 0.45).rotated(-yaw), 0.6)


func _teapot(parent: Node3D, pos: Vector3) -> void:
	var copper := _mat(Color(0.7, 0.4, 0.2), 0.35, 0.8)
	_sphere(parent, 0.11, pos + Vector3(0, 0.1, 0), copper, Vector3(1, 0.85, 1))
	var spout := _cyl(parent, 0.015, 0.03, 0.14, pos + Vector3(0.12, 0.13, 0), copper, 8)
	spout.rotation.z = -0.9
	_sphere(parent, 0.03, pos + Vector3(0, 0.2, 0), copper)
	for k in 2:
		_cyl(parent, 0.045, 0.03, 0.05, pos + Vector3(-0.2 + k * 0.12, 0.025, 0.15), _mat(Color(0.92, 0.9, 0.82), 0.4), 10)


# ── убранство по хозяевам ────────────────────────────────────

func _elder(r: Dictionary) -> void:
	var root: Node3D = r.root
	_rug(r, Vector2(2.6, 1.8), Vector3(0.6, 0, 0.2), Color(0.5, 0.12, 0.08), Color(0.12, 0.18, 0.38))
	_table(r, Vector3(1.0, 0, -0.4))
	_teapot(root, Vector3(0.8, 0.79, -0.5))
	_candle(r, Vector3(1.5, 0.79, -0.65))
	_prop(root, "village/Bench_1.glb", 0.5, Vector3(1.0, 0, 0.35), PI)
	_prop(root, "village/Bench_1.glb", 0.5, Vector3(1.0, 0, -1.15))
	_shelf(r, Vector3(1.7, 0, -SIZE.y * 0.5 + 0.2), 0.0, true)
	_block(r, Vector2(1.7, -SIZE.y * 0.5 + 0.3), 0.5)
	_bed(r, Vector3(SIZE.x * 0.5 - 0.7, 0, 0.9), 0.0, Color(0.35, 0.3, 0.45))
	_prop(root, "village/Crate.glb", 0.55, Vector3(-SIZE.x * 0.5 + 0.5, 0, 1.6), 0.3)
	_block(r, Vector2(-SIZE.x * 0.5 + 0.5, 1.6), 0.45)
	# старые фонари на крюках — работа всей жизни
	for k in 3:
		var p := Vector3(-SIZE.x * 0.5 + 0.15, 1.9, -0.9 + k * 0.6)
		_box(root, Vector3(0.12, 0.2, 0.12), p, _mat(Color(0.12, 0.1, 0.08), 0.5, 0.6))
		_box(root, Vector3(0.09, 0.14, 0.09), p, _glow(Color(0.4, 0.3, 0.2), 0.2))


func _lia(r: Dictionary) -> void:
	var root: Node3D = r.root
	_rug(r, Vector2(2.2, 1.6), Vector3(0.2, 0, 0.4), Color(0.2, 0.32, 0.5), Color(0.6, 0.45, 0.15))
	_table(r, Vector3(1.6, 0, -1.2), Vector2(1.2, 0.8))
	_candle(r, Vector3(1.6, 0.79, -1.2), 0.9)
	_bed(r, Vector3(SIZE.x * 0.5 - 0.7, 0, 1.0), 0.0, Color(0.75, 0.4, 0.2))
	_bed(r, Vector3(-SIZE.x * 0.5 + 0.7, 0, 1.2), 0.0, Color(0.3, 0.4, 0.3))
	# рисунки Лии на стене: солнце, каким она его представляет
	var paper := _mat(Color(0.9, 0.86, 0.74), 1.0)
	var sun := _glow(Color(1.0, 0.75, 0.2), 0.25)
	for k in 4:
		var x := -0.6 + k * 0.75
		var y := 1.45 + (0.12 if k % 2 == 0 else -0.05)
		_box(root, Vector3(0.55, 0.45, 0.02), Vector3(x, y, -SIZE.y * 0.5 + 0.02), paper, Vector3(0, 0, _rng.randf_range(-0.08, 0.08)))
		var s := _cyl(root, 0.11 + k * 0.015, 0.11 + k * 0.015, 0.01, Vector3(x, y + 0.03, -SIZE.y * 0.5 + 0.04), sun, 14)
		s.rotation.x = PI / 2
		for ray in 8:
			var a := ray * TAU / 8.0
			_box(root, Vector3(0.025, 0.09, 0.01), Vector3(x + cos(a) * 0.19, y + 0.03 + sin(a) * 0.19, -SIZE.y * 0.5 + 0.04), sun, Vector3(0, 0, a - PI / 2))
	# деревянная лошадка
	var toy := _mat(Color(0.6, 0.4, 0.22))
	_box(root, Vector3(0.3, 0.12, 0.1), Vector3(-0.4, 0.2, 0.9), toy)
	_box(root, Vector3(0.08, 0.16, 0.08), Vector3(-0.27, 0.3, 0.9), toy)
	_box(root, Vector3(0.4, 0.04, 0.12), Vector3(-0.4, 0.06, 0.9), toy, Vector3(0, 0, 0.1))


func _herbal(r: Dictionary) -> void:
	var root: Node3D = r.root
	_rug(r, Vector2(2.4, 1.6), Vector3(0.6, 0, 0.5), Color(0.25, 0.3, 0.15), Color(0.5, 0.35, 0.15))
	_table(r, Vector3(1.4, 0, -1.4), Vector2(1.6, 0.7))
	_candle(r, Vector3(1.0, 0.79, -1.4))
	for k in 5:
		_cyl(root, 0.05, 0.06, 0.16, Vector3(1.2 + k * 0.14, 0.87, -1.35), _mat([Color(0.4, 0.55, 0.3), Color(0.6, 0.5, 0.3), Color(0.35, 0.3, 0.45)][k % 3], 0.4), 8)
	_prop(root, "village/Cauldron.glb", 0.55, Vector3(-SIZE.x * 0.5 + 2.75, 0.0, -SIZE.y * 0.5 + 0.7))
	_block(r, Vector2(-SIZE.x * 0.5 + 2.75, -SIZE.y * 0.5 + 0.7), 0.4)
	_shelf(r, Vector3(-0.2, 0, -SIZE.y * 0.5 + 0.2), 0.0, false)
	_block(r, Vector2(-0.2, -SIZE.y * 0.5 + 0.3), 0.5)
	_bed(r, Vector3(SIZE.x * 0.5 - 0.7, 0, 1.0), 0.0, Color(0.35, 0.4, 0.25))
	# пучки трав сушатся под балками
	var herb_cols := [Color(0.35, 0.5, 0.25), Color(0.55, 0.5, 0.25), Color(0.45, 0.3, 0.4), Color(0.3, 0.45, 0.35)]
	for k in 9:
		var p := Vector3(-SIZE.x * 0.5 + 0.8 + k * 0.7, WALL_H - 0.45, _rng.randf_range(-1.5, 1.0))
		var bunch := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.02
		cone.bottom_radius = 0.12
		cone.height = 0.4
		cone.radial_segments = 7
		bunch.mesh = cone
		bunch.material_override = _mat(herb_cols[k % herb_cols.size()], 1.0)
		bunch.position = p
		bunch.rotation.x = PI
		root.add_child(bunch)
		r.cut.append(bunch)
	# светящиеся грибы в банке — память о лесе
	_cyl(root, 0.1, 0.1, 0.22, Vector3(1.9, 0.89, -1.45), _glow(Color(0.35, 0.95, 0.85), 1.5), 10)


func _fisher(r: Dictionary) -> void:
	var root: Node3D = r.root
	_rug(r, Vector2(2.0, 1.4), Vector3(0.4, 0, 0.6), Color(0.3, 0.3, 0.25), Color(0.45, 0.35, 0.2))
	_table(r, Vector3(1.2, 0, -1.0), Vector2(1.2, 0.8))
	_candle(r, Vector3(1.4, 0.79, -1.0), 0.8)
	for k in 3:
		_prop(root, "village/Barrel.glb", 0.8, Vector3(SIZE.x * 0.5 - 0.5, 0, -1.6 + k * 0.75), k * 0.7)
		_block(r, Vector2(SIZE.x * 0.5 - 0.5, -1.6 + k * 0.75), 0.4)
	_bed(r, Vector3(-SIZE.x * 0.5 + 0.7, 0, 1.2), 0.0, Color(0.3, 0.32, 0.25))
	# сети на стене, вёсла, банка с гнилушкой
	var net := MeshInstance3D.new()
	var nm := QuadMesh.new()
	nm.size = Vector2(2.4, 1.3)
	net.mesh = nm
	var netmat := _mat(Color(0.4, 0.34, 0.24, 0.8))
	netmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	netmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	net.material_override = netmat
	net.position = Vector3(0.6, 1.6, -SIZE.y * 0.5 + 0.03)
	root.add_child(net)
	for k in 2:
		_box(root, Vector3(0.08, 2.2, 0.05), Vector3(-SIZE.x * 0.5 + 0.2, 1.1, -0.4 + k * 0.3), _mat(Color(0.4, 0.28, 0.16)), Vector3(0.1, 0, 0.08))
	_cyl(root, 0.08, 0.08, 0.18, Vector3(0.9, 0.87, -1.1), _glow(Color(0.5, 0.95, 0.6), 1.8), 10)


func _study(r: Dictionary) -> void:
	var root: Node3D = r.root
	_rug(r, Vector2(2.8, 2.0), Vector3(0.6, 0, 0.3), Color(0.15, 0.18, 0.35), Color(0.55, 0.42, 0.18))
	_table(r, Vector3(0.9, 0, 0.0), Vector2(1.8, 1.0))
	_candle(r, Vector3(0.3, 0.79, 0.2), 0.9)
	_candle(r, Vector3(1.6, 0.79, -0.2), 0.7)
	# астролябия и развёрнутая карта
	var brass := _mat(Color(0.75, 0.55, 0.25), 0.3, 0.85)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.16
	tm.outer_radius = 0.19
	ring.mesh = tm
	ring.material_override = brass
	ring.position = Vector3(1.2, 1.0, 0.1)
	ring.rotation = Vector3(PI / 2, 0.4, 0)
	root.add_child(ring)
	_cyl(root, 0.03, 0.05, 0.2, Vector3(1.2, 0.88, 0.1), brass, 8)
	_box(root, Vector3(0.7, 0.01, 0.5), Vector3(0.6, 0.79, -0.05), _mat(Color(0.85, 0.78, 0.6), 1.0), Vector3(0, 0.15, 0))
	for k in 2:
		_shelf(r, Vector3(-0.4 + k * 1.6, 0, -SIZE.y * 0.5 + 0.2), 0.0, true)
		_block(r, Vector2(-0.4 + k * 1.6, -SIZE.y * 0.5 + 0.3), 0.5)
	_shelf(r, Vector3(SIZE.x * 0.5 - 0.2, 0, -0.6), -PI / 2, true)
	_block(r, Vector2(SIZE.x * 0.5 - 0.3, -0.6), 0.5)
	# звёздная карта на стене — светится, как ночное небо
	var chart := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.3, 1.0)
	chart.mesh = q
	var cm := ShaderMaterial.new()
	cm.shader = load("res://shaders/star_chart.gdshader")
	chart.material_override = cm
	chart.position = Vector3(-SIZE.x * 0.5 + 0.03, 1.6, 0.6)
	chart.rotation.y = PI / 2
	root.add_child(chart)
	_bed(r, Vector3(-SIZE.x * 0.5 + 0.7, 0, 1.7), PI / 2, Color(0.2, 0.22, 0.4))


# ── вход, выход, вид ─────────────────────────────────────────

func room(i: int) -> Dictionary:
	return rooms[i]


func inside() -> bool:
	return current >= 0


## Вид сверху — разрез (без потолка и ближних стен); от первого лица — комната целиком
func set_view(first_person: bool) -> void:
	for r in rooms:
		for n in r.cut:
			(n as Node3D).visible = first_person


func update(dt: float) -> void:
	_t += dt
	if current < 0:
		return
	var r: Dictionary = rooms[current]
	var k := 0
	for l in r.fires:
		var base := 1.7 if (l as OmniLight3D).omni_range > 5.0 else 0.6
		(l as OmniLight3D).light_energy = base * (0.88 + 0.08 * sin(_t * 9.0 + k) + 0.06 * sin(_t * 23.0 + k * 2.3))
		k += 1
