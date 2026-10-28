extends RefCounted
# Story 15.2: material library. Ten CC0 surface sets that load and name real
# textures, every art file licensed CC0 with a URL, and the epic's 25 MB budget.

const LICENSES := "res://data/LICENSES.md"
const SETS: Array[StringName] = [&"concrete", &"brick", &"cladding", &"glass", &"paving",
	&"asphalt", &"kerb", &"sand", &"rock", &"painted_metal"]
const BUDGET := 25 * 1024 * 1024
const ART := ["jpg", "jpeg", "png", "gltf", "glb", "bin"]

func test_library_has_every_set() -> bool:
	var ids := SurfaceSet.ids()
	return SETS.all(func(s): return s in ids)

func test_every_set_loads_and_names_existing_textures() -> bool:
	var ok := true
	for id in SurfaceSet.ids():
		var s := SurfaceSet.named(id)
		var good: bool = s != null and s.id == id and s.tile_size.x > 0.0 and s.tile_size.y > 0.0 \
			and _real(s.normal_rough) and (_real(s.albedo) or (s.albedo == null and id == &"glass"))
		if not good:
			print("        bad set: %s" % id)
			ok = false
	return ok

func test_textures_import_compressed_with_mipmaps() -> bool:
	var ok := true
	for f in _files("res://data/materials"):
		if not f.get_extension() in ART:
			continue
		var cfg := ConfigFile.new()
		var good: bool = cfg.load(f + ".import") == OK and cfg.get_value("params", "compress/mode") == 2 \
			and cfg.get_value("params", "mipmaps/generate") == true \
			and (not f.ends_with("_nr.jpg") or cfg.get_value("params", "compress/normal_map") == 2)
		if not good:
			print("        bad import: %s" % f)
			ok = false
	return ok

func test_every_art_file_is_cc0_with_url() -> bool:
	var listed := {}
	for line in FileAccess.get_file_as_string(LICENSES).split("\n"):
		var cells := line.split("|")
		if cells.size() >= 4:
			var file := cells[1].strip_edges().trim_prefix("`").trim_suffix("`")
			listed[file] = cells[2].contains("https://") and cells[3].strip_edges() == "CC0"
	var ok := not listed.is_empty()
	for dir in ["res://data/materials", "res://data/models"]:
		for f in _files(dir):
			if f.get_extension() in ART and not listed.get(f.trim_prefix("res://data/"), false):
				print("        unlisted or not CC0 with a URL: %s" % f)
				ok = false
	return ok

func test_materials_and_models_fit_25_mb() -> bool:
	var total := 0
	for dir in ["res://data/materials", "res://data/models"]:
		for f in _files(dir):
			total += FileAccess.get_file_as_bytes(f).size()
	if total > BUDGET:
		print("        %.1f MB over the 25 MB budget" % ((total - BUDGET) / 1048576.0))
	return total > 0 and total <= BUDGET

## A texture whose source file is on disk and has pixels.
func _real(t: Texture2D) -> bool:
	return t != null and FileAccess.file_exists(t.resource_path) and t.get_width() > 0

func _files(dir: String) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		out.append(dir + "/" + f)
	for sub in d.get_directories():
		out.append_array(_files(dir + "/" + sub))
	return out
