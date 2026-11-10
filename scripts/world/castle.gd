class_name Castle
extends Node3D
## Руины замка: мост, ворота с решёткой, кольцо обвалившихся стен с башнями, двор с обломками,
## тронный зал с колоннами, гобеленами, фресками и троном.

var colliders: Array[Vector3] = []
var frescoes: Array = [] # {id, pos: Vector3}
var throne_seat := Vector3.ZERO
var _portcullis: Node3D
var _gate_t := 0.0 # 0 — опущена, 1 — поднята
var _stone: ShaderMaterial
var _stone_dark: ShaderMaterial
var _rng := RandomNumberGenerator.new()
var _rock_tex: Texture2D
var _candle: OmniLight3D
var _t := 0.0


func build() -> void:
	name = "Castle"
	_rng.seed = 1701
	_rock_tex = load("res://assets/textures/ground/Rock030_color.jpg")
	_stone = ShaderMaterial.new()
	_stone.shader = load("res://shaders/stone.gdshader")
	_stone.set_shader_parameter("rock_tex", _rock_tex)
	_stone.set_shader_parameter("center", Vector3(CastleLayout.CENTER.x, 0, CastleLayout.CENTER.y))
	_stone.set_shader_parameter("base_y", CastleLayout.PLATEAU_H)
	_stone.set_shader_parameter("tint", 0.8)
	_stone.set_shader_parameter("fade_near", true)
	_stone_dark = _stone.duplicate()
	_stone_dark.set_shader_parameter("tint", 0.6)
	_bridge()
	_gate()
	_outer_walls()
	_courtyard()
	_hall()


func _h(p: Vector2) -> float:
	return Terrain.height_at(p.x, p.y)


func _mat(c: Color, rough := 0.9, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


func _mesh(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


func _cyl(r: float, h: float, segs := 12) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r * 1.05
	c.height = h
	c.radial_segments = segs
	return c


## Стена от a до b: высота «обрушена» кусками; препятствия вдоль
func _wall(a: Vector2, b: Vector2, hmin: float, hmax: float, thick := 1.0, mat: Material = null, collide := true) -> void:
	var len := a.distance_to(b)
	var dir := (b - a) / len
	var n := maxi(1, int(len / 2.0))
	for i in n:
		var p0 := a + dir * len * i / n
		var p1 := a + dir * len * (i + 1) / n
		var mid := (p0 + p1) * 0.5
		var hh := _rng.randf_range(hmin, hmax)
		var y := _h(mid) - 0.3
		var seg := _mesh(self, _box(Vector3(thick, hh, len / n + 0.02)), mat if mat else _stone, Vector3(mid.x, y + hh * 0.5, mid.y), Vector3(0, atan2(dir.x, dir.y), 0))
		# зубцы на целых участках
		if hh > hmax * 0.8 and _rng.randf() < 0.6:
			_mesh(self, _box(Vector3(thick * 1.05, 0.5, 0.5)), mat if mat else _stone, Vector3(mid.x, y + hh + 0.25, mid.y), Vector3(0, atan2(dir.x, dir.y), 0))
		seg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	if collide:
		var k := int(len / 0.8)
		for i in k + 1:
			var p := a + dir * len * i / maxf(k, 1)
			colliders.append(Vector3(p.x, p.y, thick * 0.5 + 0.15))


func _rubble(c: Vector2, r: float, count: int) -> void:
	for i in count:
		var p := c + Vector2(_rng.randf_range(-r, r), _rng.randf_range(-r, r))
		var s := _rng.randf_range(0.3, 0.9)
		var rock := Props.make("nature/Rock_%d.glb" % _rng.randi_range(1, 5), s)
		add_child(rock)
		rock.global_position = Vector3(p.x, _h(p) - s * 0.2, p.y)
		rock.rotation = Vector3(_rng.randf_range(-0.4, 0.4), _rng.randf() * TAU, _rng.randf_range(-0.4, 0.4))
		Props.settle(rock)
		if s > 0.6:
			colliders.append(Vector3(p.x, p.y, s * 0.6))


# ── мост ────────────────────────────────────────────────────

func _bridge() -> void:
	var a := CastleLayout.bridge_start
	var b := CastleLayout.GATE
	var len := a.distance_to(b)
	var dir := (b - a) / len
	var side := Vector2(dir.y, -dir.x)
	var n := int(len / 1.0)
	var yaw := atan2(dir.x, dir.y)
	for i in n:
		var p := a + dir * (i + 0.5) * len / n
		var y := CastleLayout.deck_height(p.x, p.y)
		_mesh(self, _box(Vector3(CastleLayout.BRIDGE_HALF * 2.0 + 0.6, 0.5, len / n + 0.05)), _stone_dark, Vector3(p.x, y - 0.25, p.y), Vector3(0, yaw, 0))
		# парапеты, местами обвалились
		for sg in [-1.0, 1.0]:
			if _rng.randf() < 0.15:
				continue
			var q: Vector2 = p + side * sg * (CastleLayout.BRIDGE_HALF + 0.15)
			_mesh(self, _box(Vector3(0.3, 0.7, len / n + 0.05)), _stone, Vector3(q.x, y + 0.3, q.y), Vector3(0, yaw, 0))
		# опоры-арки до воды
		if i % 6 == 3:
			var depth := y - Terrain.height_at(p.x, p.y) + 0.5
			_mesh(self, _box(Vector3(CastleLayout.BRIDGE_HALF * 2.0 + 0.4, depth, 1.4)), _stone_dark, Vector3(p.x, y - 0.5 - depth * 0.5, p.y), Vector3(0, yaw, 0))


# ── ворота ──────────────────────────────────────────────────

func _gate() -> void:
	var g := CastleLayout.GATE
	var y := _h(g + Vector2(0, 2))
	for sx in [-3.4, 3.4]:
		var p: Vector2 = g + Vector2(sx, 1.0)
		_mesh(self, _cyl(1.7, 7.0, 14), _stone, Vector3(p.x, y + 3.2, p.y))
		_mesh(self, _cyl(1.85, 0.5, 14), _stone_dark, Vector3(p.x, y + 6.9, p.y))
		colliders.append(Vector3(p.x, p.y, 1.8))
	_mesh(self, _box(Vector3(5.2, 1.6, 1.6)), _stone, Vector3(g.x, y + 4.8, g.y + 1.0))
	# решётка
	_portcullis = Node3D.new()
	add_child(_portcullis)
	_portcullis.global_position = Vector3(g.x, y, g.y + 0.4)
	var iron := _mat(Color(0.12, 0.11, 0.1), 0.5, 0.7)
	for i in 9:
		_mesh(_portcullis, _box(Vector3(0.08, 4.0, 0.08)), iron, Vector3(-1.6 + i * 0.4, 2.0, 0))
	for j in 5:
		_mesh(_portcullis, _box(Vector3(3.4, 0.08, 0.08)), iron, Vector3(0, 0.4 + j * 0.85, 0))


func set_gate(open: bool, instant := false) -> void:
	if instant:
		_gate_t = 1.0 if open else 0.0
		_apply_gate()


func _apply_gate() -> void:
	var y := _h(CastleLayout.GATE + Vector2(0, 2))
	_portcullis.global_position.y = y + _gate_t * 3.6


# ── внешние стены ───────────────────────────────────────────

func _outer_walls() -> void:
	var c := CastleLayout.CENTER
	var R := CastleLayout.WALL_R
	var segs := 20
	var gate_a := atan2(CastleLayout.GATE.y - c.y, CastleLayout.GATE.x - c.x)
	var broken := [5, 11, 15]
	for i in segs:
		var a0 := gate_a + TAU * (i + 0.5) / segs
		var a1 := gate_a + TAU * (i + 1.5) / segs
		if i == segs - 1:
			continue # проём ворот
		var p0 := c + Vector2(cos(a0), sin(a0)) * R
		var p1 := c + Vector2(cos(a1), sin(a1)) * R
		if i in broken:
			_rubble((p0 + p1) * 0.5, 2.5, 7)
			_wall(p0, p0.lerp(p1, 0.3), 0.6, 1.8)
			continue
		_wall(p0, p1, 3.0, 5.5, 1.2)
		if i % 4 == 1: # башни
			_mesh(self, _cyl(1.9, _rng.randf_range(5.0, 8.0), 14), _stone, Vector3(p1.x, _h(p1) + 2.5, p1.y))
			colliders.append(Vector3(p1.x, p1.y, 2.0))
	# стены от ворот к кольцу
	for sx in [-1.0, 1.0]:
		var a := CastleLayout.GATE + Vector2(sx * 4.8, 1.0)
		var b := c + Vector2(cos(gate_a - sx * TAU * 0.5 / segs), sin(gate_a - sx * TAU * 0.5 / segs)) * R
		_wall(a, b, 3.5, 5.0, 1.2)


# ── двор ────────────────────────────────────────────────────

func _courtyard() -> void:
	var c := CastleLayout.CENTER
	_rubble(c + Vector2(-12.0, -6.0), 3.0, 8)
	_rubble(c + Vector2(11.0, -9.0), 2.5, 6)
	_rubble(c + Vector2(-14.0, 6.0), 2.5, 6)
	# упавшие колонны
	for k in 4:
		var p: Vector2 = c + [Vector2(-8.0, -10.0), Vector2(9.0, -3.0), Vector2(-11.0, 2.0), Vector2(4.0, -14.0)][k]
		var col := _mesh(self, _cyl(0.45, 3.4, 10), _stone, Vector3(p.x, _h(p) + 0.4, p.y), Vector3(PI / 2, _rng.randf() * TAU, 0))
		colliders.append(Vector3(p.x, p.y, 1.2))
	# обломок колонны стоя
	for k in 3:
		var p: Vector2 = c + [Vector2(-5.0, -13.0), Vector2(6.0, -12.0), Vector2(-9.0, 8.0)][k]
		_mesh(self, _cyl(0.45, _rng.randf_range(1.2, 2.6), 10), _stone, Vector3(p.x, _h(p) + 0.8, p.y))
		colliders.append(Vector3(p.x, p.y, 0.6))
	# руина башни для пятого маяка — каменный круг
	var bp := CastleLayout.BEACON
	_mesh(self, _cyl(3.0, 0.6, 18), _stone_dark, Vector3(bp.x, _h(bp) + 0.1, bp.y))


# ── тронный зал ─────────────────────────────────────────────

func _hall() -> void:
	var mn := CastleLayout.HALL_MIN
	var mx := CastleLayout.HALL_MAX
	var door := CastleLayout.HALL_DOOR
	# стены (южная — с проёмом)
	_wall(Vector2(mn.x, mx.y), Vector2(-door, mx.y), 3.5, 5.0, 0.9)
	_wall(Vector2(door, mx.y), Vector2(mx.x, mx.y), 3.0, 5.0, 0.9)
	_wall(Vector2(mn.x, mn.y), Vector2(mn.x, mx.y), 3.8, 5.5, 0.9)
	_wall(Vector2(mx.x, mn.y), Vector2(mx.x, mx.y), 2.5, 5.5, 0.9)
	_wall(Vector2(mn.x, mn.y), Vector2(mx.x, mn.y), 4.5, 5.5, 0.9)
	# колонны
	for z in [94.0, 98.0, 102.0]:
		for x in [-3.8, 3.8]:
			var p := Vector2(x, z)
			var hh := _rng.randf_range(3.5, 5.0) if _rng.randf() < 0.7 else _rng.randf_range(1.2, 2.2)
			_mesh(self, _cyl(0.38, hh, 10), _stone, Vector3(p.x, _h(p) + hh * 0.5, p.y))
			_mesh(self, _box(Vector3(1.0, 0.3, 1.0)), _stone_dark, Vector3(p.x, _h(p) + 0.15, p.y))
			colliders.append(Vector3(p.x, p.y, 0.5))
	# ковровая дорожка к трону (истлевшая)
	var rug := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(2.0, 14.0)
	rug.mesh = pm
	var rm := ShaderMaterial.new()
	rm.shader = load("res://shaders/tapestry.gdshader")
	rm.set_shader_parameter("cloth", Color(0.35, 0.06, 0.06))
	rm.set_shader_parameter("seed", 9.0)
	rug.material_override = rm
	add_child(rug)
	rug.global_position = Vector3(0, _h(Vector2(0, 99)) + 0.02, 99.0)
	# возвышение и трон
	var tp := CastleLayout.THRONE
	var ty := _h(tp)
	_mesh(self, _box(Vector3(5.0, 0.35, 3.2)), _stone_dark, Vector3(tp.x, ty + 0.17, tp.y - 0.6))
	_mesh(self, _box(Vector3(5.6, 0.2, 3.8)), _stone_dark, Vector3(tp.x, ty + 0.05, tp.y - 0.6))
	var gold := _mat(Color(0.55, 0.42, 0.18), 0.4, 0.8)
	var velvet := _mat(Color(0.3, 0.06, 0.08), 1.0)
	_mesh(self, _box(Vector3(1.2, 0.5, 1.0)), gold, Vector3(tp.x, ty + 0.6, tp.y))
	_mesh(self, _box(Vector3(1.0, 0.1, 0.85)), velvet, Vector3(tp.x, ty + 0.88, tp.y + 0.02))
	_mesh(self, _box(Vector3(1.2, 1.9, 0.18)), gold, Vector3(tp.x, ty + 1.75, tp.y - 0.45))
	_mesh(self, _box(Vector3(0.9, 1.4, 0.05)), velvet, Vector3(tp.x, ty + 1.6, tp.y - 0.34))
	for sx in [-0.62, 0.62]:
		_mesh(self, _box(Vector3(0.14, 0.5, 0.9)), gold, Vector3(tp.x + sx, ty + 1.05, tp.y))
	throne_seat = Vector3(tp.x, ty + 0.35, tp.y + 0.05)
	colliders.append(Vector3(tp.x, tp.y - 0.3, 1.0))
	# одна свеча у трона — единственный свет короля
	var cpos := Vector2(tp.x + 1.4, tp.y + 0.4)
	_mesh(self, _cyl(0.12, 1.1, 8), gold, Vector3(cpos.x, ty + 0.9, cpos.y))
	var flame := _mesh(self, SphereMesh.new(), _glow(Color(1.0, 0.68, 0.3), 8.0), Vector3(cpos.x, ty + 1.62, cpos.y))
	flame.scale = Vector3(0.04, 0.08, 0.04)
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_candle = OmniLight3D.new()
	_candle.light_color = Color(1.0, 0.62, 0.3)
	_candle.light_energy = 0.9
	_candle.omni_range = 4.5
	_candle.omni_attenuation = 1.4
	add_child(_candle)
	_candle.global_position = Vector3(cpos.x, ty + 1.8, cpos.y)
	# гобелены
	for i in CastleLayout.TAPESTRIES.size():
		var p: Vector2 = CastleLayout.TAPESTRIES[i]
		var q := QuadMesh.new()
		q.size = Vector2(1.8, 3.2)
		var m := ShaderMaterial.new()
		m.shader = load("res://shaders/tapestry.gdshader")
		m.set_shader_parameter("cloth", [Color(0.4, 0.08, 0.08), Color(0.12, 0.16, 0.35)][i % 2])
		m.set_shader_parameter("seed", float(i) * 3.7)
		var rot := Vector3(0, PI / 2 * (1.0 if p.x < 0 else -1.0), 0) if absf(p.x) > 6.0 else Vector3.ZERO
		var off := Vector3(0.48 * (1.0 if p.x < 0 else -1.0), 0, 0) if absf(p.x) > 6.0 else Vector3(0, 0, 0.48)
		_mesh(self, q, m, Vector3(p.x, _h(p) + 2.4, p.y) + off, rot)
	# фрески
	for f in CastleLayout.FRESCOES:
		var p: Vector2 = f.pos
		var q := QuadMesh.new()
		q.size = Vector2(3.0, 2.0)
		var m := ShaderMaterial.new()
		m.shader = load("res://shaders/fresco.gdshader")
		m.set_shader_parameter("picture", CastleLayout.FRESCOES.find(f))
		var sgn: float = f.side
		var pos := Vector3(p.x - sgn * 0.3, _h(p) + 2.0, p.y)
		_mesh(self, q, m, pos, Vector3(0, -PI / 2 * sgn, 0))
		frescoes.append({id = f.id, pos = pos})


func _glow(c: Color, e: float) -> StandardMaterial3D:
	var m := _mat(c)
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = e
	return m


func update_castle(dt: float, gate_open: bool) -> void:
	_t += dt
	var want := 1.0 if gate_open else 0.0
	if absf(_gate_t - want) > 0.001:
		_gate_t = move_toward(_gate_t, want, dt / 4.0) # решётка поднимается медленно, со скрипом
		_apply_gate()
	_candle.light_energy = 0.9 * (0.9 + 0.1 * sin(_t * 8.0) * sin(_t * 5.1))
