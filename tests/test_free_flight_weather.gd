extends RefCounted
# Story 4.6: weather in free flight. E cycles clear, fog bank, whiteout, clear;
# the HUD names it; clear brings back the scene's own sky and breeze.

const Sim = preload("res://tests/sim.gd")
const ENV := preload("res://data/world/golden_hour.tres")

func _press(scene: Node) -> void:
	var ev := InputEventAction.new()
	ev.action = &"cycle_weather"
	ev.pressed = true
	scene.get_viewport().push_input(ev)

func test_e_cycles_weather_and_back_to_clear() -> bool:
	var s: Node = Sim.add(load("res://scenes/debug_flight.tscn").instantiate())
	await Sim.process_frames(2)
	var d: Drone = s.get_node("Drone")
	var hud: FlightHud = s.get_node("HUD/Flight")
	var env_node: WorldEnvironment = s.find_children("*", "WorldEnvironment", true, false)[0]
	var breeze := d.wind
	var base := ENV.fog_density
	var fog: Weather = load("res://data/weather/fog_bank.tres")
	var white: Weather = load("res://data/weather/whiteout.tres")
	var clear_start: bool = env_node.environment == ENV and breeze != null and not hud.subtitle.contains("Fog")
	_press(s)
	var fogged: bool = is_equal_approx(env_node.environment.fog_density, fog.fog_density) and d.wind == fog.wind \
		and hud.subtitle.contains("Fog bank")
	_press(s)
	var whited: bool = is_equal_approx(env_node.environment.fog_density, white.fog_density) and d.wind == white.wind \
		and hud.subtitle.contains("Whiteout")
	_press(s)
	var cleared: bool = env_node.environment == ENV and d.wind == breeze and not hud.subtitle.contains("Whiteout")
	var ok: bool = clear_start and fogged and whited and cleared and ENV.fog_density == base \
		and ControlsHelp.key_text(&"cycle_weather") == "E"
	if not ok:
		print("        %s %s %s %s" % [clear_start, fogged, whited, cleared])
	s.free()
	return ok
