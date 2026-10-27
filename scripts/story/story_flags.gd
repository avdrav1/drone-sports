class_name StoryFlags
extends RefCounted
# Story beats that have happened, kept in the save's "flags" section.
# Later epics read them (e.g. "scouted" gates recruitment in Epic 5).

static func is_set(flag: StringName) -> bool:
	var flags = SaveGame.read_section("flags", {})
	return flags is Dictionary and flags.get(String(flag), false)

static func set_flag(flag: StringName) -> void:
	var flags = SaveGame.read_section("flags", {})
	if not flags is Dictionary:
		flags = {}
	flags[String(flag)] = true
	SaveGame.write_section("flags", flags)
