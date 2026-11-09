class_name Hero
extends Node3D
## Герой: путник в капюшоне (KayKit Adventurers, CC0) с анимациями «стоит» и «идёт».
## Ходит медленно — это старый фонарщик.

const WALK_SPEED := 2.1
const HERO_HEIGHT := 1.55
const HIDE := ["Knife_Offhand", "1H_Crossbow", "2H_Crossbow", "Knife", "Throwable"]

var anim: AnimationPlayer
var skeleton: Skeleton3D
var hand_bone := -1
var speed := 0.0
var facing := 0.0
var distance := 0.0 # пройденный путь — для звука шагов
var move_target: Variant = null # точка после тапа/клика
var _walking := false
var _busy := 0.0 # пока > 0 — герой занят анимацией (пробуждение)


func build() -> void:
	name = "Hero"
	var model: Node3D = (load("res://assets/models/hero/Rogue_Hooded.glb") as PackedScene).instantiate()
	add_child(model)
	for n in model.find_children("*", "", true, false):
		if n.name in HIDE and n is Node3D:
			(n as Node3D).visible = false
	var seen := {}
	var box := AABB()
	var first := true
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if not mi.visible or mi.name in HIDE or mi.get_parent().name in HIDE:
			continue
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF # фонарь в руке: тень героя закрывала бы полкруга света
		var ab: AABB = mi.global_transform * mi.get_aabb() if mi.is_inside_tree() else mi.get_aabb()
		box = ab if first else box.merge(ab)
		first = false
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i)
			if m is StandardMaterial3D and not seen.has(m):
				seen[m] = true
				var sm := m as StandardMaterial3D
				sm.roughness = 0.85
				sm.metallic = 0.0
				sm.albedo_color = Color(0.62, 0.58, 0.5) # приглушаем яркую зелень — дорожный, выцветший плащ
	model.scale = Vector3.ONE * (HERO_HEIGHT / maxf(box.size.y, 0.01))

	var sk := model.find_children("*", "Skeleton3D", true, false)
	if sk.size() > 0:
		skeleton = sk[0]
		for bn in ["handslot.r", "handslot_r", "handslotr", "hand.r", "hand_r"]:
			hand_bone = skeleton.find_bone(bn)
			if hand_bone >= 0:
				break
	var ap := model.find_children("*", "AnimationPlayer", true, false)
	anim = ap[0]
	for a in ["Idle", "Walking_A"]:
		if anim.has_animation(a):
			anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	anim.play("Idle")


func hand_position() -> Vector3:
	if skeleton and hand_bone >= 0:
		return (skeleton.global_transform * skeleton.get_bone_global_pose(hand_bone)).origin
	return global_position + Vector3(0.3, 0.7, 0)


## Пробуждение после обморока
func wake() -> void:
	_busy = 2.6
	_walking = false
	speed = 0.0
	move_target = null
	if anim.has_animation("Lie_StandUp"):
		anim.play("Lie_StandUp")
		anim.speed_scale = 0.8
		anim.queue("Idle")


func face(p: Vector3) -> void:
	facing = atan2(p.x - global_position.x, p.z - global_position.z)
	rotation.y = facing


func update_hero(dt: float, input_dir: Vector2, cam: Camera3D, colliders: Array[Vector3], active: bool) -> void:
	if _busy > 0.0:
		_busy -= dt
		global_position.y = Terrain.height_at(global_position.x, global_position.z)
		return
	var dir := Vector3.ZERO
	if active:
		if input_dir.length_squared() > 0.0:
			move_target = null
			var fwd := -cam.global_transform.basis.z
			fwd.y = 0.0
			fwd = fwd.normalized()
			var right := Vector3(-fwd.z, 0, fwd.x)
			dir = fwd * input_dir.y + right * input_dir.x
		elif move_target != null:
			dir = (move_target as Vector3) - global_position
			dir.y = 0.0
			if dir.length() < 0.25:
				move_target = null
				dir = Vector3.ZERO
			else:
				dir = dir.normalized()

	var moving := dir.length_squared() > 0.001
	var target_speed := WALK_SPEED * minf(1.0, dir.length()) if moving else 0.0
	speed += (target_speed - speed) * minf(1.0, dt * 8.0)
	if moving:
		var want := atan2(dir.x, dir.z)
		facing += wrapf(want - facing, -PI, PI) * minf(1.0, dt * 10.0)

	if speed > 0.01:
		var before := global_position
		var next := before + Vector3(sin(facing), 0, cos(facing)) * speed * dt
		next = _resolve(next, colliders)
		if Terrain.height_at(next.x, next.z) < Terrain.WATER_LEVEL - 0.15:
			next = before # не заходим в воду глубже щиколотки
			move_target = null
		distance += Vector2(next.x - before.x, next.z - before.z).length()
		global_position = next
	global_position.y = Terrain.height_at(global_position.x, global_position.z)
	rotation.y = facing

	# «стоит» ↔ «идёт», темп шага подстраивается под скорость
	var w := clampf(speed / WALK_SPEED, 0.0, 1.0)
	if w > 0.15 and not _walking:
		_walking = true
		anim.play("Walking_A", 0.25)
	elif w <= 0.15 and _walking:
		_walking = false
		anim.play("Idle", 0.35)
	anim.speed_scale = 0.85 * maxf(0.5, w) if _walking else 1.0


func _resolve(p: Vector3, colliders: Array[Vector3]) -> Vector3:
	var r := 0.3
	for c in colliders:
		var dx := p.x - c.x
		var dz := p.z - c.y
		var d := sqrt(dx * dx + dz * dz)
		var m := c.z + r
		if d < m and d > 0.0001:
			p.x = c.x + dx / d * m
			p.z = c.y + dz / d * m
	return p
