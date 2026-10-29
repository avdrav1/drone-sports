extends RefCounted
# Story 19.3: pilot select shows the edge. Every card shows what the pilot is
# best at, the edge in plain words, and four bars computed from the edge, the
# specialist's specialty highest; it all fits at 960x720 and 1920x1080 in
# both front-end skins.

const Sim = preload("res://tests/sim.gd")

## Each specialist's best bar.
const SPECIALTY := {&"abhimanyu": &"speed", &"jatayu": &"cornering", &"hanuman": &"climb"}

func _bars(s: PilotSelect, id: StringName) -> Dictionary:
	var out := {}
	for bar in s.cards[id].find_child("Bars", true, false).get_children():
		if bar is PilotSelect.Bar:
			out[StringName(bar.name)] = bar.fill
	return out

func test_every_card_shows_best_at_edge_and_four_bars() -> bool:
	var s := PilotSelect.new()
	Sim.add(s)
	var ok := s.cards.size() == PlayerProfile.pilots().size()
	for c in PlayerProfile.pilots():
		var card: Control = s.cards[c.id]
		var best: Label = card.find_child("BestAt", true, false)
		var edge: Label = card.find_child("Edge", true, false)
		ok = ok and best.text == "Best at " + c.edge.best_at and not c.edge.best_at.is_empty()
		ok = ok and _bars(s, c.id).keys() == PilotEdge.BARS.keys()
		# One line per assist setting, then the stat steps, all filled in.
		ok = ok and edge.text.split("\n").size() == c.edge.assists.size() + 1 and not "{" in edge.text
	# The words name this pilot's number and the stock one, e.g. Abhimanyu's governor.
	var abhimanyu: String = s.cards[&"abhimanyu"].find_child("Edge", true, false).text
	ok = ok and abhimanyu.contains("15 m") and abhimanyu.contains("governor") and abhimanyu.contains("others 12")
	s.free()
	return ok

func test_bars_come_from_the_edge() -> bool:
	var s := PilotSelect.new()
	Sim.add(s)
	var ok := true
	for c in PlayerProfile.pilots():
		var bars := _bars(s, c.id)
		ok = ok and bars == c.edge.bars()
		for id in bars:
			ok = ok and bars[id] >= PilotEdge.BAR_STOCK and bars[id] <= 1.0
		if SPECIALTY.has(c.id):
			for id in bars:
				ok = ok and (id == SPECIALTY[c.id] or bars[id] < bars[SPECIALTY[c.id]])
	# Change the data and the bar follows: Jatayu with a much bigger battery.
	var jatayu: Character = PlayerProfile.pilots().filter(func(c): return c.id == &"jatayu")[0]
	var before: float = _bars(s, &"jatayu")[&"endurance"]
	var step := StatStep.new()
	step.stat = &"battery_flight_time"
	step.step = 120.0
	jatayu.edge.stats.append(step)
	s.refresh()
	var after: float = _bars(s, &"jatayu")[&"endurance"]
	jatayu.edge.stats.erase(step)
	s.free()
	return ok and jatayu.id == &"jatayu" and after > before + 0.2

## Every control on the screen, inside it, and no text wider or taller than its box.
func _fits(s: PilotSelect, screen: Vector2) -> bool:
	var ok := true
	var stack: Array[Node] = [s]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		if not (n is Control and n.is_visible_in_tree()) or n == s or n is ColorRect:
			continue
		var r: Rect2 = n.get_global_rect()
		var inside := r.position.x >= -0.5 and r.position.y >= -0.5 and r.end.x <= screen.x + 0.5 and r.end.y <= screen.y + 0.5
		var min_size: Vector2 = n.get_combined_minimum_size()
		var room := min_size.x <= r.size.x + 0.5 and min_size.y <= r.size.y + 0.5
		if not (inside and room):
			print("        %s at %s: %s (min %s)" % [n.get_path(), screen, r, min_size])
		ok = ok and inside and room
	return ok

func test_text_fits_at_960_and_1080_in_both_skins() -> bool:
	var ok := true
	PlayerProfile.choose_pilot(&"arjuna")  # Back showing: the tallest the page gets
	for act in [1, 2]:
		for screen in [Vector2(960, 720), Vector2(1920, 1080)]:
			var root := Control.new()
			root.theme = FrontSkin.for_act(act).theme()
			root.size = screen
			Sim.add(root)
			var s := PilotSelect.new()
			root.add_child(s)
			s.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			await Sim.process_frames(3)
			ok = ok and _fits(s, screen)
			root.free()
	return ok
