class_name SurfaceSet
extends Resource
# One CC0 surface from the material library in data/materials/: a colour map and
# a packed normal-roughness map, with the real-world size one repeat covers so
# world-space UVs never stretch. Sources are listed in data/LICENSES.md.

const DIR := "res://data/materials/"

## Concrete, brick, cladding, glass, paving, asphalt, kerb, sand, rock, painted_metal.
@export var id: StringName
## sRGB colour. Null where the surface has no colour of its own (glass).
@export var albedo: Texture2D
## R and G hold the tangent-space normal's X and Y (OpenGL, +Y up; Z is rebuilt,
## as Godot's NORMAL_MAP does); B holds linear roughness.
@export var normal_rough: Texture2D
## Metres one repeat covers along U and V.
@export var tile_size := Vector2.ONE
@export_range(0.0, 1.0) var metallic := 0.0

## The set saved as data/materials/<id>.tres, or null.
static func named(set_id: StringName) -> SurfaceSet:
	var path := DIR + String(set_id) + ".tres"
	return load(path) as SurfaceSet if ResourceLoader.exists(path) else null

## Every set in the library, by id.
static func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for f in ResourceLoader.list_directory(DIR):
		if f.get_extension() == "tres":
			out.append(StringName(f.get_basename()))
	return out
