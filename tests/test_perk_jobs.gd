extends RefCounted
# Story 19.6: guidance and recovery. With Sanjaya fit, the runner shows a job's
# route a step better than its data says; with Sushena fit, an injury benches
# for one job instead of two. Neither touches grading.

const Sim = preload("res://tests/sim.gd")

class Fixed extends Objective:
	func score() -> float:
		return 0.8

func _race(g: Job.Guidance) -> Node:
	var scene: Node = load("res://scenes/jobs/test_race.tscn").instantiate()
	var runner: JobRunner = scene.get_node("JobRunner")
	runner.job = runner.job.duplicate()
	runner.job.guidance = g
	return Sim.add(scene)

## [guided points, radar dots shown, job's own guidance] on a next-leg race.
func _next_leg_race() -> Array:
	var scene := _race(Job.Guidance.NEXT_LEG)
	await Sim.process_frames(3)
	var route: RouteSource = scene.get_node("Route")
	var map: MapScreen = scene.get_node("MapLayer/Map")
	var out := [route.guided().size(), map.route_chart().size(), (scene.get_node("JobRunner") as JobRunner).job.guidance]
	scene.free()
	return out

func test_sanjaya_fit_shows_the_full_route_on_a_next_leg_job() -> bool:
	var fit: Array = await _next_leg_race()
	Roster.injure(&"sanjaya")
	var benched: Array = await _next_leg_race()
	Roster.kill(&"sanjaya")
	var dead: Array = await _next_leg_race()
	# The whole loop is the drone plus every gate, as a full-guidance race shows
	# it; the next leg is two points.
	var full := _race(Job.Guidance.FULL)
	await Sim.process_frames(3)
	var loop := (full.get_node("Route") as RouteSource).guided().size()
	full.free()
	return loop > 2 and fit[0] == loop and fit[1] == loop and benched[0] == 2 and benched[1] == 2 \
		and dead[0] == 2 and dead[1] == 2 \
		and fit[2] == Job.Guidance.NEXT_LEG and dead[2] == Job.Guidance.NEXT_LEG

func test_sanjaya_raises_none_to_next_leg_and_full_stays_full() -> bool:
	var none := _race(Job.Guidance.NONE)
	await Sim.process_frames(3)
	var runner: JobRunner = none.get_node("JobRunner")
	var raised := runner.guidance() == Job.Guidance.NEXT_LEG and (none.get_node("Route") as RouteSource).guided().size() == 2
	runner.job.guidance = Job.Guidance.FULL
	var full := runner.guidance() == Job.Guidance.FULL
	none.free()
	var data_untouched := (load("res://data/jobs/rescue.tres") as Job).guidance == Job.Guidance.NONE
	return raised and full and data_untouched

func test_sushena_fit_benches_for_one_job() -> bool:
	Roster.injure(&"bhima")
	var one := Roster.jobs_benched(&"bhima") == 1
	Roster.job_done()
	var back := Roster.status(&"bhima") == Roster.Status.ACTIVE
	# Sushena's own injury uses the normal two.
	Roster.injure(&"sushena")
	var own := Roster.jobs_benched(&"sushena") == Roster.INJURY_JOBS
	# With Sushena benched, two.
	Roster.injure(&"sanjaya")
	var benched := Roster.jobs_benched(&"sanjaya") == 2
	return one and back and own and benched

func test_sushena_dead_benches_for_two() -> bool:
	Roster.kill(&"sushena")
	Roster.injure(&"nala")
	return Roster.jobs_benched(&"nala") == 2 and Roster.injury_jobs(&"nala") == 2

func _grade() -> JobResult:
	var j: Job = load("res://data/jobs/test_job.tres").duplicate()
	j.countdown = 0.1
	j.guidance = Job.Guidance.NEXT_LEG
	var root := Sim.job_setup(j, [Fixed.new()])
	var runner: JobRunner = root.get_node("Runner")
	runner.pays_out = false
	await Sim.go_live(root)
	runner.complete()
	var r := runner.result
	root.free()
	return r

func test_grading_is_unchanged_by_either_perk() -> bool:
	var fit: JobResult = await _grade()
	Roster.injure(&"sanjaya")
	Roster.injure(&"sushena")
	var benched: JobResult = await _grade()
	return fit.letter == benched.letter and fit.score == benched.score and fit.letter == "B"
