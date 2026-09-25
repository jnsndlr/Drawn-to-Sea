extends RefCounted

const SIZE := Vector2i(512, 384)
var image: Image
var texture: ImageTexture

func _init() -> void:
	image = Image.create(SIZE.x, SIZE.y, false, Image.FORMAT_RGF)
	for y in SIZE.y:
		for x in SIZE.x:
			var p := (Vector2(x + 0.5, y + 0.5) / Vector2(SIZE) - Vector2(0.5, 0.5)) * Vector2(18, 12)
			var a := ((p - Vector2(-3.8, -0.8)) * Vector2(0.65, 1)).length() - 1.65
			var b := ((p - Vector2(4.1, 2)) * Vector2(1, 0.8)).length() - 1.1
			var island := minf(a, b) + (noise_at(p * 2) - 0.5) * 0.5 + (noise_at(p * 4) - 0.5) * 0.15
			var rock := ((p - Vector2(-0.6, -0.7)) * Vector2(1, 1.2)).length() - 0.32
			rock = minf(rock, ((p - Vector2(-0.25, 0.15)) * Vector2(1.3, 0.85)).length() - 0.24)
			rock = minf(rock, ((p - Vector2(-0.8, 0.65)) * Vector2(1.1, 1)).length() - 0.16)
			rock = minf(rock, ((p - Vector2(2.9, 0.2)) * Vector2(0.8, 1.2)).length() - 0.22)
			rock += (noise_at(p * 11) - 0.5) * 0.06
			image.set_pixel(x, y, Color(island, rock, 0, 1))
	texture = ImageTexture.create_from_image(image)

func hash_at(p: Vector2) -> float:
	return fposmod(sin(p.dot(Vector2(127.1, 311.7))) * 43758.5453, 1.0)

func noise_at(p: Vector2) -> float:
	var cell := p.floor()
	var f := p - cell
	f = f * f * (Vector2(3, 3) - 2 * f)
	return lerpf(lerpf(hash_at(cell), hash_at(cell + Vector2.RIGHT), f.x), lerpf(hash_at(cell + Vector2.DOWN), hash_at(cell + Vector2.ONE), f.x), f.y)

func distance_at(p: Vector2) -> float:
	var texel := (p / Vector2(18, 12) + Vector2(0.5, 0.5)) * Vector2(SIZE) - Vector2(0.5, 0.5)
	var origin := texel.floor()
	var f := texel - origin
	var a := image.get_pixel(clampi(int(origin.x), 0, SIZE.x - 1), clampi(int(origin.y), 0, SIZE.y - 1))
	var b := image.get_pixel(clampi(int(origin.x) + 1, 0, SIZE.x - 1), clampi(int(origin.y), 0, SIZE.y - 1))
	var c := image.get_pixel(clampi(int(origin.x), 0, SIZE.x - 1), clampi(int(origin.y) + 1, 0, SIZE.y - 1))
	var d := image.get_pixel(clampi(int(origin.x) + 1, 0, SIZE.x - 1), clampi(int(origin.y) + 1, 0, SIZE.y - 1))
	var value := a.lerp(b, f.x).lerp(c.lerp(d, f.x), f.y)
	return minf(value.r, value.g)

func navigable(p: Vector2, radius: float = 0.40) -> bool:
	if absf(p.x) > 8.55 or absf(p.y) > 5.55:
		return false
	# Sample the hull perimeter as well as its center; distance is not an exact SDF.
	if distance_at(p) < 0.04:
		return false
	for i in 12:
		if distance_at(p + Vector2.from_angle(i * TAU / 12.0) * radius) < 0.04:
			return false
	return true
