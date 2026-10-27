class_name CrewWarning
extends Control
# Flashes a crew member's portrait while their HazardZone is warning, so the
# player always sees a strike coming at least a second before it can land.
# After a strike the portrait holds solid with the strike line for a moment.

@export var runner: JobRunner
## Seconds the strike notice stays up.
@export var strike_hold := 2.0
@export var flash_hz := 4.0

var portrait: CharacterPortrait
var label: Label
var _struck_id: StringName
var _struck_age := INF
var _t := 0.0
var _ring := Color.TRANSPARENT

func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	portrait = CharacterPortrait.new()
	portrait.size = Vector2(72, 72)
	add_child(portrait)
	label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 5)
	add_child(label)
	if runner:
		runner.state_changed.connect(func(s, _p): if s == JobRunner.State.BRIEFING: _connect_zones())
		_connect_zones.call_deferred()

func _connect_zones() -> void:
	for z in runner.hazard_zones():
		if not z.struck.is_connected(_on_struck):
			z.struck.connect(_on_struck)

func _on_struck(id: StringName, _cause: StringName) -> void:
	_struck_id = id
	_struck_age = 0.0

## Character ids whose zones are warning right now.
func warned() -> Array[StringName]:
	var out: Array[StringName] = []
	if runner:
		for z in runner.hazard_zones():
			if z.warning() and not z.character in out:
				out.append(z.character)
	return out

func _process(delta: float) -> void:
	_t += delta
	_struck_age += delta
	var w := warned()
	var c := size * Vector2(0.5, 0.0) + Vector2(0, 200)
	portrait.position = c - Vector2(36, 0)
	label.position = c + Vector2(-250, 78)
	label.size = Vector2(500, 30)
	if _struck_age < strike_hold:
		_show(_struck_id, "%s  STRUCK", Color(1.0, 0.35, 0.3), 1.0)
	elif not w.is_empty():
		var on := fmod(_t * flash_hz, 1.0) < 0.5
		_show(w[0], "%s  IN THE ZONE  ·  BACK OFF", Color(1.0, 0.76, 0.25), 1.0 if on else 0.4)
	else:
		portrait.visible = false
		label.visible = false
	queue_redraw()

## A dark disc and a colored ring behind the portrait so it reads over a bright sky.
func _draw() -> void:
	if not portrait.visible:
		return
	var c := portrait.position + portrait.size * 0.5
	draw_circle(c, 42.0, Color(0.05, 0.03, 0.05, 0.75))
	draw_arc(c, 42.0, 0.0, TAU, 48, _ring, 3.0, true)

func _show(id: StringName, text: String, color: Color, alpha: float) -> void:
	var ch: Character = Roster.character(id)
	portrait.character = ch
	portrait.visible = true
	portrait.modulate.a = alpha
	_ring = Color(color, alpha)
	portrait.queue_redraw()
	label.visible = true
	label.text = text % (ch.name.to_upper() if ch else String(id).to_upper())
	label.add_theme_color_override("font_color", color)
