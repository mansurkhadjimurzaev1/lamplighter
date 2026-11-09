extends Node3D
## Точка входа: собирает мир, героя, свет, звук и интерфейс; главный цикл.

var terrain: MeshInstance3D
var vegetation: Vegetation
var hero: Hero
var lantern: Lantern
var cam: CameraRig
var sound: Soundscape
var title: TitleScreen
var fps: FpsMeter
var grade: ShaderMaterial

var started := false
var _fade := 0.0
var _next_step_at := 0.65
var _last_hero_pos := Vector3.ZERO
var _velocity := Vector3.ZERO
var _press_pos := Vector2.ZERO
var _press_time := 0
# адаптивное разрешение
var render_scale := 1.0
var _gpu_samples: Array[float] = []
var _scale_cooldown := 3.0


func _ready() -> void:
	Quality.setup()
	_setup_input()
	if Args.has("bench"):
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0

	title = TitleScreen.new()
	title.build()
	add_child(title)
	title.started.connect(_on_start)
	grade = Atmosphere.grade_layer(self)
	grade.set_shader_parameter("fade", 0.0)
	fps = FpsMeter.new()
	fps.build()
	fps.extra = func(): return "%s · %.0f%% разрешения · кадр %.1f мс" % [Quality.level, render_scale * 100.0, _gpu_median()]
	add_child(fps)

	# даём заставке отрисоваться, потом строим мир
	await get_tree().process_frame
	await get_tree().process_frame
	_build_world()
	title.set_ready()
	if Args.has("autotest"):
		_autotest(Args.get_value("autotest", "user://shots"))
	elif Args.has("bench"):
		_bench()


func _build_world() -> void:
	add_child(Atmosphere.environment())
	add_child(Atmosphere.moon())

	terrain = Terrain.build()
	add_child(terrain)
	var water := Water.new()
	water.build()
	add_child(water)
	var grass := Grass.new()
	grass.name = "Grass"
	grass.build(Quality.grass_per_m2)
	add_child(grass)
	vegetation = Vegetation.new()
	vegetation.name = "Vegetation"
	vegetation.build(Quality.shadows)
	add_child(vegetation)
	add_child(Particles.fireflies(Quality.fireflies))
	add_child(Particles.dust(Quality.dust))

	hero = Hero.new()
	add_child(hero)
	hero.build()
	hero.global_position = Vector3(0, Terrain.height_at(0, 4), 4)
	_last_hero_pos = hero.global_position
	lantern = Lantern.new()
	lantern.build(Quality.shadows)
	add_child(lantern)

	cam = CameraRig.new()
	cam.setup()
	add_child(cam)
	cam.current = true
	cam.snap(hero.global_position)

	sound = Soundscape.new()
	sound.build()
	add_child(sound)

	var vp := get_viewport()
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if not OS.has_feature("mobile") else Viewport.SCALING_3D_MODE_BILINEAR
	RenderingServer.viewport_set_measure_render_time(vp.get_viewport_rid(), true)


func _on_start() -> void:
	started = true
	sound.start()


func _setup_input() -> void:
	var map := {
		"move_up": [KEY_W, KEY_UP], "move_down": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
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
	# тап / клик по земле — идти туда (короткое нажатие без сдвига)
	var pressed := false
	var released := false
	var pos := Vector2.ZERO
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		pressed = e.pressed; released = not e.pressed; pos = e.position
	elif e is InputEventScreenTouch:
		pressed = e.pressed; released = not e.pressed; pos = e.position
	if pressed:
		_press_pos = pos
		_press_time = Time.get_ticks_msec()
	elif released and started and pos.distance_to(_press_pos) < 20.0:
		var origin := cam.project_ray_origin(pos)
		var dir := cam.project_ray_normal(pos)
		var hit: Variant = Terrain.raycast(origin, dir)
		if hit != null:
			hero.move_target = hit


func _process(dt: float) -> void:
	if hero == null:
		return
	dt = minf(dt, 0.05)
	var axis := Input.get_vector("move_left", "move_right", "move_down", "move_up")
	hero.update_hero(dt, axis, cam, vegetation.colliders, started)
	_velocity = (hero.global_position - _last_hero_pos) / maxf(dt, 0.001)
	_last_hero_pos = hero.global_position

	lantern.update_lantern(dt, hero.hand_position())
	cam.follow(dt, hero.global_position, _velocity)
	RenderingServer.global_shader_parameter_set("hero_pos", hero.global_position)
	RenderingServer.global_shader_parameter_set("lantern_pos", lantern.light_world_position())

	if hero.distance >= _next_step_at:
		_next_step_at = hero.distance + randf_range(0.62, 0.68)
		sound.step(Terrain.surface_at(hero.global_position.x, hero.global_position.z))
	sound.update_sound(dt)

	# плавное появление из темноты
	_fade = minf(1.0, _fade + dt * (0.35 if started else 0.12))
	grade.set_shader_parameter("fade", _fade if started else minf(_fade, 0.45))
	if started:
		_adapt_resolution(dt)


## Адаптивное разрешение: если кадр дольше ~18 мс (меньше ~55 fps) — снижаем чёткость;
## если стабильно 60 fps — время от времени пробуем поднять обратно.
func _adapt_resolution(dt: float) -> void:
	_gpu_samples.append(get_process_delta_time() * 1000.0)
	if _gpu_samples.size() > 40:
		_gpu_samples.pop_front()
	_scale_cooldown -= dt
	if _scale_cooldown > 0.0 or _gpu_samples.size() < 30:
		return
	var med := _gpu_median()
	var next := render_scale
	var cooldown := 1.2
	if med > 18.5:
		next *= 0.88 # не успеваем — чуть ниже чёткость
	elif med < 17.4 and render_scale < 1.0:
		next *= 1.06 # успеваем — пробуем чётче
		cooldown = 6.0
	next = clampf(next, Quality.min_render_scale, 1.0)
	if absf(next - render_scale) > 0.02:
		render_scale = next
		get_viewport().scaling_3d_scale = render_scale
		_gpu_samples.clear()
		_scale_cooldown = cooldown


func _gpu_median() -> float:
	if _gpu_samples.is_empty():
		return 0.0
	var s := _gpu_samples.duplicate()
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
	if Args.has("quick"):
		title.start()
		hero.global_position = Vector3(-18, 0, -10)
		await _wait(4.0)
		fps.visible = true
		await _wait(1.0)
		await _shot(dir, "quick.png")
		print("GPU ms: ", RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid()), " CPU ms: ", RenderingServer.viewport_get_measured_render_time_cpu(get_viewport().get_viewport_rid()))
		get_tree().quit()
		return
	await _wait(0.5)
	await _shot(dir, "0-title.png")
	title.start()
	await _wait(3.5)
	await _shot(dir, "1-start.png")
	Input.action_press("move_up")
	Input.action_press("move_right")
	await _wait(2.5)
	Input.action_release("move_right")
	await _wait(1.5)
	Input.action_release("move_up")
	print("hero after walk: ", hero.global_position)
	await _shot(dir, "2-walk.png")
	fps.visible = true
	await _wait(1.5)
	await _shot(dir, "3-fps.png")
	var z := 20.0
	while Terrain.height_at(0, z) > 0.35:
		z += 0.2
	hero.global_position = Vector3(0, 0, z - 0.5)
	await _wait(3.0)
	await _shot(dir, "4-coast.png")
	hero.global_position = Vector3(-18, 0, -10)
	await _wait(3.0)
	await _shot(dir, "5-forest.png")
	print("AUTOTEST DONE fps=", Engine.get_frames_per_second(), " scale=", render_scale)
	get_tree().quit()


func _bench() -> void:
	title.start()
	await _wait(8.0)
	var f0 := Engine.get_frames_drawn()
	var t0 := Time.get_ticks_msec()
	await _wait(4.0)
	var fps_val := (Engine.get_frames_drawn() - f0) * 1000.0 / (Time.get_ticks_msec() - t0)
	print("BENCH fps=%.1f scale=%.2f gpu=%.1fms quality=%s" % [fps_val, render_scale, _gpu_median(), Quality.level])
	get_tree().quit()
