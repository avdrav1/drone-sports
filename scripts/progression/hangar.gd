extends Node
# Autoload "Hangar" (Story 27.1): each drone slot's livery and parts, and what
# is unlocked, kept in the save's "hangar" section. Slot 0 is the player's
# drone; slots 1 and up are the fleet's, one per crew member who flies. A slot
# never set wears the default livery and parts, which are the drone as it was.

signal changed(slot: int)

const CATALOG := "res://data/garage/catalog.tres"

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

func set_livery(slot: int, l: Livery) -> void:
	if not has_slot(slot) or l == null:
		return
	liveries[slot] = _clean(l)
	save()
	changed.emit(slot)

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

## Fits a known part in the slot; false, and nothing changes, otherwise.
func fit(slot: int, id: StringName) -> bool:
	var p := part(id)
	if p == null or not has_slot(slot):
		return false
	var row: Dictionary = fitted.get(slot, {})
	row[p.kind] = p.id
	fitted[slot] = row
	save()
	changed.emit(slot)
	return true

func is_unlocked(id: StringName) -> bool:
	return id in unlocked

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
