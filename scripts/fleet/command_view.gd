class_name CommandView
extends Node3D
# The fleet layer: a top-down camera over the fleet. Click a drone to select it
# (or Tab / Shift+Tab, RB / LB, through them, wrapping both ways), click the
# ground to queue a waypoint for it. The job's own action (X on a pad) sends the
# selected drone: a relay leg, or to tag a Lattice unit. F (A) drops
# into the selected drone: it takes the pilot's sticks and assists, and the
# camera rig flies with it in first person. F again hands it back to its
# autopilot, which carries on with its queue. Replaces the single-drone view
# once the Act 5 preset turns that off.

signal selected_changed(drone: Drone)
signal waypoint_queued(drone: Drone, point: Vector3)
signal dropped_in(drone: Drone)
signal left(drone: Drone)
## The number of drones under command changed (MusicDirector sizes the choir by it).
signal fleet_changed(count: int)

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

## Drone -> the crew member flying it, shown as a portrait by its ring (7.7),
## which shows their distress and loses signal when the drone is down (18.10).
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
	MusicDirector.command(self)

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
	# Shift+Tab also matches Tab's next_drone, so the previous drone is asked first.
	elif event.is_action_pressed("prev_drone"):
		_cycle(-1)
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
		DroneFace.wear(d, pilot)
	if selected == null:
		select(d)
	fleet_changed.emit(drones.size())

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
	fleet_changed.emit(drones.size())

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

## Selects the drone `step` along the fleet, wrapping at either end.
func _cycle(step := 1) -> void:
	if drones.is_empty():
		return
	var at := drones.find(selected)
	if at < 0:
		# Nothing selected: forwards starts at the first, backwards at the last.
		at = -1 if step > 0 else 0
	select(drones[posmod(at + step, drones.size())])

## The colour `d`'s ring and name are drawn in: its livery's light colour
## (Story 27.6), so each drone in the fleet can be told apart.
static func mark_color(d: Drone) -> Color:
	var look := d.get_node_or_null("Look") as DroneLook if is_instance_valid(d) else null
	var c: Color = look.worn().light_color if look else DroneLook.ACCENT
	return Color(c, 1.0)

## The portrait shown for `d` in the overlay, or null.
func portrait(d: Drone) -> CharacterPortrait:
	return $Overlay.get_child(0).portraits.get(d)

## Rings on the drones, each in its drone's light colour (the selected one
## wider, in a white halo), each pilot's portrait, and lines through each queue.
class _Overlay extends Control:
	const RING := Color(1, 1, 1, 0.75)
	const LIT := Color(1.0, 0.76, 0.25)
	## Each pilot's face by their drone, twice its old 34 px (Story 26.3).
	const FACE := 68.0
	## How far above the drone a face's bottom sits, over the name drawn at -18.
	const NAME_CLEAR := 34.0
	## The drone names' font size.
	const NAME_SIZE := 13
	## Space kept between two faces.
	const GAP := 4.0
	## Where a face's centre may sit from its drone, in order of choice: over
	## the name, then fanned out around the ring, further each time round.
	var spots: Array[Vector2] = _spots()
	var _hud_nodes: Array[Control] = []

	static func _spots() -> Array[Vector2]:
		var out: Array[Vector2] = [Vector2(0, -FACE * 0.5 - NAME_CLEAR)]
		for reach in [FACE * 0.5 + NAME_CLEAR, FACE * 1.1 + NAME_CLEAR, FACE * 1.7 + NAME_CLEAR, FACE * 2.3 + NAME_CLEAR]:
			for deg in [-90, -45, -135, 0, 180, 45, 135, 90, -67.5, -112.5, -22.5, -157.5, 22.5, 157.5, 67.5, 112.5]:
				out.append(Vector2.from_angle(deg_to_rad(deg)) * reach)
		return out
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
		var shown: Array[Drone] = []
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
				# Story 18.10: distress and signal lost for the pilot's drone.
				CrewDistress.watch(face, d, view.runner)
			var p: CharacterPortrait = portraits[d]
			p.visible = is_instance_valid(d) and cam.is_inside_tree() and not cam.is_position_behind(d.global_position)
			if p.visible:
				shown.append(d)
		_lay_out(shown)

	## Every drone's ring and name as drawn, which no face may cover.
	func marks() -> Array[Rect2]:
		var out: Array[Rect2] = []
		var cam := view.camera
		if not cam.is_inside_tree():
			return out
		var font := get_theme_default_font()
		for d in view.drones:
			if not is_instance_valid(d) or cam.is_position_behind(d.global_position):
				continue
			var at := cam.unproject_position(d.global_position)
			out.append(Rect2(at - Vector2.ONE * 16.0, Vector2.ONE * 32.0))
			var w := minf(font.get_string_size(d.name, HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_SIZE).x, 80.0)
			out.append(Rect2(at.x - w * 0.5, at.y - 18.0 - font.get_ascent(NAME_SIZE), w, font.get_height(NAME_SIZE)))
		return out

	## The HUD's text and panels over the fleet, which no face may cover either.
	func _hud() -> Array[Rect2]:
		var out: Array[Rect2] = []
		var scene := view.owner if view.owner else view.get_parent()
		if scene == null:
			return out
		if _hud_nodes.is_empty():
			for c in scene.find_children("*", "Control", true, false):
				if c is Label or c is RichTextLabel or c is BarkBox or c is PanelContainer:
					_hud_nodes.append(c)
		for c in _hud_nodes:
			if not is_instance_valid(c):
				continue
			if c is BarkBox:
				# Its panel, kept clear even between lines so faces don't jump
				# when one comes in.
				var r := BarkBox.panel_rect(c.size)
				out.append(Rect2(c.get_global_rect().position + r.position, r.size))
			elif c.is_visible_in_tree():
				out.append(c.get_global_rect())
		return out

	## Faces go by their drones, each in the first free spot: over the name
	## when it is clear, else fanned around the ring, so no face covers another,
	## a name, a ring or the HUD (Story 26.3). The selected drone's face picks
	## first.
	func _lay_out(shown: Array[Drone]) -> void:
		var cam := view.camera
		var screen := get_viewport_rect().grow(-4.0).abs()
		var busy: Array[Rect2] = marks()
		busy.append_array(_hud())
		var order := shown.duplicate()
		if view.selected in order:
			order.erase(view.selected)
			order.push_front(view.selected)
		for d in order:
			var at := cam.unproject_position(d.global_position)
			var best := Rect2()
			var least := INF
			for spot in spots:
				var r := Rect2(at + spot - Vector2.ONE * FACE * 0.5, Vector2.ONE * FACE)
				var cost := 0.0
				if screen.has_area() and not screen.encloses(r):
					cost += r.get_area() - screen.intersection(r).get_area() + 1.0
				for b in busy:
					var hit := r.intersection(b)
					if hit.has_area():
						cost += hit.get_area()
				if cost < least:
					least = cost
					best = r
				if cost == 0.0:
					break
			portraits[d].position = best.position
			busy.append(best.grow(GAP))

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
			var mark := CommandView.mark_color(d)
			draw_arc(at, 14.0 if lit else 10.0, 0.0, TAU, 24, mark, 3.0 if lit else 2.0)
			if lit:
				draw_arc(at, 16.5, 0.0, TAU, 24, Color.WHITE, 1.5)
			# A face moved off its drone keeps a thin line back to the ring.
			var face: CharacterPortrait = portraits.get(d)
			if face and face.visible:
				var c := face.position + face.size * 0.5
				var home := at + spots[0]
				if c.distance_to(home) > 1.0:
					var dir := at.direction_to(c)
					draw_line(at + dir * 16.0, c - dir * FACE * 0.45, LIT if lit else RING, 1.0)
			# The name in the same colour, on a dark shadow so a dark light colour reads.
			var font := get_theme_default_font()
			draw_string(font, at + Vector2(-39, -17), d.name, HORIZONTAL_ALIGNMENT_CENTER, 80, NAME_SIZE, Color(0, 0, 0, 0.7))
			draw_string(font, at + Vector2(-40, -18), d.name, HORIZONTAL_ALIGNMENT_CENTER, 80, NAME_SIZE, mark)
