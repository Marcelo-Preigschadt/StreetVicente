class_name CommandBuffer
extends RefCounted
## Buffer de 100 ms = 12 ticks. Faz parte do snapshot, inclusive consumo.
const WINDOW_TICKS := 12
const COMMANDS := [CombatInput.KICK, CombatInput.PUNCH, CombatInput.UP]
var entries: Array = []

func record(input: CombatInput, tick: int) -> void:
	entries = entries.filter(func(e: Array) -> bool: return tick - int(e[1]) < WINDOW_TICKS)
	for command in COMMANDS:
		if (input.pressed & command) != 0:
			entries.append([command, tick])

func consume(command: int) -> bool:
	for i in range(entries.size() - 1, -1, -1):
		if entries[i][0] == command:
			entries.remove_at(i)
			return true
	return false

func snapshot() -> Array:
	return entries.duplicate(true)

func restore(data: Array) -> void:
	entries = data.duplicate(true)
