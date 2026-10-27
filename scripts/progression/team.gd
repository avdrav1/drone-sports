class_name Team
extends Resource
# A team that can recruit the pilot (Epic 5). Joining one grants its assist
# preset; its job types decide what the job board offers. Data only.

const FACTIONS: Array[StringName] = [&"league", &"city", &"salvage"]

@export var id: StringName
@export var name := ""
## One of FACTIONS. Reputation with it is what gets the pilot noticed.
@export var faction: StringName
## Job types this team takes on, matching Job.job_type.
@export var job_types: Array[StringName] = []
## Faction reputation at which the team makes an offer.
@export var reputation_needed := 0
## A story flag that makes the team ask, e.g. scouted. When set, it replaces
## the reputation check.
@export var needs_flag: StringName
## The assists the pilot flies with on this team.
@export var preset: AssistStack
## Cutscene played once on joining, e.g. the recruitment scene. Empty for none.
@export_file("*.tscn") var joining_scene := ""
## One line for the offer and the job board.
@export var blurb := ""

## Problems with this resource given the job types that exist; empty when valid.
func validate(known_types: Array) -> Array[String]:
	var out: Array[String] = []
	if id == &"" or name.is_empty():
		out.append("%s: needs an id and a name" % id)
	if not faction in FACTIONS:
		out.append("%s: unknown faction %s" % [id, faction])
	if job_types.is_empty():
		out.append("%s: takes no job types" % id)
	for t in job_types:
		if not t in known_types:
			out.append("%s: no job of type %s" % [id, t])
	if reputation_needed < 0:
		out.append("%s: negative reputation needed" % id)
	if preset == null:
		out.append("%s: grants no assist preset" % id)
	return out
