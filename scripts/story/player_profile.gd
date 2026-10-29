class_name PlayerProfile
extends RefCounted
# Who the player is, from the save's "profile" section: their handle and the
# pilot avatar they fly as (Story 7.2). Avatars are the characters tagged pilot
# in data/characters/pilots.tres; Arjuna until the player picks.

const DEFAULT_HANDLE := "ARJUNA_07"
const PILOTS := "res://data/characters/pilots.tres"
const DEFAULT_PILOT := &"arjuna"

static func handle() -> String:
	return _profile().get("handle", DEFAULT_HANDLE)

## Every selectable avatar, in list order: only characters tagged pilot.
static func pilots() -> Array[Character]:
	var out: Array[Character] = []
	for c in (load(PILOTS) as Cast).characters:
		if c and &"pilot" in c.tags:
			out.append(c)
	return out

## True once the player has picked an avatar on the pilot select screen.
static func has_pilot() -> bool:
	return _profile().has("pilot")

## The chosen avatar, or Arjuna when none is chosen (or the saved one is gone).
static func pilot() -> Character:
	var id := StringName(str(_profile().get("pilot", DEFAULT_PILOT)))
	var fallback: Character = null
	for c in pilots():
		if c.id == id:
			return c
		if c.id == DEFAULT_PILOT:
			fallback = c
	return fallback

## Fly as `id` from now on. False, and nothing changes, if it is not a pilot.
static func choose_pilot(id: StringName) -> bool:
	if not pilots().any(func(c): return c.id == id):
		return false
	var profile := _profile()
	profile["pilot"] = String(id)
	SaveGame.write_section("profile", profile)
	return true

static func _profile() -> Dictionary:
	var profile = SaveGame.read_section("profile", {})
	return profile if profile is Dictionary else {}
