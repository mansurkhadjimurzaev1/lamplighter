extends Node3D
## Точка входа: собирает мир, деревню, жителей, героя, свет, звук и интерфейс; главный цикл.
## Состояния: PLAY — игра, LIGHTING — зажигание маяка, FAINT — обморок,
## DIALOGUE — разговор, JOURNAL — журнал открыт.

enum State { PLAY, LIGHTING, FAINT, DIALOGUE, JOURNAL, MAP, FERRY, PAUSE, MENU, ENDING, CUTSCENE }

## Задание, которое закрывается зажжением маяка (по номеру маяка)
const BEACON_QUESTS := ["light_beacon", "forest_beacon", "swamp_beacon", "mountain_beacon", "castle_final"]

const NPCS := [
	{id = "oldrich", name = "Ольдрих", model = "KK_Barbarian", hide_extra = ["Barbarian_Hat", "Barbarian_Cape"], height = 1.45,
		swaps = [[Color("#4a6680"), 0.2, Color(0.46, 0.4, 0.33)]]},
	{id = "borta", name = "Борта", model = "KK_Knight", hide_extra = ["Knight_Helmet", "Knight_Cape"], height = 1.6,
		swaps = [[Color("#788088"), 0.1, Color(0.4, 0.26, 0.15)], [Color("#a8b8b8"), 0.08, Color(0.55, 0.38, 0.22)], [Color("#701838"), 0.12, Color(0.35, 0.22, 0.12)]]},
	{id = "lia", name = "Лия", model = "KK_Rogue", hide_extra = ["Rogue_Cape"], height = 1.0, pose = "Sit_Floor_Idle", sitting = true,
		swaps = [[Color("#008a52"), 0.3, Color(0.9, 0.66, 0.28)]]},
	# Мара — в покрывале (капюшон) и длинном плаще тёплых цветов
	{id = "vale", name = "Вейл", model = "KK_Mage", hide_extra = ["Mage_Hat", "Mage_Cape"], height = 1.5, forest = true,
		swaps = [[Color("#2c2c4c"), 0.16, Color(0.28, 0.33, 0.18)], [Color("#a01858"), 0.15, Color(0.55, 0.42, 0.22)]]},
	# паромщик стоит в своей лодке
	{id = "ferryman", name = "Корней", model = "KK_Barbarian", hide_extra = ["Barbarian_Hat"], height = 1.5, swamp = true,
		swaps = [[Color("#4a6680"), 0.2, Color(0.24, 0.27, 0.22)], [Color("#985840"), 0.08, Color(0.3, 0.22, 0.14)]]},
	# учёный — в тёмно-синем халате, без колпака
	{id = "ansar", name = "Ансар", model = "KK_Mage", hide_extra = ["Mage_Hat"], height = 1.5, mountain = true,
		swaps = [[Color("#2c2c4c"), 0.16, Color(0.16, 0.2, 0.32)], [Color("#a01858"), 0.15, Color(0.62, 0.5, 0.3)]]},
	# король: доспех под выцветшей мантией, корона, сидит на троне
	{id = "king", name = "Король", model = "KK_Knight", hide_extra = ["Knight_Helmet"], height = 1.55, castle = true, crown = true, pose = "Sit_Chair_Idle",
		swaps = [[Color("#788088"), 0.1, Color(0.32, 0.26, 0.36)], [Color("#a8b8b8"), 0.08, Color(0.5, 0.45, 0.5)], [Color("#701838"), 0.12, Color(0.4, 0.08, 0.1)]]},
	{id = "mara", name = "Мара", model = "KK_Rogue_Hooded", height = 1.42,
		swaps = [[Color("#008a52"), 0.3, Color(0.62, 0.26, 0.17)], [Color("#985840"), 0.1, Color(0.82, 0.7, 0.5)]]},
]

var START := Vector2(0, 4)

var terrain: MeshInstance3D
var vegetation: Vegetation
var village: Village
var forest: Forest
var _forest_f := 0.0
var swamp: Swamp
var _swamp_f := 0.0
var _bog_t := 0.0
var _bog_warned := false
var ferryman: Villager
var mountains: Mountains
var _mtn_f := 0.0
var _cold := 0.0 # 0..1 — холод гасит фонарь
var _cold_warned := 0
var castle: Castle
var castle_shades: Shades
var _castle_f := 0.0
var _moon: DirectionalLight3D
var _drips: AudioStreamPlayer
var _gate_hint_t := 0.0
var _gate_announced := false
var hero: Hero
var lantern: Lantern
var cam: CameraRig
var sound: Soundscape
var region_audio: RegionAudio
var title: MainMenu
var _loading: LoadingScreen
var ending: Ending
var prologue: Prologue
## Этап 6: дома с интерьерами, волны Пелены, подсказка цели, добрые дела
var interiors: Interiors
var veil := Veil.new()
var goal_hud: GoalHud
var deeds: Deeds
var _door_t := -1.0 # переход через дверь (затемнение), −1 — нет
var _door_to := -1 # куда: номер комнаты или −1 — наружу
var _rumble: AudioStreamPlayer
var _guide_t := 0.0
var _veil_vis := 0.0
var _ash: GPUParticles3D
var ambience: Ambience
var _moths: GPUParticles3D
var _exposure := 0.0
var _menu_spot := Vector3.ZERO
var _menu_fire: Node3D
var _ending_pending := -1.0 # отсчёт до начала хорошего финала после зажжения пятого маяка
var fps: FpsMeter
var hud: Hud
var dialogue: DialogueBox
var journal: Journal
var pause_menu: PauseMenu
var minimap: Minimap
var _revealed_beacons := {}
var grade: ShaderMaterial
var env: WorldEnvironment
var beacons: Array[Beacon] = []
var flasks: OilFlasks
var _extra_flasks: Array[OilFlasks] = []
var pickups: Pickups
var shades: Shades
var npcs: Array[Villager] = []
var oil := Oil.new()
var colliders: Array[Vector3] = []
## Места, где можно что-то сделать клавишей E: {pos, r, pc, touch, act: Callable, ok: Callable}
var interactables: Array = []

var started := false
var state := State.PLAY
var _state_t := 0.0
var _talking_to := ""
var _fade := 0.0
var _faint_mult := 1.0
var _dawn := 0.0
var _next_step_at := 0.65
var _last_hero_pos := Vector3.ZERO
var _velocity := Vector3.ZERO
var _press_pos := Vector2.ZERO
var _press_time := 0
var _pressing := false
var _touch_raise := false
var _mouse_raise := false
var _quill: AudioStreamWAV
var raised := false
# адаптивное разрешение
var render_scale := 1.0
var _frame_samples: Array[float] = []
var _scale_cooldown := 3.0
var _shadow_soft := true


func _ready() -> void:
	Settings.load_settings()
	if Args.has("lang"):
		Settings.lang = Args.get_value("lang") # для проверок, без сохранения
	Quality.setup()
	_loading = LoadingScreen.new()
	_loading.build()
	add_child(_loading)
	Beacon.all.clear()
	GameState.load_data()
	GameState.reset()
	SaveGame.load_game()
	_setup_input()
	if Args.has("bench"):
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0

	title = MainMenu.new()
	title.build()
	add_child(title)
	title.started.connect(_on_start)
	title.new_game.connect(_restart)
	title.language_changed.connect(func(): get_tree().reload_current_scene())
	title.quality_changed.connect(_apply_quality_live)
	grade = Atmosphere.grade_layer(self)
	grade.set_shader_parameter("fade", 0.0)
	if Args.has("earlyN") and not get_tree().has_meta("pressed_n"):
		get_tree().set_meta("pressed_n", true)
		get_tree().create_timer(0.3).timeout.connect(func():
			var ev := InputEventKey.new()
			ev.physical_keycode = KEY_N
			ev.pressed = true
			Input.parse_input_event(ev))
	fps = FpsMeter.new()
	fps.build()
	fps.extra = func(): return Tr.t("%s · %.0f%% разрешения%s · кадр %.1f мс · масло %.0f%%") % [Quality.level, render_scale * 100.0, "" if env == null or env.environment.ssao_enabled else Tr.t(" · эффекты упрощены"), _median(), oil.level * 100.0]
	add_child(fps)

	await get_tree().process_frame
	await get_tree().process_frame
	_build_world()
	_setup_menu_vista()
	_loading.close()
	title.set_ready()
	state = State.MENU
	sound.start() # в меню — ночной ветер, сверчки, треск костра
	if Args.has("menulook"):
		_menu_look()
	elif SaveGame.skip_menu_once or Args.has("autotest") or Args.has("bench"):
		SaveGame.skip_menu_once = false
		title.visible = false
		title.start()
	if Args.has("pausetest"):
		print("before: has_lantern=", GameState.flags.get("has_lantern", false), " has_save=", SaveGame.has_save())
		if not get_tree().has_meta("paused_once"):
			get_tree().set_meta("paused_once", true)
			title.start()
			await get_tree().create_timer(1.5).timeout
			var esc := InputEventKey.new()
			esc.physical_keycode = KEY_ESCAPE
			esc.pressed = true
			Input.parse_input_event(esc)
			await get_tree().create_timer(0.5).timeout
			print("paused state=", state, " menu open=", pause_menu.is_open())
			pause_menu._on_new()
			print("after 1st click has_save=", SaveGame.has_save())
			pause_menu._on_new()
		else:
			await get_tree().create_timer(2.0).timeout
			get_tree().quit()
	if Args.has("earlyN"):
		print("earlyN: has_lantern=", GameState.flags.get("has_lantern", false), " has_save=", SaveGame.has_save())
		if not get_tree().has_meta("early_done"):
			get_tree().set_meta("early_done", true)
		else:
			await get_tree().create_timer(2.0).timeout
			get_tree().quit()
	if Args.has("presstest"):
		print("before N: has_lantern=", GameState.flags.get("has_lantern", false), " lit=", SaveGame.lit, " has_save=", SaveGame.has_save())
		if Engine.get_frames_drawn() > 0 and not get_tree().has_meta("pressed_n"):
			get_tree().set_meta("pressed_n", true)
			await get_tree().create_timer(1.0).timeout
			var ev := InputEventKey.new()
			ev.physical_keycode = KEY_N
			ev.keycode = KEY_N
			ev.pressed = true
			Input.parse_input_event(ev)
		else:
			await get_tree().create_timer(2.0).timeout
			get_tree().quit()
	if Args.has("autotest"):
		_autotest(Args.get_value("autotest", "user://shots"))
	elif Args.has("bench"):
		_bench()


func _build_world() -> void:
	env = Atmosphere.environment()
	add_child(env)
	if Args.has("bright"): # отладка: светло, без тумана
		env.environment.ambient_light_energy = 4.0
		env.environment.fog_enabled = false
		env.environment.volumetric_fog_enabled = false
	_moon = Atmosphere.moon()
	add_child(_moon)

	# деревня и маяк над ней: маяк — на вершине холма в 15–22 м от площади
	VillageLayout.setup()
	Terrain.setup()
	CastleLayout.setup()
	START = VillageLayout.world(VillageLayout.HERO_START)
	var vc := VillageLayout.CENTER
	var beacon_pos := Beacon.find_hilltop(Vector3(vc.x, 0, vc.y), 15.0, 22.0)
	VillageLayout.build_paths(beacon_pos)

	terrain = Terrain.build()
	add_child(terrain)
	var water := Water.new()
	water.build()
	add_child(water)

	vegetation = Vegetation.new()
	vegetation.name = "Vegetation"
	vegetation.exclusions.append(Vector3(beacon_pos.x, beacon_pos.z, 6.0))
	vegetation.exclusions.append(Vector3(vc.x, vc.y, VillageLayout.RADIUS + 1.0))
	# въезд на мост к замку — без деревьев и камней
	var bsx := CastleLayout.bridge_start
	vegetation.exclusions.append(Vector3(bsx.x, bsx.y, 4.0))
	vegetation.exclusions.append(Vector3(bsx.x, bsx.y - 4.0, 3.0))
	var road := VillageLayout.dirt_road
	for i in 8:
		var rp := road[0].lerp(road[1], i / 7.0)
		vegetation.exclusions.append(Vector3(rp.x, rp.y, 2.2))

	var grass := Grass.new()
	grass.name = "Grass"
	grass.build(Quality.grass_per_m2)
	add_child(grass)
	vegetation.build(Quality.shadows)
	vegetation.build_forest(Quality.shadows)
	add_child(vegetation)
	colliders = vegetation.colliders
	forest = Forest.new()
	add_child(forest)
	forest.build()
	colliders.append_array(forest.colliders)
	vegetation.build_swamp(Quality.shadows)
	swamp = Swamp.new()
	add_child(swamp)
	swamp.build()
	colliders.append_array(swamp.colliders)
	mountains = Mountains.new()
	add_child(mountains)
	mountains.build()
	colliders.append_array(mountains.colliders)
	castle = Castle.new()
	add_child(castle)
	castle.build()
	colliders.append_array(castle.colliders)
	village = Village.new()
	add_child(village)
	if not Args.has("skip_village"):
		village.build()
	colliders.append_array(village.colliders)
	_build_interiors()

	var rock_tex: Texture2D = load("res://assets/textures/ground/Rock030_color.jpg")
	var b := Beacon.new()
	add_child(b)
	# волна маяка деревни накрывает всю деревню
	var area := maxf(Beacon.MAX_RADIUS, Vector2(beacon_pos.x, beacon_pos.z).distance_to(vc) + VillageLayout.RADIUS + 2.0)
	b.build(0, beacon_pos, rock_tex, area)
	colliders.append(b.collider)
	b.set_flowers(vegetation.build_bloom(beacon_pos, area, 700))
	beacons.append(b)
	# маяк Шепчущего леса — на поляне в глубине леса
	var fb2 := ForestLayout.node("B")
	var fbp := Vector3(fb2.x, Terrain.height_at(fb2.x, fb2.y), fb2.y)
	var b2 := Beacon.new()
	add_child(b2)
	b2.build(1, fbp, rock_tex, 32.0)
	colliders.append(b2.collider)
	b2.set_flowers(vegetation.build_bloom(fbp, 26.0, 500))
	beacons.append(b2)
	# маяк над Топью — на островке за протокой
	var sbp := Vector3(SwampLayout.BEACON.x, Terrain.height_at(SwampLayout.BEACON.x, SwampLayout.BEACON.y), SwampLayout.BEACON.y)
	var b3 := Beacon.new()
	add_child(b3)
	b3.build(2, sbp, rock_tex, SwampLayout.RADIUS + 6.0)
	colliders.append(b3.collider)
	b3.set_flowers(vegetation.build_bloom(sbp, SwampLayout.RADIUS, 300))
	beacons.append(b3)
	# маяк на утёсе у обсерватории
	var mbp := Vector3(MountainLayout.BEACON.x, Terrain.height_at(MountainLayout.BEACON.x, MountainLayout.BEACON.y), MountainLayout.BEACON.y)
	var b4 := Beacon.new()
	add_child(b4)
	b4.build(3, mbp, rock_tex, MountainLayout.RADIUS + 12.0)
	colliders.append(b4.collider)
	b4.set_flowers(vegetation.build_bloom(mbp, MountainLayout.RADIUS, 250))
	beacons.append(b4)
	# пятый маяк — во дворе замка (зажечь можно будет в финале)
	var cbp := Vector3(CastleLayout.BEACON.x, Terrain.height_at(CastleLayout.BEACON.x, CastleLayout.BEACON.y) + 0.4, CastleLayout.BEACON.y)
	var b5 := Beacon.new()
	add_child(b5)
	b5.build(4, cbp, rock_tex, 60.0)
	colliders.append(b5.collider)
	beacons.append(b5)

	flasks = OilFlasks.new()
	flasks.build(12, colliders, [Vector3(beacon_pos.x, beacon_pos.z, 5.0), Vector3(vc.x, vc.y, VillageLayout.RADIUS + 2.0)], SaveGame.flasks_taken)
	add_child(flasks)
	flasks.picked.connect(_on_flask)
	var forest_flasks := OilFlasks.new()
	forest_flasks.name = "ForestFlasks"
	forest_flasks.build(7, colliders, [Vector3(fb2.x, fb2.y, 6.0)], SaveGame.flasks_taken, Vector3(ForestLayout.CENTER.x, ForestLayout.CENTER.y, ForestLayout.RADIUS - 2.0), 100)
	add_child(forest_flasks)
	forest_flasks.picked.connect(_on_flask)
	_extra_flasks.append(forest_flasks)
	var swamp_flasks := OilFlasks.new()
	swamp_flasks.name = "SwampFlasks"
	swamp_flasks.build(6, colliders, [Vector3(SwampLayout.BEACON.x, SwampLayout.BEACON.y, SwampLayout.RING_OUT)], SaveGame.flasks_taken, Vector3(SwampLayout.CENTER.x, SwampLayout.CENTER.y, SwampLayout.RADIUS - 3.0), 200, 0.0)
	add_child(swamp_flasks)
	swamp_flasks.picked.connect(_on_flask)
	_extra_flasks.append(swamp_flasks)
	var mtn_flasks := OilFlasks.new()
	mtn_flasks.name = "MountainFlasks"
	mtn_flasks.build(5, colliders, [Vector3(MountainLayout.OBS.x, MountainLayout.OBS.y, 4.0)], SaveGame.flasks_taken, Vector3(MountainLayout.CENTER.x, MountainLayout.CENTER.y, MountainLayout.RADIUS), 300, 0.0)
	add_child(mtn_flasks)
	mtn_flasks.picked.connect(_on_flask)
	_extra_flasks.append(mtn_flasks)

	add_child(Particles.fireflies(Quality.fireflies))
	add_child(Particles.dust(Quality.dust))

	hero = Hero.new()
	add_child(hero)
	hero.build()
	lantern = Lantern.new()
	lantern.build(Quality.shadows)
	add_child(lantern)

	cam = CameraRig.new()
	cam.setup()
	add_child(cam)
	cam.current = true

	sound = Soundscape.new()
	sound.build()
	add_child(sound)
	region_audio = RegionAudio.new()
	region_audio.build()
	add_child(region_audio)
	ambience = Ambience.new()
	add_child(ambience)
	ambience.build()
	for bb in beacons:
		bb.sound = sound
	if not Args.has("skip_vsound"):
		_village_sounds()
	_quill = Synth.wav(Synth.quill(), false)

	shades = Shades.new()
	add_child(shades)
	shades.build(6 if Quality.level != "low" else 4)
	castle_shades = Shades.new()
	add_child(castle_shades)
	castle_shades.build(8 if Quality.level != "low" else 5, true)
	castle_shades.sound = sound
	_drips = AudioStreamPlayer.new()
	_drips.stream = Synth.cached("drips", func(): return Synth.drips(19.0, 89), true)
	_drips.volume_db = -80.0
	add_child(_drips)
	shades.sound = sound

	hud = Hud.new()
	hud.build()
	add_child(hud)
	goal_hud = GoalHud.new()
	goal_hud.build()
	add_child(goal_hud)
	goal_hud.cam = cam
	_ash = _make_ash()
	add_child(_ash)
	_moths = _make_moths()
	lantern.add_child(_moths)
	_rumble = AudioStreamPlayer.new()
	_rumble.stream = Synth.cached("veil_rumble", func(): return Synth.filter(Synth.noise(12.0, true), "lp", 140.0, 0.7), true)
	_rumble.volume_db = -80.0
	add_child(_rumble)
	hud.action_pressed.connect(_interact)
	hud.journal_pressed.connect(_open_journal)
	dialogue = DialogueBox.new()
	dialogue.build(func(): sound.play(_quill, 0.05, randf_range(0.9, 1.2)))
	add_child(dialogue)
	dialogue.closed.connect(_on_dialogue_closed)
	journal = Journal.new()
	journal.build()
	add_child(journal)
	journal.closed.connect(func(): state = State.PLAY)
	pause_menu = PauseMenu.new()
	pause_menu.build()
	add_child(pause_menu)
	pause_menu.resume.connect(func(): state = State.PLAY)
	pause_menu.new_game.connect(_restart)
	pause_menu.quit_game.connect(func(): get_tree().quit())
	pause_menu.language_changed.connect(func():
		_save_progress()
		get_tree().reload_current_scene())
	pause_menu.quality_changed.connect(_apply_quality_live)

	if not Args.has("skip_npcs"):
		_spawn_npcs()
	_spawn_pickups(beacon_pos)
	deeds = Deeds.new()
	add_child(deeds)
	deeds.build(pickups)
	deeds.message.connect(func(t): hud.toast(t))
	_setup_interactables()

	# карта: рисуем мир, восстанавливаем исследованное
	MapData.build(colliders)
	MapData.from_string_data(SaveGame.explored)
	# свою деревню фонарщик знает наизусть
	MapData.reveal(VillageLayout.CENTER, VillageLayout.RADIUS + 4.0)
	minimap = Minimap.new()
	minimap.build()
	add_child(minimap)
	if Args.has("nomap"):
		minimap.visible = false
	minimap.toggled.connect(func(open):
		if open and state == State.PLAY:
			state = State.MAP
			hero.move_target = null
		elif not open and state == State.MAP:
			state = State.PLAY)
	var vcl := VillageLayout.CENTER
	minimap.labels = [{pos = CastleLayout.CENTER + Vector2(0, CastleLayout.RADIUS - 2.0), text = Tr.t("Руины замка")}, {pos = vcl + Vector2(0, VillageLayout.RADIUS + 4.0), text = Tr.t("Тихий Брод")}, {pos = ForestLayout.CENTER + Vector2(0, 8), text = Tr.t("Шепчущий лес")}, {pos = SwampLayout.CENTER + Vector2(0, 18), text = Tr.t("Топь")}, {pos = MountainLayout.CENTER + Vector2(0, 22), text = Tr.t("Горная обсерватория")}]

	# действия из диалогов, которые выполняет игра
	GameState.hooks = {
		notify = func(t): hud.toast(t),
		oil = func(v): oil.add(v),
		upgrade_lantern = _upgrade_lantern,
		save = _save_progress,
		king_to_beacon = _king_to_beacon,
		ending_bad = func(): _start_ending.call_deferred(false),
		deliver_letter = _check_letters,
	}

	# загрузка сохранения
	for i in SaveGame.lit:
		if int(i) < beacons.size():
			beacons[int(i)].set_lit_instant()
	oil.level = SaveGame.oil
	for bi in mountains.braziers.size():
		if GameState.flags.get("brazier_%d" % bi, false):
			mountains.light_brazier(bi)
	for li in village.lamps.size():
		village.set_lamp(li, GameState.flags.get("lamp_%d" % li, false), true)
	if GameState.flags.get("lantern_upgraded", false):
		oil.upgrade()
		lantern.upgrade()
	if GameState.quest("get_lantern") == "":
		GameState.quests["get_lantern"] = "active"
	var lit0 := 0
	for i in 4:
		if beacons[i].lit:
			lit0 += 1
	CastleLayout.gate_open = lit0 >= 4
	_gate_announced = CastleLayout.gate_open
	castle.set_gate(CastleLayout.gate_open, true)
	hero.global_position = _respawn_point()
	_last_hero_pos = hero.global_position
	cam.snap(hero.global_position)

	var vp := get_viewport()
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if not OS.has_feature("mobile") else Viewport.SCALING_3D_MODE_BILINEAR
	_pick_upscaler()
	get_window().size_changed.connect(_pick_upscaler)
	if Args.has("nograde"):
		for c in get_children():
			if c is CanvasLayer and c.layer == 1:
				c.visible = false


func _exit_tree() -> void:
	# статические кэши держат ресурсы — отпускаем до остановки движка
	Props.clear()
	UiStyle.clear()
	MapData.clear()
	Beacon.all.clear()
	DialogueRunner._cache.clear()
	GameState.hooks = {}


func _spawn_npcs() -> void:
	var square := VillageLayout.world(Vector2.ZERO)
	for cfg in NPCS:
		var v := Villager.new()
		add_child(v)
		v.build(cfg)
		var p: Vector2
		var look := square
		if cfg.get("castle", false):
			p = Vector2(castle.throne_seat.x, castle.throne_seat.z)
			look = CastleLayout.THRONE + Vector2(0, 10)
		elif cfg.get("mountain", false):
			p = MountainLayout.OBS + Vector2(1.2, 2.8)
			look = MountainLayout.OBS + Vector2(4.0, 6.0)
		elif cfg.get("swamp", false):
			p = Vector2(swamp.stern().x, swamp.stern().z)
		elif cfg.get("forest", false):
			p = ForestLayout.world(ForestLayout.N["V"] + Vector2(0.5, 2.0))
			look = ForestLayout.world(ForestLayout.N["V"] + Vector2(1.0, 1.0))
		else:
			p = VillageLayout.world(VillageLayout.NPC_SPOTS[cfg.id])
		var pos := Vector3(p.x, Terrain.height_at(p.x, p.y), p.y)
		v.place(pos, atan2(look.x - p.x, look.y - p.y))
		if cfg.get("castle", false):
			v.global_position = castle.throne_seat
			v.talk_radius = 3.0
		if cfg.get("swamp", false):
			ferryman = v
			v.talk_radius = 3.2
		else:
			colliders.append(Vector3(p.x, p.y, 0.45))
		npcs.append(v)


func _spawn_pickups(beacon_pos: Vector3) -> void:
	pickups = Pickups.new()
	pickups.name = "Pickups"
	add_child(pickups)
	var w := func(local: Vector2) -> Vector3:
		var q := VillageLayout.world(local)
		return Vector3(q.x, Terrain.height_at(q.x, q.y), q.y)
	pickups.add("horseshoe", "horseshoe", w.call(Vector2(12.6, -7.6)))
	pickups.add("wool", "wool", w.call(Vector2(-11.2, 5.2)))
	var road := VillageLayout.dirt_road
	var rp := road[0].lerp(road[1], 0.55)
	var side := (road[1] - road[0]).normalized().orthogonal() * 1.6
	pickups.add("spoon", "spoon", Vector3(rp.x + side.x, Terrain.height_at(rp.x + side.x, rp.y + side.y), rp.y + side.y))
	# бусина — в стороне от дороги, на опушке
	var bp := Vector2(beacon_pos.x, beacon_pos.z) + (VillageLayout.CENTER - Vector2(beacon_pos.x, beacon_pos.z)).normalized().rotated(1.2) * 9.0
	pickups.add("bead", "bead", Vector3(bp.x, Terrain.height_at(bp.x, bp.y), bp.y))
	# первоцвет появляется у подножия маяка, когда тот зажжён
	var fp := beacon_pos + (Vector3(VillageLayout.CENTER.x, 0, VillageLayout.CENTER.y) - beacon_pos).normalized() * 2.4
	pickups.add("first_flower", "flower", Vector3(fp.x, Terrain.height_at(fp.x, fp.z), fp.z), "quest:light_beacon=done")
	# лес: грибы-огоньки (по заданию Вейла) и записки
	var i := 0
	for m in ForestLayout.MUSHROOMS:
		var q := ForestLayout.world(m)
		pickups.add("mushroom_%d" % i, "mushroom", Vector3(q.x, Terrain.height_at(q.x, q.y), q.y), "quest:vale_mushrooms=active")
		i += 1
	var pi := 0
	for pg in MountainLayout.PAGES:
		pickups.add("page_%d" % pi, "star_page", _ground3(pg), "quest:ansar_pages=active")
		pi += 1
	for note_id in MountainLayout.NOTES:
		pickups.add("note_" + note_id, "note:" + note_id, _ground3(MountainLayout.NOTES[note_id]))
	pickups.add("rope", "rope", _ground3(SwampLayout.ROPE), "quest:ferry_fix=active")
	pickups.add("resin", "resin", _ground3(SwampLayout.RESIN) + Vector3(0, 0.6, 0), "quest:ferry_fix=active")
	for note_id in CastleLayout.NOTES:
		pickups.add("note_" + note_id, "note:" + note_id, _ground3(CastleLayout.NOTES[note_id]))
	for note_id in SwampLayout.NOTES:
		pickups.add("note_" + note_id, "note:" + note_id, _ground3(SwampLayout.NOTES[note_id]))
	for note_id in ForestLayout.NOTES:
		var q: Vector2 = ForestLayout.world(ForestLayout.NOTES[note_id])
		pickups.add("note_" + note_id, "note:" + note_id, Vector3(q.x, Terrain.height_at(q.x, q.y), q.y))


func _setup_interactables() -> void:
	for v in npcs:
		var npc := v
		interactables.append({node = npc, r = npc.talk_radius, pc = Tr.t("E — поговорить: ") + npc.display_name, touch = Tr.t("Поговорить: ") + npc.display_name,
			act = func(): _talk(npc.id), ok = func(): return true})
	var board := VillageLayout.world(VillageLayout.BOARD)
	interactables.append({pos = Vector3(board.x, 0, board.y), r = 2.0, pc = Tr.t("E — прочитать указ"), touch = Tr.t("Прочитать указ"),
		act = func():
			GameState.apply("note:decree")
			_open_journal("decree"),
		ok = func(): return true})
	for bi in mountains.braziers.size():
		var bz: Dictionary = mountains.braziers[bi]
		var idx: int = bi
		interactables.append({pos = bz.pos, r = 2.8, pc = Tr.t("E — разжечь жаровню"), touch = Tr.t("Разжечь жаровню"),
			act = func(): _light_brazier(idx),
			ok = func(): return not mountains.braziers[idx].lit and GameState.flags.get("has_lantern", false)})
	for k in 2:
		var at_a := k == 0
		var pier := SwampLayout.pier_a() if at_a else SwampLayout.pier_b()
		interactables.append({pos = Vector3(pier.x, 0, pier.y), r = 2.6, pc = Tr.t("E — переправиться"), touch = Tr.t("Переправиться"),
			act = _ferry_start,
			ok = func(): return GameState.flags.get("ferry_fixed", false) and swamp.boat_at_a == at_a and not swamp.ferrying()})
	for bb in beacons:
		var beacon := bb
		interactables.append({node = beacon, r = 3.4, pc = Tr.t("E — зажечь маяк"), touch = Tr.t("Зажечь маяк"),
			act = func(): _light(beacon), ok = func(): return not beacon.lit and GameState.flags.get("has_lantern", false) and (beacon.index < 4 or GameState.flags.get("castle_final_ready", false))})
	for ri in interiors.rooms.size():
		var room: Dictionary = interiors.rooms[ri]
		var idx: int = ri
		interactables.append({pos = room.door_out, r = 1.9, pc = Tr.t("E — войти: ") + room.title, touch = Tr.t("Войти: ") + room.title,
			act = func(): _door_go(idx), ok = func(): return _door_t < 0.0 and not interiors.inside()})
		interactables.append({pos = room.exit_in, r = 1.5, pc = Tr.t("E — выйти"), touch = Tr.t("Выйти"),
			act = func(): _door_go(-1), ok = func(): return _door_t < 0.0 and interiors.current == idx})
	for li in village.lamps.size():
		var lidx: int = li
		interactables.append({pos = village.lamp_pos(li), r = 1.9, pc = Tr.t("E — зажечь фонарь"), touch = Tr.t("Зажечь фонарь"),
			act = func(): _light_lamp(lidx),
			ok = func(): return not village.lamps[lidx].lit and GameState.flags.get("has_lantern", false) and oil.level > 0.05})
	interactables.append({node = deeds.lamb, r = 3.0, pc = Tr.t("E — позвать Звёздочку"), touch = Tr.t("Позвать Звёздочку"),
		act = deeds.call_lamb, ok = func(): return deeds.lamb_active() and not deeds.lamb_following})
	for fr in castle.frescoes:
		var fid: String = fr.id
		interactables.append({pos = fr.pos, r = 2.4, pc = Tr.t("E — рассмотреть фреску"), touch = Tr.t("Рассмотреть фреску"),
			act = func():
				GameState.apply("note:" + fid)
				_open_journal(fid),
			ok = func(): return true})


func _village_sounds() -> void:
	var sq := Vector2.ZERO
	village.add_emitter(Vector2(9.0, -10.0), Synth.cached("rooster_a", func(): return Synth.rooster(22.0, 5), true), 0.55, 9.0)
	village.add_emitter(Vector2(-11.0, 9.0), Synth.cached("rooster_b", func(): return Synth.rooster(29.0, 9), true), 0.45, 9.0)
	village.add_emitter(VillageLayout.PEN_CENTER, Synth.cached("sheep_a", func(): return Synth.sheep(17.0, 3), true), 0.6, 5.0)
	village.add_emitter(sq, Synth.cached("well", func(): return Synth.well(19.0), true), 0.45, 4.0)
	village.add_emitter(Vector2(-1.0, 10.0), Synth.cached("voices_a", func(): return Synth.voices(10.0, 2, 13), true), 0.7, 4.0)
	village.add_emitter(Vector2(4.0, -3.0), Synth.cached("voices_b", func(): return Synth.voices(12.0, 2, 29), true), 0.5, 4.0)


func _respawn_point() -> Vector3:
	if _castle_f > 0.3 and CastleLayout.gate_open:
		var bs := CastleLayout.bridge_start
		return Vector3(bs.x, Terrain.height_at(bs.x, bs.y), bs.y)
	if SaveGame.last_beacon >= 0 and SaveGame.last_beacon < beacons.size():
		var b := beacons[SaveGame.last_beacon]
		var dir := (Vector3(VillageLayout.CENTER.x, 0, VillageLayout.CENTER.y) - b.position)
		dir.y = 0
		var p := b.position + dir.normalized() * 3.0
		return Vector3(p.x, Terrain.height_at(p.x, p.z), p.z)
	return Vector3(START.x, Terrain.height_at(START.x, START.y), START.y)


func _on_start() -> void:
	started = true
	state = State.PLAY
	_leave_menu_vista()
	var want_prologue: bool = not GameState.flags.get("prologue_seen", false) and not GameState.flags.get("has_lantern", false)
	if want_prologue and (not Args.has("autotest") or Args.has("prologuetest")) and not Args.has("bench"):
		_start_prologue()
		return
	if GameState.quest("get_lantern") == "active":
		hud.toast(Tr.t("Старейшина Ольдрих ждёт у своего дома"))


func _start_prologue() -> void:
	state = State.CUTSCENE
	hud.visible = false
	minimap.visible = false
	goal_hud.visible = false
	prologue = Prologue.new()
	add_child(prologue)
	prologue.begin(self, cam, hero.global_position)
	prologue.finished.connect(_end_prologue)


func _end_prologue() -> void:
	GameState.flags["prologue_seen"] = true
	state = State.PLAY
	hud.visible = true
	minimap.visible = not Args.has("nomap")
	goal_hud.visible = true
	_fade = 0.0
	cam.snap(hero.global_position)
	prologue.queue_free()
	prologue = null
	hud.toast(Tr.t("Старейшина Ольдрих ждёт у своего дома"))


func _setup_input() -> void:
	var map := {
		"move_up": [KEY_W, KEY_UP], "move_down": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"raise": [KEY_SPACE], "interact": [KEY_E], "journal": [KEY_J],
	}
	for action in map:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in map[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)


func _unhandled_input(e: InputEvent) -> void:
	if _unhandled_key_ending(e):
		return
	if state == State.MENU:
		return
	if e is InputEventKey and e.pressed and not e.echo:
		if e.physical_keycode == KEY_F:
			fps.toggle()
		elif e.physical_keycode == KEY_ESCAPE and state == State.PLAY and started:
			state = State.PAUSE
			hero.move_target = null
			pause_menu.open()
		elif e.is_action("interact"):
			_interact()
		elif e.is_action("journal"):
			_open_journal()
		elif e.physical_keycode == KEY_M and state == State.PLAY and started:
			minimap.toggle_full()
		elif e.physical_keycode == KEY_V and state == State.PLAY and started:
			Settings.first_person = not Settings.first_person
			Settings.save_settings()
			hud.toast(Tr.t("Вид от первого лица") if Settings.first_person else Tr.t("Вид сверху"))
	if state != State.PLAY:
		return
	if cam.first_person:
		if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			cam.mouse_look(e.relative)
		elif e is InputEventMouseButton and e.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			_mouse_raise = e.pressed
		return
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_RIGHT:
		_mouse_raise = e.pressed
	var pressed := false
	var released := false
	var pos := Vector2.ZERO
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		pressed = e.pressed; released = not e.pressed; pos = e.position
	elif e is InputEventScreenTouch:
		pressed = e.pressed; released = not e.pressed; pos = e.position
	elif e is InputEventScreenDrag or e is InputEventMouseMotion:
		if _pressing and e.position.distance_to(_press_pos) > 20.0 and not _touch_raise:
			_pressing = false
	if pressed:
		_press_pos = pos
		_press_time = Time.get_ticks_msec()
		_pressing = true
	elif released:
		var was_raise := _touch_raise
		_touch_raise = false
		var was_tap := _pressing
		_pressing = false
		if was_raise or not was_tap or not started:
			return
		var hit: Variant = Terrain.raycast(cam.project_ray_origin(pos), cam.project_ray_normal(pos))
		if hero.room.size.x > 0.0:
			hit = Plane(Vector3.UP, hero.room_y).intersects_ray(cam.project_ray_origin(pos), cam.project_ray_normal(pos))
		if hit != null:
			hero.move_target = hit


# ── взаимодействия ──────────────────────────────────────────

func _nearest_interactable() -> Variant:
	var best: Variant = null
	var best_d := INF
	for it in interactables:
		if not it.ok.call():
			continue
		var p: Vector3 = it.node.global_position if it.has("node") else it.pos
		var d := Vector2(p.x - hero.global_position.x, p.z - hero.global_position.z).length()
		if d < it.r and d < best_d:
			best = it
			best_d = d
	return best


func _interact() -> void:
	if state != State.PLAY or not started:
		return
	var it: Variant = _nearest_interactable()
	if it != null:
		it.act.call()


func _talk(id: String) -> void:
	if dialogue.open(id):
		state = State.DIALOGUE
		_talking_to = id
		hero.move_target = null
		hud.show_prompt("", "", false)


func _on_dialogue_closed() -> void:
	_talking_to = ""
	if state == State.ENDING:
		return
	state = State.PLAY


func _open_journal(note := "") -> void:
	if state == State.PLAY and started:
		state = State.JOURNAL
		hero.move_target = null
		journal.open(note)
	elif state == State.JOURNAL:
		journal.close()


func _upgrade_lantern() -> void:
	GameState.flags["lantern_upgraded"] = true
	oil.upgrade()
	lantern.upgrade()
	oil.level = 1.0


## Сохранение в деревне (дом — тоже точка покоя)
func _save_progress() -> void:
	SaveGame.oil = oil.level
	SaveGame.flasks_taken = flasks.taken_indices()
	SaveGame.explored = MapData.to_string_data()
	for ef in _extra_flasks:
		SaveGame.flasks_taken.append_array(ef.taken_indices())
	SaveGame.save()


func _on_flask(_index: int) -> void:
	oil.add(Oil.FLASK_AMOUNT)
	sound.sfx("clink", 0.35, randf_range(0.95, 1.08))


func _light(b: Beacon) -> void:
	state = State.LIGHTING
	_state_t = 0.0
	hero.move_target = null
	hero.face(b.position)
	b.light_up(lantern.light_world_position())
	hud.show_prompt("", "", false)
	GameState.apply("quest:%s=done" % BEACON_QUESTS[b.index])
	# маяк — точка сохранения
	SaveGame.lit.append(b.index)
	SaveGame.last_beacon = b.index
	oil.level = 1.0 # огонь маяка заново наполняет фонарь
	_save_progress()
	hud.toast(Tr.t("Игра сохранена"))
	if b.index == 4:
		_ending_pending = 6.5 # пятый огонь — хорошая концовка


func _start_faint() -> void:
	state = State.FAINT
	_state_t = 0.0
	hero.move_target = null
	sound.sfx("sigh", 0.5)


# ── главный цикл ────────────────────────────────────────────

func _process(dt: float) -> void:
	if hero == null:
		return
	dt = minf(dt, 0.05)
	if state == State.MENU:
		_process_menu(dt)
		return
	if state == State.ENDING:
		_process_ending(dt)
		return
	if state == State.CUTSCENE:
		_process_cutscene(dt)
		return
	if _ending_pending > 0.0:
		_ending_pending -= dt
		if _ending_pending <= 0.0:
			_start_ending(true)
			return
	_state_t += dt
	var playing := started and state == State.PLAY and _door_t < 0.0
	var has_lantern: bool = GameState.flags.get("has_lantern", false)
	var inside := interiors.inside()
	_update_door(dt)
	# волна Пелены: укрытие, сила, тревога
	var shelter := _shelter()
	var veil_ev := veil.tick(dt, started and has_lantern and beacons[0].lit and _castle_f < 0.3 and state in [State.PLAY, State.MAP, State.DIALOGUE, State.JOURNAL, State.FERRY])
	_on_veil_event(veil_ev)
	var life0 := Beacon.restore_at(hero.global_position) if not inside else 1.0
	_exposure = veil.strength * (1.0 - shelter) * (1.0 - 0.6 * life0) * (0.45 if GameState.flags.get("veil_hood", false) else 1.0)
	_veil_vis = lerpf(_veil_vis, 0.0 if inside else veil.strength * (1.0 - 0.5 * life0), 1.0 - exp(-dt * 1.5))

	if _pressing and not _touch_raise and Time.get_ticks_msec() - _press_time > 350:
		_touch_raise = true
	raised = (Input.is_action_pressed("raise") or _mouse_raise or _touch_raise) and playing and has_lantern
	if state == State.LIGHTING and _state_t < 1.6:
		raised = true

	_update_view_mode()
	var axis := Input.get_vector("move_left", "move_right", "move_down", "move_up")
	hero.update_hero(dt, axis, cam, colliders, playing)
	_velocity = (hero.global_position - _last_hero_pos) / maxf(dt, 0.001)
	_last_hero_pos = hero.global_position

	var life := Beacon.restore_at(hero.global_position)
	if playing and has_lantern:
		# в воде топи масло горит быстрее (сырость, брызги)
		var hp0 := hero.global_position
		var wading := SwampLayout.in_swamp(hp0.x, hp0.z) and not SwampLayout.on_boardwalk(hp0.x, hp0.z) and Terrain.height_at(hp0.x, hp0.z) < -0.05
		# холод: масло горит быстрее, чем холоднее
		oil.drain(dt, raised, life > 0.5 or inside, (2.5 if wading else 1.0) * (1.0 + _cold * 2.0) * (1.0 + 2.0 * _exposure))
	lantern.set_carried(has_lantern)
	# холод и Пелена гасят фонарь: свет тусклее и меньше, чем по маслу
	var eff_oil := oil.level * (1.0 - _cold * 0.65) * (1.0 - 0.3 * _exposure)
	if cam.first_person:
		cam.follow_fp(dt, hero.global_position, clampf(hero.speed / Hero.WALK_SPEED, 0.0, 1.0), hero.distance)
		lantern.update_lantern(dt, cam.fp_lantern_pivot(), eff_oil, raised, 0.5)
	else:
		lantern.update_lantern(dt, hero.hand_position(), eff_oil, raised)
		cam.zoom = 1.55 if (state == State.LIGHTING and _state_t < 9.0) else (0.8 if state == State.DIALOGUE else 1.0 + _mtn_f * 0.2)
		if inside:
			cam.zoom = 0.62
		cam.follow(dt, hero.global_position, _velocity)
	RenderingServer.global_shader_parameter_set("hero_pos", hero.global_position)
	RenderingServer.global_shader_parameter_set("lantern_pos", lantern.light_world_position() if has_lantern else Vector3(0, -100, 0))
	Beacon.update_globals()

	# жители
	for v in npcs:
		v.update_npc(dt, hero.global_position, DialogueRunner.has_news(v.id), _talking_to == v.id)

	# Тени
	var light_r := oil.light_radius(raised) * (1.0 - _cold * 0.5) * (1.0 - 0.4 * _exposure) if has_lantern else 0.0
	var out := oil.level < 0.04 or not has_lantern
	if shades.tick(dt, hero.global_position, light_r, raised, out, colliders, playing and not inside):
		_start_faint()
	if castle_shades.tick(dt, hero.global_position, light_r, raised, out, colliders, playing and not inside):
		_start_faint()

	# находки и подсказки
	if playing:
		flasks.update_flasks(dt, hero.global_position)
		for ef in _extra_flasks:
			ef.update_flasks(dt, hero.global_position)
		pickups.update_pickups(dt, hero.global_position)
		if has_lantern and GameState.quest("village_lamps") == "":
			GameState.apply("quest:village_lamps=active")
		# первый шаг в горы
		if _mtn_f > 0.4 and GameState.quest("mountain_beacon") == "":
			GameState.apply("quest:mountain_beacon=active")
			hud.toast(Tr.t("Горы. Ветер здесь холоднее, чем память."))
		# первый шаг в топь
		if _swamp_f > 0.4 and GameState.quest("swamp_beacon") == "":
			GameState.apply("quest:swamp_beacon=active")
			hud.toast(Tr.t("Топь. Здесь даже тишина вязкая."))
		# первый шаг в лес
		if _forest_f > 0.35 and GameState.quest("forest_beacon") == "":
			GameState.apply("quest:forest_beacon=active")
			hud.toast(Tr.t("Шепчущий лес. Здесь тише, чем в тишине."))
		var it: Variant = _nearest_interactable()
		if it != null:
			hud.show_prompt(it.pc, it.touch, true)
		else:
			hud.show_prompt("", "", false)
	else:
		flasks.update_flasks(dt, Vector3(9999, 0, 9999))
		pickups.update_pickups(dt, Vector3(9999, 0, 9999))
	deeds.update(dt, hero.global_position, hero.facing, has_lantern and oil.level > 0.04, playing)
	interiors.update(dt)
	if inside:
		interiors.set_view(cam.first_person)
	_update_guide(dt, inside)
	if state == State.LIGHTING and _state_t > 5.0:
		state = State.PLAY
	if state == State.FAINT:
		_update_faint()
	_update_bog(dt)
	_update_ferry_state()
	_update_cold(dt)

	# звук
	if hero.distance >= _next_step_at:
		_next_step_at = hero.distance + randf_range(0.62, 0.68)
		sound.step("wood" if inside else Terrain.surface_at(hero.global_position.x, hero.global_position.z))
	if not inside:
		_dawn = lerpf(_dawn, life, 1.0 - exp(-dt * 1.2))
	sound.calm = _dawn
	sound.wick = (lerpf(0.25, 1.0, sqrt(oil.level)) * (1.4 if raised else 1.0)) if has_lantern else 0.0
	if inside:
		sound.wick = 1.7 # треск очага
	sound.update_sound(dt)
	var hp := hero.global_position
	var vlife := Beacon.restore_at(hp) if beacons[0].lit else 0.0
	var flife := 0.0
	if beacons[1].lit:
		flife = 1.0 - Terrain.ss(beacons[1].radius - 6.0, beacons[1].radius, Vector2(hp.x - beacons[1].position.x, hp.z - beacons[1].position.z).length())
	var slife := 0.0
	if beacons[2].lit:
		slife = 1.0 - Terrain.ss(beacons[2].radius - 6.0, beacons[2].radius, Vector2(hp.x - beacons[2].position.x, hp.z - beacons[2].position.z).length())
	var mlife := 0.0
	if beacons[3].lit:
		mlife = 1.0 - Terrain.ss(beacons[3].radius - 6.0, beacons[3].radius, Vector2(hp.x - beacons[3].position.x, hp.z - beacons[3].position.z).length())
	# голоса ночи вокруг героя
	ambience.island = 1.0 - maxf(maxf(_forest_f, _swamp_f), maxf(_mtn_f, _castle_f))
	ambience.forest = _forest_f
	ambience.swamp = _swamp_f
	ambience.mountains = _mtn_f
	ambience.castle = _castle_f
	ambience.inside = 1.0 if inside else 0.0
	ambience.alive = life
	var sn := 99.0
	for sh in shades.list_all() + castle_shades.list_all():
		if sh.visible:
			sn = minf(sn, sh.global_position.distance_to(hp))
	ambience.shade_near = sn
	ambience.update(dt, hp, hero.distance, has_lantern, playing)
	_moths.emitting = has_lantern and not inside and _veil_vis < 0.5 and Quality.level != "low"
	region_audio.update_layers(dt, {"village": vlife * (1.0 - _forest_f) * (1.0 - _swamp_f) * (1.0 - _mtn_f), "forest": flife, "swamp": slife, "mountains": mlife})
	_mtn_f = lerpf(_mtn_f, 0.0 if inside else MountainLayout.region_factor(hp.x, hp.z), 1.0 - exp(-dt * 0.8))
	mountains.update_mountains(dt, hp, _mtn_f, mlife)
	RenderingServer.global_shader_parameter_set("wind_strength", 1.0 + _mtn_f * 1.8 * (1.0 - mlife * 0.6) + 2.2 * _veil_vis)
	sound.mountain = 0.0 if inside else maxf(_mtn_f * (1.0 - mlife * 0.7), 0.85 * _veil_vis)
	_rumble.volume_db = linear_to_db(maxf(0.0001, (0.25 if inside else 0.9) * maxf(veil.strength, 0.6 if veil.warning() else 0.0)))
	if _rumble.volume_db > -60.0 and not _rumble.playing:
		_rumble.play()
	elif _rumble.volume_db <= -60.0 and _rumble.playing:
		_rumble.stop()
	grade.set_shader_parameter("frost", _cold)
	_forest_f = lerpf(_forest_f, 0.0 if inside else ForestLayout.region_factor(hp.x, hp.z), 1.0 - exp(-dt * 0.8))
	_swamp_f = lerpf(_swamp_f, 0.0 if inside else SwampLayout.mask(hp.x, hp.z), 1.0 - exp(-dt * 0.8))
	forest.update_forest(dt, hp, beacons[1].lit)
	swamp.update_swamp(dt, hp, beacons[2].lit)

	_update_castle(dt)
	Atmosphere.set_dawn(env, _dawn, _forest_f, _swamp_f, _mtn_f, _castle_f)
	_moon.light_energy = 0.42 * (1.0 - _castle_f)
	_apply_veil_env(inside)
	if not inside:
		_update_map()
	else:
		minimap.set_shown(false)
	grade.set_shader_parameter("dawn", _dawn)
	hud.oil = oil.level
	hud.show_flask = has_lantern and state != State.DIALOGUE

	_fade = minf(1.0, _fade + dt * (0.35 if started else 0.12))
	grade.set_shader_parameter("fade", (_fade if started else minf(_fade, 0.45)) * _faint_mult)
	if started:
		_adapt_resolution(dt)


# ── главное меню: ночной холм, костёр, фонарщик ──────────────

func _setup_menu_vista() -> void:
	# самый высокий холм острова вдали от деревни, маяка и моста
	var best := Vector3.ZERO
	var best_h := -INF
	for i in 400:
		var a := i * 0.31
		var r := 14.0 + (i % 20) * 1.1
		var x := cos(a) * r
		var z := sin(a) * r
		if VillageLayout.in_village(x, z, 6.0) or Vector2(x, z).distance_to(Vector2(beacons[0].position.x, beacons[0].position.z)) < 9.0:
			continue
		if Vector2(x, z).distance_to(CastleLayout.bridge_start) < 6.0 or not Hero.can_stand(x, z):
			continue
		var h := Terrain.height_at(x, z) + Terrain.normal_at(x, z).y * 2.0
		if h > best_h:
			best_h = h
			best = Vector3(x, Terrain.height_at(x, z), z)
	_menu_spot = best
	# костёр: камни, пламя, искры, тёплый свет
	_menu_fire = Node3D.new()
	add_child(_menu_fire)
	_menu_fire.global_position = best + Vector3(1.1, 0, 0.6)
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.32, 0.3, 0.3)
	for k in 8:
		var st := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.13
		sm.height = 0.18
		st.mesh = sm
		st.material_override = stone
		st.position = Vector3(cos(k * TAU / 8.0) * 0.42, 0.04, sin(k * TAU / 8.0) * 0.42)
		_menu_fire.add_child(st)
	var fl := Fx.flames()
	fl.amount = 24
	fl.scale = Vector3.ONE * 0.6
	fl.position.y = 0.12
	fl.emitting = true
	_menu_fire.add_child(fl)
	var em := Fx.embers(14)
	em.position.y = 0.2
	em.emitting = true
	_menu_fire.add_child(em)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.55, 0.25)
	l.light_energy = 2.2
	l.omni_range = 8.0
	l.position.y = 0.7
	l.shadow_enabled = Quality.shadows
	l.light_volumetric_fog_energy = 1.4
	_menu_fire.add_child(l)
	_menu_fire.set_meta("light", l)
	# фонарщик сидит у огня
	hero.global_position = best
	hero.face(_menu_fire.global_position)
	hero.riding = true
	if hero.anim.has_animation("Sit_Floor_Idle"):
		hero.anim.get_animation("Sit_Floor_Idle").loop_mode = Animation.LOOP_LINEAR
		hero.anim.play("Sit_Floor_Idle")


func _process_menu(dt: float) -> void:
	_state_t += dt
	var c := _menu_spot + Vector3(0.5, 0.9, 0.3)
	var a := 0.6 + _state_t * 0.04
	cam.global_position = c + Vector3(cos(a) * 6.5, 2.4 + sin(_state_t * 0.1) * 0.3, sin(a) * 6.5)
	cam.look_at(c + Vector3(0, 0.3, 0), Vector3.UP)
	lantern.set_carried(true)
	lantern.update_lantern(dt, hero.hand_position(), 0.8, false)
	var fl: OmniLight3D = _menu_fire.get_meta("light")
	fl.light_energy = 2.2 * (0.85 + 0.15 * sin(_state_t * 9.0) * sin(_state_t * 5.3))
	RenderingServer.global_shader_parameter_set("hero_pos", hero.global_position + Vector3(0, -50, 0))
	RenderingServer.global_shader_parameter_set("lantern_pos", lantern.light_world_position())
	Beacon.update_globals()
	sound.wick = 1.8 # треск костра
	sound.update_sound(dt)
	region_audio.update_layers(dt, {"village": 0.0})
	_crickets_menu(dt)
	Atmosphere.set_dawn(env, 0.0)
	_fade = minf(1.0, _fade + dt * 0.5)
	grade.set_shader_parameter("fade", _fade)
	minimap.set_shown(false)
	minimap.update_map([Vector4.ZERO, Vector4.ZERO, Vector4.ZERO, Vector4.ZERO, Vector4.ZERO])
	hud.show_flask = false


var _menu_crickets: AudioStreamPlayer


## Сверчки в меню (тихо, ночные)
func _crickets_menu(_dt: float) -> void:
	if _menu_crickets == null:
		_menu_crickets = AudioStreamPlayer.new()
		_menu_crickets.stream = Synth.cached("crickets_a", func(): return Synth.crickets(8.0, 5, 31), true)
		_menu_crickets.volume_db = linear_to_db(0.18)
		add_child(_menu_crickets)
		_menu_crickets.play()


func _leave_menu_vista() -> void:
	if _menu_crickets:
		_menu_crickets.stop()
	if _menu_fire:
		_menu_fire.queue_free()
		_menu_fire = null
	hero.riding = false
	hero.anim.play("Idle")
	hero.global_position = _respawn_point()
	_last_hero_pos = hero.global_position
	cam.snap(hero.global_position)
	_fade = 0.0
	if GameState.quest("get_lantern") == "active":
		hud.toast(Tr.t("Старейшина Ольдрих ждёт у своего дома"))


## Качество: часть применяется сразу, остальное — после перезапуска
func _apply_quality_live() -> void:
	Quality.setup()
	var e := env.environment
	e.ssao_enabled = Quality.ssao
	e.volumetric_fog_enabled = Quality.volumetric_fog
	lantern.light.shadow_enabled = Quality.shadows
	render_scale = 1.0
	get_viewport().scaling_3d_scale = 1.0


# ── финал ───────────────────────────────────────────────────

## Король встаёт и идёт к пятому маяку
func _king_to_beacon() -> void:
	for v in npcs:
		if v.id == "king":
			var p := CastleLayout.BEACON + Vector2(-2.6, -1.2)
			v.place(Vector3(p.x, Terrain.height_at(p.x, p.y), p.y), atan2(CastleLayout.BEACON.x - p.x, CastleLayout.BEACON.y - p.y))
			v.anim.play("Idle")
			v.anim.get_animation("Idle").loop_mode = Animation.LOOP_LINEAR


func _start_ending(good: bool) -> void:
	if state == State.ENDING:
		return
	state = State.ENDING
	hero.move_target = null
	hud.show_prompt("", "", false)
	hud.visible = false
	minimap.visible = false
	dialogue.visible = false
	castle_shades.reset_all()
	shades.reset_all()
	if not good:
		lantern.set_carried(false) # фонарь остался у трона
	ending = Ending.new()
	add_child(ending)
	ending.begin(good, self, cam, env)
	ending.finished.connect(func(): get_tree().reload_current_scene())


func _process_ending(dt: float) -> void:
	ending.update(dt)
	Beacon.update_globals()
	forest.update_forest(dt, hero.global_position, true)
	swamp.update_swamp(dt, hero.global_position, beacons[2].lit)
	mountains.update_mountains(dt, hero.global_position, 0.0, 1.0)
	castle.update_castle(dt, true)
	region_audio.update_layers(dt, ending.life())
	sound.calm = ending.dawn
	sound.mountain = 0.0
	sound.update_sound(dt)
	_drips.volume_db = -80.0
	grade.set_shader_parameter("dawn", ending.dawn if ending.good else 0.12)
	grade.set_shader_parameter("frost", 0.0)
	grade.set_shader_parameter("fade", 1.0)
	_moon.light_energy = 0.42 * (1.0 - ending.dawn)
	RenderingServer.global_shader_parameter_set("wind_strength", 1.0)
	if not ending.good:
		Atmosphere.set_dawn(env, 0.1)


## Вид от первого лица (тест): только в обычной игре; диалоги, маяки, финал — прежней камерой
func _update_view_mode() -> void:
	var fp := Settings.first_person and started and state == State.PLAY and not hero.riding
	if fp != cam.first_person:
		if fp:
			cam.enter_first_person()
		else:
			cam.leave_first_person()
		hero.visible = not fp
		hero.instant_turn = fp
		_mouse_raise = false
	var want_mode := Input.MOUSE_MODE_CAPTURED if fp and get_window().has_focus() else Input.MOUSE_MODE_VISIBLE
	if Input.mouse_mode != want_mode and not Args.has("autotest"):
		Input.mouse_mode = want_mode


func _unhandled_key_ending(e: InputEvent) -> bool:
	if state == State.CUTSCENE and prologue and e is InputEventKey and e.pressed and not e.echo and e.physical_keycode in [KEY_ESCAPE, KEY_SPACE, KEY_ENTER]:
		prologue.skip()
		return true
	if state == State.ENDING and e is InputEventKey and e.pressed and not e.echo and e.physical_keycode in [KEY_ESCAPE, KEY_SPACE, KEY_ENTER]:
		ending.skip()
		return true
	return false


## Новая игра: стереть сохранение и перезапустить сцену
func _restart() -> void:
	SaveGame.reset()
	SaveGame.skip_menu_once = true
	get_tree().reload_current_scene()


func _ground3(p: Vector2) -> Vector3:
	return Vector3(p.x, maxf(Terrain.height_at(p.x, p.y), SwampLayout.deck_height(p.x, p.y) if SwampLayout.on_boardwalk(p.x, p.y) else -99.0), p.y)


## Переправа через протоку на лодке паромщика
func _ferry_start() -> void:
	state = State.FERRY
	_state_t = 0.0
	hero.move_target = null
	hero.riding = true
	hud.show_prompt("", "", false)
	swamp.start_ferry()


func _update_ferry_state() -> void:
	if ferryman:
		var st := swamp.stern()
		ferryman.global_position = st
		if state == State.FERRY:
			ferryman.rotation.y = swamp.boat.rotation.y
	if state != State.FERRY:
		return
	hero.global_position = swamp.seat()
	hero.facing = swamp.boat.rotation.y
	hero.rotation.y = hero.facing
	if not swamp.ferrying():
		hero.riding = false
		hero.global_position = swamp.landing()
		_last_hero_pos = hero.global_position
		state = State.PLAY


## Замок: ворота открываются, когда горят 4 маяка; тьма и тишина внутри
func _update_castle(dt: float) -> void:
	var hp := hero.global_position
	_castle_f = lerpf(_castle_f, CastleLayout.region_factor(hp.x, hp.z), 1.0 - exp(-dt * 0.8))
	var lit := 0
	for i in 4:
		if beacons[i].lit:
			lit += 1
	var open := lit >= 4
	if open and not CastleLayout.gate_open:
		CastleLayout.gate_open = true
		if not _gate_announced and started:
			_gate_announced = true
			hud.toast(Tr.t("Где-то на юге, за мостом, с лязгом поднялась старая решётка."))
			GameState.apply("quest:castle=active")
	castle.update_castle(dt, CastleLayout.gate_open)
	# подсказка у закрытых ворот
	_gate_hint_t -= dt
	if not CastleLayout.gate_open and state == State.PLAY and _gate_hint_t <= 0.0:
		if Vector2(hp.x - CastleLayout.GATE.x, hp.z - CastleLayout.GATE.y).length() < 4.5:
			_gate_hint_t = 12.0
			hud.toast(Tr.t("Решётка не поддаётся — будто её держит сама темнота. Горит маяков: %d из 4.") % lit)
	# капли в пустых залах
	var dv := _castle_f * (1.0 - beacons[4].radius / 60.0)
	if dv > 0.02 and not _drips.playing and started:
		_drips.play()
	_drips.volume_db = linear_to_db(maxf(0.0001, dv * 0.5))


## Разжечь жаровню огнём фонаря (чуть масла)
func _light_brazier(i: int) -> void:
	mountains.light_brazier(i)
	GameState.flags["brazier_%d" % i] = true
	if GameState.quest("warm_road") == "":
		GameState.apply("quest:warm_road=active")
	var lit_n := 0
	for k in mountains.braziers.size():
		if mountains.braziers[k].lit:
			lit_n += 1
	if lit_n >= mountains.braziers.size() and GameState.quest("warm_road") == "active":
		GameState.flags["warm_road"] = true
		GameState.apply("quest:warm_road=done")
	oil.level = maxf(0.0, oil.level - 0.04)
	sound.sfx("ignite", 0.35, 1.3)
	_save_progress()


## Холод в горах: растёт выше и дольше на морозе; у жаровен и в ожившей области — уходит.
## Дойдёт до конца — фонарь гаснет, герой теряет сознание.
func _update_cold(dt: float) -> void:
	if state != State.PLAY or not started:
		if state == State.FAINT:
			_cold = move_toward(_cold, 0.0, dt * 0.3)
		return
	var hp := hero.global_position
	var warm := 1.0 if interiors.inside() else mountains.warmth(hp)
	var life := Beacon.restore_at(hp)
	if warm > 0.3 or life > 0.5:
		_cold = move_toward(_cold, 0.0, dt / 3.0)
	elif _mtn_f > 0.4 and GameState.flags.get("has_lantern", false):
		var altitude := clampf(hp.y / MountainLayout.PEAK, 0.0, 1.0)
		var resist := (0.6 if GameState.flags.get("scarf", false) else 1.0) * (0.75 if GameState.flags.get("warm_road", false) else 1.0)
		_cold = minf(1.0, _cold + dt / 75.0 * (0.6 + altitude * 1.2) * _mtn_f * resist)
	else:
		_cold = move_toward(_cold, 0.0, dt / 12.0)
	if _cold > 0.5 and _cold_warned < 1:
		_cold_warned = 1
		hud.toast(Tr.t("Холод пробирает до костей. Фонарь дрожит — нужна жаровня."))
	elif _cold > 0.82 and _cold_warned < 2:
		_cold_warned = 2
		hud.toast(Tr.t("Пальцы немеют… Огонь вот-вот погаснет."))
	elif _cold < 0.3:
		_cold_warned = 0
	if _cold >= 1.0:
		_start_faint()


## Трясина: затягивает. Медленно идёшь, погружаешься; задержишься — обморок
func _update_bog(dt: float) -> void:
	if state != State.PLAY:
		return
	var hp := hero.global_position
	var bog := SwampLayout.bog_at(hp.x, hp.z) if not SwampLayout.on_boardwalk(hp.x, hp.z) else 0.0
	if bog > 0.5:
		if not _bog_warned:
			_bog_warned = true
			hud.toast(Tr.t("Трясина! Назад, пока не затянуло…"))
		_bog_t += dt
		hero.slow = 0.35
		hero.sink = minf(0.65, _bog_t * 0.14)
		if _bog_t > 5.0:
			_start_faint()
	else:
		_bog_t = maxf(0.0, _bog_t - dt * 2.0)
		hero.slow = 1.0
		hero.sink = move_toward(hero.sink, 0.0, dt * 0.8)
		if _bog_t <= 0.0:
			_bog_warned = false


## Карта: открываем исследованное, ставим метки
# ── этап 6: дома, волны Пелены, цель, добрые дела ─────────────

func _build_interiors() -> void:
	interiors = Interiors.new()
	add_child(interiors)
	var door := func(node: Node3D, extra := 0.9) -> Array:
		var size: Vector3 = node.get_meta("size")
		var yaw := node.rotation.y
		var d := Vector2(sin(yaw), cos(yaw))
		var c := Vector2(node.global_position.x, node.global_position.z)
		var p := c + d * (size.z * 0.5 + extra)
		return [_ground3(p), d]
	for h in village.houses:
		if h.id == "elder_house":
			var dr: Array = door.call(h.node)
			interiors.add_room("elder", Tr.t("дом Ольдриха"), "elder", dr[0], dr[1])
		elif h.m == "House_2":
			var dr: Array = door.call(h.node)
			interiors.add_room("lia", Tr.t("дом Лии"), "lia", dr[0], dr[1])
	if forest.hut_node:
		var dr: Array = door.call(forest.hut_node)
		interiors.add_room("vale", Tr.t("хижина Вейла"), "herbal", dr[0], dr[1])
	if swamp.hut_node:
		var dr: Array = door.call(swamp.hut_node)
		interiors.add_room("korney", Tr.t("хижина Корнея"), "fisher", dr[0], dr[1])
	var od := MountainLayout.OBS + Vector2(-2.6, -2.2 + 2.42 + 0.9)
	interiors.add_room("obs", Tr.t("обсерватория"), "study", _ground3(od), Vector2(0, 1))
	colliders.append_array(interiors.colliders)
	for r in interiors.rooms:
		(r.root as Node3D).visible = false


## Переход через дверь: затемнение → перенос → проявление
func _door_go(to: int) -> void:
	_door_to = to
	_door_t = 0.0
	hero.move_target = null
	sound.sfx("clink", 0.18, 0.6)


func _update_door(dt: float) -> void:
	if _door_t < 0.0:
		return
	var before := _door_t
	_door_t += dt
	if before < 0.35 and _door_t >= 0.35:
		if _door_to >= 0:
			_enter_room(_door_to)
		else:
			_leave_room()
	_faint_mult = (1.0 - Terrain.ss(0.0, 0.35, _door_t)) if _door_t < 0.35 else Terrain.ss(0.35, 0.85, _door_t)
	if _door_t >= 0.85:
		_door_t = -1.0
		_faint_mult = 1.0


func _enter_room(i: int) -> void:
	var r: Dictionary = interiors.rooms[i]
	interiors.current = i
	(r.root as Node3D).visible = true
	hero.room = r.rect
	hero.room_y = (r.center as Vector3).y
	hero.global_position = (r.exit_in as Vector3) + Vector3(0, 0, -0.7)
	hero.facing = PI
	hero.rotation.y = PI
	cam.look_yaw = 0.0
	cam.look_pitch = deg_to_rad(-6.0)
	_last_hero_pos = hero.global_position
	cam.zoom = 0.62
	cam.snap(hero.global_position)
	interiors.set_view(cam.first_person)
	if veil.active() or veil.warning():
		hud.toast(Tr.t("Здесь Пелена не достанет. Переждём у огня."))


func _leave_room() -> void:
	var r: Dictionary = interiors.rooms[interiors.current]
	(r.root as Node3D).visible = false
	interiors.current = -1
	hero.room = Rect2()
	hero.global_position = r.door_out
	hero.facing = r.out_yaw
	hero.rotation.y = r.out_yaw
	cam.look_yaw = float(r.out_yaw) + PI
	_last_hero_pos = hero.global_position
	cam.zoom = 1.0
	cam.snap(hero.global_position)


## 0..1 — насколько герой укрыт от волны: дом, живой огонь рядом, зажжённый маяк
func _shelter() -> float:
	if interiors.inside():
		return 1.0
	var hp := hero.global_position
	var best := 0.0
	for i in village.lamps.size():
		if village.lamps[i].lit:
			var d := Vector2(hp.x, hp.z).distance_to(Vector2(village.lamp_pos(i).x, village.lamp_pos(i).z))
			best = maxf(best, 1.0 - Terrain.ss(2.6, 4.2, d))
	best = maxf(best, clampf(mountains.warmth(hp) * 1.4, 0.0, 1.0))
	for b in beacons:
		if b.lit:
			best = maxf(best, 1.0 - Terrain.ss(7.0, 10.0, Vector2(hp.x - b.position.x, hp.z - b.position.z).length()))
	return best


## Куда бежать от волны: ближайшая дверь, горящий фонарь, жаровня или маяк
func _nearest_shelter() -> Variant:
	var hp := hero.global_position
	var best: Variant = null
	var best_d := 70.0
	var cand: Array = []
	for r in interiors.rooms:
		cand.append(r.door_out)
	for i in village.lamps.size():
		if village.lamps[i].lit:
			cand.append(village.lamp_pos(i))
	for bz in mountains.braziers:
		if bz.lit:
			cand.append(bz.pos)
	for b in beacons:
		if b.lit:
			cand.append(b.position)
	for c in cand:
		var p: Vector3 = c
		var d := Vector2(p.x - hp.x, p.z - hp.z).length()
		if d < best_d:
			best_d = d
			best = p
	return best


func _on_veil_event(ev: String) -> void:
	match ev:
		"warn":
			if veil.waves == 0:
				hud.toast(Tr.t("С гор накатывает волна Пелены! Укройся в доме (E у двери) или у живого огня."))
			else:
				hud.toast(Tr.t("Гул с гор… Пелена надвигается."))
		"wave":
			hud.toast(Tr.t("Пелена накрыла землю. Масло тает, свет сжимается."))
		"calm":
			hud.toast(Tr.t("Пелена отступила."))


## Мошки и пылинки, кружащие у фонаря — видны в его свете
func _make_moths() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 14
	p.lifetime = 3.5
	p.local_coords = true
	p.preprocess = 2.0
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.55
	pm.gravity = Vector3.ZERO
	pm.initial_velocity_min = 0.05
	pm.initial_velocity_max = 0.25
	pm.spread = 180.0
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 2.5
	pm.turbulence_noise_scale = 1.5
	pm.turbulence_influence_min = 0.15
	pm.turbulence_influence_max = 0.35
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.add_point(0.2, Color(1, 1, 1, 1))
	fade.add_point(0.8, Color(1, 1, 1, 1))
	fade.set_color(fade.get_point_count() - 1, Color(1, 1, 1, 0))
	var gt := GradientTexture1D.new()
	gt.gradient = fade
	pm.color_ramp = gt
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.022, 0.022)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(1.0, 0.85, 0.6, 0.8)
	var dot := GradientTexture2D.new()
	dot.fill = GradientTexture2D.FILL_RADIAL
	dot.fill_from = Vector2(0.5, 0.5)
	dot.fill_to = Vector2(1.0, 0.5)
	var dg := Gradient.new()
	dg.set_color(0, Color(1, 1, 1, 1))
	dg.set_color(1, Color(1, 1, 1, 0))
	dot.gradient = dg
	dot.width = 32
	dot.height = 32
	m.albedo_texture = dot
	q.material = m
	p.draw_pass_1 = q
	p.position = Vector3(0, -0.1, 0)
	return p


## Пепел, который несёт волна Пелены (летит вокруг героя)
func _make_ash() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 500 if Quality.level != "low" else 220
	p.lifetime = 4.0
	p.preprocess = 2.0
	p.visibility_aabb = AABB(Vector3(-20, -6, -20), Vector3(40, 16, 40))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(14, 5, 14)
	pm.direction = Vector3(1, -0.2, 0.4)
	pm.spread = 25.0
	pm.initial_velocity_min = 1.5
	pm.initial_velocity_max = 3.5
	pm.gravity = Vector3(0.8, -0.35, 0.3)
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 1.2
	pm.scale_min = 0.5
	pm.scale_max = 1.3
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.07, 0.07)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.62, 0.57, 0.53, 0.6)
	var dot := GradientTexture2D.new()
	dot.fill = GradientTexture2D.FILL_RADIAL
	dot.fill_from = Vector2(0.5, 0.5)
	dot.fill_to = Vector2(1.0, 0.5)
	dot.width = 32
	dot.height = 32
	var dg := Gradient.new()
	dg.set_color(0, Color(1, 1, 1, 1))
	dg.set_color(1, Color(1, 1, 1, 0))
	dot.gradient = dg
	m.albedo_texture = dot
	q.material = m
	p.draw_pass_1 = q
	p.emitting = false
	return p


## Пелена в воздухе: густой пепельный туман; в доме — тёплый полумрак без тумана
func _apply_veil_env(inside: bool) -> void:
	var e := env.environment
	_ash.emitting = _veil_vis > 0.08
	_ash.amount_ratio = clampf(_veil_vis, 0.05, 1.0)
	_ash.global_position = hero.global_position + Vector3(0, 2.0, 0)
	if inside:
		e.ambient_light_color = Color(0.32, 0.22, 0.16)
		e.ambient_light_energy = 0.35
		e.fog_density = 0.0
		e.background_color = Color(0, 0, 0)
		if e.volumetric_fog_enabled:
			e.volumetric_fog_density = 0.0
		_moon.light_energy = 0.0
		grade.set_shader_parameter("dawn", 0.0)
		return
	var v := _veil_vis
	if v < 0.002:
		return
	e.fog_density += 0.035 * v
	e.fog_light_color = e.fog_light_color.lerp(Color(0.2, 0.16, 0.14), v * 0.85)
	e.ambient_light_color = e.ambient_light_color.lerp(Color(0.36, 0.3, 0.28), v * 0.6)
	if e.volumetric_fog_enabled:
		e.volumetric_fog_density += 0.012 * v
		e.volumetric_fog_albedo = e.volumetric_fog_albedo.lerp(Color(0.75, 0.68, 0.62), v)
	_moon.light_energy *= 1.0 - 0.6 * v


## «Что сейчас» и метка цели (пересчёт 4 раза в секунду)
func _update_guide(dt: float, inside: bool) -> void:
	goal_hud.hero_pos = hero.global_position
	goal_hud.shown = started and state in [State.PLAY, State.FERRY] and _door_t < 0.0
	_guide_t -= dt
	if _guide_t > 0.0:
		return
	_guide_t = 0.25
	var g := Guide.goal(self)
	var urgent := false
	if inside:
		var r: Dictionary = interiors.rooms[interiors.current]
		g = {text = (Tr.t("Пелена снаружи. Переждём у огня.") if veil.active() or veil.warning() else Tr.t("Ты в доме: ") + r.title + Tr.t(". E у двери — выйти.")), pos = null}
	elif (veil.warning() or veil.active()) and _shelter() < 0.8:
		urgent = true
		var left := veil.seconds_left()
		var t := Tr.t("Пелена надвигается! Укройся в доме или у огня") if veil.warning() else Tr.t("Пелена! Укройся в доме или у живого огня")
		if left > 0:
			t += " (%d %s)" % [left, Tr.t("с")]
		g = {text = t, pos = _nearest_shelter()}
	elif veil.active():
		g = {text = Tr.t("Ты в укрытии. Пережди волну."), pos = null}
	goal_hud.text = g.text
	goal_hud.target = g.pos
	goal_hud.urgent = urgent


## Фонарщик зажигает фонарь на столбе
func _light_lamp(i: int) -> void:
	village.set_lamp(i, true)
	GameState.flags["lamp_%d" % i] = true
	oil.level = maxf(0.0, oil.level - 0.02)
	sound.sfx("ignite", 0.3, 1.5)
	var n := 0
	for k in village.lamps.size():
		if village.lamps[k].lit:
			n += 1
	if n >= village.lamps.size():
		if GameState.quest("village_lamps") != "done":
			GameState.apply("quest:village_lamps=done")
			oil.add(0.5)
	else:
		hud.toast(Tr.t("Фонарь горит: %d из %d") % [n, village.lamps.size()])


## Письма: когда все три доставлены — задание выполнено
func _check_letters() -> void:
	for id in ["letter_mara_done", "letter_borta_done", "letter_lia_done"]:
		if not GameState.flags.get(id, false):
			return
	GameState.apply("quest:post_letters=done")
	_save_progress()


## Предыстория: мир живёт своей жизнью, камеру ведёт Prologue
func _process_cutscene(dt: float) -> void:
	if prologue:
		prologue.update(dt)
	Beacon.update_globals()
	RenderingServer.global_shader_parameter_set("hero_pos", hero.global_position)
	RenderingServer.global_shader_parameter_set("lantern_pos", Vector3(0, -100, 0))
	lantern.set_carried(false)
	forest.update_forest(dt, hero.global_position, beacons[1].lit)
	swamp.update_swamp(dt, hero.global_position, beacons[2].lit)
	mountains.update_mountains(dt, hero.global_position, 0.0, 0.0)
	sound.wick = 0.0
	sound.mountain = 0.3
	sound.update_sound(dt)
	region_audio.update_layers(dt, {"village": 0.0, "forest": 0.0, "swamp": 0.0, "mountains": 0.0})
	Atmosphere.set_dawn(env, 0.0)
	grade.set_shader_parameter("fade", 1.0)
	grade.set_shader_parameter("dawn", 0.0)
	grade.set_shader_parameter("frost", 0.0)


func _update_map() -> void:
	var hp := Vector2(hero.global_position.x, hero.global_position.z)
	MapData.update(hp)
	var bdata: Array[Vector4] = []
	var marks: Array = []
	for b in beacons:
		var bp := Vector2(b.position.x, b.position.z)
		bdata.append(Vector4(bp.x, bp.y, b.radius, 0))
		if b.lit and b.radius >= b.max_radius - 0.5 and not _revealed_beacons.has(b.index):
			_revealed_beacons[b.index] = true
			MapData.reveal(bp, b.radius) # ожившая область открывается целиком
		if b.lit or MapData.explored(bp):
			marks.append({pos = bp, kind = "beacon_lit" if b.lit else "beacon", r = 0.0})
		else:
			# задание ведёт к маяку, но место ещё не найдено — примерный круг «где-то здесь»
			var q: String = BEACON_QUESTS[b.index]
			if GameState.quest(q) == "active":
				var off: Vector2 = [Vector2(3.0, -2.0), Vector2(-5.0, 4.0), Vector2(-4.0, 3.0), Vector2(5.0, 4.0), Vector2(-6.0, -4.0)][b.index]
				marks.append({pos = bp + off, kind = "target", r = [10.0, 14.0, 12.0, 14.0, 12.0][b.index]})
	while bdata.size() < 5:
		bdata.append(Vector4.ZERO)
	for w in swamp._wisps:
		if w.fade > 0.3 and w.node.visible:
			marks.append({pos = w.pos, kind = "wisp", r = 0.0})
	for v in npcs:
		var vp := Vector2(v.global_position.x, v.global_position.z)
		if DialogueRunner.has_news(v.id) and MapData.explored(vp):
			marks.append({pos = vp, kind = "npc", r = 0.0})
	if goal_hud and goal_hud.target != null:
		var gt: Vector3 = goal_hud.target
		marks.append({pos = Vector2(gt.x, gt.z), kind = "goal", r = 0.0})
	minimap.markers = marks
	minimap.hero = hp
	minimap.facing = hero.facing
	minimap.fwd = Vector2(-sin(cam.view_yaw()), -cos(cam.view_yaw()))
	minimap.set_shown(started and state in [State.PLAY, State.LIGHTING, State.MAP, State.FERRY])
	minimap.update_map(bdata)


## Обморок: экран медленно темнеет, тишина, пробуждение у последнего маяка (или дома)
func _update_faint() -> void:
	var t := _state_t
	if t < 2.6:
		_faint_mult = 1.0 - Terrain.ss(0.0, 2.6, t)
	elif t < 3.8:
		_faint_mult = 0.0
		if hero.global_position.distance_to(_respawn_point()) > 1.0:
			hero.global_position = _respawn_point()
			_last_hero_pos = hero.global_position
			cam.snap(hero.global_position)
			shades.reset_all()
			oil.level = maxf(oil.level, 0.6)
			_bog_t = 0.0
			_cold = 0.0
			_cold_warned = 0
			hero.sink = 0.0
			hero.slow = 1.0
			swamp.reset_boat()
			hero.wake()
	elif t < 6.3:
		_faint_mult = Terrain.ss(3.8, 6.3, t)
	else:
		_faint_mult = 1.0
		state = State.PLAY


## Адаптивное разрешение: если кадр дольше ~18 мс (меньше ~55 fps) — снижаем чёткость;
## если стабильно 60 fps — время от времени пробуем поднять обратно.
func _adapt_resolution(dt: float) -> void:
	if Args.has("fixscale"):
		get_viewport().scaling_3d_scale = float(Args.get_value("fixscale"))
		render_scale = get_viewport().scaling_3d_scale
		return
	_frame_samples.append(get_process_delta_time() * 1000.0)
	if _frame_samples.size() > 40:
		_frame_samples.pop_front()
	_scale_cooldown -= dt
	if _scale_cooldown > 0.0 or _frame_samples.size() < 30:
		return
	var med := _median()
	var next := render_scale
	var cooldown := 1.2
	if med > 18.5:
		next *= 0.88
	elif med < 17.4 and render_scale < 1.0:
		next *= 1.06
		cooldown = 6.0
	# чёткость уже минимальная, а кадров всё равно мало (большой экран) — жертвуем
	# самым дорогим эффектом (затенение углов) и возвращаем чёткость
	if next < Quality.min_render_scale and _degrade_step():
		next = render_scale + 0.12
		cooldown = 2.0
	next = clampf(next, Quality.min_render_scale, 1.0)
	if absf(next - render_scale) > 0.02:
		render_scale = next
		get_viewport().scaling_3d_scale = render_scale
		_frame_samples.clear()
		_scale_cooldown = cooldown


## Большой экран (полноэкранный режим на Retina) — простой апскейл: он на ~3 мс дешевле FSR,
## а на экране с удвоенной плотностью пикселей разница почти не видна.
func _pick_upscaler() -> void:
	var px := get_window().size.x * get_window().size.y
	var big := px > 3_000_000 or Args.get_value("upscale", "") == "bilinear"
	get_viewport().scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR if (big or OS.has_feature("mobile")) else Viewport.SCALING_3D_MODE_FSR


## Отключаем по одному самые дорогие эффекты. false — отключать больше нечего.
func _degrade_step() -> bool:
	var e := env.environment
	if e.ssao_enabled:
		e.ssao_enabled = false # затенение углов
	elif e.volumetric_fog_enabled:
		e.volumetric_fog_enabled = false # объёмный туман
	elif lantern.light.shadow_enabled and RenderingServer.get_frame_setup_time_cpu() >= 0.0 and _shadow_soft:
		_shadow_soft = false
		RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW)
	else:
		return false
	print("качество снижено: ssao=", e.ssao_enabled, " vfog=", e.volumetric_fog_enabled, " soft=", _shadow_soft)
	return true


func _median() -> float:
	if _frame_samples.is_empty():
		return 0.0
	var s := _frame_samples.duplicate()
	s.sort()
	return s[s.size() / 2]


# ── автоматические проверки (для разработки) ─────────────────

func _shot(dir: String, file: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img.get_width() > 1600:
		img.resize(img.get_width() / 2, img.get_height() / 2, Image.INTERPOLATE_BILINEAR)
	img.save_png(dir.path_join(file))


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _goto_local(local: Vector2) -> void:
	var p := VillageLayout.world(local)
	hero.global_position = Vector3(p.x, Terrain.height_at(p.x, p.y), p.y)


## Пройти разговор до конца, выбирая указанные варианты (по очереди)
func _auto_talk(id: String, picks: Array, dir: String, shot_prefix: String) -> void:
	_talk(id)
	var k := 0
	var guard := 0
	while dialogue.is_open() and guard < 40:
		guard += 1
		await _wait(0.9)
		if k == 0:
			await _shot(dir, shot_prefix + ".png")
		k += 1
		if dialogue.runner.is_last_page() and not dialogue.runner.choices.is_empty():
			dialogue._next() # показать текст целиком
			await _wait(0.2)
			if guard == 2 or guard == 3:
				await _shot(dir, shot_prefix + "-choices.png")
			var pick: int = picks.pop_front() if picks.size() > 0 else 0
			dialogue._pick(pick)
		else:
			dialogue._next()
			dialogue._next()


func _stage6(dir: String) -> void:
	Settings.first_person = Args.has("fp")
	await _wait(1.5)
	await _shot(dir, "a0-start-goal.png")
	GameState.flags["has_lantern"] = true
	GameState.apply("quest:get_lantern=done")
	await _wait(1.0)
	# двери снаружи
	for r in interiors.rooms:
		hero.global_position = r.door_out
		hero.facing = r.out_yaw + PI
		cam.zoom = 1.0
		cam.snap(hero.global_position)
		await _wait(1.6)
		await _shot(dir, "b-door-%s.png" % r.id)
	# фонари
	var lp := village.lamp_pos(0)
	hero.global_position = lp + Vector3(1.0, 0, 1.0)
	cam.snap(hero.global_position)
	await _wait(1.0)
	await _shot(dir, "c0-lamp-dark.png")
	_interact()
	await _wait(2.0)
	await _shot(dir, "c1-lamp-lit.png")
	for i in village.lamps.size():
		if not village.lamps[i].lit:
			_light_lamp(i)
	await _wait(2.0)
	hero.global_position = _ground3(VillageLayout.world(Vector2(0, 3)))
	cam.zoom = 1.6
	await _wait(2.0)
	await _shot(dir, "c2-village-lamps.png")
	cam.zoom = 1.0
	print("lamps quest=", GameState.quest("village_lamps"))
	# дома изнутри
	for i in interiors.rooms.size():
		hero.global_position = interiors.rooms[i].door_out
		await _wait(0.3)
		_door_go(i)
		await _wait(1.6)
		await _shot(dir, "d-room-%s.png" % interiors.rooms[i].id)
		Settings.first_person = true
		await _wait(1.0)
		await _shot(dir, "d-room-%s-fp.png" % interiors.rooms[i].id)
		Settings.first_person = Args.has("fp")
		hero.global_position = interiors.rooms[i].exit_in
		await _wait(0.3)
		_door_go(-1)
		await _wait(1.2)
	print("after rooms inside=", interiors.inside(), " room=", hero.room)
	# волна Пелены
	beacons[0].set_lit_instant()
	hero.global_position = _ground3(VillageLayout.world(Vector2(12, 12)))
	cam.snap(hero.global_position)
	veil.force_warn(4.0)
	await _wait(2.0)
	await _shot(dir, "e0-warn.png")
	await _wait(9.0)
	await _shot(dir, "e1-wave-village.png")
	hero.global_position = _ground3(Vector2(18, -14))
	cam.snap(hero.global_position)
	await _wait(5.0)
	var o0 := oil.level
	await _wait(3.0)
	print("wave: strength=%.2f exposure=%.2f oil drop/3s=%.3f" % [veil.strength, _exposure, o0 - oil.level])
	await _shot(dir, "e2-wave-open.png")
	hero.global_position = village.lamp_pos(2) + Vector3(1.2, 0, 0.6)
	await _wait(2.0)
	print("near lamp: shelter=%.2f exposure=%.2f" % [_shelter(), _exposure])
	await _shot(dir, "e3-wave-lamp.png")
	hero.global_position = interiors.rooms[0].door_out
	await _wait(0.3)
	_door_go(0)
	await _wait(2.0)
	await _shot(dir, "e4-wave-inside.png")
	hero.global_position = interiors.rooms[0].exit_in
	_door_go(-1)
	await _wait(1.0)
	# ягнёнок
	GameState.apply("quest:lia_lamb=active")
	var lb := deeds.lamb.global_position
	hero.global_position = _ground3(Vector2(lb.x + 1.5, lb.z + 1.2))
	cam.snap(hero.global_position)
	await _wait(1.5)
	await _shot(dir, "f0-lamb.png")
	var nit: Variant = _nearest_interactable()
	print("nearest=", nit.pc if nit != null else "none", " lamb_dist=", hero.global_position.distance_to(deeds.lamb.global_position), " active=", deeds.lamb_active())
	_interact()
	print("following=", deeds.lamb_following)
	var pen := VillageLayout.world(VillageLayout.PEN_CENTER + Vector2(3.5, 0))
	var from := Vector2(hero.global_position.x, hero.global_position.z)
	var steps := int(from.distance_to(pen) / 0.5)
	for k in steps:
		var q := from.lerp(pen, float(k + 1) / steps)
		hero.global_position = _ground3(q)
		hero.facing = atan2(pen.x - from.x, pen.y - from.y)
		await _wait(0.22)
		if k == steps / 2:
			await _shot(dir, "f1-lamb-follow.png")
		if GameState.flags.get("lamb_home", false):
			break
	await _wait(1.0)
	print("lamb_home=", GameState.flags.get("lamb_home", false))
	await _shot(dir, "f2-lamb-home.png")
	# Лия и письма
	GameState.apply("give:post_bag")
	await _wait(0.5)
	print("letters=", GameState.items)
	await _auto_talk("lia", [], dir, "g0-lia")
	print("lia: quest lamb=", GameState.quest("lia_lamb"), " scarf=", GameState.flags.get("scarf", false), " letter=", GameState.flags.get("letter_lia_done", false))
	await _auto_talk("lia", [], dir, "g1-lia2")
	await _auto_talk("mara", [], dir, "g2-mara")
	print("mara: bread=", GameState.quest("mara_bread"), " letter=", GameState.flags.get("letter_mara_done", false))
	await _auto_talk("borta", [], dir, "g3-borta")
	print("post=", GameState.quest("post_letters"), " items=", GameState.items)
	# лунная трава
	GameState.apply("quest:borta_herbs=active")
	var hs := Deeds.snap(Deeds.HERB_SPOTS[0])
	hero.global_position = _ground3(hs + Vector2(1.5, 1.5))
	cam.snap(hero.global_position)
	await _wait(1.5)
	await _shot(dir, "h0-herb.png")
	print("AUTOTEST DONE fps=", Engine.get_frames_per_second())
	get_tree().quit()


func _menu_look() -> void:
	var dir := Args.get_value("menulook")
	DirAccess.make_dir_recursive_absolute(dir)
	await _wait(5.0)
	await _shot(dir, "menu.png")
	title._settings.open()
	await _wait(1.0)
	await _shot(dir, "settings.png")
	get_tree().quit()


func _autotest(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	Settings.first_person = Args.has("fp") # проверки — с обычной камерой, если не попросили иначе
	await _wait(0.5)
	title.start()
	if Args.has("pinelook"):
		GameState.flags["has_lantern"] = true
		var c := VillageLayout.world(Vector2(-1.5, 4.5))
		print("pine spot ", c)
		var base := _ground3(c)
		var model := Pine.make(1037, load("res://assets/textures/ground/Rock030_color.jpg"))
		for part in model.parts:
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_custom_data = true
			mm.mesh = part.mesh
			mm.instance_count = 1
			mm.set_instance_transform(0, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 8.0), base))
			mm.set_instance_custom_data(0, Color(base.y, 8.0, 0.5, 0.0))
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			add_child(mmi)
		var views := [["fp-near", 1.6, 5.0, true], ["fp-mid", 5.5, 14.0, true], ["tp", 3.0, 0.0, false]]
		for v in views:
			Settings.first_person = v[3]
			hero.global_position = _ground3(c - Vector2(0, v[1]))
			cam.look_yaw = PI
			cam.look_pitch = deg_to_rad(v[2])
			cam.snap(hero.global_position)
			Input.action_press("raise")
			await _wait(2.0)
			await _shot(dir, "pine-%s.png" % v[0])
			Input.action_release("raise")
		get_tree().quit()
		return
	if Args.has("doorlook"):
		Settings.first_person = true
		for r in interiors.rooms:
			hero.global_position = (r.door_out as Vector3) + Vector3(sin(r.out_yaw), 0, cos(r.out_yaw)) * 1.5
			cam.look_yaw = float(r.out_yaw)
			cam.look_pitch = deg_to_rad(-5.0)
			await _wait(1.5)
			await _shot(dir, "door-%s.png" % r.id)
		get_tree().quit()
		return
	if Args.has("wavelook"):
		Settings.first_person = Args.has("fp")
		GameState.flags["has_lantern"] = true
		beacons[0].set_lit_instant()
		var at := Args.get_value("wavelook_at", "forest")
		var spot := ForestLayout.node("E") + Vector2(3, 6) if at == "forest" else SwampLayout.WALK[3]
		hero.global_position = _ground3(spot)
		cam.snap(hero.global_position)
		await _wait(3.0)
		await _shot(dir, "w0-calm.png")
		veil.force_warn(6.0)
		await _wait(4.0)
		await _shot(dir, "w1-warn.png")
		await _wait(10.0)
		var o0 := oil.level
		await _wait(4.0)
		print("wave: strength=%.2f exposure=%.2f vis=%.2f oil drop/4s=%.3f" % [veil.strength, _exposure, _veil_vis, o0 - oil.level])
		await _shot(dir, "w2-wave.png")
		Input.action_press("raise")
		await _wait(1.5)
		await _shot(dir, "w3-wave-raise.png")
		Input.action_release("raise")
		get_tree().quit()
		return
	if Args.has("stage6test"):
		await _stage6(dir)
		return
	if Args.has("prologuetest"):
		for k in 7:
			await _wait(6.5)
			await _shot(dir, "p%d.png" % k)
		await _wait(8.0)
		await _shot(dir, "p-after.png")
		print("state=", state, " seen=", GameState.flags.get("prologue_seen", false))
		get_tree().quit()
		return
	if Args.has("hutlook"):
		await _wait(1.0)
		GameState.flags["has_lantern"] = true
		Settings.first_person = false
		for k in [["hut-top", SwampLayout.HUT + Vector2(0, 2.0), 1.8], ["hut-walk", Vector2(64.0, -8.2), 1.3], ["walk-gap1", SwampLayout.GAPS[0], 0.9], ["walk-gap2", SwampLayout.GAPS[1], 0.9]]:
			hero.global_position = _ground3(k[1] + Vector2(0, 0.0))
			cam.zoom = k[2]
			await _wait(2.5)
			await _shot(dir, "%s.png" % k[0])
		Settings.first_person = true
		for k in [["fp-hut", Vector2(62.0, -7.6), SwampLayout.HOUSE], ["fp-hut2", Vector2(72.5, -12.0), SwampLayout.HOUSE + Vector2(-2, 0)]]:
			hero.global_position = _ground3(k[1])
			var d: Vector2 = k[2] - k[1]
			cam.look_yaw = atan2(-d.x, -d.y)
			cam.look_pitch = deg_to_rad(-12.0)
			await _wait(2.0)
			await _shot(dir, "%s.png" % k[0])
		get_tree().quit()
		return
	if Args.has("fptest"):
		await _wait(1.0)
		GameState.flags["has_lantern"] = true
		Settings.first_person = true
		var vc := VillageLayout.world(Vector2(0, 0))
		var spots := [
			["village", vc + Vector2(0, 6), vc],
			["village-walk", vc + Vector2(-6, 2), vc + Vector2(-12, -6)],
			["forest", ForestLayout.CENTER + Vector2(0, 26), ForestLayout.CENTER],
			["swamp", SwampLayout.WALK[2], SwampLayout.WALK[4]],
			["stairs", MountainLayout.STAIRS[0], MountainLayout.STAIRS[1]],
			["castle", CastleLayout.GATE + Vector2(0, -6), CastleLayout.CENTER],
			["hall", CastleLayout.THRONE + Vector2(0, 9), CastleLayout.THRONE],
		]
		for sp in spots:
			var from: Vector2 = sp[1]
			var to: Vector2 = sp[2]
			hero.global_position = _ground3(from)
			var d := to - from
			cam.look_yaw = atan2(-d.x, -d.y)
			cam.look_pitch = deg_to_rad(-6.0)
			await _wait(2.5)
			await _shot(dir, "fp-%s.png" % sp[0])
			if sp[0] == "village-walk":
				Input.action_press("move_up")
				Input.action_press("raise")
				await _wait(1.6)
				await _shot(dir, "fp-%s-raise.png" % sp[0])
				Input.action_release("move_up")
				Input.action_release("raise")
			if sp[0] == "stairs":
				for i in range(1, 5):
					var pt: Vector2 = MountainLayout.STAIRS[i]
					hero.move_target = Vector3(pt.x, 0, pt.y)
					var dd := pt - Vector2(hero.global_position.x, hero.global_position.z)
					cam.look_yaw = atan2(-dd.x, -dd.y)
					await _wait(dd.length() / 2.0 + 1.0)
					await _shot(dir, "fp-stairs-%d.png" % i)
		print("AUTOTEST DONE fps=", Engine.get_frames_per_second())
		get_tree().quit()
		return
	if Args.has("villagetest"):
		await _wait(1.0)
		cam.zoom = float(Args.get_value("zoom", "1.0"))
		var spots := [Vector2(0, 0), Vector2(-6, -4), Vector2(9, -3), Vector2(-1, 8), Vector2(-12, 2), Vector2(-12, -8)]
		for i in spots.size():
			_goto_local(spots[i])
			await _wait(2.5)
			await _shot(dir, "v%d.png" % i)
		get_tree().quit()
		return
	if Args.has("maptest"):
		await _wait(2.0)
		await _shot(dir, "m0-mini-start.png")
		# прогулка по деревне и к лесу — карта открывается
		for q in [Vector2(-7, 4), Vector2(-7, -6), Vector2(-3, -16), Vector2(-2, -26), Vector2(0, -33)]:
			hero.global_position = Vector3(q.x, Terrain.height_at(q.x, q.y), q.y)
			await _wait(0.6)
		GameState.quests["forest_beacon"] = "active"
		GameState.quests["light_beacon"] = "active"
		await _wait(1.0)
		await _shot(dir, "m1-mini-trail.png")
		minimap.toggle_full()
		await _wait(0.8)
		await _shot(dir, "m2-full.png")
		minimap.toggle_full()
		get_tree().quit()
		return
	if Args.has("kinglook"):
		await _wait(1.5)
		GameState.flags["has_lantern"] = true
		for i in 4:
			beacons[i].set_lit_instant()
		var fr: Dictionary = castle.frescoes[0]
		hero.global_position = Vector3(fr.pos.x + 1.6, Terrain.height_at(fr.pos.x + 1.6, fr.pos.z), fr.pos.z)
		await _wait(1.5)
		print("hero=", hero.global_position, " fresco=", fr.pos, " nearest=", _nearest_interactable(), " count=", interactables.size(), " frescoes=", castle.frescoes.size())
		hero.global_position = Vector3(0, Terrain.height_at(0, 96.5), 96.5)
		castle_shades.reset_all()
		await _wait(2.0)
		await _shot(dir, "king.png")
		var k: Villager = null
		for v in npcs:
			if v.id == "king":
				k = v
		print("king at ", k.global_position, " seat ", castle.throne_seat, " anim ", k.anim.current_animation)
		get_tree().quit()
		return
	if Args.has("finaltest"):
		var good := Args.get_value("finaltest") != "bad"
		await _wait(1.5)
		GameState.flags["has_lantern"] = true
		GameState.flags["knows_truth"] = true
		for i in 4:
			beacons[i].set_lit_instant()
		await _wait(1.0)
		hero.global_position = Vector3(0, Terrain.height_at(0, 96.5), 96.5)
		castle_shades.reset_all()
		await _wait(1.5)
		await _auto_talk("king", [0], dir, "e00-king-first")
		print("king_met=", GameState.flags.get("king_met", false))
		await _auto_talk("king", [1, 0, 0] if good else [0, 1, 1], dir, "e01-king-final")
		print("final flags: ready=", GameState.flags.get("castle_final_ready", false), " bad=", GameState.flags.get("ending_bad", false), " state=", state)
		if good:
			var b5 := beacons[4]
			hero.global_position = b5.position + Vector3(0, 0, 3.0)
			hero.global_position.y = Terrain.height_at(hero.global_position.x, hero.global_position.z)
			await _wait(1.5)
			await _shot(dir, "e02-at-beacon.png")
			print("prompt: ", _nearest_interactable().pc if _nearest_interactable() != null else "none")
			_interact()
			await _wait(4.0)
			await _shot(dir, "e03-fifth-fire.png")
			await _wait(4.0)
		print("ending started: ", state == State.ENDING)
		for k in 9:
			await _wait(6.5)
			await _shot(dir, "e1%d-ending.png" % k)
		await _wait(8.0)
		await _shot(dir, "e20-credits.png")
		print("AUTOTEST DONE fps=", Engine.get_frames_per_second())
		get_tree().quit()
		return
	if Args.has("castletest"):
		await _wait(1.5)
		fps.visible = true
		GameState.flags["has_lantern"] = true
		var bs := CastleLayout.bridge_start
		hero.global_position = Vector3(bs.x, Terrain.height_at(bs.x, bs.y), bs.y)
		await _wait(1.0)
		await _shot(dir, "c00-bridge-start.png")
		hero.move_target = Vector3(CastleLayout.GATE.x, 0, CastleLayout.GATE.y + 4.0)
		await _wait(1.5)
		var hp1 := hero.global_position
		print("debug: state=", state, " target=", hero.move_target, " speed=", hero.speed, " pos=", hp1, " can_next=", Hero.can_stand(hp1.x, hp1.z + 0.3), " on_bridge=", CastleLayout.on_bridge(hp1.x, hp1.z + 0.3), " bt=", CastleLayout.bridge_t(hp1.x, hp1.z + 0.3))
		await _wait(14.5)
		print("closed gate: hero z=%.1f (gate z=%.1f) y=%.2f" % [hero.global_position.z, CastleLayout.GATE.y, hero.global_position.y])
		await _shot(dir, "c01-gate-closed.png")
		for i in 4:
			beacons[i].set_lit_instant()
		await _wait(5.0)
		print("gate open: ", CastleLayout.gate_open)
		await _shot(dir, "c02-gate-open.png")
		hero.move_target = Vector3(CastleLayout.GATE.x, 0, CastleLayout.GATE.y + 6.0)
		await _wait(4.0)
		print("inside: hero z=%.1f" % hero.global_position.z)
		await _shot(dir, "c03-courtyard.png")
		var sh: Shade = castle_shades.list_all()[0]
		sh.appear_at(hero.global_position + Vector3(4.0, 0, 3.0))
		await _wait(3.0)
		await _shot(dir, "c04-shade.png")
		castle_shades.reset_all()
		await _wait(6.5) # если Тень успела коснуться — дождаться пробуждения
		state = State.PLAY
		# фреска
		var fr: Dictionary = castle.frescoes[0]
		hero.move_target = null
		hero.global_position = Vector3(fr.pos.x + 1.6, Terrain.height_at(fr.pos.x + 1.6, fr.pos.z), fr.pos.z)
		castle_shades.reset_all()
		await _wait(2.0)
		await _shot(dir, "c05-fresco.png")
		print("before fresco: state=", state, " started=", started, " near=", _nearest_interactable() != null, " hero=", hero.global_position)
		_interact()
		await _wait(1.0)
		await _shot(dir, "c06-fresco-journal.png")
		journal.close()
		# король
		hero.global_position = Vector3(0, Terrain.height_at(0, 96.5), 96.5)
		castle_shades.reset_all()
		await _wait(2.0)
		await _shot(dir, "c07-king.png")
		await _auto_talk("king", [1], dir, "c08-king-talk")
		cam.zoom = 2.2
		hero.global_position = Vector3(0, Terrain.height_at(0, 112.0), 112.0)
		await _wait(3.0)
		await _shot(dir, "c09-overview.png")
		print("quests: ", GameState.quests, " notes: ", GameState.notes)
		print("AUTOTEST DONE fps=", Engine.get_frames_per_second(), " scale=", render_scale)
		get_tree().quit()
		return
	if Args.has("brazierlook"):
		await _wait(1.5)
		GameState.flags["has_lantern"] = true
		hero.global_position = _ground3(MountainLayout.STAIRS[2])
		await _wait(0.5)
		for k in [0, 1, 2]:
			var bz: Dictionary = mountains.braziers[k]
			# идём по ступеням мимо жаровни: должна стоять сбоку, проход свободен
			var st := MountainLayout.stair_info(bz.pos.x, bz.pos.z)
			print("brazier ", k, " pos=", Vector2(bz.pos.x, bz.pos.z), " dist to stairs axis=%.2f ridge=%.2f" % [st.x, MountainLayout.ridge_dist(bz.pos.x, bz.pos.z)])
		for pt in MountainLayout.STAIRS.slice(3, 6):
			hero.move_target = Vector3(pt.x, 0, pt.y)
			await _wait(hero.global_position.distance_to(Vector3(pt.x, hero.global_position.y, pt.y)) / 2.0 + 1.5)
			print("reached ", pt, " -> ", Vector2(hero.global_position.x, hero.global_position.z))
		var b1: Dictionary = mountains.braziers[1]
		var info := MountainLayout.stair_info(b1.pos.x, b1.pos.z)
		# встать на ступени в ближайшем к жаровне месте
		var best := Vector2.ZERO
		var bd := 999.0
		for kk in 200:
			var c := Vector2(b1.pos.x, b1.pos.z) + Vector2(randf_range(-3, 3), randf_range(-3, 3))
			if MountainLayout.stair_info(c.x, c.y).x < 1.0 and c.distance_to(Vector2(b1.pos.x, b1.pos.z)) < bd:
				bd = c.distance_to(Vector2(b1.pos.x, b1.pos.z))
				best = c
		hero.global_position = _ground3(best)
		hero.move_target = null
		await _wait(2.0)
		print("hero on stairs %.2f m from brazier; prompt: " % bd, _nearest_interactable().pc if _nearest_interactable() != null else "none", " state=", state)
		await _shot(dir, "brazier.png")
		get_tree().quit()
		return
	if Args.has("mtnlook"):
		await _wait(1.5)
		GameState.flags["has_lantern"] = true
		for i in [3, 5]:
			hero.global_position = _ground3(MountainLayout.STAIRS[i])
			await _wait(2.5)
			await _shot(dir, "look-%d.png" % i)
		get_tree().quit()
		return
	if Args.has("mountaintest"):
		await _wait(1.5)
		fps.visible = true
		GameState.flags["has_lantern"] = true
		hero.global_position = _ground3(MountainLayout.STAIRS[0])
		await _wait(1.0)
		# подъём по лестнице пешком
		var k := 0
		for pt in MountainLayout.STAIRS.slice(1):
			hero.move_target = Vector3(pt.x, 0, pt.y)
			await _wait(hero.global_position.distance_to(Vector3(pt.x, hero.global_position.y, pt.y)) / 2.0 + 1.5)
			print("stair ", k, " goal ", pt, " -> ", Vector2(hero.global_position.x, hero.global_position.z), " y=%.1f cold=%.2f" % [hero.global_position.y, _cold])
			if k == 1:
				await _shot(dir, "m00-foot.png")
			if k == 3:
				await _shot(dir, "m01-stairs.png")
			k += 1
		await _shot(dir, "m02-summit.png")
		# сойти со ступеней нельзя
		var before := hero.global_position
		hero.move_target = before + Vector3(0, 0, 8)
		await _wait(2.0)
		print("off-stairs moved: %.2f" % before.distance_to(hero.global_position))
		# холод без жаровен
		_cold = 0.6
		await _wait(1.5)
		await _shot(dir, "m03-cold.png")
		var bz: Dictionary = mountains.braziers[3]
		hero.global_position = bz.pos + Vector3(1.5, 0, 0.5)
		await _wait(1.0)
		_interact()
		await _wait(3.0)
		print("cold near brazier: %.2f" % _cold)
		await _shot(dir, "m04-brazier.png")
		# Ансар
		hero.global_position = _ground3(MountainLayout.OBS + Vector2(2.6, 4.0))
		cam.zoom = 1.3
		await _wait(2.0)
		await _shot(dir, "m05-observatory.png")
		cam.zoom = 1.0
		await _auto_talk("ansar", [0], dir, "m06-ansar")
		for pg in MountainLayout.PAGES + [MountainLayout.NOTES["smoke_map"], MountainLayout.NOTES["palace_reply"]]:
			hero.global_position = _ground3(pg + Vector2(0.4, 0.3))
			await _wait(1.3)
		print("items: ", GameState.items)
		hero.global_position = _ground3(MountainLayout.OBS + Vector2(2.6, 4.0))
		await _wait(1.0)
		await _auto_talk("ansar", [1, 0], dir, "m07-truth")
		# маяк
		var b4 := beacons[3]
		var dir_b := (Vector3(MountainLayout.RIDGE[1].x, 0, MountainLayout.RIDGE[1].y) - b4.position)
		dir_b.y = 0
		hero.global_position = b4.position + dir_b.normalized() * 2.8
		await _wait(1.5)
		await _shot(dir, "m08-beacon.png")
		_interact()
		await _wait(6.0)
		await _shot(dir, "m09-wave.png")
		await _wait(12.0)
		hero.global_position = _ground3(MountainLayout.OBS + Vector2(2.6, 4.0))
		cam.zoom = 1.4
		await _wait(3.0)
		await _shot(dir, "m10-alive.png")
		await _auto_talk("ansar", [], dir, "m11-after")
		print("notes: ", GameState.notes)
		print("quests: ", GameState.quests)
		print("AUTOTEST DONE fps=", Engine.get_frames_per_second(), " scale=", render_scale)
		get_tree().quit()
		return
	if Args.has("shoretest"):
		await _wait(1.5)
		GameState.flags["has_lantern"] = true
		hero.global_position = _ground3(Vector2(28.5, -4.6))
		await _wait(1.0)
		for target in [Vector2(37.0, -4.6), Vector2(45.0, -6.5), Vector2(51.0, -2.5)]:
			hero.move_target = Vector3(target.x, 0, target.y)
			await _wait(5.0)
			print("goal ", target, " -> hero ", Vector2(hero.global_position.x, hero.global_position.z), " y=", hero.global_position.y)
		await _shot(dir, "shore.png")
		get_tree().quit()
		return
	if Args.has("wisplook"):
		await _wait(1.5)
		GameState.flags["has_lantern"] = true
		var bc: Vector2 = SwampLayout.BOGS[1][0]
		var farp := bc + Vector2(-6.0, 6.5)
		hero.global_position = Vector3(farp.x, Terrain.height_at(farp.x, farp.y), farp.y)
		cam.zoom = 1.6
		await _wait(3.0)
		await _shot(dir, "wisp-far.png")
		if Args.has("faronly"):
			get_tree().quit()
			return
		var near := bc + Vector2(0.0, 7.5)
		hero.global_position = Vector3(near.x, Terrain.height_at(near.x, near.y), near.y)
		cam.zoom = 1.3
		await _wait(3.0)
		await _shot(dir, "wisp-near.png")
		for w in swamp._wisps:
			print("wisp pos=", w.node.global_position, " fade=", w.fade, " visible=", w.node.visible, " hidden=", w.hidden)
		get_tree().quit()
		return
	if Args.has("swamptest"):
		await _wait(1.5)
		fps.visible = true
		GameState.flags["has_lantern"] = true
		var g3 := func(p: Vector2) -> Vector3: return _ground3(p)
		hero.global_position = g3.call(SwampLayout.WALK[0])
		await _wait(2.5)
		await _shot(dir, "w00-edge.png")
		print("swamp quest: ", GameState.quest("swamp_beacon"))
		hero.global_position = g3.call(SwampLayout.WALK[2])
		await _wait(2.5)
		await _shot(dir, "w01-boardwalk.png")
		# огни издали — как маяк
		hero.global_position = g3.call(SwampLayout.WALK[3])
		cam.zoom = 1.6
		await _wait(3.0)
		await _shot(dir, "w02-wisps-far.png")
		cam.zoom = 1.0
		# брод: масло тратится быстрее
		var shallow := Vector2.ZERO
		for k in 400:
			var c := SwampLayout.CENTER + Vector2(randf_range(-25, 25), randf_range(-25, 25))
			var h := Terrain.height_at(c.x, c.y)
			if h < -0.3 and h > -0.8 and SwampLayout.bog_at(c.x, c.y) == 0.0 and not SwampLayout.on_boardwalk(c.x, c.y):
				shallow = c
				break
		hero.global_position = g3.call(shallow)
		oil.level = 0.8
		await _wait(4.0)
		print("oil after 4s wading: ", oil.level, " (normal would be ", 0.8 - 4.0 / 240.0, ")")
		await _shot(dir, "w03-wading.png")
		# трясина
		var bogc: Vector2 = SwampLayout.BOGS[0][0]
		hero.global_position = g3.call(bogc + Vector2(6.5, 0))
		await _wait(1.0)
		hero.move_target = Vector3(bogc.x, 0, bogc.y)
		await _wait(3.0)
		await _shot(dir, "w04-bog.png")
		await _wait(4.5)
		print("after bog: state=", state, " (FAINT=", State.FAINT, ")")
		await _wait(5.0)
		# паромщик
		hero.global_position = g3.call(SwampLayout.pier_a())
		await _wait(2.0)
		await _shot(dir, "w05-ferryman.png")
		await _auto_talk("ferryman", [1, 0], dir, "w06-korney")
		# верёвка и смола
		for item_pos in [SwampLayout.ROPE, SwampLayout.RESIN]:
			hero.global_position = g3.call(item_pos + Vector2(0.4, 0.3))
			await _wait(1.6)
		print("items: ", GameState.items)
		hero.global_position = g3.call(SwampLayout.pier_a())
		await _wait(1.0)
		await _auto_talk("ferryman", [0], dir, "w07-fix")
		print("ferry fixed: ", GameState.flags.get("ferry_fixed", false))
		await _wait(0.5)
		_interact()
		await _wait(3.0)
		await _shot(dir, "w08-ferry.png")
		await _wait(5.0)
		print("after ferry: hero=", hero.global_position, " boat_at_a=", swamp.boat_at_a)
		# записка у маяка и маяк
		var bn: Vector2 = SwampLayout.NOTES["boot_drawing"]
		hero.global_position = g3.call(bn + Vector2(0.3, 0.3))
		await _wait(1.5)
		var b3 := beacons[2]
		var dir_b := (Vector3(SwampLayout.pier_b().x, 0, SwampLayout.pier_b().y) - b3.position)
		dir_b.y = 0
		hero.global_position = b3.position + dir_b.normalized() * 2.8
		await _wait(1.5)
		await _shot(dir, "w09-beacon.png")
		_interact()
		await _wait(6.0)
		await _shot(dir, "w10-wave.png")
		await _wait(10.0)
		hero.global_position = g3.call(SwampLayout.pier_b())
		cam.zoom = 1.5
		await _wait(3.0)
		await _shot(dir, "w11-alive.png")
		cam.zoom = 1.0
		_interact()
		await _wait(8.5)
		await _auto_talk("ferryman", [], dir, "w12-korney-after")
		hero.global_position = g3.call(SwampLayout.WALK[3])
		await _wait(3.0)
		await _shot(dir, "w13-boardwalk-alive.png")
		print("notes: ", GameState.notes)
		print("quests: ", GameState.quests)
		print("AUTOTEST DONE fps=", Engine.get_frames_per_second(), " scale=", render_scale)
		get_tree().quit()
		return
	if Args.has("forestlook"):
		await _wait(1.0)
		GameState.flags["has_lantern"] = true
		var k := 0
		for id in ["E", "J1", "J2", "V", "J3", "P"]:
			var q := ForestLayout.node(id) + (Vector2(1.6, 1.0) if id == "V" else Vector2.ZERO)
			hero.global_position = Vector3(q.x, Terrain.height_at(q.x, q.y), q.y)
			await _wait(2.5)
			await _shot(dir, "look%d-%s.png" % [k, id])
			k += 1
		get_tree().quit()
		return
	if Args.has("foresttest"):
		await _wait(1.5)
		fps.visible = true
		GameState.flags["has_lantern"] = true
		var fpos := func(id: String, off := Vector2.ZERO) -> Vector3:
			var q := ForestLayout.node(id) + off
			return Vector3(q.x, Terrain.height_at(q.x, q.y), q.y)
		# тропа от деревни к лесу
		var tr := ForestLayout.trail()
		hero.global_position = Vector3(tr[1].x, Terrain.height_at(tr[1].x, tr[1].y), tr[1].y)
		await _wait(2.5)
		await _shot(dir, "f00-trail.png")
		hero.global_position = fpos.call("E")
		await _wait(3.0)
		await _shot(dir, "f01-entrance.png")
		print("forest quest: ", GameState.quest("forest_beacon"))
		hero.global_position = fpos.call("J1")
		await _wait(3.0)
		await _shot(dir, "f02-junction.png")
		# попытка сойти с тропы
		var before: Vector3 = hero.global_position
		Input.action_press("move_left")
		await _wait(2.5)
		Input.action_release("move_left")
		print("off-path walk moved: ", before.distance_to(hero.global_position), " walkable=", ForestLayout.walkable(hero.global_position.x, hero.global_position.z))
		await _shot(dir, "f03-blocked.png")
		# Вейл
		hero.global_position = fpos.call("V", Vector2(1.6, 1.0))
		await _wait(2.5)
		await _shot(dir, "f04-vale-glade.png")
		await _auto_talk("vale", [0, 0, 1], dir, "f05-vale")
		# грибы
		for k in ForestLayout.MUSHROOMS.size():
			var m: Vector2 = ForestLayout.world(ForestLayout.MUSHROOMS[k])
			hero.global_position = Vector3(m.x + 0.6, Terrain.height_at(m.x, m.y), m.y + 0.6)
			await _wait(1.0)
			if k == 0:
				await _shot(dir, "f06-mushroom.png")
			hero.move_target = Vector3(m.x, 0, m.y)
			await _wait(1.6)
		print("mushrooms: ", GameState.items.get("mushroom", 0))
		hero.global_position = fpos.call("V", Vector2(1.6, 1.0))
		await _wait(1.0)
		await _auto_talk("vale", [1], dir, "f07-vale-brought")
		# записки
		for note_id in ForestLayout.NOTES:
			var q: Vector2 = ForestLayout.world(ForestLayout.NOTES[note_id])
			hero.global_position = Vector3(q.x + 0.5, Terrain.height_at(q.x, q.y), q.y)
			await _wait(1.0)
		print("notes: ", GameState.notes)
		hero.global_position = fpos.call("J3")
		await _wait(3.0)
		await _shot(dir, "f08-deep.png")
		hero.global_position = fpos.call("P", Vector2(1, -1))
		await _wait(3.0)
		await _shot(dir, "f09-near-beacon.png")
		var b2 := beacons[1]
		var dir_b := (Vector3(ForestLayout.node("P").x, 0, ForestLayout.node("P").y) - b2.position)
		dir_b.y = 0
		hero.global_position = b2.position + dir_b.normalized() * 2.8
		await _wait(1.5)
		await _shot(dir, "f10-beacon.png")
		_interact()
		await _wait(5.0)
		await _shot(dir, "f11-wave.png")
		await _wait(9.0)
		await _shot(dir, "f12-alive.png")
		hero.global_position = fpos.call("J3")
		await _wait(3.0)
		await _shot(dir, "f13-alive-path.png")
		hero.global_position = fpos.call("V", Vector2(1.6, 1.0))
		await _wait(1.5)
		await _auto_talk("vale", [], dir, "f14-vale-after")
		print("quests: ", GameState.quests)
		print("AUTOTEST DONE fps=", Engine.get_frames_per_second(), " scale=", render_scale)
		get_tree().quit()
		return
	if Args.has("npctest"):
		await _wait(1.5)
		GameState.flags["has_lantern"] = true
		cam.zoom = 0.55
		for v in npcs:
			var sk: Skeleton3D = v.find_children("*", "Skeleton3D", true, false)[0]
			print(v.id, " head scale=", sk.get_bone_pose_scale(sk.find_bone("head")), " global=", sk.get_bone_global_pose(sk.find_bone("head")).basis.get_scale())
		for id in ["oldrich", "borta", "lia", "mara"]:
			_goto_local(VillageLayout.NPC_SPOTS[id] + Vector2(1.3, 1.1))
			await _wait(2.0)
			await _shot(dir, "npc-%s.png" % id)
			if Args.has("fpnpc"):
				Settings.first_person = true
				var w := VillageLayout.world(VillageLayout.NPC_SPOTS[id])
				hero.global_position = _ground3(w + Vector2(0, 2.2))
				cam.look_yaw = 0.0
				cam.look_pitch = deg_to_rad(-8.0)
				Input.action_press("raise")
				await _wait(1.5)
				await _shot(dir, "npc-%s-fp.png" % id)
				Input.action_release("raise")
				Settings.first_person = false
		get_tree().quit()
		return
	if Args.has("storytest"):
		await _wait(2.5)
		fps.visible = true
		await _shot(dir, "s00-start.png")
		# Ольдрих — фонарь
		_goto_local(VillageLayout.NPC_SPOTS.oldrich + Vector2(1.2, 1.2))
		await _wait(1.5)
		await _shot(dir, "s01-oldrich-near.png")
		await _auto_talk("oldrich", [0, 1], dir, "s02-oldrich")
		await _wait(1.0)
		await _shot(dir, "s03-lantern.png")
		# Лия
		_goto_local(VillageLayout.NPC_SPOTS.lia + Vector2(1.3, 0.8))
		await _wait(1.2)
		await _auto_talk("lia", [1, 1], dir, "s04-lia")
		# Мара — обмен: подбираем подкову
		_goto_local(Vector2(12.6, -7.6))
		await _wait(1.2)
		await _shot(dir, "s05-pickup.png")
		_goto_local(VillageLayout.NPC_SPOTS.mara + Vector2(0.5, -1.4))
		await _wait(1.2)
		await _auto_talk("mara", [0, 0, 1, 3], dir, "s06-mara")
		# Борта
		_goto_local(VillageLayout.NPC_SPOTS.borta + Vector2(-1.2, 0.6))
		await _wait(1.2)
		await _auto_talk("borta", [0], dir, "s07-borta")
		await _auto_talk("borta", [0], dir, "s08-borta-forge")
		print("upgraded: ", GameState.flags.get("lantern_upgraded", false), " items: ", GameState.items, " quests: ", GameState.quests)
		# журнал
		_open_journal()
		await _wait(1.0)
		await _shot(dir, "s09-journal.png")
		journal.close()
		# указ
		_goto_local(VillageLayout.BOARD + Vector2(0.8, 0.8))
		await _wait(1.0)
		_interact()
		await _wait(1.0)
		await _shot(dir, "s10-decree.png")
		journal.close()
		# маяк
		var b := beacons[0]
		var dir_in := (Vector3(VillageLayout.CENTER.x, 0, VillageLayout.CENTER.y) - b.position)
		dir_in.y = 0
		dir_in = dir_in.normalized()
		hero.global_position = b.position + dir_in * 2.8
		await _wait(1.5)
		_interact()
		await _wait(13.0)
		# первоцвет и Лия
		hero.global_position = b.position + dir_in * 2.4
		await _wait(1.0)
		_goto_local(VillageLayout.NPC_SPOTS.lia + Vector2(1.3, 0.8))
		await _wait(2.0)
		await _shot(dir, "s11-village-alive.png")
		await _auto_talk("lia", [0], dir, "s12-lia-flower")
		await _auto_talk("oldrich", [1], dir, "s13-oldrich-after")
		_goto_local(Vector2(0, 3))
		cam.zoom = 1.6
		await _wait(3.0)
		await _shot(dir, "s14-square-alive.png")
		print("notes: ", GameState.notes, " quests: ", GameState.quests)
		print("AUTOTEST DONE fps=", Engine.get_frames_per_second())
		get_tree().quit()
		return
	await _wait(3.0)
	await _shot(dir, "01-start.png")
	print("AUTOTEST DONE fps=", Engine.get_frames_per_second())
	get_tree().quit()


func _bench() -> void:
	title.start()
	if Args.get_value("at", "") == "castle":
		GameState.flags["has_lantern"] = true
		for i in 4:
			beacons[i].set_lit_instant()
		hero.global_position = Vector3(0, Terrain.height_at(0, 112.0), 112.0)
	if Args.get_value("at", "") == "mountain":
		GameState.flags["has_lantern"] = true
		hero.global_position = _ground3(MountainLayout.STAIRS[5])
	if Args.get_value("at", "") == "swamp":
		GameState.flags["has_lantern"] = true
		hero.global_position = _ground3(SwampLayout.WALK[3])
	if Args.get_value("at", "") == "forest":
		GameState.flags["has_lantern"] = true
		var q := ForestLayout.node("J2")
		hero.global_position = Vector3(q.x, Terrain.height_at(q.x, q.y), q.y)
	await _wait(float(Args.get_value("warm", "8")))
	var f0 := Engine.get_frames_drawn()
	var t0 := Time.get_ticks_msec()
	await _wait(4.0)
	var fps_val := (Engine.get_frames_drawn() - f0) * 1000.0 / (Time.get_ticks_msec() - t0)
	print("window px=", get_window().size, " screen=", DisplayServer.screen_get_size(), " scale=", DisplayServer.screen_get_scale())
	print("BENCH fps=%.1f scale=%.2f frame=%.1fms quality=%s" % [fps_val, render_scale, _median(), Quality.level])
	get_tree().quit()
