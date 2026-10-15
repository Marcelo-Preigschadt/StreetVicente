class_name LocalCombatInput
extends Node
## Captura edges via eventos e polling; não perde um tap curto entre ticks.
var pending: Array[int] = [0, 0]
var previous: Array[int] = [0, 0]
const NAMES := ["left", "right", "down", "up", "punch", "kick", "guard"]

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	for slot in 2:
		for bit in NAMES.size():
			if event.is_action_pressed("p%d_%s" % [slot + 1, NAMES[bit]]):
				pending[slot] |= 1 << bit

func sample(slot: int) -> CombatInput:
	var held := 0
	for bit in NAMES.size():
		if Input.is_action_pressed("p%d_%s" % [slot + 1, NAMES[bit]]):
			held |= 1 << bit
	var result := CombatInput.new(held, pending[slot] | (held & ~previous[slot]))
	pending[slot] = 0
	previous[slot] = held
	return result

func clear() -> void:
	pending = [0, 0]
	previous = [0, 0]
	Input.release_pressed_events()
