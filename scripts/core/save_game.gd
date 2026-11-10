class_name SaveGame
extends RefCounted
## Сохранение в user://save.json. Пишется только у маяков (маяк = точка сохранения).

const PATH := "user://save.json"

static var lit: Array = [] # индексы зажжённых маяков
static var last_beacon := -1 # где проснуться
static var oil := 1.0
static var flasks_taken: Array = [] # индексы подобранных флаконов
static var state := {} # история: флаги, задания, вещи, записки
static var explored := "" # исследованное на карте


static func load_game() -> void:
	if Args.has("newgame") or not FileAccess.file_exists(PATH):
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	var data: Variant = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return
	if not data.has("state"):
		return # сохранение старой версии (до деревни и сюжета) — начинаем заново
	lit = data.get("lit", [])
	last_beacon = int(data.get("last_beacon", -1))
	oil = float(data.get("oil", 1.0))
	flasks_taken = data.get("flasks_taken", [])
	state = data.get("state", {})
	explored = data.get("explored", "")
	GameState.from_dict(state)


## Новая игра: стираем сохранение
static func reset() -> void:
	lit = []
	last_beacon = -1
	oil = 1.0
	flasks_taken = []
	state = {}
	explored = ""
	GameState.reset()
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


static func has_save() -> bool:
	if not FileAccess.file_exists(PATH):
		return false
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return typeof(d) == TYPE_DICTIONARY and d.has("state")


static func save() -> void:
	if Args.has("nosave"):
		return
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	state = GameState.to_dict()
	f.store_string(JSON.stringify({lit = lit, last_beacon = last_beacon, oil = oil, flasks_taken = flasks_taken, state = state, explored = explored}, "\t"))
