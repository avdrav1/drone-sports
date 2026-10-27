class_name Consequences
extends RefCounted
# What a death changes (Story 7.6, the table in CHARACTERS.md). Each is a
# Character.death_consequence tag; the HUD, shop, career, and board ask here
# whether it is in effect, so none of them names a character (CLAUDE.md rule 6).

## Jobs the shop stays shut after the death that closes it.
const SHOP_CLOSED_JOBS := 3
## Upgrade prices from the death on, closed or reopened.
const SHOP_MARKUP := 1.25
## Consequence tag -> the faction it locks for the rest of the playthrough.
const FACTION_LOCKS := {&"salvage_locked": &"salvage", &"city_locked": &"city"}

## The dead whose death carries `tag`.
static func causes(tag: StringName) -> Array[Character]:
	var out: Array[Character] = []
	if tag == &"":
		return out
	for id in Roster.ids():
		var c: Character = Roster.character(id)
		if c.death_consequence == tag and not Roster.is_alive(id):
			out.append(c)
	return out

static func in_effect(tag: StringName) -> bool:
	return not causes(tag).is_empty()

## A locked faction makes no offers and its jobs leave the board.
static func faction_locked(faction: StringName) -> bool:
	for tag in FACTION_LOCKS:
		if FACTION_LOCKS[tag] == faction and in_effect(tag):
			return true
	return false

## Jobs left until the shop reopens; 0 when it is open.
static func shop_closed_jobs() -> int:
	var left := 0
	for c in causes(&"shop_closed"):
		left = maxi(left, SHOP_CLOSED_JOBS - Roster.jobs_since_death(c.id))
	return left

static func price_factor() -> float:
	return SHOP_MARKUP if in_effect(&"shop_closed") else 1.0

## Names of the dead this job needs alive (Job.requires_living).
static func missing_crew(job: Job) -> Array[String]:
	var out: Array[String] = []
	for id in job.requires_living:
		if not Roster.is_alive(id):
			out.append(Roster.character(id).name)
	return out

## On the board at all: not from a locked faction.
static func listed(job: Job) -> bool:
	return not faction_locked(job.faction)
