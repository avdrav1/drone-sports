extends RefCounted
# Story 27.6: a livery for every fleet drone. In a fleet job drone N wears
# slot N's livery and flies with slot N's parts; the command view rings and
# names each drone in its light colour; COPY TO ALL copies looks and parts but
# leaves names (and race numbers); slot 0 (its parts, livery, upgrades and
# pilot's edge) never changes a fleet drone; the
# hangar's slot picker keeps the fleet's slots locked until the fleet is
# first flown.

const Sim = preload("res://tests/sim.gd")
const SCENES := ["res://scenes/jobs/fleet_inspection.tscn", "res://scenes/jobs/fleet_race.tscn"]
const BOARD := "res://scenes/ui/job_board.tscn"
## Fleet slot -> [body swatch, light swatch, frame].
const LOOKS := {
	1: [&"indigo", &"emerald", &"heavy_hauler"],
	2: [&"madder", &"lapis", &"light_racer"],
	3: [&"ivory", &"rose", &"freestyle"],
}

func _color(id: StringName) -> Color:
	for s in Hangar.catalog.palette:
		if s.id == id:
			return s.color
	return Color.BLACK

func _unlock_all() -> void:
	for u in Hangar.catalog.unlocks:
		Hangar.unlocked.append(u.item)

## A livery for `slot` from LOOKS, named and numbered after the slot.
func _dress_slot(slot: int, look: Array) -> void:
	var l := Hangar.livery(slot)
	l.body_color = _color(look[0])
	l.light_color = _color(look[1])
	l.drone_name = "Drone %d" % slot
	l.race_number = 10 + slot
	Hangar.set_livery(slot, l)
	Hangar.fit(slot, look[2])

## Slot 0 in a look no fleet slot wears, with props of its own.
func _dress_player() -> void:
	var l := Hangar.livery(0)
	l.body_color = _color(&"copper")
	l.light_color = _color(&"saffron")
	l.decal = &"lotus"
	Hangar.set_livery(0, l)
	Hangar.fit(0, &"speed_props")

## A fleet job with its briefing begun, so the runner's lead drone is applied too.
func _job(path: String) -> Node:
	var s: Node = load(path).instantiate()
	var runner: JobRunner = s.get_node("JobRunner")
	runner.pays_out = false
	runner.results_scene = null
	runner.back_scene = ""
	runner.auto_begin = false
	Sim.add(s)
	runner.begin()
	return s

## The body's paint on the drone: its look's first painted box's material
## (not the pilot's face panel, nor its back plate).
func _body(d: Drone) -> Color:
	var face := DroneFace.of(d)
	for mi: MeshInstance3D in d.get_node("Look").find_children("*", "MeshInstance3D", true, false):
		if mi.material_override is StandardMaterial3D and not (face and (mi == face or face.is_ancestor_of(mi))):
			return (mi.material_override as StandardMaterial3D).albedo_color
	return Color.TRANSPARENT

func _stats(d: Drone) -> Dictionary:
	var out := {}
	for s in Part.STATS:
		out[s] = d.get(s)
	return out

static func _same(a: Dictionary, b: Dictionary) -> bool:
	for k in a:
		if not is_equal_approx(a[k], b[k]):
			return false
	return true

## Each drone wears and flies its own slot: drone N (from 1) is slot N.
func _checks_slots(view: CommandView) -> Array:
	var out := []
	for i in view.drones.size():
		var d := view.drones[i]
		var slot := i + 1
		var l := Hangar.livery(slot)
		var worn: Livery = (d.get_node("Look") as DroneLook).worn()
		if not (worn.to_dict() == l.to_dict() and _body(d).is_equal_approx(l.body_color)):
			out.append("drone %d wears %s body %s, not slot %d's" % [slot, worn.to_dict(), _body(d), slot])
		if not _same(_stats(d), Garage.stats_with(Hangar.parts(slot), null, slot)):
			out.append("drone %d flies %s, not slot %d's %s" % [slot, _stats(d), slot, Garage.stats_with(Hangar.parts(slot), null, slot)])
	return out

func test_each_fleet_drone_wears_and_flies_its_slot() -> bool:
	_unlock_all()
	StoryFlags.set_flag(Achievement.FLEET_FLAG)
	_dress_player()
	for slot in LOOKS:
		_dress_slot(slot, LOOKS[slot])
	var out := []
	for path in SCENES:
		var s := _job(path)
		var view: CommandView = s.get_node("CommandView")
		if view.drones.size() < 3:
			out.append("only %d drones in %s" % [view.drones.size(), path])
		out.append_array(_checks_slots(view))
		# The frames differ, so the drones do: not one stock drone repeated.
		if _same(_stats(view.drones[0]), _stats(view.drones[1])):
			out.append("drones 1 and 2 fly alike in %s" % path)
		s.free()
	if not out.is_empty():
		print("        ", "\n        ".join(out.slice(0, 8)))
	return out.is_empty()

func test_slot_0_never_changes_a_fleet_drone() -> bool:
	_unlock_all()
	_dress_player()
	# The player's upgrades and pilot's edge are slot 0's too.
	PlayerProfile.choose_pilot(&"arjuna")
	Garage.levels[&"thrust"] = 2
	var stock := Garage.stats_with(Hangar.parts(1), null, 1)
	var out := []
	for path in SCENES:
		var s := _job(path)
		var view: CommandView = s.get_node("CommandView")
		# The runner's drone is the fleet's first, and still not slot 0's.
		var runner: JobRunner = s.get_node("JobRunner")
		if runner.drone != view.drones[0]:
			out.append("the runner flies another drone in %s" % path)
		for d in view.drones:
			var worn: Livery = (d.get_node("Look") as DroneLook).worn()
			if worn.decal == &"lotus" or worn.light_color.is_equal_approx(_color(&"saffron")) \
					or _body(d).is_equal_approx(_color(&"copper")):
				out.append("%s wears slot 0's livery in %s" % [d.name, path])
			if not _same(_stats(d), stock):
				out.append("%s flies slot 0's parts in %s" % [d.name, path])
		out.append_array(_checks_slots(view))
		s.free()
	Garage.levels.clear()
	if not out.is_empty():
		print("        ", "\n        ".join(out.slice(0, 8)))
	return out.is_empty()

func test_each_ring_and_name_is_in_its_drones_light_colour() -> bool:
	_unlock_all()
	StoryFlags.set_flag(Achievement.FLEET_FLAG)
	for slot in LOOKS:
		_dress_slot(slot, LOOKS[slot])
	var s := _job(SCENES[0])
	var view: CommandView = s.get_node("CommandView")
	await Sim.process_frames(2)
	var ok := view.drones.size() >= 3
	var seen := []
	for i in view.drones.size():
		var c := CommandView.mark_color(view.drones[i])
		ok = ok and c.is_equal_approx(Color(Hangar.livery(i + 1).light_color, 1.0)) and not c in seen
		seen.append(c)
	# Selecting one keeps its colour: the selection is shown by a halo, not by recolouring.
	view.select(view.drones[1])
	ok = ok and CommandView.mark_color(view.drones[1]).is_equal_approx(_color(&"lapis"))
	s.free()
	return ok

func test_copy_to_all_copies_looks_and_parts_but_leaves_names() -> bool:
	_unlock_all()
	StoryFlags.set_flag(Achievement.FLEET_FLAG)
	_dress_player()
	var player := Hangar.livery(0).to_dict()
	var player_parts := Hangar.parts(0)
	for slot in LOOKS:
		_dress_slot(slot, LOOKS[slot])
	var from := Hangar.livery(2)
	from.decal = &"chakra"
	from.glow = true
	Hangar.set_livery(2, from)
	Hangar.fit(2, &"long_battery")
	var ok := Hangar.copy_to_fleet(2)
	for slot in range(1, Hangar.slot_count()):
		var l := Hangar.livery(slot)
		var looks := l.to_dict()
		var want := from.to_dict()
		for k in ["name", "race_number"]:
			looks.erase(k)
			want.erase(k)
		ok = ok and looks == want and Hangar.parts(slot) == Hangar.parts(2)
		# Each keeps its own name and number.
		var own := "Drone %d" % slot if LOOKS.has(slot) else ""
		ok = ok and l.drone_name == own and l.race_number == (10 + slot if LOOKS.has(slot) else 0)
	# The player's drone is not a fleet slot, and slot 0 copies nowhere.
	ok = ok and Hangar.livery(0).to_dict() == player and Hangar.parts(0) == player_parts
	ok = ok and not Hangar.copy_to_fleet(0)
	# Saved.
	Hangar.load_saved()
	ok = ok and Hangar.livery(1).decal == &"chakra" and Hangar.part_id(3, &"battery") == &"long_battery" \
		and Hangar.livery(3).drone_name == "Drone 3"
	return ok

## A board in a viewport with the hangar open.
func _open() -> HangarScreen:
	PlayerProfile.choose_pilot(&"arjuna")
	var sv := SubViewport.new()
	sv.size = Vector2i(960, 720)
	Sim.add(sv)
	var b: JobBoard = load(BOARD).instantiate()
	sv.add_child(b)
	await Sim.process_frames(2)
	b.menu_button(&"Garage").pressed.emit()
	await Sim.process_frames(2)
	return b.shop

func test_the_slot_picker_opens_the_fleet_once_it_is_flown() -> bool:
	_unlock_all()
	var h := await _open()
	var n := Hangar.slot_count()
	var ok: bool = n >= 4 and h.slot_picker.item_count == n and h.slot_picker.get_item_text(0) == "YOUR DRONE" \
		and h.slot_picker.get_item_text(1).begins_with("FLEET 1") and h.slot_picker.get_item_text(2).begins_with("FLEET 2")
	# Before the fleet is first flown: every fleet slot locked, COPY TO ALL off.
	for i in range(1, n):
		ok = ok and h.slot_picker.is_item_disabled(i) and h.slot_picker.get_item_text(i).contains("locked")
	ok = ok and not h.pick_slot(1) and h.slot == 0 and h.copy_button.disabled
	# Flown: open on the next visit; a fleet slot's change applies to it alone.
	StoryFlags.set_flag(Achievement.FLEET_FLAG)
	h.leave()
	h.open()
	for i in range(1, n):
		ok = ok and not h.slot_picker.is_item_disabled(i) and not h.slot_picker.get_item_text(i).contains("locked")
	var player := Hangar.livery(0).to_dict()
	h.slot_picker.select(2)
	h.slot_picker.item_selected.emit(2)
	ok = ok and h.slot == 2 and not h.copy_button.disabled
	h.paint(&"light_color", _color(&"emerald"))
	h.try_part(&"grip_props")
	h.set_drone_name("Kestrel")
	ok = ok and h.apply() and Hangar.livery(2).light_color.is_equal_approx(_color(&"emerald")) \
		and Hangar.part_id(2, &"props") == &"grip_props" and Hangar.livery(0).to_dict() == player
	# COPY TO ALL from it: the others take the look and parts but not the name.
	h.paint(&"body_color", _color(&"indigo"))
	h.copy_button.pressed.emit()
	ok = ok and Hangar.livery(2).body_color.is_equal_approx(_color(&"indigo"))
	for i in range(1, n):
		ok = ok and Hangar.livery(i).body_color.is_equal_approx(_color(&"indigo")) \
			and Hangar.part_id(i, &"props") == &"grip_props" and Hangar.livery(i).drone_name == ("Kestrel" if i == 2 else "")
	ok = ok and Hangar.livery(0).to_dict() == player and Hangar.part_id(0, &"props") == &"stock_props"
	# Back on your drone, COPY TO ALL is off: slot 0 never reaches the fleet.
	ok = ok and h.pick_slot(0) and h.copy_button.disabled and not h.copy_to_all()
	h.get_viewport().queue_free()
	await Sim.process_frames(1)
	return ok
