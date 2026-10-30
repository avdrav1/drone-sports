extends Node
# Autoload "Hangar" (Story 27.1): each drone slot's livery and parts, and what
# is unlocked, kept in the save's "hangar" section. Slot 0 is the player's
# drone; slots 1 and up are the fleet's, one per crew member who flies. A slot
# never set wears the default livery and parts, which are the drone as it was.
# Story 27.3: every look and part that is not a default is locked until bought
# with job money (priced as the shop's upgrades are) or earned by an
# achievement at a job's results. A locked item cannot be applied.

signal changed(slot: int)
## An item opened, bought or earned.
signal opened(id: StringName)

const CATALOG := "res://data/garage/catalog.tres"
## The item id of lit lights: the livery's glow.
const GLOW := &"glow"

var catalog: HangarCatalog
## Slot -> Livery, for slots set away from the default.
var liveries := {}
## Slot -> {kind -> part id}, for slots set away from the default.
var fitted := {}
## Item ids unlocked (Story 27.3).
var unlocked: Array[StringName] = []

func _ready() -> void:
	catalog = load(CATALOG)
	load_saved()

## The player's drone plus one per fleet drone, as many as the largest fleet:
## every crew member who flies, living or not.
func slot_count() -> int:
	return 1 + FleetCrew.tagged().size()

func has_slot(slot: int) -> bool:
	return slot >= 0 and slot < slot_count()

## A copy of the slot's livery; change it and hand it to `set_livery`.
func livery(slot: int) -> Livery:
	var l: Livery = liveries.get(slot, catalog.default_livery)
	return l.duplicate()

## Sets the slot's livery; false, and nothing changes, if it wears a locked item.
func set_livery(slot: int, l: Livery) -> bool:
	if not has_slot(slot) or l == null:
		return false
	var clean := _clean(l)
	if not locked_in(clean).is_empty():
		return false
	liveries[slot] = clean
	save()
	changed.emit(slot)
	return true

## Puts the slot's livery on the drone (Story 27.2), on its frame's hull, with
## the arms at the drone's arm length (Story 27.4). Looks only.
func dress(d: Drone, slot := 0) -> void:
	var look := d.get_node_or_null("Look") as DroneLook if d else null
	var frame := part(part_id(slot, &"frame"))
	if look:
		look.wear(livery(slot), frame.hull if frame else Vector3.ONE)

## Adds the slot's parts' stat steps to the drone (Story 27.4). Garage.apply
## calls it, once per drone, with the upgrades and the pilot's edge.
func apply_parts(d: Drone, slot := 0) -> void:
	for kind in Part.KINDS:
		var p := part(part_id(slot, kind))
		if p:
			p.apply_stats(d)

func is_decal(id: StringName) -> bool:
	return id == &"" or id in catalog.decals

func part(id: StringName) -> Part:
	for p in catalog.parts:
		if p.id == id:
			return p
	return null

func default_part(kind: StringName) -> Part:
	for p in catalog.default_parts:
		if p.kind == kind:
			return p
	return null

## The id of the part of `kind` fitted in the slot.
func part_id(slot: int, kind: StringName) -> StringName:
	var d := default_part(kind)
	return fitted.get(slot, {}).get(kind, d.id if d else &"")

## Kind -> part id, for every kind.
func parts(slot: int) -> Dictionary:
	var out := {}
	for kind in Part.KINDS:
		out[kind] = part_id(slot, kind)
	return out

## Fits a known, unlocked part in the slot; false, and nothing changes, otherwise.
func fit(slot: int, id: StringName) -> bool:
	var p := part(id)
	if p == null or not has_slot(slot) or not is_open(id):
		return false
	var row: Dictionary = fitted.get(slot, {})
	row[p.kind] = p.id
	fitted[slot] = row
	save()
	changed.emit(slot)
	return true

func is_unlocked(id: StringName) -> bool:
	return id in unlocked

## How the item opens, or null for a default (or anything else with none).
func unlock_of(id: StringName) -> Unlock:
	for u in catalog.unlocks:
		if u.item == id:
			return u
	return null

## May be applied: a default, or unlocked.
func is_open(id: StringName) -> bool:
	return unlock_of(id) == null or is_unlocked(id)

## The palette's swatch of this colour, or null.
func swatch_of(c: Color) -> Swatch:
	for s in catalog.palette:
		if s.color.is_equal_approx(c):
			return s
	return null

## The locked items the livery wears: its decal, a colour's swatch, lit lights.
## A colour off the palette is no item; the hangar only offers the palette.
func locked_in(l: Livery) -> Array[StringName]:
	var ids: Array[StringName] = []
	if l.decal != &"":
		ids.append(l.decal)
	if l.glow:
		ids.append(GLOW)
	for key in Livery.COLORS:
		var s := swatch_of(l.get(key))
		if s:
			ids.append(s.id)
	var out: Array[StringName] = []
	for id in ids:
		if not is_open(id) and not id in out:
			out.append(id)
	return out

## What the hangar charges for a locked item now, with the shop's markup and
## the price perk as on upgrades (Garage.marked_up); -1 when it is open or not
## for sale.
func price(id: StringName) -> int:
	var u := unlock_of(id)
	if u == null or u.price <= 0 or is_unlocked(id):
		return -1
	return Garage.marked_up(u.price)

## As upgrades: affordable, for sale, and the shop not closed.
func can_buy(id: StringName) -> bool:
	var p := price(id)
	return p >= 0 and Wallet.balance >= p and Consequences.shop_closed_jobs() == 0

## Spends the item's price from the wallet and opens it. False, and nothing
## changes, if it cannot be bought.
func buy(id: StringName) -> bool:
	if not can_buy(id):
		return false
	Wallet.add(-price(id))
	Wallet.save()
	_open(id)
	return true

## How the item opens, as the hangar shows it; empty for an open item.
func how(id: StringName) -> String:
	var u := unlock_of(id)
	if u == null or is_unlocked(id):
		return ""
	return u.describe(price(id))

## Opens every locked item whose achievement `result` (the job just flown) or
## the save now meets, once each, and saves. The opened ones, in catalog order.
func earn(result: JobResult = null) -> Array[Unlock]:
	var out: Array[Unlock] = []
	for u in catalog.unlocks:
		if u.achievement and not is_unlocked(u.item) and u.achievement.met(result):
			unlocked.append(u.item)
			out.append(u)
	if not out.is_empty():
		save()
		for u in out:
			opened.emit(u.item)
	return out

func _open(id: StringName) -> void:
	if is_unlocked(id):
		return
	unlocked.append(id)
	save()
	opened.emit(id)

## A copy with an unknown decal put back to the default's.
func _clean(l: Livery) -> Livery:
	var out: Livery = l.duplicate()
	if not is_decal(out.decal):
		out.decal = catalog.default_livery.decal
	return out

func save() -> void:
	var slots := {}
	for slot in liveries:
		slots[str(slot)] = {"livery": liveries[slot].to_dict()}
	for slot in fitted:
		var row: Dictionary = slots.get(str(slot), {})
		var ids := {}
		for kind in fitted[slot]:
			ids[String(kind)] = String(fitted[slot][kind])
		row["parts"] = ids
		slots[str(slot)] = row
	SaveGame.write_section("hangar", {"slots": slots, "unlocked": unlocked.map(func(id): return String(id))})

## Reads the section; anything unknown or garbled falls back to the default
## instead of failing.
func load_saved() -> void:
	liveries.clear()
	fitted.clear()
	unlocked.clear()
	var saved = SaveGame.read_section("hangar", {})
	if not saved is Dictionary:
		return
	var slots = saved.get("slots", {})
	if slots is Dictionary:
		for key in slots:
			if not (key is String and key.is_valid_int()) or not slots[key] is Dictionary:
				continue
			var slot := int(key)
			if slot < 0:
				continue
			if slots[key].has("livery"):
				liveries[slot] = _clean(Livery.from_dict(slots[key]["livery"], catalog.default_livery))
			var ids = slots[key].get("parts", {})
			if ids is Dictionary:
				for kind in ids:
					var p := part(StringName(str(ids[kind])))
					if p and String(p.kind) == str(kind):
						var row: Dictionary = fitted.get(slot, {})
						row[p.kind] = p.id
						fitted[slot] = row
	var ids = saved.get("unlocked", [])
	if ids is Array:
		for id in ids:
			if id is String:
				unlocked.append(StringName(id))
