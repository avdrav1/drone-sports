class_name JobResult
extends RefCounted
# What happened on a job, for the results screen.

var job: Job
var completed := false
var fail_reason := ""
var score := 0.0
var letter := "F"
## Seconds flown live, and crashes in them (Story 27.3's achievements).
var time := 0.0
var crashes := 0
## True when a completed job beat the best grade flown on it before (Story 18.3).
var new_best := false
## One entry per objective: {label, score, weight}.
var objectives: Array[Dictionary] = []
var pay := 0
var reputation_change := 0
## Crew perks paid on top (Story 19.5), already in pay and reputation_change:
## {id, text, amount, unit}, e.g. {"text": "Bhima's site rates", "amount": 18, "unit": ""}.
var bonuses: Array[Dictionary] = []
## Character id -> strikes landed on them this job.
var strikes := {}
## Character id -> Roster.Status after this job's strikes (injured or dead).
var casualties := {}
## Character id -> the line shown beside their casualty on the results screen.
var casualty_lines := {}
## Hangar items this job opened by achievement (Story 27.3), in catalog order.
var unlocks: Array[Unlock] = []
## The closing line for the results screen: {id, text}. Empty when nobody speaks.
var bark := {}
## The final crew pass after the Lattice (Story 8.6): {id, text, alive} for
## every crew member, the dead with their memorial line.
var epilogue: Array[Dictionary] = []
