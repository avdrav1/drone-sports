class_name CrewPerk
extends Resource
# What a support crew member brings while fit to work (Story 19.4): on while
# they are active, off while benched, gone for good once dead. Systems ask
# Perks for a kind and never name a character (CLAUDE.md rule 6).

## pay and reputation: fraction added to a job's pay or reputation gain.
## price: fraction off every Garage price. guidance: steps of route guidance
## added on a job. recovery: jobs off an injury's time on the bench.
const KINDS: Array[StringName] = [&"pay", &"reputation", &"price", &"guidance", &"recovery"]

## One of KINDS.
@export var kind: StringName
@export var amount := 0.0
## What they bring, lower case for mid-sentence: "Bhima's site rates +18".
@export var name := ""

## What it does in plain words (Story 19.7), from kind and amount, e.g.
## "+15% pay on every job".
func effect_text() -> String:
	var pct := roundi(amount * 100.0)
	match kind:
		&"pay":
			return "+%d%% pay on every job" % pct
		&"reputation":
			return "+%d%% reputation from every job" % pct
		&"price":
			return "Garage prices %d%% lower" % pct
		&"guidance":
			return "Route guidance %s better on every job" % ("one step" if roundi(amount) == 1 else "%d steps" % roundi(amount))
		&"recovery":
			return "Injured crew back %s sooner" % ("one job" if roundi(amount) == 1 else "%d jobs" % roundi(amount))
	return ""

## "Site rates", for the start of a line.
func title() -> String:
	return name.left(1).to_upper() + name.substr(1)

## "Site rates: +15% pay on every job".
func line() -> String:
	return "%s: %s" % [title(), effect_text()]
