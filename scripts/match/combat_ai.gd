class_name CombatAI
extends RefCounted
## Seeded decisions; no RNG from presentation participates in combat.
var seed_value: int = 24681357
var tick: int = 0
var choice: int = 0


func sample(sim: FightSimulation, slot: int) -> CombatInput:
	tick += 1
	var f := sim.fighters[slot]
	var other := sim.fighters[1 - slot]
	var distance := absi(f.x - other.x) / FighterModel.SCALE
	var held := 0
	var pressed := 0
	if tick % 24 == 0:
		seed_value = (seed_value * 1103515245 + 12345) & 0x7fffffff
		choice = seed_value % 10
	if distance > 180:
		held = CombatInput.RIGHT if other.x > f.x else CombatInput.LEFT
	elif choice < 2:
		held = CombatInput.GUARD | (CombatInput.DOWN if choice == 1 else 0)
	if tick % 26 == 0:
		if f.meter >= 100 and choice > 3:
			pressed = CombatInput.SUPER
		elif distance > 250 and choice > 5:
			pressed = CombatInput.SPECIAL
		elif distance < 220:
			pressed = CombatInput.PUNCH if choice < 5 else CombatInput.KICK
		if choice == 9:
			pressed |= CombatInput.UP
	if choice == 8:
		held |= CombatInput.STRONG
	elif choice < 4:
		held |= CombatInput.LIGHT
	return CombatInput.new(held, pressed)
