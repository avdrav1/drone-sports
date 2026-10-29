extends RefCounted
# Story 18.4: warmer lines. Every living character's pools grow by at least
# three lines per event, {you} fills from their `calls_you`, every line from
# before is still there, and lines added to serious pools stay sincere.
# The baseline is tests/lines_before_18_4.json: every character's lines as
# text, as they were before this story.

const Sim = preload("res://tests/sim.gd")
const BEFORE := "res://tests/lines_before_18_4.json"
## Line lists said in order or once, not picked from: not pools.
const NOT_POOLS := ["trench", "epilogue"]
const SERIOUS := ["warning", "strike", "hurt", "memorial"]
## Exclamations of delight and emote words that never belong in a serious line.
const GLEE := ["yay", "woo", "woohoo", "whee", "wheee", "hooray", "hurray", "yippee", "yahoo", "haha", "hehe",
	"heh", "ha", "lol", "ooh", "aww", "tada", "boop", "bonk", "zoom", "eep", "eek", "nailed", "sweet", "awesome",
	"heart", "hearts", "sparkle", "sparkles", "giggle", "giggles", "wink", "winks", "grin", "grins", "hug", "hugs",
	"smile", "smiles", "music", "note", "notes", "star", "stars"]
const GLEE_MARKS := ["<3", ":)", ":d", ";)", "^^", "♥", "☺", "*", "~"]

func _fresh() -> void:
	SaveGame.write_section("roster", {})
	Roster.load_saved()

func _before() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(BEFORE))

func _character(id: String) -> Character:
	return load("res://data/characters/%s.tres" % id)

## A pool's lines as text, raw ({you} unfilled).
func _texts(id: String, event: String, status: String) -> Array:
	var e: Variant = Bark.lines_of(StringName(id)).get(event, {}) if Roster.character(StringName(id)) \
		else JSON.parse_string(FileAccess.get_file_as_string(_character(id).lines)).get(event, {})
	return (e.get(status, []) as Array).map(Bark.text_of) if e is Dictionary else []

## Lines in a pool now that were not there before.
func _added(id: String, event: String, status: String) -> Array:
	var entry: Variant = _before()[id].get(event, {})
	if not entry is Dictionary:  # memorial: one line, so any change is an added line
		var now := str(JSON.parse_string(FileAccess.get_file_as_string(_character(id).lines)).get(event, ""))
		return [] if status != "active" or now == entry else [now]
	var was: Array = entry.get(status, [])
	return _texts(id, event, status).filter(func(t): return not t in was)

func test_every_pool_grows_by_three() -> bool:
	_fresh()
	var before := _before()
	var ok: bool = before.size() == 9
	for id in before:
		for event in before[id]:
			if before[id][event] is Dictionary and not event in NOT_POOLS:
				for status in before[id][event]:
					var grew: int = _texts(id, event, status).size() - before[id][event][status].size()
					if grew < 3:
						print("        %s %s %s grew by %d" % [id, event, status, grew])
					ok = ok and grew >= 3
	# And as Bark serves them, for the cast, in both states.
	for id in Roster.ids():
		for event in before[String(id)]:
			if before[String(id)][event] is Dictionary and not event in NOT_POOLS:
				var e: Dictionary = before[String(id)][event]
				ok = ok and Bark.pool(id, StringName(event)).size() >= e.active.size() + 3
				if e.has("injured"):
					ok = ok and Bark.pool(id, StringName(event), Roster.Status.INJURED).size() >= e.injured.size() + 3
	return ok

func test_every_you_resolves() -> bool:
	_fresh()
	var ok := true
	var filled := 0
	for id in _before():
		var c := _character(id)
		ok = ok and not c.calls_you.is_empty() and c.validate().is_empty()
		var lines: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(c.lines))
		for event in lines:
			if not lines[event] is Dictionary:
				continue
			for status in lines[event]:
				for line in lines[event][status]:
					var raw := Bark.text_of(line)
					var said := Bark.fill(c, raw)
					var good: bool = not said.contains("{") and not said.contains("}")
					if raw.contains("{you}"):
						filled += 1
						good = good and Array(c.calls_you).any(func(n): return said == raw.replace("{you}", n)) \
							and said == Bark.fill(c, raw)
					if not good:
						print("        %s %s: %s -> %s" % [id, event, raw, said])
					ok = ok and good
	# What Bark hands out is filled, and a filled line keeps its face.
	var b := Bark.new()
	b.seed = 3
	Sim.add(b)
	for id in Roster.ids():
		for e in Bark.EVENTS:
			for t in Bark.pool(id, e) + Bark.pool(id, e, Roster.Status.INJURED):
				ok = ok and not t.contains("{") and not t.contains("}")
	var pool := Bark.pool(&"sanjaya", &"complete")
	for i in pool.size():
		var line := b.say(&"complete", &"sanjaya")
		if Bark.lines_of(&"sanjaya").complete.active.any(func(l): return l is Dictionary and Bark.text_of(l).contains("{you}") \
				and Bark.fill(Roster.character(&"sanjaya"), Bark.text_of(l)) == line.text):
			ok = ok and line.face == &"happy"
	b.free()
	return ok and filled > 100

func test_every_existing_line_still_present() -> bool:
	var before := _before()
	var ok := true
	for id in before:
		var now: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_character(id).lines))
		for event in before[id]:
			var was: Variant = before[id][event]
			if not was is Dictionary:
				ok = ok and now.get(event) == was
				continue
			for status in was:
				var texts: Array = (now[event][status] as Array).map(Bark.text_of)
				# Old lines stay first and in order; trench and epilogue are exactly as they were.
				var same: bool = texts.slice(0, was[status].size()) == was[status]
				if event in NOT_POOLS:
					same = same and texts == was[status]
				if not same:
					print("        %s %s %s changed" % [id, event, status])
				ok = ok and same
	return ok

func test_added_serious_lines_stay_sincere() -> bool:
	var ok := true
	var checked := 0
	for id in _before():
		for event in SERIOUS:
			for status in ["active", "injured"]:
				for t in _added(id, event, status):
					checked += 1
					var lower: String = t.to_lower()
					var words := Array(lower.replace("'", "").split(" ", false)).map(func(w): return w.strip_edges().rstrip(".,!?;:-").lstrip("."))
					var glee: bool = GLEE.any(func(g): return g in words) or GLEE_MARKS.any(func(m): return lower.contains(m)) \
						or t.contains("{you}")
					if glee:
						print("        %s %s: %s" % [id, event, t])
					ok = ok and not glee
	return ok and checked >= 9 * 6

## Story 7.3's, 17.2's and 17.9's bark tests, run as they are.
func test_existing_bark_tests_pass() -> bool:
	var ok := true
	for path in ["res://tests/test_bark.gd", "res://tests/test_flight_lines.gd"]:
		var suite: RefCounted = load(path).new()
		for m in suite.get_method_list():
			if String(m.name).begins_with("test_"):
				var passed: bool = await suite.call(m.name)
				if not passed:
					print("        %s %s failed" % [path, m.name])
				ok = ok and passed
	_fresh()
	return ok
