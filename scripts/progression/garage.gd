extends Node
# Autoload "Garage": upgrade levels bought, kept in the save's "upgrades" section.
# Buying spends the wallet; `apply` sets the player's drone stats from the levels
# and the chosen pilot's tweak (Story 7.2).

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
## carries shop_closed (Story 7.6).
func price(id: StringName) -> int:
	var u := upgrade(id)
	var l := level(id)
	return ceili(u.prices[l] * Consequences.price_factor()) if u and l < u.max_level() else -1

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

## Set the drone's stats from its scene values plus every level bought and the
## chosen pilot's tweak. Once per drone.
func apply(drone: Drone) -> void:
	if drone == null or drone.has_meta(APPLIED):
		return
	drone.set_meta(APPLIED, true)
	for u in upgrades.upgrades:
		if level(u.id) > 0:
			drone.set(u.stat, drone.get(u.stat) + u.step * level(u.id))
	var pilot := PlayerProfile.pilot()
	if pilot and pilot.tweak:
		drone.set(pilot.tweak.stat, drone.get(pilot.tweak.stat) + pilot.tweak.step)

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
