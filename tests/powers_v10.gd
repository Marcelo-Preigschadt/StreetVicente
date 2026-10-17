class_name PowersV10Tests
extends RefCounted
const UNIT := FighterModel.SCALE


static func run(s: SceneTree) -> void:
	_round_end(s)
	for direction in [1, -1]:
		for distance in [220, 500, 900]:
			for strength in 3:
				_roll(s, distance, direction, strength, false)
				_roll(s, distance, direction, strength, true)
	_roll_whiff_and_interrupt(s)
	_uppers(s)
	_story(s)


static func _inputs(guard: bool = false) -> Array[CombatInput]:
	return [CombatInput.new(), CombatInput.new(CombatInput.GUARD if guard else 0)]


static func _sim(id: String, distance: int, direction: int = 1) -> FightSimulation:
	var sim := FightSimulation.new(
		LegacyRoster.get_character(id), LegacyRoster.get_character("rafael")
	)
	sim.fighters[0].x = (160 if direction == 1 else 1120) * UNIT
	sim.fighters[1].x = sim.fighters[0].x + direction * distance * UNIT
	sim.fighters[0].facing = direction
	sim.fighters[1].facing = -direction
	return sim


static func _round_end(s: SceneTree) -> void:
	for timeout in [false, true]:
		var sim := _sim("marcelo", 140)
		sim.wins[0] = 1  # Exercise final match settlement, beyond the round reset deadline.
		var fx := CombatImpact.new()
		if timeout:
			sim.remaining_ticks = 1
			sim.fighters[1].health = 1
		else:
			sim.fighters[1].health = 1
			sim.fighters[0]._start_move(sim.fighters[0].character.get_move("punch", 2))
		var calls: Array = []
		var ko_freeze := false
		var victory_x := 0
		for tick in 520:
			sim.step(_inputs())
			fx.consume(sim.events, sim)
			fx._process(1.0 / 120)
			if sim.winner >= 0 and sim.freeze_ticks > 0:
				ko_freeze = true
			if sim.round_wait >= 30:
				s.check(
					sim.freeze_ticks == 0 and fx.shake == 0,
					"KO/timeout: hitstop e vibração terminam"
				)
			if sim.round_wait == 100:
				victory_x = sim.fighters[0].x
			if sim.round_wait > 100:
				s.check(sim.fighters[0].x == victory_x, "Vitória estável sem deslocamento residual")
			for e in sim.events:
				if e.kind == "announcer":
					calls.append(e.cue)
			s.check(sim.projectiles.is_empty(), "Poderes encerrados após o round")
		s.check(sim.winner == 0, "KO e timeout preservam o vencedor")
		s.check(timeout or ko_freeze, "Último impacto conserva hitstop antes de drenar")
		s.check(calls.slice(0, 3) == ["ko", "you", "win"], "Anúncios do round em ordem e uma vez")
		fx.free()


static func _roll(s: SceneTree, distance: int, direction: int, strength: int, guard: bool) -> void:
	var sim := _sim("joao", distance, direction)
	var f := sim.fighters[0]
	var start := f.x
	f._start_move(f.character.get_move("special", strength))
	var hits: Array = []
	var blocks := 0
	var contact_x := 0
	var retreated := false
	var phases: Dictionary = {}
	for tick in 420:
		sim.step(_inputs(guard))
		phases[f.roll_phase] = true
		for e in sim.events:
			if e.kind in ["hit", "block"]:
				if contact_x == 0:
					contact_x = f.x
				if e.kind == "block":
					blocks += 1
				else:
					hits.append(e)
				s.check(e.effect == "electricRoll", "Contato do rolinho dispara choque próprio")
				s.check(
					(f.x - start) * direction >= (distance - 220) * UNIT,
					"Rolinho percorre a distância até contato"
				)
		if contact_x != 0 and (contact_x - f.x) * direction > 20 * UNIT:
			retreated = true
		s.check(sim.projectiles.is_empty(), "Rolinho é o corpo do João, sem projétil substituto")
		s.check(
			f.x >= FightSimulation.LEFT_WALL and f.x <= FightSimulation.RIGHT_WALL,
			"Rolinho respeita paredes"
		)
		if (
			f.roll_phase in [RollMotion.TRAVEL, RollMotion.SHOCK, RollMotion.REBOUND]
			and tick % 13 == 0
		):
			var saved := sim.snapshot()
			for i in 12:
				sim.step(_inputs(guard))
			var expected := sim.state_hash()
			sim.restore(saved)
			for i in 12:
				sim.step(_inputs(guard))
			s.check(sim.state_hash() == expected, "Snapshot/replay do rolinho determinístico")
			# Restore once more so the main loop still observes every contact event.
			sim.restore(saved)
	if guard:
		s.check(blocks == 1 and hits.is_empty(), "Defesa interrompe no primeiro contato sem combo")
		s.check(not phases.has(RollMotion.SHOCK), "Defesa não entra no estado de choque")
	else:
		s.check(hits.size() == 3 and blocks == 0, "Rolinho conecta exatamente três pulsos")
		if hits.size() == 3:
			s.check(
				hits.map(func(e: Dictionary) -> int: return e.combo) == [1, 2, 3],
				"Três choques são combo contínuo"
			)
			s.check(hits[2].damage > hits[0].damage, "Terceiro pulso é o finalizador")
		s.check(
			sim.fighters[1].dizzy_ticks == 0, "Um rolinho não impõe tontura automática após o combo"
		)
		s.check(phases.has(RollMotion.SHOCK), "Acerto entra na sequência elétrica")
	s.check(
		phases.has(RollMotion.REBOUND) and retreated,
		"Acerto/defesa provocam rebote físico para trás"
	)
	s.check(
		f.state == FighterState.Id.IDLE and f.grounded(),
		"Rolinho termina no chão com controle recuperado"
	)


static func _roll_whiff_and_interrupt(s: SceneTree) -> void:
	var sim := _sim("joao", 900)
	var f := sim.fighters[0]
	sim.fighters[1].invincible_ticks = 2000
	f._start_move(f.character.get_move("special", 1))
	var hits := 0
	for i in 500:
		sim.step(_inputs())
		hits += sim.events.filter(func(e: Dictionary) -> bool: return e.kind == "hit").size()
	s.check(
		hits == 0 and f.state == FighterState.Id.IDLE, "Erro/invulnerabilidade não prende no giro"
	)
	s.check(f.roll_hits == 0, "Whiff não cria combo fantasma")
	for phase in [RollMotion.TRAVEL, RollMotion.SHOCK, RollMotion.REBOUND]:
		f._start_move(f.character.get_move("special", 1))
		f.roll_phase = phase
		f.receive_hit(sim.fighters[1].character.get_move("punch", 1), -1, false)
		s.check(
			not RollMotion.active(f) and f.attack_boxes().is_empty(),
			"Interrupção cancela o rolinho em toda fase"
		)


static func _uppers(s: SceneTree) -> void:
	for id in LegacyRoster.ids():
		for direction in [1, -1]:
			for distance in [260, 700]:
				for guard in [false, true]:
					var sim := _sim(id, distance, direction)
					var f := sim.fighters[0]
					f._start_move(f.character.get_move("uppercut", 1))
					var hits := 0
					var blocks := 0
					for tick in 260:
						sim.step(_inputs(guard))
						for e in sim.events:
							hits += int(e.kind == "hit")
							blocks += int(e.kind == "block")
						if (
							f.state == FighterState.Id.ATTACK
							and f.current_move().phase(f.move_tick) != "ACTIVE"
						):
							s.check(
								f.attack_boxes().is_empty(),
								"Gancho sem colisão em preparação/recuperação: " + id
							)
					if distance == 260:
						s.check(
							hits == (0 if guard else 1) and blocks == (1 if guard else 0),
							"Gancho alcança 260px e respeita defesa/espelho: " + id
						)
					else:
						s.check(
							hits == 0 and blocks == 0,
							"Gancho não vira golpe de tela inteira: " + id
						)
					s.check(
						f.grounded() and f.state == FighterState.Id.IDLE,
						"Gancho recupera no chão: " + id
					)


static func _story(s: SceneTree) -> void:
	var story := StorySimulation.new(LegacyRoster.get_character("joao"))
	var target: FighterModel = story.enemies[0].fighter
	story.enemies = [story.enemies[0]]
	target.health = 1000
	target.character.speed_units = 0
	target.ground_y = story.hero.ground_y
	target.y = target.ground_y
	target.x = story.hero.x + 500 * UNIT
	story.enemies[0].cooldown = 2000
	story.hero._start_move(story.hero.character.get_move("special", 1))
	var hits := 0
	for tick in 400:
		story.step(CombatInput.new())
		for e in story.events:
			if e.kind == "hit" and e.get("effect", "") == "electricRoll":
				hits += 1
	s.check(hits == 3, "História usa deslocamento e os três contatos elétricos")
	s.check(story.hero.state == FighterState.Id.IDLE, "História recupera após rolinho")
