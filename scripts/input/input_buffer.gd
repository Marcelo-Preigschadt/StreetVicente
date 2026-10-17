class_name CommandBuffer
extends RefCounted
## Buffer de 100 ms = 12 ticks. Faz parte do snapshot, inclusive consumo.
const WINDOW_TICKS := 12
const COMMANDS := [
	CombatInput.CUSTOM,
	CombatInput.COUNTER,
	CombatInput.SUPER,
	CombatInput.SPECIAL,
	CombatInput.UPPERCUT,
	CombatInput.THROW,
	CombatInput.DRONE,
	CombatInput.KICK,
	CombatInput.PUNCH,
	CombatInput.UP,
	CombatInput.JUMP
]
var entries: Array = []


func record(input: CombatInput, tick: int) -> void:
	entries = entries.filter(func(e: Array) -> bool: return tick - int(e[1]) < WINDOW_TICKS)
	for command in COMMANDS:
		if (input.pressed & command) != 0:
			entries.append(
				[
					command,
					tick,
					2 if input.has(CombatInput.STRONG) else 0 if input.has(CombatInput.LIGHT) else 1
				]
			)


func strength(command: int, fallback: int = 1) -> int:
	for i in range(entries.size() - 1, -1, -1):
		if entries[i][0] == command:
			return int(entries[i][2]) if entries[i].size() > 2 else fallback
	return fallback


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


func discard(mask: int) -> void:
	entries = entries.filter(func(e: Array) -> bool: return (int(e[0]) & mask) == 0)
