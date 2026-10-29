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
## What they bring, lower case for mid-sentence: "Bea's site rates +18".
@export var name := ""
