extends RefCounted
# Story 30.2: the Four's symbols and motifs. Every god's symbols draw on their
# disc at 32, 64 and 128 px with no polygon skipped (one symbol, larger, below
# the detail size), the ink reads on the field, and each Deity.motif names a
# stem in data/music/four.tres that tools/music/generate.py wrote, listed as
# generated, with data/music/ still under its budget.

const Sim = preload("res://tests/sim.gd")
const LIST := "res://data/deities/deities.tres"
const MANIFEST := "res://data/music/manifest.json"
const LICENSES := "res://data/audio/LICENSES.md"
const MUSIC_DIR := "res://data/music"
const SIZES := [32, 64, 128]
## data/music/'s budget (test_music.gd).
const BUDGET := 16 * 1024 * 1024

func _deities() -> Array[Deity]:
	return (load(LIST) as DeityList).deities

func _art() -> DeitySymbolArt:
	return load(DeitySymbol.ART)

## What a symbol of `d` at `px` should draw, in drawing order.
func _expected(d: Deity, px: int) -> Array[StringName]:
	var art := _art()
	var places: Dictionary = art.placements if px >= art.detail_below else art.small
	var out: Array[StringName] = []
	for sym in art.order:
		if sym in d.symbols and places.has(sym):
			out.append(sym)
	return out

func test_every_symbol_has_a_place_and_a_drawing_order() -> bool:
	var art := _art()
	var ok: bool = art.detail_below > 32 and art.detail_below <= 64 and art.vedas == 4
	for d in _deities():
		var small := 0
		for sym in d.symbols:
			ok = ok and art.placements.has(sym) and sym in art.order
			small += 1 if art.small.has(sym) else 0
		# Below the detail size each god still shows exactly one symbol.
		ok = ok and small == 1
	return ok

func test_each_symbol_draws_at_32_64_and_128_px() -> bool:
	var ok := true
	var shown: Array[DeitySymbol] = []
	for d in _deities():
		for px in SIZES:
			var s := DeitySymbol.new()
			s.deity = d
			s.custom_minimum_size = Vector2(px, px)
			s.size = Vector2(px, px)
			shown.append(Sim.add(s))
	await Sim.process_frames(2)
	for s in shown:
		var px := int(s.size.x)
		var want := _expected(s.deity, px)
		if s.size != Vector2(px, px) or s.drawn != want or s.skipped != 0 or want.is_empty():
			print("        %s at %d px drew %s (skipped %d)" % [s.deity.id, px, s.drawn, s.skipped])
			ok = false
		s.free()
	return ok

func test_the_ink_reads_on_each_field() -> bool:
	var s := DeitySymbol.new()
	var ok := true
	for d in _deities():
		var ink := s.ink_for(d)
		if absf(ink.get_luminance() - d.colour.get_luminance()) < 0.35:
			print("        %s: ink %s on %s" % [d.id, ink, d.colour])
			ok = false
	s.free()
	return ok

func test_each_motif_resolves_to_a_stem() -> bool:
	var sc: Score = load(Deity.MOTIF_SCORE)
	var seen := {}
	var ok: bool = sc != null and sc.stems.size() == 4
	for d in _deities():
		var stem := d.motif_stem()
		ok = ok and d.motif != &"" and stem != null and stem.id == d.motif and stem.stream != null \
			and stem.muffled != null and stem.level_db > Music.SILENT_DB and not seen.has(d.motif)
		seen[d.motif] = true
	return ok

func test_the_generator_wrote_the_motifs_in_the_key() -> bool:
	var m: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	var four: Dictionary = m.scores.get("four", {})
	var plays: Dictionary = four.get("plays", {})
	var sc: Score = load(Deity.MOTIF_SCORE)
	var ok: bool = is_equal_approx(float(four.get("tonic", 0.0)), float(m.tonic)) and is_equal_approx(sc.tonic, float(m.tonic))
	for d in _deities():
		# Listed with what plays it, and never a voice: the Four have no voices.
		ok = ok and String(d.motif) in four.get("stems", []) and plays.get(String(d.motif), "voice") != "voice"
	return ok and plays.get("motif_krishna", "") == "flute"

func test_motifs_are_licensed_and_the_budget_holds() -> bool:
	var text := FileAccess.get_file_as_string(LICENSES)
	var ok := true
	for d in _deities():
		for suffix in ["", "_muffled"]:
			var row := "| `../music/four_%s%s.ogg` | `tools/music/generate.py` | generated |" % [d.motif, suffix]
			ok = ok and text.contains(row) and FileAccess.file_exists("%s/four_%s%s.ogg" % [MUSIC_DIR, d.motif, suffix])
	var total := 0
	for f in DirAccess.open(MUSIC_DIR).get_files():
		if f.get_extension() != "import":
			total += FileAccess.open(MUSIC_DIR + "/" + f, FileAccess.READ).get_length()
	return ok and total > 0 and total < BUDGET
