class_name Chorus
extends Node
# The Lattice's voice (Story 8.7): short, flat, plural lines from the boss's
# chorus file, said on each phase's start, on reclaiming a unit that held a
# crew member's drone, on a strike, and once at shutdown. After that it stops.
# Picks lines like Bark: seeded, no repeats within a job until a pool runs out.
# Each line has a tone under it (Story 14.8), so the tones stop with the lines.
# Not a character: it has no portrait in the cast, only its dot grid.

## {text} said on `event`.
signal spoke(event: StringName, text: String)

const PHASE_EVENTS := {
	LatticeFight.Phase.RECLAIM: &"phase_reclaim",
	LatticeFight.Phase.TRENCH: &"phase_trench",
	LatticeFight.Phase.OVERRIDE: &"phase_override",
}

@export var fight: LatticeFight
@export var seed := 1

var lines := {}
var used: Array[String] = []
var silent := false
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.seed = seed
	lines = load_lines(fight.boss().chorus)
	fight.phase_started.connect(func(p): if PHASE_EVENTS.has(p): say(PHASE_EVENTS[p]))
	fight.unit_reclaimed.connect(_on_reclaimed)
	fight.boss_disabled.connect(_on_shutdown)
	fight.runner.crew_struck.connect(func(_id, _before): say(&"strike"))

static func load_lines(path: String) -> Dictionary:
	var res: JSON = load(path) if ResourceLoader.exists(path) else null
	return res.data if res and res.data is Dictionary else {}

## Says a line for `event`; {name} and {role} fill from `about`. Returns the
## line, or "" once silent or with nothing to say.
func say(event: StringName, about: Character = null) -> String:
	if silent:
		return ""
	var pool: Array = lines.get(String(event), [])
	if pool.is_empty():
		return ""
	var fresh := pool.filter(func(l): return not l in used)
	if fresh.is_empty():
		fresh = pool
	var line: String = fresh[_rng.randi() % fresh.size()]
	used.append(line)
	var text := line
	if about:
		text = text.format({"name": about.name, "role": about.role.to_lower()})
	Sfx.play(&"lattice_tone")
	spoke.emit(event, text)
	return text

## The last thing it says.
func _on_shutdown() -> void:
	say(&"shutdown")
	silent = true

func _on_reclaimed(unit: int, _by: Drone) -> void:
	var id: StringName = fight.lattice.units[unit].crew
	if id != &"":
		say(&"crew_unit", Roster.character(id))
