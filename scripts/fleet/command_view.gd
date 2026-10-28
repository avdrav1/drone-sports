class_name CommandView
extends Node3D
# The fleet layer: a top-down camera over the fleet. Click a drone to select it
# (or Tab through them), click the ground to queue a waypoint for it. F drops
# into the selected drone: it takes the pilot's sticks and assists, and the
# camera rig flies with it in first person. F again hands it back to its
# autopilot, which carries on with its queue. Replaces the single-drone view
# once the Act 5 preset turns that off.

signal selected_changed(drone: Drone)
signal waypoint_queued(drone: Drone, point: Vector3)
signal dropped_in(drone: Drone)
signal left(drone: Drone)

## The fleet: Drone scenes, each with an Autopilot as its intent source.
@export var drones: Array[Drone] = []
## Flies the dropped-in drone. Its camera shows while a drone is flown.
@export var camera_rig: CameraRig
## Over the fleet, metres.
@export var height := 70.0
## Waypoints sit this far above the clicked ground, m.
@export var waypoint_altitude := 10.0
## What the camera looks down on; the fleet's centre when unset.
@export var focus: Node3D
## A fleet job's runner: the fleet holds still until Live, on its autopilots.
@export var runner: JobRunner

## Drone -> the crew member flying it, shown as a portrait by its ring (7.7).
var pilots := {}
var selected: Drone
## The drone being flown by hand, or null when commanding.
var flown: Drone

@onready var camera: Camera3D = $Camera
@onready var pilot: PilotInput = $PilotInput

func _ready() -> void:
	camera.far = 4000.0
	camera.make_current()
	var overlay := _Overlay.new()
	overlay.view = self
	$Overlay.add_child(overlay)
	if not drones.is_empty():
		select(drones[0])
	_place_camera()
	if runner:
		runner.state_changed.connect(_on_runner_state)

func _on_runner_state(state: JobRunner.State, _previous: JobRunner.State) -> void:
	match state:
		JobRunner.State.BRIEFING:
			# The runner gave its drone the job's assists; fleet drones fly their own.
			for d in drones:
				d.freeze = true
				if d != flown:
					Autopilot.of(d).engage()
		JobRunner.State.LIVE:
			for d in drones:
				d.freeze = false

func _process(_delta: float) -> void:
	if not flown:
		_place_camera()

func _place_camera() -> void:
	var at := focus.global_position if focus else centre()
	camera.global_position = at + Vector3.UP * height
	camera.look_at(at, Vector3.FORWARD)

## Middle of the fleet on the ground.
func centre() -> Vector3:
	if drones.is_empty():
		return Vector3.ZERO
	var sum := Vector3.ZERO
	for d in drones:
		sum += d.global_position
	sum /= drones.size()
	return Vector3(sum.x, 0.0, sum.z)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("drop_in"):
		leave() if flown else drop_in()
	elif flown:
		return
	elif event.is_action_pressed("next_drone"):
		_cycle()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		click(event.position)
	else:
		return
	get_viewport().set_input_as_handled()

## Adds a drone to the fleet, e.g. one freed from the Lattice.
func add(d: Drone, pilot: Character = null) -> void:
	drones.append(d)
	if pilot:
		pilots[d] = pilot
	if selected == null:
		select(d)

## Takes a drone out of the fleet: lost, captured, or gone.
func remove(d: Drone) -> void:
	if d == flown:
		leave()
	drones.erase(d)
	pilots.erase(d)
	var overlay := $Overlay.get_child(0)
	if overlay.portraits.has(d):
		overlay.portraits[d].queue_free()
		overlay.portraits.erase(d)
	if d == selected:
		selected = null
		if not drones.is_empty():
			select(drones[0])

func select(d: Drone) -> void:
	if d == selected:
		return
	selected = d
	selected_changed.emit(d)

## A click at a screen point: selects the drone under it, or queues a waypoint
## for the selected drone where it lands on anything else.
func click(screen: Vector2) -> void:
	var from := camera.project_ray_origin(screen)
	var to := from + camera.project_ray_normal(screen) * camera.far
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to))
	if hit.is_empty():
		return
	if hit.collider is Drone and hit.collider in drones:
		select(hit.collider)
	elif selected:
		var p: Vector3 = hit.position + Vector3.UP * waypoint_altitude
		Autopilot.of(selected).queue(p)
		waypoint_queued.emit(selected, p)

## The selected drone takes the pilot's input and assists; the rig flies with it.
func drop_in() -> void:
	if selected == null:
		return
	flown = selected
	pilot.reparent(flown)
	pilot.reset()
	flown.intent_source = pilot
	flown.assists.apply_stack(GameSettings.effective_stack(Career.preset()))
	if camera_rig:
		camera_rig.target = flown
		camera_rig.set_view(CameraRig.View.FPV)
		camera_rig.camera.make_current()
	dropped_in.emit(flown)

## Hands the flown drone back to its autopilot and returns to the top-down view.
func leave() -> void:
	if flown == null:
		return
	var d := flown
	var auto := Autopilot.of(d)
	d.intent_source = auto
	auto.engage()
	pilot.reparent(self)
	flown = null
	camera.make_current()
	left.emit(d)

func _cycle() -> void:
	if drones.is_empty():
		return
	select(drones[(drones.find(selected) + 1) % drones.size()])

## The portrait shown for `d` in the overlay, or null.
func portrait(d: Drone) -> CharacterPortrait:
	return $Overlay.get_child(0).portraits.get(d)

## Rings on the drones (the selected one lit), each pilot's portrait, and lines
## through each queue.
class _Overlay extends Control:
	const RING := Color(1, 1, 1, 0.75)
	const LIT := Color(1.0, 0.76, 0.25)
	const FACE := 34.0
	var view: CommandView
	## Drone -> CharacterPortrait.
	var portraits := {}

	func _ready() -> void:
		set_anchors_preset(PRESET_FULL_RECT)
		mouse_filter = MOUSE_FILTER_IGNORE

	func _process(_delta: float) -> void:
		visible = view.flown == null
		_place_portraits()
		queue_redraw()

	func _place_portraits() -> void:
		var cam := view.camera
		for d in view.drones:
			if not view.pilots.has(d):
				continue
			if not portraits.has(d):
				var face := CharacterPortrait.new()
				face.character = view.pilots[d]
				face.custom_minimum_size = Vector2.ONE * FACE
				face.size = Vector2.ONE * FACE
				face.mouse_filter = MOUSE_FILTER_IGNORE
				add_child(face)
				portraits[d] = face
			var p: CharacterPortrait = portraits[d]
			p.visible = is_instance_valid(d) and cam.is_inside_tree() and not cam.is_position_behind(d.global_position)
			if p.visible:
				p.position = cam.unproject_position(d.global_position) + Vector2(16, -FACE - 6)

	func _draw() -> void:
		var cam := view.camera
		if not cam.is_inside_tree():
			return
		for d in view.drones:
			if not is_instance_valid(d) or cam.is_position_behind(d.global_position):
				continue
			var lit := d == view.selected
			var at := cam.unproject_position(d.global_position)
			var auto := Autopilot.of(d)
			if auto and not auto.done():
				var prev := at
				for i in range(auto.index, auto.waypoints.size()):
					if cam.is_position_behind(auto.waypoints[i]):
						break
					var p := cam.unproject_position(auto.waypoints[i])
					draw_line(prev, p, LIT if lit else RING, 1.5)
					draw_circle(p, 3.0, LIT if lit else RING)
					prev = p
			draw_arc(at, 14.0 if lit else 10.0, 0.0, TAU, 24, LIT if lit else RING, 2.0)
			draw_string(get_theme_default_font(), at + Vector2(-40, -18), d.name, HORIZONTAL_ALIGNMENT_CENTER, 80, 13, LIT if lit else RING)
