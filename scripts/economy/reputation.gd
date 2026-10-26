extends Node
# Autoload "Reputation": standing with each faction, a plain number per faction id.

signal changed(faction: StringName, value: int)

var by_faction := {}

func _ready() -> void:
	load_saved()

func of(faction: StringName) -> int:
	return by_faction.get(faction, 0)

func add(faction: StringName, amount: int) -> void:
	by_faction[faction] = of(faction) + amount
	changed.emit(faction, by_faction[faction])

func save() -> void:
	var out := {}
	for f in by_faction:
		out[String(f)] = by_faction[f]
	SaveGame.write_section("reputation", out)

func load_saved() -> void:
	by_faction.clear()
	var saved = SaveGame.read_section("reputation", {})
	if saved is Dictionary:
		for f in saved:
			by_faction[StringName(f)] = int(saved[f])
