class_name MapData
extends RefCounted
## Данные карты: нарисованный «от руки» мир (пергамент, чернила) и туман неизведанного.

const FOG_STEP := 2.0 # метров на клетку тумана
const REVEAL := 14.0 # сколько видно вокруг героя (м)

static var base_tex: ImageTexture
static var fog_img: Image
static var fog_tex: ImageTexture
static var _fog_dirty := false
static var _last_reveal := Vector2(INF, INF)


static func fog_res() -> Vector2i:
	var size := Terrain.MAX - Terrain.MIN
	return Vector2i(int(ceil(size.x / FOG_STEP)) + 1, int(ceil(size.y / FOG_STEP)) + 1)


## Рисуем карту по данным рельефа: вода, берег, линии высот, лес, дороги, постройки, деревья
static func build(obstacles: Array[Vector3]) -> void:
	var h: Image = Terrain.height_img
	var info: Image = Terrain.info_img
	var w := h.get_width()
	var hh := h.get_height()
	var img := Image.create(w, hh, false, Image.FORMAT_RGBA8)
	var paper := Color(0.87, 0.79, 0.61)
	var ink := Color(0.27, 0.18, 0.1)
	var water := Color(0.6, 0.66, 0.66)
	for j in hh:
		for i in w:
			var e := h.get_pixel(i, j).r
			var inf := info.get_pixel(i, j)
			var noise := _hash(i, j)
			var c := paper * (0.95 + 0.05 * noise)
			if e < 0.0:
				# вода: голубоватая размывка и горизонтальная штриховка
				c = water.lerp(paper, clampf(1.0 + e / 2.5, 0.0, 1.0) * 0.5)
				if j % 4 == 0 and e < -0.6:
					c = c.lerp(ink, 0.12)
			else:
				# линии высот каждые 1.5 м
				var el := h.get_pixel(mini(i + 1, w - 1), j).r
				var ed := h.get_pixel(i, mini(j + 1, hh - 1)).r
				if floorf(e / 1.5) != floorf(el / 1.5) or floorf(e / 1.5) != floorf(ed / 1.5):
					c = c.lerp(ink, 0.18)
				# лес: зеленоватая размывка и крап
				if inf.b > 0.05:
					c = c.lerp(Color(0.6, 0.66, 0.48), inf.b * 0.7)
					if noise > 0.82:
						c = c.lerp(Color(0.25, 0.32, 0.18), inf.b * 0.6)
				# дороги и брусчатка
				if inf.g > 0.4:
					c = c.lerp(Color(0.55, 0.4, 0.25), (inf.g - 0.4) * 1.4)
				if inf.r > 0.4:
					c = c.lerp(Color(0.48, 0.42, 0.36), (inf.r - 0.4) * 1.5)
			# мосты и мостки над водой
			if e < 0.0 and inf.g > 0.7:
				c = c.lerp(Color(0.5, 0.42, 0.32), 0.8)
			# береговая линия
			if absf(e) < 0.12:
				c = c.lerp(ink, 0.7)
			img.set_pixel(i, j, c)
	# препятствия: крупные — постройки (тёмные пятна), мелкие — деревья и камни (точки)
	for o in obstacles:
		var p := (Vector2(o.x, o.y) - Terrain.MIN) / Terrain.STEP
		var r := maxf(o.z / Terrain.STEP, 0.8)
		var col := Color(0.3, 0.2, 0.12) if o.z > 0.9 else Color(0.28, 0.34, 0.2)
		_disc(img, p, r * (1.0 if o.z > 0.9 else 0.8), col, 0.75 if o.z > 0.9 else 0.55)
	base_tex = ImageTexture.create_from_image(img)

	var fr := fog_res()
	if fog_img == null or fog_img.get_width() != fr.x:
		fog_img = Image.create(fr.x, fr.y, false, Image.FORMAT_L8)
	fog_tex = ImageTexture.create_from_image(fog_img)


static func _hash(i: int, j: int) -> float:
	var x := sin(i * 12.9898 + j * 78.233) * 43758.5453
	return x - floorf(x)


static func _disc(img: Image, c: Vector2, r: float, col: Color, a: float) -> void:
	for y in range(int(c.y - r - 1), int(c.y + r + 2)):
		for x in range(int(c.x - r - 1), int(c.x + r + 2)):
			if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
				continue
			var d := Vector2(x, y).distance_to(c)
			if d <= r:
				img.set_pixel(x, y, img.get_pixel(x, y).lerp(col, a * clampf(r - d + 0.5, 0.0, 1.0)))


## Открыть место на карте (вокруг героя или ожившую область)
static func reveal(world: Vector2, radius := REVEAL) -> void:
	if fog_img == null:
		return
	var fr := fog_res()
	var c := (world - Terrain.MIN) / FOG_STEP
	var rr := radius / FOG_STEP
	for y in range(maxi(0, int(c.y - rr - 1)), mini(fr.y, int(c.y + rr + 2))):
		for x in range(maxi(0, int(c.x - rr - 1)), mini(fr.x, int(c.x + rr + 2))):
			var d := Vector2(x, y).distance_to(c)
			var v := clampf((rr - d) / 2.0, 0.0, 1.0) # мягкий край
			var old := fog_img.get_pixel(x, y).r
			if v > old:
				fog_img.set_pixel(x, y, Color(v, v, v))
				_fog_dirty = true


## Каждый кадр: открываем вокруг героя (не чаще, чем раз в метр пути)
static func update(hero: Vector2) -> void:
	if hero.distance_to(_last_reveal) > 1.0:
		_last_reveal = hero
		reveal(hero)
	if _fog_dirty:
		_fog_dirty = false
		fog_tex.update(fog_img)


static func explored(world: Vector2) -> bool:
	if fog_img == null:
		return false
	var p := Vector2i(((world - Terrain.MIN) / FOG_STEP).round())
	if p.x < 0 or p.y < 0 or p.x >= fog_img.get_width() or p.y >= fog_img.get_height():
		return false
	return fog_img.get_pixel(p.x, p.y).r > 0.3


## Сохранение исследованного
static func to_string_data() -> String:
	return Marshalls.raw_to_base64(fog_img.get_data()) if fog_img else ""


static func from_string_data(s: String) -> void:
	if s == "" or fog_img == null:
		return
	var data := Marshalls.base64_to_raw(s)
	if data.size() == fog_img.get_data().size():
		fog_img = Image.create_from_data(fog_img.get_width(), fog_img.get_height(), false, Image.FORMAT_L8, data)
		fog_tex.update(fog_img)


static func clear() -> void:
	base_tex = null
	fog_tex = null
	fog_img = null
	_last_reveal = Vector2(INF, INF)
