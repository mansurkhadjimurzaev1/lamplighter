class_name Quality
extends RefCounted
## Настройки качества: low / medium / high.
## Телефон → medium, компьютер → high. Переопределить: аргумент запуска  -- --q=low

static var level := "high"
static var shadows := true
static var grass_per_m2 := 40.0
static var volumetric_fog := true
static var ssao := true
static var fireflies := 110
static var dust := 200
static var min_render_scale := 0.6


static func setup() -> void:
	level = "medium" if OS.has_feature("mobile") else "high"
	if Settings.quality in ["low", "medium", "high"]:
		level = Settings.quality
	var forced := Args.get_value("q", "")
	if forced in ["low", "medium", "high"]:
		level = forced
	match level:
		"low":
			shadows = false; grass_per_m2 = 12.0; volumetric_fog = false; ssao = false
			fireflies = 40; dust = 60; min_render_scale = 0.5
		"medium":
			shadows = true; grass_per_m2 = 24.0; volumetric_fog = false; ssao = false
			fireflies = 70; dust = 120; min_render_scale = 0.55
		_:
			shadows = true; grass_per_m2 = 40.0; volumetric_fog = true; ssao = true
			fireflies = 110; dust = 200; min_render_scale = 0.5
	# отладочные переопределения: --shadows=0 --grass=10 --vfog=0
	if Args.has("shadows"): shadows = Args.get_value("shadows") == "1"
	if Args.has("grass"): grass_per_m2 = float(Args.get_value("grass"))
	if Args.has("vfog"): volumetric_fog = Args.get_value("vfog") == "1"
	if Args.has("ssao"): ssao = Args.get_value("ssao") == "1"
