class_name Unlock
extends Resource
# Story 27.3: how a hangar item that is not a default opens: bought from the
# wallet at `price`, earned by `achievement`, or either when it has both. The
# item is a part, decal or swatch id, or Hangar.GLOW for lit lights.

@export var item: StringName
## What the item is called where it is shown, e.g. "Lotus decal".
@export var name := ""
## Wallet price before any markup or perk; 0 is not for sale.
@export var price := 0
## Opens it at a job's results when met; none is bought only.
@export var achievement: Achievement

## How it opens, e.g. "Buy for 400, or finish Parcel to the pad in under 40 s".
## `cost` is the price as the hangar charges it now (Hangar.price).
func describe(cost := price) -> String:
	var earn := achievement.describe() if achievement else ""
	if price <= 0:
		return earn.left(1).to_upper() + earn.substr(1)
	return "Buy for %d" % cost + (", or %s" % earn if earn else "")

## Problems with this unlock; empty when it is valid.
func validate() -> Array[String]:
	var out: Array[String] = []
	if item == &"" or name.is_empty():
		out.append("%s: needs an item and a name" % item)
	if price <= 0 and achievement == null:
		out.append("%s: needs a price, an achievement, or both" % item)
	if achievement:
		for p in achievement.validate():
			out.append("%s: %s" % [item, p])
	return out
