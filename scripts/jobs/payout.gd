class_name Payout
extends RefCounted
# Settles a finished job: pays the wallet, keeps the best payout, moves faction
# reputation, saves.

static func settle(result: JobResult, scale: GradeScale) -> void:
	result.pay = roundi(result.job.pay * float(scale.pay_multiplier.get(result.letter, 0.0)))
	result.reputation_change = int(scale.reputation_change.get(result.letter, 0))
	Wallet.add(result.pay)
	Wallet.record_pay(result.pay)
	Reputation.add(result.job.faction, result.reputation_change)
	Wallet.save()
	Reputation.save()
