extends Node
# Autoload "Garage": upgrade levels bought, kept in the save's "upgrades" section.
# Buying spends the wallet; `apply` sets the player's drone stats from the levels,
# the hangar slot's parts and the chosen pilot's edge (Stories 7.2, 19.1, 27.4).

signal bought(upgrade: Upgrade, level: int)

const UPGRADES := "res://data/upgrades/upgrades.tres"
const APPLIED := &"garage_applied"

var upgrades: UpgradeList
## Upgrade id -> level bought.
var levels := {}

func _ready() -> void:
	upgrades = load(UPGRADES)
	load_saved()

func upgrade(id: StringName) -> Upgrade:
	for u in upgrades.upgrades:
		if u.id == id:
			return u
	return null

func level(id: StringName) -> int:
	return levels.get(id, 0)

## The next level's price, or -1 at the top level. Marked up once a death
## carries shop_closed (Story 7.6); lowered by the fit crew's price perk (Story
## 19.5). The markup's death ends the perk, so the two never stack.
func price(id: StringName) -> int:
	var u := upgrade(id)
	var l := level(id)
	if u == null or l >= u.max_level():
		return -1
	return marked_up(u.prices[l])

## A shop price as charged now: the markup and the price perk on `base`. The
## hangar's items are priced the same way (Story 27.3).
func marked_up(base: int) -> int:
	var factor := Consequences.price_factor() * maxf(0.0, 1.0 - Perks.amount(&"price"))
	# Snapped first, so 500 x 0.8 is 400, not 401 from float error.
	return ceili(snappedf(base * factor, 0.001))

func can_buy(id: StringName) -> bool:
	var p := price(id)
	return p >= 0 and Wallet.balance >= p and Consequences.shop_closed_jobs() == 0

## Spend the wallet on the next level. False, and nothing changes, if the pilot
## cannot afford it, it is maxed, or the shop is closed.
func buy(id: StringName) -> bool:
	if not can_buy(id):
		return false
	var p := price(id)
	Wallet.add(-p)
	Wallet.save()
	levels[id] = level(id) + 1
	save()
	bought.emit(upgrade(id), levels[id])
	return true

## Set the drone's stats from its scene values plus every level bought, the
## parts fitted in its hangar slot (Story 27.4) and the chosen pilot's edge, and
## tune its assists to the edge, and dress it in the slot's livery (Story 27.2).
## Slot 0 is the player's drone. Once per drone.
func apply(drone: Drone, slot := 0) -> void:
	if drone == null or drone.has_meta(APPLIED):
		return
	drone.set_meta(APPLIED, true)
	_add_levels(drone, levels)
	Hangar.apply_parts(drone, slot)
	_add_edge(drone)
	tune(drone)
	Hangar.dress(drone, slot)

## What `apply` would set the stats to with these parts (kind -> part id) and
## upgrade levels (id -> level; null is the levels bought): Part.STATS by name.
## The hangar's stat bars (Story 27.5); no drone in the game is touched.
func stats_with(parts: Dictionary, at_levels = null) -> Dictionary:
	var d := Drone.new()
	_add_levels(d, levels if at_levels == null else at_levels)
	for kind in parts:
		var p := Hangar.part(parts[kind])
		if p:
			p.apply_stats(d)
	_add_edge(d)
	var out := {}
	for stat in Part.STATS:
		out[stat] = d.get(stat)
	d.free()
	return out

func _add_levels(drone: Drone, at_levels: Dictionary) -> void:
	for u in upgrades.upgrades:
		var l: int = at_levels.get(u.id, 0)
		if l > 0:
			drone.set(u.stat, drone.get(u.stat) + u.step * l)

func _add_edge(drone: Drone) -> void:
	var pilot := PlayerProfile.pilot()
	if pilot and pilot.edge:
		pilot.edge.apply_stats(drone)

## Give the drone's assists that are on the chosen pilot's settings; the ones
## that are off keep their own. Call again after switching assists.
func tune(drone: Drone) -> void:
	var pilot := PlayerProfile.pilot()
	if drone and drone.assists and pilot and pilot.edge:
		pilot.edge.tune(drone.assists)

func save() -> void:
	var out := {}
	for id in levels:
		out[String(id)] = levels[id]
	SaveGame.write_section("upgrades", out)

func load_saved() -> void:
	levels.clear()
	var saved = SaveGame.read_section("upgrades", {})
	if saved is Dictionary:
		for id in saved:
			levels[StringName(id)] = int(saved[id])
