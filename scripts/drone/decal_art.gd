class_name DecalArt
extends RefCounted
# Story 27.2: the hull decals and race numbers, drawn here in code: no image
# files, so nothing to license (data/LICENSES.md says so). Original motifs from
# Rajasthani block print and architecture and the epics: block print, a
# jharokha's lattice, a chakra, a lotus, a peacock's feather, the sun, racing
# stripes, and the pilot's team emblem in team colours.
# A decal is a white mask the material tints with the livery's decal colour;
# the team emblem alone carries its own colours. Each image is drawn once and
# shared by every drone that wears it.

const IDS: Array[StringName] = [&"block_print", &"jharokha", &"chakra", &"lotus", &"peacock",
	&"sun", &"stripes", &"team"]
## Pixels a side. Drawn with 2x2 samples a pixel for soft edges.
const SIZE := 128
## The emblem's colours with no team: the home game's (Team's own default).
const HOME_COLORS: Array[Color] = [Color(0.35, 0.8, 0.95), Color(0.9, 0.95, 1.0)]

static var _textures := {}

## The decal's texture, drawn on first use; null for an unknown id. The team
## emblem is drawn in `colors` (primary, secondary).
static func texture(id: StringName, colors: Array[Color] = HOME_COLORS) -> Texture2D:
	if not id in IDS:
		return null
	var key := String(id) if id != &"team" else "team:%s:%s" % [colors[0].to_html(), colors[1].to_html()]
	if not _textures.has(key):
		_textures[key] = ImageTexture.create_from_image(image(id, colors))
	return _textures[key]

## The race number's texture, 1 to 99, in seven-segment digits.
static func number_texture(n: int) -> Texture2D:
	var key := "number:%d" % n
	if not _textures.has(key):
		_textures[key] = ImageTexture.create_from_image(number_image(n))
	return _textures[key]

static func image(id: StringName, colors: Array[Color] = HOME_COLORS) -> Image:
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var tint: Array[Color] = [Color.WHITE, Color.WHITE]
	if id == &"team":
		tint = colors
	for py in SIZE:
		for px in SIZE:
			var sum := Color(0, 0, 0, 0)
			for s in 4:
				# Pixel to [-1, 1], y up: the top of the image is the drone's nose.
				var p := Vector2((px + 0.25 + 0.5 * (s % 2)) / SIZE * 2.0 - 1.0,
					1.0 - (py + 0.25 + 0.5 * (s >> 1)) / SIZE * 2.0)
				var ink := _ink(id, p)
				if ink > 0:
					sum += tint[ink - 1]
			if sum.a > 0.0:
				img.set_pixel(px, py, Color(sum.r / sum.a, sum.g / sum.a, sum.b / sum.a, sum.a / 4.0))
	img.generate_mipmaps()
	return img

## Which ink covers `p`: 0 none, 1 the main colour, 2 the second (team only).
static func _ink(id: StringName, p: Vector2) -> int:
	match id:
		&"block_print": return _block_print(p)
		&"jharokha": return _jharokha(p)
		&"chakra": return _chakra(p)
		&"lotus": return _lotus(p)
		&"peacock": return _peacock(p)
		&"sun": return _sun(p)
		&"stripes": return _stripes(p)
		&"team": return _team(p)
	return 0

# A border and a 3x3 block of butis: four-petal flowers, with small diamonds
# between, as a carved block stamps them.
static func _block_print(p: Vector2) -> int:
	var edge := maxf(absf(p.x), absf(p.y))
	if edge > 0.97:
		return 0
	if edge > 0.87:
		return 1
	if edge > 0.82:
		return 0
	var cell := 1.64 / 3.0
	var c := ((p + Vector2(0.82, 0.82)) / cell).floor()
	var q := (p + Vector2(0.82, 0.82) - (c + Vector2(0.5, 0.5)) * cell) / (cell * 0.5)
	if int(c.x + c.y) % 2 == 0:
		for d in [Vector2(0.48, 0), Vector2(-0.48, 0), Vector2(0, 0.48), Vector2(0, -0.48)]:
			if q.distance_to(d) < 0.3:
				return 1
		return 1 if q.length() < 0.16 else 0
	return 1 if absf(q.x) + absf(q.y) < 0.42 and absf(q.x) + absf(q.y) > 0.22 else 0

# A pointed jharokha window: the arch's frame, a stone lattice inside, a sill.
static func _jharokha(p: Vector2) -> int:
	if p.y < -0.84 and p.y > -0.98 and absf(p.x) < 0.78:
		return 1
	if not _arch(p, 0.0):
		return 0
	if not _arch(p, 0.11):
		return 1
	var a := fposmod(p.x + p.y, 0.3)
	var b := fposmod(p.x - p.y, 0.3)
	return 1 if a < 0.055 or b < 0.055 else 0

static func _arch(p: Vector2, inset: float) -> bool:
	var half := 0.62 - inset
	if p.y < -0.84 + inset or absf(p.x) > half:
		return false
	if p.y <= 0.1:
		return true
	var r := 0.92 - inset
	return p.distance_to(Vector2(-0.3, 0.1)) < r and p.distance_to(Vector2(0.3, 0.1)) < r

# A wheel: rim, hub and twelve spokes.
static func _chakra(p: Vector2) -> int:
	var r := p.length()
	if r > 0.95:
		return 0
	if r > 0.78 or r < 0.17:
		return 1
	if r < 0.27:
		return 0
	var step := TAU / 12.0
	var a := atan2(p.y, p.x)
	var off := a - roundf(a / step) * step
	return 1 if absf(r * sin(off)) < 0.045 else 0

# A lotus in outline: five pointed petals rising from the water line.
static func _lotus(p: Vector2) -> int:
	if p.y < -0.66 and p.y > -0.78 and absf(p.x) < 0.8:
		return 1
	var base := Vector2(0, -0.6)
	for petal in [[0.0, 1.45], [0.6, 1.15], [-0.6, 1.15], [1.15, 0.85], [-1.15, 0.85]]:
		var d := Vector2(sin(petal[0]), cos(petal[0]))
		var s := (p - base).dot(d)
		var t := absf((p - base).dot(Vector2(d.y, -d.x)))
		var length: float = petal[1]
		if s <= 0.0 or s >= length:
			continue
		var w := 0.3 * sin(PI * s / length)
		if t < w and (t > w - 0.075 or s < 0.06 or s > length - 0.06):
			return 1
	return 0

# A peacock feather's eye on its shaft, with barbs below.
static func _peacock(p: Vector2) -> int:
	var e := Vector2(p.x / 0.44, (p.y - 0.28) / 0.6).length()
	if e < 1.0:
		return 1 if e > 0.84 or (e > 0.58 and e < 0.68) or e < 0.4 else 0
	if p.y > -0.33:
		return 0
	if absf(p.x) < 0.035 and p.y > -0.98:
		return 1
	var spread := 0.42 * (p.y + 1.0) / 0.67
	if absf(p.x) < spread and fposmod(p.y - absf(p.x) * 0.9, 0.17) < 0.045:
		return 1
	return 0

# The sun: a disc, a ring, and twelve tapering rays.
static func _sun(p: Vector2) -> int:
	var r := p.length()
	if r < 0.38 or (r > 0.46 and r < 0.52):
		return 1
	if r < 0.58 or r > 0.97:
		return 0
	var step := TAU / 12.0
	var a := atan2(p.y, p.x)
	var off := absf(a - roundf(a / step) * step)
	return 1 if off < 0.22 * (0.97 - r) / 0.39 else 0

# Racing stripes nose to tail: a wide one down the middle and a thin pair
# beside, their ends cut on a slant toward the nose.
static func _stripes(p: Vector2) -> int:
	var slant := absf(p.x) * 0.5
	if p.y > 0.94 - slant or p.y < -0.94 - slant:
		return 0
	return 1 if absf(p.x) < 0.15 or (absf(p.x) > 0.3 and absf(p.x) < 0.4) else 0

# The team emblem: a shield in the team's first colour, with a border and a
# chevron in its second.
static func _team(p: Vector2) -> int:
	if not _shield(p, 0.0):
		return 0
	if not _shield(p, 0.1):
		return 2
	return 2 if absf(p.y - (0.2 - absf(p.x) * 0.75)) < 0.13 else 1

static func _shield(p: Vector2, inset: float) -> bool:
	var half := 0.74 - inset
	if absf(p.x) > half or p.y > 0.86 - inset:
		return false
	if p.y >= -0.1:
		return true
	return Vector2(p.x / half, (p.y + 0.1) / (0.88 - inset)).length() < 1.0

# Segments a to g of each digit, as rectangles in a 1 x 2 cell.
const SEGMENTS := [
	Rect2(0.12, 0.0, 0.76, 0.24), Rect2(0.76, 0.12, 0.24, 0.84), Rect2(0.76, 1.04, 0.24, 0.84),
	Rect2(0.12, 1.76, 0.76, 0.24), Rect2(0.0, 1.04, 0.24, 0.84), Rect2(0.0, 0.12, 0.24, 0.84),
	Rect2(0.12, 0.88, 0.76, 0.24),
]
const DIGITS := ["abcdef", "bc", "abdeg", "abcdg", "bcfg", "acdfg", "acdefg", "abc", "abcdefg", "abcdfg"]

## The number in white seven-segment digits on clear, twice as wide as tall.
static func number_image(n: int) -> Image:
	var img := Image.create(SIZE, SIZE >> 1, false, Image.FORMAT_RGBA8)
	var text := str(clampi(n, 0, 99))
	var cell := 27.0 # digit width, px; a digit is twice as tall
	var gap := 9.0
	var width := text.length() * cell + (text.length() - 1) * gap
	var left := (SIZE - width) / 2.0
	var top := (SIZE * 0.5 - cell * 2.0) / 2.0
	for i in text.length():
		var lit: String = DIGITS[int(text[i])]
		for s in 7:
			if not "abcdefg"[s] in lit:
				continue
			var r: Rect2 = SEGMENTS[s]
			var at := Vector2(left + i * (cell + gap), top) + r.position * cell
			img.fill_rect(Rect2i(Vector2i(at.round()), Vector2i((r.size * cell).round())), Color.WHITE)
	img.generate_mipmaps()
	return img
