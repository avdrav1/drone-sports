class_name Quality
extends RefCounted
# The renderer extras a scene uses (Story 15.1). High adds what only Forward+
# has: SSAO, SSIL, SSR, SDFGI, volumetric fog, and longer, softer sun shadows.
# Low, or any other renderer, turns them all off. The tier is a player setting
# (GameSettings.quality); the web build is always Low.

enum Tier { LOW, HIGH }

## Sun shadow reach and softness on High; Low keeps the scene's own.
const HIGH_SHADOW_DISTANCE := 600.0
const HIGH_SUN_ANGLE := 1.2
## Bounce light strength; above 1 keeps shaded walls near the Low tier's brightness.
const SDFGI_ENERGY := 1.6
## Volumetric fog reach, m; regular fog carries on past it.
const VOLUMETRIC_LENGTH := 160.0
## Volumetric density per unit of the Environment's exponential fog density.
const VOLUMETRIC_PER_FOG := 0.5

## The renderer in use: "forward_plus", "mobile", or "gl_compatibility".
static func renderer() -> String:
	return RenderingServer.get_current_rendering_method()

## True when `tier` gets the extras under `method`.
static func extras_on(tier: int = GameSettings.quality, method: String = renderer()) -> bool:
	return tier == Tier.HIGH and method == "forward_plus"

## Sets `env`'s extras and `sun`'s shadows for `tier` under `method`. `env` must
## be a per-scene copy, never the shared resource; `sun` may be null.
static func apply(env: Environment, sun: DirectionalLight3D, tier: int = GameSettings.quality, method: String = renderer()) -> void:
	var on := extras_on(tier, method)
	env.ssao_enabled = on
	env.ssil_enabled = on
	env.ssr_enabled = on
	env.sdfgi_enabled = on
	env.volumetric_fog_enabled = on
	if on:
		env.sdfgi_use_occlusion = true
		env.sdfgi_cascades = 4
		env.sdfgi_energy = SDFGI_ENERGY
		env.ssr_max_steps = 48
		env.volumetric_fog_length = VOLUMETRIC_LENGTH
		env.volumetric_fog_anisotropy = 0.6
	fog(env)
	if sun:
		# The scene's own shadow, kept once so Low can go back to it.
		if not sun.has_meta(&"low_shadow"):
			sun.set_meta(&"low_shadow", [sun.directional_shadow_max_distance, sun.light_angular_distance])
		var low: Array = sun.get_meta(&"low_shadow")
		sun.directional_shadow_max_distance = HIGH_SHADOW_DISTANCE if on else low[0]
		sun.light_angular_distance = HIGH_SUN_ANGLE if on else low[1]

## Maps `env`'s exponential fog onto its volumetric fog, when that is on, so
## weather fog reads on both tiers. Weather.apply calls it after each change.
static func fog(env: Environment) -> void:
	if not env.volumetric_fog_enabled:
		return
	env.volumetric_fog_density = env.fog_density * VOLUMETRIC_PER_FOG if env.fog_enabled else 0.0
	env.volumetric_fog_albedo = env.fog_light_color
	env.volumetric_fog_sky_affect = env.fog_sky_affect
