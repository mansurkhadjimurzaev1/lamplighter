class_name Args
extends RefCounted
## Аргументы запуска после «--», например:  Godot --path . -- --autotest=/tmp/shots --q=low

static var _map := {}
static var _parsed := false


static func _parse() -> void:
	if _parsed:
		return
	_parsed = true
	for a in OS.get_cmdline_user_args():
		var s: String = a.trim_prefix("--")
		var eq := s.find("=")
		if eq >= 0:
			_map[s.substr(0, eq)] = s.substr(eq + 1)
		else:
			_map[s] = ""


static func has(key: String) -> bool:
	_parse()
	return _map.has(key)


static func get_value(key: String, default_value: String = "") -> String:
	_parse()
	return _map.get(key, default_value)
