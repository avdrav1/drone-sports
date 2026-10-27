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
