class_name Oil
extends RefCounted
## Масло в фонаре = жизнь. Тратится медленно; поднятый фонарь тратит быстрее.
## Уровень видно по яркости и радиусу света (и маленькому флакону), без полосок.

const FULL_TANK_SECONDS := 240.0 # полный фонарь горит ~4 минуты
const RAISED_MULT := 3.0
const FLASK_AMOUNT := 0.35

var level := 1.0 # 0..1


func drain(dt: float, raised: bool, safe: bool) -> void:
	if safe:
		return # у зажжённого маяка масло не тратится
	level = maxf(0.0, level - dt / FULL_TANK_SECONDS * (RAISED_MULT if raised else 1.0))


func add(amount: float) -> void:
	level = minf(1.0, level + amount)


## Радиус света, от которого отступают Тени (м)
func light_radius(raised: bool) -> float:
	var r := lerpf(1.4, 5.5, sqrt(level))
	return r * (1.45 if raised else 1.0)


## 0 — полно, 1 — почти пусто: насколько сильно дрожит свет
func low() -> float:
	return clampf(1.0 - level / 0.25, 0.0, 1.0)
