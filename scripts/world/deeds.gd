class_name Deeds
extends Node3D
## Добрые дела — побочные задания этапа 6:
##   «Фонари Тихого Брода» — зажечь 7 уличных фонарей (E у столба);
##   «Звёздочка» — найти ягнёнка Лии у дороги в лес и привести в загон (идёт следом за светом);
##   «Лепёшка для Корнея» — из чайханы в Топь (только диалоги);
##   «Обожжённые руки» — 4 стебля лунной травы → Вейл варит мазь → Борта (колпак от ветра);
##   «Письма без адресата» — сумка почтальона у подножия гор, три письма жителям;
##   «Тёплая дорога» — разжечь все жаровни на горной лестнице.

signal message(text: String)

const LAMB_START := Vector2(7.0, -23.0)
const HERB_SPOTS := [Vector2(-29.0, 19.0), Vector2(27.0, 7.0), Vector2(-15.0, -27.0), Vector2(17.0, 30.0)]

var lamb: Node3D
var lamb_following := false
var _lamb_anim: AnimationPlayer
var _lamb_idle := ""
var _lamb_walk := ""
var _lamb_sound: AudioStreamPlayer3D
var _lamb_target := Vector2.ZERO
var _lamb_timer := 0.0
var _rng := RandomNumberGenerator.new()


## Найти ближайшее место, где можно стоять (вне деревни и глубины леса)
static func snap(p: Vector2) -> Vector2:
	for r in range(0, 12):
		for k in 12:
			var q := p + Vector2(cos(k * TAU / 12.0), sin(k * TAU / 12.0)) * r * 0.8
			if Hero.can_stand(q.x, q.y) and not ForestLayout.in_core(q.x, q.y) and Terrain.height_at(q.x, q.y) > 0.2 and not SwampLayout.in_swamp(q.x, q.y):
				return q
	return p


func build(pickups: Pickups) -> void:
	name = "Deeds"
	_rng.seed = 404
	# лунная трава
	var i := 0
	for s in HERB_SPOTS:
		var q := snap(s)
		pickups.add("moonherb_%d" % i, "moonherb", Vector3(q.x, Terrain.height_at(q.x, q.y), q.y), "quest:borta_herbs=active")
		i += 1
	# сумка почтальона у подножия гор
	var bag := snap(MountainLayout.STAIRS[0] + Vector2(3.0, 2.5))
	pickups.add("post_bag", "post_bag", Vector3(bag.x, Terrain.height_at(bag.x, bag.y), bag.y), "flag:has_lantern")
	_build_lamb()


func _build_lamb() -> void:
	var scene: PackedScene = load("res://assets/models/animals/Sheep.fbx")
	var s: Node3D = scene.instantiate()
	lamb = Node3D.new()
	lamb.name = "Lamb"
	lamb.add_child(s)
	add_child(lamb)
	var box := AABB()
	for mi: MeshInstance3D in s.find_children("*", "MeshInstance3D", true, false):
		box = (lamb.global_transform.affine_inverse() * mi.global_transform) * mi.get_aabb()
	s.scale = Vector3.ONE * (0.72 / maxf(box.size.y, 0.001))
	s.position.y = -box.position.y * s.scale.y
	# белое пятнышко на лбу — Звёздочка
	var star := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.05
	sm.height = 0.06
	star.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 1, 0.95)
	mat.emission_enabled = true
	mat.emission = Color(1, 0.95, 0.8)
	mat.emission_energy_multiplier = 0.6
	star.material_override = mat
	star.position = Vector3(0, 0.62, 0.36)
	lamb.add_child(star)
	_lamb_anim = s.find_children("*", "AnimationPlayer", true, false)[0]
	for a in _lamb_anim.get_animation_list():
		if "Idle" in a and _lamb_idle == "":
			_lamb_idle = a
		if ("Walk" in a or "Run" in a) and _lamb_walk == "":
			_lamb_walk = a
	if _lamb_idle == "":
		_lamb_idle = _lamb_anim.get_animation_list()[0]
	for a in [_lamb_idle, _lamb_walk]:
		if a != "":
			_lamb_anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	_lamb_anim.play(_lamb_idle)
	_lamb_sound = AudioStreamPlayer3D.new()
	_lamb_sound.stream = Synth.cached("lamb", func(): return Synth.sheep(14.0, 41), true)
	_lamb_sound.unit_size = 7.0
	_lamb_sound.max_distance = 45.0
	_lamb_sound.pitch_scale = 1.35 # ягнёнок — голос тоньше
	lamb.add_child(_lamb_sound)
	if GameState.flags.get("lamb_home", false):
		_put_in_pen()
	else:
		var p := snap(LAMB_START)
		lamb.global_position = Vector3(p.x, Terrain.height_at(p.x, p.y), p.y)


func _put_in_pen() -> void:
	var c := VillageLayout.world(VillageLayout.PEN_CENTER + Vector2(1.2, -0.6))
	lamb.global_position = Vector3(c.x, Terrain.height_at(c.x, c.y), c.y)
	_lamb_target = c
	lamb_following = false


func lamb_active() -> bool:
	return GameState.quest("lia_lamb") == "active" and not GameState.flags.get("lamb_home", false)


func call_lamb() -> void:
	lamb_following = true
	message.emit(Tr.t("Звёздочка подняла голову и пошла за светом"))


## Каждый кадр: ягнёнок, проверки заданий
func update(dt: float, hero_pos: Vector3, hero_facing: float, light_on: bool, playing: bool) -> void:
	_update_lamb(dt, hero_pos, hero_facing, light_on, playing)
	if not playing:
		return
	# сумка почтальона → три письма
	if int(GameState.items.get("post_bag", 0)) > 0:
		GameState.apply("take:post_bag")
		GameState.apply("quest:post_letters=active")
		for id in ["letter_mara", "letter_borta", "letter_lia"]:
			GameState.apply("give:" + id)


func _update_lamb(dt: float, hero_pos: Vector3, facing: float, light_on: bool, playing: bool) -> void:
	var home: bool = GameState.flags.get("lamb_home", false)
	var active := lamb_active()
	lamb.visible = active or home
	_lamb_sound.volume_db = linear_to_db(0.55 if (active and not lamb_following) else 0.0001)
	if active and not _lamb_sound.playing:
		_lamb_sound.play()
	elif not active and _lamb_sound.playing:
		_lamb_sound.stop()
	var moving := false
	var p := Vector2(lamb.global_position.x, lamb.global_position.z)
	if active and lamb_following:
		var hp := Vector2(hero_pos.x, hero_pos.z)
		if hp.distance_to(p) > 30.0 or not light_on:
			# фонарь погас или герой исчез (обморок) — ягнёнок остаётся и ждёт
			lamb_following = false
		else:
			var behind := hp - Vector2(sin(facing), cos(facing)) * 1.4
			var to := behind - p
			if to.length() > 0.5:
				var sp := clampf(to.length() * 1.5, 0.0, 2.8)
				p += to.normalized() * minf(to.length(), sp * dt)
				lamb.rotation.y = lerp_angle(lamb.rotation.y, atan2(to.x, to.y), dt * 6.0)
				moving = sp > 0.4
			# дома: загон рядом
			var pen := VillageLayout.world(VillageLayout.PEN_CENTER)
			if p.distance_to(pen) < 6.0 and playing:
				GameState.flags["lamb_home"] = true
				_put_in_pen()
				message.emit(Tr.t("Звёздочка дома. Расскажи Лие"))
				return
	elif home:
		# пасётся в загоне вместе с остальными
		_lamb_timer -= dt
		if _lamb_timer <= 0.0:
			_lamb_timer = _rng.randf_range(4.0, 10.0)
			var half := VillageLayout.PEN_SIZE * 0.5 - Vector2(1.0, 1.0)
			_lamb_target = VillageLayout.world(VillageLayout.PEN_CENTER + Vector2(_rng.randf_range(-half.x, half.x), _rng.randf_range(-half.y, half.y)))
		var to := _lamb_target - p
		if to.length() > 0.2:
			p += to.normalized() * minf(to.length(), dt * 0.4)
			lamb.rotation.y = lerp_angle(lamb.rotation.y, atan2(to.x, to.y), dt * 2.0)
	lamb.global_position = Vector3(p.x, Terrain.height_at(p.x, p.y), p.y)
	var want := _lamb_walk if (moving and _lamb_walk != "") else _lamb_idle
	if _lamb_anim.current_animation != want:
		_lamb_anim.play(want, 0.25)
