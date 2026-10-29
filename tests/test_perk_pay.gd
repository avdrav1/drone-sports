extends RefCounted
# Story 19.5: pay, reputation, and prices. Bea's site rates add 15 percent to a
# job's pay, Rin's good word 25 percent to reputation gains, and Dot's trade
# prices take 20 percent off every Garage price, each only while fit. The
# results screen names each bonus.

const Sim = preload("res://tests/sim.gd")
const SCALE := preload("res://data/jobs/grade_scale.tres")

## Settles a 1000-pay job at `letter` without touching the wallet for good.
func _settle(letter := "A") -> JobResult:
	var r := JobResult.new()
	r.job = load("res://data/jobs/test_job.tres").duplicate()
	r.job.pay = 1000
	r.letter = letter
	var balance := Wallet.balance
	Payout.settle(r, SCALE)
	Wallet.balance = balance
	Wallet.save()
	return r

func _without_rin(f: Callable):
	var rin: Character = Roster.character(&"rin")
	var perk := rin.perk
	rin.perk = null
	var out = f.call()
	rin.perk = perk
	return out

func test_bea_fit_pays_15_percent_more() -> bool:
	var fit := _settle()
	var named := fit.bonuses.any(func(b): return b.text == "Bhima's site rates" and b.amount == 150)
	Roster.injure(&"bea")
	var benched := _settle()
	Roster.kill(&"bea")
	var dead := _settle()
	return fit.pay == 1150 and named and benched.pay == 1000 and dead.pay == 1000 \
		and benched.bonuses.all(func(b): return b.unit != "")

func test_rin_fit_raises_reputation_gains_by_25_percent() -> bool:
	var with_rin := _settle("A")
	var without: JobResult = _without_rin(func(): return _settle("A"))
	var b_grade := _settle("B")
	var loss := _settle("F")
	return without.reputation_change == 10 and with_rin.reputation_change == 13 \
		and b_grade.reputation_change == 6 + roundi(6 * 0.25) \
		and loss.reputation_change == -5 and loss.bonuses.is_empty() \
		and with_rin.bonuses.any(func(b): return b.text == "Drona's good word" and b.unit == " reputation")

func test_dot_fit_takes_20_percent_off_every_price() -> bool:
	var fit := true
	for u in Garage.upgrades.upgrades:
		fit = fit and Garage.price(u.id) == roundi(u.prices[0] * 0.8)
	Roster.injure(&"dot")
	var benched := true
	for u in Garage.upgrades.upgrades:
		benched = benched and Garage.price(u.id) == u.prices[0]
	return fit and benched

func test_after_dot_dies_prices_follow_the_closed_then_markup_rule() -> bool:
	Roster.kill(&"dot")
	var closed := Consequences.shop_closed_jobs() == 3
	for i in 3:
		Roster.job_done()
	var marked := true
	for u in Garage.upgrades.upgrades:
		marked = marked and Garage.price(u.id) == ceili(u.prices[0] * 1.25)
	return closed and marked and Consequences.shop_closed_jobs() == 0

func test_results_screen_names_each_bonus() -> bool:
	var r := _settle()
	r.completed = true
	var screen: Control = load("res://scenes/ui/results.tscn").instantiate()
	Sim.add(screen)
	screen.show_result(r)
	await Sim.process_frames(1)
	var lines: Array = screen.get_node("%Rows").get_children() \
		.filter(func(c): return c is Label and c.name.begins_with("Bonus")).map(func(l): return l.text)
	var money: String = screen.get_node("%Money").text
	screen.free()
	return lines == ["Bhima's site rates +150", "Drona's good word +3 reputation"] \
		and money.contains("Pay 1150") and money.contains("+13")
