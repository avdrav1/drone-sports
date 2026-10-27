class_name UpgradeList
extends Resource
# Every upgrade the shop sells, in shop order. A list rather than a folder scan,
# so exported builds (where .tres files are remapped) find them too.

@export var upgrades: Array[Upgrade] = []
