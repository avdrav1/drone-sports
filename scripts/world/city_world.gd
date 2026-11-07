class_name CityWorld
extends Node3D
# Story 34.1: a whole free-flight city a job can fly in: towers, streets with
# their clutter, overhead spans, fences, traffic, and rooftops, all built from
# one layout. A job scene instances this and sets `layout`; with a `runner`,
# the cars hold still until the job goes live, so a mission puts them in the
# same places at the same moment of every run.

## The city to build. Unset, the children keep their own (the sandbox layout).
@export var layout: CityLayout
## The job whose live time the traffic follows. Unset, the cars drive at once.
@export var runner: JobRunner

@onready var city: City = $City
@onready var streets: Streets = $Streets
@onready var rooftops: Rooftops = $Rooftops
@onready var traffic: Traffic = $Streets/Traffic

## Before the children build: every one of them gets the same layout.
func _enter_tree() -> void:
	if layout:
		for n in [$City, $Streets, $Rooftops]:
			n.layout = layout

func _ready() -> void:
	if runner:
		traffic.set_physics_process(false)
		runner.state_changed.connect(_on_state_changed)

func _on_state_changed(state: JobRunner.State, _previous: JobRunner.State) -> void:
	if state == JobRunner.State.LIVE:
		traffic.set_physics_process(true)
