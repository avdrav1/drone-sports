class_name BodyKit
extends Resource
# Story 29.1: a pilot's drone, shaped like the pilot's animal from the epics.
# Shell parts DroneLook (through AnimalShell) puts on the stock body: a head,
# ears, a mane or ruff, wings, a tail. Visual only: meshes with no body, all
# inside the drone's collision box, so mass, shape, stats and the flight model
# never change (rules 1 and 5). Worn by the player's drone, slot 0.

## The animals AnimalShell knows how to build.
const ANIMALS: Array[StringName] = [&"horse", &"monkey", &"lion_cub", &"vulture"]

@export var id: StringName
## One of ANIMALS: which shell is built.
@export var animal: StringName
## What it is called, e.g. "White horse".
@export var name := ""
## The kit's own paint. A livery colour still at its stock value (the carbon
## of a drone never painted) wears this colour instead; one the player has
## chosen wins. The animal's coat follows the body colour.
@export var paint: Livery
## The mane, crest, ruff or tail plume.
@export var mane := Color(0.5, 0.5, 0.5)
## Eyes, nose, beak.
@export var detail := Color(0.1, 0.1, 0.1)
## The battery pack's casing, which carries the race number.
@export var battery := Color(0.1, 0.1, 0.12)
## One more colour of the animal's own: a bridle, a band, a muzzle, the flight
## feathers.
@export var trim := Color(0.9, 0.7, 0.3)

static var _stock: Livery

## `l` as this kit wears it: every colour still at stock in the kit's paint;
## its decal, number, glow and name as they are.
func painted(l: Livery) -> Livery:
	if _stock == null:
		_stock = Livery.new()
	var out: Livery = l.duplicate()
	if paint == null:
		return out
	for key in Livery.COLORS:
		if (l.get(key) as Color).is_equal_approx(_stock.get(key)):
			out.set(key, paint.get(key))
	return out

## Problems with this kit; empty when it is valid.
func validate() -> Array[String]:
	var out: Array[String] = []
	if id == &"" or name.is_empty():
		out.append("body kit needs an id and a name")
	if not animal in ANIMALS:
		out.append("body kit %s: unknown animal %s" % [id, animal])
	if paint == null:
		out.append("body kit %s: needs its own paint" % id)
	return out
