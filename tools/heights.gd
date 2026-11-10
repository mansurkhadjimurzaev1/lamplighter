extends SceneTree
## Высоты вдоль линии: godot --headless --path . --script res://tools/heights.gd -- x0 z0 x1 z1 шаг
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	VillageLayout.setup()
	Terrain.setup()
	var p0 := Vector2(float(a[0]), float(a[1]))
	var p1 := Vector2(float(a[2]), float(a[3]))
	var n := int(p0.distance_to(p1) / float(a[4]))
	for i in n + 1:
		var p := p0.lerp(p1, float(i) / n)
		print("%.1f, %.1f  h=%.2f  swamp=%.2f  walk=%s" % [p.x, p.y, Terrain.height_at(p.x, p.y), SwampLayout.mask(p.x, p.y), Hero.can_stand(p.x, p.y)])
	quit()
