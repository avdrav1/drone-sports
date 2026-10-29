class_name GameName
extends RefCounted
# The game's name (Story 24.1). `application/config/name` is the one place it
# lives: the Web export titles the page with it, on desktop it names the
# user:// folder the save is in, and the title logo and the intro's title card
# read it here instead of holding the text.

const SETTING := "application/config/name"

## The name as the logo and the title card letter it: upper-cased.
static func title() -> String:
	return str(ProjectSettings.get_setting(SETTING, "")).to_upper()
