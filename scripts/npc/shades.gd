class_name Shades
extends Node3D
## Управляет Тенями: появление во тьме вдали от героя, повторное появление после рассеивания.

var list: Array[Shade] = []
var _rng := RandomNumberGenerator.new()
var sound: Soundscape
## Тени замка: появляются только внутри стен, когда герой в замке
var castle := false


func build(count: int, castle_mode := false) -> void:
	castle = castle_mode
	name = "CastleShades" if castle else "Shades"
	_rng.seed = 404 if not castle else 505
	var scene: PackedScene = load("res://assets/models/hero/Rogue_Hooded.glb")
	var human: Array[PackedScene] = [load("res://assets/models/people/KK_Knight.glb"), load("res://assets/models/people/KK_Barbarian.glb")]
	for i in count:
		var s := Shade.new()
		add_child(s)
		if castle:
			# похожи на людей: стражники и придворные — выше, плотнее, сильнее
			s.build(human[i % 2], _rng, 1.95, Villager.PROPS + ["Knight_Helmet", "Barbarian_Hat"])
			s.speed_mult = 1.5
			s.toughness = 2.2
		else:
			s.build(scene, _rng)
		s.visible = false
		s.state = Shade.State.GONE
		s.respawn_in = 2.0 + i * 1.5


func _spawn_point(hero: Vector3) -> Variant:
	if castle:
		if CastleLayout.region_factor(hero.x, hero.z) < 0.5:
			return null
		for i in 60:
			var c := CastleLayout.CENTER
			var a := _rng.randf() * TAU
			var d := sqrt(_rng.randf()) * (CastleLayout.WALL_R - 2.0)
			var p := Vector3(c.x + cos(a) * d, 0, c.y + sin(a) * d)
			var dh := Vector2(p.x - hero.x, p.z - hero.z).length()
			if dh < 8.0 or dh > 22.0 or not Hero.can_stand(p.x, p.z):
				continue
			p.y = Terrain.height_at(p.x, p.z)
			return p
		return null
	for i in 60:
		var a := _rng.randf() * TAU
		var d := _rng.randf_range(17.0, 34.0)
		var p := Vector3(hero.x + cos(a) * d, 0, hero.z + sin(a) * d)
		p.y = Terrain.height_at(p.x, p.z)
		if p.y < 0.4 or not Hero.can_stand(p.x, p.z) or CastleLayout.region_factor(p.x, p.z) > 0.0:
			continue
		var dh := Vector2(p.x - hero.x, p.z - hero.z).length()
		if dh < 17.0 or dh > 34.0:
			continue
		if Beacon.restore_at(p) > 0.0 or VillageLayout.in_village(p.x, p.z, 6.0):
			continue
		return p
	return null


## Возвращает true, если какая-то Тень коснулась героя
func tick(dt: float, hero: Vector3, light_r: float, strong: bool, out: bool, colliders: Array[Vector3], active: bool) -> bool:
	var touched := false
	for s in list_all():
		if s.state == Shade.State.GONE:
			if s.respawn_in <= 0.0:
				var p: Variant = _spawn_point(hero)
				if p != null:
					s.appear_at(p)
				else:
					s.respawn_in = 3.0
			else:
				s.respawn_in -= dt
			continue
		if not active:
			continue
		if s.tick(dt, hero, light_r, strong, out, colliders, sound):
			touched = true
	return touched


func list_all() -> Array[Shade]:
	var out: Array[Shade] = []
	for c in get_children():
		if c is Shade:
			out.append(c)
	return out


## После обморока — все Тени рассеиваются и появятся позже, далеко
func reset_all() -> void:
	for s in list_all():
		s.visible = false
		s.state = Shade.State.GONE
		s.respawn_in = _rng.randf_range(6.0, 14.0)
