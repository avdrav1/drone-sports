class_name Wind
extends Resource
# Per-scene wind: a steady base vector plus gusts along it. Deterministic in time.

## Steady wind velocity, m/s.
@export var base := Vector3.ZERO
## Peak gust speed added along the base direction, m/s.
@export var gust_amplitude := 0.0
## Seconds between gust peaks.
@export var gust_period := 5.0

func sample(time: float) -> Vector3:
	var dir := base.normalized() if base.length_squared() > 0.0 else Vector3.RIGHT
	# Two incommensurate sines so gusts do not feel metronomic.
	var w := TAU / maxf(gust_period, 0.01)
	var gust := 0.5 * (1.0 + 0.7 * sin(w * time) + 0.3 * sin(w * 2.37 * time + 1.3))
	return base + dir * gust_amplitude * gust
