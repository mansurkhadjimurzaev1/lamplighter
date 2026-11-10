class_name GameState
extends RefCounted
## Состояние истории: флаги, задания, вещи в сумке, найденные записки.
## Условия и действия диалогов записаны строками, например:
##   условия: "flag:has_lantern", "!item:wire", "quest:lia_sun=active", "trinkets", "a & b"
##   действия: "flag:x", "quest:id=done", "give:wire", "take:$sel", "oil:0.5", "note:id", "upgrade_lantern", "save"

static var flags := {}
static var quests := {}
static var items := {}
static var notes: Array = []
static var picked := {} # подобранные находки в мире
static var sel := "" # выбранная для обмена вещь

static var quest_data := {}
static var item_data := {}
static var note_data := {}

## Действия, которые выполняет сама игра (масло, фонарь, сохранение, уведомления)
static var hooks := {}


static func load_data() -> void:
	quest_data = _json("res://data/quests.json")
	item_data = _json("res://data/items.json")
	note_data = _json("res://data/notes.json")


static func _json(path: String) -> Dictionary:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return d if typeof(d) == TYPE_DICTIONARY else {}


static func reset() -> void:
	flags = {}
	quests = {}
	items = {}
	notes = []
	picked = {}
	sel = ""


static func to_dict() -> Dictionary:
	return {flags = flags, quests = quests, items = items, notes = notes, picked = picked}


static func from_dict(d: Dictionary) -> void:
	flags = d.get("flags", {})
	quests = d.get("quests", {})
	items = d.get("items", {})
	notes = d.get("notes", [])
	picked = d.get("picked", {})


static func quest(id: String) -> String:
	return quests.get(id, "")


static func trinkets() -> Array:
	var out := []
	for id in items:
		if int(items[id]) > 0 and item_data.get(id, {}).get("trinket", false):
			out.append(id)
	return out


static func item_name(id: String) -> String:
	return item_data.get(id, {}).get("name", id)


static func check(cond: String) -> bool:
	if cond.strip_edges() == "" or cond == "true":
		return true
	for part in cond.split("&"):
		if not _check_one(part.strip_edges()):
			return false
	return true


static func _check_one(c: String) -> bool:
	var neg := c.begins_with("!")
	if neg:
		c = c.substr(1)
	var r := false
	if c == "trinkets":
		r = trinkets().size() > 0
	elif c.begins_with("flag:"):
		r = flags.get(c.substr(5), false)
	elif c.begins_with("item:"):
		var body := c.substr(5)
		if ">=" in body:
			var kv := body.split(">=")
			r = int(items.get(kv[0], 0)) >= int(kv[1])
		else:
			r = int(items.get(body, 0)) > 0
	elif c.begins_with("quest:"):
		var body := c.substr(6)
		if "!=" in body:
			var kv := body.split("!=")
			r = quest(kv[0]) != kv[1]
		else:
			var kv := body.split("=")
			r = quest(kv[0]) == kv[1]
	return r != neg


static func apply(a: String) -> void:
	a = a.replace("$sel", sel)
	if a.begins_with("flag:"):
		flags[a.substr(5)] = true
	elif a.begins_with("quest:"):
		var kv := a.substr(6).split("=")
		var old := quest(kv[0])
		if old == kv[1] or (old == "done" and kv[1] == "active"):
			return
		quests[kv[0]] = kv[1]
		var title: String = quest_data.get(kv[0], {}).get("title", kv[0])
		_notify("Задание выполнено: " + title if kv[1] == "done" else "Новое задание: " + title)
	elif a.begins_with("give:"):
		var id := a.substr(5)
		items[id] = int(items.get(id, 0)) + 1
		_notify("Получено: " + item_name(id))
	elif a.begins_with("take:"):
		var id := a.substr(5)
		var count := 1
		if "*" in id:
			count = int(id.get_slice("*", 1))
			id = id.get_slice("*", 0)
		items[id] = maxi(0, int(items.get(id, 0)) - count)
		if items[id] == 0:
			items.erase(id)
	elif a.begins_with("note:"):
		var id := a.substr(5)
		if not notes.has(id):
			notes.append(id)
			_notify("Новая запись в журнале: " + note_data.get(id, {}).get("title", id))
	elif a.begins_with("oil:"):
		_hook("oil", float(a.substr(4)))
	else:
		_hook(a, null)


static func _hook(name: String, arg: Variant) -> void:
	if hooks.has(name):
		if arg == null:
			hooks[name].call()
		else:
			hooks[name].call(arg)


static func _notify(text: String) -> void:
	_hook("notify", text)
