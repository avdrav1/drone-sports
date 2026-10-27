extends Node
# Autoload "Career": which team the pilot flies for and which offers they have
# had. No team is Act 1, the home game. An offer is made once per team, ever:
# accepting or declining it, the team never asks again.

signal offer_made(team: Team)
signal team_changed(team: Team)

const TEAMS := "res://data/teams/teams.tres"
const HOME_PRESET := "res://data/assists/act1.tres"

var teams: TeamList
## Current team id; empty in Act 1.
var team_id: StringName = &""
## Team ids ever offered, accepted or not.
var offered: Array[StringName] = []
## Offers made and not yet answered, in order.
var pending: Array[StringName] = []
## Job id -> times completed.
var completed := {}

func _ready() -> void:
	teams = load(TEAMS)
	# Settings are a static class with no node of their own; the career brings them in.
	GameSettings.load_saved()
	load_saved()

func team() -> Team:
	return teams.by_id(team_id) if team_id != &"" else null

## The assists the pilot has earned: the team's preset, or Act 1 at home.
func preset() -> AssistStack:
	var t := team()
	return t.preset if t else load(HOME_PRESET)

## E.g. "Act 2  ·  Skyline Juniors", or "Act 1  ·  Home game".
func label() -> String:
	var t := team()
	return "%s  ·  %s" % [preset().label, t.name if t else "Home game"]

func act() -> int:
	return int(preset().label.trim_prefix("Act "))

## Would `t` make an offer now? It must never have offered, want a pilot this
## good (a later act than now), and see the faction reputation it needs, or for
## a team with `needs_flag`, that story flag.
func wants(t: Team) -> bool:
	if t.id in offered or t.id == team_id or Consequences.faction_locked(t.faction):
		return false
	# A pilot whose own faction is locked will take a team of the same act.
	if int(t.preset.label.trim_prefix("Act ")) < act() + (0 if team_locked() else 1):
		return false
	# A scout's team asks on the flag alone: they already saw the run.
	if t.needs_flag != &"":
		return StoryFlags.is_set(t.needs_flag)
	return Reputation.of(t.faction) >= t.reputation_needed

## Make every offer now due. Returns the new ones. Offers from a faction
## locked since are withdrawn.
func check_offers() -> Array[Team]:
	pending = pending.filter(func(p): return teams.by_id(p) == null or not Consequences.faction_locked(teams.by_id(p).faction))
	var made: Array[Team] = []
	for t in teams.teams:
		if wants(t):
			offered.append(t.id)
			pending.append(t.id)
			made.append(t)
	if not made.is_empty():
		save()
		for t in made:
			offer_made.emit(t)
	return made

func pending_offers() -> Array[Team]:
	var out: Array[Team] = []
	for id in pending:
		out.append(teams.by_id(id))
	return out

## Join the team. Its preset applies from the next drone that flies.
func accept(id: StringName) -> void:
	if not id in pending:
		return
	pending.erase(id)
	team_id = id
	# A team made earlier may now be beneath the pilot.
	pending = pending.filter(func(p): return wants_still(teams.by_id(p)))
	save()
	team_changed.emit(team())

func decline(id: StringName) -> void:
	pending.erase(id)
	save()

## Jobs the pilot may fly now: the current team's job types, or the home
## game's tagged jobs in Act 1. Never a locked faction's job or one whose
## required crew is dead (Story 7.6). A pilot left on a locked faction's team
## keeps its assists and flies the home game's jobs too, so the career goes on.
func can_fly(job: Job) -> bool:
	if not Consequences.listed(job) or not Consequences.missing_crew(job).is_empty():
		return false
	var t := team()
	var home := job.tags.has(&"act1")
	if t == null:
		return home
	return job.job_type in t.job_types or (home and team_locked())

## The pilot's own team is in a faction a death has locked.
func team_locked() -> bool:
	var t := team()
	return t != null and Consequences.faction_locked(t.faction)

## Names of the teams that fly this kind of job, for a locked job's row.
func unlocked_by(job: Job) -> Array[String]:
	var out: Array[String] = []
	for t in teams.teams:
		if job.job_type in t.job_types and not Consequences.faction_locked(t.faction):
			out.append(t.name)
	return out

func wants_still(t: Team) -> bool:
	return int(t.preset.label.trim_prefix("Act ")) > act()

## A job finished as complete; saved at once.
func job_completed(job_id: StringName) -> void:
	completed[job_id] = times_completed(job_id) + 1
	save()

func times_completed(job_id: StringName) -> int:
	return completed.get(job_id, 0)

func save() -> void:
	var done := {}
	for id in completed:
		done[String(id)] = completed[id]
	SaveGame.write_section("career", {"team": String(team_id), "completed": done,
		"offered": offered.map(func(s): return String(s)), "pending": pending.map(func(s): return String(s))})

func load_saved() -> void:
	var saved = SaveGame.read_section("career", {})
	if not saved is Dictionary:
		saved = {}
	team_id = StringName(saved.get("team", ""))
	if teams and team_id != &"" and teams.by_id(team_id) == null:
		team_id = &""
	completed.clear()
	var done = saved.get("completed", {})
	if done is Dictionary:
		for id in done:
			completed[StringName(id)] = int(done[id])
	offered.assign(saved.get("offered", []).map(func(s): return StringName(s)))
	pending.assign(saved.get("pending", []).map(func(s): return StringName(s)))
