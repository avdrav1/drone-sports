extends RefCounted
# Story 30.4: the shedding: the names of assists let go and what each unlocks,
# from data (data/assists/unlocks.tres, read through data/story/shedding.tres).
# Since Story 35.1 no offer removes assists, so no offer shows it. The act
# presets are unchanged.

const Sim = preload("res://tests/sim.gd")
const SHEDDING := "res://data/story/shedding.tres"
const UNLOCKS := "res://data/assists/unlocks.tres"
const ACTS := "res://data/assists/act%d.tres"
const TEAMS := ["skyline_juniors", "harbor_couriers", "cannery_row", "city_rescue_air", "halcyon_racing", "deadweight"]

func _team(id: String) -> Team:
	return load("res://data/teams/%s.tres" % id)

func _dialog() -> OfferDialog:
	var d := OfferDialog.new()
	Sim.add(d)
	return d

## The words the shedding shows, joined, or "" when it is not there.
func _shown(d: OfferDialog) -> String:
	if d.content == null:
		return ""
	var out := ""
	for l in d.content.find_children("*", "Label", true, false):
		out += (l as Label).text + "\n"
	return out

func test_every_assist_has_a_name_and_an_unlock_in_data() -> bool:
	var u: AssistUnlocks = load(UNLOCKS)
	var ok := true
	for id in AssistStack.IDS:
		ok = ok and u.names.get(id, "") != "" and u.unlocks.get(id, "") != ""
	# The words are data, not code.
	var code := FileAccess.get_file_as_string("res://scripts/ui/offer_dialog.gd") \
		+ FileAccess.get_file_as_string("res://scripts/story/shedding.gd")
	for id in AssistStack.IDS:
		ok = ok and not code.contains(u.unlocks[id])
	return ok

func test_the_unlocks_follow_the_assist_table() -> bool:
	# CLAUDE.md's table, "Removing it unlocks".
	var u: AssistUnlocks = load(UNLOCKS)
	var want := {
		&"collision_guard": ["tight gaps", "interior flying"],
		&"altitude_hold": ["dives", "low passes"],
		&"auto_level": ["banked turns", "dutch angles"],
		&"speed_governor": ["full throttle", "top speed"],
		&"battery_wind": ["route planning", "timing to gusts"],
		&"single_drone_view": ["fleet command layer"],
	}
	var ok := true
	for id in want:
		for words in want[id]:
			ok = ok and u.unlocks[id].contains(words)
	return ok

func test_the_lines_come_from_data() -> bool:
	var shed: Shedding = (load(SHEDDING) as Shedding).duplicate()
	shed.unlocks = (shed.unlocks as AssistUnlocks).duplicate()
	shed.unlocks.unlocks = shed.unlocks.unlocks.duplicate()
	shed.unlocks.unlocks[&"collision_guard"] = "a test word"
	var removed: Array[StringName] = [&"collision_guard"]
	return shed.lines(removed).size() == 1 and shed.lines(removed)[0].contains("a test word") \
		and shed.lines([] as Array[StringName]).is_empty()

func test_act_presets_are_unchanged() -> bool:
	# Which assists are on in each act, in AssistStack.IDS order.
	var want := {
		1: [true, true, true, true, true, true, true, true],
		2: [false, true, true, true, true, true, true, true],
		3: [false, false, false, false, true, true, true, true],
		4: [false, false, false, false, false, false, false, true],
		5: [false, false, false, false, false, false, false, false],
	}
	var ok := true
	for act in want:
		var s: AssistStack = load(ACTS % act)
		for i in AssistStack.IDS.size():
			ok = ok and s.is_on(AssistStack.IDS[i]) == want[act][i]
	return ok

## Story 35.1: joining a team changes the act, never the assists, so no offer,
## from any career, sheds anything: no lines, no symbol, no motif, the plain
## offer text naming the act.
func test_no_offer_sheds_anything() -> bool:
	var before := Music.score
	var d := _dialog()
	var ok := true
	for from_team in [""] + TEAMS:
		Career.team_id = StringName(from_team)
		for id in TEAMS:
			var t := _team(id)
			d.show_offer(t)
			ok = ok and d.content == null and d.shed_lines.is_empty() and d.get_label().visible \
				and d.dialog_text.contains(t.preset.label) and Music.score == before
			for a in AssistStack.IDS:
				ok = ok and not d.dialog_text.contains(FlightHud.ASSIST_NAMES[a])
			d.hide()
	Career.team_id = &""
	Career.offered.clear()
	d.free()
	return ok
