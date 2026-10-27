extends SceneTree
# Minimal test runner. Loads every res://tests/test_*.gd, instantiates it,
# and calls each method whose name starts with "test_". A method passes
# unless it returns false or the engine logs an error while it runs.
# Test methods may await (e.g. physics frames); the runner awaits them.
# Exit code 1 if anything fails.

var _errors: Array = []

# Tests never touch the player's save.
const TEST_SAVE := "user://test_run_save.json"

func _initialize() -> void:
	_run()

func _run() -> void:
	# Let the root viewport enter the tree before any test adds nodes.
	await process_frame
	_install_error_logger()
	_use_test_save()
	var passed := 0
	var failed := 0
	var dir := DirAccess.open("res://tests")
	if dir == null:
		push_error("tests/ directory not found")
		quit(1)
		return
	for file in dir.get_files():
		if not (file.begins_with("test_") and file.ends_with(".gd")):
			continue
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
			_errors.clear()
			_fresh_roster()
			var result = await suite.call(name)
			if result == false or not _errors.is_empty():
				failed += 1
				print("FAIL  %s::%s" % [file, name])
				for e in _errors:
					print("        error: %s" % e)
			else:
				passed += 1
				print("ok    %s::%s" % [file, name])
		if suite is Node:
			suite.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	print("\n%d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)

func _use_test_save() -> void:
	SaveGame.path = TEST_SAVE
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	SaveGame.load_all(self)

## Strikes injure and kill for good, and offers and teams stick, so every test
## starts with the whole crew alive, no flags, no reputation, no team, and a stock drone.
func _fresh_roster() -> void:
	for section in ["roster", "career", "flags", "reputation", "upgrades"]:
		SaveGame.write_section(section, {})
	for autoload in ["Roster", "Career", "Reputation", "Garage"]:
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
