class_name Payout
extends RefCounted
# Settles a finished job: pays the wallet, keeps the best payout, moves faction
# reputation, saves. The fit crew's pay and reputation perks (Story 19.5) add
# on top, each owner's share listed in result.bonuses for the results screen.

static func settle(result: JobResult, scale: GradeScale) -> void:
	result.pay = roundi(result.job.pay * float(scale.pay_multiplier.get(result.letter, 0.0)))
	result.reputation_change = int(scale.reputation_change.get(result.letter, 0))
	result.bonuses.clear()
	result.pay += _bonus(result, &"pay", result.pay, "")
	# Gains only: a perk never deepens a loss.
	if result.reputation_change > 0:
		result.reputation_change += _bonus(result, &"reputation", result.reputation_change, " reputation")
	Wallet.add(result.pay)
	Wallet.record_pay(result.pay)
	Reputation.add(result.job.faction, result.reputation_change)
	Wallet.save()
	Reputation.save()

## Each fit owner's share of `base` from their perk of `kind`, listed in
## result.bonuses as {id, text, amount}, e.g. "Bhima's site rates", 18. The total.
static func _bonus(result: JobResult, kind: StringName, base: int, unit: String) -> int:
	var total := 0
	for c in Perks.owners(kind):
		var amount := roundi(base * c.perk.amount)
		if amount <= 0:
			continue
		result.bonuses.append({"id": c.id, "text": "%s's %s" % [c.name, c.perk.name], "amount": amount, "unit": unit})
		total += amount
	return total
