extends SceneTree
## Где маяк деревни и начало моста
func _init() -> void:
	VillageLayout.setup()
	Terrain.setup()
	CastleLayout.setup()
	var vc := VillageLayout.CENTER
	print("village beacon: ", Beacon.find_hilltop(Vector3(vc.x, 0, vc.y), 15.0, 22.0), " bridge_start: ", CastleLayout.bridge_start)
	quit()
