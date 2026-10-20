class_name TaisV17Tests
extends RefCounted
## Identity provenance, anatomical scale, true boot release and enlarged contacts.


static func run(s: SceneTree) -> void:
	var c := LegacyRoster.get_character("tais")
	var f := FighterModel.new(c, 0, 450)
	var standing := CharacterArt.frame(f)
	var height: float = standing.frame.rect[3] * standing.frame.scale
	s.check(absf(height - 300) < 4, "Tais mantém porte adulto de 300 px")
	f.state = FighterState.Id.CROUCH
	var low: Dictionary = CharacterArt.frame(f).frame
	var low_height: float = low.rect[3] * low.scale
	s.check(low_height < height * .76, "Tais agacha dobrando joelhos e tronco")
	f.state = FighterState.Id.ATTACK
	f.move_id = "crouchPunch:1"
	for tick in f.current_move().total_ticks():
		f.move_tick = tick
		var frame: Dictionary = CharacterArt.frame(f).frame
		s.check(absf(frame.rect[3] * frame.scale - low_height) < 18,
			"Direto baixo mantém o mesmo corpo ao longo do golpe")
		if tick == 0 or tick == f.current_move().total_ticks() - 1:
			s.check(frame.source == low.source and frame.source_cel == low.source_cel
				and frame.scale == low.scale, "Agachar e iniciar/finalizar soco compartilha desenho")
	for state in FighterState.Id.values():
		if state == FighterState.Id.ATTACK:
			continue
		f.state = state
		s.check(CharacterArt.frame(f).frame.face_revision == 17,
			"Todo estado da Tais usa a identidade revisada")
	for name in ["punch", "kick", "crouchPunch", "sweep", "airPunch", "airKick",
		"special", "uppercut", "super", "throw", "guardCounter"]:
		for strength in 3:
			f.state = FighterState.Id.ATTACK
			f.move_id = "%s:%d" % [name, strength]
			for tick in f.current_move().total_ticks():
				f.move_tick = tick
				var art := CharacterArt.frame(f)
				s.check(art.frame.face_revision == 17 and "tais/arcade-v17" in art.sheet.image,
					"Sem retorno ao conjunto anterior: Tais/" + name)
				s.check(art.frame.scale <= 1, "Desenhos da Tais conservam resolução nativa")
				if name not in ["special", "super"]:
					s.check(f.attack_boxes().is_empty() == (f.current_move().phase(tick) != "ACTIVE"),
						"Contato ocorre na fase ativa: Tais/" + name)
	for entry in [["punch", 170], ["kick", 190], ["crouchPunch", 150],
		["sweep", 180], ["throw", 130], ["uppercut", 185]]:
		for facing in [-1, 1]:
			var sim := FightSimulation.new(c, LegacyRoster.get_character("rafael"))
			f = sim.fighters[0]
			f.x = 640 * FighterModel.SCALE
			f.facing = facing
			sim.fighters[1].x = f.x + facing * int(entry[1]) * FighterModel.SCALE
			f._start_move(c.get_move(entry[0], 1))
			var airborne := false
			for tick in 170:
				sim.step([CombatInput.new(), CombatInput.new()])
				airborne = airborne or f.y < f.ground_y
			s.check(sim.fighters[1].health < 1000, "Contato físico nos dois sentidos: Tais/" + entry[0])
			if entry[0] == "uppercut":
				s.check(airborne, "Salto Olímpico faz a Tais sair fisicamente do chão")
	for name in ["special", "super"]:
		for facing in [-1, 1]:
			f = FighterModel.new(c, 0, 640)
			f.meter = 100
			f.facing = facing
			f._start_move(c.get_move(name, 1))
			f.move_tick = f.current_move().startup * 2
			var socket := CombatGeometry.hand(f)
			var system := PowerSystem.new()
			system.emit(f, 0)
			var p: Dictionary = system.projectiles[0]
			s.check(p.spawn_x == socket.x and p.spawn_y == socket.y,
				"Pulso nasce no tênis estendido registrado, nos dois sentidos")
			s.check(abs(socket.x - f.x) > 140 * FighterModel.SCALE,
				"Emissão acompanha a extensão real do chassé")
			s.check(p.radius == (146 if name == "super" else 58),
				"Núcleo visível tem raio físico ampliado, não só decoração")
			var sim := FightSimulation.new(c, LegacyRoster.get_character("rafael"))
			sim.fighters[0].meter = 100
			sim.fighters[0]._start_move(c.get_move(name, 1))
			sim.fighters[1].x = sim.fighters[0].x + 440 * FighterModel.SCALE
			var blocked := false
			for tick in 180:
				sim.step([CombatInput.new(), CombatInput.new(CombatInput.GUARD)])
				for event in sim.events:
					blocked = blocked or event.kind == "block"
			s.check(blocked, "Pulso ampliado continua bloqueável: " + name)
			if name == "super":
				s.check(sim.fighters[0].emitted_waves == 4 and sim.fighters[0].meter == 0,
					"Circuito preserva quatro ondas e custo integral")
	var campaign := StorySimulation.new(c)
	var lane := campaign.hero.ground_y
	for tick in 12:
		campaign.step(CombatInput.new(CombatInput.UP))
	s.check(campaign.hero.ground_y < lane and CharacterArt.frame(campaign.hero).key == "walk",
		"Tais anima o corpo inteiro ao andar em profundidade")
	s.check(c.legacy.style == "Savate", "Estilo da Tais preservado")
	s.check(c.legacy.powers.super == "Circuito Campeão", "Nome do super preservado")
	s.check(c.legacy.portrait == "res://assets/legacy/runtime/tais-head-menu-v4.webp",
		"Retrato aprovado preservado")
	s.check(c.legacy.voices.super == "res://assets/legacy/audio/tais-super-br-v3.wav",
		"Voz original individual preservada")
	TaisFXV17.load_data()
	s.check(TaisFXV17.art.frames.size() == 24, "Vinte e quatro desenhos de efeitos próprios")
