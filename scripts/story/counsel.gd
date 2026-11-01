class_name Counsel
extends Resource
# Story 30.10: Krishna's counsel, the launch confirmation for the final job.
# Arjuna hesitates; Sanjaya relays the counsel on duty, on acting without
# clinging to the outcome, and on the crew who stand with you. The lines change
# with the vows kept per thread and the crew lost, both read from the save. The
# final job is the boss's while it is enabled and the fleet final otherwise, and
# then nothing here names the boss. A dead speaker never speaks (rule 7): the
# counsel shows as text with no speaker.

const DEITIES := "res://data/deities/deities.tres"

## Whose counsel it is (Krishna).
@export var deity: Deity
## Who relays it, a character id.
@export var speaker: StringName = &"sanjaya"
## The dialog's title.
@export var dialog_title := ""
## Above the lines: while the speaker lives, and with no speaker.
@export var heading := ""
@export var heading_unspoken := ""
## The job it plays before while the boss is enabled, and the one otherwise.
@export var boss_job: StringName = &"lattice"
@export var final_job: StringName = &"fleet_race"
## Arjuna's pause before each; the fleet final's names no boss.
@export_multiline var hesitation_boss := ""
@export_multiline var hesitation_final := ""
## On duty and on acting without clinging to the outcome.
@export var lines_duty: Array[String] = []
## Deity id -> the line for a thread with a vow kept, in the Four's order.
@export var kept_lines := {}
## In place of the kept lines when every thread has a vow kept, or none has.
@export var all_kept := ""
@export var none_kept := ""
## The crew who stand with you: while none has died, and once any has
## ({names} is who).
@export var crew_whole := ""
@export var crew_lost := ""
@export var closing := ""
@export var launch_text := "Launch"
@export var decline_text := "Not yet"

## The job the counsel plays before.
func job_id() -> StringName:
	return boss_job if BossGate.listed() else final_job

func applies_to(job: Job) -> bool:
	return job != null and job.id == job_id()

## Whether the speaker is alive to relay it.
func spoken() -> bool:
	return Roster.is_alive(speaker)

func title() -> String:
	return heading if spoken() else heading_unspoken

## Every line, in order, for `job` and the save as it stands.
func lines(job: Job) -> Array[String]:
	var out: Array[String] = []
	out.append(hesitation_boss if job and job.id == boss_job else hesitation_final)
	out.append_array(lines_duty)
	var kept: Array[String] = []
	for d in (load(DEITIES) as DeityList).deities:
		if Vows.kept(d.id) > 0 and kept_lines.has(String(d.id)):
			kept.append(kept_lines[String(d.id)])
	if kept.is_empty():
		out.append(none_kept)
	elif kept.size() == kept_lines.size():
		out.append(all_kept)
	else:
		out.append_array(kept)
	var lost := dead_names()
	out.append(crew_whole if lost.is_empty() else crew_lost.format({"names": LaunchDialog._and(lost)}))
	out.append(closing)
	return out

## The names of the crew who have died, in roster order.
static func dead_names() -> Array[String]:
	var out: Array[String] = []
	for id in Roster.ids():
		if Roster.status(id) == Roster.Status.DEAD:
			var c: Character = Roster.character(id)
			out.append(c.name if c else String(id))
	return out
