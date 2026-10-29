extends RefCounted
# Story 5.4: save game. Wallet, reputation, team, completed jobs, and the expert
# toggle survive a relaunch, and the job board comes back exactly; a corrupt
# file starts a new game with a warning instead of crashing.

const Sim = preload("res://tests/sim.gd")
const BOARD := "res://scenes/ui/job_board.tscn"

## Everything the board shows, as text.
func _snapshot() -> Array:
	var b: JobBoard = load(BOARD).instantiate()
	Sim.add(b)
	var out := [b._header.text, b.money_text()]
	for id in b.job_rows:
		var row: Node = b.job_rows[id]
		out.append([id, (row.get_child(0).get_node("Details") as Label).text, b.fly_button(id) != null])
	for id in b.crew_rows:
		out.append([id, (b.crew_rows[id].get_node("Info/Status") as Label).text])
	b.free()
	return out

## In-memory state as a fresh launch has it before reading the save.
func _forget() -> void:
	Wallet.balance = 0
	Reputation.by_faction.clear()
	Career.team_id = &""
	Career.completed.clear()
	Career.offered.clear()
	GameSettings.expert_all_assists_off = false

func test_relaunch_restores_the_board_exactly() -> bool:
	Wallet.balance = 0
	Wallet.add(2400)
	Wallet.save()
	Reputation.add(&"city", 14)
	Reputation.save()
	StoryFlags.set_flag(&"scouted")
	Career.check_offers()
	Career.accept(&"skyline_juniors")
	Career.job_completed(&"test_race")
	Career.job_completed(&"test_race")
	Roster.injure(&"nala")
	GameSettings.expert_all_assists_off = true
	GameSettings.save()
	var before := _snapshot()
	_forget()
	SaveGame.load_all(Sim.tree())
	var after := _snapshot()
	var expert := GameSettings.expert_all_assists_off
	GameSettings.expert_all_assists_off = false
	GameSettings.save()
	Wallet.balance = 0
	Wallet.save()
	var race: Array = before.filter(func(r): return r is Array and r[0] == &"test_race")[0]
	return before == after and expert and before[0].contains("Skyline Juniors") and before[1].contains("2400") \
		and race[1].contains("done 2×") and race[2]

func test_completing_a_job_saves_it() -> bool:
	var root := Sim.job_setup(load("res://data/jobs/sample_delivery.tres"))
	var runner: JobRunner = root.get_node("Runner")
	runner.results_scene = null
	await Sim.go_live(root)
	runner.complete()
	var saved = SaveGame.read_section("career", {}).get("completed", {})
	root.free()
	Wallet.balance = 0
	Wallet.save()
	return saved.get("sample_delivery", 0) == 1 and Career.times_completed(&"sample_delivery") == 1

func test_corrupt_file_is_a_new_game_with_a_warning() -> bool:
	Wallet.add(500)
	Wallet.save()
	var f := FileAccess.open(SaveGame.path, FileAccess.WRITE)
	f.store_string("{ this is not json")
	f.close()
	SaveGame.load_all(Sim.tree())
	var fresh: bool = Wallet.balance == 0 and Career.team_id == &"" and SaveGame.warning.contains("new game")
	var kept := FileAccess.file_exists(SaveGame.path + ".corrupt")
	var b: JobBoard = load(BOARD).instantiate()
	Sim.add(b)
	var shown: bool = b.warning_label.visible and b.warning_label.text.contains("could not be read")
	b.free()
	# Shown once: the next board is clean, and saving works again.
	b = load(BOARD).instantiate()
	Sim.add(b)
	var once := not b.warning_label.visible
	b.free()
	Wallet.add(1)
	Wallet.save()
	var writes: bool = int(SaveGame.read_section("wallet", 0)) == 1
	Wallet.balance = 0
	Wallet.save()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveGame.path + ".corrupt"))
	return fresh and kept and shown and once and writes
