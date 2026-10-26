extends Node
# Autoload "Wallet": the player's money.

signal changed(balance: int)

var balance := 0

func _ready() -> void:
	load_saved()

func add(amount: int) -> void:
	balance += amount
	changed.emit(balance)

func save() -> void:
	SaveGame.write_section("wallet", balance)

func load_saved() -> void:
	balance = int(SaveGame.read_section("wallet", 0))
	changed.emit(balance)
