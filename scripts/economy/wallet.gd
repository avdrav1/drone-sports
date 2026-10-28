extends Node
# Autoload "Wallet": the player's money, and the most one job ever paid (the
# title screen's best score, Story 17.3).

signal changed(balance: int)

var balance := 0
## The highest single job payout, ever.
var best_pay := 0

func _ready() -> void:
	load_saved()

func add(amount: int) -> void:
	balance += amount
	changed.emit(balance)

## A job paid `amount`; keeps it if it is the best yet. Saved with the wallet.
func record_pay(amount: int) -> void:
	best_pay = maxi(best_pay, amount)

func save() -> void:
	SaveGame.write_section("wallet", balance)
	SaveGame.write_section("best_pay", best_pay)

func load_saved() -> void:
	balance = int(SaveGame.read_section("wallet", 0))
	best_pay = int(SaveGame.read_section("best_pay", 0))
	changed.emit(balance)
