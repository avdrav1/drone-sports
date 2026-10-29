extends RefCounted
# Story 21.3: every score in the song's sound. tools/music/generate.py reads
# tools/music/song_profile.json, so every Score plays at the song's tempo (or
# a multiple the manifest states) on its tonic, and the acts play the song's
# chords; the generator stays deterministic, each act still strips back (fewer
# stems than the act before), and data/music/ stays under budget and licensed.

const PROFILE := "res://tools/music/song_profile.json"
const MANIFEST := "res://data/music/manifest.json"
const MUSIC_DIR := "res://data/music"
const LICENSES := "res://data/audio/LICENSES.md"
const BUDGET := 10 * 1024 * 1024
const ACTS := 5

func _json(path: String) -> Dictionary:
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	return d if d is Dictionary else {}

func _scores() -> Array[Score]:
	var out: Array[Score] = []
	for f in DirAccess.open(MUSIC_DIR).get_files():
		if f.get_extension() == "tres":
			out.append(load(MUSIC_DIR + "/" + f))
	return out

func test_every_score_uses_the_song_tempo_and_tonic() -> bool:
	var p := _json(PROFILE)
	var m := _json(MANIFEST)
	var bpm := float(p.get("bpm", 0.0))
	var multiples: Array = m.get("tempo_multiples", [])
	var ok: bool = bpm > 0.0 and is_equal_approx(float(m.get("song_bpm", 0.0)), bpm) and not multiples.is_empty()
	var scores := _scores()
	ok = ok and scores.size() == m.get("scores", {}).size()
	for sc in scores:
		var listed: Dictionary = m.scores.get(String(sc.id), {})
		var k := float(listed.get("tempo_multiple", -1.0))
		# The tempo is the song's times the multiple the manifest states for it.
		var good: bool = multiples.has(k) and is_equal_approx(sc.tempo, bpm * k) \
			and absf(sc.tonic - float(p.get("tonic_hz", 0.0))) < 0.01
		if not good:
			print("        %s: %.2f bpm (x%s of %.1f), tonic %.2f" % [sc.id, sc.tempo, k, bpm, sc.tonic])
		ok = ok and good
	return ok

func test_acts_play_the_songs_chords() -> bool:
	var chords: Array = _json(PROFILE).get("chords", [])
	var m := _json(MANIFEST)
	var ok := true
	for act in range(1, ACTS):
		var played: Array = m.scores.get("act_%d" % act, {}).get("chords", [])
		# One chord a bar, starting on the tonic, read from the song every two
		# of its bars somewhere in it.
		var found := false
		for start in chords.size() - 2 * played.size():
			var same := true
			for i in played.size():
				same = same and chords[start + 2 * i] == played[i]
			found = found or same
		var good: bool = played.size() == 8 and played[0] == _json(PROFILE).get("tonic", "") and found
		if not good:
			print("        act %d plays %s" % [act, played])
		ok = ok and good
	return ok

func test_generator_is_deterministic() -> bool:
	# --check renders everything again and fails unless every file matches.
	var out := []
	var code := OS.execute("python3", [ProjectSettings.globalize_path("res://tools/music/generate.py"), "--check"], out, true)
	if code != 0:
		print("        generate.py --check exited %d: %s" % [code, "".join(out).strip_edges()])
	return code == 0

func test_each_act_has_fewer_stems_than_the_one_before() -> bool:
	var ok := true
	var last := 1 << 30
	for act in range(1, ACTS + 1):
		var sc: Score = load(MusicDirector.SCORE_PATH % act)
		if sc == null or sc.stems.size() >= last:
			print("        act %d has %d stems after %d" % [act, sc.stems.size() if sc else -1, last])
			ok = false
		last = sc.stems.size() if sc else 0
	return ok

func test_music_is_under_ten_megabytes() -> bool:
	var total := 0
	for f in DirAccess.open(MUSIC_DIR).get_files():
		if f.get_extension() != "import":
			total += FileAccess.open(MUSIC_DIR + "/" + f, FileAccess.READ).get_length()
	if total >= BUDGET:
		print("        data/music/ is %d bytes" % total)
	return total > 0 and total < BUDGET

func test_every_music_file_is_listed() -> bool:
	var text := FileAccess.get_file_as_string(LICENSES)
	var ok := true
	for f in DirAccess.open(MUSIC_DIR).get_files():
		if f.get_extension() == "ogg" and not text.contains("`../music/%s`" % f):
			print("        unlisted: data/music/%s" % f)
			ok = false
	# And nothing listed is gone.
	for line in text.split("\n"):
		var at := line.find("`../music/")
		if at >= 0:
			var f := line.substr(at + 10, line.find("`", at + 1) - at - 10)
			if not FileAccess.file_exists(MUSIC_DIR + "/" + f):
				print("        listed but missing: data/music/%s" % f)
				ok = false
	return ok
