class_name CrewLook
extends Resource
# How one crew member looks (Story 20.1): which body, skin, hair, outfit, and
# their accessory, so every view draws the same person. CrewFigure builds the
# 3D figure from it; the portrait reads the same colours.

## Parts of a body a look colours, in the order crew_body.gdshader numbers them.
const ROLES: Array[StringName] = [&"skin", &"hair", &"top", &"bottom", &"shoes"]

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
	return out
