extends SceneTree
## Самые частые цвета текстуры модели: godot --headless --path . --script res://tools/palette.gd -- KK_Mage ...
func _init() -> void:
	for f in OS.get_cmdline_user_args():
		var n: Node = (load("res://assets/models/people/%s.glb" % f) as PackedScene).instantiate()
		var tex: Texture2D = null
		for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
			var m := mi.mesh.surface_get_material(0)
			if m is StandardMaterial3D and (m as StandardMaterial3D).albedo_texture:
				tex = (m as StandardMaterial3D).albedo_texture
				break
		var img := tex.get_image()
		if img.is_compressed():
			img.decompress()
		var counts := {}
		for y in range(0, img.get_height(), 2):
			for x in range(0, img.get_width(), 2):
				var c := img.get_pixel(x, y)
				var key := "%02x%02x%02x" % [int(c.r * 255) / 8 * 8, int(c.g * 255) / 8 * 8, int(c.b * 255) / 8 * 8]
				counts[key] = counts.get(key, 0) + 1
		var keys := counts.keys().filter(func(k):
			var c := Color("#" + k)
			return c.s > 0.35 and not (c.h < 0.12 or c.h > 0.95))
		keys.sort_custom(func(a, b): return counts[a] > counts[b])
		print(f, " ", keys.slice(0, 14))
		n.free()
	quit()
