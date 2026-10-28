class_name TerrainImage
extends RefCounted
# A shaded top-down picture of the ground, baked once from DesertTerrain.height_at
# and cached per terrain and area. Pixel (0, 0) is the area's north-west corner.
# Building footprints, when given, are baked in dark over the ground.

const BUILDING := Color(0.12, 0.1, 0.1, 0.85)

static var _cache := {}

## `area` is world XZ (position is the min x, min z corner).
static func bake(terrain: DesertTerrain, area: Rect2, px := 128, footprints: Array[Rect2] = []) -> ImageTexture:
	var key := [terrain.params(), area, px, footprints]
	if _cache.has(key):
		return _cache[key]
	var img := Image.create(px, px, false, Image.FORMAT_RGBA8)
	var low := Color(0.32, 0.2, 0.12, 0.55)
	var high := Color(0.95, 0.75, 0.5, 0.75)
	for j in px:
		for i in px:
			var x := area.position.x + (i + 0.5) / px * area.size.x
			var z := area.position.y + (j + 0.5) / px * area.size.y
			img.set_pixel(i, j, low.lerp(high, clampf(terrain.height_at(x, z) / 60.0, 0.0, 1.0)))
	var cell := area.size / px
	for r in footprints:
		var from := ((r.position - area.position) / cell).floor()
		var to := ((r.end - area.position) / cell).ceil()
		for j in range(maxi(int(from.y), 0), mini(int(to.y), px)):
			for i in range(maxi(int(from.x), 0), mini(int(to.x), px)):
				img.set_pixel(i, j, BUILDING)
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex
