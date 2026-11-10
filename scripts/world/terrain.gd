class_name Terrain
extends RefCounted
## Рельеф острова ~80×80 м (центр в 0,0), вода на высоте 0.
## Одни и те же функции используют меш земли, трава, деревья, звук шагов.

const ISLAND_RADIUS := 40.0
const WATER_LEVEL := 0.0
## Прямоугольник мира: южный остров с деревней + лесной массив на севере
const MIN := Vector2(-122.0, -116.0)
const MAX := Vector2(116.0, 126.0)
const STEP := 0.6
## Для совместимости (некоторые системы ещё раскладывают по острову)
const SIZE := 140.0
const SEGS := 256

static var _hills: FastNoiseLite
static var _bumps: FastNoiseLite
static var _coast: FastNoiseLite
static var _surf: FastNoiseLite
static var _surf2: FastNoiseLite

## Карты для шейдеров (трава, вода): высота и веса материалов
static var height_tex: ImageTexture
static var weight_tex: ImageTexture
## Для карты: высоты (R), брусчатка (R), дорога (G), чаща (B)
static var height_img: Image
static var info_img: Image


static func _static_init() -> void:
	_hills = _noise(7, 0.035, 4)
	_bumps = _noise(8, 0.18, 2)
	_coast = _noise(13, 0.03, 3)
	_surf = _noise(29, 0.08, 3)
	_surf2 = _noise(31, 0.4, 2)


static func _noise(seed_value: int, freq: float, octaves: int) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = seed_value
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = freq
	n.fractal_type = FastNoiseLite.FRACTAL_FBM
	n.fractal_octaves = octaves
	return n


## smoothstep, который работает и при e0 > e1
static func ss(e0: float, e1: float, x: float) -> float:
	var t := clampf((x - e0) / (e1 - e0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


static func height_at(x: float, z: float) -> float:
	var h := raw_height(x, z)
	# деревня стоит на выровненной площадке
	var f := VillageLayout.flatten(x, z)
	if f > 0.0:
		h = lerpf(h, VillageLayout.plateau + _bumps.get_noise_2d(x, z) * 0.12, f)
	# поляна лесного маяка — ровная
	var bf := 1.0 - ss(6.0, 10.0, Vector2(x, z).distance_to(ForestLayout.node("B")))
	if bf > 0.0:
		h = lerpf(h, _forest_clearing_h, bf)
	return h


static var _forest_clearing_h := 0.0


static func setup() -> void:
	var b := ForestLayout.node("B")
	_forest_clearing_h = raw_height(b.x, b.y) + 0.4


## Суша (0..1): остров с деревней и лесной массив
static func land_mask(x: float, z: float) -> float:
	var m := 0.0
	for area in [[Vector2.ZERO, ISLAND_RADIUS], [ForestLayout.CENTER, ForestLayout.RADIUS], [MountainLayout.CENTER, MountainLayout.RADIUS], [CastleLayout.CENTER, CastleLayout.RADIUS]]:
		var c: Vector2 = area[0]
		var r: float = area[1]
		var d := Vector2(x, z).distance_to(c)
		var coast := r * (0.9 + 0.22 * _coast.get_noise_2d(x, z))
		m = maxf(m, ss(coast + 3.0, coast - 9.0, d))
	return m


## Рельеф без деревни
static func raw_height(x: float, z: float) -> float:
	var d := sqrt(x * x + z * z)
	var island := land_mask(x, z)
	var hills := _hills.get_noise_2d(x, z)
	var bumps := _bumps.get_noise_2d(x + 40.0, z) * 0.3
	var centre := ss(26.0, 0.0, d) * 1.6
	var land := 1.0 + centre + (hills * 0.5 + 0.5) * 4.0 + bumps
	var h := island * land - (1.0 - island) * 3.5
	# горы на западе
	var mm := MountainLayout.mask(x, z)
	if mm > 0.0:
		h = lerpf(h, MountainLayout.height(x, z, h), mm)
	# перешеек: тропа от деревни к подножию гор идёт по невысокому мысу
	if x < -20.0 and x > -50.0:
		var st := MountainLayout.stair_info(x, z)
		if st.x < 8.0:
			var bridge := lerpf(-3.5, st.y, 1.0 - ss(3.0, 8.0, st.x + _bumps.get_noise_2d(x, z) * 1.5))
			h = maxf(h, bridge)
	# островок замка на юге
	var cm := CastleLayout.mask(x, z)
	if cm > 0.0:
		h = lerpf(h, CastleLayout.height(x, z, h), cm)
	# топь на востоке: низина с кочками, омутами и трясинами
	var sm := SwampLayout.mask(x, z)
	if sm > 0.0:
		h = lerpf(h, SwampLayout.height(x, z), sm)
	return h


static func normal_at(x: float, z: float) -> Vector3:
	var e := 0.25
	var hx := height_at(x + e, z) - height_at(x - e, z)
	var hz := height_at(x, z + e) - height_at(x, z - e)
	return Vector3(-hx, 2.0 * e, -hz).normalized()


## Веса (трава, земля, камень)
static func weights_for(x: float, z: float, h: float, slope: float) -> Vector3:
	var n := _surf.get_noise_2d(x, z)
	var n2 := _surf2.get_noise_2d(x + 11.0, z)
	var rock := ss(0.1, 0.22, slope + n2 * 0.04)
	rock = maxf(rock, ss(0.32, 0.5, n * 0.8 + n2 * 0.25) * 0.9) # каменистые плеши
	var dirt := ss(0.9, 0.25, h) # берег — голая земля
	dirt = maxf(dirt, ss(0.12, 0.32, -n + n2 * 0.2)) # тропинки и проплешины
	dirt *= 1.0 - rock
	var mtn := MountainLayout.mask(x, z)
	if mtn > 0.0:
		rock = maxf(rock, ss(0.18, 0.35, slope) * mtn)
		dirt *= 1.0 - mtn * ss(2.0, 5.0, h)
	var sm := SwampLayout.mask(x, z)
	if sm > 0.0:
		rock *= 1.0 - sm
		dirt = lerpf(dirt, clampf(0.6 - h * 0.6, 0.2, 1.0), sm)
	var grass := maxf(0.0, 1.0 - rock - dirt)
	var s := grass + dirt + rock
	return Vector3(grass, dirt, rock) / s


static func weights_at(x: float, z: float) -> Vector3:
	return weights_for(x, z, height_at(x, z), 1.0 - normal_at(x, z).y)


## "grass" | "dirt" | "rock" | "water" — для звука шагов
static func surface_at(x: float, z: float) -> String:
	if SwampLayout.on_boardwalk(x, z):
		return "wood"
	if height_at(x, z) < WATER_LEVEL + 0.08:
		return "water"
	var w := weights_at(x, z)
	if w.z >= w.x and w.z >= w.y:
		return "rock"
	if w.y >= w.x:
		return "dirt"
	return "grass"


## Луч из камеры → точка на земле (для тапа/клика)
static func raycast(origin: Vector3, dir: Vector3) -> Variant:
	var t := 0.0
	var prev := origin
	while t < 250.0:
		t += 0.3
		var p := origin + dir * t
		if p.y <= height_at(p.x, p.z):
			# уточняем делением пополам
			var a := prev
			var b := p
			for i in 12:
				var m := (a + b) * 0.5
				if m.y <= height_at(m.x, m.z):
					b = m
				else:
					a = m
			return b
		prev = p
	return null


## Размер карт высот/весов (пиксели)
static func map_res() -> Vector2i:
	return Vector2i(int(round((MAX.x - MIN.x) / STEP)) + 1, int(round((MAX.y - MIN.y) / STEP)) + 1)


## Передать шейдеру карту острова (трава, вода, Тени)
static func apply_map(mat: ShaderMaterial) -> void:
	var r := map_res()
	mat.set_shader_parameter("height_map", height_tex)
	mat.set_shader_parameter("weight_map", weight_tex)
	mat.set_shader_parameter("map_min", MIN)
	mat.set_shader_parameter("map_step", STEP)
	mat.set_shader_parameter("map_res", Vector2(r.x, r.y))


## Строит меш земли и карты высот/весов
static func build() -> MeshInstance3D:
	var r := map_res()
	var nx := r.x
	var nz := r.y
	var heights := PackedFloat32Array()
	heights.resize(nx * nz)
	for j in nz:
		for i in nx:
			heights[j * nx + i] = height_at(MIN.x + i * STEP, MIN.y + j * STEP)

	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	verts.resize(nx * nz)
	normals.resize(nx * nz)
	colors.resize(nx * nz)
	var himg := Image.create(nx, nz, false, Image.FORMAT_RF)
	var wimg := Image.create(nx, nz, false, Image.FORMAT_RGB8)
	var iimg := Image.create(nx, nz, false, Image.FORMAT_RGB8)
	for j in nz:
		for i in nx:
			var idx := j * nx + i
			var x := MIN.x + i * STEP
			var z := MIN.y + j * STEP
			var h := heights[idx]
			var hl := heights[j * nx + maxi(i - 1, 0)]
			var hr := heights[j * nx + mini(i + 1, nx - 1)]
			var hd := heights[maxi(j - 1, 0) * nx + i]
			var hu := heights[mini(j + 1, nz - 1) * nx + i]
			var nrm := Vector3(hl - hr, 2.0 * STEP, hd - hu).normalized()
			var w := weights_for(x, z, h, 1.0 - nrm.y)
			var pave := VillageLayout.paving_at(x, z)
			# двор замка вымощен старыми плитами — с проплешинами
			var cmk := CastleLayout.mask(x, z)
			if cmk > 0.0 and Vector2(x, z).distance_to(CastleLayout.CENTER) < CastleLayout.WALL_R + 1.0:
				pave = maxf(pave, cmk * ss(-0.35, 0.1, _surf2.get_noise_2d(x * 0.6, z * 0.6)))
			# грунтовые дороги: к маяку деревни, тропа к лесу, лесные тропы
			var road := VillageLayout.road_at(x, z)
			road = maxf(road, 1.0 - ss(0.7, 1.6, ForestLayout.trail_dist(x, z)))
			var in_forest := ForestLayout.in_core(x, z)
			# мостки на карте — как дорога
			if SwampLayout.walk_dist(x, z) < SwampLayout.WALK_HALF + 0.3:
				road = maxf(road, 0.8)
			if CastleLayout.on_bridge(x, z):
				road = maxf(road, 0.9)
			# каменная лестница и гребень в горах — на карте как дорога
			if MountainLayout.mask(x, z) > 0.3 and (MountainLayout.stair_info(x, z).x < MountainLayout.PATH_HALF or MountainLayout.ridge_dist(x, z) < MountainLayout.PATH_HALF):
				road = maxf(road, 0.8)
			if in_forest:
				road = maxf(road, 1.0 - ss(0.0, 1.0, ForestLayout.path_dist(x, z) + 0.6))
			if road > 0.0:
				w = w.lerp(Vector3(0.1, 0.9, 0.0), road)
			verts[idx] = Vector3(x, h, z)
			normals[idx] = nrm
			colors[idx] = Color(w.x, w.y, w.z, pave)
			himg.set_pixel(i, j, Color(h, 0, 0))
			# на брусчатке трава не растёт; в чаще под елями — мох вместо травы
			var gw := w.x * (1.0 - pave) * (0.35 if in_forest and road < 0.2 else 1.0)
			# выше снеговой линии в горах трава не растёт
			gw *= 1.0 - MountainLayout.mask(x, z) * ss(1.8, 3.2, h)
			wimg.set_pixel(i, j, Color(gw, w.y, w.z))
			iimg.set_pixel(i, j, Color(pave, road, 1.0 if in_forest else ForestLayout.region_factor(x, z) * 0.6))

	var indices := PackedInt32Array()
	indices.resize((nx - 1) * (nz - 1) * 6)
	var k := 0
	for j in nz - 1:
		for i in nx - 1:
			var a := j * nx + i
			indices[k] = a; indices[k + 1] = a + 1; indices[k + 2] = a + nx
			indices[k + 3] = a + 1; indices[k + 4] = a + nx + 1; indices[k + 5] = a + nx
			k += 6

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	height_tex = ImageTexture.create_from_image(himg)
	weight_tex = ImageTexture.create_from_image(wimg)
	height_img = himg
	info_img = iimg

	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/terrain.gdshader")
	var base := "res://assets/textures/ground/"
	mat.set_shader_parameter("grass_c", load(base + "Grass004_color.jpg"))
	mat.set_shader_parameter("grass_n", load(base + "Grass004_normal.jpg"))
	mat.set_shader_parameter("dirt_c", load(base + "Ground037_color.jpg"))
	mat.set_shader_parameter("dirt_n", load(base + "Ground037_normal.jpg"))
	mat.set_shader_parameter("rock_c", load(base + "Rock030_color.jpg"))
	mat.set_shader_parameter("rock_n", load(base + "Rock030_normal.jpg"))
	mat.set_shader_parameter("pave_c", load(base + "PavingStones070_color.jpg"))
	mat.set_shader_parameter("pave_n", load(base + "PavingStones070_normal.jpg"))
	mat.set_shader_parameter("forest", Vector3(ForestLayout.CENTER.x, ForestLayout.CENTER.y, ForestLayout.RADIUS))
	mat.set_shader_parameter("swamp", Vector3(SwampLayout.CENTER.x, SwampLayout.CENTER.y, SwampLayout.RADIUS))
	mat.set_shader_parameter("mountain", Vector3(MountainLayout.CENTER.x, MountainLayout.CENTER.y, MountainLayout.RADIUS))
	mesh.surface_set_material(0, mat)

	var mi := MeshInstance3D.new()
	mi.name = "Terrain"
	mi.mesh = mesh
	return mi
