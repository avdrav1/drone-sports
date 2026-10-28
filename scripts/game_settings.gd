class_name GameSettings
extends RefCounted
# Player settings that outrank game data, kept in the save's "settings" section.

## "Expert: all assists off". Overrides whatever preset a job or act applies.
static var expert_all_assists_off := false
## Bus name -> linear volume 0..1 (Story 14.1). Missing buses play at 1.
static var volumes := {}
static var muted := false
## Renderer extras (Story 15.1): Quality.Tier. High on desktop; the web is always Low.
static var quality: int = default_quality()

## The stack to actually apply once settings are taken into account.
static func effective_stack(stack: AssistStack) -> AssistStack:
	return stack.all_off() if expert_all_assists_off else stack

static func save() -> void:
	SaveGame.write_section("settings", {"expert_all_assists_off": expert_all_assists_off,
		"volumes": volumes, "muted": muted, "quality": quality})

static func load_saved() -> void:
	var saved = SaveGame.read_section("settings", {})
	expert_all_assists_off = saved is Dictionary and bool(saved.get("expert_all_assists_off", false))
	volumes = {}
	muted = false
	quality = default_quality()
	if saved is Dictionary:
		var v = saved.get("volumes", {})
		if v is Dictionary:
			for k in v:
				volumes[String(k)] = clampf(float(v[k]), 0.0, 1.0)
		muted = bool(saved.get("muted", false))
		if not OS.has_feature("web"):
			quality = clampi(int(saved.get("quality", quality)), Quality.Tier.LOW, Quality.Tier.HIGH)

## High on desktop, Low on the web build.
static func default_quality() -> int:
	return Quality.Tier.LOW if OS.has_feature("web") else Quality.Tier.HIGH
