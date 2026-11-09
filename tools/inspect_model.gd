extends SceneTree
## Печатает материалы модели: godot --headless --path . --script res://tools/inspect_model.gd -- PineTree_1

func _init() -> void:
	for f in OS.get_cmdline_user_args():
		var root: Node = (load("res://assets/models/nature/%s.glb" % f) as PackedScene).instantiate()
		for mi in root.find_children("*", "MeshInstance3D", true, false):
			for i in mi.mesh.get_surface_count():
				var m = mi.mesh.surface_get_material(i)
				print(f, " surf", i, " ", m.resource_name if m else "null", " ", (m as BaseMaterial3D).albedo_color if m is BaseMaterial3D else "-", " vcol=", (m as BaseMaterial3D).vertex_color_use_as_albedo if m is BaseMaterial3D else "-")
		root.free()
	quit()
