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
	var short := below_grade(b).size()
	if short > 0:
		out.append("%s on every mission first, %d to go" % [b.min_grade, short])
	for id in b.required_characters:
		var c: Character = Roster.character(id)
		if c and not Roster.is_alive(id):
			out.append("%s is gone" % c.name)
	var fleet := FleetCrew.flyers().size()
	if fleet < b.min_fleet:
		out.append("needs %d crew who fly, %d left" % [b.min_fleet, fleet])
	return out

## Board missions whose best grade is not yet `b.min_grade` or better.
static func below_grade(b: Boss) -> Array[Job]:
	var out: Array[Job] = []
	if b.min_grade == "":
		return out
	for job in (load("res://data/jobs/board.tres") as JobList).jobs:
		# Letters run A (best) to F, so a better grade sorts first.
		if not Career.grades.has(job.id) or Career.grades[job.id] > b.min_grade:
			out.append(job)
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
