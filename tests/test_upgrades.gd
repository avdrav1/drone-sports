extends RefCounted
# Story 5.5: upgrades. Buying max thrust raises the climb rate in the debug
# scene; prices and effects come from data; no money, no sale; assists untouched.
# Nala is fit throughout, so every price is Nala's 20 percent off (Story 19.5).

const Sim = preload("res://tests/sim.gd")

## Climb rate after 0.5 s of full throttle with no assists, in the debug scene.
func _climb_rate() -> float:
	var scene: Node = load("res://scenes/debug_flight.tscn").instantiate()
	Sim.add(scene)
	var d: Drone = scene.get_node("Drone")
	var src := Sim.FixedSource.new()
	src.value = Sim.intent(1.0)
	d.add_child(src)
	d.intent_source = src
	await Sim.physics_frames(1)
	d.assists.apply_stack(Sim.all_off())
	await Sim.physics_frames(30)
	var vy := d.linear_velocity.y
	scene.free()
	return vy

func test_buying_thrust_raises_climb_rate() -> bool:
	var stock := await _climb_rate()
	Wallet.balance = 480
	var bought := Garage.buy(&"thrust")
	var tuned := await _climb_rate()
	var assists_same := true
	var d: Drone = Sim.drone(Sim.intent())
	Garage.apply(d)
	var thrust := d.max_thrust
	for a in d.assists.assists():
		assists_same = assists_same and not a.enabled  # applying upgrades never switches assists
	var count := d.assists.assists().size()
	d.free()
	# Stock 4.5 N plus one 0.5 N level, plus whatever the pilot's edge adds (Story 19.2).
	var want := 5.0
	for s in PlayerProfile.pilot().edge.stats:
		want += s.step if s.stat == &"max_thrust" else 0.0
	print("        climb after 0.5 s: stock %.2f m/s, upgraded %.2f m/s" % [stock, tuned])
	return bought and Wallet.balance == 0 and tuned > stock * 1.1 and is_equal_approx(thrust, want) \
		and assists_same and count == 6

func test_prices_and_effects_are_data() -> bool:
	var u: Upgrade = load("res://data/upgrades/thrust.tres")
	var saved := u.prices.duplicate()
	u.prices[0] = 50
	Wallet.balance = 40
	var cheap := Garage.price(&"thrust") == 40 and Garage.buy(&"thrust")
	u.prices = saved
	var levels_saved: bool = SaveGame.read_section("upgrades", {}).get("thrust", 0) == 1
	var all_ok := true
	for x in Garage.upgrades.upgrades:
		all_ok = all_ok and x.stat in Upgrade.STATS and x.max_level() > 0 and x.step != 0.0
	return cheap and levels_saved and all_ok and Garage.upgrades.upgrades.size() == 3

func test_cannot_buy_without_funds_or_past_max() -> bool:
	Wallet.balance = 479
	var poor := not Garage.buy(&"thrust") and Garage.level(&"thrust") == 0 and Wallet.balance == 479
	Wallet.balance = 100000
	for i in 3:
		Garage.buy(&"thrust")
	var at_top := Wallet.balance
	var maxed := not Garage.buy(&"thrust") and Garage.level(&"thrust") == 3 and Wallet.balance == at_top \
		and Garage.price(&"thrust") == -1
	Wallet.balance = 0
	return poor and maxed

func test_shop_on_the_board() -> bool:
	Wallet.balance = 530
	var b: JobBoard = load("res://scenes/ui/job_board.tscn").instantiate()
	Sim.add(b)
	await Sim.process_frames(1)
	b.shop.open()
	var thrust := b.shop.buy_button(&"thrust")
	var drag := b.shop.buy_button(&"drag")
	var ok: bool = b.shop.visible and not thrust.disabled and thrust.text.contains("480") and drag.disabled
	thrust.pressed.emit()
	await Sim.process_frames(1)
	ok = ok and Garage.level(&"thrust") == 1 and b.money_text().contains("Wallet  50") \
		and b.shop.buy_button(&"thrust").disabled and b.shop.buy_button(&"thrust").text.contains("960")
	b.free()
	Wallet.balance = 0
	return ok
