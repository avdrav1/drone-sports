class_name CityLayout
extends Resource
# The parameters a CityPlan is generated from: a street grid over a round core,
# lots cut from each block, and heights that fall off from downtown to the edge.
# Distances in metres; the grid is centred on the origin.

## Street patterns a seed can pick (Story 26.3 on): the grid, the grid
## crossed by one or two diagonal avenues (Story 26.6), and ring roads round the
## plaza crossed by spokes out from it (Story 26.7), and the winding lanes of
## an old town (Story 26.8).
enum Pattern { GRID, DIAGONAL, RADIAL, OLD_TOWN }

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
## Winding old town (Story 26.8, `pattern` OLD_TOWN): a loop of streets round
## the spawn plaza, its centreline at least hub_radius out; `through_streets`
## wider streets (street_width) winding from it to the core's edge; and lanes
## grown from both by seeded random walks that bend and branch and end where
## they meet another lane or the core's edge. Each lane is a width from
## `lane_width` (least, most) wide, its legs `lane_length` (least, most) long,
## turning at most `lane_bend` degrees at each bend; each leg starts a branch by
## chance `lane_branch`. Lanes that do not meet keep `lane_gap` metres apart,
## kerb to kerb. Buildings stand `old_town_height` (least, most) tall, within
## height_min to height_max.
@export var through_streets := 3
@export var lane_width := Vector2(5, 6.5)
@export var lane_length := Vector2(16, 30)
@export var lane_bend := 30.0
@export_range(0.0, 1.0) var lane_branch := 0.4
@export var lane_gap := 8.0
@export var old_town_height := Vector2(5, 24)
## Ducts and pipes overhead (Story 26.9, read by OverheadSpans, not the plan):
## each stretch of a street no wider than `span_max_width` has a slot every
## `span_spacing` metres, taken by chance `span_chance` (`span_lane_chance` on a
## street narrower than street_width, such as an old town's lanes). A taken slot
## is a pipe rack of two or three pipes by chance `rack_chance`, else a single
## duct, its underside `span_clear` (least, most) metres up. `span_gap` is the
## least gap between a rack's pipes and between any two spans; keep it wide
## enough for the collision guard to let a drone through.
@export var span_spacing := 6.0
@export_range(0.0, 1.0) var span_chance := 0.75
@export_range(0.0, 1.0) var span_lane_chance := 0.9
@export var span_max_width := 12.0
@export var span_clear := Vector2(7, 14)
@export var span_gap := 2.4
@export_range(0.0, 1.0) var rack_chance := 0.5
## Fences with holes (Story 26.10, read by Fences, not the plan): chain-link
## runs `fence_height` tall on posts, panels at least `fence_panel` wide post to
## post, round a vacant lot by chance `fence_vacant_chance` and along a clear
## stretch of block edge by chance `fence_edge_chance`. Each panel is a hole by
## chance `fence_hole_chance` (each run has at least one): missing, torn open
## at drone height, or lifted off the ground. `fence_hole` is the least width
## and height of a hole; keep it wide enough for the collision guard to let a
## drone through.
@export_range(0.0, 1.0) var fence_vacant_chance := 0.7
@export_range(0.0, 1.0) var fence_edge_chance := 0.5
@export var fence_height := 4.0
@export var fence_panel := 3.2
@export var fence_hole := Vector2(2.4, 2.4)
@export_range(0.0, 1.0) var fence_hole_chance := 0.3
## Cars on the streets (Story 26.11, read by Traffic, not the plan): how many
## drive the city's lanes, fewer where the lanes have no room for them, and
## the range of cruising speeds each is given, in m/s.
@export var car_count := 26
@export var car_speed := Vector2(8, 13)
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
		pattern, drop_chance, square_chance, diagonals, diagonal_angle, diagonal_offset,
		diagonal_run_on, hub_radius, spokes, rings, ring_spacing, ring_step, through_streets, lane_width,
		lane_length, lane_bend, lane_branch, lane_gap, old_town_height, shrine_height, shrine_side, shrine_clearance]

## Drops every entry of a per-layout cache (keyed by params() and then the
## builder's own settings) that this layout did not build, so free flight's
## rerolls keep one city's worth (Story 26.1).
func prune(cache: Dictionary) -> void:
	var p := params()
	for key: Array in cache.keys():
		if key.slice(0, p.size()) != p:
			cache.erase(key)
