extends Node3D
## Точка входа: собирает мир, героя, свет, звук и интерфейс; главный цикл.
## Состояния: PLAY — обычная игра, LIGHTING — зажигание маяка, FAINT — обморок.

enum State { PLAY, LIGHTING, FAINT }

const START := Vector2(0, 4)

var terrain: MeshInstance3D
var vegetation: Vegetation
var hero: Hero
var lantern: Lantern
var cam: CameraRig
var sound: Soundscape
var region_audio: RegionAudio
var title: TitleScreen
var fps: FpsMeter
var hud: Hud
var grade: ShaderMaterial
var env: WorldEnvironment
var beacons: Array[Beacon] = []
var flasks: OilFlasks
var shades: Shades
var oil := Oil.new()
var colliders: Array[Vector3] = []

var started := false
var state := State.PLAY
var _state_t := 0.0
var _lighting_beacon: Beacon
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
var raised := false
# адаптивное разрешение
var render_scale := 1.0
var _frame_samples: Array[float] = []
var _scale_cooldown := 3.0


func _ready() -> void:
	Quality.setup()
	Beacon.all.clear() # после перезапуска сцены — без старых маяков
	SaveGame.load_game()
	_setup_input()
	if Args.has("bench"):
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0

	title = TitleScreen.new()
	title.build()
	add_child(title)
	title.started.connect(_on_start)
	title.new_game.connect(func():
		SaveGame.reset()
		get_tree().reload_current_scene())
	grade = Atmosphere.grade_layer(self)
	grade.set_shader_parameter("fade", 0.0)
	fps = FpsMeter.new()
	fps.build()
	fps.extra = func(): return "%s · %.0f%% разрешения · кадр %.1f мс · масло %.0f%%" % [Quality.level, render_scale * 100.0, _median(), oil.level * 100.0]
	add_child(fps)

	await get_tree().process_frame
	await get_tree().process_frame
	_build_world()
	title.set_ready()
	if Args.has("autotest"):
		_autotest(Args.get_value("autotest", "user://shots"))
	elif Args.has("bench"):
		_bench()


func _build_world() -> void:
	env = Atmosphere.environment()
	add_child(env)
	add_child(Atmosphere.moon())

	terrain = Terrain.build()
	add_child(terrain)
	var water := Water.new()
	water.build()
	add_child(water)

	# маяк — на вершине холма в 16–30 м от старта; вокруг него ничего не растёт
	var start3 := Vector3(START.x, Terrain.height_at(START.x, START.y), START.y)
	var beacon_pos := Beacon.find_hilltop(start3, 16.0, 30.0)
	vegetation = Vegetation.new()
	vegetation.name = "Vegetation"
	vegetation.exclusions.append(Vector3(beacon_pos.x, beacon_pos.z, 6.0))

	var grass := Grass.new()
	grass.name = "Grass"
	grass.build(Quality.grass_per_m2)
	add_child(grass)
	vegetation.build(Quality.shadows)
	add_child(vegetation)
	colliders = vegetation.colliders

	var rock_tex: Texture2D = load("res://assets/textures/ground/Rock030_color.jpg")
	var b := Beacon.new()
	add_child(b)
	b.build(0, beacon_pos, rock_tex)
	colliders.append(b.collider)
	b.set_flowers(vegetation.build_bloom(beacon_pos, Beacon.MAX_RADIUS, 520))
	beacons.append(b)

	flasks = OilFlasks.new()
	flasks.build(12, colliders, [Vector3(beacon_pos.x, beacon_pos.z, 5.0)], SaveGame.flasks_taken)
	add_child(flasks)
	flasks.picked.connect(_on_flask)

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

	shades = Shades.new()
	add_child(shades)
	shades.build(6 if Quality.level != "low" else 4)
	shades.sound = sound

	hud = Hud.new()
	hud.build()
	add_child(hud)
	hud.action_pressed.connect(_try_light)

	# загрузка сохранения
	for i in SaveGame.lit:
		if int(i) < beacons.size():
			beacons[int(i)].set_lit_instant()
	oil.level = SaveGame.oil
	hero.global_position = _respawn_point()
	_last_hero_pos = hero.global_position
	cam.snap(hero.global_position)

	var vp := get_viewport()
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if not OS.has_feature("mobile") else Viewport.SCALING_3D_MODE_BILINEAR


func _respawn_point() -> Vector3:
	if SaveGame.last_beacon >= 0 and SaveGame.last_beacon < beacons.size():
		var b := beacons[SaveGame.last_beacon]
		# у подножия маяка, со стороны центра острова
		var dir := Vector3(-b.position.x, 0, -b.position.z).normalized()
		var p := b.position + dir * 3.0
		return Vector3(p.x, Terrain.height_at(p.x, p.z), p.z)
	return Vector3(START.x, Terrain.height_at(START.x, START.y), START.y)


func _on_start() -> void:
	started = true
	sound.start()


func _setup_input() -> void:
	var map := {
		"move_up": [KEY_W, KEY_UP], "move_down": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"raise": [KEY_SPACE], "interact": [KEY_E],
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
		elif e.physical_keycode == KEY_ESCAPE and not OS.has_feature("mobile"):
			get_tree().quit()
		elif e.is_action("interact"):
			_try_light()
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_RIGHT:
		_mouse_raise = e.pressed # правая кнопка мыши — тоже поднять фонарь
	# тап / клик — идти; долгое нажатие на месте — поднять фонарь
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
		if was_raise or not was_tap or not started or state != State.PLAY:
			return
		var hit: Variant = Terrain.raycast(cam.project_ray_origin(pos), cam.project_ray_normal(pos))
		if hit != null:
			hero.move_target = hit


func _on_flask(_index: int) -> void:
	oil.add(Oil.FLASK_AMOUNT)
	sound.sfx("clink", 0.35, randf_range(0.95, 1.08))


func _nearest_unlit() -> Beacon:
	for b in beacons:
		if not b.lit and b.near(hero.global_position):
			return b
	return null


func _try_light() -> void:
	if state != State.PLAY or not started:
		return
	var b := _nearest_unlit()
	if b == null:
		return
	state = State.LIGHTING
	_state_t = 0.0
	_lighting_beacon = b
	hero.move_target = null
	hero.face(b.position)
	b.light_up(lantern.light_world_position())
	hud.show_prompt("", "", false)
	# маяк — точка сохранения
	SaveGame.lit.append(b.index)
	SaveGame.last_beacon = b.index
	oil.level = 1.0 # огонь маяка заново наполняет фонарь
	SaveGame.oil = oil.level
	SaveGame.flasks_taken = flasks.taken_indices()
	SaveGame.save()


func _start_faint() -> void:
	state = State.FAINT
	_state_t = 0.0
	hero.move_target = null
	sound.sfx("sigh", 0.5)


func _process(dt: float) -> void:
	if hero == null:
		return
	dt = minf(dt, 0.05)
	_state_t += dt
	var playing := started and state == State.PLAY

	# поднять фонарь: пробел, правая кнопка мыши или долгое нажатие на экран
	if _pressing and not _touch_raise and Time.get_ticks_msec() - _press_time > 350:
		_touch_raise = true
	raised = (Input.is_action_pressed("raise") or _mouse_raise or _touch_raise) and playing
	if state == State.LIGHTING and _state_t < 1.6:
		raised = true

	var axis := Input.get_vector("move_left", "move_right", "move_down", "move_up")
	hero.update_hero(dt, axis, cam, colliders, playing)
	_velocity = (hero.global_position - _last_hero_pos) / maxf(dt, 0.001)
	_last_hero_pos = hero.global_position

	var life := Beacon.restore_at(hero.global_position)
	if playing:
		oil.drain(dt, raised, life > 0.5)
	lantern.update_lantern(dt, hero.hand_position(), oil.level, raised)
	cam.zoom = 1.55 if (state == State.LIGHTING and _state_t < 9.0) else 1.0
	cam.follow(dt, hero.global_position, _velocity)
	RenderingServer.global_shader_parameter_set("hero_pos", hero.global_position)
	RenderingServer.global_shader_parameter_set("lantern_pos", lantern.light_world_position())
	Beacon.update_globals()

	# Тени
	var light_r := oil.light_radius(raised)
	var out := oil.level < 0.04
	if shades.tick(dt, hero.global_position, light_r, raised, out, colliders, playing):
		_start_faint()

	# флаконы и маяк
	if playing:
		flasks.update_flasks(dt, hero.global_position)
		var nb := _nearest_unlit()
		hud.show_prompt("E — зажечь маяк", "Зажечь маяк", nb != null)
	else:
		flasks.update_flasks(dt, Vector3(9999, 0, 9999))
	if state == State.LIGHTING and _state_t > 5.0:
		state = State.PLAY
	if state == State.FAINT:
		_update_faint()

	# звук: шаги, ветер, фитиль, голоса ожившей земли
	if hero.distance >= _next_step_at:
		_next_step_at = hero.distance + randf_range(0.62, 0.68)
		sound.step(Terrain.surface_at(hero.global_position.x, hero.global_position.z))
	_dawn = lerpf(_dawn, life, 1.0 - exp(-dt * 1.2))
	sound.calm = _dawn
	sound.wick = lerpf(0.25, 1.0, sqrt(oil.level)) * (1.4 if raised else 1.0)
	sound.update_sound(dt)
	region_audio.update_layers(dt, {"island": life if beacons[0].lit else 0.0})

	Atmosphere.set_dawn(env, _dawn)
	grade.set_shader_parameter("dawn", _dawn)
	hud.oil = oil.level

	_fade = minf(1.0, _fade + dt * (0.35 if started else 0.12))
	grade.set_shader_parameter("fade", (_fade if started else minf(_fade, 0.45)) * _faint_mult)
	if started:
		_adapt_resolution(dt)


## Обморок: экран медленно темнеет, тишина, пробуждение у последнего маяка
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
			hero.wake()
	elif t < 6.3:
		_faint_mult = Terrain.ss(3.8, 6.3, t)
	else:
		_faint_mult = 1.0
		state = State.PLAY


## Адаптивное разрешение: если кадр дольше ~18 мс (меньше ~55 fps) — снижаем чёткость;
## если стабильно 60 fps — время от времени пробуем поднять обратно.
func _adapt_resolution(dt: float) -> void:
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
	next = clampf(next, Quality.min_render_scale, 1.0)
	if absf(next - render_scale) > 0.02:
		render_scale = next
		get_viewport().scaling_3d_scale = render_scale
		_frame_samples.clear()
		_scale_cooldown = cooldown


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


func _autotest(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	await _wait(0.5)
	title.start()
	if Args.has("shadetest"):
		await _wait(2.0)
		var sh: Shade = shades.list_all()[0]
		sh.appear_at(hero.global_position + Vector3(4.5, 0, 1.5))
		await _wait(4.0)
		await _shot(dir, "shade-1.png")
		print("shade dist ", sh.global_position.distance_to(hero.global_position), " state ", sh.state)
		Input.action_press("raise")
		await _wait(0.8)
		await _shot(dir, "shade-2.png")
		await _wait(1.5)
		await _shot(dir, "shade-3.png")
		Input.action_release("raise")
		print("shade state after raise ", sh.state)
		get_tree().quit()
		return
	await _wait(3.0)
	fps.visible = true
	var b := beacons[0]
	print("beacon at ", b.position, " flasks taken ", flasks.taken_indices())
	await _shot(dir, "01-start.png")

	# флакон: ставим героя рядом с ближайшим
	oil.level = 0.5
	var fl: Node3D = null
	for c in flasks.get_children():
		if c is Node3D and c.visible and c.get_child_count() > 3:
			fl = c
			break
	if fl:
		hero.global_position = fl.global_position + Vector3(2.5, 0, 0)
		await _wait(1.5)
		await _shot(dir, "02-flask.png")
		hero.move_target = fl.global_position
		await _wait(2.0)
		print("oil after flask: ", oil.level)

	# Тени: ставим одну рядом во тьме
	var s: Shade = shades.list_all()[0]
	s.appear_at(hero.global_position + Vector3(6, 0, 2))
	await _wait(4.0)
	await _shot(dir, "03-shade.png")
	Input.action_press("raise")
	await _wait(1.2)
	await _shot(dir, "04-raised.png")
	await _wait(2.0)
	Input.action_release("raise")
	print("shade state after raise: ", s.state)

	# мало масла — свет дрожит и сжимается
	oil.level = 0.08
	await _wait(1.5)
	await _shot(dir, "05-low-oil.png")

	# маяк
	oil.level = 0.7
	var dir_in := Vector3(-b.position.x, 0, -b.position.z).normalized()
	hero.global_position = b.position + dir_in * 2.8
	await _wait(2.0)
	await _shot(dir, "06-beacon-unlit.png")
	_try_light()
	await _wait(1.0)
	await _shot(dir, "07-spark.png")
	await _wait(1.0)
	await _shot(dir, "08-ignite.png")
	await _wait(2.5)
	await _shot(dir, "09-wave.png")
	await _wait(3.0)
	await _shot(dir, "10-wave2.png")
	await _wait(6.0)
	await _shot(dir, "11-alive.png")
	hero.global_position = b.position + dir_in * 12.0
	await _wait(3.0)
	await _shot(dir, "12-alive-meadow.png")
	hero.global_position = b.position + dir_in * 30.0
	await _wait(3.0)
	await _shot(dir, "13-edge.png")

	# обморок: масло кончилось, Тень рядом
	oil.level = 0.0
	s.appear_at(hero.global_position + Vector3(1.0, 0, 0.5))
	await _wait(1.5)
	await _shot(dir, "14-faint-start.png")
	await _wait(1.6)
	await _shot(dir, "15-faint-dark.png")
	await _wait(3.0)
	await _shot(dir, "16-wake.png")
	print("state ", state, " hero ", hero.global_position, " save ", FileAccess.get_file_as_string(SaveGame.PATH))
	print("AUTOTEST DONE fps=", Engine.get_frames_per_second(), " scale=", render_scale)
	get_tree().quit()


func _bench() -> void:
	title.start()
	await _wait(8.0)
	var f0 := Engine.get_frames_drawn()
	var t0 := Time.get_ticks_msec()
	await _wait(4.0)
	var fps_val := (Engine.get_frames_drawn() - f0) * 1000.0 / (Time.get_ticks_msec() - t0)
	print("BENCH fps=%.1f scale=%.2f frame=%.1fms quality=%s" % [fps_val, render_scale, _median(), Quality.level])
	get_tree().quit()
