extends RefCounted
# Story 30.4: the shedding. A promotion offer that removes assists names each
# one and what removing it unlocks, from data (data/assists/unlocks.tres, read
# through data/story/shedding.tres), under Shiva's symbol with his motif alone.
# An offer that removes none shows nothing extra. The act presets are unchanged.

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

func test_every_removing_offer_names_each_assist_and_its_unlock() -> bool:
	var u: AssistUnlocks = load(UNLOCKS)
	var d := _dialog()
	var ok := true
	var checked := 0
	# Every team, offered from every act's career (Career.preset() is the team's).
	for from_team in [""] + TEAMS:
		Career.team_id = StringName(from_team)
		for id in TEAMS:
			var t := _team(id)
			var removed := Career.preset().removed_by(t.preset)
			if removed.is_empty():
				continue
			d.show_offer(t)
			var shown := _shown(d)
			ok = ok and d.shed_lines.size() == removed.size() and not d.get_label().visible
			for a in removed:
				ok = ok and shown.contains(u.names[a]) and shown.contains(u.unlocks[a])
			checked += 1
			d.hide()
	Career.team_id = &""
	d.free()
	return ok and checked > 6

func test_the_lines_come_from_data() -> bool:
	var shed: Shedding = (load(SHEDDING) as Shedding).duplicate()
	shed.unlocks = (shed.unlocks as AssistUnlocks).duplicate()
	shed.unlocks.unlocks = shed.unlocks.unlocks.duplicate()
	shed.unlocks.unlocks[&"collision_guard"] = "a test word"
	var removed: Array[StringName] = [&"collision_guard"]
	return shed.lines(removed).size() == 1 and shed.lines(removed)[0].contains("a test word") \
		and shed.lines([] as Array[StringName]).is_empty()

func test_skyline_offer_shows_shiva_and_his_motif_then_puts_the_music_back() -> bool:
	var theme: Score = load(MusicDirector.THEME_PATH)
	MusicDirector.play_score(theme, &"title")
	var d := _dialog()
	d.show_offer(_team("skyline_juniors"))
	var shiva: Deity = (load(SHEDDING) as Shedding).deity
	var symbols := d.content.find_children("*", "DeitySymbol", true, false) if d.content else []
	var symbol_ok: bool = symbols.size() == 1 and (symbols[0] as DeitySymbol).deity == shiva and shiva.id == &"shiva"
	var shown := _shown(d)
	var lines_ok: bool = d.shed_lines.size() == 1 and shown.contains("collision guard") \
		and shown.contains("tight gaps and interior flying") and d.dialog_text.contains("GUARD")
	var motif_ok: bool = Music.score != null and Music.score.resource_path == Deity.MOTIF_SCORE
	if motif_ok:
		for s in Music.score.stems:
			var want: float = s.level_db if s.id == shiva.motif else Music.SILENT_DB
			motif_ok = motif_ok and is_equal_approx(Music.levels.get(s.id, Music.SILENT_DB), want)
	# Nothing in it is a face, a portrait or a crew member's word.
	var plain: bool = d.content.find_children("*", "TextureRect", true, false).is_empty()
	d.canceled.emit()
	await Sim.process_frames(2)
	var back: bool = Music.score == theme and MusicDirector.mix == &"title"
	Career.offered.clear()
	d.free()
	return symbol_ok and lines_ok and motif_ok and plain and back

func test_an_offer_removing_nothing_shows_nothing_extra() -> bool:
	Career.team_id = &"skyline_juniors"
	var before := Music.score
	var d := _dialog()
	d.show_offer(_team("harbor_couriers"))  # Act 2 to Act 2
	var ok: bool = d.content == null and d.shed_lines.is_empty() and d.get_label().visible \
		and d.dialog_text.contains("Act 2") and Music.score == before
	# After one that did, the next that does not clears it.
	Career.team_id = &""
	d.show_offer(_team("skyline_juniors"))
	var had := d.content != null
	Career.team_id = &"skyline_juniors"
	d.show_offer(_team("harbor_couriers"))
	ok = ok and had and d.content == null and d.get_label().visible
	d._hush()
	Career.team_id = &""
	d.free()
	return ok

func test_act_presets_are_unchanged() -> bool:
	# Which assists are on in each act, in AssistStack.IDS order.
	var want := {
		1: [true, true, true, true, true, true, true],
		2: [false, true, true, true, true, true, true],
		3: [false, false, false, false, true, true, true],
		4: [false, false, false, false, false, false, true],
		5: [false, false, false, false, false, false, false],
	}
	var ok := true
	for act in want:
		var s: AssistStack = load(ACTS % act)
		for i in AssistStack.IDS.size():
			ok = ok and s.is_on(AssistStack.IDS[i]) == want[act][i]
	return ok
