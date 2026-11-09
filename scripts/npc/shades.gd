class_name Shades
extends Node3D
## Управляет Тенями: появление во тьме вдали от героя, повторное появление после рассеивания.

var list: Array[Shade] = []
var _rng := RandomNumberGenerator.new()
var sound: Soundscape


func build(count: int) -> void:
	name = "Shades"
	_rng.seed = 404
	var scene: PackedScene = load("res://assets/models/hero/Rogue_Hooded.glb")
	for i in count:
		var s := Shade.new()
		add_child(s)
		s.build(scene, _rng)
		s.visible = false
		s.state = Shade.State.GONE
		s.respawn_in = 2.0 + i * 1.5


func _spawn_point(hero: Vector3) -> Variant:
	for i in 60:
		var a := _rng.randf() * TAU
		var d := sqrt(_rng.randf()) * (Terrain.ISLAND_RADIUS - 3.0)
		var p := Vector3(cos(a) * d, 0, sin(a) * d)
		p.y = Terrain.height_at(p.x, p.z)
		if p.y < 0.4:
			continue
		var dh := Vector2(p.x - hero.x, p.z - hero.z).length()
		if dh < 17.0 or dh > 34.0:
			continue
		if Beacon.restore_at(p) > 0.0:
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
