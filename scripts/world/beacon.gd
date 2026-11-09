class_name Beacon
extends Node3D
## Маяк: каменная башня с чашей огня на холме. Зажигается фонарём — и вокруг
## расходится волна оживания: цвет, рассветный свет, трава, цветы, звуки.
## Маяк — точка сохранения.

signal lit_changed

const MAX_RADIUS := 25.0
const TOWER_H := 4.2
const IGNITE_AT := 1.3 # когда искра долетает до чаши
const WAVE_START := 1.9
const WAVE_TIME := 10.0 # сколько расходится волна

static var all: Array[Beacon] = []

var index := 0
var lit := false
var radius := 0.0 # радиус ожившей области
var wave := -1.0 # радиус фронта волны (-1 — нет волны)
var bowl_world := Vector3.ZERO
var collider := Vector3.ZERO

var _t := -1.0 # время с начала зажигания
var _from := Vector3.ZERO # откуда летит искра (фонарь)
var _fire_light: OmniLight3D
var _dawn_light: OmniLight3D
var _flames: GPUParticles3D
var _embers: GPUParticles3D
var _burst: GPUParticles3D
var _pollen: GPUParticles3D
var _spark: Node3D
var _spark_trail: GPUParticles3D
var _flower_root: Node3D
var _ash: MeshInstance3D
var _sfx_done := false
var sound: Soundscape


func build(idx: int, pos: Vector3, stone_tex: Texture2D) -> void:
	index = idx
	name = "Beacon_%d" % idx
	position = pos
	all.append(self)
	collider = Vector3(pos.x, pos.z, 1.55)

	var stone := ShaderMaterial.new()
	stone.shader = load("res://shaders/stone.gdshader")
	stone.set_shader_parameter("rock_tex", stone_tex)
	stone.set_shader_parameter("center", pos)
	stone.set_shader_parameter("base_y", pos.y - 0.6)
	var dark_stone := stone.duplicate()
	dark_stone.set_shader_parameter("tint", 0.75)

	_cyl(1.75, 1.6, 0.7, Vector3(0, -0.25, 0), stone, 14) # ступень-основание
	_cyl(1.2, 1.4, 0.5, Vector3(0, 0.35, 0), dark_stone, 14) # цоколь
	_cyl(0.95, 1.15, TOWER_H - 0.9, Vector3(0, 0.6 + (TOWER_H - 0.9) / 2.0, 0), stone, 14) # башня
	_cyl(1.25, 1.05, 0.35, Vector3(0, TOWER_H - 0.1, 0), dark_stone, 14) # карниз
	for i in 8: # зубцы
		var a := i * TAU / 8.0
		var b := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.4, 0.35, 0.3)
		b.mesh = bm
		b.material_override = stone
		b.position = Vector3(cos(a) * 1.08, TOWER_H + 0.25, sin(a) * 1.08)
		b.rotation.y = -a
		add_child(b)

	# железная чаша на ножке
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.09, 0.08, 0.075)
	iron.metallic = 0.7
	iron.roughness = 0.5
	_cyl(0.18, 0.22, 0.35, Vector3(0, TOWER_H + 0.25, 0), iron, 10)
	_cyl(0.85, 0.35, 0.45, Vector3(0, TOWER_H + 0.62, 0), iron, 16)
	var rim := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.82
	tm.outer_radius = 0.92
	rim.mesh = tm
	rim.material_override = iron
	rim.position = Vector3(0, TOWER_H + 0.84, 0)
	add_child(rim)
	# зола в погасшей чаше
	_ash = _cyl(0.78, 0.78, 0.04, Vector3(0, TOWER_H + 0.78, 0), _mat(Color(0.22, 0.2, 0.19)), 16)
	bowl_world = pos + Vector3(0, TOWER_H + 0.95, 0)

	# огонь, искры, вспышка
	_flames = Fx.flames()
	_flames.position = Vector3(0, TOWER_H + 0.95, 0)
	_flames.emitting = false
	add_child(_flames)
	_embers = Fx.embers()
	_embers.position = _flames.position
	_embers.emitting = false
	add_child(_embers)
	_burst = Fx.burst()
	_burst.position = _flames.position
	add_child(_burst)

	_fire_light = OmniLight3D.new()
	_fire_light.light_color = Color(1.0, 0.62, 0.28)
	_fire_light.position = Vector3(0, TOWER_H + 1.5, 0)
	_fire_light.omni_range = 18.0
	_fire_light.omni_attenuation = 1.1
	_fire_light.light_energy = 0.0
	_fire_light.shadow_enabled = Quality.level == "high"
	_fire_light.light_volumetric_fog_energy = 2.0
	_fire_light.visible = false
	add_child(_fire_light)

	# «рассветный» свет над ожившей областью: мягкий, тёплый, без теней
	_dawn_light = OmniLight3D.new()
	_dawn_light.light_color = Color(1.0, 0.8, 0.68)
	_dawn_light.position = Vector3(0, 14.0, 0)
	_dawn_light.omni_range = 1.0
	_dawn_light.omni_attenuation = 0.6
	_dawn_light.light_energy = 0.0
	_dawn_light.light_volumetric_fog_energy = 0.4
	_dawn_light.visible = false
	add_child(_dawn_light)

	_pollen = Fx.pollen(MAX_RADIUS * 0.85)
	_pollen.position = Vector3(0, -2.0, 0)
	_pollen.emitting = false
	add_child(_pollen)

	# искра, летящая из фонаря в чашу
	_spark = Node3D.new()
	_spark.top_level = true
	_spark.visible = false
	add_child(_spark)
	var sm := MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = 0.06
	sp.height = 0.12
	sm.mesh = sp
	var smat := StandardMaterial3D.new()
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.albedo_color = Color(1.0, 0.8, 0.45)
	smat.emission_enabled = true
	smat.emission = Color(1.0, 0.7, 0.35)
	smat.emission_energy_multiplier = 16.0
	sm.material_override = smat
	_spark.add_child(sm)
	_spark_trail = Fx.embers(60)
	(_spark_trail.process_material as ParticleProcessMaterial).emission_sphere_radius = 0.05
	(_spark_trail.process_material as ParticleProcessMaterial).initial_velocity_max = 0.5
	_spark_trail.lifetime = 0.9
	_spark_trail.emitting = false
	_spark_trail.top_level = true
	add_child(_spark_trail)


func set_flowers(node: Node3D) -> void:
	_flower_root = node
	add_child(node)


func _cyl(top: float, bottom: float, h: float, pos: Vector3, mat: Material, segs := 12) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = top
	cm.bottom_radius = bottom
	cm.height = h
	cm.radial_segments = segs
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
	return mi


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	return m


func near(p: Vector3, dist := 3.4) -> bool:
	return Vector2(p.x - position.x, p.z - position.z).length() < dist


## Зажечь (from — где сейчас огонь фонаря)
func light_up(from: Vector3) -> void:
	if lit or _t >= 0.0:
		return
	_from = from
	_t = 0.0
	_sfx_done = false
	lit = true
	lit_changed.emit()


func is_animating() -> bool:
	return _t >= 0.0


## Уже зажжённый маяк при загрузке сохранения
func set_lit_instant() -> void:
	lit = true
	radius = MAX_RADIUS
	wave = -1.0
	_ash.visible = false
	_flames.emitting = true
	_embers.emitting = true
	_pollen.emitting = true
	_fire_light.visible = true
	_fire_light.light_energy = 3.0
	_dawn_light.visible = true
	_dawn_light.omni_range = MAX_RADIUS + 3.0
	_dawn_light.light_energy = 1.3


func _process(dt: float) -> void:
	if lit and _t < 0.0:
		# огонь живёт: мерцание
		var f := 1.0 + sin(Time.get_ticks_msec() * 0.011) * 0.06 + sin(Time.get_ticks_msec() * 0.027) * 0.05
		_fire_light.light_energy = 3.0 * f
		return
	if _t < 0.0:
		return
	_t += dt

	# 1) искра летит из фонаря в чашу по дуге
	if _t < IGNITE_AT:
		var u := _t / IGNITE_AT
		var e := u * u * (3.0 - 2.0 * u)
		var p := _from.lerp(bowl_world, e) + Vector3(0, sin(e * PI) * 2.2, 0)
		_spark.visible = true
		_spark.global_position = p
		_spark_trail.global_position = p
		_spark_trail.emitting = true
	elif not _sfx_done:
		# 2) вспышка: огонь вспыхивает, сноп искр
		_sfx_done = true
		_spark.visible = false
		_spark_trail.emitting = false
		_ash.visible = false
		_flames.emitting = true
		_embers.emitting = true
		_burst.restart()
		_burst.emitting = true
		_fire_light.visible = true
		if sound:
			sound.sfx("ignite", 0.55)

	if _t >= IGNITE_AT:
		var k := _t - IGNITE_AT
		_fire_light.light_energy = 3.0 + 14.0 * exp(-k * 2.2) # яркая вспышка, затем ровный огонь

	# 3) волна оживания расходится от маяка
	if _t >= WAVE_START:
		var w := clampf((_t - WAVE_START) / WAVE_TIME, 0.0, 1.0)
		var eased := 1.0 - pow(1.0 - w, 2.2)
		wave = eased * (MAX_RADIUS + 6.0)
		radius = maxf(radius, wave)
		_dawn_light.visible = true
		_dawn_light.omni_range = maxf(1.0, minf(wave, MAX_RADIUS) + 3.0)
		_dawn_light.light_energy = 1.3 * minf(1.0, w * 2.0)
		if w > 0.15 and not _pollen.emitting:
			_pollen.emitting = true
		if w >= 1.0:
			wave = -1.0
			radius = MAX_RADIUS
			_t = -1.0


## Насколько ожило место (0..1) — та же формула, что в шейдерах
static func restore_at(p: Vector3) -> float:
	var best := 0.0
	for b in all:
		if b.radius <= 0.01:
			continue
		var d := Vector2(p.x - b.position.x, p.z - b.position.z).length()
		best = maxf(best, 1.0 - Terrain.ss(b.radius - 6.0, b.radius, d))
	return best


static func update_globals() -> void:
	var wave_v := Vector4(0, 0, 0, -1)
	for i in 5:
		var v := Vector4.ZERO
		if i < all.size():
			var b := all[i]
			v = Vector4(b.position.x, b.position.y, b.position.z, b.radius)
			if b.wave >= 0.0:
				wave_v = Vector4(b.position.x, b.position.y, b.position.z, b.wave)
		RenderingServer.global_shader_parameter_set("beacon_%d" % i, v)
	RenderingServer.global_shader_parameter_set("beacon_wave", wave_v)


## Найти вершину холма для маяка: самая высокая точка в кольце вокруг старта
static func find_hilltop(start: Vector3, min_d: float, max_d: float) -> Vector3:
	var best := Vector3.ZERO
	var best_h := -INF
	var a := 0.0
	while a < TAU:
		var r := min_d
		while r <= max_d:
			var x := start.x + cos(a) * r
			var z := start.z + sin(a) * r
			var h := Terrain.height_at(x, z)
			# предпочитаем ровную вершину
			var flat := Terrain.normal_at(x, z).y
			var score := h + flat * 2.0
			if score > best_h and Vector2(x, z).length() < Terrain.ISLAND_RADIUS - 8.0:
				best_h = score
				best = Vector3(x, h, z)
			r += 1.0
		a += TAU / 72.0
	return best
