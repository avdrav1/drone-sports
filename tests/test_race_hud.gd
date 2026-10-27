extends RefCounted
# Story 3.4: race HUD. Next gate marker stays on screen; split delta is colored.

const Sim = preload("res://tests/sim.gd")
const RIG := preload("res://scenes/camera/camera_rig.tscn")

## Course, a frozen player drone behind gate 0, a camera rig, and the race HUD.
func _setup() -> Array:
	var root := Node3D.new()
	Sim.add(root)
	var course := Course.new()
	course.data = load("res://data/courses/test_loop.tres")
	root.add_child(course)
	var d := Sim.drone(Sim.intent(), Vector3.ZERO)
	d.freeze = true
	d.global_position = course.gates[0].global_transform * Vector3(0, 0, 6)
	course.add_racer(d)
	var rig: CameraRig = RIG.instantiate()
	rig.target = d
	root.add_child(rig)
	rig.camera.make_current()
	var hud := RaceHud.new()
	hud.course = course
	hud.racer = d
	hud.camera_rig = rig
	root.add_child(hud)
	return [root, course, d, rig, hud]

func _free(s: Array) -> void:
	s[2].free()
	s[0].free()

func test_marker_on_screen_when_gate_ahead() -> bool:
	var s := _setup()
	await Sim.process_frames(3)
	var m: Dictionary = s[4].marker()
	var rect: Rect2 = s[4].get_viewport_rect()
	var ok: bool = m.on_screen and rect.has_point(m.pos)
	_free(s)
	return ok

func test_marker_at_edge_pointing_when_gate_behind() -> bool:
	var s := _setup()
	var d: Drone = s[2]
	# Turn around: gate 0 is now behind the chase camera.
	d.rotate_y(PI)
	s[3].set_view(CameraRig.View.CHASE)
	await Sim.process_frames(3)
	var hud: RaceHud = s[4]
	var m: Dictionary = hud.marker()
	var rect := hud.get_viewport_rect()
	var p: Vector2 = m.pos
	var e := hud.margin() + 1.0
	var at_edge := p.x <= e or p.y <= e or p.x >= rect.size.x - e or p.y >= rect.size.y - e
	var ok: bool = not m.on_screen and rect.has_point(p) and at_edge
	_free(s)
	return ok

## Flies a stand-in racer around one lap, waiting `slow` extra frames at each gate.
func _lap(c: Course, r: Node3D, slow: int) -> void:
	for i in range(1, c.gates.size()) + [0]:
		var g: Gate = c.gates[i]
		r.global_position = g.global_transform * Vector3(0, 20, 1.5)
		await Sim.physics_frames(1 + slow)
		r.global_position = g.global_transform * Vector3(0, 0, 1.5)
		await Sim.physics_frames(1)
		r.global_position = g.global_transform * Vector3(0, 0, -1.5)
		await Sim.physics_frames(1)

## Two laps by a plain stand-in racer (a frozen body can lag hand placement by a frame).
func _split_after(first_slow: int, second_slow: int) -> Array:
	var s := _setup()
	var course: Course = s[1]
	var hud: RaceHud = s[4]
	var r := Node3D.new()
	s[0].add_child(r)
	r.global_position = course.gates[0].global_transform * Vector3(0, 0, 4)
	course.add_racer(r)
	hud.racer = r
	course.start()
	r.global_position = course.gates[0].global_transform * Vector3(0, 0, 1.5)
	await Sim.physics_frames(2)
	r.global_position = course.gates[0].global_transform * Vector3(0, 0, -1.5)
	await Sim.physics_frames(2)
	await _lap(course, r, first_slow)
	await _lap(course, r, second_slow)
	return s

func test_split_green_when_faster_than_best() -> bool:
	var s := await _split_after(3, 0)
	var hud: RaceHud = s[4]
	var ok := hud.split_delta < 0.0 and hud.split_color() == RaceHud.AHEAD and hud.split_visible()
	_free(s)
	return ok

func test_split_red_when_slower_than_best() -> bool:
	var s := await _split_after(0, 3)
	var hud: RaceHud = s[4]
	var ok := hud.split_delta > 0.0 and hud.split_color() == RaceHud.BEHIND
	_free(s)
	return ok

func test_position_and_lap_text() -> bool:
	var s := _setup()
	var hud: RaceHud = s[4]
	var ok: bool = hud.position_text() == "1/1" and hud.lap_text() == "1/2"
	_free(s)
	return ok
