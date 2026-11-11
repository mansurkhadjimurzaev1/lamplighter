class_name Villager
extends Node3D
## Житель деревни: модель KayKit (без оружия и шлемов), перекрашенная одежда,
## анимация простоя, поворачивается к собеседнику. Огонёк над головой — есть что сказать.

const PROPS := ["Spellbook", "Spellbook_open", "1H_Wand", "2H_Staff", "1H_Axe_Offhand", "Barbarian_Round_Shield", "1H_Axe", "2H_Axe", "Mug", "1H_Sword_Offhand", "Badge_Shield", "Rectangle_Shield", "Round_Shield", "Spike_Shield", "1H_Sword", "2H_Sword", "Knife_Offhand", "1H_Crossbow", "2H_Crossbow", "Knife", "Throwable"]

var id := ""
var display_name := ""
var talk_radius := 2.4
var anim: AnimationPlayer
var _base_rot := 0.0
var _wisp: Node3D
var _wisp_mat: ShaderMaterial
var _wisp_alpha := 0.0
var _head_h := 1.6
var _t := 0.0


## cfg: id, name, model, scale, hide_extra, swaps [[src Color, tol, dst Color]], scarf Color, pose
func build(cfg: Dictionary) -> void:
	id = cfg.id
	display_name = Tr.t(cfg.name)
	name = "NPC_" + id
	var model: Node3D = (load("res://assets/models/people/%s.glb" % cfg.model) as PackedScene).instantiate()
	add_child(model)
	var hide: Array = PROPS + cfg.get("hide_extra", [])
	for n in model.find_children("*", "", true, false):
		if n.name in hide and n is Node3D:
			(n as Node3D).visible = false
	var box := AABB()
	var first := true
	var head_mi: MeshInstance3D = null
	var mats := {}
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if not mi.is_visible_in_tree():
			continue
		var ab: AABB = (global_transform.affine_inverse() * mi.global_transform) * mi.get_aabb()
		box = ab if first else box.merge(ab)
		first = false
		if "_Head" in mi.name:
			head_mi = mi
		for i in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(i)
			if src is StandardMaterial3D:
				if not mats.has(src):
					mats[src] = _tinted((src as StandardMaterial3D).albedo_texture, cfg.get("swaps", []))
				mi.set_surface_override_material(i, mats[src])
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var s: float = cfg.get("height", 1.5) / maxf(box.size.y, 0.01)
	model.scale = Vector3.ONE * s
	_head_h = box.size.y * s

	if cfg.has("scarf") and head_mi != null:
		_add_scarf(model, head_mi, cfg.scarf)
	if cfg.get("crown", false) and head_mi != null:
		_add_crown(model, head_mi)

	anim = model.find_children("*", "AnimationPlayer", true, false)[0]
	var pose: String = cfg.get("pose", "Idle")
	if anim.has_animation(pose):
		anim.get_animation(pose).loop_mode = Animation.LOOP_LINEAR
		anim.play(pose)
		anim.seek(randf() * 2.0)
		anim.speed_scale = randf_range(0.85, 1.0)
	if cfg.get("sitting", false):
		talk_radius = 2.6

	# огонёк над головой
	_wisp = Node3D.new()
	add_child(_wisp)
	var q := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.35, 0.35)
	q.mesh = qm
	_wisp_mat = ShaderMaterial.new()
	_wisp_mat.shader = load("res://shaders/particle_glow.gdshader")
	_wisp_mat.set_shader_parameter("intensity", 3.0)
	_wisp_mat.set_shader_parameter("tint", Vector3(1.0, 0.72, 0.38))
	q.material_override = _wisp_mat
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_wisp.add_child(q)
	var sparks := Fx.embers(5)
	(sparks.process_material as ParticleProcessMaterial).emission_sphere_radius = 0.08
	(sparks.process_material as ParticleProcessMaterial).initial_velocity_max = 0.4
	_wisp.add_child(sparks)


func _tinted(tex: Texture2D, swaps: Array) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/npc.gdshader")
	m.set_shader_parameter("tex", tex)
	for i in mini(swaps.size(), 3):
		var sw: Array = swaps[i]
		var src: Color = sw[0]
		m.set_shader_parameter("swap%d_src" % i, Vector4(src.r, src.g, src.b, sw[1]))
		m.set_shader_parameter("swap%d_dst" % i, sw[2])
	return m


## Платок: полусфера на голове и спадающий на плечи край
func _add_scarf(model: Node3D, head_mi: MeshInstance3D, col: Color) -> void:
	var sk: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
	var bone := sk.find_bone("head")
	if bone < 0:
		return
	var head_box: AABB = (sk.global_transform.affine_inverse() * head_mi.global_transform) * head_mi.get_aabb()
	var att := BoneAttachment3D.new()
	att.bone_name = "head"
	sk.add_child(att)
	var rest := sk.get_bone_global_rest(bone)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.95
	var cap := MeshInstance3D.new()
	var sm := SphereMesh.new()
	var r := maxf(head_box.size.x, head_box.size.z) * 0.47
	sm.radius = r
	sm.height = r * 2.0
	sm.is_hemisphere = true
	cap.mesh = sm
	cap.material_override = mat
	var hc := head_box.get_center()
	cap.position = rest.affine_inverse() * Vector3(hc.x, hc.y - head_box.size.y * 0.08, hc.z - head_box.size.z * 0.08)
	cap.scale = Vector3(1.0, 0.95, 1.05)
	att.add_child(cap)
	var drape := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r * 0.8
	cm.bottom_radius = r * 1.0
	cm.height = head_box.size.y * 0.45
	drape.mesh = cm
	drape.material_override = mat
	drape.position = rest.affine_inverse() * Vector3(hc.x, hc.y - head_box.size.y * 0.3, hc.z - head_box.size.z * 0.12)
	att.add_child(drape)


## Корона: потускневший золотой обруч с зубцами
func _add_crown(model: Node3D, head_mi: MeshInstance3D) -> void:
	var sk: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
	var bone := sk.find_bone("head")
	if bone < 0:
		return
	var head_box: AABB = (sk.global_transform.affine_inverse() * head_mi.global_transform) * head_mi.get_aabb()
	var att := BoneAttachment3D.new()
	att.bone_name = "head"
	sk.add_child(att)
	var rest := sk.get_bone_global_rest(bone)
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(0.62, 0.48, 0.2)
	gold.metallic = 0.85
	gold.roughness = 0.45
	var r := maxf(head_box.size.x, head_box.size.z) * 0.36
	var top := head_box.end.y - head_box.size.y * 0.06
	var hc := head_box.get_center()
	var ring := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r * 0.97
	cm.height = head_box.size.y * 0.12
	cm.cap_top = false
	cm.cap_bottom = false
	ring.mesh = cm
	ring.material_override = gold
	ring.position = rest.affine_inverse() * Vector3(hc.x, top, hc.z)
	att.add_child(ring)
	for k in 6:
		var a := k * TAU / 6.0
		var spike := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(r * 0.4, head_box.size.y * 0.12, r * 0.1)
		spike.mesh = pm
		spike.material_override = gold
		spike.position = rest.affine_inverse() * Vector3(hc.x + cos(a) * r, top + head_box.size.y * 0.11, hc.z + sin(a) * r)
		spike.rotation.y = -a + PI / 2
		att.add_child(spike)


func place(pos: Vector3, facing: float) -> void:
	global_position = pos
	rotation.y = facing
	_base_rot = facing


func update_npc(dt: float, hero: Vector3, news: bool, talking: bool) -> void:
	_t += dt
	var to := hero - global_position
	to.y = 0.0
	var want := _base_rot
	if to.length() < 5.0 or talking:
		want = atan2(to.x, to.z)
	rotation.y = lerp_angle(rotation.y, want, minf(1.0, dt * 3.0))
	_wisp_alpha = move_toward(_wisp_alpha, 1.0 if (news and not talking) else 0.0, dt * 1.5)
	_wisp.visible = _wisp_alpha > 0.01
	_wisp.position = Vector3(0, _head_h + 0.45 + sin(_t * 2.0) * 0.07, 0)
	_wisp.rotation.y = -rotation.y
	_wisp_mat.set_shader_parameter("intensity", 3.0 * _wisp_alpha * (0.8 + 0.2 * sin(_t * 3.3)))


func near(p: Vector3) -> bool:
	return Vector2(p.x - global_position.x, p.z - global_position.z).length() < talk_radius
