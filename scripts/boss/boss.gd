class_name Boss
extends Resource
# The Lattice as data (docs/BOSS.md). `enabled` is the feature flag: when false
# the job never reaches the board and nothing under scenes/boss/ is loaded.

@export var enabled := true
## The boss job. Its scene is a path, so loading this never loads the scene.
@export var job: Job
## Crew who must be alive to attempt it.
@export var required_characters: Array[StringName] = [&"sanjaya"]
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

@export_group("Shell")
## Outer radius of the sphere, m.
@export var radius := 60.0
## The shell, outside in: the lid over the trench, the trench, its floor.
@export var lid := 3.0
@export var tunnel_height := 8.0
@export var floor := 3.0
@export var trench_width := 10.0
## How far round the trench runs from the entrance to the shutter, degrees.
@export var trench_arc := 120.0
## Units in the outer layer; inner layers scale with their area.
@export var unit_count := 2400
## A captured drone's size in the shell, as a multiple of a real one.
@export var unit_scale := 9.0
@export var core_radius := 6.0
## Seeds which units hold the crew's lost drones.
@export var seed := 7
