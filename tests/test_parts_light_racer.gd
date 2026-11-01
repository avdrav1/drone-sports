extends RefCounted
# Story 27.4: every job still finishes with the light racer fitted. In its own
# file so scripts/test.sh can give this long run a process of its own.

const Parts := preload("res://tests/test_parts.gd")

func test_every_job_finishes_with_the_light_racer() -> bool:
	return await Parts.new().every_job_finishes_with(&"light_racer")
