class_name UiStyle
extends RefCounted
## Общий стиль интерфейса: пергамент, чернила, книжный шрифт.

const INK := Color(0.24, 0.15, 0.08)
const INK_SOFT := Color(0.38, 0.27, 0.16)
const INK_RED := Color(0.5, 0.16, 0.08)
const PAPER := Color(0.86, 0.78, 0.6)

static var _font: Font
static var _font_bold: Font
static var _font_italic: Font
static var _paper_tex: ImageTexture


static var _title_font: FontFile


## Книжный шрифт Cormorant Garamond (OFL, с кириллицей); жирность — через вариацию
static func font(bold := false, italic := false) -> Font:
	if _font == null:
		var reg: FontFile = load("res://assets/fonts/CormorantGaramond.ttf")
		var ita: FontFile = load("res://assets/fonts/CormorantGaramond-Italic.ttf")
		var r := FontVariation.new()
		r.base_font = reg
		r.variation_opentype = {"wght": 500}
		var b := FontVariation.new()
		b.base_font = reg
		b.variation_opentype = {"wght": 700}
		var i := FontVariation.new()
		i.base_font = ita
		i.variation_opentype = {"wght": 500}
		_font = r
		_font_bold = b
		_font_italic = i
	return _font_bold if bold else (_font_italic if italic else _font)


## Заглавный шрифт — славянская «вязь» Ruslan Display (OFL)
static func title_font() -> Font:
	if _title_font == null:
		_title_font = load("res://assets/fonts/RuslanDisplay-Regular.ttf")
	return _title_font


## Текстура пергамента: тёплая бумага с волокнами и потемневшими краями
static func paper_texture() -> ImageTexture:
	if _paper_tex:
		return _paper_tex
	var w := 512
	var h := 256
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var n := FastNoiseLite.new()
	n.frequency = 0.02
	n.fractal_octaves = 5
	var fib := FastNoiseLite.new()
	fib.frequency = 0.004
	fib.noise_type = FastNoiseLite.TYPE_PERLIN
	for y in h:
		for x in w:
			var v := n.get_noise_2d(x, y) * 0.5 + 0.5
			var f := fib.get_noise_2d(x * 6.0, y * 0.4) * 0.5 + 0.5
			var ex := minf(x, w - 1 - x) / float(w)
			var ey := minf(y, h - 1 - y) / float(h)
			var edge := clampf(minf(ex * 9.0, ey * 7.0), 0.0, 1.0)
			var c := PAPER * lerpf(0.82, 1.04, v) * lerpf(0.96, 1.02, f)
			c = c.lerp(Color(0.55, 0.4, 0.24), (1.0 - edge) * 0.55)
			c.a = 1.0
			img.set_pixel(x, y, c)
	_paper_tex = ImageTexture.create_from_image(img)
	return _paper_tex


static func paper_box() -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = paper_texture()
	sb.content_margin_left = 34
	sb.content_margin_right = 34
	sb.content_margin_top = 22
	sb.content_margin_bottom = 22
	return sb


static func label(text: String, size: int, color := INK, bold := false, italic := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(bold, italic))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## Кнопка-строка: текст чернилами, при наведении — красноватый с маркером
static func text_button(text: String, size := 20) -> Button:
	var b := Button.new()
	b.text = "›  " + text
	b.flat = true
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", font())
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", INK_SOFT)
	b.add_theme_color_override("font_hover_color", INK_RED)
	b.add_theme_color_override("font_pressed_color", INK_RED)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return b


static func clear() -> void:
	_title_font = null
	_font = null
	_font_bold = null
	_font_italic = null
	_paper_tex = null
