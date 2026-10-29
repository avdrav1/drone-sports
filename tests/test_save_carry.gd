extends RefCounted
# Story 24.2: renaming the game moved the desktop user:// folder, so a save left
# in the old folder is carried into the new one at boot: once, never over a
# save already there, and the old file stays. Throwaway folders stand in for
# the real ones.

const Sim = preload("res://tests/sim.gd")

var root := ProjectSettings.globalize_path("user://test_carry")
var old_dir := root.path_join(SaveGame.OLD_NAME)
var new_dir := root.path_join("Jaisalmer")

## Empties the throwaway folders.
func _clear() -> void:
	for dir in [old_dir, new_dir]:
		if not DirAccess.dir_exists_absolute(dir):
			continue
		for file in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir.path_join(file))
		DirAccess.remove_absolute(dir)
	DirAccess.remove_absolute(root)

func _write(file: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(file.get_base_dir())
	var f := FileAccess.open(file, FileAccess.WRITE)
	f.store_string(text)

## Back to the test save, as the runner has it.
func _restore(test_path: String) -> void:
	SaveGame.path = test_path
	SaveGame.load_all(Sim.tree())
	_clear()

func test_an_old_save_is_carried_over_intact() -> bool:
	_clear()
	var test_path := SaveGame.path
	# A career saved under the old name: money, a death, a finished job.
	Wallet.balance = 0
	Wallet.add(3150)
	Wallet.save()
	Roster.kill(&"ozzie")
	Career.job_completed(&"test_race")
	DirAccess.make_dir_recursive_absolute(old_dir)
	DirAccess.copy_absolute(ProjectSettings.globalize_path(test_path), old_dir.path_join("save.json"))
	var old_text := FileAccess.get_file_as_string(old_dir.path_join("save.json"))
	# A fresh launch under the new name, before anything reads the save.
	for section in ["wallet", "roster", "career"]:
		SaveGame.write_section(section, {} if section != "wallet" else 0)
	SaveGame.load_all(Sim.tree())
	var forgot := Wallet.balance == 0 and Roster.is_alive(&"ozzie") and Career.times_completed(&"test_race") == 0
	var copied := SaveGame.carry_over(old_dir, new_dir)
	SaveGame.path = new_dir.path_join("save.json")
	SaveGame.load_all(Sim.tree())
	var same := Wallet.balance == 3150 and not Roster.is_alive(&"ozzie") \
		and Roster.status(&"ozzie") == Roster.Status.DEAD and Career.times_completed(&"test_race") == 1
	var old_kept := FileAccess.get_file_as_string(old_dir.path_join("save.json")) == old_text
	# Once: even with the new save gone (say, set aside as corrupt), it never comes back.
	var again := SaveGame.carry_over(old_dir, new_dir)
	DirAccess.remove_absolute(new_dir.path_join("save.json"))
	var after_loss := SaveGame.carry_over(old_dir, new_dir)
	_restore(test_path)
	Wallet.balance = 0
	Wallet.save()
	return forgot and copied and same and old_kept and not again and not after_loss

func test_a_save_in_the_new_folder_is_left_alone() -> bool:
	_clear()
	_write(old_dir.path_join("save.json"), "{\"wallet\": 10}")
	_write(new_dir.path_join("save.json"), "{\"wallet\": 99}")
	var copied := SaveGame.carry_over(old_dir, new_dir)
	var ok := not copied and FileAccess.get_file_as_string(new_dir.path_join("save.json")) == "{\"wallet\": 99}" \
		and FileAccess.get_file_as_string(old_dir.path_join("save.json")) == "{\"wallet\": 10}" \
		and not FileAccess.file_exists(new_dir.path_join(SaveGame.CARRIED))
	_clear()
	return ok

func test_no_old_save_does_nothing() -> bool:
	_clear()
	var copied := SaveGame.carry_over(old_dir, new_dir)
	var ok := not copied and not DirAccess.dir_exists_absolute(new_dir) and not DirAccess.dir_exists_absolute(old_dir)
	_clear()
	return ok

func test_it_runs_first_at_boot_and_not_under_tests() -> bool:
	var autoloads := ProjectSettings.get_property_list().map(func(p): return p.name) \
		.filter(func(n): return n.begins_with("autoload/"))
	var first := autoloads.all(func(n): return ProjectSettings.get_order(n) >= ProjectSettings.get_order("autoload/SaveCarry"))
	return autoloads.has("autoload/SaveCarry") and first and OS.has_environment(SaveGame.NO_CARRY) \
		and Sim.tree().root.get_child(0).name == "SaveCarry"
