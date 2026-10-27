class_name JobResult
extends RefCounted
# What happened on a job, for the results screen.

var job: Job
var completed := false
var fail_reason := ""
var score := 0.0
var letter := "F"
## One entry per objective: {label, score, weight}.
var objectives: Array[Dictionary] = []
var pay := 0
var reputation_change := 0
## Character id -> strikes landed on them this job.
var strikes := {}
## Character id -> Roster.Status after this job's strikes (injured or dead).
var casualties := {}
## Character id -> the line shown beside their casualty on the results screen.
var casualty_lines := {}
## The closing line for the results screen: {id, text}. Empty when nobody speaks.
var bark := {}
