class_name GameSettings
extends RefCounted
# Player settings that outrank game data. Not saved yet.

## "Expert: all assists off". Overrides whatever preset a job or act applies.
static var expert_all_assists_off := false

## The stack to actually apply once settings are taken into account.
static func effective_stack(stack: AssistStack) -> AssistStack:
	return stack.all_off() if expert_all_assists_off else stack
