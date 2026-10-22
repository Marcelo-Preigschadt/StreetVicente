class_name KhauanyV21Tests
extends RefCounted
## Rebuilt photo identity in all states, whole-body contacts, five fork waves and Story.


static func run(s: SceneTree) -> void:
	var c := LegacyRoster.get_character("khauany")
	var f := FighterModel.new(c, 0, 450)
	var standing := CharacterArt.frame(f)
	var height: float = standing.frame.rect[3] * standing.frame.scale
	s.check(absf(height - 300) < 4, "Khauãny mantém porte adulto de 300 px")
	f.state = FighterState.Id.CROUCH
	var low: Dictionary = CharacterArt.frame(f).frame
	var low_height: float = low.rect[3] * low.scale
	s.check(low_height < height * .76, "Khauãny agacha dobrando joelhos e tronco")
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
	# Regression: the sweep must keep the same head/body scale and a complete
	# authored low-contact cel, rather than shrinking or losing the guard arm.
	f.move_id = "sweep:1"
	for tick in f.current_move().total_ticks():
		f.move_tick = tick
		var sweep_frame: Dictionary = CharacterArt.frame(f).frame
		s.check(absf(sweep_frame.scale - low.scale) < .001,
			"Varrida mantém a escala anatômica do agachamento")
		if f.current_move().phase(tick) == "ACTIVE":
			s.check(sweep_frame.source == "low" and sweep_frame.source_cel == 6
				and sweep_frame.collision.has("hit"), "Varrida usa quadro completo e contato registrado")
	for state in FighterState.Id.values():
		if state == FighterState.Id.ATTACK:
			continue
		f.state = state
		s.check(CharacterArt.frame(f).frame.face_revision == 21,
			"Todo estado do Khauãny usa a identidade revisada")
	for name in ["punch", "kick", "crouchPunch", "sweep", "airPunch", "airKick",
		"special", "uppercut", "super", "throw", "guardCounter"]:
		for strength in 3:
			f.state = FighterState.Id.ATTACK
			f.move_id = "%s:%d" % [name, strength]
			for tick in f.current_move().total_ticks():
				f.move_tick = tick
				var art := CharacterArt.frame(f)
				s.check(art.frame.face_revision == 21 and "khauany/arcade-v21" in art.sheet.image,
					"Sem retorno ao conjunto anterior: Khauãny/" + name)
				s.check(art.frame.scale <= 1, "Desenhos do Khauãny conservam resolução nativa")
				if name not in ["special", "super"]:
					s.check(f.attack_boxes().is_empty() == (f.current_move().phase(tick) != "ACTIVE"),
						"Contato ocorre na fase ativa: Khauãny/" + name)
	for entry in [["punch", 170], ["kick", 180], ["crouchPunch", 150],
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
			s.check(sim.fighters[1].health < 1000, "Contato físico nos dois sentidos: Khauãny/" + entry[0])
			if entry[0] == "uppercut":
				s.check(airborne, "Contra-ataque Ascendente faz o Khauãny sair fisicamente do chão")
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
				"Pulso nasce no punho estendido registrado, nos dois sentidos")
			s.check(abs(socket.x - f.x) > 60 * FighterModel.SCALE,
				"Emissão acompanha a extensão real do palma")
			s.check(p.radius == (150 if name == "super" else 64),
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
				s.check(sim.fighters[0].emitted_waves == 5 and sim.fighters[0].meter == 0,
					"Kata preserva cinco ondas e custo integral")
	var campaign := StorySimulation.new(c)
	var lane := campaign.hero.ground_y
	for tick in 12:
		campaign.step(CombatInput.new(CombatInput.UP))
	s.check(campaign.hero.ground_y < lane and CharacterArt.frame(campaign.hero).key == "walk",
		"Khauãny anima o corpo inteiro ao andar em profundidade")
	s.check(c.legacy.style == "MMA · Contra-ataque", "Estilo do Khauãny preservado")
	s.check(c.legacy.powers.super == "Banquete de Garfos", "Nome do super preservado")
	s.check(c.legacy.portrait == "res://assets/characters/khauany/portrait-v21.webp",
		"Retrato refeito a partir da nova fotografia")
	s.check(c.legacy.voices.super == "res://assets/legacy/audio/khauany-super-br-v1.wav",
		"Voz original individual preservada")
	KhauanyFXV21.load_data()
	s.check(KhauanyFXV21.art.frames.size() == 24, "Vinte e quatro desenhos de efeitos próprios")
