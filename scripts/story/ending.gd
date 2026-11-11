class_name Ending
extends Node
## Концовки. Хорошая: пятый огонь, Пелена расходится, восходит солнце, жители выходят на площадь,
## звучит весь живой мир; камера облетает все области. Вторая: мир остаётся в сумерках.
## Потом — титры и возврат в главное меню.

signal finished

const LINES_GOOD_RU := [
	"Пятый огонь вспыхнул над руинами — и с холмов пошёл тёплый ветер.",
	"Пелена дрогнула, поредела и уплыла на восток, как уходит долгая болезнь.",
	"Впервые за двадцать лет над королевством взошло солнце.",
	"Люди выходили на пороги, щурились и не верили. Потом — смеялись.",
	"Лия увидела солнце. Оно было тёплым и пахло травой.",
	"Старый король стоял у маяка и не прятал лица от света.",
	"А фонарщик сел у огня и наконец погасил свой фонарь. Он был больше не нужен.",
]
const LINES_GOOD_EN := [
	"The fifth fire blazed above the ruins — and a warm wind came down from the hills.",
	"The Pall trembled, thinned and drifted east, the way a long illness leaves.",
	"For the first time in twenty years, the sun rose over the kingdom.",
	"People stepped onto their doorsteps, squinting, not believing. Then they laughed.",
	"Lia saw the sun. It was warm, and it smelled of grass.",
	"The old king stood by the beacon and did not hide his face from the light.",
	"And the lamplighter sat down by the fire and, at last, put out his lantern. It was no longer needed.",
]
const LINES_BAD_RU := [
	"Фонарь остался у трона. Впервые за много ночей король уснул.",
	"Над королевством стоят сумерки. Четыре огня горят на холмах — и этого почти достаточно.",
	"Люди иногда выходят на пороги и смотрят на юг, туда, где не горит пятый маяк.",
	"Может быть, однажды кто-то другой принесёт огонь. Терпение умеет ждать.",
]
const LINES_BAD_EN := [
	"The lantern stayed by the throne. For the first time in many nights, the king slept.",
	"Twilight lies over the kingdom. Four fires burn on the hills — and that is almost enough.",
	"Sometimes people step onto their doorsteps and look south, where the fifth beacon does not burn.",
	"Perhaps one day someone else will bring the fire. Patience knows how to wait.",
]

var good := true
var main: Node
var cam: Camera3D
var _t := 0.0
var _shots: Array = [] # [{pos, look, dur}]
var _shot_i := 0
var _shot_t := 0.0
var _lines: Array = []
var _line_i := -1
var _line_t := 0.0
var _text: Label
var _layer: CanvasLayer
var _fade: ColorRect
var _sun: DirectionalLight3D
var _env: Environment
var _sky_mat: ProceduralSkyMaterial
var _people: Array = [] # {node, from, to, t}
var _credits: Control
var _credits_t := -1.0
var _done := false
## 0..1 — насколько «рассвело» во всём мире (для звука, цвета)
var dawn := 0.0


func begin(is_good: bool, main_node: Node, camera: Camera3D, env: WorldEnvironment) -> void:
	good = is_good
	main = main_node
	cam = camera
	_env = env.environment
	name = "Ending"
	_lines = (LINES_GOOD_EN if Settings.lang == "en" else LINES_GOOD_RU) if good else (LINES_BAD_EN if Settings.lang == "en" else LINES_BAD_RU)
	_build_overlay()
	_build_shots()
	if good:
		_sun = DirectionalLight3D.new()
		_sun.light_color = Color(1.0, 0.72, 0.45)
		_sun.light_energy = 0.0
		_sun.rotation = Vector3(deg_to_rad(-3.0), deg_to_rad(-150.0), 0)
		_sun.shadow_enabled = true
		main.add_child(_sun)
		_sky_mat = ProceduralSkyMaterial.new()
		_sky_mat.sky_top_color = Color(0.03, 0.04, 0.1)
		_sky_mat.sky_horizon_color = Color(0.06, 0.06, 0.12)
		_sky_mat.ground_horizon_color = Color(0.06, 0.06, 0.12)
		_sky_mat.ground_bottom_color = Color(0.02, 0.02, 0.05)
		_sky_mat.sun_angle_max = 8.0
		var sky := Sky.new()
		sky.sky_material = _sky_mat
		_env.sky = sky
		_env.background_mode = Environment.BG_SKY
		_spawn_people()


func _build_overlay() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 30
	main.add_child(_layer)
	# кинематографичные полосы
	for top in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color.BLACK
		bar.set_anchors_preset(Control.PRESET_TOP_WIDE if top else Control.PRESET_BOTTOM_WIDE)
		bar.custom_minimum_size = Vector2(0, 70)
		if not top:
			bar.offset_top = -70
		_layer.add_child(bar)
	_text = UiStyle.label("", 30, Color(1.0, 0.92, 0.78), false, true)
	_text.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_text.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_text.offset_top = -190
	_text.offset_left = -560
	_text.offset_right = 560
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_text.add_theme_constant_override("outline_size", 8)
	_text.modulate.a = 0.0
	_layer.add_child(_text)
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.modulate.a = 0.0
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_fade)


func _g(p: Vector2, lift := 0.0) -> Vector3:
	return Vector3(p.x, Terrain.height_at(p.x, p.y) + lift, p.y)


func _build_shots() -> void:
	var cb := _g(CastleLayout.BEACON, 3.0)
	var vc := _g(VillageLayout.CENTER, 1.0)
	var fb := _g(ForestLayout.node("B"), 2.0)
	var sb := _g(SwampLayout.BEACON, 2.0)
	var ob := _g(MountainLayout.OBS, 4.0)
	_shots = [
		{pos = cb + Vector3(7, 6, 11), look = cb + Vector3(0, 2, 0), dur = 7.0},
		{pos = Vector3(0, 30, 128), look = Vector3(0, 2, 60), dur = 8.0},
		{pos = vc + Vector3(9, 8, 15), look = vc, dur = 9.0},
		{pos = fb + Vector3(14, 16, 16), look = fb, dur = 7.0},
		{pos = sb + Vector3(-12, 14, 16), look = sb, dur = 7.0},
		{pos = ob + Vector3(14, 9, 16), look = ob + Vector3(0, 3, 0), dur = 7.0},
		{pos = Vector3(-10, 65, 150), look = Vector3(0, 0, -10), dur = 10.0},
	]
	if not good:
		_shots = [
			{pos = _g(CastleLayout.THRONE, 1.5) + Vector3(5, 5, 8), look = _g(CastleLayout.THRONE, 1.0), dur = 9.0},
			{pos = Vector3(0, 30, 128), look = Vector3(0, 2, 60), dur = 9.0},
			{pos = vc + Vector3(9, 9, 15), look = vc, dur = 9.0},
			{pos = Vector3(-10, 60, 145), look = Vector3(0, 0, -10), dur = 11.0},
		]


## Жители выходят из домов на площадь
func _spawn_people() -> void:
	var models := ["KK_Barbarian", "KK_Knight", "KK_Rogue", "KK_Mage", "KK_Rogue_Hooded"]
	var hide_all := ["Barbarian_Hat", "Knight_Helmet", "Mage_Hat", "Knight_Cape", "Barbarian_Cape", "Mage_Cape", "Rogue_Cape"]
	var cols := [Color(0.55, 0.3, 0.2), Color(0.35, 0.4, 0.25), Color(0.6, 0.5, 0.3), Color(0.3, 0.32, 0.45), Color(0.55, 0.22, 0.18), Color(0.45, 0.38, 0.3)]
	var plots := VillageLayout.plots()
	var k := 0
	for plot in plots:
		if not (plot.m.begins_with("House") or plot.m == "Blacksmith" or plot.m == "Mill"):
			continue
		for n in 2:
			var v := Villager.new()
			main.add_child(v)
			v.build({id = "folk_%d" % k, name = "", model = models[k % models.size()], hide_extra = hide_all, height = randf_range(1.2, 1.5),
				swaps = [[Color("#4a6680"), 0.2, cols[k % cols.size()]], [Color("#008a52"), 0.3, cols[(k + 2) % cols.size()]], [Color("#2c2c4c"), 0.16, cols[(k + 4) % cols.size()]]]})
			var from := VillageLayout.world(plot.p * 0.82) + Vector2(randf_range(-1, 1), randf_range(-1, 1))
			var to := VillageLayout.world(Vector2(randf_range(-4.5, 4.5), randf_range(-4.5, 4.5)))
			v.place(_g(from), atan2(to.x - from.x, to.y - from.y))
			v.anim.play("Walking_A")
			v.anim.get_animation("Walking_A").loop_mode = Animation.LOOP_LINEAR
			v.visible = false
			_people.append({node = v, from = from, to = to, t = -randf_range(0.0, 2.5)})
			k += 1


func _ease(u: float) -> float:
	return u * u * (3.0 - 2.0 * u)


func update(dt: float) -> void:
	if _done:
		return
	_t += dt
	# титры
	if _credits_t >= 0.0:
		_credits_t += dt
		var c := _credits as Control
		c.position.y = 900.0 - _credits_t * 48.0
		if c.position.y + c.size.y < -60.0 or _credits_t > 70.0:
			_done = true
			finished.emit()
		return
	# камера
	if _shot_i < _shots.size():
		var s: Dictionary = _shots[_shot_i]
		var prev: Dictionary = _shots[maxi(_shot_i - 1, 0)]
		_shot_t += dt
		var u := _ease(clampf(_shot_t / 2.5, 0.0, 1.0)) if _shot_i > 0 else 1.0
		var drift: Vector3 = Vector3(sin(_t * 0.2), 0, cos(_t * 0.2)) * 1.5 * (_shot_t / float(s.dur))
		var pos: Vector3 = (prev.pos as Vector3).lerp(s.pos, u) + drift
		var look: Vector3 = (prev.look as Vector3).lerp(s.look, u)
		cam.global_position = pos
		cam.look_at(look, Vector3.UP)
		if _shot_t >= s.dur:
			_shot_t = 0.0
			_shot_i += 1
	# текст: строка на каждый план
	var want_line := mini(_shot_i, _lines.size() - 1) if good else mini(_shot_i, _lines.size() - 1)
	if want_line != _line_i and _shot_i < _shots.size():
		_line_i = want_line
		_line_t = 0.0
		_text.text = _lines[_line_i]
	_line_t += dt
	var dur: float = _shots[mini(_shot_i, _shots.size() - 1)].dur
	_text.modulate.a = clampf(minf((_line_t - 0.6) / 1.2, (dur - _line_t) / 1.0), 0.0, 1.0)
	# рассвет
	if good:
		dawn = Terrain.ss(4.0, 26.0, _t)
		_sun.light_energy = 1.7 * dawn
		_sun.rotation.x = deg_to_rad(lerpf(-2.0, -24.0, dawn))
		_sky_mat.sky_top_color = Color(0.03, 0.04, 0.1).lerp(Color(0.38, 0.55, 0.85), dawn)
		_sky_mat.sky_horizon_color = Color(0.06, 0.06, 0.12).lerp(Color(1.0, 0.74, 0.55), dawn)
		_sky_mat.ground_horizon_color = _sky_mat.sky_horizon_color
		_env.fog_light_color = Color(0.05, 0.06, 0.12).lerp(Color(0.85, 0.72, 0.62), dawn)
		_env.fog_density = lerpf(0.03, 0.004, dawn)
		_env.volumetric_fog_enabled = false
		_env.ambient_light_color = Color(0.22, 0.27, 0.55).lerp(Color(0.95, 0.85, 0.78), dawn)
		_env.ambient_light_energy = lerpf(0.75, 1.2, dawn)
		for b in Beacon.all:
			if b.lit:
				b.radius = maxf(b.radius, lerpf(b.max_radius, 260.0, dawn))
		# жители выходят, когда камера над деревней
		if _shot_i >= 2:
			for p in _people:
				p.t += dt
				var v: Villager = p.node
				if p.t > 0.0:
					v.visible = true
					var w := clampf(p.t / 6.0, 0.0, 1.0)
					var at: Vector2 = (p.from as Vector2).lerp(p.to, w)
					v.global_position = _g(at)
					if w >= 1.0 and v.anim.current_animation != "Cheer":
						v.anim.play("Cheer")
						v.anim.get_animation("Cheer").loop_mode = Animation.LOOP_LINEAR
	else:
		dawn = 0.0
	# конец облёта — затемнение и титры
	if _shot_i >= _shots.size():
		_fade.modulate.a = minf(1.0, _fade.modulate.a + dt * 0.5)
		_text.modulate.a = 0.0
		if _fade.modulate.a >= 1.0:
			_show_credits()


func _show_credits() -> void:
	_credits_t = 0.0
	_credits = VBoxContainer.new()
	var c := _credits as VBoxContainer
	c.add_theme_constant_override("separation", 10)
	c.position = Vector2(0, 900)
	c.size = Vector2(get_viewport().get_visible_rect().size.x, 0)
	_layer.add_child(c)
	var gold := Color(0.98, 0.86, 0.62)
	var soft := Color(0.95, 0.84, 0.65, 0.7)
	var add := func(text: String, size: int, col: Color, title := false):
		var l := UiStyle.label(text, size, col)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if title:
			l.add_theme_font_override("font", UiStyle.title_font())
		c.add_child(l)
	var en := Settings.lang == "en"
	add.call(Tr.t("Последний фонарщик"), 54, gold, true)
	add.call(("The good ending" if en else "Рассвет") if good else ("The twilight ending" if en else "Сумерки"), 24, soft)
	add.call(" ", 30, soft)
	for row in [
		["Идея, мир и история" if not en else "Idea, world and story", "автор игры" if not en else "the author of the game"],
		["Код и сборка" if not en else "Code and build", "Claude (Anthropic) — по описаниям автора" if not en else "Claude (Anthropic) — from the author's descriptions"],
		["Движок" if not en else "Engine", "Godot Engine 4 (MIT)"],
		["Персонажи" if not en else "Characters", "KayKit — Kay Lousberg (CC0)"],
		["Природа, деревня, животные" if not en else "Nature, village, animals", "Quaternius (CC0)"],
		["Текстуры" if not en else "Textures", "ambientCG (CC0)"],
		["Шрифты" if not en else "Fonts", "Ruslan Display, Cormorant Garamond (SIL OFL)"],
		["Звуки" if not en else "Sounds", "синтезированы кодом — без музыки" if not en else "synthesized in code — no music"],
	]:
		add.call(row[0], 20, soft)
		add.call(row[1], 26, gold)
		add.call(" ", 8, soft)
	add.call(" ", 40, soft)
	add.call("Терпение ходит медленно. Но доходит дальше всех." if not en else "Patience walks slowly. But it walks the farthest.", 24, soft)
	add.call(" ", 60, soft)
	add.call(Tr.t("Спасибо, что прошли этот путь."), 28, gold)
	add.call(Tr.t("Конец"), 40, gold, true)


func skip() -> void:
	if _credits_t < 0.0:
		_shot_i = _shots.size()
		_fade.modulate.a = 1.0
	else:
		_done = true
		finished.emit()


## Жизнь каждой области для звуков (в хорошем финале — весь мир звучит)
func life() -> Dictionary:
	var v := dawn if good else 0.0
	return {"village": v, "forest": v, "swamp": v, "mountains": v}
