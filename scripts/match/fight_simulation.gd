class_name FightSimulation
extends RefCounted
## Única autoridade da partida. step([P1,P2]) avança exatamente 1/120 s.
## Eventos são dados descartáveis; a apresentação decide quando reproduzi-los.
const TICK_RATE := 120
const LEFT_WALL := 60 * FighterModel.SCALE
const RIGHT_WALL := 1220 * FighterModel.SCALE
const BODY_WIDTH := 76 * FighterModel.SCALE
var fighters: Array[FighterModel] = []
var tick: int = 0
var remaining_ticks: int = 99 * TICK_RATE
var freeze_ticks: int = 0
var winner: int = -1  # -1 em curso; 0/1 vencedor; 2 empate.
var events: Array = []


func _init(p1: CharacterData, p2: CharacterData) -> void:
	fighters = [FighterModel.new(p1, 0, 410), FighterModel.new(p2, 1, 870)]


func step(inputs: Array[CombatInput]) -> void:
	assert(inputs.size() == 2)
	events.clear()
	for i in 2:
		fighters[i].record_input(inputs[i], tick)
	if winner >= 0:
		tick += 1
		return
	if freeze_ticks > 0:
		freeze_ticks -= 1
		tick += 1
		return
	# Facing e decisões usam posições do início do tick em ambos os slots.
	var previous_x := [fighters[0].x, fighters[1].x]
	for i in 2:
		fighters[i].begin_tick(previous_x[1 - i])
	_resolve_bodies()
	var contacts: Array = []
	for i in 2:
		var attacker := fighters[i]
		var defender := fighters[1 - i]
		if defender.slot in attacker.hit_targets:
			continue
		var connected := false
		for hit in attacker.attack_boxes():
			for hurt in defender.hurtboxes():
				if BoxMath.overlap(hit, hurt):
					connected = true
		if connected:
			var move := attacker.current_move()
			contacts.append(
				{
					"attacker": i,
					"defender": 1 - i,
					"move": move,
					"facing": attacker.facing,
					"blocked": defender.blocking(move.level)
				}
			)
	# Coleta completa antes de aplicar: golpes simultâneos fazem trade.
	for contact in contacts:
		var attacker := fighters[int(contact.attacker)]
		var defender := fighters[int(contact.defender)]
		var move: MoveData = contact.move
		attacker.hit_targets.append(defender.slot)
		defender.receive_hit(move, contact.facing, contact.blocked)
		freeze_ticks = maxi(freeze_ticks, move.hitstop * 2)
		events.append(
			{
				"id": "%d:%d:%d" % [tick, attacker.slot, defender.slot],
				"tick": tick,
				"kind": "block" if contact.blocked else "hit",
				"slot": defender.slot,
				"x": defender.x,
				"y": defender.y - 110 * FighterModel.SCALE
			}
		)
	_resolve_bodies()
	for fighter in fighters:
		fighter.end_tick()
	remaining_ticks = maxi(0, remaining_ticks - 1)
	if fighters[0].health <= 0 or fighters[1].health <= 0 or remaining_ticks == 0:
		winner = (
			2
			if fighters[0].health == fighters[1].health
			else (0 if fighters[0].health > fighters[1].health else 1)
		)
	tick += 1


func _resolve_bodies() -> void:
	for fighter in fighters:
		fighter.x = clampi(fighter.x, LEFT_WALL, RIGHT_WALL)
	var a := fighters[0]
	var b := fighters[1]
	if absi(a.y - b.y) >= 175 * FighterModel.SCALE:
		return
	var left := a if a.x <= b.x else b
	var right := b if a.x <= b.x else a
	var overlap := BODY_WIDTH - (right.x - left.x)
	if overlap <= 0:
		return
	@warning_ignore("integer_division")
	var half: int = overlap / 2
	left.x -= half
	right.x += overlap - half
	if left.x < LEFT_WALL:
		right.x += LEFT_WALL - left.x
		left.x = LEFT_WALL
	if right.x > RIGHT_WALL:
		left.x -= right.x - RIGHT_WALL
		right.x = RIGHT_WALL


func snapshot() -> Dictionary:
	return {
		"schema": 1,
		"tick": tick,
		"remaining_ticks": remaining_ticks,
		"freeze_ticks": freeze_ticks,
		"winner": winner,
		"fighters": [fighters[0].snapshot(), fighters[1].snapshot()]
	}


func restore(data: Dictionary) -> void:
	assert(data.schema == 1)
	tick = data.tick
	remaining_ticks = data.remaining_ticks
	freeze_ticks = data.freeze_ticks
	winner = data.winner
	for i in 2:
		fighters[i].restore(data.fighters[i])
	events.clear()


func state_hash() -> String:
	# Ordem de campos fixa. Usar versão/build idênticos na comparação entre peers.
	return var_to_bytes(snapshot()).hex_encode().sha256_text()
