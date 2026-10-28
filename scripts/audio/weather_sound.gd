class_name WeatherSound
extends Node
# Weather you hear (Story 14.7). WeatherState adds one beside Rain, Snow, and
# Lightning, so every scene with weather sounds like it. Rain loops at a level
# set by intensity, and turns to rain drumming on a roof while something is
# overhead of the drone. A wind loop follows the wind measured where the drone
# is (what the air is doing, whether or not the sim lets it push). Snow hushes
# the mix: the place's Ambience loops and the wind crossfade to baked muffled
# copies, since the web build has no live filters, and so does the music
# (Music.hush, Story 16.8). Thunder follows each lightning strike after the
# time sound takes to arrive: distance / 343 s.
# Sound only; nothing here touches flight.

const RAIN := &"weather_rain"
const ROOF := &"weather_rain_roof"
const WIND := &"weather_wind"
const THUNDER := &"thunder"
## Metres per second.
const SPEED_OF_SOUND := 343.0
## Below this linear level a loop is stopped rather than played silent.
const SILENT := 0.001

## Wind speed, m/s, where the wind loop reaches full level.
@export var full_wind := 14.0
## How far overhead a roof still counts, m.
@export var roof_height := 60.0
## Seconds to move between open rain and rain on a roof.
@export var roof_time := 0.5
## Seconds for snow's hush to settle in or lift.
@export var hush_time := 3.0
## Thunder this close or nearer plays at full gain, m.
@export var thunder_near := 300.0

## The drone listened for; null follows the camera rig's target.
var drone: Drone
## Linear levels, 0..1, of the loops as last mixed.
var rain_level := 0.0
var roof_level := 0.0
var wind_level := 0.0
## Measured wind speed at the drone, m/s.
var wind_speed := 0.0
## 0 to 1: how far snow has hushed the mix.
var hush := 0.0
## True while something is overhead of the drone.
var under_roof := false
## Thunder on its way: {due (s on this node's clock), distance (m)}.
var pending: Array[Dictionary] = []

var rain_player: AudioStreamPlayer
var roof_player: AudioStreamPlayer
var wind_player: AudioStreamPlayer
var wind_muffled: AudioStreamPlayer
var _roof_mix := 0.0
var _time := 0.0
var _db := {}  # event id -> volume_db
var _muffled_db := 0.0
var _ambience: Array[Ambience] = []
var _ambience_age := INF

func _ready() -> void:
	rain_player = _loop(RAIN)
	roof_player = _loop(ROOF)
	wind_player = _loop(WIND)
	var e := Sfx.bank.find(WIND) if Sfx.bank else null
	if e and e.muffled:
		wind_muffled = _player("WindMuffled", e.muffled, e.bus)
		_muffled_db = e.volume_db + e.muffled_db
	var lightning := get_parent().get_node_or_null(^"Lightning") as Lightning if get_parent() else null
	if lightning:
		lightning.struck.connect(_on_struck)

func _exit_tree() -> void:
	for a in _ambience:
		if is_instance_valid(a):
			a.hush = 0.0
	Music.hush = 0.0

func _process(delta: float) -> void:
	advance(delta)

## One step: levels from the weather and the drone, snow's hush, thunder due.
func advance(delta: float) -> void:
	_time += delta
	var w := _weather()
	var d := _listener_drone()
	var rain := 0.0
	var snow := 0.0
	if w:
		if w.precipitation == Weather.Precipitation.RAIN:
			rain = w.intensity
		elif w.precipitation == Weather.Precipitation.SNOW:
			snow = w.intensity
	under_roof = rain > 0.0 and d != null and _roof_over(d)
	var step := delta / roof_time if roof_time > 0.0 else 1.0
	_roof_mix = move_toward(_roof_mix, 1.0 if under_roof else 0.0, step)
	rain_level = rain * (1.0 - _roof_mix)
	roof_level = rain * _roof_mix
	wind_speed = d.measured_wind().length() if d else 0.0
	wind_level = clampf(wind_speed / full_wind, 0.0, 1.0)
	hush = move_toward(hush, snow, delta / hush_time if hush_time > 0.0 else 1.0)
	if not is_equal_approx(Music.hush, hush):
		Music.hush = hush
	_level(rain_player, RAIN, rain_level)
	_level(roof_player, ROOF, roof_level)
	if wind_muffled:
		var on := wind_level > SILENT
		_set_db(wind_player, _db.get(WIND, 0.0), wind_level * sqrt(1.0 - hush), on)
		# Both copies start and stop on the same frame, so they stay in step.
		_set_db(wind_muffled, _muffled_db, wind_level * sqrt(hush), on)
	else:
		_level(wind_player, WIND, wind_level)
	if wind_player:
		wind_player.pitch_scale = 0.85 + 0.3 * wind_level
		if wind_muffled:
			wind_muffled.pitch_scale = wind_player.pitch_scale
	_hush_ambience(delta)
	_thunder()

## Seconds thunder takes to arrive from a strike `distance` m away.
static func thunder_delay(distance: float) -> float:
	return distance / SPEED_OF_SOUND

func _on_struck(s: Lightning.Strike) -> void:
	var distance := s.position.distance_to(_listener_position())
	pending.append({"due": _time + thunder_delay(distance), "distance": distance})

func _thunder() -> void:
	var i := 0
	while i < pending.size():
		var t: Dictionary = pending[i]
		if t.due <= _time:
			pending.remove_at(i)
			var far: float = maxf(t.distance, thunder_near) / thunder_near
			Sfx.play(THUNDER, null, -10.0 * log(far) / log(10.0))
		else:
			i += 1

func _weather() -> Weather:
	var state := get_parent() as WeatherState
	return state.weather if state else null

func _listener_drone() -> Drone:
	if is_instance_valid(drone):
		return drone
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	var rig := camera.get_parent() as CameraRig if camera else null
	if rig and is_instance_valid(rig.target):
		return rig.target as Drone
	return null

func _listener_position() -> Vector3:
	var d := _listener_drone()
	if d and d.is_inside_tree():
		return d.global_position
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	if camera:
		return camera.global_position
	var scope := get_parent().get_parent() as Node3D if get_parent() else null
	return scope.global_position if scope and scope.is_inside_tree() else Vector3.ZERO

## True when a body is overhead of `d` within roof_height.
func _roof_over(d: Drone) -> bool:
	if not d.is_inside_tree():
		return false
	var from := d.global_position + Vector3.UP * 0.3
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.UP * roof_height)
	q.exclude = [d.get_rid()]
	q.collide_with_areas = false
	return not d.get_world_3d().direct_space_state.intersect_ray(q).is_empty()

## Snow's hush on every Ambience in the scene (looked up again each second).
func _hush_ambience(delta: float) -> void:
	_ambience_age += delta
	if _ambience_age >= 1.0:
		_ambience_age = 0.0
		_ambience.clear()
		var scope := get_parent().get_parent() if get_parent() else null
		if scope:
			for n in scope.find_children("*", "Ambience", true, false):
				_ambience.append(n as Ambience)
	for a in _ambience:
		if is_instance_valid(a) and not is_equal_approx(a.hush, hush):
			a.hush = hush

func _loop(id: StringName) -> AudioStreamPlayer:
	var e := Sfx.bank.find(id) if Sfx.bank else null
	if e == null or e.streams.is_empty():
		push_warning("WeatherSound: no sound event '%s'" % id)
		return null
	_db[id] = e.volume_db
	return _player(String(id).to_pascal_case(), e.streams[0], e.bus)

func _player(node_name: String, stream: AudioStream, bus: StringName) -> AudioStreamPlayer:
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	var p := AudioStreamPlayer.new()
	p.name = node_name
	p.stream = stream
	p.bus = bus
	add_child(p)
	return p

func _level(p: AudioStreamPlayer, id: StringName, level: float) -> void:
	if p:
		_set_db(p, _db.get(id, 0.0), level, level > SILENT)

## `level` (linear) on top of `base_db`; plays while `on`, stops otherwise.
func _set_db(p: AudioStreamPlayer, base_db: float, level: float, on: bool) -> void:
	if p == null:
		return
	p.volume_db = base_db + linear_to_db(maxf(level, 0.0001))
	if on and not p.playing:
		p.play()
	elif not on and p.playing:
		p.stop()
