class_name ForestLayout
extends RefCounted
## Шепчущий лес — к северу от деревни (север = −z).
## Внутри леса ходить можно только по тропам; тропы закольцованы, неверные ведут по кругу.
## Верный путь: вход → развилки J1 → J2 → J3 → P → поляна маяка.

const CENTER := Vector2(0.0, -66.0)
const RADIUS := 38.0
## Внутренняя часть леса, где можно ходить только по тропам
const CORE := 33.0
const PATH_HALF := 1.7

## Узлы троп (локально от центра леса)
const N := {
	"E": Vector2(0, 33), "J1": Vector2(0, 20), "J2": Vector2(-6, 6), "J3": Vector2(-14, -8),
	"P": Vector2(-6, -20), "B": Vector2(3, -25),
	"a1": Vector2(10, 14), "a2": Vector2(14, 24), "a3": Vector2(6, 30), # петля от J1 обратно ко входу
	"v1": Vector2(-11, 17), "V": Vector2(-18, 20), # к хижине Вейла
	"b1": Vector2(8, 1), "b2": Vector2(10, 11), # петля от J2 к J1
	"c1": Vector2(-24, -15), "c2": Vector2(-23, 0), # петля от J3 к J2
	"d1": Vector2(7, -12), "d2": Vector2(7, -1), # петля от P к J2
}
const EDGES := [
	["E", "J1"], ["J1", "J2"], ["J2", "J3"], ["J3", "P"], ["P", "B"],
	["J1", "a1"], ["a1", "a2"], ["a2", "a3"], ["a3", "E"],
	["J1", "v1"], ["v1", "V"],
	["J2", "b1"], ["b1", "b2"], ["b2", "J1"],
	["J3", "c1"], ["c1", "c2"], ["c2", "J2"],
	["P", "d1"], ["d1", "d2"], ["d2", "J2"],
]
## Верный путь — по нему летят светлячки-проводники
const ROUTE := ["E", "J1", "J2", "J3", "P", "B"]
## Поляны: узел → радиус
const GLADES := {"B": 7.5, "V": 5.0, "J1": 3.2, "J2": 3.2, "J3": 3.2, "P": 3.0, "E": 3.5}

## Записки, грибы-огоньки, лунные лучи (локально)
const NOTES := {"soldier_letter": Vector2(8.5, 0.0), "king_page": Vector2(-1.0, -22.0)}
const MUSHROOMS := [Vector2(-23.5, -8.0), Vector2(12.5, 19.0), Vector2(-9.5, -15.0)]
const BEAMS := [Vector2(0, 26), Vector2(-3, 13), Vector2(-10, -1), Vector2(-17, 18), Vector2(-11, -15), Vector2(2, -24), Vector2(6, -27), Vector2(9, 6), Vector2(-21, -7), Vector2(11, 20), Vector2(5, -9), Vector2(-4, -26)]


static func world(local: Vector2) -> Vector2:
	return CENTER + local


static func node(id: String) -> Vector2:
	return world(N[id])


static func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return p.distance_to(a + ab * t)


## Расстояние до ближайшей тропы или поляны (0 — на тропе)
static func path_dist(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var best := 999.0
	for e in EDGES:
		best = minf(best, _seg_dist(p, node(e[0]), node(e[1])) - PATH_HALF)
	for g in GLADES:
		best = minf(best, p.distance_to(node(g)) - GLADES[g])
	return maxf(best, 0.0)


static func in_core(x: float, z: float) -> bool:
	return Vector2(x, z).distance_to(CENTER) < CORE


## Можно ли здесь стоять (в глубине леса — только тропы и поляны)
static func walkable(x: float, z: float) -> bool:
	return not in_core(x, z) or path_dist(x, z) <= 0.05


## 0 — вне леса, 1 — в глубине леса (для тумана, света, звуков)
static func region_factor(x: float, z: float) -> float:
	var d := Vector2(x, z).distance_to(CENTER)
	return 1.0 - Terrain.ss(RADIUS - 14.0, RADIUS + 2.0, d)


## Тропа от деревни до опушки (мировые координаты)
static func trail() -> PackedVector2Array:
	var v := VillageLayout.CENTER
	return PackedVector2Array([v + Vector2(1.5, -VillageLayout.RADIUS + 1.0), Vector2(-2.0, -22.0), node("E") + Vector2(0, 4)])


static func trail_dist(x: float, z: float) -> float:
	var t := trail()
	var p := Vector2(x, z)
	var best := 999.0
	for i in t.size() - 1:
		best = minf(best, _seg_dist(p, t[i], t[i + 1]))
	return best


## Точки верного пути для светлячков-проводников
static func route_points() -> PackedVector2Array:
	var out := PackedVector2Array()
	for id in ROUTE:
		out.append(node(id))
	return out
