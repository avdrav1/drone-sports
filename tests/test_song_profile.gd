extends RefCounted
# Story 21.2: the song's profile. tools/music/analyze.py writes
# tools/music/song_profile.json the same way every run: tempo, tonic and mode
# (matching the hand-checked values kept in its "hand" block), a chord per bar,
# the drum pattern, and a spectral envelope per instrument role. key.py takes
# its tonic from the profile, so every score and in-key sound moves to it, and
# both generators' --check pass on the regenerated files.

const PROFILE := "res://tools/music/song_profile.json"
const MANIFEST := "res://data/music/manifest.json"
const PITCHES := "res://data/audio/generated/pitches.json"
const NAMES := ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"]

func _json(path: String) -> Dictionary:
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	return d if d is Dictionary else {}

func _python(script: String, args: Array) -> int:
	var out := []
	var code := OS.execute("python3", [ProjectSettings.globalize_path(script)] + args, out, true)
	if code != 0:
		print("        %s %s exited %d: %s" % [script.get_file(), " ".join(args), code, "".join(out).strip_edges()])
	return code

func test_analysis_writes_the_same_json_twice() -> bool:
	# --check analyses the song again and compares with the committed JSON
	# (without the FLAC it says so and passes).
	return _python("res://tools/music/analyze.py", ["--check"]) == 0

func test_tempo_and_tonic_match_the_hand_checked_values() -> bool:
	var p := _json(PROFILE)
	var hand: Dictionary = p.get("hand", {})
	var measured: Dictionary = p.get("measured", {})
	var ok: bool = hand.has("bpm") and hand.has("tonic") and hand.has("mode")
	# The measured values agree with the hand-checked ones...
	ok = ok and absf(float(measured.get("bpm", 0.0)) - float(hand.get("bpm", -1.0))) < 0.05 \
		and measured.get("tonic", "") == hand.get("tonic", "?") and measured.get("mode", "") == hand.get("mode", "?")
	# ...and the profile's own are them, with the tonic in Hz on that note in
	# octave 3 (within the song's tuning, under a quarter tone from A440).
	var pc := NAMES.find(String(p.get("tonic", "")))
	var et := 440.0 * pow(2.0, (48 + pc - 69) / 12.0)
	var cents := 1200.0 * log(float(p.get("tonic_hz", 1.0)) / et) / log(2.0)
	ok = ok and is_equal_approx(float(p.get("bpm", 0.0)), float(hand.get("bpm", -1.0))) \
		and p.get("tonic", "") == hand.get("tonic", "?") and p.get("mode", "") == hand.get("mode", "?") \
		and pc >= 0 and absf(cents - float(p.get("tuning_cents", 99))) < 0.5 and absf(cents) < 25.0
	# The theme cut from the song (Story 21.1) is on the same tempo.
	var theme: Score = load(MusicDirector.THEME_PATH)
	ok = ok and theme != null and is_equal_approx(theme.tempo, float(p.get("bpm", 0.0)))
	if not ok:
		print("        profile %s %s %s Hz, measured %s, hand %s" % [p.get("bpm"), p.get("tonic"), p.get("tonic_hz"), measured, hand])
	return ok

func test_profile_holds_chords_drums_and_tones() -> bool:
	var p := _json(PROFILE)
	var chords: Array = p.get("chords", [])
	var ok: bool = int(p.get("bars", 0)) > 0 and chords.size() == int(p.get("bars", -1))
	for c in chords:
		ok = ok and (c == "N" or NAMES.has(String(c).trim_suffix("m")))
	var drums: Dictionary = p.get("drums", {})
	for voice in ["kick", "snare", "hat"]:
		var d: Dictionary = drums.get(voice, {})
		ok = ok and (d.get("steps", []) as Array).size() == 16 and not (d.get("onsets", []) as Array).is_empty()
	var tones: Dictionary = p.get("tones", {})
	for role in ["bass", "pads", "lead", "drums"]:
		var env: Array = tones.get(role, {}).get("envelope", [])
		var top := -INF
		for e in env:
			top = maxf(top, float(e[1]))
		ok = ok and env.size() >= 4 and is_zero_approx(top)
	return ok and (tones.get("bass", {}).get("harmonics_db", []) as Array).size() == 8 \
		and (tones.get("lead", {}).get("harmonics_db", []) as Array).size() == 8

func test_key_takes_the_profiles_tonic() -> bool:
	var tonic: float = _json(PROFILE).get("tonic_hz", 0.0)
	var out := []
	OS.execute("python3", ["-c", "import sys; sys.dont_write_bytecode = True; sys.path.insert(0, sys.argv[1]); import key; print(repr(key.TONIC))",
		ProjectSettings.globalize_path("res://tools/music")], out, true)
	var key_tonic := "".join(out).strip_edges().to_float()
	# What the generators wrote with it: every score's tonic and the motor hum.
	var ok: bool = tonic > 0.0 and is_equal_approx(key_tonic, tonic) \
		and is_equal_approx(float(_json(MANIFEST).get("tonic", 0.0)), tonic) \
		and is_equal_approx(float(_json(PITCHES).get("drone_hum", {}).get("hz", 0.0)), tonic)
	if not ok:
		print("        profile %s, key.py %s" % [tonic, "".join(out).strip_edges()])
	return ok

func test_both_generators_check_after_regenerating() -> bool:
	var music := _python("res://tools/music/generate.py", ["--check"])
	var sfx := _python("res://tools/sfx/generate.py", ["--check"])
	return music == 0 and sfx == 0
