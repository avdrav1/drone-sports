class_name PlayerProfile
extends RefCounted
# Who the player is, from the save's "profile" section.

const DEFAULT_HANDLE := "PIP_07"

static func handle() -> String:
	var profile = SaveGame.read_section("profile", {})
	return profile.get("handle", DEFAULT_HANDLE) if profile is Dictionary else DEFAULT_HANDLE
