class_name HangarCatalog
extends Resource
# Story 27.1: what the hangar knows of: the default livery, the decals, and the
# parts with each kind's default. Story 27.3: the palette, and how each item
# that is not a default unlocks. A list rather than a folder scan, so exported
# builds (where .tres files are remapped) find them too.

## Every slot starts on this: the drone as it looked before the hangar.
@export var default_livery: Livery
## Decal ids a livery may wear; DecalArt draws each (Story 27.2).
@export var decals: Array[StringName] = []
## Every part, of every kind.
@export var parts: Array[Part] = []
## One part per kind, fitted to every slot until changed. They change nothing:
## the drone as it was (Story 27.4's defaults).
@export var default_parts: Array[Part] = []
## Every colour a livery may pick (Story 27.3).
@export var palette: Array[Swatch] = []
## One per item that is not a default: every decal, every part and swatch but
## the defaults, and lit lights (Story 27.3).
@export var unlocks: Array[Unlock] = []
## The names a pad picks a drone's name from, having no keys to type one on
## (Story 27.5).
@export var drone_names: Array[String] = []
