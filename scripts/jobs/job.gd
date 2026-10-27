class_name Job
extends Resource
# What a job is, as data. The scene that flies it holds a JobRunner pointing here.

## How much of the route the radar, map, and world ribbon show.
enum Guidance { FULL, NEXT_LEG, NONE }

@export var id: StringName
@export var title := ""
## Who is paying, as shown to the player.
@export var client := ""
## What kind of job, e.g. race or demolition. Teams take on job types (Epic 5).
@export var job_type: StringName
## Faction whose reputation this job moves.
@export var faction: StringName
## Assists the drone flies with. Expert mode still overrides it.
@export var required_assists: AssistStack
## Seconds of live flying before the job fails. 0 means no limit.
@export var time_limit := 0.0
@export var pay := 0
## Seconds of countdown between Briefing and Live.
@export var countdown := 3.0
## Camera view set on Briefing.
@export var default_view := CameraRig.View.CHASE
## Objective weights by objective node name. Overrides each objective's own weight.
@export var weights := {}
## Free-form tags, e.g. act1 for the home-game framing.
@export var tags: Array[StringName] = []
## Route display: the whole route, the next leg only, or nothing. Not an assist.
@export var guidance := Guidance.FULL
## Characters at risk on this job; each needs a HazardZone. Empty means nobody can be struck.
@export var crew_in_field: Array[StringName] = []
## Fog and wind. Null flies clear and still.
@export var weather: Weather
