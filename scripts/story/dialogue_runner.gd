class_name DialogueRunner
extends RefCounted
## Ведёт разговор по данным из data/dialogues/<id>.json.

static var _cache := {}

var npc := ""
var data := {}
var node_id := ""
var page := 0
var pages: Array = []
var choices: Array = [] # [{text, next, do}]


static func load_npc(id: String) -> Dictionary:
	if not _cache.has(id):
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(Tr.data_path("res://data/dialogues/%s.json" % id)))
		_cache[id] = d if typeof(d) == TYPE_DICTIONARY else {}
	return _cache[id]


## Есть ли у жителя что сказать (огонёк над головой)
static func has_news(id: String) -> bool:
	for c in load_npc(id).get("news", []):
		if GameState.check(c):
			return true
	return false


func start(id: String) -> bool:
	npc = id
	data = load_npc(id)
	for e in data.get("entries", []):
		if GameState.check(e.get("if", "true")):
			_enter(e.node)
			return true
	return false


func speaker() -> String:
	return data.get("name", npc)


func current_text() -> String:
	return pages[page] if page < pages.size() else ""


func is_last_page() -> bool:
	return page >= pages.size() - 1


func _enter(id: String) -> void:
	node_id = id
	page = 0
	choices = []
	var n: Dictionary = data.nodes.get(id, {})
	var t: Variant = n.get("text", "")
	if n.has("alt") and GameState.check(n.alt.get("if", "")):
		t = n.alt.text
	pages = t if t is Array else [t]
	pages = pages.map(func(p): return _fill(p))
	for a in n.get("do", []):
		GameState.apply(a)
	if n.has("choices_from") and n.choices_from == "trinkets":
		for id_item in GameState.trinkets():
			choices.append({text = Tr.t("Отдать: ") + GameState.item_name(id_item), next = n.get("pick_next", "end"), pick = id_item})
		choices.append({text = Tr.t("Передумал."), next = "menu" if data.nodes.has("menu") else "end"})
	else:
		for c in n.get("choices", []):
			if GameState.check(c.get("if", "true")):
				choices.append(c)


func _fill(t: String) -> String:
	if "{sel_mara}" in t:
		t = t.replace("{sel_mara}", GameState.item_data.get(GameState.sel, {}).get("mara", Tr.t("Хорошая вещь.")))
	return t


## Следующая страница или узел (если нет выбора). false — разговор окончен.
func advance() -> bool:
	if page < pages.size() - 1:
		page += 1
		return true
	if choices.size() > 0:
		return true
	var nxt: String = data.nodes.get(node_id, {}).get("next", "end")
	if nxt == "end" or not data.nodes.has(nxt):
		return false
	_enter(nxt)
	return true


## Выбор варианта ответа. false — разговор окончен.
func choose(i: int) -> bool:
	if i < 0 or i >= choices.size():
		return true
	var c: Dictionary = choices[i]
	if c.has("pick"):
		GameState.sel = c.pick
	for a in c.get("do", []):
		GameState.apply(a)
	var nxt: String = c.get("next", "end")
	if nxt == "end" or not data.nodes.has(nxt):
		return false
	_enter(nxt)
	return true
