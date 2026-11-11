class_name Veil
extends RefCounted
## Волны Пелены. Время от времени с гор накатывает густой дым: сначала предупреждение
## (гул, ветер крепчает), потом сама волна — туман, свет сжимается, масло тает в разы быстрее.
## Укрытие — дом (E у двери) или живой огонь рядом: фонарь на столбе, жаровня, костёр, маяк.
## У зажжённого маяка волна заметно слабее.

enum Phase { CALM, WARN, WAVE, EASE }

const WARN_TIME := 22.0
const WAVE_TIME := 40.0
const EASE_TIME := 8.0
const FIRST_DELAY := 75.0 # первая волна — вскоре после первого маяка

var phase := Phase.CALM
var timer := FIRST_DELAY
var strength := 0.0 # 0..1 — сила волны сейчас (плавно)
var waves := 0 # сколько волн уже было
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.randomize()


## enabled — можно ли сейчас начинать/продолжать волну (идёт игра, есть фонарь, не в замке).
## Возвращает событие: "warn", "wave", "calm" или "".
func tick(dt: float, enabled: bool) -> String:
	var ev := ""
	if not enabled and phase == Phase.CALM:
		strength = move_toward(strength, 0.0, dt * 0.3)
		return ev
	if not enabled and phase == Phase.WARN:
		phase = Phase.CALM # ушли в замок или в разговор до начала — волна откладывается
		timer = 30.0
	timer -= dt
	match phase:
		Phase.CALM:
			if timer <= 0.0:
				phase = Phase.WARN
				timer = WARN_TIME
				ev = "warn"
		Phase.WARN:
			if timer <= 0.0:
				phase = Phase.WAVE
				timer = WAVE_TIME
				ev = "wave"
		Phase.WAVE:
			if timer <= 0.0:
				phase = Phase.EASE
				timer = EASE_TIME
		Phase.EASE:
			if timer <= 0.0:
				phase = Phase.CALM
				waves += 1
				timer = _rng.randf_range(150.0, 230.0)
				ev = "calm"
	var want := 0.0
	match phase:
		Phase.WARN:
			want = 0.18 * (1.0 - timer / WARN_TIME)
		Phase.WAVE:
			want = 1.0
		Phase.EASE:
			want = timer / EASE_TIME
	strength = move_toward(strength, want, dt * (0.25 if want > strength else 0.2))
	return ev


func warning() -> bool:
	return phase == Phase.WARN


func active() -> bool:
	return phase == Phase.WAVE or (phase == Phase.EASE and strength > 0.3)


## Сколько секунд до волны (во время предупреждения)
func seconds_left() -> int:
	return int(ceil(timer)) if phase == Phase.WARN else 0


## Для проверок: сразу начать предупреждение
func force_warn(seconds := WARN_TIME) -> void:
	phase = Phase.WARN
	timer = seconds
