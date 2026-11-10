class_name VillageLayout
extends RefCounted
## Планировка деревни Тихий Брод: где что стоит, где брусчатка, где ровная земля.
## Координаты построек — относительно центра деревни (площадь с колодцем).

const CENTER := Vector2(-7.0, 11.0)
const RADIUS := 17.0
const PAVE_WIDTH := 1.5

## Высота «площадки» деревни (берётся из рельефа в центре)
static var plateau := 0.0
## Дорожки брусчатки (в мировых координатах), задаются при build_paths()
static var paths: Array[PackedVector2Array] = []
## Дорога к маяку (грунтовая, без брусчатки)
static var dirt_road := PackedVector2Array()


static func world(local: Vector2) -> Vector2:
	return CENTER + local


static func setup() -> void:
	plateau = Terrain.raw_height(CENTER.x, CENTER.y)


static func build_paths(beacon: Vector3) -> void:
	paths.clear()
	var c := CENTER
	# площадь и улочки к домам, кузнице, чайхане
	for target in [Vector2(-6.5, -4.5), Vector2(6.0, -6.0), Vector2(-7.5, 5.5), Vector2(7.5, 6.0), Vector2(11.0, -0.5), Vector2(-0.5, 8.0), Vector2(-13.0, -8.0)]:
		paths.append(PackedVector2Array([c, c + target]))
	# дорога к маяку: от площади до края деревни — брусчатка, дальше — грунт
	var dir := (Vector2(beacon.x, beacon.z) - c).normalized()
	var edge := c + dir * (RADIUS - 2.0)
	paths.append(PackedVector2Array([c, edge]))
	dirt_road = PackedVector2Array([edge, Vector2(beacon.x, beacon.z) - dir * 4.0])


static func in_village(x: float, z: float, margin := 0.0) -> bool:
	return Vector2(x, z).distance_to(CENTER) < RADIUS + margin


## Насколько выровнять землю (1 — внутри деревни, 0 — снаружи)
static func flatten(x: float, z: float) -> float:
	var d := Vector2(x, z).distance_to(CENTER)
	return 1.0 - Terrain.ss(RADIUS - 5.0, RADIUS + 5.0, d)


static func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return p.distance_to(a + ab * t)


## 0..1 — насколько здесь брусчатка
static func paving_at(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var best := 99.0
	for path in paths:
		for i in path.size() - 1:
			best = minf(best, _seg_dist(p, path[i], path[i + 1]))
	var square := p.distance_to(CENTER) - 4.2 # круглая площадь у колодца
	best = minf(best, maxf(square, 0.0))
	return 1.0 - Terrain.ss(PAVE_WIDTH * 0.6, PAVE_WIDTH, best)


## 0..1 — грунтовая дорога к маяку
static func road_at(x: float, z: float) -> float:
	if dirt_road.size() < 2:
		return 0.0
	var d := _seg_dist(Vector2(x, z), dirt_road[0], dirt_road[1])
	return 1.0 - Terrain.ss(0.8, 1.6, d)


## Что где стоит: модель, позиция (локально), поворот (градусы), размер (высота, или ширина для "w")
static func plots() -> Array:
	return [
		{m = "House_1", p = Vector2(-9.0, -7.0), r = 35.0, h = 6.2, id = "elder_house"},
		{m = "House_2", p = Vector2(8.0, -9.0), r = -30.0, h = 6.6},
		{m = "House_3", p = Vector2(-10.0, 7.5), r = 120.0, h = 5.0},
		{m = "House_4", p = Vector2(9.5, 8.5), r = -135.0, h = 4.6},
		{m = "Blacksmith", p = Vector2(14.0, -1.0), r = -90.0, h = 5.6, id = "smithy"},
		{m = "Mill", p = Vector2(-15.5, -10.0), r = 45.0, h = 9.0},
		{m = "Well", p = Vector2(0.0, 0.0), r = 0.0, h = 2.6, id = "well"},
		{m = "Gazebo", p = Vector2(-1.0, 11.0), r = 0.0, h = 3.4, id = "chaikhana"},
		{m = "MarketStand_1", p = Vector2(4.5, -4.5), r = -20.0, h = 2.6},
		{m = "Cart", p = Vector2(11.0, -6.0), r = 60.0, h = 1.5},
		{m = "Barrel", p = Vector2(11.5, 2.5), r = 0.0, h = 0.9},
		{m = "Barrel", p = Vector2(12.3, 3.0), r = 40.0, h = 0.9},
		{m = "Barrel", p = Vector2(-6.0, -3.5), r = 10.0, h = 0.9},
		{m = "Crate", p = Vector2(5.8, -3.0), r = 15.0, h = 0.7},
		{m = "Crate", p = Vector2(6.4, -2.3), r = 50.0, h = 0.6},
		{m = "Bags", p = Vector2(3.4, -5.6), r = 0.0, h = 0.7},
		{m = "Hay", p = Vector2(-12.5, 1.0), r = 20.0, h = 1.0},
		{m = "Hay", p = Vector2(-11.8, 2.2), r = 70.0, h = 0.9},
		{m = "Bench_1", p = Vector2(-2.6, 2.4), r = 30.0, h = 0.55},
		{m = "Bench_1", p = Vector2(2.8, -2.0), r = 200.0, h = 0.55},
		{m = "Pumpkin_Crop", p = Vector2(-12.5, 10.5), r = 0.0, h = 0.6},
		{m = "Pumpkin_Crop", p = Vector2(-13.5, 11.5), r = 50.0, h = 0.6},
		{m = "Wheat_Crop", p = Vector2(-14.5, 9.0), r = 0.0, h = 1.0},
		{m = "Wheat_Crop", p = Vector2(-15.5, 10.2), r = 30.0, h = 1.0},
		{m = "Carrot_Crop", p = Vector2(-12.8, 12.8), r = 0.0, h = 0.4},
	]


## Загон для овец (локально): центр и размер
const PEN_CENTER := Vector2(-14.0, 2.5)
const PEN_SIZE := Vector2(6.0, 4.5)

## Фонари на столбах (локально)
const LAMPS := [Vector2(3.2, 2.6), Vector2(-3.4, -3.2), Vector2(-4.2, 4.6), Vector2(6.8, -2.6), Vector2(-0.6, -7.5), Vector2(9.5, 2.8), Vector2(2.5, 8.0)]

## Хлебная печь, наковальня, доска объявлений (локально)
const OVEN := Vector2(5.5, 4.2)
const ANVIL := Vector2(11.0, 0.8)
const BOARD := Vector2(2.2, -1.8)

## Где стоят жители и где начинает герой (локально)
const NPC_SPOTS := {
	"oldrich": Vector2(-5.6, -3.6),
	"borta": Vector2(10.2, 2.0),
	"lia": Vector2(1.9, 2.4),
	"mara": Vector2(-1.2, 9.2),
}
const HERO_START := Vector2(-4.4, -2.0)
