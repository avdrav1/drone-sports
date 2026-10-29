extends Node
# Autoload "SaveCarry", first in the list (Story 24.2): before any other
# autoload reads the save, a save from before the game was renamed is carried
# into the new user:// folder.

func _ready() -> void:
	SaveGame.carry_over_on_boot()
