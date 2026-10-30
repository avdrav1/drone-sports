extends RefCounted
# Story 27.3: unlocks, by money and by achievement. Every look and part that is
# not a default is locked until bought (priced as the shop's upgrades) or
# earned at a job's results; a locked item cannot be applied; every item names
# how it unlocks.

const Sim = preload("res://tests/sim.gd")

## Every item that is not a default: decals, parts and swatches but the
## defaults, and lit lights.
func _items() -> Array[StringName]:
	var out: Array[StringName] = [Hangar.GLOW]
	out.append_array(Hangar.catalog.decals)
	for p in Hangar.catalog.parts:
		if not p in Hangar.catalog.default_parts:
			out.append(p.id)
	for s in Hangar.catalog.palette:
		if not s.id in _default_swatches():
			out.append(s.id)
	return out

func _default_swatches() -> Array[StringName]:
	var out: Array[StringName] = []
	var def := Hangar.catalog.default_livery
	for key in Livery.COLORS:
		var s := Hangar.swatch_of(def.get(key))
		if s:
			out.append(s.id)
	return out

## A finished job's result, for the achievements that ask how it went.
func _result(job_id: StringName, completed := true, time := 30.0, crashes := 0) -> JobResult:
	var r := JobResult.new()
	r.job = (load(Achievement.JOBS) as JobList).by_id(job_id)
	r.completed = completed
	r.time = time
	r.crashes = crashes
	return r

func test_every_item_names_how_it_unlocks() -> bool:
	var items := _items()
	var ok := items.size() == 1 + 8 + 8 + Hangar.catalog.palette.size() - 3
	var seen: Array[StringName] = []
	var kinds := {}
	var both := 0
	for u in Hangar.catalog.unlocks:
		var problems := u.validate()
		if not problems.is_empty():
			print("        ", problems)
		ok = ok and problems.is_empty() and u.item in items and not u.item in seen
		seen.append(u.item)
		if u.achievement:
			kinds[u.achievement.kind] = true
			both += 1 if u.price > 0 else 0
	for id in items:
		var how := Hangar.how(id)
		ok = ok and not Hangar.is_open(id) and Hangar.unlock_of(id) != null and how.length() > 6 \
			and how[0] == how[0].to_upper()
	# The defaults are open from the start: stock parts, no decal, the default
	# livery's swatches, which are all of its colours.
	for p in Hangar.catalog.default_parts:
		ok = ok and Hangar.is_open(p.id) and Hangar.how(p.id) == ""
	ok = ok and _default_swatches().size() == Livery.COLORS.size() \
		and Hangar.locked_in(Hangar.catalog.default_livery).is_empty()
	# Every kind of achievement opens something, and some items open by either.
	ok = ok and kinds.size() == Achievement.Kind.size() and both > 0
	# The text names the price, the achievement, or both.
	var lotus := Hangar.unlock_of(&"lotus")
	ok = ok and Hangar.how(&"lotus") == "Buy for %d, or finish Search and rescue: Sushena with no crashes" % Hangar.price(&"lotus") \
		and lotus.describe() == "Buy for 500, or finish Search and rescue: Sushena with no crashes" \
		and Hangar.how(&"team") == "Get scouted by a team" and Hangar.how(&"ivory") == "Buy for %d" % Hangar.price(&"ivory")
	return ok

func test_a_locked_item_cannot_be_applied() -> bool:
	var before := Hangar.livery(0).to_dict()
	var ok := not Hangar.fit(0, &"light_racer") and Hangar.part_id(0, &"frame") == &"stock_frame"
	var decal := Hangar.livery(0)
	decal.decal = &"lotus"
	var paint := Hangar.livery(0)
	paint.body_color = Hangar.catalog.palette[5].color
	var lit := Hangar.livery(0)
	lit.glow = true
	for l in [decal, paint, lit]:
		ok = ok and not Hangar.set_livery(0, l) and Hangar.livery(0).to_dict() == before
	ok = ok and Hangar.locked_in(decal) == [&"lotus"] and Hangar.locked_in(lit) == [Hangar.GLOW] \
		and Hangar.locked_in(paint) == [Hangar.catalog.palette[5].id]
	# Open, each applies.
	Hangar.unlocked.append_array([&"light_racer", &"lotus", Hangar.catalog.palette[5].id, Hangar.GLOW])
	ok = ok and Hangar.fit(0, &"light_racer")
	for l in [decal, paint, lit]:
		ok = ok and Hangar.set_livery(0, l) and Hangar.livery(0).to_dict() == l.to_dict()
	return ok

func test_buying_spends_exactly_its_price() -> bool:
	var keep := Wallet.balance
	var id := &"grip_props"
	var p := Hangar.price(id)
	Wallet.balance = p - 1
	var ok := p > 0 and not Hangar.can_buy(id) and not Hangar.buy(id) and Wallet.balance == p - 1 \
		and not Hangar.is_unlocked(id)
	Wallet.balance = p + 37
	ok = ok and Hangar.can_buy(id) and Hangar.buy(id) and Wallet.balance == 37 and Hangar.is_open(id) \
		and Hangar.price(id) == -1 and not Hangar.buy(id) and Wallet.balance == 37 and Hangar.how(id) == ""
	# An item earned only, never for sale, cannot be bought.
	Wallet.balance = 100000
	ok = ok and Hangar.price(&"team") == -1 and not Hangar.buy(&"team") and Wallet.balance == 100000
	# Bought stays bought.
	SaveGame.load_all(Sim.tree())
	ok = ok and Hangar.is_unlocked(id) and Hangar.fit(0, id) and not Hangar.is_unlocked(&"team")
	Wallet.balance = keep
	Wallet.save()
	return ok

func test_shop_markup_and_price_perk_change_hangar_prices() -> bool:
	var keep := Wallet.balance
	Wallet.balance = 100000
	var base := Hangar.unlock_of(&"lotus").price
	# Nala's price perk, while fit, as on upgrades (Story 19.5).
	var fit := Hangar.price(&"lotus") == roundi(base * 0.8) and Hangar.price(&"lotus") == Garage.marked_up(base)
	Roster.injure(&"nala")
	var benched := Hangar.price(&"lotus") == base
	# After the death that shuts the shop: nothing sells, then the markup (Story 7.6).
	Roster.kill(&"nala")
	var closed := Consequences.shop_closed_jobs() == 3 and not Hangar.can_buy(&"lotus") and not Hangar.buy(&"lotus") \
		and Wallet.balance == 100000
	for i in 3:
		Roster.job_done()
	var marked := Hangar.price(&"lotus") == ceili(base * 1.25) and Hangar.buy(&"lotus") \
		and Wallet.balance == 100000 - ceili(base * 1.25)
	Wallet.balance = keep
	Wallet.save()
	return fit and benched and closed and marked

func test_an_achievement_opens_its_item_once_and_keeps_it() -> bool:
	# Earlier suites' payouts would meet the best-payout achievements.
	var keep := Wallet.best_pay
	Wallet.best_pay = 0
	# Lotus: rescue finished with no crashes. A crash, a fail, or another job
	# does not open it.
	var ok := Hangar.earn(_result(&"rescue", true, 30.0, 1)).is_empty() \
		and Hangar.earn(_result(&"rescue", false)).is_empty() \
		and Hangar.earn(_result(&"inspection")).all(func(u): return u.item != &"lotus")
	var opened := Hangar.earn(_result(&"rescue"))
	ok = ok and opened.size() == 1 and opened[0].item == &"lotus" and Hangar.is_open(&"lotus")
	# Once: the next clean finish opens nothing new.
	ok = ok and Hangar.earn(_result(&"rescue")).is_empty()
	SaveGame.load_all(Sim.tree())
	ok = ok and Hangar.is_unlocked(&"lotus")
	# A time: the speed props under 40 s on the parcel job, not at 41.
	ok = ok and not &"speed_props" in Hangar.earn(_result(&"sample_delivery", true, 41.0, 1)).map(func(u): return u.item) \
		and &"speed_props" in Hangar.earn(_result(&"sample_delivery", true, 39.0, 1)).map(func(u): return u.item)
	Wallet.best_pay = keep
	return ok

func test_each_kind_of_achievement_is_met_by_what_it_names() -> bool:
	var keep := Wallet.best_pay
	var a := Achievement.new()
	a.kind = Achievement.Kind.JOB_DONE
	a.job = &"demolition"
	var ok := not a.met()
	Career.job_completed(&"demolition")
	ok = ok and a.met()
	a.kind = Achievement.Kind.BEST_PAY
	a.amount = keep + 500
	ok = ok and not a.met()
	Wallet.record_pay(keep + 500)
	ok = ok and a.met()
	a.kind = Achievement.Kind.REPUTATION
	a.faction = &"salvage"
	a.amount = 25
	Reputation.add(&"salvage", 24)
	ok = ok and not a.met()
	Reputation.add(&"salvage", 1)
	ok = ok and a.met() and a.describe() == "reach 25 reputation with Salvage"
	a.kind = Achievement.Kind.STORY_FLAG
	a.flag = &"scouted"
	ok = ok and not a.met()
	StoryFlags.set_flag(&"scouted")
	ok = ok and a.met()
	a.kind = Achievement.Kind.FLEET_FLOWN
	ok = ok and not a.met()
	StoryFlags.set_flag(Achievement.FLEET_FLAG)
	ok = ok and a.met()
	Wallet.best_pay = keep
	Wallet.save()
	return ok

func test_either_the_price_or_the_achievement_opens_it() -> bool:
	var keep := Wallet.balance
	var best := Wallet.best_pay
	Wallet.best_pay = 0
	# Heavy hauler: for sale, and earned by finishing the demolition run.
	Wallet.balance = Hangar.price(&"heavy_hauler")
	var bought := Hangar.buy(&"heavy_hauler") and Hangar.is_open(&"heavy_hauler") and Wallet.balance == 0
	Hangar.unlocked.clear()
	Wallet.balance = 0
	Career.job_completed(&"demolition")
	var earned := Hangar.earn(_result(&"demolition")).map(func(u): return u.item)
	Wallet.balance = keep
	Wallet.best_pay = best
	Wallet.save()
	return bought and earned == [&"heavy_hauler"] and Hangar.is_open(&"heavy_hauler")

func test_the_fleet_first_flown_sets_its_flag() -> bool:
	var root: Node = load("res://scenes/jobs/fleet_race.tscn").instantiate()
	var runner: JobRunner = root.get_node("JobRunner")
	runner.auto_begin = false
	runner.results_scene = null
	Sim.add(root)
	runner.begin()
	var before := StoryFlags.is_set(Achievement.FLEET_FLAG)
	runner.launch(true)
	while runner.state == JobRunner.State.COUNTDOWN:
		await Sim.tree().physics_frame
	var after := StoryFlags.is_set(Achievement.FLEET_FLAG)
	root.free()
	return not before and after

func test_a_job_counts_its_crashes_and_time_and_shows_what_it_opened() -> bool:
	var job: Job = load("res://data/jobs/rescue.tres")
	var root := Sim.job_setup(job)
	var runner: JobRunner = root.get_node("Runner")
	runner.results_scene = null
	var watcher := FlightWatcher.new()
	watcher.runner = runner
	root.add_child(watcher)
	var bark := Bark.new()
	bark.runner = runner
	bark.seed = 3
	root.add_child(bark)
	var radio: Array = []
	bark.said.connect(func(l): radio.append(l))
	runner.begin()
	# A crash in the briefing does not count; live, a crash and its recovery do.
	watcher.flight_event.emit(&"crash")
	runner.launch(true)
	while runner.state == JobRunner.State.COUNTDOWN:
		await Sim.tree().physics_frame
	watcher.flight_event.emit(&"crash")
	watcher.flight_event.emit(&"reset")
	await Sim.physics_frames(30)
	runner.complete()
	var r := runner.result
	var ok := r.crashes == 2 and r.time > 0.4 and r.time < 1.0 and not &"lotus" in r.unlocks.map(func(u): return u.item)
	root.free()
	# Clean this time: the lotus opens, on the results and the radio.
	Bark.moment_times.clear()
	root = Sim.job_setup(job)
	runner = root.get_node("Runner")
	runner.results_scene = null
	bark = Bark.new()
	bark.runner = runner
	bark.seed = 3
	root.add_child(bark)
	radio.clear()
	bark.said.connect(func(l): radio.append(l))
	runner.begin()
	runner.launch(true)
	while runner.state == JobRunner.State.COUNTDOWN:
		await Sim.tree().physics_frame
	runner.complete()
	r = runner.result
	ok = ok and r.crashes == 0 and r.unlocks.map(func(u): return u.item).has(&"lotus") \
		and radio.any(func(l): return l.event == &"unlock")
	var screen: Control = load("res://scenes/ui/results.tscn").instantiate()
	Sim.add(screen)
	screen.show_result(r)
	var rows := screen.find_children("Unlock*", "Label", true, false)
	ok = ok and rows.any(func(l): return l.text.begins_with("Unlocked: Lotus decal (finish Search and rescue"))
	screen.free()
	root.free()
	SaveGame.load_all(Sim.tree())
	return ok and Hangar.is_unlocked(&"lotus")
