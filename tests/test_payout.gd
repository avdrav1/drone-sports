extends RefCounted
# Story 2.4: payout and reputation. The whole crew is fit, so pay carries Bhima's
# +15 percent and reputation gains Drona's +25 percent (Story 19.5).

const Sim = preload("res://tests/sim.gd")
const TEST_SAVE := "user://test_save.json"

class Fixed extends Objective:
	var value := 1.0
	func score() -> float:
		return value

var _real_path := ""

func _isolate() -> void:
	_real_path = SaveGame.path
	SaveGame.path = TEST_SAVE
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	Wallet.balance = 0
	Reputation.by_faction.clear()

func _restore() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	SaveGame.path = _real_path
	Wallet.load_saved()
	Reputation.load_saved()

# Runs a 100-pay league job whose single objective scores `value`; returns the result.
func _run(value: float, complete := true) -> JobResult:
	var o := Fixed.new()
	o.value = value
	var j: Job = load("res://data/jobs/test_job.tres").duplicate()
	j.countdown = 0.1
	var root := Sim.job_setup(j, [o])
	await Sim.go_live(root)
	var runner: JobRunner = root.get_node("Runner")
	if complete:
		runner.complete()
	else:
		runner.fail("test")
	var r := runner.result
	root.free()
	return r

func test_a_pays_full() -> bool:
	_isolate()
	var r: JobResult = await _run(0.95)
	var ok := r.letter == "A" and r.pay == 115 and Wallet.balance == 115 and Reputation.of(&"league") == 13
	_restore()
	return ok

func test_c_pays_60_percent() -> bool:
	_isolate()
	var r: JobResult = await _run(0.65)
	var ok := r.letter == "C" and r.pay == 69 and Wallet.balance == 69
	_restore()
	return ok

func test_f_pays_nothing_and_costs_5_rep() -> bool:
	_isolate()
	var low: JobResult = await _run(0.1)
	var ok := low.letter == "F" and low.pay == 0 and Reputation.of(&"league") == -5
	var failed: JobResult = await _run(1.0, false)
	ok = ok and failed.letter == "F" and failed.pay == 0 and Wallet.balance == 0 \
		and Reputation.of(&"league") == -10
	_restore()
	return ok

func test_values_persist_across_save_and_load() -> bool:
	_isolate()
	await _run(0.95)
	await _run(0.8)
	Wallet.balance = 0
	Reputation.by_faction.clear()
	Wallet.load_saved()
	Reputation.load_saved()
	var ok := Wallet.balance == 207 and Reputation.of(&"league") == 21 \
		and FileAccess.file_exists(TEST_SAVE)
	_restore()
	return ok

func test_result_lists_objectives() -> bool:
	_isolate()
	var r: JobResult = await _run(0.5)
	_restore()
	return r.objectives.size() == 1 and r.objectives[0].score == 0.5 and r.completed
