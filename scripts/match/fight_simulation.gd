class_name FightSimulation
extends RefCounted
## Única autoridade da partida. step([P1,P2]) avança exatamente 1/120 s.
## Eventos são dados descartáveis; a apresentação decide quando reproduzi-los.
const TICK_RATE := 120
const LEFT_WALL := 60 * FighterModel.SCALE
const RIGHT_WALL := 1220 * FighterModel.SCALE
const BODY_WIDTH := 76 * FighterModel.SCALE
var projectiles: Array = []
var projectile_seq: int = 0
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


func _init(p1: CharacterData, p2: CharacterData) -> void:
	fighters = [FighterModel.new(p1, 0, 410), FighterModel.new(p2, 1, 870)]


func step(inputs: Array[CombatInput]) -> void:
	assert(inputs.size() == 2)
	events.clear()
	for i in 2:
		fighters[i].record_input(inputs[i], tick)
	if winner >= 0:
		round_wait += 1
		if round_wait >= 240 and not match_over:
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
		if defender.slot in attacker.hit_targets:
			continue
		var connected := false
		for hit in attacker.attack_boxes():
			for hurt in defender.hurtboxes():
				if BoxMath.overlap(hit, hurt):
					connected = true
		if connected:
			var move := attacker.current_move()
			if move.legacy.get("level", "") == "throw" and not defender.grounded():
				continue
			contacts.append(
				{
					"attacker": i,
					"defender": 1 - i,
					"move": move,
					"facing": attacker.facing,
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
		if not contact.blocked:
			attacker.combo += 1
			attacker.combo_ticks = maxi(100, move.hitstun * 2 + 30)
			attacker.meter = mini(100, attacker.meter + int(move.legacy.get("meter", 8)))
		defender.receive_hit(move, contact.facing, contact.blocked)
		freeze_ticks = maxi(freeze_ticks, move.hitstop * 2)
		events.append(
			{
				"id": "%d:%d:%d" % [tick, attacker.slot, defender.slot],
				"tick": tick,
				"kind": "block" if contact.blocked else "hit",
				"move": move.id,
				"character": attacker.character.id,
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
		if winner < 2:
			wins[winner] += 1
		match_over = wins[0] >= 2 or wins[1] >= 2
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
	assert(data.schema == 1)
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
	return var_to_bytes(snapshot()).hex_encode().sha256_text()


func _emit_powers() -> void:
	for f in fighters:
		if f.state != FighterState.Id.ATTACK:
			continue
		var move := f.current_move()
		if move.legacy.is_empty():
			continue
		var m := move.legacy
		if f.move_tick == 0:
			events.append(
				{
					"id": "%d:voice:%d" % [tick, f.slot],
					"kind": "voice",
					"character": f.character.id,
					"move": m.name,
					"tick": tick,
					"slot": f.slot,
					"x": f.x,
					"y": f.y
				}
			)
			if m.name == "super":
				freeze_ticks = maxi(freeze_ticks, 20)
		if not m.get("projectile", false) and not m.get("summon", false):
			continue
		var waves := int(m.get("waves", 3 if m.name == "super" else 1))
		if f.character.id == "marcelo" and m.name in ["super", "drone"]:
			waves = 5 if m.name == "super" else 1
		var release_tick := move.startup * 2 + f.emitted_waves * 10
		if f.emitted_waves >= waves or f.move_tick < release_tick:
			continue
		projectile_seq += 1
		var drone: bool = f.character.id == "marcelo" and m.name in ["super", "drone"]
		projectiles.append(
			{
				"id": projectile_seq,
				"owner": f.slot,
				"character": f.character.id,
				"move": move.id,
				"x": f.x + f.facing * 70 * FighterModel.SCALE,
				"y":
				f.y - (140 + (f.emitted_waves % 3) * 35 if drone else 185) * FighterModel.SCALE,
				"vx": f.facing * roundi(float(m.get("speed", 720)) * FighterModel.SCALE / 120.0),
				"age": 0,
				"ttl": 600,
				"delay": (80 if m.name == "super" else 240) if drone else 0,
				"warmup": 80 if m.name == "super" else 240,
				"drone": drone,
				"radius": int(m.get("radius", 26)),
				"effect": str(m.get("effect", f.character.id)),
				"lane": 0
			}
		)
		f.emitted_waves += 1


func _projectile_contacts(contacts: Array) -> void:
	var alive: Array = []
	for p in projectiles:
		p.age += 1
		if p.age > p.ttl:
			continue
		if p.delay > 0:
			p.delay -= 1
			alive.append(p)
			continue
		var attacker := fighters[int(p.owner)]
		var defender := fighters[1 - int(p.owner)]
		if p.drone:
			# Disparo acompanha a altura do alvo; sentinela no chão não perde o adversário.
			p.y = defender.y - 145 * FighterModel.SCALE
		p.x += p.vx
		if p.x < -100 * FighterModel.SCALE or p.x > 1380 * FighterModel.SCALE:
			continue
		var radius := int(p.radius) * FighterModel.SCALE
		var hit := Rect2i(int(p.x) - radius, int(p.y) - radius, radius * 2, radius * 2)
		var found := false
		var move := attacker.character.move_for(p.move)
		for hurt in defender.hurtboxes():
			if BoxMath.overlap(hit, hurt):
				found = true
		if found:
			contacts.append(
				{
					"attacker": attacker.slot,
					"defender": defender.slot,
					"move": move,
					"facing": signi(int(p.vx)),
					"blocked":
					move.legacy.get("level", "") != "throw" and defender.blocking(move.level),
					"projectile": true
				}
			)
		else:
			alive.append(p)
	projectiles = alive
