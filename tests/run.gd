extends SceneTree
# Minimal test runner. Loads every res://tests/test_*.gd, instantiates it,
# and calls each method whose name starts with "test_". A method passes
# unless it returns false or the engine logs an error while it runs.
# Test methods may await (e.g. physics frames); the runner awaits them.
# Exit code 1 if anything fails.
# ONLY=test_foo,test_song_* in the environment runs just those files (`*` is a
# wildcard); scripts/test.sh uses it to split a full run across processes.
# Each test's and file's time goes in the log for test.sh to rank.

var _errors: Array = []

# Tests never touch the player's save.
## DRONE_TEST_SAVE names another file, so two checkouts can test at once.
var TEST_SAVE: String = OS.get_environment("DRONE_TEST_SAVE") if OS.has_environment("DRONE_TEST_SAVE") else "user://test_run_save.json"

func _initialize() -> void:
	# Before the autoloads boot, and for every Godot a test starts: no carrying
	# the player's old save (Story 24.2).
	OS.set_environment(SaveGame.NO_CARRY, "1")
	_run()

func _run() -> void:
	# Let the root viewport enter the tree before any test adds nodes.
	await process_frame
	# Tests open the title already past its PLAY; test_title_screen.gd asks for it.
	# (Loaded here, not named: the title's script needs the autoloads to compile.)
	load("res://scripts/ui/title_screen.gd").needs_play = false
	_install_error_logger()
	_use_test_save()
	var passed := 0
	var failed := 0
	var dir := DirAccess.open("res://tests")
	if dir == null:
		push_error("tests/ directory not found")
		quit(1)
		return
	var picked := select(dir.get_files(), OS.get_environment("ONLY"))
	# A mistyped name must not pass as a short green run.
	for pattern in picked.unmatched:
		failed += 1
		print("FAIL  ONLY names no test file: %s" % pattern)
	for file in picked.files:
		var file_start := Time.get_ticks_msec()
		var script: GDScript = load("res://tests/" + file)
		if script == null or not script.can_instantiate():
			failed += 1
			print("FAIL  %s (does not load)" % file)
			continue
		var suite = script.new()
		for m in suite.get_method_list():
			var name: String = m.name
			if not name.begins_with("test_"):
				continue
			# Every test starts inside a physics tick, before the nodes' own step. A
			# flight test relies on it: a drone it adds flies in that same tick.
			# Otherwise where a test starts hangs on how the one before it finished.
			await physics_frame
			_errors.clear()
			var start := Time.get_ticks_msec()
			_fresh_roster()
			var result = await suite.call(name)
			var ms := Time.get_ticks_msec() - start
			if result == false or not _errors.is_empty():
				failed += 1
				print("FAIL  %s::%s [%d ms]" % [file, name, ms])
				for e in _errors:
					print("        error: %s" % e)
			else:
				passed += 1
				print("ok    %s::%s [%d ms]" % [file, name, ms])
		if suite is Node:
			suite.free()
		print("file  %s [%d ms]" % [file, Time.get_ticks_msec() - file_start])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_probe_save()))
	print("\n%d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)

## The test files in `files` that `only` (comma-separated names without .gd, `*`
## a wildcard) picks, all of them if it is empty, and the patterns that matched
## nothing.
static func select(files: PackedStringArray, only: String) -> Dictionary:
	var tests := PackedStringArray()
	for file in files:
		if file.begins_with("test_") and file.ends_with(".gd"):
			tests.append(file)
	if only.strip_edges().is_empty():
		return {"files": tests, "unmatched": PackedStringArray()}
	var patterns := only.split(",", false)
	var kept := PackedStringArray()
	var used := {}
	for file in tests:
		for pattern in patterns:
			if file.get_basename().match(pattern.strip_edges()):
				used[pattern] = true
				if not kept.has(file):
					kept.append(file)
	var unmatched := PackedStringArray()
	for pattern in patterns:
		if not used.has(pattern):
			unmatched.append(pattern.strip_edges())
	return {"files": kept, "unmatched": unmatched}

func _use_test_save() -> void:
	SaveGame.path = TEST_SAVE
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	SaveGame.load_all(self)
	OS.set_environment("DRONE_PROBE_SAVE", _probe_save())

## The save for the render probes this process starts (they inherit its
## environment), so two test processes never share one.
func _probe_save() -> String:
	return TEST_SAVE + ".probe"

## Strikes injure and kill for good, and offers and teams stick, so every test
## starts with the whole crew alive, no flags, no reputation, no team, a stock drone,
## a stock ride (Story 27.1), no pilot chosen, and no vows kept (Story 30.5).
func _fresh_roster() -> void:
	for section in ["roster", "career", "flags", "reputation", "upgrades", "hangar", "profile", "vows"]:
		SaveGame.write_section(section, {})
	for autoload in ["Roster", "Career", "Reputation", "Garage", "Hangar"]:
		var node := root.get_node_or_null(autoload)
		if node:
			node.load_saved()

# Godot 4.5+ can route engine errors to a script Logger. Older engines skip this.
func _install_error_logger() -> void:
	if not ClassDB.class_exists("Logger"):
		return
	var logger = load("res://tests/error_logger.gd").new()
	logger.sink = _errors
	OS.call("add_logger", logger)
