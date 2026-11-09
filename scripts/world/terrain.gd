class_name Terrain
extends RefCounted
## Рельеф острова ~80×80 м (центр в 0,0), вода на высоте 0.
## Одни и те же функции используют меш земли, трава, деревья, звук шагов.

const ISLAND_RADIUS := 40.0
const WATER_LEVEL := 0.0
const SIZE := 140.0 # меш больше острова — склоны уходят под воду
const SEGS := 256

static var _hills: FastNoiseLite
static var _bumps: FastNoiseLite
static var _coast: FastNoiseLite
static var _surf: FastNoiseLite
static var _surf2: FastNoiseLite

## Карты для шейдеров (трава, вода): высота и веса материалов
static var height_tex: ImageTexture
static var weight_tex: ImageTexture


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
	var d := sqrt(x * x + z * z)
	var coast := ISLAND_RADIUS * (0.9 + 0.22 * _coast.get_noise_2d(x, z))
	var island := ss(coast + 3.0, coast - 9.0, d)
	var hills := _hills.get_noise_2d(x, z)
	var bumps := _bumps.get_noise_2d(x + 40.0, z) * 0.3
	var centre := ss(26.0, 0.0, d) * 1.6
	var land := 1.0 + centre + (hills * 0.5 + 0.5) * 4.0 + bumps
	return island * land - (1.0 - island) * 3.5


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
	var grass := maxf(0.0, 1.0 - rock - dirt)
	var s := grass + dirt + rock
	return Vector3(grass, dirt, rock) / s


static func weights_at(x: float, z: float) -> Vector3:
	return weights_for(x, z, height_at(x, z), 1.0 - normal_at(x, z).y)


## "grass" | "dirt" | "rock" | "water" — для звука шагов
static func surface_at(x: float, z: float) -> String:
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


## Строит меш земли и карты высот/весов
static func build() -> MeshInstance3D:
	var n := SEGS + 1
	var step := SIZE / SEGS
	var half := SIZE * 0.5
	var heights := PackedFloat32Array()
	heights.resize(n * n)
	for j in n:
		for i in n:
			heights[j * n + i] = height_at(-half + i * step, -half + j * step)

	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	verts.resize(n * n)
	normals.resize(n * n)
	colors.resize(n * n)
	var himg := Image.create(n, n, false, Image.FORMAT_RF)
	var wimg := Image.create(n, n, false, Image.FORMAT_RGB8)
	for j in n:
		for i in n:
			var idx := j * n + i
			var x := -half + i * step
			var z := -half + j * step
			var h := heights[idx]
			var hl := heights[j * n + maxi(i - 1, 0)]
			var hr := heights[j * n + mini(i + 1, n - 1)]
			var hd := heights[maxi(j - 1, 0) * n + i]
			var hu := heights[mini(j + 1, n - 1) * n + i]
			var nrm := Vector3(hl - hr, 2.0 * step, hd - hu).normalized()
			var w := weights_for(x, z, h, 1.0 - nrm.y)
			verts[idx] = Vector3(x, h, z)
			normals[idx] = nrm
			colors[idx] = Color(w.x, w.y, w.z)
			himg.set_pixel(i, j, Color(h, 0, 0))
			wimg.set_pixel(i, j, Color(w.x, w.y, w.z))

	var indices := PackedInt32Array()
	indices.resize(SEGS * SEGS * 6)
	var k := 0
	for j in SEGS:
		for i in SEGS:
			var a := j * n + i
			indices[k] = a; indices[k + 1] = a + 1; indices[k + 2] = a + n
			indices[k + 3] = a + 1; indices[k + 4] = a + n + 1; indices[k + 5] = a + n
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

	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/terrain.gdshader")
	var base := "res://assets/textures/ground/"
	mat.set_shader_parameter("grass_c", load(base + "Grass004_color.jpg"))
	mat.set_shader_parameter("grass_n", load(base + "Grass004_normal.jpg"))
	mat.set_shader_parameter("dirt_c", load(base + "Ground037_color.jpg"))
	mat.set_shader_parameter("dirt_n", load(base + "Ground037_normal.jpg"))
	mat.set_shader_parameter("rock_c", load(base + "Rock030_color.jpg"))
	mat.set_shader_parameter("rock_n", load(base + "Rock030_normal.jpg"))
	mesh.surface_set_material(0, mat)

	var mi := MeshInstance3D.new()
	mi.name = "Terrain"
	mi.mesh = mesh
	return mi
