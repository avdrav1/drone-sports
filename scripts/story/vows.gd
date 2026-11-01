class_name Vows
extends RefCounted
# Vows kept, per thread, in the save's "vows" section: deity id -> count. The
# only place a deity id is saved (Story 30.1's guard); counts only, no status.

const SECTION := "vows"

static func kept(deity: StringName) -> int:
	var all = SaveGame.read_section(SECTION, {})
	return int(all.get(String(deity), 0)) if all is Dictionary else 0

static func record_kept(deity: StringName) -> void:
	var all = SaveGame.read_section(SECTION, {})
	if not all is Dictionary:
		all = {}
	all[String(deity)] = kept(deity) + 1
	SaveGame.write_section(SECTION, all)
