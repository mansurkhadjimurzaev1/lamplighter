extends SceneTree
## Рендер людей и печать костей: godot --path . --script res://tools/people_probe.gd -- out.png
func _init() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var files := ["KK_Mage", "KK_Barbarian", "KK_Knight", "KK_Rogue", "KK_Mage", "KK_Barbarian", "KK_Knight", "KK_Rogue"]
	var root := Node3D.new()
	get_root().add_child(root)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.6, 0.65)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.7
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.7, 0.4, 0)
	root.add_child(sun)
	var i := 0
	for f in files:
		var n: Node3D = (load("res://assets/models/people/%s.glb" % f) as PackedScene).instantiate()
		root.add_child(n)
		n.position = Vector3(i * 1.3, 0, 0)
		var props := ["Spellbook", "Spellbook_open", "1H_Wand", "2H_Staff", "1H_Axe_Offhand", "Barbarian_Round_Shield", "1H_Axe", "2H_Axe", "Mug", "1H_Sword_Offhand", "Badge_Shield", "Rectangle_Shield", "Round_Shield", "Spike_Shield", "1H_Sword", "2H_Sword", "Knife_Offhand", "1H_Crossbow", "2H_Crossbow", "Knife", "Throwable"]
		for c in n.find_children("*", "", true, false):
			if c.name in props or (i >= 4 and (c.name.ends_with("_Hat") or c.name.ends_with("_Helmet"))):
				c.visible = false
		var ap: AnimationPlayer = n.find_children("*", "AnimationPlayer", true, false)[0]
		ap.play("Idle")
		var sk: Skeleton3D = n.find_children("*", "Skeleton3D", true, false)[0]
		if i == 0:
			var names := []
			for b in sk.get_bone_count():
				names.append(sk.get_bone_name(b))
			print("bones: ", names)
			print("skeleton global scale: ", sk.global_transform.basis.get_scale(), " head y: ", (sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Head"))).origin if sk.find_bone("Head") >= 0 else "?")
		i += 1
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.position = Vector3(4.55, 1.6, 6.0)
	cam.look_at(Vector3(4.55, 1.0, 0))
	cam.current = true
	for k in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(out)
	quit()
