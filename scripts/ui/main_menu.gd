class_name MainMenu
extends CanvasLayer
## Главное меню: название славянской вязью, кнопки «Продолжить / Новая игра / Настройки / Выйти».
## Сцена позади — ночной холм, костёр и фонарщик (её ставит main.gd).

signal started # продолжить / начать игру
signal new_game # новая игра поверх сохранения (сотрёт его)
signal language_changed
signal quality_changed

var _root := Control.new()
var _box: VBoxContainer
var _settings: SettingsPanel
var _ready_to_start := false
var _done := false
var _confirm_new := false
var _new_btn: Button
var _cont_btn: Button
var _t := 0.0


func build() -> void:
	layer = 10
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	# мягкое затемнение слева, где текст
	var shade := TextureRect.new()
	var g := GradientTexture2D.new()
	g.fill_from = Vector2(0, 0.5)
	g.fill_to = Vector2(1, 0.5)
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color(0.01, 0.01, 0.04, 0.8), Color(0.01, 0.01, 0.04, 0.0)])
	g.gradient = grad
	shade.texture = g
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(shade)

	_box = VBoxContainer.new()
	_box.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	_box.offset_left = 90
	_box.grow_vertical = Control.GROW_DIRECTION_BOTH
	_box.add_theme_constant_override("separation", 6)
	_root.add_child(_box)
	var title := Label.new()
	title.text = Tr.t("Последний фонарщик")
	title.add_theme_font_override("font", UiStyle.title_font())
	title.add_theme_font_size_override("font_size", 64 if Settings.lang == "ru" else 56)
	title.add_theme_color_override("font_color", Color(0.98, 0.86, 0.62))
	title.add_theme_color_override("font_shadow_color", Color(1.0, 0.5, 0.15, 0.35))
	title.add_theme_constant_override("shadow_outline_size", 12)
	title.add_theme_constant_override("shadow_offset_x", 0)
	title.add_theme_constant_override("shadow_offset_y", 0)
	_box.add_child(title)
	var sub := UiStyle.label(Tr.t("Небо закрыла Пелена. Остался один фонарь."), 24, Color(0.95, 0.84, 0.65, 0.75), false, true)
	sub.autowrap_mode = TextServer.AUTOWRAP_OFF
	_box.add_child(sub)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 30)
	_box.add_child(sp)

	_cont_btn = _btn(Tr.t("Продолжить"))
	_cont_btn.pressed.connect(start)
	_cont_btn.visible = SaveGame.has_save()
	_new_btn = _btn(Tr.t("Новая игра"))
	_new_btn.pressed.connect(_on_new)
	var set_btn := _btn(Tr.t("Настройки"))
	set_btn.pressed.connect(func(): _settings.open())
	if not OS.has_feature("mobile"):
		var q := _btn(Tr.t("Выйти"))
		q.pressed.connect(func(): get_tree().quit())

	var touch := OS.has_feature("mobile")
	var ctl := UiStyle.label(Tr.t("Тап — идти  ·  долгое касание — поднять фонарь") if touch else Tr.t("WASD / клик — идти  ·  пробел — поднять фонарь  ·  E — действие  ·  J — журнал  ·  M — карта  ·  V — вид  ·  Esc — пауза"), 18, Color(0.95, 0.84, 0.65, 0.68))
	ctl.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	ctl.grow_horizontal = Control.GROW_DIRECTION_BOTH
	ctl.offset_top = -44
	ctl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ctl.autowrap_mode = TextServer.AUTOWRAP_OFF
	_root.add_child(ctl)

	_settings = SettingsPanel.new()
	_settings.build()
	add_child(_settings)
	_settings.language_changed.connect(func(): language_changed.emit())
	_settings.quality_changed.connect(func(): quality_changed.emit())
	_root.modulate.a = 0.0
	_box.modulate.a = 0.0


func _btn(text: String) -> Button:
	var b := UiStyle.text_button(text, 30)
	b.add_theme_color_override("font_color", Color(0.95, 0.84, 0.65, 0.85))
	b.add_theme_color_override("font_hover_color", Color(1.0, 0.7, 0.35))
	b.add_theme_color_override("font_pressed_color", Color(1.0, 0.7, 0.35))
	_box.add_child(b)
	return b


func set_ready() -> void:
	_ready_to_start = true


func _on_new() -> void:
	if SaveGame.has_save() and not _confirm_new:
		_confirm_new = true
		_new_btn.text = "›  " + Tr.t("Точно? Весь путь сотрётся — нажми ещё раз")
		return
	if SaveGame.has_save():
		_done = true
		new_game.emit()
	else:
		start()


## Начать игру (продолжить сохранение или начать без сохранения)
func start() -> void:
	if _done or not _ready_to_start:
		return
	_done = true
	started.emit()


func _process(dt: float) -> void:
	_t += dt
	if _done:
		_root.modulate.a = maxf(0.0, _root.modulate.a - dt * 1.5)
		if _root.modulate.a <= 0.0:
			visible = false
		return
	if _ready_to_start:
		_root.modulate.a = minf(1.0, _root.modulate.a + dt * 0.6)
		_box.modulate.a = Terrain.ss(0.8, 3.0, _t)
