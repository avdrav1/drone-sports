extends RefCounted
# Story 14.7: weather sound. Rain's level follows intensity (and moves to the
# roof loop under cover), thunder follows its flash by distance / 343 s, and the
# wind loop's level follows the wind measured at the drone.

const Sim = preload("res://tests/sim.gd")

func _rain(intensity: float) -> Weather:
	var w := Weather.new()
	w.precipitation = Weather.Precipitation.RAIN
	w.intensity = intensity
	return w

## A scene root with a WeatherState; returns its WeatherSound.
func _sound(root: Node3D) -> WeatherSound:
	Sim.add(root)
	return WeatherState.of(root).get_node("Sound")

func test_rain_level_follows_intensity() -> bool:
	var root := Node3D.new()
	var sound := _sound(root)
	var levels := []
	var dbs := []
	var playing := []
	for i in [0.2, 0.5, 0.9]:
		Weather.apply(_rain(i), null, root)
		sound.advance(0.1)
		levels.append(sound.rain_level)
		dbs.append(sound.rain_player.volume_db)
		playing.append(sound.rain_player.playing)
	Weather.apply(null, null, root)
	sound.advance(0.1)
	var dry: bool = sound.rain_level == 0.0 and not sound.rain_player.playing
	var ok: bool = is_equal_approx(levels[0], 0.2) and is_equal_approx(levels[1], 0.5) \
		and is_equal_approx(levels[2], 0.9) and dbs[0] < dbs[1] and dbs[1] < dbs[2] \
		and playing.all(func(p: bool) -> bool: return p) and dry \
		and sound.rain_player.bus == &"Weather"
	if not ok:
		print("        %s %s %s %s" % [levels, dbs, playing, dry])
	root.free()
	return ok

func test_rain_moves_to_the_roof_under_cover() -> bool:
	var root := Node3D.new()
	var sound := _sound(root)
	var d := Sim.drone(Sim.intent(), Vector3(0, 5, 0))
	d.freeze = true
	sound.drone = d
	var roof := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(10, 1, 10)
	shape.shape = box
	roof.add_child(shape)
	root.add_child(roof)
	roof.global_position = Vector3(0, 15, 0)
	await Sim.physics_frames(2)
	Weather.apply(_rain(0.6), null, root)
	sound.advance(1.0)
	var covered: bool = sound.under_roof and is_equal_approx(sound.roof_level, 0.6) \
		and sound.rain_level == 0.0 and sound.roof_player.playing
	roof.free()
	await Sim.physics_frames(2)
	sound.advance(1.0)
	var open: bool = not sound.under_roof and is_equal_approx(sound.rain_level, 0.6) and sound.roof_level == 0.0
	if not (covered and open):
		print("        %s %s" % [covered, open])
	d.free()
	root.free()
	return covered and open

func test_thunder_follows_flash_by_distance() -> bool:
	var root := Node3D.new()
	var sound := _sound(root)
	var lightning: Lightning = WeatherState.of(root).get_node("Lightning")
	Sfx.clear_log()
	var near := Lightning.Strike.new()
	near.position = Vector3(686, 0, 0)  # 2 s away
	var far := Lightning.Strike.new()
	far.position = Vector3(0, 0, -1715)  # 5 s away
	lightning.strike(near)
	lightning.strike(far)
	var flashed: bool = lightning.flash > 0.0 and Sfx.count(&"thunder") == 0
	var heard := []  # seconds after the strikes at which each thunder played
	var t := 0.0
	for i in 60:
		sound.advance(0.1)
		t += 0.1
		while heard.size() < Sfx.count(&"thunder"):
			heard.append(t)
	var gains := Sfx.log.filter(func(l: Dictionary) -> bool: return l.id == &"thunder").map(
		func(l: Dictionary) -> float: return l.gain_db)
	var ok: bool = flashed and heard.size() == 2 \
		and absf(heard[0] - WeatherSound.thunder_delay(686.0)) < 0.11 \
		and absf(heard[1] - WeatherSound.thunder_delay(1715.0)) < 0.11 \
		and is_equal_approx(WeatherSound.thunder_delay(343.0), 1.0) \
		and gains[1] < gains[0] and sound.pending.is_empty()
	if not ok:
		print("        %s %s %s" % [flashed, heard, gains])
	root.free()
	return ok

func test_wind_loop_follows_measured_wind() -> bool:
	var root := Node3D.new()
	var sound := _sound(root)
	var d := Sim.drone(Sim.intent(), Vector3(0, 10, 0))
	d.freeze = true
	sound.drone = d
	var levels := []
	var speeds := []
	var dbs := []
	for speed in [0.0, 3.0, 7.0, 12.0]:
		var w := Wind.new()
		w.base = Vector3(speed, 0, 0)
		d.wind = w
		sound.advance(0.1)
		levels.append(sound.wind_level)
		speeds.append(d.measured_wind().length())
		dbs.append(sound.wind_player.volume_db)
	var ok: bool = levels[0] == 0.0
	for i in range(1, 4):
		ok = ok and is_equal_approx(levels[i], clampf(speeds[i] / sound.full_wind, 0.0, 1.0)) \
			and levels[i] > levels[i - 1] and dbs[i] > dbs[i - 1]
	ok = ok and sound.wind_player.playing and is_equal_approx(sound.wind_speed, speeds[3])
	if not ok:
		print("        %s %s %s" % [levels, speeds, dbs])
	d.free()
	root.free()
	return ok
