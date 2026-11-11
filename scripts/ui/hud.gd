class_name Hud
extends CanvasLayer
## Интерфейс поверх игры: маленький флакон масла (без полосок и цифр)
## и подсказка действия («зажечь маяк»).

signal action_pressed
signal journal_pressed

var oil := 1.0
var _flask := FlaskIcon.new()
var _prompt: Button
var _prompt_alpha := 0.0
var _prompt_want := false
var _touch := false
var show_flask := true
var _toasts: Array = [] # очередь уведомлений
var _toast: Label
var _toast_t := 0.0


class FlaskIcon extends Control:
	var level := 1.0
	var t := 0.0

	func _process(dt: float) -> void:
		t += dt
		queue_redraw()

	func _draw() -> void:
		# флакон: стеклянный контур, внутри тёплое масло; при малом уровне — тревожно мерцает
		var c := Vector2(24, 34)
		var low := clampf(1.0 - level / 0.25, 0.0, 1.0)
		var pulse := 0.65 + 0.35 * sin(t * (3.0 + low * 6.0))
		var glow := Color(1.0, 0.62, 0.22, (0.25 + 0.75 * level) * lerpf(1.0, pulse, low))
		var r := 14.0
		var fill_h := level * r * 2.0
		# масло — круг, «срезанный» по уровню
		var pts := PackedVector2Array()
		var top := c.y + r - fill_h
		for i in 33:
			var a := PI * 2.0 * i / 32.0
			var p := c + Vector2(cos(a), sin(a)) * (r - 2.0)
			p.y = maxf(p.y, top)
			pts.append(p)
		if level > 0.01:
			draw_colored_polygon(pts, glow)
			draw_circle(c + Vector2(0, 3), r * 1.8, Color(1.0, 0.55, 0.2, 0.06 * level))
		var glass := Color(0.95, 0.88, 0.75, 0.55)
		draw_arc(c, r, -PI * 0.38, PI * 1.38, 32, glass, 1.6, true)
		draw_line(c + Vector2(-5, -r + 1), c + Vector2(-5, -r - 9), glass, 1.6, true)
		draw_line(c + Vector2(5, -r + 1), c + Vector2(5, -r - 9), glass, 1.6, true)
		draw_rect(Rect2(c + Vector2(-6.5, -r - 15), Vector2(13, 6)), Color(0.6, 0.42, 0.26, 0.8))


func build() -> void:
	layer = 5
	_touch = OS.has_feature("mobile") or DisplayServer.is_touchscreen_available() and OS.has_feature("mobile")
	_flask.position = Vector2(18, 0)
	_flask.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_flask.offset_top = -78
	_flask.offset_left = 18
	_flask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flask.size = Vector2(50, 60)
	add_child(_flask)

	_prompt = Button.new()
	_prompt.flat = true
	_prompt.focus_mode = Control.FOCUS_NONE
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.offset_top = -110
	_prompt.offset_bottom = -70
	_prompt.offset_left = -200
	_prompt.offset_right = 200
	var font := UiStyle.font()
	_prompt.add_theme_font_override("font", font)
	_prompt.add_theme_font_size_override("font_size", 22)
	for st in ["font_color", "font_hover_color", "font_pressed_color"]:
		_prompt.add_theme_color_override(st, Color(1.0, 0.86, 0.62))
	_prompt.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.08, 0.9))
	_prompt.add_theme_constant_override("outline_size", 6)
	_prompt.pressed.connect(func(): action_pressed.emit())
	_prompt.modulate.a = 0.0
	add_child(_prompt)

	_toast = Label.new()
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.offset_top = 22
	_toast.offset_left = -360
	_toast.offset_right = 360
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast.add_theme_font_override("font", font)
	_toast.add_theme_font_size_override("font_size", 21)
	_toast.add_theme_color_override("font_color", Color(1.0, 0.88, 0.66))
	_toast.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.06, 0.9))
	_toast.add_theme_constant_override("outline_size", 6)
	_toast.modulate.a = 0.0
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toast)

	if _touch:
		var jb := Button.new()
		jb.text = Tr.t("Журнал")
		jb.focus_mode = Control.FOCUS_NONE
		jb.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		jb.offset_left = -130
		jb.offset_top = 14
		jb.offset_right = -14
		jb.offset_bottom = 56
		jb.add_theme_font_override("font", font)
		jb.add_theme_font_size_override("font_size", 20)
		jb.pressed.connect(func(): journal_pressed.emit())
		add_child(jb)


func show_prompt(text_pc: String, text_touch: String, on: bool) -> void:
	_prompt_want = on
	if on:
		_prompt.text = text_touch if _touch else text_pc


func toast(text: String) -> void:
	_toasts.append(text)


func _process(dt: float) -> void:
	_flask.level = oil
	_flask.visible = show_flask
	# уведомления по очереди: появиться, подержаться, исчезнуть
	_toast_t -= dt
	if _toast_t <= 0.0 and _toasts.size() > 0:
		_toast.text = _toasts.pop_front()
		_toast_t = 3.6
	_toast.modulate.a = clampf(minf(3.6 - _toast_t, _toast_t) * 2.0, 0.0, 1.0) if _toast_t > 0.0 else 0.0
	_prompt_alpha = move_toward(_prompt_alpha, 1.0 if _prompt_want else 0.0, dt * 3.0)
	_prompt.modulate.a = _prompt_alpha * (0.8 + 0.2 * sin(Time.get_ticks_msec() * 0.003))
	_prompt.visible = _prompt_alpha > 0.01
	_prompt.mouse_filter = Control.MOUSE_FILTER_STOP if _prompt_want else Control.MOUSE_FILTER_IGNORE
