class_name CastleLayout
extends RefCounted
## Руины замка — на скалистом островке к югу (юг = +z), за длинным каменным мостом.
## Ворота открываются, когда горят 4 маяка. Внутри — тронный зал с королём.

const CENTER := Vector2(0.0, 94.0)
const RADIUS := 30.0 # суша островка
const PLATEAU_H := 2.6
const WALL_R := 22.0 # кольцо внешних стен
const GATE := Vector2(0.0, 72.0) # ворота (на северной стене)
const BRIDGE_HALF := 1.7

## Тронный зал (прямоугольник), вход с юга; трон у северной стены — король смотрит на входящего (и в камеру)
const HALL_MIN := Vector2(-7.0, 90.0)
const HALL_MAX := Vector2(7.0, 109.0)
const HALL_DOOR := 1.8 # полуширина проёма
const THRONE := Vector2(0.0, 92.6)
## Фрески: позиция на стене и сторона (+1 — правая стена, −1 — левая); у каждой — своя картина
const FRESCOES := [
	{id = "fresco_beacons", pos = Vector2(-6.75, 95.0), side = -1},
	{id = "fresco_mine", pos = Vector2(6.75, 95.0), side = 1},
	{id = "fresco_grief", pos = Vector2(-6.75, 103.0), side = -1},
	{id = "fresco_dark", pos = Vector2(6.75, 103.0), side = 1},
]
const TAPESTRIES := [Vector2(-6.8, 99.0), Vector2(6.8, 99.0), Vector2(-3.0, 90.2), Vector2(3.0, 90.2)]
const BEACON := Vector2(13.0, 98.0) # пятый маяк — во дворе на руине башни
const NOTES := {"guard_note": Vector2(-10.0, 80.0), "king_diary": Vector2(1.6, 94.6)}

## Ворота открыты (4 маяка горят)
static var gate_open := false
static var bridge_start := Vector2(0.0, 36.0)
static var _start_h := 1.0
static var _n: FastNoiseLite


static func _static_init() -> void:
	_n = FastNoiseLite.new()
	_n.seed = 97
	_n.frequency = 0.08


## Найти берег острова к югу от деревни — там начинается мост
static func setup() -> void:
	var z := 26.0
	while z < 60.0 and Terrain.raw_height(0.0, z) > 0.6:
		z += 0.25
	bridge_start = Vector2(0.0, z - 2.0)
	_start_h = Terrain.raw_height(0.0, bridge_start.y)


static func mask(x: float, z: float) -> float:
	var d := Vector2(x, z).distance_to(CENTER)
	return 1.0 - Terrain.ss(RADIUS - 6.0, RADIUS + 2.0, d)


## Высота островка: ровное плато с обрывами к морю
static func height(x: float, z: float, base: float) -> float:
	var d := Vector2(x, z).distance_to(CENTER)
	var cliff := 1.0 - Terrain.ss(RADIUS - 5.0, RADIUS - 1.0, d + _n.get_noise_2d(x, z) * 2.0)
	return lerpf(base, PLATEAU_H + _n.get_noise_2d(x * 2.0, z * 2.0) * 0.08, cliff)


static func region_factor(x: float, z: float) -> float:
	var d := Vector2(x, z).distance_to(CENTER)
	return 1.0 - Terrain.ss(RADIUS - 6.0, RADIUS + 6.0, d)


static func in_hall(x: float, z: float) -> bool:
	return x > HALL_MIN.x and x < HALL_MAX.x and z > HALL_MIN.y and z < HALL_MAX.y


# ── мост ────────────────────────────────────────────────────

static func bridge_t(x: float, z: float) -> Vector2:
	# x — расстояние до оси моста, y — доля длины
	var a := bridge_start
	var b := GATE
	var ab := b - a
	var p := Vector2(x, z)
	var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return Vector2(p.distance_to(a + ab * t), t)


static func on_bridge(x: float, z: float) -> bool:
	var bt := bridge_t(x, z)
	return bt.x <= BRIDGE_HALF and bt.y > 0.0 and bt.y < 1.0


static func deck_height(x: float, z: float) -> float:
	var t := bridge_t(x, z).y
	# пологий горб посередине
	return lerpf(_start_h, PLATEAU_H, t) + sin(t * PI) * 1.2


## Закрытые ворота не пускают дальше моста
static func blocked(x: float, z: float) -> bool:
	if gate_open:
		return false
	return z > GATE.y - 0.8 and absf(x - GATE.x) < 4.0 and z < GATE.y + 3.0
