class_name SwampLayout
extends RefCounted
## Топь — к востоку от деревни. Мелкая вода (можно брести, но масло тратится быстрее),
## глубокие омуты (не пройти), трясины (затягивают), гнилые мостки, островок паромщика,
## островок маяка за глубокой протокой — туда только на лодке.

const CENTER := Vector2(74.0, -12.0)
const RADIUS := 36.0

const HUT := Vector2(68.0, -9.0) # островок паромщика
const HUT_R := 5.5
const BEACON := Vector2(92.0, -26.0) # островок маяка
const BEACON_R := 7.5
const RING_OUT := 14.0 # глубокая протока вокруг островка маяка

## Гнилые мостки (мировые точки): от берега острова к хижине и к причалу
const WALK := [Vector2(31.0, -4.6), Vector2(37.0, -4.6), Vector2(45.0, -6.5), Vector2(51.0, -2.5), Vector2(57.0, -5.0), Vector2(63.0, -8.0), Vector2(68.0, -9.0)]
const WALK2 := [Vector2(70.5, -11.0), Vector2(75.0, -13.0), Vector2(79.3, -15.9)]
const WALK_HALF := 0.75
## Где в мостках прогнили доски (дыры, но пройти можно — по краю)
const GAPS := [Vector2(48.0, -4.7), Vector2(60.0, -6.5)]

## Трясины: центр и радиус. Над ними висят блуждающие огни.
const BOGS := [[Vector2(62.0, 10.0), 5.0], [Vector2(84.0, 4.0), 5.5], [Vector2(55.0, -24.0), 5.0], [Vector2(98.0, -4.0), 4.5]]

## Записки и находки (мировые)
const NOTES := {"sealed_letter": Vector2(53.0, -1.4), "boot_drawing": Vector2(89.5, -22.0)}
const ROPE := Vector2(57.5, -3.6) # верёвка — на старых мостках
const RESIN := Vector2(78.0, 6.5) # смола — на мёртвом дереве у кочки (рядом трясина!)

static var _n1: FastNoiseLite
static var _n2: FastNoiseLite


static func _static_init() -> void:
	_n1 = FastNoiseLite.new()
	_n1.seed = 61
	_n1.frequency = 0.09
	_n1.fractal_octaves = 3
	_n2 = FastNoiseLite.new()
	_n2.seed = 67
	_n2.frequency = 0.05
	_n2.fractal_octaves = 2


static func pier_a() -> Vector2:
	return WALK2[WALK2.size() - 1]


static func pier_b() -> Vector2:
	var dir := (HUT - BEACON).normalized()
	return BEACON + dir * (BEACON_R - 0.3)


## 0..1 — насколько это место топь (плавный край)
static func mask(x: float, z: float) -> float:
	var d := Vector2(x, z).distance_to(CENTER)
	return 1.0 - Terrain.ss(RADIUS - 6.0, RADIUS + 4.0, d)


static func in_swamp(x: float, z: float) -> bool:
	return mask(x, z) > 0.5


static func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return p.distance_to(a + ab * t)


## Расстояние до оси мостков
static func walk_dist(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var best := 999.0
	for path in [WALK, WALK2]:
		for i in path.size() - 1:
			best = minf(best, _seg_dist(p, path[i], path[i + 1]))
	return best


static func on_boardwalk(x: float, z: float) -> bool:
	# мостки начинаются на берегу острова — ходить можно по всем доскам, и над морем тоже
	return walk_dist(x, z) <= WALK_HALF + 0.05


static func bog_at(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var best := 0.0
	for b in BOGS:
		best = maxf(best, 1.0 - Terrain.ss(b[1] * 0.6, b[1], p.distance_to(b[0])))
	return best


## Высота дна/земли в топи
static func height(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var hum := _n1.get_noise_2d(x, z)
	var h := -0.35 + hum * 0.75 # кочки и мелководье
	# глубокие омуты
	var deep := _n2.get_noise_2d(x + 40.0, z)
	h = lerpf(h, -1.4, Terrain.ss(0.25, 0.45, deep))
	# трясины — ровная «мелкая» гладь (обманчиво)
	var bog := bog_at(x, z)
	h = lerpf(h, -0.32, bog)
	# вдоль мостков — не глубже колена
	var wd := walk_dist(x, z)
	h = maxf(h, lerpf(-0.6, -2.0, Terrain.ss(1.0, 3.0, wd)))
	# островок паромщика
	var hi := 1.0 - Terrain.ss(HUT_R - 1.5, HUT_R + 1.5, p.distance_to(HUT))
	h = lerpf(h, 0.65, hi)
	# островок маяка и глубокая протока вокруг
	var db := p.distance_to(BEACON)
	var ring := Terrain.ss(BEACON_R - 0.5, BEACON_R + 1.5, db) * (1.0 - Terrain.ss(RING_OUT - 2.0, RING_OUT, db))
	h = lerpf(h, -1.8, ring)
	h = lerpf(h, 0.75, 1.0 - Terrain.ss(BEACON_R - 2.0, BEACON_R, db))
	# причал A — у края протоки
	h = lerpf(h, maxf(h, -0.4), 1.0 - Terrain.ss(1.0, 2.5, p.distance_to(pier_a())))
	return h


## Высота настила мостков
static func deck_height(x: float, z: float) -> float:
	return maxf(Terrain.height_at(x, z) + 0.2, 0.32)


## Можно ли здесь стоять (с учётом мостков)
static func walkable(x: float, z: float, h: float) -> bool:
	if on_boardwalk(x, z):
		return true
	if in_swamp(x, z):
		# через протоку маяка — только на лодке
		var db := Vector2(x, z).distance_to(BEACON)
		if db > BEACON_R - 0.2 and db < RING_OUT - 0.5:
			return false
		return h > -0.9
	return h > Terrain.WATER_LEVEL - 0.15
