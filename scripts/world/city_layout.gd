class_name CityLayout
extends Resource
# The parameters a CityPlan is generated from: a street grid over a round core,
# lots cut from each block, and heights that fall off from downtown to the edge.
# Distances in metres; the grid is centred on the origin.

## Street patterns a seed can pick (Story 26.3 on). Only the grid for now.
enum Pattern { GRID }

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
## Chance a lot is left empty: sand and no building, an open yard between
## towers (Story 26.2). Drawn from its own stream, so 0 builds the plan as before.
@export_range(0.0, 1.0) var vacant_chance := 0.0
## How the streets are laid out.
@export var pattern: Pattern = Pattern.GRID
## Chance a grid street segment between two junctions is left out and the blocks
## either side merge into a superblock (Story 26.3). Drawn from its own stream,
## so 0 builds the plan as before.
@export_range(0.0, 1.0) var drop_chance := 0.0
## Chance a block holds no lots: a paved square. Its own stream too.
@export_range(0.0, 1.0) var square_chance := 0.0
## Areas no lot may touch: x, z, and radius.
@export var clearings: PackedVector3Array = []
## The Four's shrines (Story 30.8) stand on low roofs, one per quarter of the
## city: a roof at most this high (a fraction of the height range), with a clear
## square at least `shrine_side` across, and this far past every clearing's edge.
## They never change the lots; the plan only picks roofs for them.
@export_range(0.0, 1.0) var shrine_height := 0.35
@export var shrine_side := 8.0
@export var shrine_clearance := 24.0

## Everything that shapes the plan, for caches built from it.
func params() -> Array:
	return [seed, core_radius, block_size, street_width, avenue_every, avenue_width, sidewalk,
		lot_gap, lot_min, lot_max, height_min, height_max, height_falloff, ground_floor, storey, clearings, vacant_chance,
		pattern, drop_chance, square_chance, shrine_height, shrine_side, shrine_clearance]

## Drops every entry of a per-layout cache (keyed by params() and then the
## builder's own settings) that this layout did not build, so free flight's
## rerolls keep one city's worth (Story 26.1).
func prune(cache: Dictionary) -> void:
	var p := params()
	for key: Array in cache.keys():
		if key.slice(0, p.size()) != p:
			cache.erase(key)
