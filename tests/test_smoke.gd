extends RefCounted
# Story 0.2 acceptance: one trivial passing test exists.

func test_runner_works() -> bool:
	return 1 + 1 == 2

func test_project_name() -> bool:
	return ProjectSettings.get_setting("application/config/name") == "Drone Sports"
