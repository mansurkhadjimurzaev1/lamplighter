class_name LoadingScreen
extends CanvasLayer
## Экран загрузки: тёмный пергамент, тёплое пятно света и цитата о терпении и надежде.

const QUOTES_RU := [
	["Терпение ходит медленно. Но доходит дальше всех.", "Старейшина Ольдрих"],
	["Огонь не держат в кулаке — задушишь. Его берегут в ладонях.", "Кузнец Борта"],
	["Заблудиться не стыдно. Стыдно делать вид, что знаешь дорогу.", "Травник Вейл"],
	["Настоящий свет не убегает, когда к нему идёшь.", "Паромщик Корней"],
	["Учёный смотрит не только на то, что красиво. Учёный смотрит на то, что есть.", "Учёный Ансар"],
	["Темнота сама не уходит. Она только учит ждать.", "Из разговоров у колодца"],
	["Надежда — это фонарь, который несут, даже когда не видно дороги.", "Слова фонарщиков"],
]
const QUOTES_EN := [
	["Patience walks slowly. But it walks the farthest.", "Elder Oldrich"],
	["You don't hold fire in a fist — you'll smother it. You keep it in your palms.", "Borta the Smith"],
	["Getting lost is no shame. Pretending to know the way is.", "Vale the Herbalist"],
	["True light doesn't run away when you walk toward it.", "Korney the Ferryman"],
	["A scholar looks not only at what is beautiful. A scholar looks at what is.", "Ansar the Scholar"],
	["Darkness never leaves on its own. It only teaches you to wait.", "Overheard by the well"],
	["Hope is a lantern you carry even when you cannot see the road.", "A lamplighters' saying"],
]

var _root := Control.new()
var _t := 0.0
var _closing := false


func build() -> void:
	layer = 40
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.05)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(bg)
	var glow := TextureRect.new()
	var g := GradientTexture2D.new()
	g.fill = GradientTexture2D.FILL_RADIAL
	g.fill_from = Vector2(0.5, 0.5)
	g.fill_to = Vector2(1.0, 0.5)
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color(1.0, 0.55, 0.2, 0.22), Color(1.0, 0.55, 0.2, 0.0)])
	g.gradient = grad
	glow.texture = g
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	_root.add_child(glow)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.custom_minimum_size = Vector2(820, 0)
	box.add_theme_constant_override("separation", 14)
	_root.add_child(box)
	var quotes := QUOTES_EN if Settings.lang == "en" else QUOTES_RU
	var q: Array = quotes[randi() % quotes.size()]
	var text := UiStyle.label("«%s»" % q[0] if Settings.lang == "ru" else "“%s”" % q[0], 32, Color(0.95, 0.84, 0.65), false, true)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(text)
	var who := UiStyle.label("— " + q[1], 20, Color(0.95, 0.84, 0.65, 0.6))
	who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(who)
	var load := UiStyle.label(Tr.t("Загрузка мира…"), 18, Color(0.95, 0.84, 0.65, 0.4), false, true)
	load.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	load.grow_horizontal = Control.GROW_DIRECTION_BOTH
	load.offset_top = -60
	load.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(load)


func close() -> void:
	_closing = true


func _process(dt: float) -> void:
	_t += dt
	if _closing:
		_root.modulate.a = maxf(0.0, _root.modulate.a - dt * 1.2)
		if _root.modulate.a <= 0.0:
			queue_free()
