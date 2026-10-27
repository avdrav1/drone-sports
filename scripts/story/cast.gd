class_name Cast
extends Resource
# The list of characters the Roster loads. A list rather than a folder scan, so
# exported builds (where .tres files are remapped) find them too.

@export var characters: Array[Character] = []
