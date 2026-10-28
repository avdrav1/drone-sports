class_name Boss
extends Resource
# The Lattice as data (docs/BOSS.md). `enabled` is the feature flag: when false
# the job never reaches the board and nothing under scenes/boss/ is loaded.

@export var enabled := true
## The boss job. Its scene is a path, so loading this never loads the scene.
@export var job: Job
## Crew who must be alive to attempt it.
@export var required_characters: Array[StringName] = [&"marlo"]
## A job that must be completed first: the fleet final, so the Lattice ends Act 5.
@export var after_job: StringName = &"fleet_race"
## Living crew tagged can_fly needed for the fleet phase.
@export var min_fleet := 2
## Reclaimed units side by side that open the trench entrance (phase 1).
@export var gap_units := 4
## Seconds the trench stays open once the player is in it (phase 2).
@export var trench_time := 60.0
## The override hold (phase 3): seconds, and the sphere's radius in metres.
@export var hold_time := 10.0
@export var hold_radius := 1.0
## The chorus's lines.
@export_file("*.json") var chorus := "res://data/dialogue/lattice.json"
