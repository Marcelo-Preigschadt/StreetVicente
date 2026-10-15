class_name ReplayTimeline
extends RefCounted
## Histórico LOCAL para testar save/load e correção de inputs atrasados.
## Não é uma sessão online: não implementa transporte, previsão nem confirmação.
const CAPACITY := 240
var history: Dictionary = {}


func advance(sim: FightSimulation, inputs: Array[CombatInput]) -> void:
	history[sim.tick] = {
		"before": sim.snapshot(), "inputs": [inputs[0].serialize(), inputs[1].serialize()]
	}
	sim.step(inputs)
	history.erase(sim.tick - CAPACITY - 1)


func correct_and_replay(
	sim: FightSimulation, from_tick: int, slot: int, corrected: CombatInput
) -> bool:
	if not history.has(from_tick) or slot < 0 or slot > 1:
		return false
	var end_tick := sim.tick
	history[from_tick].inputs[slot] = corrected.serialize()
	sim.restore(history[from_tick].before)
	for frame in range(from_tick, end_tick):
		var recorded: Array = history[frame].inputs
		var inputs: Array[CombatInput] = [
			CombatInput.new(recorded[0][0], recorded[0][1]),
			CombatInput.new(recorded[1][0], recorded[1][1])
		]
		history[frame].before = sim.snapshot()
		sim.step(inputs)
	return true
