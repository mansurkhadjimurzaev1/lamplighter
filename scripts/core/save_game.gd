class_name SaveGame
extends RefCounted
## Сохранение в user://save.json. Пишется только у маяков (маяк = точка сохранения).

const PATH := "user://save.json"

static var lit: Array = [] # индексы зажжённых маяков
static var last_beacon := -1 # где проснуться
static var oil := 1.0
static var flasks_taken: Array = [] # индексы подобранных флаконов


static func load_game() -> void:
	if Args.has("newgame") or not FileAccess.file_exists(PATH):
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	var data: Variant = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return
	lit = data.get("lit", [])
	last_beacon = int(data.get("last_beacon", -1))
	oil = float(data.get("oil", 1.0))
	flasks_taken = data.get("flasks_taken", [])


## Новая игра: стираем сохранение
static func reset() -> void:
	lit = []
	last_beacon = -1
	oil = 1.0
	flasks_taken = []
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


static func has_save() -> bool:
	return FileAccess.file_exists(PATH)


static func save() -> void:
	if Args.has("nosave"):
		return
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({lit = lit, last_beacon = last_beacon, oil = oil, flasks_taken = flasks_taken}, "\t"))
