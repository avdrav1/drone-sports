class_name CityLayout
extends Resource
# The parameters a CityPlan is generated from: a street grid over a round core,
# lots cut from each block, and heights that fall off from downtown to the edge.
# Distances in metres; the grid is centred on the origin.

@export var seed := 1
## Lots stand fully inside this radius. Keep it inside the terrain's flat radius.
@export var core_radius := 140.0
## Width of a block between streets, kerb to kerb.
@export var block_size := 40.0
@export var street_width := 10.0
## Every Nth street from the centre is an avenue.
@export var avenue_every := 3
@export var avenue_width := 16.0
## Lots are set back this far from the kerb.
@export var sidewalk := 3.0
## Alley between neighbouring lots.
@export var lot_gap := 1.0
## A lot's side, before it is fitted to the block.
@export var lot_min := 12.0
@export var lot_max := 22.0
@export var height_min := 6.0
@export var height_max := 80.0
## Higher keeps tall towers closer to the centre.
@export var height_falloff := 1.5
## Building shapes (Story 15.6) step at storey lines: the ground floor's top, then
## every storey above it. Keep in step with City.ground_floor and window_cell.y.
@export var ground_floor := 4.0
@export var storey := 3.5
## Areas no lot may touch: x, z, and radius.
@export var clearings: PackedVector3Array = []

## Everything that shapes the plan, for caches built from it.
func params() -> Array:
	return [seed, core_radius, block_size, street_width, avenue_every, avenue_width, sidewalk,
		lot_gap, lot_min, lot_max, height_min, height_max, height_falloff, ground_floor, storey, clearings]
