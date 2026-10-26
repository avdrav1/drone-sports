extends SceneTree
# Minimal test runner. Loads every res://tests/test_*.gd, instantiates it,
# and calls each method whose name starts with "test_". A method passes
# unless it returns false. Exit code 1 if anything fails.

func _init() -> void:
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
		var suite = script.new()
		for m in suite.get_method_list():
			var name: String = m.name
			if not name.begins_with("test_"):
				continue
			var result = suite.call(name)
			if result == false:
				failed += 1
				print("FAIL  %s::%s" % [file, name])
			else:
				passed += 1
				print("ok    %s::%s" % [file, name])
		if suite is Node:
			suite.free()
	print("\n%d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)
