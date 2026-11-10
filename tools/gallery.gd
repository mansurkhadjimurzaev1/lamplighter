extends SceneTree
## Галерея моделей для осмотра: godot --path . --script res://tools/gallery.gd -- out.png dir file1 file2 ...
## Печатает анимации и материалы, рисует модели в ряд при дневном свете.

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	var dir: String = args[1]
	var files := args.slice(2)
	var root := Node3D.new()
	get_root().add_child(root)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.6, 0.65)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(1, 1, 1)
	env.environment.ambient_light_energy = 0.6
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, 0.6, 0)
	root.add_child(sun)
	var x := 0.0
	var maxh := 0.0
	for f in files:
		var scene: PackedScene = load("res://%s/%s.glb" % [dir, f])
		var n: Node3D = scene.instantiate()
		root.add_child(n)
		var box := AABB()
		var first := true
		var mats := {}
		for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
			var ab: AABB = mi.global_transform * mi.get_aabb()
			box = ab if first else box.merge(ab)
			first = false
			for i in mi.mesh.get_surface_count():
				var m = mi.mesh.surface_get_material(i)
				if m: mats[m.resource_name] = true
		var anims := []
		for ap: AnimationPlayer in n.find_children("*", "AnimationPlayer", true, false):
			anims = ap.get_animation_list()
		print(f, " size=", box.size.snapped(Vector3.ONE * 0.01), " mats=", mats.keys(), " anims=", anims)
		var s := 2.0 / maxf(box.size.y, box.size.x * 0.6)
		n.scale = Vector3.ONE * s
		n.position = Vector3(x - box.position.x * s, -box.position.y * s, -box.get_center().z * s)
		x += box.size.x * s + 0.6
		maxh = maxf(maxh, box.size.y * s)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.position = Vector3(x * 0.5, maxh * 0.9 + x * 0.25, x * 0.75 + maxh)
	cam.look_at(Vector3(x * 0.5, maxh * 0.35, 0))
	cam.fov = 45
	cam.current = true
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(out)
	quit()
