class_name BossGate
extends RefCounted
# Whether the Lattice shows on the job board and whether it can be flown. Every
# boss scene load goes through open(), which records it, so a test can prove a
# disabled boss never loads anything.

const DATA := "res://data/boss/lattice.tres"

## The boss in play; tests may set their own.
static var boss: Boss
## Paths opened through open(), oldest first.
static var loads: Array[String] = []

static func data() -> Boss:
	if boss == null:
		boss = load(DATA)
	return boss

## On the board at all.
static func listed() -> bool:
	var b := data()
	return b != null and b.enabled and b.job != null

## Why it cannot be flown yet; empty when it can.
static func reasons() -> Array[String]:
	var out: Array[String] = []
	var b := data()
	if b == null:
		return out
	if b.after_job != &"" and Career.times_completed(b.after_job) == 0:
		var before: Job = (load("res://data/jobs/board.tres") as JobList).by_id(b.after_job)
		out.append("fly %s first" % (before.title if before else String(b.after_job)))
	for id in b.required_characters:
		var c: Character = Roster.character(id)
		if c and not Roster.is_alive(id):
			out.append("%s is gone" % c.name)
	var fleet := FleetCrew.flyers().size()
	if fleet < b.min_fleet:
		out.append("needs %d crew who fly, %d left" % [b.min_fleet, fleet])
	return out

static func flyable() -> bool:
	return listed() and reasons().is_empty()

## Changes to the boss job's scene, if it can be flown.
static func open(tree: SceneTree) -> bool:
	if not flyable():
		return false
	loads.append(data().job.scene)
	tree.change_scene_to_file(data().job.scene)
	return true
