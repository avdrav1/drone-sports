extends RefCounted
# Story 27.1: a livery in the save. Every drone slot has a livery and parts kept
# in the save's "hangar" section; a save without one starts every slot on the
# default, which is the drone as it was; unknown ids fall back to the default.

const Sim = preload("res://tests/sim.gd")
const STATS: Array[StringName] = [&"mass", &"drag", &"angular_drag", &"max_thrust", &"arm_length",
	&"yaw_torque_per_thrust", &"battery_flight_time"]

## The player's drone with the garage applied, as its stats.
func _stats() -> Dictionary:
	var d: Drone = Sim.drone(Sim.intent())
	Garage.apply(d)
	var out := {}
	for s in STATS:
		out[s] = d.get(s)
	var assists := d.assists.assists().size()
	d.free()
	out[&"assists"] = assists
	return out

## A part the catalog does not ship, for the length of one test.
func _test_part(kind: StringName) -> Part:
	var p := Part.new()
	p.id = StringName("test_" + kind)
	p.kind = kind
	Hangar.catalog.parts.append(p)
	return p

func test_no_hangar_section_is_the_default_ride() -> bool:
	var before := _stats()
	var data := SaveGame.read()
	data.erase("hangar")
	SaveGame._store(data)
	SaveGame.load_all(Sim.tree())
	var def := Hangar.catalog.default_livery
	var ok := Hangar.slot_count() == 1 + FleetCrew.tagged().size() and Hangar.slot_count() >= 3
	for slot in Hangar.slot_count():
		ok = ok and Hangar.livery(slot).to_dict() == def.to_dict()
		for kind in Part.KINDS:
			var p := Hangar.part(Hangar.part_id(slot, kind))
			ok = ok and p != null and p == Hangar.default_part(kind)
	# The default livery is today's look: read the colours off a drone body.
	var look := DroneLook.new()
	look._build()
	var meshes := look.get_children()
	var col := func(i: int) -> Color: return (meshes[i] as MeshInstance3D).material_override.albedo_color
	var blade: Color = look._blades[0].albedo_color
	var looks_same: bool = col.call(0) == def.body_color and col.call(1) == def.canopy_color \
		and col.call(3) == def.light_color and col.call(5) == def.arm_color \
		and Color(blade.r, blade.g, blade.b) == def.prop_color \
		and def.decal == &"" and def.race_number == 0 and def.drone_name == ""
	look.free()
	return ok and looks_same and _stats() == before

func test_slot_two_keeps_its_livery_and_parts() -> bool:
	var frame := _test_part(&"frame")
	Hangar.catalog.decals.append(&"test_lotus")
	var l := Hangar.livery(2)
	l.body_color = Color(0.6, 0.1, 0.3)
	l.light_color = Color(0.1, 0.8, 0.9)
	l.decal = &"test_lotus"
	l.race_number = 27
	l.drone_name = "Garuda"
	Hangar.set_livery(2, l)
	var fitted := Hangar.fit(2, frame.id)
	var slot0 := Hangar.livery(0).to_dict()
	SaveGame.load_all(Sim.tree())
	var back := Hangar.livery(2)
	var ok := fitted and back.to_dict() == l.to_dict() and back.drone_name == "Garuda" \
		and back.decal == &"test_lotus" and Hangar.part_id(2, &"frame") == frame.id \
		and Hangar.part_id(2, &"props") == Hangar.default_part(&"props").id
	# Slot 0 is untouched, and so are the other fleet slots.
	ok = ok and Hangar.livery(0).to_dict() == slot0 and slot0 == Hangar.catalog.default_livery.to_dict() \
		and Hangar.part_id(0, &"frame") == Hangar.default_part(&"frame").id \
		and Hangar.livery(1).to_dict() == slot0
	# A copy handed out does not change the slot until it is set.
	back.race_number = 3
	ok = ok and Hangar.livery(2).race_number == 27
	Hangar.catalog.parts.erase(frame)
	Hangar.catalog.decals.erase(&"test_lotus")
	return ok

func test_unknown_ids_fall_back_to_the_default() -> bool:
	var def := Hangar.catalog.default_livery
	var bad_livery := def.to_dict()
	bad_livery["decal"] = "no_such_decal"
	bad_livery["body_color"] = "not a colour"
	bad_livery["light_color"] = "ff0000"
	SaveGame.write_section("hangar", {"slots": {
		"1": {"livery": bad_livery, "parts": {"frame": "warp_frame", "props": "stock_battery"}},
		"x": {"livery": {}}, "-1": "junk", "3": {"livery": "junk", "parts": []},
	}, "unlocked": ["lotus", 4]})
	SaveGame.load_all(Sim.tree())
	var one := Hangar.livery(1)
	var ok := one.decal == def.decal and one.body_color == def.body_color \
		and one.light_color == Color.html("ff0000")
	# An unknown part, or a part of the wrong kind, fits the default.
	for kind in Part.KINDS:
		ok = ok and Hangar.part_id(1, kind) == Hangar.default_part(kind).id
	ok = ok and Hangar.livery(3).to_dict() == def.to_dict() and Hangar.unlocked.size() == 1 and Hangar.unlocked[0] == &"lotus"
	# Setting an unknown decal or fitting an unknown part keeps the default.
	var l := Hangar.livery(2)
	l.decal = &"no_such_decal"
	Hangar.set_livery(2, l)
	ok = ok and Hangar.livery(2).decal == def.decal and not Hangar.fit(2, &"warp_frame") \
		and not Hangar.fit(Hangar.slot_count(), &"stock_frame")
	return ok
