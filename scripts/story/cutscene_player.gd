class_name CutscenePlayer
extends Node3D
# Plays a Cutscene: each beat's backdrop (job scenes run unpaid with their HUDs
# hidden), a camera that orbits, chases, or holds, and captions over letterbox
# bars. Any key skips. At the end it sets the seen flag and opens next_scene.
# Once seen, it forwards straight to next_scene unless `replay` is set. The
# cutscene's bed loops under every beat until it ends.

signal finished

## Set before opening the scene to play a cutscene that was already seen.
static var replay := false

@export var cutscene: Cutscene
## Seconds of fade at a backdrop change.
@export var fade := 0.6
## Input ignored for this long, so a key still held from the last scene doesn't skip.
@export var skip_grace := 0.4
@export var framing: ArcadeFraming = preload("res://data/framing/act1.tres")

var index := -1
var beat: CutsceneBeat
## Seconds into the current beat.
var t := 0.0
var done := false
var camera: Camera3D
var backdrop: Node
var caption: Label
var title_label: Label
var portrait: CharacterPortrait
## The card behind a portrait; "UNKNOWN" for a silhouette.
var card: PanelContainer
var card_name: Label
var bezel: Control
var curtain: ColorRect
## Plays the cutscene's bed; null when it has none.
var bed: AudioStreamPlayer

var _backdrop_path := ""
var _angle := 0.0
var _age := 0.0

func _ready() -> void:
	if cutscene.seen_flag != &"" and StoryFlags.is_set(cutscene.seen_flag) and not replay:
		done = true
		_go_next.call_deferred()
		return
	replay = false
	camera = Camera3D.new()
	camera.far = 4000.0
	add_child(camera)
	_build_overlay()
	_start_bed()
	advance()

func _process(delta: float) -> void:
	if done or beat == null:
		return
	_age += delta
	t += delta
	if t >= beat.duration:
		advance()
		if done:
			return
	_place_camera(delta)
	_fade()

func _input(event: InputEvent) -> void:
	if done or _age < skip_grace:
		return
	var pressed := (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton) \
		and event.is_pressed() and not event.is_echo()
	if pressed:
		get_viewport().set_input_as_handled()
		finish()

## Next beat, or the end.
func advance() -> void:
	index += 1
	if index >= cutscene.beats.size():
		finish()
		return
	beat = cutscene.beats[index]
	t = 0.0
	if beat.backdrop != "" and beat.backdrop != _backdrop_path:
		_load_backdrop(beat)
	_angle = 0.0
	caption.text = beat.caption
	title_label.text = beat.title
	card.visible = beat.portrait != &""
	if card.visible:
		var c: Character = Roster.character(beat.portrait)
		portrait.character = c
		portrait.modulate = Color(0.02, 0.02, 0.03) if beat.silhouette else Color.WHITE
		card_name.text = "UNKNOWN VIEWER" if beat.silhouette else c.name.to_upper()
		portrait.queue_redraw()
	bezel.visible = beat.bezel
	_place_camera(0.0, true)

func finish() -> void:
	if done:
		return
	done = true
	if bed:
		bed.stop()
	if cutscene.seen_flag != &"":
		StoryFlags.set_flag(cutscene.seen_flag)
	finished.emit()
	_go_next.call_deferred()

## The node the camera works from, or null.
func focus_node() -> Node3D:
	if backdrop == null or beat == null or beat.focus.is_empty():
		return null
	return backdrop.get_node_or_null(beat.focus) as Node3D

func _start_bed() -> void:
	var e := Sfx.bank.find(cutscene.bed) if Sfx.bank and cutscene.bed != &"" else null
	if e == null or e.streams.is_empty():
		push_warning("CutscenePlayer: no bed '%s'" % cutscene.bed)
		return
	bed = AudioStreamPlayer.new()
	bed.name = "Bed"
	bed.stream = e.streams[0]
	bed.bus = e.bus
	bed.volume_db = e.volume_db
	add_child(bed)
	bed.play()

func _go_next() -> void:
	if cutscene.next_scene != "" and is_inside_tree():
		get_tree().change_scene_to_file(cutscene.next_scene)

func _load_backdrop(b: CutsceneBeat) -> void:
	if backdrop:
		backdrop.free()
	_backdrop_path = b.backdrop
	backdrop = load(b.backdrop).instantiate()
	var runner := backdrop.find_child("JobRunner", false) as JobRunner
	if runner:
		runner.auto_begin = false
		runner.pays_out = false
		runner.confirm_risk = false
		runner.results_scene = null
		runner.back_scene = ""
	add_child(backdrop)
	for layer in backdrop.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	if runner:
		runner.begin()
		if b.live:
			runner.launch(true)
	camera.make_current()

func _place_camera(delta: float, snap := false) -> void:
	var f := focus_node()
	if f == null:
		return
	var at := f.global_position
	var want: Vector3
	match beat.camera:
		CutsceneBeat.Camera.ORBIT:
			_angle += deg_to_rad(beat.orbit_speed) * delta
			want = at + Vector3(cos(_angle), 0, sin(_angle)) * beat.orbit_radius + Vector3.UP * beat.orbit_height
		CutsceneBeat.Camera.CHASE:
			var fwd := -f.global_transform.basis.z
			fwd.y = 0.0
			fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
			var right := fwd.cross(Vector3.UP)
			want = at - fwd * beat.offset.z + Vector3.UP * beat.offset.y + right * beat.offset.x
		_:
			want = at + beat.offset
	camera.global_position = want if snap else camera.global_position.lerp(want, clampf(delta * 4.0, 0.0, 1.0))
	if not camera.global_position.is_equal_approx(at):
		camera.look_at(at, Vector3.UP)

func _fade() -> void:
	var into := t
	var out := beat.duration - t
	var next := cutscene.beats[index + 1] if index + 1 < cutscene.beats.size() else null
	var cuts_in := index == 0 or beat.backdrop != ""
	var cuts_out := next == null or next.backdrop != ""
	var black := 0.0
	if cuts_in:
		black = maxf(black, 1.0 - into / fade)
	if cuts_out:
		black = maxf(black, 1.0 - out / fade)
	curtain.color.a = clampf(black, 0.0, 1.0)
	var text_alpha := clampf(minf(into, out) / 0.5, 0.0, 1.0)
	caption.modulate.a = text_alpha
	title_label.modulate.a = text_alpha
	card.modulate.a = text_alpha

func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	bezel = _Bezel.new()
	bezel.framing = framing
	bezel.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bezel)
	for top in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color.BLACK
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.anchor_right = 1.0
		bar.anchor_top = 0.0 if top else 1.0
		bar.anchor_bottom = 0.0 if top else 1.0
		bar.offset_top = 0.0 if top else -84.0
		bar.offset_bottom = 84.0 if top else 0.0
		root.add_child(bar)
	caption = Label.new()
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.anchor_left = 0.15
	caption.anchor_right = 0.85
	caption.anchor_top = 1.0
	caption.anchor_bottom = 1.0
	caption.offset_top = -190.0
	caption.offset_bottom = -96.0
	caption.add_theme_font_size_override("font_size", 26)
	caption.add_theme_color_override("font_outline_color", Color.BLACK)
	caption.add_theme_constant_override("outline_size", 8)
	root.add_child(caption)
	title_label = Label.new()
	title_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 72)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.76, 0.25))
	title_label.add_theme_color_override("font_outline_color", Color.BLACK)
	title_label.add_theme_constant_override("outline_size", 12)
	root.add_child(title_label)
	card = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.32, 0.34, 0.4, 0.92)
	style.border_color = Color(0.35, 0.8, 0.95)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(16)
	card.add_theme_stylebox_override("panel", style)
	card.anchor_left = 0.5
	card.anchor_right = 0.5
	card.anchor_top = 0.5
	card.anchor_bottom = 0.5
	card.offset_left = -100.0
	card.offset_right = 100.0
	card.offset_top = -190.0
	card.offset_bottom = 30.0
	root.add_child(card)
	var stack := VBoxContainer.new()
	card.add_child(stack)
	portrait = CharacterPortrait.new()
	portrait.custom_minimum_size = Vector2(160, 160)
	stack.add_child(portrait)
	card_name = Label.new()
	card_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_name.add_theme_font_size_override("font_size", 14)
	stack.add_child(card_name)
	var skip := Label.new()
	skip.text = "Any key to skip"
	skip.modulate = Color(1, 1, 1, 0.5)
	skip.add_theme_font_size_override("font_size", 14)
	skip.anchor_left = 1.0
	skip.anchor_right = 1.0
	skip.offset_left = -180.0
	skip.offset_right = -24.0
	skip.offset_top = 32.0
	skip.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(skip)
	curtain = ColorRect.new()
	curtain.color = Color(0, 0, 0, 1)
	curtain.set_anchors_preset(Control.PRESET_FULL_RECT)
	curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(curtain)

## The home game's frame: a dark border, the league banner, and the player's handle.
class _Bezel extends Control:
	var framing: ArcadeFraming

	func _ready() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var s := size
		var b := 120.0
		var frame := Color(0.05, 0.05, 0.08)
		draw_rect(Rect2(0, 0, b, s.y), frame)
		draw_rect(Rect2(s.x - b, 0, b, s.y), frame)
		draw_rect(Rect2(b, 84, s.x - b * 2.0, s.y - 168), Color(0.35, 0.8, 0.95, 0.8), false, 2.0)
		var font := get_theme_default_font()
		if framing:
			draw_string(font, Vector2(b + 10, 106), framing.title, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.75))
			draw_string(font, Vector2(b + 10, s.y - 94), "PLAYER  " + PlayerProfile.handle(), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.76, 0.25))
