class_name TitleScreen
extends Node
# The title (Story 17.3): the game's name, PRESS START, and the best score over
# the city slowly orbiting behind (a backdrop-only CutscenePlayer on the
# sandbox, HUDs hidden). Any key, click, or pad button opens the job board,
# which asks for a pilot first on a new game. Esc on the board comes back.
# The game opens here, even the first time: the intro is only shown from
# OPTIONS > Watch intro, and forwards here when it ends.
# Story 17.6: it wears the act's FrontSkin; the cabinet's Start is a coin chime.
# Story 17.12: between the logo and PRESS START, the story crawl rolls away
# into the distance: why you are playing. It loops until you press start.
# Story 18.5: come from the board, a crew member waves goodbye on the radio.
# Story 24.1: the logo is the game's name from the project settings.
# Story 24.6: lettered like Hindi, hanging from a headline bar (TitleMark).

const BOARD := "res://scenes/ui/job_board.tscn"
## Shown for a best score of zero.
const NO_SCORE := "- - - -"
const CRAWL := "res://data/ui/crawl.tres"

## Input ignored for this long, so the Esc that left the board doesn't start again.
@export var start_grace := 0.4
## PRESS START blinks on this period, s.
@export var blink := 1.1

var started := false
var title_mark: TitleMark
var press_start: Label
var best_label: Label
var crawl: StoryCrawl
var skin: FrontSkin
## Set by the board as you leave it: the next title says goodbye, once.
static var wave_goodbye := false
var bark: Bark
var radio: BarkBox

var _age := 0.0

@onready var backdrop: CutscenePlayer = $Backdrop

func _ready() -> void:
	skin = FrontSkin.current()
	_build()
	best_label.text = "BEST JOB  " + best_text(Wallet.best_pay)
	MusicDirector.title()
	if wave_goodbye:
		wave_goodbye = false
		goodbye()

## A crew member's goodbye on the radio, low on the left over the title.
func goodbye() -> Dictionary:
	if bark == null:
		bark = Bark.new()
		add_child(bark)
		radio = BarkBox.new()
		radio.bark = bark
		title_mark.get_parent().add_child(radio)
		radio.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return bark.moment(&"goodbye")

func _process(delta: float) -> void:
	_age += delta
	press_start.modulate.a = 1.0 if fmod(_age, blink) < blink * 0.65 else 0.15

## "- - - -" for nothing paid yet, else the payout.
static func best_text(best: int) -> String:
	return NO_SCORE if best <= 0 else str(best)

## Every key and button is the title's: none reaches the sandbox behind it.
func _input(event: InputEvent) -> void:
	if not (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton):
		return
	get_viewport().set_input_as_handled()
	if event.is_pressed() and not event.is_echo() and _age >= start_grace:
		start()

## Opens the board; it opens pilot select over itself when none is chosen.
func start() -> void:
	if started:
		return
	started = true
	Sfx.play(skin.start_sound if skin.start_sound != &"" else UiSounds.CONFIRM)
	get_tree().change_scene_to_file.call_deferred(BOARD)

func _build() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = skin.theme()
	layer.add_child(root)
	# Shade top and bottom so the text reads over any sky or sand.
	for top in [true, false]:
		var shade := TextureRect.new()
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shade.anchor_right = 1.0
		shade.anchor_top = 0.0 if top else 0.6
		shade.anchor_bottom = 0.4 if top else 1.0
		shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		shade.texture = _fade_texture(top)
		root.add_child(shade)
	title_mark = TitleMark.new()
	title_mark.name = "Title"
	title_mark.font_size = 128
	title_mark.add_theme_color_override("font_color", skin.accent)
	title_mark.add_theme_color_override("font_outline_color", Color.BLACK)
	title_mark.add_theme_constant_override("outline_size", 14)
	title_mark.anchor_right = 1.0
	title_mark.anchor_top = 0.1
	title_mark.anchor_bottom = 0.32
	root.add_child(title_mark)
	crawl = StoryCrawl.new()
	crawl.name = "Crawl"
	crawl.crawl = load(CRAWL)
	crawl.color = skin.accent
	crawl.font = skin.display_font if skin.display_font else skin.font
	crawl.heading_font = crawl.font
	crawl.anchor_right = 1.0
	crawl.anchor_top = 0.3
	crawl.anchor_bottom = 0.7
	root.add_child(crawl)
	press_start = _label("PRESS START", 34, skin.text, 8)
	press_start.theme_type_variation = &"Display"
	press_start.name = "PressStart"
	_place(press_start, 0.7, 0.78)
	root.add_child(press_start)
	best_label = _label("", 22, skin.heading, 6)
	best_label.name = "Best"
	_place(best_label, 0.86, 0.94)
	root.add_child(best_label)
	if skin.scanlines:
		var lines := Scanlines.new()
		lines.name = "Scanlines"
		root.add_child(lines)

## Spans the width between two heights, as fractions of the screen.
func _place(c: Control, top: float, bottom: float) -> void:
	c.anchor_right = 1.0
	c.anchor_top = top
	c.anchor_bottom = bottom
	c.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

## Black at the screen edge fading to clear towards the middle.
func _fade_texture(top: bool) -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0.6 if top else 0.0))
	g.set_color(1, Color(0, 0, 0, 0.0 if top else 0.7))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	return tex

func _label(text: String, font_size: int, color: Color, outline: int) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", outline)
	return l
