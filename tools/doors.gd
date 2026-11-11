extends SceneTree
## Печатает материалы моделей домов и центры их поверхностей (ищем дверь).
func _initialize() -> void:
	for m in ["House_1", "House_2", "House_3", "House_4", "Blacksmith"]:
		var sc: PackedScene = load("res://assets/models/village/%s.glb" % m)
		var n: Node3D = sc.instantiate()
		root.add_child(n)
		var total := AABB()
		var first := true
		var mats := {}
		for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
			var t := mi.global_transform
			var ab := t * mi.get_aabb()
			total = ab if first else total.merge(ab)
			first = false
			var mesh := mi.mesh
			for s in mesh.get_surface_count():
				var mat := mesh.surface_get_material(s)
				var nm: String = mat.resource_name if mat else "?"
				var arr := mesh.surface_get_arrays(s)
				var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
				var c := Vector3.ZERO
				var lo := Vector3(INF, INF, INF)
				var hi := -lo
				for v in verts:
					var w := t * v
					c += w
					lo = lo.min(w); hi = hi.max(w)
				c /= maxf(verts.size(), 1)
				mats[nm + "/" + mi.name] = "c=%s lo=%s hi=%s" % [c, lo, hi]
		print(m, " total=", total)
		for k in mats:
			print("   ", k, " ", mats[k])
		n.queue_free()
	quit()
