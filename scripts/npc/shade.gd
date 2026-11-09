class_name Shade
extends Node3D
## Тень — отчаяние людей, принявшее форму. Медленно подкрадывается во тьме,
## держится у края света и дрожит, от сильного света рассеивается в дым.
## Её не убивают — отгоняют.

enum State { WANDER, STALK, AFRAID, DISPERSE, GONE }

const STALK_SPEED := 0.75
const FLEE_SPEED := 1.8
const NOTICE_DIST := 16.0
const TOUCH_DIST := 0.75

var state := State.WANDER
var home := Vector3.ZERO
var exposure := 0.0
var respawn_in := 0.0
var _mat: ShaderMaterial
var _anim: AnimationPlayer
var _smoke: GPUParticles3D
var _puff: GPUParticles3D
var _eyes: Array[MeshInstance3D] = []
var _eye_mat: StandardMaterial3D
var _fade := 0.0
var _fear := 0.0
var _wander_target := Vector3.ZERO
var _wander_timer := 0.0
var _seed := 0.0
var _model: Node3D


func build(model_scene: PackedScene, rng: RandomNumberGenerator) -> void:
	name = "Shade"
	_seed = rng.randf() * 100.0
	_model = model_scene.instantiate()
	add_child(_model)
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/shade.gdshader")
	_mat.set_shader_parameter("height_map", Terrain.height_tex)
	_mat.set_shader_parameter("map_size", Terrain.SIZE)
	_mat.set_shader_parameter("map_res", float(Terrain.SEGS + 1))
	_mat.set_shader_parameter("seed", _seed)
	var box := AABB()
	var first := true
	var head_mi: MeshInstance3D = null
	for mi: MeshInstance3D in _model.find_children("*", "MeshInstance3D", true, false):
		if mi.name in Hero.HIDE or mi.get_parent().name in Hero.HIDE:
			mi.visible = false
			continue
		mi.material_override = _mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var ab: AABB = (global_transform.affine_inverse() * mi.global_transform) * mi.get_aabb()
		box = ab if first else box.merge(ab)
		first = false
		if "Head" in mi.name:
			head_mi = mi
	for n in _model.find_children("*", "", true, false):
		if n.name in Hero.HIDE and n is Node3D:
			(n as Node3D).visible = false
	# Тени чуть выше и тоньше человека
	var s := 1.75 / maxf(box.size.y, 0.01) * rng.randf_range(0.92, 1.12)
	_model.scale = Vector3(s * 0.85, s, s * 0.85)

	# тусклые глаза в глубине капюшона
	_eye_mat = StandardMaterial3D.new()
	_eye_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_eye_mat.albedo_color = Color(0.75, 0.82, 1.0)
	_eye_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var sk := _model.find_children("*", "Skeleton3D", true, false)
	if sk.size() > 0 and head_mi != null:
		var skel: Skeleton3D = sk[0]
		# рамка головы в пространстве скелета
		var head_box: AABB = (skel.global_transform.affine_inverse() * head_mi.global_transform) * head_mi.get_aabb()
		var bone := skel.find_bone("head")
		var att := BoneAttachment3D.new()
		att.bone_name = "head" if bone >= 0 else skel.get_bone_name(0)
		skel.add_child(att)
		var rest := skel.get_bone_global_rest(maxi(bone, 0))
		var hc := head_box.get_center()
		for side in [-1.0, 1.0]:
			var e := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = head_box.size.x * 0.05
			sm.height = sm.radius * 1.4
			e.mesh = sm
			e.material_override = _eye_mat
			e.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var model_pos := Vector3(hc.x + side * head_box.size.x * 0.16, hc.y - head_box.size.y * 0.05, head_box.end.z - head_box.size.z * 0.12)
			e.position = rest.affine_inverse() * model_pos
			att.add_child(e)
			_eyes.append(e)

	_smoke = Fx.smoke()
	_smoke.position = Vector3(0, 0.9, 0)
	add_child(_smoke)
	_puff = Fx.smoke_burst()
	_puff.position = Vector3(0, 0.9, 0)
	add_child(_puff)

	var ap := _model.find_children("*", "AnimationPlayer", true, false)
	_anim = ap[0]
	_anim.play("Walking_A")
	_anim.speed_scale = 0.5
	_apply_visual()


func appear_at(p: Vector3) -> void:
	home = p
	global_position = Vector3(p.x, Terrain.height_at(p.x, p.z), p.z)
	state = State.WANDER
	exposure = 0.0
	_fade = 0.0
	_wander_target = global_position
	visible = true
	_smoke.emitting = true


func disperse(sound: Soundscape) -> void:
	if state == State.DISPERSE or state == State.GONE:
		return
	state = State.DISPERSE
	_puff.restart()
	_puff.emitting = true
	_smoke.emitting = false
	if sound:
		sound.sfx("disperse", 0.4, randf_range(0.85, 1.1))


## light_r — радиус света фонаря; strong — фонарь поднят; out — фонарь почти погас.
## Возвращает true, если Тень коснулась героя.
func tick(dt: float, hero: Vector3, light_r: float, strong: bool, out: bool, colliders: Array[Vector3], sound: Soundscape) -> bool:
	match state:
		State.GONE:
			respawn_in -= dt
			return false
		State.DISPERSE:
			_fade = move_toward(_fade, 0.0, dt / 1.3)
			_fear = 1.0
			_apply_visual()
			if _fade <= 0.0:
				state = State.GONE
				visible = false
				respawn_in = randf_range(18.0, 35.0)
			return false

	_fade = move_toward(_fade, 1.0, dt / 2.5) # проступает из тьмы медленно
	var to_hero := hero - global_position
	to_hero.y = 0.0
	var dist := to_hero.length()
	var dir := to_hero / maxf(dist, 0.001)
	var hold := light_r * 0.85 + 0.3 # держится на самом краю света
	var move := Vector3.ZERO
	var speed := 0.0

	# ожившая земля — Теням там не место
	if Beacon.restore_at(global_position) > 0.25:
		disperse(sound)
		return false

	if dist < NOTICE_DIST:
		if out:
			state = State.STALK
		elif dist < hold:
			state = State.AFRAID
		else:
			state = State.STALK
	else:
		state = State.WANDER

	match state:
		State.WANDER:
			_wander_timer -= dt
			if _wander_timer <= 0.0:
				_wander_timer = randf_range(3.0, 7.0)
				_wander_target = home + Vector3(randf_range(-6, 6), 0, randf_range(-6, 6))
			var w := _wander_target - global_position
			w.y = 0.0
			if w.length() > 0.5:
				move = w.normalized()
				speed = 0.35
			_fear = move_toward(_fear, 0.0, dt)
		State.STALK:
			if out or dist > hold + 0.3:
				move = dir
				speed = STALK_SPEED * (1.4 if out else 1.0)
			_fear = move_toward(_fear, 0.15, dt)
		State.AFRAID:
			# отступает от света и дрожит
			move = -dir
			speed = FLEE_SPEED * clampf((hold - dist) / 1.5, 0.2, 1.0) * (1.6 if strong else 1.0)
			_fear = move_toward(_fear, 1.0, dt * 3.0)

	# в сильном свете Тень накапливает «страх» и рассеивается
	if not out and (dist < light_r * 0.6 or (strong and dist < light_r * 0.95)):
		exposure += dt * (1.5 if strong else 0.3)
	else:
		exposure = maxf(0.0, exposure - dt * 0.5)
	if exposure >= 1.0:
		disperse(sound)
		return false

	if speed > 0.0:
		var next := global_position + move * speed * dt
		for c in colliders:
			var dx := next.x - c.x
			var dz := next.z - c.y
			var d := sqrt(dx * dx + dz * dz)
			if d < c.z + 0.35 and d > 0.001:
				next.x = c.x + dx / d * (c.z + 0.35)
				next.z = c.y + dz / d * (c.z + 0.35)
		if Terrain.height_at(next.x, next.z) > 0.1:
			global_position = next
	global_position.y = Terrain.height_at(global_position.x, global_position.z)
	# смотрит на героя (или по ходу)
	var look := dir if state != State.WANDER else move
	if look.length() > 0.1:
		rotation.y = lerp_angle(rotation.y, atan2(look.x, look.z), minf(1.0, dt * 4.0))
	_anim.speed_scale = 0.25 + speed * 0.5
	_apply_visual()
	return dist < TOUCH_DIST and state != State.AFRAID


func _apply_visual() -> void:
	_mat.set_shader_parameter("fade", _fade)
	_mat.set_shader_parameter("fear", _fear)
	_eye_mat.albedo_color.a = _fade * (0.55 + 0.25 * sin(Time.get_ticks_msec() * 0.002 + _seed))
	(_smoke.draw_pass_1 as QuadMesh).size = Vector2.ONE * 0.7 * maxf(_fade, 0.3)
