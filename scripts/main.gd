extends Node3D
## Точка входа: собирает мир, деревню, жителей, героя, свет, звук и интерфейс; главный цикл.
## Состояния: PLAY — игра, LIGHTING — зажигание маяка, FAINT — обморок,
## DIALOGUE — разговор, JOURNAL — журнал открыт.

enum State { PLAY, LIGHTING, FAINT, DIALOGUE, JOURNAL, MAP, FERRY, PAUSE }

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
var title: TitleScreen
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
	Quality.setup()
	Beacon.all.clear()
	GameState.load_data()
	GameState.reset()
	SaveGame.load_game()
	_setup_input()
	if Args.has("bench"):
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0

	title = TitleScreen.new()
	title.build()
	add_child(title)
	title.started.connect(_on_start)
	title.new_game.connect(_restart)
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
	fps.extra = func(): return "%s · %.0f%% разрешения%s · кадр %.1f мс · масло %.0f%%" % [Quality.level, render_scale * 100.0, "" if env == null or env.environment.ssao_enabled else " · эффекты упрощены", _median(), oil.level * 100.0]
	add_child(fps)

	await get_tree().process_frame
	await get_tree().process_frame
	_build_world()
	title.set_ready()
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

	if not Args.has("skip_npcs"):
		_spawn_npcs()
	_spawn_pickups(beacon_pos)
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
	minimap.labels = [{pos = CastleLayout.CENTER + Vector2(0, CastleLayout.RADIUS - 2.0), text = "Руины замка"}, {pos = vcl + Vector2(0, VillageLayout.RADIUS + 4.0), text = "Тихий Брод"}, {pos = ForestLayout.CENTER + Vector2(0, 8), text = "Шепчущий лес"}, {pos = SwampLayout.CENTER + Vector2(0, 18), text = "Топь"}, {pos = MountainLayout.CENTER + Vector2(0, 22), text = "Горная обсерватория"}]

	# действия из диалогов, которые выполняет игра
	GameState.hooks = {
		notify = func(t): hud.toast(t),
		oil = func(v): oil.add(v),
		upgrade_lantern = _upgrade_lantern,
		save = _save_progress,
	}

	# загрузка сохранения
	for i in SaveGame.lit:
		if int(i) < beacons.size():
			beacons[int(i)].set_lit_instant()
	oil.level = SaveGame.oil
	for bi in mountains.braziers.size():
		if GameState.flags.get("brazier_%d" % bi, false):
			mountains.light_brazier(bi)
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
	for note_id in SwampLayout.NOTES:
		pickups.add("note_" + note_id, "note:" + note_id, _ground3(SwampLayout.NOTES[note_id]))
	for note_id in ForestLayout.NOTES:
		var q: Vector2 = ForestLayout.world(ForestLayout.NOTES[note_id])
		pickups.add("note_" + note_id, "note:" + note_id, Vector3(q.x, Terrain.height_at(q.x, q.y), q.y))


func _setup_interactables() -> void:
	for v in npcs:
		var npc := v
		interactables.append({node = npc, r = npc.talk_radius, pc = "E — поговорить: " + npc.display_name, touch = "Поговорить: " + npc.display_name,
			act = func(): _talk(npc.id), ok = func(): return true})
	var board := VillageLayout.world(VillageLayout.BOARD)
	interactables.append({pos = Vector3(board.x, 0, board.y), r = 2.0, pc = "E — прочитать указ", touch = "Прочитать указ",
		act = func():
			GameState.apply("note:decree")
			_open_journal("decree"),
		ok = func(): return true})
	for bi in mountains.braziers.size():
		var bz: Dictionary = mountains.braziers[bi]
		var idx: int = bi
		interactables.append({pos = bz.pos, r = 2.8, pc = "E — разжечь жаровню", touch = "Разжечь жаровню",
			act = func(): _light_brazier(idx),
			ok = func(): return not mountains.braziers[idx].lit and GameState.flags.get("has_lantern", false)})
	for k in 2:
		var at_a := k == 0
		var pier := SwampLayout.pier_a() if at_a else SwampLayout.pier_b()
		interactables.append({pos = Vector3(pier.x, 0, pier.y), r = 2.6, pc = "E — переправиться", touch = "Переправиться",
			act = _ferry_start,
			ok = func(): return GameState.flags.get("ferry_fixed", false) and swamp.boat_at_a == at_a and not swamp.ferrying()})
	for bb in beacons:
		var beacon := bb
		interactables.append({node = beacon, r = 3.4, pc = "E — зажечь маяк", touch = "Зажечь маяк",
			act = func(): _light(beacon), ok = func(): return not beacon.lit and GameState.flags.get("has_lantern", false) and (beacon.index < 4 or GameState.flags.get("castle_final_ready", false))})
	for fr in castle.frescoes:
		var fid: String = fr.id
		interactables.append({pos = fr.pos, r = 2.4, pc = "E — рассмотреть фреску", touch = "Рассмотреть фреску",
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
	sound.start()
	if GameState.quest("get_lantern") == "active":
		hud.toast("Старейшина Ольдрих ждёт у своего дома")


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
	if state != State.PLAY:
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
	state = State.PLAY
	_talking_to = ""


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
	_state_t += dt
	var playing := started and state == State.PLAY
	var has_lantern: bool = GameState.flags.get("has_lantern", false)

	if _pressing and not _touch_raise and Time.get_ticks_msec() - _press_time > 350:
		_touch_raise = true
	raised = (Input.is_action_pressed("raise") or _mouse_raise or _touch_raise) and playing and has_lantern
	if state == State.LIGHTING and _state_t < 1.6:
		raised = true

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
		oil.drain(dt, raised, life > 0.5, (2.5 if wading else 1.0) * (1.0 + _cold * 2.0))
	lantern.set_carried(has_lantern)
	# холод гасит фонарь: свет тусклее и меньше, чем по маслу
	var eff_oil := oil.level * (1.0 - _cold * 0.65)
	lantern.update_lantern(dt, hero.hand_position(), eff_oil, raised)
	cam.zoom = 1.55 if (state == State.LIGHTING and _state_t < 9.0) else (0.8 if state == State.DIALOGUE else 1.0 + _mtn_f * 0.2)
	cam.follow(dt, hero.global_position, _velocity)
	RenderingServer.global_shader_parameter_set("hero_pos", hero.global_position)
	RenderingServer.global_shader_parameter_set("lantern_pos", lantern.light_world_position() if has_lantern else Vector3(0, -100, 0))
	Beacon.update_globals()

	# жители
	for v in npcs:
		v.update_npc(dt, hero.global_position, DialogueRunner.has_news(v.id), _talking_to == v.id)

	# Тени
	var light_r := oil.light_radius(raised) * (1.0 - _cold * 0.5) if has_lantern else 0.0
	var out := oil.level < 0.04 or not has_lantern
	if shades.tick(dt, hero.global_position, light_r, raised, out, colliders, playing):
		_start_faint()
	if castle_shades.tick(dt, hero.global_position, light_r, raised, out, colliders, playing):
		_start_faint()

	# находки и подсказки
	if playing:
		flasks.update_flasks(dt, hero.global_position)
		for ef in _extra_flasks:
			ef.update_flasks(dt, hero.global_position)
		pickups.update_pickups(dt, hero.global_position)
		# первый шаг в горы
		if _mtn_f > 0.4 and GameState.quest("mountain_beacon") == "":
			GameState.apply("quest:mountain_beacon=active")
			hud.toast("Горы. Ветер здесь холоднее, чем память.")
		# первый шаг в топь
		if _swamp_f > 0.4 and GameState.quest("swamp_beacon") == "":
			GameState.apply("quest:swamp_beacon=active")
			hud.toast("Топь. Здесь даже тишина вязкая.")
		# первый шаг в лес
		if _forest_f > 0.35 and GameState.quest("forest_beacon") == "":
			GameState.apply("quest:forest_beacon=active")
			hud.toast("Шепчущий лес. Здесь тише, чем в тишине.")
		var it: Variant = _nearest_interactable()
		if it != null:
			hud.show_prompt(it.pc, it.touch, true)
		else:
			hud.show_prompt("", "", false)
	else:
		flasks.update_flasks(dt, Vector3(9999, 0, 9999))
		pickups.update_pickups(dt, Vector3(9999, 0, 9999))
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
		sound.step(Terrain.surface_at(hero.global_position.x, hero.global_position.z))
	_dawn = lerpf(_dawn, life, 1.0 - exp(-dt * 1.2))
	sound.calm = _dawn
	sound.wick = (lerpf(0.25, 1.0, sqrt(oil.level)) * (1.4 if raised else 1.0)) if has_lantern else 0.0
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
	region_audio.update_layers(dt, {"village": vlife * (1.0 - _forest_f) * (1.0 - _swamp_f) * (1.0 - _mtn_f), "forest": flife, "swamp": slife, "mountains": mlife})
	_mtn_f = lerpf(_mtn_f, MountainLayout.region_factor(hp.x, hp.z), 1.0 - exp(-dt * 0.8))
	mountains.update_mountains(dt, hp, _mtn_f, mlife)
	RenderingServer.global_shader_parameter_set("wind_strength", 1.0 + _mtn_f * 1.8 * (1.0 - mlife * 0.6))
	sound.mountain = _mtn_f * (1.0 - mlife * 0.7)
	grade.set_shader_parameter("frost", _cold)
	_forest_f = lerpf(_forest_f, ForestLayout.region_factor(hp.x, hp.z), 1.0 - exp(-dt * 0.8))
	_swamp_f = lerpf(_swamp_f, SwampLayout.mask(hp.x, hp.z), 1.0 - exp(-dt * 0.8))
	forest.update_forest(dt, hp, beacons[1].lit)
	swamp.update_swamp(dt, hp, beacons[2].lit)

	_update_castle(dt)
	Atmosphere.set_dawn(env, _dawn, _forest_f, _swamp_f, _mtn_f, _castle_f)
	_moon.light_energy = 0.42 * (1.0 - _castle_f)
	_update_map()
	grade.set_shader_parameter("dawn", _dawn)
	hud.oil = oil.level
	hud.show_flask = has_lantern and state != State.DIALOGUE

	_fade = minf(1.0, _fade + dt * (0.35 if started else 0.12))
	grade.set_shader_parameter("fade", (_fade if started else minf(_fade, 0.45)) * _faint_mult)
	if started:
		_adapt_resolution(dt)


## Новая игра: стереть сохранение и перезапустить сцену
func _restart() -> void:
	SaveGame.reset()
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
			hud.toast("Где-то на юге, за мостом, с лязгом поднялась старая решётка.")
			GameState.apply("quest:castle=active")
	castle.update_castle(dt, CastleLayout.gate_open)
	# подсказка у закрытых ворот
	_gate_hint_t -= dt
	if not CastleLayout.gate_open and state == State.PLAY and _gate_hint_t <= 0.0:
		if Vector2(hp.x - CastleLayout.GATE.x, hp.z - CastleLayout.GATE.y).length() < 4.5:
			_gate_hint_t = 12.0
			hud.toast("Решётка не поддаётся — будто её держит сама темнота. Горит маяков: %d из 4." % lit)
	# капли в пустых залах
	var dv := _castle_f * (1.0 - beacons[4].radius / 60.0)
	if dv > 0.02 and not _drips.playing and started:
		_drips.play()
	_drips.volume_db = linear_to_db(maxf(0.0001, dv * 0.5))


## Разжечь жаровню огнём фонаря (чуть масла)
func _light_brazier(i: int) -> void:
	mountains.light_brazier(i)
	GameState.flags["brazier_%d" % i] = true
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
	var warm := mountains.warmth(hp)
	var life := Beacon.restore_at(hp)
	if warm > 0.3 or life > 0.5:
		_cold = move_toward(_cold, 0.0, dt / 3.0)
	elif _mtn_f > 0.4 and GameState.flags.get("has_lantern", false):
		var altitude := clampf(hp.y / MountainLayout.PEAK, 0.0, 1.0)
		_cold = minf(1.0, _cold + dt / 75.0 * (0.6 + altitude * 1.2) * _mtn_f)
	else:
		_cold = move_toward(_cold, 0.0, dt / 12.0)
	if _cold > 0.5 and _cold_warned < 1:
		_cold_warned = 1
		hud.toast("Холод пробирает до костей. Фонарь дрожит — нужна жаровня.")
	elif _cold > 0.82 and _cold_warned < 2:
		_cold_warned = 2
		hud.toast("Пальцы немеют… Огонь вот-вот погаснет.")
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
			hud.toast("Трясина! Назад, пока не затянуло…")
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
	minimap.markers = marks
	minimap.hero = hp
	minimap.facing = hero.facing
	minimap.fwd = Vector2(-sin(cam.yaw), -cos(cam.yaw))
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


func _autotest(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	await _wait(0.5)
	title.start()
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
		for id in ["oldrich", "borta", "lia", "mara"]:
			_goto_local(VillageLayout.NPC_SPOTS[id] + Vector2(1.3, 1.1))
			await _wait(2.0)
			await _shot(dir, "npc-%s.png" % id)
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
