extends RefCounted
# Story 30.7: Brahma's vow of making. In the briefing of a job offering it, the
# map plans a path of up to eight points (keys, pad or mouse); the vow is kept
# when the drone passes them in order. Planning is unavailable elsewhere, the
# path shows on the map and the radar, and guidance and grading are unchanged.

const Sim = preload("res://tests/sim.gd")
const MAKING := "res://data/vows/making.tres"
const RESCUE := "res://scenes/jobs/rescue.tscn"
const DELIVERY := "res://scenes/jobs/sample_delivery.tscn"
## Three points well away from the drone's pad and from each other.
const PATH := [Vector3(0, 0, -40), Vector3(40, 0, -80), Vector3(-40, 0, -120)]

func _making() -> Vow:
	return load(MAKING)

func _scene(path: String) -> Node:
	var s: Node = load(path).instantiate()
	var runner: JobRunner = s.get_node("JobRunner")
	runner.pays_out = false
	runner.results_scene = null
	runner.back_scene = ""
	Sim.add(s)
	return s

func _map(s: Node) -> MapScreen:
	return s.get_node("MapLayer/Map")

## Opens the map and places PATH through its cursor, as the player does.
func _plan(s: Node) -> bool:
	var map := _map(s)
	if not map.visible:
		map.toggle()
	for p in PATH:
		map.cursor = map.to_chart(p)
		map.press()
	return map.runner.plan.size() == PATH.size()

## Launches with `vow` made through the dialog, then holds the drone so the
## test can set where it is.
func _launch_with(runner: JobRunner, vow: Vow) -> bool:
	runner.request_launch()
	await Sim.process_frames(1)
	var d := runner.launch_dialog
	if d and d.visible:
		for i in d.vows.size():
			if d.vows[i] == vow:
				d.boxes[i].button_pressed = true
		d.hide()
		d.confirmed.emit()
	while runner.state == JobRunner.State.COUNTDOWN:
		await Sim.physics_frames(1)
	runner.drone.freeze = true
	return runner.state == JobRunner.State.LIVE and runner.vow == vow

## Flies over PATH's points in `order` (indices), a few ticks over each.
func _visit(runner: JobRunner, order: Array) -> void:
	for i in order:
		runner.drone.global_position = PATH[i] + Vector3(3, 15, 0)
		await Sim.physics_frames(3)
		# Away again, between points.
		runner.drone.global_position = Vector3(90, 15, 0)
		await Sim.physics_frames(2)

## A rescue with PATH planned and the vow made, flown in `order`, completed.
func _fly(order: Array) -> JobResult:
	var s := _scene(RESCUE)
	await Sim.process_frames(2)
	var runner: JobRunner = s.get_node("JobRunner")
	var ok := _plan(s)
	ok = ok and await _launch_with(runner, _making())
	await _visit(runner, order)
	runner.complete()
	var r := runner.result
	s.free()
	return r if ok else null

func test_the_vow_of_making_is_brahmas_and_offered_from_act_4() -> bool:
	var v := _making()
	var four: DeityList = load("res://data/deities/deities.tres")
	var ok: bool = v.deity == four.by_id(&"brahma") and v.kind == &"making" and v.text != "" \
		and v.title() == "The vow of making" and v.max_points == 8 and v.pass_radius > 0.0
	ok = ok and v in (load("res://data/jobs/rescue.tres") as Job).vows
	var early := ["res://data/assists/act1.tres", "res://data/assists/act2.tres", "res://data/assists/act3.tres"]
	for f in DirAccess.get_files_at("res://data/jobs"):
		var j = load("res://data/jobs/" + f) if f.ends_with(".tres") else null
		if j is Job and v in j.vows and j.required_assists and j.required_assists.resource_path in early:
			print("        %s offers making before Act 4" % f)
			ok = false
	return ok

func test_three_points_passed_in_order_keep_the_vow() -> bool:
	var r := await _fly([0, 1, 2])
	return r != null and r.vow == _making() and r.vow_kept

func test_out_of_order_does_not_keep_the_vow() -> bool:
	var r := await _fly([0, 2, 1])
	var reversed := await _fly([2, 1, 0])
	return r != null and r.vow != null and not r.vow_kept and reversed != null and not reversed.vow_kept

func test_a_missed_point_does_not_keep_the_vow() -> bool:
	var r := await _fly([0, 2])
	return r != null and r.vow != null and not r.vow_kept

func test_planning_is_unavailable_on_jobs_without_the_vow() -> bool:
	var s := _scene(DELIVERY)
	await Sim.process_frames(2)
	var runner: JobRunner = s.get_node("JobRunner")
	var map := _map(s)
	map.toggle()
	map.cursor = map.to_chart(PATH[0])
	map.press()
	var ok: bool = runner.state == JobRunner.State.BRIEFING and runner.making_vow() == null \
		and not runner.can_plan() and not map.planning() and runner.place_point(PATH[1]) == -1 \
		and runner.plan.is_empty() and not _making() in runner.offered_vows()
	s.free()
	# And on the rescue, the vow is not offered until a path is made, and no
	# planning once the job is in flight.
	s = _scene(RESCUE)
	await Sim.process_frames(2)
	runner = s.get_node("JobRunner")
	ok = ok and runner.can_plan() and not _making() in runner.offered_vows()
	ok = ok and _plan(s) and _making() in runner.offered_vows()
	runner.launch(true)
	ok = ok and not runner.can_plan() and runner.place_point(PATH[0]) == -1 and runner.plan.size() == 3 \
		and not _map(s).planning()
	s.free()
	return ok

func test_place_move_and_remove_up_to_eight_points() -> bool:
	var s := _scene(RESCUE)
	await Sim.process_frames(2)
	var runner: JobRunner = s.get_node("JobRunner")
	var map := _map(s)
	map.toggle()
	var r := map.chart_rect()
	for i in 10:
		map.cursor = r.position + Vector2(20 + i * 30, 40)
		map.press()
	var ok: bool = runner.plan.size() == 8
	# Pick up the second point and put it down elsewhere.
	map.cursor = map.to_chart(runner.plan[1])
	map.press()
	map.cursor = r.position + Vector2(200, 200)
	map.press()
	ok = ok and runner.plan.size() == 8 and map.to_chart(runner.plan[1]).distance_to(r.position + Vector2(200, 200)) < 1.0
	# Remove the point under the cursor, then the last with none under it.
	map.remove()
	ok = ok and runner.plan.size() == 7 and map.to_chart(runner.plan[1]).distance_to(r.position + Vector2(80, 40)) < 1.0
	map.cursor = r.end - Vector2(5, 5)
	map.remove()
	ok = ok and runner.plan.size() == 6
	s.free()
	return ok

func _key(code: Key, down := true) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = down
	return e

func _button(b: JoyButton, down := true) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = b
	e.pressed = down
	return e

## Presses and releases `press` as the player does, through the viewport.
func _tap(at: Node, press: InputEvent, release: InputEvent) -> void:
	at.get_viewport().push_input(press)
	at.get_viewport().push_input(release)
	await Sim.process_frames(1)

## Keys and pad both plan (Epic 23): the flight stick or arrows move the cursor,
## the accept key or A places, the reset key or button removes, and none of it
## launches the job.
func test_keys_and_pad_both_plan() -> bool:
	var s := _scene(RESCUE)
	await Sim.process_frames(2)
	var runner: JobRunner = s.get_node("JobRunner")
	var map := _map(s)
	map.toggle()
	var r := map.chart_rect()
	map.cursor = r.position + r.size * 0.1
	var start := map.cursor
	Input.action_press(&"roll_right")
	await Sim.process_frames(10)
	Input.action_release(&"roll_right")
	var ok: bool = map.cursor.x > start.x and is_equal_approx(map.cursor.y, start.y)
	await _tap(map, _key(KEY_SPACE), _key(KEY_SPACE, false))
	ok = ok and runner.plan.size() == 1
	map.cursor = r.position + r.size * 0.5
	await _tap(map, _button(JOY_BUTTON_A), _button(JOY_BUTTON_A, false))
	ok = ok and runner.plan.size() == 2
	await _tap(map, _key(KEY_R), _key(KEY_R, false))
	ok = ok and runner.plan.size() == 1
	map.cursor = r.position + r.size * 0.9
	await _tap(map, _button(JOY_BUTTON_A), _button(JOY_BUTTON_A, false))
	var reset_pad := -1
	for e in InputMap.action_get_events(&"reset_drone"):
		if e is InputEventJoypadButton:
			reset_pad = e.button_index
	ok = ok and reset_pad >= 0 and runner.plan.size() == 2
	await _tap(map, _button(reset_pad as JoyButton), _button(reset_pad as JoyButton, false))
	ok = ok and runner.plan.size() == 1
	ok = ok and runner.state == JobRunner.State.BRIEFING and (runner.launch_dialog == null or not runner.launch_dialog.visible)
	s.free()
	# Leave the prompts on keys, as the other tests expect.
	InputPrompt.use_keys()
	return ok

func test_the_planned_line_shows_on_map_and_radar() -> bool:
	var s := _scene(RESCUE)
	await Sim.process_frames(2)
	var runner: JobRunner = s.get_node("JobRunner")
	var map := _map(s)
	var radar: Radar = s.get_node("HUD/Radar")
	var ok := _plan(s)
	var line := map.plan_chart()
	ok = ok and line.size() == 3 and line[0].distance_to(map.to_chart(PATH[0])) < 1.0
	ok = ok and await _launch_with(runner, _making())
	runner.drone.global_position = Vector3(0, 15, -10)
	await Sim.process_frames(2)
	ok = ok and radar.runner == runner and not radar.plan_dots().is_empty() and map.plan_chart().size() == 3
	s.free()
	return ok

## One rescue flown over PATH in order, with the path planned and the vow
## made or neither: [guidance, score, letter, objectives, vow kept].
func _run(vowed: bool) -> Array:
	var s := _scene(RESCUE)
	await Sim.process_frames(2)
	var runner: JobRunner = s.get_node("JobRunner")
	if vowed:
		_plan(s)
	await _launch_with(runner, _making() if vowed else null)
	await _visit(runner, [0, 1, 2])
	var guidance := runner.guidance()
	runner.live_time = 20.0
	runner.complete()
	var r := runner.result
	s.free()
	return [guidance, r.score, r.letter, r.objectives, r.vow_kept]

## The vow and its path change no guidance and no grade.
func test_guidance_and_grading_are_unchanged() -> bool:
	var plain := await _run(false)
	var vowed := await _run(true)
	if plain.slice(0, 4) != vowed.slice(0, 4):
		print("        %s vs %s" % [plain, vowed])
	return plain.slice(0, 4) == vowed.slice(0, 4) and vowed[4] and not plain[4]
