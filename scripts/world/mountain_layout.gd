class_name MountainLayout
extends RefCounted
## Горы на западе: массив с вершиной, на которой стоит обсерватория Ансара.
## Подняться можно только по каменной лестнице (серпантин); вокруг — скалы.
## Маяк — на соседнем утёсе, к нему ведёт гребень.

const CENTER := Vector2(-78.0, 2.0)
const RADIUS := 38.0
const PEAK := 15.0 # высота вершины (м)
const CORE := 30.0 # внутри — только по лестнице и площадкам

## Лестница: от западной окраины деревни к вершине (мировые точки)
const STAIRS := [Vector2(-24.0, 10.0), Vector2(-34.0, 8.0), Vector2(-44.0, 6.0), Vector2(-51.0, 13.0),
	Vector2(-57.0, 5.0), Vector2(-64.0, 12.0), Vector2(-70.0, 4.0), Vector2(-76.0, 6.0)]
## Гребень к утёсу маяка
const RIDGE := [Vector2(-76.0, 6.0), Vector2(-83.0, -2.0), Vector2(-89.0, -9.0)]
const OBS := Vector2(-78.0, 4.0) # площадка обсерватории
const OBS_R := 7.5
const BEACON := Vector2(-90.0, -10.0)
const BEACON_R := 5.5
const PATH_HALF := 1.4

## Жаровни вдоль пути (мировые точки)
const BRAZIERS := [Vector2(-45.5, 7.5), Vector2(-56.0, 6.5), Vector2(-65.0, 10.5), Vector2(-74.0, 7.5), Vector2(-84.5, -3.0)]
## Листы звёздных карт, разметанные ветром
const PAGES := [Vector2(-50.0, 11.0), Vector2(-62.0, 9.0), Vector2(-69.5, 5.5)]
const NOTES := {"smoke_map": Vector2(-58.5, 6.0), "palace_reply": Vector2(-88.0, -7.5)}

static var _n: FastNoiseLite
static var _cum: Array[float] = [] # длина лестницы до каждой точки


static func _static_init() -> void:
	_n = FastNoiseLite.new()
	_n.seed = 83
	_n.frequency = 0.06
	_n.fractal_octaves = 4
	var c := 0.0
	_cum.append(0.0)
	for i in STAIRS.size() - 1:
		c += STAIRS[i].distance_to(STAIRS[i + 1])
		_cum.append(c)


static func mask(x: float, z: float) -> float:
	var d := Vector2(x, z).distance_to(CENTER)
	return 1.0 - Terrain.ss(RADIUS - 8.0, RADIUS + 2.0, d)


static func in_mountains(x: float, z: float) -> bool:
	return mask(x, z) > 0.5


static func _seg(p: Vector2, a: Vector2, b: Vector2) -> Vector2:
	# x — расстояние до отрезка, y — доля вдоль отрезка
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return Vector2(p.distance_to(a + ab * t), t)


## Расстояние до лестницы и высота лестницы в ближайшей точке
static func stair_info(x: float, z: float) -> Vector2:
	var p := Vector2(x, z)
	var best := 999.0
	var s := 0.0
	for i in STAIRS.size() - 1:
		var r := _seg(p, STAIRS[i], STAIRS[i + 1])
		if r.x < best:
			best = r.x
			s = lerpf(_cum[i], _cum[i + 1], r.y)
	var total: float = _cum[_cum.size() - 1]
	# подъём начинается у подножия (третья точка) — до неё тропа почти ровная
	var foot: float = _cum[2]
	var u := clampf((s - foot) / (total - foot), 0.0, 1.0)
	var h := lerpf(1.2, PEAK, u * u * (3.0 - 2.0 * u) * 0.35 + u * 0.65)
	return Vector2(best, h)


static func ridge_dist(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var best := 999.0
	for i in RIDGE.size() - 1:
		best = minf(best, _seg(p, RIDGE[i], RIDGE[i + 1]).x)
	return best


## Места жаровен: у середины прямых пролётов лестницы (и гребня), за краем ступеней —
## на ту сторону, где до соседних пролётов серпантина дальше. Проход всегда свободен.
static func brazier_spots() -> Array[Vector2]:
	var out: Array[Vector2] = []
	var segs := [[STAIRS[2], STAIRS[3]], [STAIRS[3], STAIRS[4]], [STAIRS[4], STAIRS[5]], [STAIRS[5], STAIRS[6]], [RIDGE[0], RIDGE[1]]]
	for sg in segs:
		var a: Vector2 = sg[0]
		var b: Vector2 = sg[1]
		var mid := (a + b) * 0.5
		var dir := (b - a).normalized()
		var side := Vector2(-dir.y, dir.x)
		var best := mid
		var best_d := -1.0
		for sgn in [1.0, -1.0]:
			var c: Vector2 = mid + side * sgn * (PATH_HALF + 1.0)
			var d := minf(stair_info(c.x, c.y).x, ridge_dist(c.x, c.y))
			if d > best_d:
				best_d = d
				best = c
		out.append(best)
	return out


## Высота гор (без учёта острова)
static func height(x: float, z: float, base: float) -> float:
	var p := Vector2(x, z)
	var d := p.distance_to(CENTER)
	var u := clampf(1.0 - d / RADIUS, 0.0, 1.0)
	var rock := _n.get_noise_2d(x, z)
	var h := maxf(base, PEAK * 1.15 * pow(u, 0.9) + rock * 3.0 * u)
	# лестница: вырублена в склоне
	var st := stair_info(x, z)
	var on := 1.0 - Terrain.ss(PATH_HALF, PATH_HALF + 2.5, st.x)
	h = lerpf(h, st.y, on)
	# гребень к утёсу: чуть ниже вершины
	var rd := ridge_dist(x, z)
	h = lerpf(h, PEAK - 1.0, 1.0 - Terrain.ss(PATH_HALF, PATH_HALF + 2.5, rd))
	# площадки обсерватории и маяка
	h = lerpf(h, PEAK + 0.2, 1.0 - Terrain.ss(OBS_R - 1.0, OBS_R + 2.0, p.distance_to(OBS)))
	h = lerpf(h, PEAK - 1.0, 1.0 - Terrain.ss(BEACON_R - 1.0, BEACON_R + 2.0, p.distance_to(BEACON)))
	return h


## В глубине гор — только лестница, гребень и площадки
static func walkable(x: float, z: float) -> bool:
	var p := Vector2(x, z)
	if p.distance_to(CENTER) > CORE:
		return true
	if stair_info(x, z).x <= PATH_HALF + 0.05 or ridge_dist(x, z) <= PATH_HALF + 0.05:
		return true
	return p.distance_to(OBS) <= OBS_R or p.distance_to(BEACON) <= BEACON_R


## 0..1 — насколько герой в горах (для холода, снега, ветра)
static func region_factor(x: float, z: float) -> float:
	var d := Vector2(x, z).distance_to(CENTER)
	return 1.0 - Terrain.ss(RADIUS - 10.0, RADIUS + 2.0, d)
