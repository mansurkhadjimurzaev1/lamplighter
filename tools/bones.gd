extends SceneTree
func _initialize() -> void:
	for m in ["people/KK_Barbarian", "hero/Rogue_Hooded"]:
		var n: Node = (load("res://assets/models/%s.glb" % m) as PackedScene).instantiate()
		root.add_child(n)
		var sk: Skeleton3D = n.find_children("*", "Skeleton3D", true, false)[0]
		var names := []
		for i in sk.get_bone_count():
			names.append("%d:%s(p%d)" % [i, sk.get_bone_name(i), sk.get_bone_parent(i)])
		print(m, " ", names)
		var ap: AnimationPlayer = n.find_children("*", "AnimationPlayer", true, false)[0]
		var a := ap.get_animation("Idle")
		var sc := 0
		for t in a.get_track_count():
			if a.track_get_type(t) == Animation.TYPE_SCALE_3D:
				sc += 1
		print("scale tracks in Idle: ", sc, " of ", a.get_track_count())
	quit()
