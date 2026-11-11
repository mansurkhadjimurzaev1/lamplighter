class_name Settings
extends RefCounted
## Настройки игрока: громкость, качество, язык. Хранятся в user://settings.json.

const PATH := "user://settings.json"

static var volume := 0.85 # общая громкость 0..1
static var quality := "" # "" — автоматически (по устройству), иначе low / medium / high
static var lang := "ru"
static var first_person := false # тестовый вид от первого лица (V)


static func load_settings() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if typeof(d) != TYPE_DICTIONARY:
		return
	volume = clampf(float(d.get("volume", volume)), 0.0, 1.0)
	quality = str(d.get("quality", quality))
	lang = str(d.get("lang", lang))
	if not lang in ["ru", "en"]:
		lang = "ru"
	first_person = bool(d.get("first_person", false))


static func save_settings() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({volume = volume, quality = quality, lang = lang, first_person = first_person}, "\t"))
