class_name FightSimulation
extends RefCounted
## Única autoridade da partida. step([P1,P2]) avança exatamente 1/120 s.
## Eventos são dados descartáveis; a apresentação decide quando reproduzi-los.
const TICK_RATE := 120
const LEFT_WALL := 60 * FighterModel.SCALE
const RIGHT_WALL := 1220 * FighterModel.SCALE
const BODY_WIDTH := 76 * FighterModel.SCALE
const INTRO_TICKS := 336  # Full original voice clips: Round 1.165s, number 0.766s, Fight 0.682s.
const FIGHT_TICKS := 96
const ROUND_WAIT_TICKS := 408  # Allows You/Win/Perfect to finish without cutting syllables.
var powers := PowerSystem.new()
var projectiles: Array:
	get:
		return powers.projectiles
	set(value):
		powers.projectiles = value
var projectile_seq: int:
	get:
		return powers.sequence
	set(value):
		powers.sequence = value
var wins: Array = [0, 0]
var round_number: int = 1
var round_wait: int = 0
var match_over: bool = false
var fighters: Array[FighterModel] = []
var tick: int = 0
var remaining_ticks: int = 99 * TICK_RATE
var freeze_ticks: int = 0
var winner: int = -1  # -1 em curso; 0/1 vencedor; 2 empate.
var events: Array = []
var round_intros: bool = false
var intro_ticks: int = 0


func _init(p1: CharacterData, p2: CharacterData) -> void:
	fighters = [FighterModel.new(p1, 0, 410), FighterModel.new(p2, 1, 870)]


func begin_round_intro() -> void:
	round_intros = true
	intro_ticks = INTRO_TICKS


func _announce(cue: String) -> void:
	events.append({"id": "%d:announce:%s" % [tick, cue], "kind": "announcer", "cue": cue})


func step(inputs: Array[CombatInput]) -> void:
	assert(inputs.size() == 2)
	events.clear()
	powers.events.clear()
	if intro_ticks > 0:
		# Discard pre-fight buttons instead of buffering an accidental opening attack.
		for f in fighters:
			f.record_input(CombatInput.new(), tick)
			f.buffer = CommandBuffer.new()
			f.state_tick += 1
		if intro_ticks == INTRO_TICKS:
			_announce("round")
		elif intro_ticks == INTRO_TICKS - 144:
			_announce(str(mini(round_number, 9)))
		elif intro_ticks == FIGHT_TICKS:
			_announce("fight")
		intro_ticks -= 1
		tick += 1
		return
	for i in 2:
		fighters[i].record_input(inputs[i], tick)
	if winner >= 0:
		if freeze_ticks > 0:
			freeze_ticks -= 1
			tick += 1
			return
		round_wait += 1
		for f in fighters:
			f._integrate_air()
			f.state_tick += 1
			if round_wait == 1:
				f.roll_phase = 0
			if round_wait == 1 and f.health > 0:
				f.move_id = ""
				f.transition(FighterState.Id.IDLE if f.grounded() else FighterState.Id.JUMP)
		if winner != 2 and round_wait >= 90 and fighters[winner].grounded():
			fighters[winner].transition(FighterState.Id.VICTORY)
		if round_wait == 1:
			_announce("ko")
		elif round_wait == 90 and winner != 2:
			_announce("you")
		elif round_wait == 198 and winner != 2:
			_announce("win" if winner == 0 else "lose")
		elif round_wait == 288 and winner != 2:
			if fighters[winner].health == fighters[winner].character.max_health:
				_announce("perfect")
		if round_wait >= ROUND_WAIT_TICKS and not match_over:
			var charge := [fighters[0].meter, fighters[1].meter]
			fighters = [
				FighterModel.new(fighters[0].character, 0, 410),
				FighterModel.new(fighters[1].character, 1, 870)
			]
			for i in 2:
				fighters[i].meter = charge[i]
			winner = -1
			round_number += 1
			round_wait = 0
			remaining_ticks = 99 * TICK_RATE
			projectiles.clear()
			freeze_ticks = 0
			if round_intros:
				intro_ticks = INTRO_TICKS
			events.append(
				{"id": "%d:round" % tick, "kind": "round", "tick": tick, "slot": 0, "x": 0, "y": 0}
			)
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
	for i in 2:
		if fighters[i].state == FighterState.Id.WALK:
			fighters[i].walk_distance += absi(fighters[i].x - int(previous_x[i]))
	_emit_powers()
	var contacts: Array = []
	for i in 2:
		var attacker := fighters[i]
		var defender := fighters[1 - i]
		if RollMotion.active(attacker) and not RollMotion.can_contact(attacker, defender):
			continue
		if defender.slot in attacker.hit_targets:
			continue
		var connected := false
		var point := Vector2i.ZERO
		for hit in attacker.attack_boxes():
			for hurt in defender.hurtboxes():
				if BoxMath.overlap(hit, hurt):
					connected = true
					var overlap := hit.intersection(hurt)
					point = overlap.position + overlap.size / 2
					break
			if connected:
				break
		if connected:
			var move := (
				RollMotion.contact_move(attacker)
				if RollMotion.active(attacker)
				else attacker.current_move()
			)
			if move.legacy.get("level", "") == "throw" and not defender.grounded():
				continue
			contacts.append(
				{
					"attacker": i,
					"defender": 1 - i,
					"move": move,
					"facing": attacker.facing,
					"impact_x": point.x,
					"impact_y": point.y,
					"blocked":
					move.legacy.get("level", "") != "throw" and defender.blocking(move.level)
				}
			)
	_projectile_contacts(contacts)
	# Coleta completa antes de aplicar: golpes simultâneos fazem trade.
	for contact in contacts:
		var attacker := fighters[int(contact.attacker)]
		var defender := fighters[int(contact.defender)]
		var move: MoveData = contact.move
		if not contact.get("projectile", false):
			attacker.hit_targets.append(defender.slot)
		attacker.has_contact = true
		var combo_name := ""
		if not contact.blocked:
			combo_name = attacker.connect_hit(defender, move)
			attacker.meter = mini(100, attacker.meter + int(move.legacy.get("meter", 8)))
		var before_health := defender.health
		var region := (
			"head"
			if defender.y - int(contact.get("impact_y", defender.y)) >= 210 * FighterModel.SCALE
			else "body"
		)
		defender.receive_hit(
			move,
			contact.facing,
			contact.blocked,
			attacker.slot,
			attacker.combo,
			attacker.scaled_damage(move),
			region
		)
		var rolling := RollMotion.active(attacker)
		if rolling:
			RollMotion.contact(attacker, defender, contact.blocked)
		freeze_ticks = maxi(freeze_ticks, move.hitstop * 2)
		events.append(
			{
				"id":
				"%d:%d:%d:%d" % [tick, attacker.slot, defender.slot, int(contact.get("entity", 0))],
				"tick": tick,
				"kind": "block" if contact.blocked else "hit",
				"move": move.id,
				"character": attacker.character.id,
				"slot": defender.slot,
				"attacker": attacker.slot,
				"facing": contact.facing,
				"damage": before_health - defender.health,
				"combo": attacker.combo,
				"combo_name": combo_name,
				"effect":
				(
					"electricRoll"
					if rolling
					else str(contact.get("effect", move.legacy.get("effect", "")))
				),
				"power_kind":
				(
					"roll"
					if rolling
					else str(
						contact.get(
							"power_kind",
							(
								"strike"
								if move.legacy.get("name", "") in ["special", "super", "uppercut"]
								else ""
							)
						)
					)
				),
				"x": int(contact.get("impact_x", defender.x)),
				"y": int(contact.get("impact_y", defender.y - 190 * FighterModel.SCALE))
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
		if winner < 2:
			wins[winner] += 1
		match_over = wins[0] >= 2 or wins[1] >= 2
		projectiles.clear()
		for f in fighters:
			f.input = CombatInput.new()
			f.buffer = CommandBuffer.new()
			f.push_remaining = 0
			f.push_ticks = 0
		events.append(
			{
				"id": "%d:round_end" % tick,
				"kind": "round_end",
				"winner": winner,
				"round": round_number,
				"life": fighters[0].health,
				"seconds": ceili(remaining_ticks / 120.0),
				"ko": fighters[1].health <= 0
			}
		)
		if match_over:
			events.append({"id": "%d:result" % tick, "kind": "result", "winner": winner})
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
	var overlap := CombatGeometry.half_width(a) + CombatGeometry.half_width(b) - (right.x - left.x)
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
		"round_intros": round_intros,
		"intro_ticks": intro_ticks,
		"projectiles": projectiles.duplicate(true),
		"projectile_seq": projectile_seq,
		"wins": wins.duplicate(),
		"round_number": round_number,
		"round_wait": round_wait,
		"match_over": match_over,
		"tick": tick,
		"remaining_ticks": remaining_ticks,
		"freeze_ticks": freeze_ticks,
		"winner": winner,
		"fighters": [fighters[0].snapshot(), fighters[1].snapshot()]
	}


func restore(data: Dictionary) -> void:
	data = SnapshotCodec.integers(data)
	assert(data.schema == 1)
	round_intros = data.get("round_intros", false)
	intro_ticks = data.get("intro_ticks", 0)
	projectiles = data.get("projectiles", []).duplicate(true)
	projectile_seq = data.get("projectile_seq", 0)
	wins = data.get("wins", [0, 0]).duplicate()
	round_number = data.get("round_number", 1)
	round_wait = data.get("round_wait", 0)
	match_over = data.get("match_over", false)
	tick = data.tick
	remaining_ticks = data.remaining_ticks
	freeze_ticks = data.freeze_ticks
	winner = data.winner
	for i in 2:
		fighters[i].restore(data.fighters[i])
	events.clear()


func state_hash() -> String:
	# Ordem de campos fixa. Usar versão/build idênticos na comparação entre peers.
	return SnapshotCodec.state_hash(snapshot())


func power_actors() -> Array[FighterModel]:
	return fighters


func _emit_powers() -> void:
	for f in fighters:
		if powers.emit(f, tick):
			freeze_ticks = maxi(freeze_ticks, 20)
	events.append_array(powers.events)
	powers.events.clear()


func _projectile_contacts(contacts: Array) -> void:
	contacts.append_array(powers.advance(fighters, 1280, tick))
	events.append_array(powers.events)
	powers.events.clear()
