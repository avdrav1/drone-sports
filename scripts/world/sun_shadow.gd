class_name SunShadow
extends Resource
# How the sun's shadow cascades are laid out (Story 15.3): crisp near the drone,
# softer and coarser far out. Splits are fractions of the reach. The Low reach is
# the scene's own; High (Story 15.1) swaps in its longer reach and wider sun.

## Shadow reach on Low, m.
@export var max_distance := 250.0
## Shadow reach and sun size, degrees, on High under Forward+.
@export var high_distance := 600.0
@export var high_sun_angle := 1.2
## Where each cascade ends, as a fraction of the reach. Must rise.
@export_range(0.0, 1.0) var split_1 := 0.05
@export_range(0.0, 1.0) var split_2 := 0.15
@export_range(0.0, 1.0) var split_3 := 0.4
## Fraction of the reach where the shadow starts fading out.
@export_range(0.0, 1.0) var fade_start := 0.8
## Blur on the far cascades' filter; 1 is the engine's own.
@export_range(0.0, 4.0) var blur := 1.5
## Normal bias, scaled by each cascade's texel size.
@export var normal_bias := 1.2

## Puts the cascades on `sun`, and the High values where Quality.apply reads them.
## Call before Quality.apply, which keeps these as the Low values.
func apply(sun: DirectionalLight3D) -> void:
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = max_distance
	sun.directional_shadow_split_1 = split_1
	sun.directional_shadow_split_2 = split_2
	sun.directional_shadow_split_3 = split_3
	sun.directional_shadow_blend_splits = true
	sun.directional_shadow_fade_start = fade_start
	sun.shadow_blur = blur
	sun.shadow_normal_bias = normal_bias
	sun.set_meta(&"high_shadow", [high_distance, high_sun_angle])
