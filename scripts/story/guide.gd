class_name Guide
extends RefCounted
## «Что сейчас»: одна строка с главной целью и точка, куда она ведёт (для метки на экране
## и на карте). Цель выводится из прогресса — флагов, заданий и зажжённых маяков.
## В глубине леса точной метки нет: путь там показывают только светлячки.


static func _npc(m: Node, id: String) -> Variant:
	for v in m.npcs:
		if v.id == id:
			return v.global_position
	return null


static func _g(p: Vector2) -> Vector3:
	return Vector3(p.x, Terrain.height_at(p.x, p.y), p.y)


## {text: String, pos: Vector3 или null}
static func goal(m: Node) -> Dictionary:
	var f: Dictionary = GameState.flags
	var b: Array = m.beacons
	if not f.get("has_lantern", false):
		return {text = Tr.t("Поговори со старейшиной Ольдрихом у колодца"), pos = _npc(m, "oldrich")}
	if not b[0].lit:
		return {text = Tr.t("Зажги маяк на холме над деревней"), pos = b[0].position}
	if not b[1].lit:
		if m._forest_f > 0.45:
			return {text = Tr.t("Ищи маяк в глубине леса. Иди за светлячками, которые летят, а не кружат"), pos = null}
		return {text = Tr.t("Иди на север, в Шепчущий лес — там второй маяк"), pos = _g(ForestLayout.node("E"))}
	if not b[2].lit:
		if GameState.quest("swamp_beacon") == "" and m._swamp_f < 0.4:
			return {text = Tr.t("Иди на восток, в Топь — по старым мосткам"), pos = _g(SwampLayout.WALK[0])}
		if not f.get("ferry_fixed", false):
			var q := GameState.quest("ferry_fix")
			if q != "active":
				return {text = Tr.t("Найди паромщика Корнея — его лодка у островка с хижиной"), pos = m.ferryman.global_position if m.ferryman else null}
			var it: Dictionary = GameState.items
			if not it.has("rope"):
				return {text = Tr.t("Найди верёвку на старых мостках"), pos = _g(SwampLayout.ROPE)}
			if not it.has("resin"):
				return {text = Tr.t("Добудь смолу с мёртвого дерева. Осторожно: рядом трясина"), pos = _g(SwampLayout.RESIN)}
			return {text = Tr.t("Отнеси верёвку и смолу Корнею"), pos = m.ferryman.global_position if m.ferryman else null}
		var hp: Vector3 = m.hero.global_position
		if Vector2(hp.x, hp.z).distance_to(SwampLayout.BEACON) > SwampLayout.BEACON_R + 2.0:
			var pa := SwampLayout.pier_a()
			return {text = Tr.t("Переправься на лодке Корнея к островку маяка"), pos = _g(pa)}
		return {text = Tr.t("Зажги маяк над топью"), pos = b[2].position}
	if not b[3].lit:
		if m._mtn_f < 0.3:
			return {text = Tr.t("Иди на запад, в горы — к каменной лестнице"), pos = _g(MountainLayout.STAIRS[0])}
		return {text = Tr.t("Поднимайся к маяку на утёсе. Грейся у жаровен — холод гасит фонарь"), pos = b[3].position}
	if GameState.quest("castle") != "done":
		return {text = Tr.t("Решётка на юге поднялась. Иди в руины замка, в тронный зал"), pos = _npc(m, "king")}
	if not f.get("castle_final_ready", false) and not f.get("ending_bad", false):
		return {text = Tr.t("Поговори с королём"), pos = _npc(m, "king")}
	if not b[4].lit:
		return {text = Tr.t("Зажги последний маяк во дворе замка"), pos = b[4].position}
	return {text = "", pos = null}
