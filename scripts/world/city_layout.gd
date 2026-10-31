class_name CityLayout
extends Resource
# The parameters a CityPlan is generated from: a street grid over a round core,
# lots cut from each block, and heights that fall off from downtown to the edge.
# Distances in metres; the grid is centred on the origin.

## Street patterns a seed can pick (Story 26.3 on): the grid, the grid
## crossed by one or two diagonal avenues (Story 26.6), and ring roads round the
## plaza crossed by spokes out from it (Story 26.7).
enum Pattern { GRID, DIAGONAL, RADIAL }

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
## Diagonal avenues (Story 26.6, `pattern` DIAGONAL): how many (least, most),
## their angle to the grid in degrees (least, most), and how far from the centre
## each may pass, in metres. Each is avenue_width wide and runs across the core.
@export var diagonals := Vector2i(1, 2)
@export var diagonal_angle := Vector2(20, 70)
@export var diagonal_offset := 12.0
## How far past the core's edge, in metres, an avenue and the grid street ends
## that meet it in a T may run, so the road stays on the terrain's flat ground.
@export var diagonal_run_on := 8.0
## Ring and spokes (Story 26.7, `pattern` RADIAL): the plaza ring's centreline
## radius round the spawn plaza; how many spokes run out from it to the core's
## edge (street_width wide, at seeded angles); how many rings, counting the
## plaza's, and the metres between their centrelines (a ring that would leave
## no room for a lot before the core's edge is left out); and the most degrees
## one straight segment of a ring turns through.
@export var hub_radius := 40.0
@export var spokes := 6
@export var rings := 3
@export var ring_spacing := 38.0
@export var ring_step := 10.0
## Areas no lot may touch: x, z, and radius.
@export var clearings: PackedVector3Array = []

## Everything that shapes the plan, for caches built from it.
func params() -> Array:
	return [seed, core_radius, block_size, street_width, avenue_every, avenue_width, sidewalk,
		lot_gap, lot_min, lot_max, height_min, height_max, height_falloff, ground_floor, storey, clearings, vacant_chance,
		pattern, drop_chance, square_chance, diagonals, diagonal_angle, diagonal_offset,
		diagonal_run_on, hub_radius, spokes, rings, ring_spacing, ring_step]

## Drops every entry of a per-layout cache (keyed by params() and then the
## builder's own settings) that this layout did not build, so free flight's
## rerolls keep one city's worth (Story 26.1).
func prune(cache: Dictionary) -> void:
	var p := params()
	for key: Array in cache.keys():
		if key.slice(0, p.size()) != p:
			cache.erase(key)
