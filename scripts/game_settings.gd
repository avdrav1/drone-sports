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
## The pad (Story 23.6): StickLayout.MODE_2 or MODE_1, pitch inverted, stick feel
## (PilotInput.expo, 0 to 1), the flight sticks' deadzone, and rumble (Story 23.7).
## Button remaps per pad name live in PadRemap (Story 28.5).
static var stick_mode: int = StickLayout.MODE_2
static var invert_pitch := false
static var stick_expo := 0.4
static var stick_deadzone := 0.2
static var rumble := true

## The stack to actually apply once settings are taken into account.
static func effective_stack(stack: AssistStack) -> AssistStack:
	return stack.all_off() if expert_all_assists_off else stack

static func save() -> void:
	SaveGame.write_section("settings", {"expert_all_assists_off": expert_all_assists_off,
		"volumes": volumes, "muted": muted, "quality": quality,
		"stick_mode": stick_mode, "invert_pitch": invert_pitch, "stick_expo": stick_expo,
		"stick_deadzone": stick_deadzone, "rumble": rumble, "pad_remaps": PadRemap.to_save()})

static func load_saved() -> void:
	var saved = SaveGame.read_section("settings", {})
	expert_all_assists_off = saved is Dictionary and bool(saved.get("expert_all_assists_off", false))
	volumes = {}
	muted = false
	quality = default_quality()
	_load_pad(saved if saved is Dictionary else {})
	if saved is Dictionary:
		var v = saved.get("volumes", {})
		if v is Dictionary:
			for k in v:
				volumes[String(k)] = clampf(float(v[k]), 0.0, 1.0)
		muted = bool(saved.get("muted", false))
		if not OS.has_feature("web"):
			quality = clampi(int(saved.get("quality", quality)), Quality.Tier.LOW, Quality.Tier.HIGH)

## The pad settings, onto the InputMap at once (applied on boot this way).
static func _load_pad(saved: Dictionary) -> void:
	stick_mode = StickLayout.MODE_1 if int(saved.get("stick_mode", StickLayout.MODE_2)) == StickLayout.MODE_1 else StickLayout.MODE_2
	invert_pitch = bool(saved.get("invert_pitch", false))
	stick_expo = clampf(float(saved.get("stick_expo", 0.4)), 0.0, 1.0)
	stick_deadzone = clampf(float(saved.get("stick_deadzone", 0.2)), StickLayout.DEADZONE_MIN, StickLayout.DEADZONE_MAX)
	rumble = bool(saved.get("rumble", true))
	StickLayout.apply()
	PadRemap.from_save(saved.get("pad_remaps", {}))
	PadRemap.refresh()

## High on desktop, Low on the web build.
static func default_quality() -> int:
	return Quality.Tier.LOW if OS.has_feature("web") else Quality.Tier.HIGH
