class_name Achievement
extends Resource
# Story 27.3: something the pilot does that opens a hangar item. Data, checked
# at each job's results (Hangar.earn): a job completed, completed under a time
# or with no crashes, a best payout reached, a reputation level with a faction,
# a story flag, or the fleet first flown.

enum Kind { JOB_DONE, JOB_TIME, JOB_CLEAN, BEST_PAY, REPUTATION, STORY_FLAG, FLEET_FLOWN }

const JOBS := "res://data/jobs/board.tres"
## Set the first time a fleet job goes live (FleetCrew).
const FLEET_FLAG := &"fleet_flown"

@export var kind := Kind.JOB_DONE
## JOB_DONE, JOB_TIME, JOB_CLEAN: the job's id.
@export var job: StringName
## JOB_TIME: finished in this many seconds of live time or fewer.
@export var seconds := 0.0
## BEST_PAY: the payout; REPUTATION: the level.
@export var amount := 0
## REPUTATION: one of Team.FACTIONS.
@export var faction: StringName
## STORY_FLAG: the flag.
@export var flag: StringName
## STORY_FLAG: what the pilot does, e.g. "get scouted by a team". Other kinds
## name themselves.
@export var label := ""

## True when it is met now. `result` is the job just flown, for the kinds that
## ask how it went (a time, no crashes); the others read the save.
func met(result: JobResult = null) -> bool:
	match kind:
		Kind.JOB_DONE:
			return Career.times_completed(job) > 0
		Kind.JOB_TIME:
			return _this_job(result) and result.time <= seconds
		Kind.JOB_CLEAN:
			return _this_job(result) and result.crashes == 0
		Kind.BEST_PAY:
			return Wallet.best_pay >= amount
		Kind.REPUTATION:
			return Reputation.of(faction) >= amount
		Kind.STORY_FLAG:
			return StoryFlags.is_set(flag)
		Kind.FLEET_FLOWN:
			return StoryFlags.is_set(FLEET_FLAG)
	return false

func _this_job(result: JobResult) -> bool:
	return result != null and result.completed and result.job != null and result.job.id == job

## What to do, from a lower-case verb: "finish Parcel to the pad in under 40 s".
func describe() -> String:
	match kind:
		Kind.JOB_DONE:
			return "finish %s" % job_title()
		Kind.JOB_TIME:
			return "finish %s in under %d s" % [job_title(), roundi(seconds)]
		Kind.JOB_CLEAN:
			return "finish %s with no crashes" % job_title()
		Kind.BEST_PAY:
			return "earn %d on one job" % amount
		Kind.REPUTATION:
			return "reach %d reputation with %s" % [amount, String(faction).capitalize()]
		Kind.STORY_FLAG:
			return label
		Kind.FLEET_FLOWN:
			return "fly a fleet job"
	return ""

func job_title() -> String:
	var j: Job = (load(JOBS) as JobList).by_id(job)
	return j.title if j else String(job)

## Problems with this achievement; empty when it is valid.
func validate() -> Array[String]:
	var out: Array[String] = []
	match kind:
		Kind.JOB_DONE, Kind.JOB_TIME, Kind.JOB_CLEAN:
			if (load(JOBS) as JobList).by_id(job) == null:
				out.append("no job on the board called %s" % job)
			if kind == Kind.JOB_TIME and seconds <= 0.0:
				out.append("%s: a time needs its seconds" % job)
		Kind.BEST_PAY:
			if amount <= 0:
				out.append("a best payout needs its amount")
		Kind.REPUTATION:
			if not faction in Team.FACTIONS or amount <= 0:
				out.append("a reputation level needs one of %s and a level" % [Team.FACTIONS])
		Kind.STORY_FLAG:
			if flag == &"" or label.is_empty():
				out.append("a story flag needs its flag and a label")
	return out
