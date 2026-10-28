extends RefCounted
# Story 16.2: instruments and the tonic. The music generator is reproducible
# byte for byte, its demo score plays every instrument, the motor hum and the
# Lattice's sounds sit on the key's tonic or fifth, and every Score shares the
# manifest's tonic.

const MUSIC_DIR := "res://data/music"
const MANIFEST := "res://data/music/manifest.json"
const PITCHES := "res://data/audio/generated/pitches.json"
const TUNED := [&"drone_hum", &"lattice_drone", &"lattice_tone"]

func _json(path: String) -> Dictionary:
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	return d if d is Dictionary else {}

func test_generator_writes_the_same_files_twice() -> bool:
	# --check renders everything again into build/music/check/ and compares
	# each file with data/music/ byte for byte.
	var out := []
	var code := OS.execute("python3", [ProjectSettings.globalize_path("res://tools/music/generate.py"), "--check"], out, true)
	if code != 0:
		print("        generate.py --check exited %d: %s" % [code, "".join(out).strip_edges()])
	return code == 0

func test_demo_manifest_lists_every_instrument() -> bool:
	var m := _json(MANIFEST)
	var all: Array = m.get("instruments", [])
	var demo: Dictionary = m.get("scores", {}).get("demo", {})
	var played := []
	var bars := {}
	for e in demo.get("instruments", []):
		played.append(e.instrument)
		bars[int(e.bar)] = true
	var sc: Score = load(MUSIC_DIR + "/demo.tres")
	var ok := all.size() >= 11 and sc != null and sc.id == &"demo"
	for name in ["tanpura", "reed", "voice", "frame_drum", "cymbals", "kick", "clap", "bass", "arp", "pad", "lead"]:
		ok = ok and name in all
	# Each instrument in turn: every one played, each in its own bar of the loop.
	for name in all:
		ok = ok and played.count(name) == 1
	return ok and played.size() == all.size() and bars.size() == all.size() and sc.bars == all.size()

func test_tuned_sounds_sit_on_the_tonic_or_fifth() -> bool:
	var tonic: float = _json(MANIFEST).get("tonic", 0.0)
	var p := _json(PITCHES)
	var ok := tonic > 0.0
	for id in TUNED:
		var e: Dictionary = p.get(String(id), {})
		var degree := int(e.get("degree", 0))
		var hz: float = e.get("hz", 0.0)
		var expect := tonic * (1.5 if degree == 5 else 1.0) * pow(2.0, int(e.get("octave", 0)))
		ok = ok and degree in [1, 5] and absf(hz - expect) < 0.01
		# The baked file really is at that pitch: more energy there than a
		# semitone either side.
		var s := _wav(_bank_file(id))
		var here := _goertzel(s, hz)
		var near := maxf(_goertzel(s, hz * pow(2.0, 1.0 / 12.0)), _goertzel(s, hz / pow(2.0, 1.0 / 12.0)))
		if not (s.size() > 0 and here > 2.0 * near):
			print("        %s: %.1f at %.2f Hz vs %.1f a semitone off" % [id, here, hz, near])
			ok = false
	return ok

func test_manifest_tonic_matches_every_score() -> bool:
	var m := _json(MANIFEST)
	var tonic: float = m.get("tonic", 0.0)
	var scores: Dictionary = m.get("scores", {})
	var ok := tonic > 0.0 and is_equal_approx(m.get("fifth", 0.0), tonic * 1.5)
	var n := 0
	for f in DirAccess.open(MUSIC_DIR).get_files():
		if f.get_extension() != "tres":
			continue
		var sc: Score = load(MUSIC_DIR + "/" + f)
		var e: Dictionary = scores.get(String(sc.id), {})
		n += 1
		if not (is_equal_approx(sc.tonic, tonic) and is_equal_approx(e.get("tonic", 0.0), tonic) \
				and is_equal_approx(e.get("tempo", 0.0), sc.tempo) and int(e.get("bars", 0)) == sc.bars):
			print("        %s: tonic %s, manifest %s" % [f, sc.tonic, e])
			ok = false
	return ok and n == scores.size() and n > 0

func test_hum_plays_on_the_tonic_at_pitch_one() -> bool:
	# DroneSound pitches drone_hum by thrust; at pitch_scale 1 it is the
	# recorded base pitch, the tonic itself.
	var e: Dictionary = _json(PITCHES).get("drone_hum", {})
	return int(e.get("degree", 0)) == 1 and int(e.get("octave", 99)) == 0 \
		and is_equal_approx(e.get("hz", 0.0), _json(MANIFEST).get("tonic", -1.0))

func _bank_file(id: StringName) -> String:
	var bank: SoundBank = load("res://data/audio/bank.tres")
	for ev in bank.events:
		if ev.id == id and not ev.streams.is_empty():
			return ev.streams[0].resource_path
	return ""

## Mono 16-bit PCM samples of a .wav, as floats; empty if it can't be read.
func _wav(path: String) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var b := FileAccess.get_file_as_bytes(path)
	var at := 12
	while at + 8 <= b.size():
		var tag := b.slice(at, at + 4).get_string_from_ascii()
		var size := b.decode_u32(at + 4)
		if tag == "data":
			out.resize(size / 2)
			for i in out.size():
				out[i] = b.decode_s16(at + 8 + i * 2) / 32768.0
			return out
		at += 8 + size + (size & 1)
	return out

## Magnitude of one frequency in s (the Goertzel algorithm).
func _goertzel(s: PackedFloat32Array, hz: float) -> float:
	var c := 2.0 * cos(TAU * hz / 22050.0)
	var a := 0.0
	var b := 0.0
	for x in s:
		var t := x + c * a - b
		b = a
		a = t
	return sqrt(maxf(0.0, a * a + b * b - c * a * b))
