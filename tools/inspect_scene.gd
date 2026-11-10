extends SceneTree
## Печать узлов, анимаций и размеров: godot --headless --path . --script res://tools/inspect_scene.gd -- res://path
func _init() -> void:
	var n: Node3D = (load(OS.get_cmdline_user_args()[0]) as PackedScene).instantiate()
	get_root().add_child(n)
	for c in n.find_children("*", "", true, false):
		var extra := ""
		if c is MeshInstance3D:
			extra = " aabb=" + str((c as MeshInstance3D).global_transform * (c as MeshInstance3D).get_aabb())
		print(c.get_class(), " ", c.name, extra)
	for ap: AnimationPlayer in n.find_children("*", "AnimationPlayer", true, false):
		print("anims: ", ap.get_animation_list())
	quit()
