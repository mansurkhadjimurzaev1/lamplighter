class_name Pine
extends RefCounted
## Ель, собранная кодом: сужающийся ствол и ярусы веток. Каждая ветка — две
## «карточки» хвои буквой V, слегка провисают к кончику. Хвою рисует shaders/needles.gdshader.
## Размер нормализован: высота 1, основание в (0, 0, 0) — как модели в Vegetation.
## Дальше NEAR метров — упрощённая крона (меньше веток, шире).

const NEAR := 28.0


static func _trunk(segs: int, r0: float, r1: float, h: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 6
	for j in rings:
		var t0 := float(j) / rings
		var t1 := float(j + 1) / rings
		for i in segs:
			var a0 := TAU * i / segs
			var a1 := TAU * (i + 1) / segs
			var p := func(a: float, t: float) -> Vector3:
				var r := lerpf(r0, r1, t)
				return Vector3(cos(a) * r, t * h, sin(a) * r)
			var q := [p.call(a0, t0), p.call(a1, t0), p.call(a1, t1), p.call(a0, t1)]
			var n0 := Vector3(cos(a0), 0.15, sin(a0)).normalized()
			var n1 := Vector3(cos(a1), 0.15, sin(a1)).normalized()
			for k in [[0, n0], [2, n1], [1, n1], [0, n0], [3, n0], [2, n1]]:
				st.set_normal(k[1])
				st.add_vertex(q[k[0]])
	return st.commit()


static func _branches(rng: RandomNumberGenerator, trunk_h: float, whorls := 14, extra := 3, base_count := 6, wide := 1.0) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var y0 := 0.21
	for w in whorls:
		var t := float(w) / (whorls - 1)
		var y := lerpf(y0, 0.96, pow(t, 0.92)) + rng.randf_range(-0.012, 0.012)
		var free := 1.0 - (y - y0) / (1.0 - y0) # 1 внизу, 0 у верхушки
		var length := 0.07 + 0.30 * pow(free, 0.95)
		var count := base_count + int(round(free * extra))
		var rot := rng.randf() * TAU
		for b in count:
			var a := rot + TAU * b / count + rng.randf_range(-0.25, 0.25)
			var dir := Vector3(cos(a), 0, sin(a))
			var side := Vector3(-dir.z, 0, dir.x)
			var lift := lerpf(0.14, 0.0, free) + rng.randf_range(-0.05, 0.05) # нижние ветки смотрят вниз
			var droop := 0.05 * length / 0.37 + 0.02
			var L := length * rng.randf_range(0.85, 1.12)
			var width := (L * 0.72 + 0.03) * wide
			var base := Vector3(0, y, 0) + dir * 0.008
			# две карточки буквой V (поднятые края) — ветка выглядит объёмной с любого ракурса
			for tiltk: float in [-1.0, 1.0]:
				var tilt: float = tiltk * 0.55
				var segs := 3
				var prev_l := Vector3.ZERO
				var prev_r := Vector3.ZERO
				for sgi in segs + 1:
					var s := float(sgi) / segs
					var c := base + dir * L * s + Vector3(0, lift * L * s - droop * s * s, 0)
					var half := width * 0.5
					var off := (side * cos(tilt) + Vector3.UP * sin(tilt) * 0.6) * half
					# каждая карточка — половина ветки: от веточки до одного края
					var l: Vector3 = c + off if tiltk > 0 else c
					var r: Vector3 = c if tiltk > 0 else c - off
					if sgi > 0:
						var nrm := Vector3.UP
						var uv_l0 := Vector2(float(sgi - 1) / segs, 0.0 if tiltk > 0 else 0.5)
						var uv_r0 := Vector2(float(sgi - 1) / segs, 0.5 if tiltk > 0 else 1.0)
						var uv_l1 := Vector2(s, uv_l0.y)
						var uv_r1 := Vector2(s, uv_r0.y)
						for v in [[prev_l, uv_l0], [l, uv_l1], [r, uv_r1], [prev_l, uv_l0], [r, uv_r1], [prev_r, uv_r0]]:
							st.set_normal(nrm)
							st.set_uv(v[1])
							st.add_vertex(v[0])
					prev_l = l
					prev_r = r
	# верхушка — маленькая вертикальная «свечка»
	for k in 3:
		var a := TAU * k / 3.0
		var d := Vector3(cos(a), 0, sin(a)) * 0.035
		var top := Vector3(0, 1.0, 0)
		var bot := Vector3(0, 0.9, 0)
		for v in [[bot - d, Vector2(0.0, 0.0)], [top, Vector2(1.0, 0.5)], [bot + d, Vector2(0.0, 1.0)]]:
			st.set_normal(Vector3.UP)
			st.set_uv(v[1])
			st.add_vertex(v[0])
	st.index()
	return st.commit()


## Тёмный объём внутри кроны: прячет просветы между ветками
static func _core() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 8
	var bot := 0.24
	var top := 0.97
	for i in segs:
		var a0 := TAU * i / segs
		var a1 := TAU * (i + 1) / segs
		var r := 0.15
		var p0 := Vector3(cos(a0) * r, bot, sin(a0) * r)
		var p1 := Vector3(cos(a1) * r, bot, sin(a1) * r)
		var t := Vector3(0, top, 0)
		var n0 := Vector3(cos(a0), 0.5, sin(a0)).normalized()
		var n1 := Vector3(cos(a1), 0.5, sin(a1)).normalized()
		for v in [[p0, n0], [t, Vector3.UP], [p1, n1]]:
			st.set_normal(v[1])
			st.add_vertex(v[0])
	return st.commit()


## {parts: [{mesh, xf}], width} — как Vegetation._load_model
static func make(seed_value: int, rock_tex: Texture2D) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var trunk := _trunk(7, 0.022, 0.003, 0.97)
	var bark := ShaderMaterial.new()
	bark.shader = preload("res://shaders/foliage.gdshader")
	bark.set_shader_parameter("albedo", Color(0.2, 0.12, 0.07))
	bark.set_shader_parameter("kind", 2)
	bark.set_shader_parameter("rock_tex", rock_tex)
	trunk.surface_set_material(0, bark)
	var br := _branches(rng, 0.97)
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = seed_value + 5
	var br_far := _branches(rng2, 0.97, 9, 2, 4, 1.35)
	var needles := ShaderMaterial.new()
	needles.shader = preload("res://shaders/needles.gdshader")
	needles.set_shader_parameter("albedo", Color(0.07, 0.16, 0.09).lerp(Color(0.09, 0.15, 0.07), rng.randf()))
	br.surface_set_material(0, needles)
	br_far.surface_set_material(0, needles)
	var core := _core()
	var cm := ShaderMaterial.new()
	cm.shader = preload("res://shaders/foliage.gdshader")
	cm.set_shader_parameter("albedo", Color(0.03, 0.07, 0.04))
	cm.set_shader_parameter("kind", 0)
	cm.set_shader_parameter("rock_tex", rock_tex)
	core.surface_set_material(0, cm)
	if Quality.level == "low":
		return {parts = [{mesh = trunk, xf = Transform3D.IDENTITY}, {mesh = br_far, xf = Transform3D.IDENTITY, shadow = false}, {mesh = core, xf = Transform3D.IDENTITY}], width = 0.6}
	return {parts = [{mesh = trunk, xf = Transform3D.IDENTITY}, {mesh = br, xf = Transform3D.IDENTITY, shadow = false, range = Vector2(0.0, NEAR)}, {mesh = br_far, xf = Transform3D.IDENTITY, shadow = false, range = Vector2(NEAR, 0.0)}, {mesh = core, xf = Transform3D.IDENTITY}], width = 0.6}
