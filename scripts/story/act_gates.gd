class_name ActGates
extends Resource
# Story 30.3: the scenes that open each of the Four's threads, one per act
# gate (Brahma at Act 1, Vishnu at 2, Shiva at 4, Krishna at 5). Career plays
# each once per save; a list so exported builds find them.

@export var gates: Array[Cutscene] = []

func for_act(act: int) -> Cutscene:
	for c in gates:
		if c.gate_act == act:
			return c
	return null
