class_name GameSettings
extends RefCounted
# Player settings that outrank game data, kept in the save's "settings" section.

## "Expert: all assists off". Overrides whatever preset a job or act applies.
static var expert_all_assists_off := false

## The stack to actually apply once settings are taken into account.
static func effective_stack(stack: AssistStack) -> AssistStack:
	return stack.all_off() if expert_all_assists_off else stack

static func save() -> void:
	SaveGame.write_section("settings", {"expert_all_assists_off": expert_all_assists_off})

static func load_saved() -> void:
	var saved = SaveGame.read_section("settings", {})
	expert_all_assists_off = saved is Dictionary and bool(saved.get("expert_all_assists_off", false))
