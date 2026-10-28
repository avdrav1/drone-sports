extends RefCounted
# Story 16.3: the mantra. One chant hook (tools/music/mantra.json) in a call
# half and an answer half, sung only on the generator's invented vowels,
# exactly 8 bars at any tempo; every act score names a mantra stem.

const MANTRA := "res://tools/music/mantra.json"
const MANIFEST := "res://data/music/manifest.json"
const MUSIC_DIR := "res://data/music"
const BARS := 8

func _json(path: String) -> Dictionary:
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	return d if d is Dictionary else {}

func _beats(notes: Array) -> int:
	var n := 0
	for note in notes:
		n += int(note.beats)
	return n

func test_mantra_uses_only_the_generators_vowels() -> bool:
	var vowels: Array = _json(MANIFEST).get("vowels", [])
	var m := _json(MANTRA)
	var ok: bool = vowels.size() > 0 and not m.get("call", []).is_empty() and not m.get("answer", []).is_empty()
	for half in ["call", "answer"]:
		for note in m.get(half, []):
			if not (note.syllable in vowels and note.degree is float and note.degree == floorf(note.degree)):
				print("        %s: %s" % [half, note])
				ok = false
	return ok

func test_hook_is_eight_bars_at_any_tempo() -> bool:
	# Lengths are in beats, so 32 beats is 8 bars of 4/4 whatever the tempo;
	# each half is 4 bars so Act 5 can split it.
	var m := _json(MANTRA)
	var ok := _beats(m.get("call", [])) == BARS * 2 and _beats(m.get("answer", [])) == BARS * 2
	var mf: Dictionary = _json(MANIFEST).get("mantra", {})
	ok = ok and int(mf.get("bars", 0)) == BARS and int(mf.get("call_beats", 0)) == 16 and int(mf.get("answer_beats", 0)) == 16
	# The rendered hook: 8 bars at its score's tempo, to the sample.
	var sc: Score = load(MUSIC_DIR + "/mantra.tres")
	ok = ok and sc.bars == BARS
	for id in [&"mantra_voice", &"mantra_lead", &"mantra_tanpura"]:
		var s := sc.find(id)
		ok = ok and s != null and _ogg_samples(s.stream.resource_path) == roundi(BARS * 4 * 60.0 / sc.tempo * 22050)
	return ok

func test_every_act_score_names_a_mantra_stem() -> bool:
	# Act scores (data/music/act_*.tres) arrive in 16.4 onward; each must carry
	# at least one stem whose id starts with "mantra", and whole hooks of bars.
	var ok := true
	for f in DirAccess.open(MUSIC_DIR).get_files():
		if not (f.begins_with("act_") and f.get_extension() == "tres"):
			continue
		var sc: Score = load(MUSIC_DIR + "/" + f)
		var named := false
		for s in sc.stems:
			named = named or String(s.id).begins_with("mantra")
		if not named or sc.bars % BARS != 0:
			print("        %s: mantra stem %s, %d bars" % [f, named, sc.bars])
			ok = false
	return ok

## Samples in an Ogg Vorbis file: the granule position of its last page, or -1.
func _ogg_samples(path: String) -> int:
	var bytes := FileAccess.get_file_as_bytes(path)
	var at := bytes.size() - 27
	while at >= 0:
		if bytes[at] == 0x4F and bytes[at + 1] == 0x67 and bytes[at + 2] == 0x67 and bytes[at + 3] == 0x53:
			return bytes.decode_s64(at + 6)
		at -= 1
	return -1
