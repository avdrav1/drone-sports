class_name CrewLook
extends Resource
# How one crew member looks (Story 20.1): which body, skin, hair, outfit, and
# their accessory, so every view draws the same person. CrewFigure builds the
# 3D figure from it; the portrait reads the same colours.

## Parts of a body a look colours, in the order crew_body.gdshader numbers them.
const ROLES: Array[StringName] = [&"skin", &"hair", &"top", &"bottom", &"shoes"]
## The portrait's iconography (Story 26.2), each drawn by CharacterPortrait:
## what is worn on the head, the hair (empty takes the body's), the beard, the
## held object, and marks on the face and body.
const HEADWEAR: Array[StringName] = [&"", &"crown", &"helmet", &"turban", &"band", &"crest"]
const HAIR: Array[StringName] = [&"", &"long", &"curls", &"short", &"jata", &"bald"]
const BEARDS: Array[StringName] = [&"", &"moustache", &"beard"]
const HELD: Array[StringName] = [&"", &"bow", &"gada", &"chakra", &"stone", &"herb"]
const MARKS: Array[StringName] = [&"tilak", &"tripundra", &"glow", &"earrings", &"necklace", &"beads", &"sacred_thread", &"armour", &"sash", &"neck_ring"]

@export var body: CrewBody
@export var skin := Color(0.96, 0.78, 0.62)
@export var hair := Color(0.25, 0.18, 0.14)
@export var top := Color(0.4, 0.6, 0.9)
@export var bottom := Color(0.25, 0.28, 0.4)
@export var shoes := Color(0.2, 0.2, 0.24)
## Worn on the head, one of Character.SHAPES; matches the character's shape.
@export var accessory: StringName = &"round"
## The accessory's main colour.
@export var accessory_color := Color(1, 0.8, 0.3)
## Its second colour: lenses, band, ball, fin.
@export var accessory_detail := Color(1, 1, 1)
## The kind of head their portrait paints (Story 26.1), one of
## CharacterPortrait.HEADS: human, vanara or bird.
@export var head: StringName = &"human"
## On the portrait's head, one of HEADWEAR, in accessory_color with
## accessory_detail for its jewels and trim (Story 26.2).
@export var headwear: StringName
## The portrait's hair, one of HAIR; empty takes the body's hair style.
@export var hair_cut: StringName
## One of BEARDS, in the hair colour.
@export var beard: StringName
## What they carry, one of HELD, on the left (-1) or right (1) shoulder.
@export var held: StringName
@export var held_side := -1.0
## Marks and ornaments, each one of MARKS.
@export var marks: Array[StringName] = []
## 0 is young, 1 an elder: lines on the face, a drawn jaw, greying.
@export_range(0.0, 1.0) var age := 0.0
## 1 is an average frame; more is broader in the jaw, neck and brow.
@export_range(0.8, 1.4) var build := 1.0

## The colour of one of ROLES.
func color(role: StringName) -> Color:
	return get(role)

## The hair style comes with the body.
func hair_style() -> StringName:
	return body.hair_style if body else &""

## Problems with this look; empty when it is valid.
func validate() -> Array[String]:
	var out: Array[String] = []
	if body == null:
		out.append("look has no body")
	else:
		out.append_array(body.validate())
	if not accessory in Character.SHAPES:
		out.append("unknown accessory %s" % accessory)
	if not head in CharacterPortrait.HEADS:
		out.append("unknown head %s" % head)
	for pair in [[headwear, HEADWEAR], [hair_cut, HAIR], [beard, BEARDS], [held, HELD]]:
		if not pair[0] in pair[1]:
			out.append("unknown %s" % pair[0])
	for m in marks:
		if not m in MARKS:
			out.append("unknown mark %s" % m)
	return out
