class_name Journal
extends CanvasLayer
## Журнал заданий и записок — раскрытая книга. Клавиша J (на телефоне — кнопка).

signal closed

var _open := false
var _book: Control
var _left: VBoxContainer
var _right: VBoxContainer
var _note_text: Label
var _note_title: Label
var _selected := ""


func build() -> void:
	layer = 16
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.01, 0.03, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_book = Control.new()
	_book.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_book)
	visible = false


func is_open() -> bool:
	return _open


func open(note := "") -> void:
	_open = true
	visible = true
	if note != "":
		_selected = note
	_rebuild()


func close() -> void:
	_open = false
	visible = false
	closed.emit()


func _page(rect: Rect2) -> VBoxContainer:
	var p := PanelContainer.new()
	var sb := UiStyle.paper_box()
	sb.content_margin_left = 30
	sb.content_margin_right = 30
	sb.content_margin_top = 26
	p.add_theme_stylebox_override("panel", sb)
	p.position = rect.position
	p.size = rect.size
	_book.add_child(p)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	p.add_child(scroll)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 6)
	scroll.add_child(v)
	return v


func _rebuild() -> void:
	for c in _book.get_children():
		c.queue_free()
	var vs := get_viewport().get_visible_rect().size
	var portrait := vs.x < vs.y
	var w := minf(vs.x - 24.0, 1080.0)
	var h := minf(vs.y - 60.0, 640.0)
	var origin := (vs - Vector2(w, h)) / 2.0
	var lrect: Rect2
	var rrect: Rect2
	if portrait:
		lrect = Rect2(origin, Vector2(w, h * 0.5 - 4))
		rrect = Rect2(origin + Vector2(0, h * 0.5 + 4), Vector2(w, h * 0.5 - 4))
	else:
		lrect = Rect2(origin, Vector2(w * 0.5 - 2, h))
		rrect = Rect2(origin + Vector2(w * 0.5 + 2, 0), Vector2(w * 0.5 - 2, h))
	# корешок книги
	if not portrait:
		var spine := ColorRect.new()
		spine.color = Color(0.2, 0.12, 0.06, 0.8)
		spine.position = origin + Vector2(w * 0.5 - 6, 4)
		spine.size = Vector2(12, h - 8)
		_book.add_child(spine)
	_left = _page(lrect)
	_right = _page(rrect)

	# ── левая страница: задания и сумка
	_left.add_child(UiStyle.label("Задания", 30, UiStyle.INK_RED, true))
	var any := false
	for id in GameState.quest_data:
		var st := GameState.quest(id)
		if st == "active":
			any = true
			var q: Dictionary = GameState.quest_data[id]
			_left.add_child(UiStyle.label(q.title, 21, UiStyle.INK, true))
			_left.add_child(UiStyle.label(q.active, 17, UiStyle.INK_SOFT))
	for id in GameState.quest_data:
		if GameState.quest(id) == "done":
			any = true
			var q: Dictionary = GameState.quest_data[id]
			_left.add_child(UiStyle.label("✓ " + q.title, 18, Color(UiStyle.INK_SOFT, 0.6), false, true))
	if not any:
		_left.add_child(UiStyle.label("Пока ничего. Ольдрих ждёт у своего дома.", 17, UiStyle.INK_SOFT, false, true))
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 14)
	_left.add_child(sp)
	_left.add_child(UiStyle.label("В сумке", 24, UiStyle.INK_RED, true))
	var bag := []
	for id in GameState.items:
		var n := int(GameState.items[id])
		if n > 0:
			bag.append(GameState.item_name(id) + ("" if n == 1 else " ×%d" % n))
	_left.add_child(UiStyle.label(", ".join(bag) if bag.size() > 0 else "Пусто.", 17, UiStyle.INK_SOFT))

	# ── правая страница: записки
	_right.add_child(UiStyle.label("Записки", 30, UiStyle.INK_RED, true))
	if GameState.notes.is_empty():
		_right.add_child(UiStyle.label("Пока ни одной. Фонарь освещает не только дорогу.", 17, UiStyle.INK_SOFT, false, true))
	for id in GameState.notes:
		var b := UiStyle.text_button(GameState.note_data.get(id, {}).get("title", id), 19)
		var nid: String = id
		b.pressed.connect(func():
			_selected = nid
			_rebuild())
		_right.add_child(b)
	if _selected != "" and GameState.notes.has(_selected):
		var sep := ColorRect.new()
		sep.color = Color(UiStyle.INK_SOFT, 0.3)
		sep.custom_minimum_size = Vector2(0, 1)
		_right.add_child(sep)
		_right.add_child(UiStyle.label(GameState.note_data[_selected].title, 22, UiStyle.INK, true))
		_right.add_child(UiStyle.label(GameState.note_data[_selected].text, 18, UiStyle.INK, false, true))

	var close_b := UiStyle.text_button("Закрыть  (J)", 16)
	close_b.position = origin + Vector2(w - 160, h + 8)
	close_b.add_theme_color_override("font_color", Color(0.95, 0.85, 0.65))
	close_b.pressed.connect(close)
	_book.add_child(close_b)


func _input(e: InputEvent) -> void:
	if not _open:
		return
	if e is InputEventKey and e.pressed and not e.echo and e.physical_keycode in [KEY_J, KEY_ESCAPE]:
		close()
		get_viewport().set_input_as_handled()
