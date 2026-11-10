class_name Pickups
extends Node3D
## Находки в мире: вещи для обмена, первоцвет у маяка. Подбираются при подходе.

const RADIUS := 1.1

var _items: Array = [] # {id, item, node, base_y, cond}
var _sparkle: GPUParticles3D
var _t := 0.0


func add(id: String, item: String, pos: Vector3, cond := "true") -> void:
	if GameState.picked.has(id):
		return
	var node := Node3D.new()
	add_child(node)
	node.global_position = pos + Vector3(0, 0.25, 0)
	_model(node, item)
	var glint := Fx.embers(5)
	var pm := glint.process_material as ParticleProcessMaterial
	pm.emission_sphere_radius = 0.2
	pm.initial_velocity_max = 0.35
	pm.gravity = Vector3(0, 0.2, 0)
	node.add_child(glint)
	var halo := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.9, 0.9)
	halo.mesh = qm
	var hm := ShaderMaterial.new()
	hm.shader = load("res://shaders/particle_glow.gdshader")
	hm.set_shader_parameter("intensity", 0.5)
	hm.set_shader_parameter("tint", Vector3(1.0, 0.8, 0.5))
	halo.material_override = hm
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(halo)
	_items.append({id = id, item = item, node = node, base_y = node.global_position.y, cond = cond})
	if _sparkle == null:
		_sparkle = Fx.burst(30, 2.0)
		add_child(_sparkle)


func _mat(c: Color, metal := 0.0, emit := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metal
	m.roughness = 0.5
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	return m


func _model(n: Node3D, item: String) -> void:
	var mi := MeshInstance3D.new()
	match item.get_slice(":", 0):
		"note":
			var scroll := CylinderMesh.new()
			scroll.top_radius = 0.045
			scroll.bottom_radius = 0.045
			scroll.height = 0.3
			mi.mesh = scroll
			mi.material_override = _mat(Color(0.88, 0.8, 0.6), 0.0, 0.6)
			mi.rotation = Vector3(0, 0, PI / 2)
			var tie := MeshInstance3D.new()
			var tm := TorusMesh.new()
			tm.inner_radius = 0.045
			tm.outer_radius = 0.055
			tie.mesh = tm
			tie.material_override = _mat(Color(0.55, 0.15, 0.1))
			tie.rotation = Vector3(0, 0, PI / 2)
			n.add_child(tie)
		"mushroom":
			var cap := SphereMesh.new()
			cap.radius = 0.16
			cap.height = 0.14
			cap.is_hemisphere = true
			mi.mesh = cap
			mi.material_override = _mat(Color(0.35, 0.95, 0.85), 0.0, 3.0)
			mi.position.y = 0.12
			var stem := MeshInstance3D.new()
			var sm := CylinderMesh.new()
			sm.top_radius = 0.04
			sm.bottom_radius = 0.055
			sm.height = 0.16
			stem.mesh = sm
			stem.material_override = _mat(Color(0.85, 0.85, 0.78), 0.0, 0.4)
			stem.position.y = 0.05
			n.add_child(stem)
		"rope":
			var t := TorusMesh.new()
			t.inner_radius = 0.06
			t.outer_radius = 0.16
			mi.mesh = t
			mi.material_override = _mat(Color(0.62, 0.5, 0.32), 0.0, 0.3)
		"resin":
			var s5 := SphereMesh.new()
			s5.radius = 0.1
			s5.height = 0.16
			mi.mesh = s5
			mi.material_override = _mat(Color(0.85, 0.5, 0.12), 0.0, 1.6)
		"horseshoe":
			var t := TorusMesh.new()
			t.inner_radius = 0.07
			t.outer_radius = 0.11
			mi.mesh = t
			mi.material_override = _mat(Color(0.35, 0.3, 0.28), 0.8)
			mi.rotation = Vector3(PI / 2, 0, 0)
		"wool":
			var s := SphereMesh.new()
			s.radius = 0.12
			s.height = 0.2
			mi.mesh = s
			mi.material_override = _mat(Color(0.85, 0.82, 0.75))
		"spoon":
			var b := BoxMesh.new()
			b.size = Vector3(0.03, 0.02, 0.26)
			mi.mesh = b
			mi.material_override = _mat(Color(0.55, 0.36, 0.2))
			var bowl := MeshInstance3D.new()
			var s2 := SphereMesh.new()
			s2.radius = 0.05
			s2.height = 0.04
			bowl.mesh = s2
			bowl.material_override = mi.material_override
			bowl.position = Vector3(0, 0, 0.14)
			n.add_child(bowl)
		"bead":
			var s3 := SphereMesh.new()
			s3.radius = 0.06
			s3.height = 0.12
			mi.mesh = s3
			mi.material_override = _mat(Color(0.25, 0.45, 0.95), 0.0, 1.5)
		"flower":
			var s4 := SphereMesh.new()
			s4.radius = 0.06
			s4.height = 0.08
			mi.mesh = s4
			mi.material_override = _mat(Color(1.0, 0.85, 0.35), 0.0, 3.0)
			for k in 6:
				var p := MeshInstance3D.new()
				var pm := SphereMesh.new()
				pm.radius = 0.06
				pm.height = 0.03
				p.mesh = pm
				p.material_override = _mat(Color(1.0, 0.95, 0.85), 0.0, 1.2)
				p.position = Vector3(cos(k * TAU / 6.0), 0, sin(k * TAU / 6.0)) * 0.09
				p.scale = Vector3(1.4, 1, 0.7)
				p.rotation.y = -k * TAU / 6.0
				n.add_child(p)
			var stem := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.01
			cm.bottom_radius = 0.012
			cm.height = 0.3
			stem.mesh = cm
			stem.material_override = _mat(Color(0.2, 0.45, 0.12))
			stem.position = Vector3(0, -0.15, 0)
			n.add_child(stem)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(mi)


## Возвращает true, если что-то подобрали
func update_pickups(dt: float, hero: Vector3) -> bool:
	_t += dt
	var got := false
	for it in _items:
		if GameState.picked.has(it.id):
			continue
		var n: Node3D = it.node
		var active := GameState.check(it.cond)
		n.visible = active
		if not active:
			continue
		n.global_position.y = it.base_y + sin(_t * 1.7 + n.global_position.x) * 0.05
		n.rotation.y += dt * 0.8
		if Vector2(n.global_position.x - hero.x, n.global_position.z - hero.z).length() < RADIUS:
			GameState.picked[it.id] = true
			n.visible = false
			_sparkle.global_position = n.global_position
			_sparkle.restart()
			_sparkle.emitting = true
			if it.item.begins_with("note:"):
				GameState.apply(it.item)
			else:
				GameState.apply("give:" + it.item)
			got = true
	return got
