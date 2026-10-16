class_name ArcadeV8Tests
extends RefCounted


static func run(s: SceneTree) -> void:
	_art(s)
	_air_chain(s)
	_rounds(s)
	_pause(s)


static func _art(s: SceneTree) -> void:
	ArcadeArt.load_data()
	for manifest in ArcadeArt.data.values():
		for sheet in manifest.sheets.values():
			var texture := LegacyRoster.texture(sheet.image)
			s.check(
				texture.get_size() == Vector2(sheet.size[0], sheet.size[1]),
				"Atlas importado corresponde ao empacotamento registrado"
			)
	for id in ["rafael", "adriano"]:
		var f := FighterModel.new(LegacyRoster.get_character(id), 0, 400)
		for state in [
			FighterState.Id.IDLE,
			FighterState.Id.WALK,
			FighterState.Id.JUMP,
			FighterState.Id.CROUCH,
			FighterState.Id.BLOCK,
			FighterState.Id.HITSTUN,
			FighterState.Id.KNOCKDOWN
		]:
			f.state = state
			s.check(ArcadeArt.has_frame(f), "Novo corpo completo por estado: " + id)
		f.state = FighterState.Id.IDLE
		var art := CharacterArt.frame(f)
		var h := float(art.frame.rect[3]) * float(art.frame.scale) * CharacterMetrics.factor(id)
		s.check(absf(h - 300) < 1, "Altura registrada de 300px: " + id)
		for name in ["punch", "kick", "crouchPunch", "sweep", "airPunch", "airKick", "uppercut"]:
			f.state = FighterState.Id.ATTACK
			f.move_id = name + ":1"
			var move := f.current_move()
			for tick in move.total_ticks():
				f.move_tick = tick
				var selected := CharacterArt.frame(f)
				s.check(not selected.frame.is_empty(), "Quadro válido: %s/%s" % [id, name])
				if move.phase(tick) == "ACTIVE":
					s.check(
						not f.attack_boxes().is_empty(),
						"Membro ativo registrado: %s/%s" % [id, name]
					)
				else:
					s.check(
						f.attack_boxes().is_empty(), "Sem dano fora de active: %s/%s" % [id, name]
					)


static func _air_chain(s: SceneTree) -> void:
	var c := LegacyRoster.get_character("marcelo")
	var r := LegacyRoster.get_character("rafael")
	var sim := FightSimulation.new(c, r)
	sim.fighters[0].x = 500 * 256
	sim.fighters[1].x = 665 * 256
	for f in sim.fighters:
		f.y -= 100 * 256
		f.transition(FighterState.Id.JUMP)
	sim.step([CombatInput.new(0, CombatInput.PUNCH), CombatInput.new()])
	for i in 40:
		if sim.fighters[0].has_contact:
			break
		s.neutral(sim)
	s.check(sim.fighters[0].has_contact, "Soco aéreo conecta com a geometria do novo desenho")
	while sim.freeze_ticks > 1:
		s.neutral(sim)
	var saved := sim.snapshot()
	sim.step([CombatInput.new(0, CombatInput.KICK), CombatInput.new()])
	s.neutral(sim, 2)
	s.check(sim.fighters[0].move_id == "airKick:1", "Contato confirma soco aéreo -> chute")
	s.neutral(sim, 55)
	var expected := sim.state_hash()
	s.check(
		sim.fighters[0].combo >= 2, "Segundo golpe conecta como combo real, sem intervalo acionável"
	)
	sim.restore(saved)
	sim.step([CombatInput.new(0, CombatInput.KICK), CombatInput.new()])
	s.neutral(sim, 57)
	s.check(sim.state_hash() == expected, "Replay preserva cancel aéreo e dano")
	var miss := FightSimulation.new(c, r)
	miss.fighters[0].y -= 180 * 256
	miss.fighters[0].transition(FighterState.Id.JUMP)
	miss.step([CombatInput.new(0, CombatInput.PUNCH), CombatInput.new()])
	s.neutral(miss, 3)
	miss.step([CombatInput.new(0, CombatInput.KICK), CombatInput.new()])
	s.neutral(miss, 3)
	s.check(miss.fighters[0].move_id == "airPunch:1", "Whiff não libera cancel aéreo")
	s.neutral(miss, 120)
	s.check(not miss.fighters[0].air_normal_used, "Aterrissagem libera ações do próximo salto")


static func _rounds(s: SceneTree) -> void:
	var c := LegacyRoster.get_character("marcelo")
	var sim := FightSimulation.new(c, LegacyRoster.get_character("rafael"))
	sim.begin_round_intro()
	var x := sim.fighters[0].x
	var cues: Array = []
	var saved: Dictionary
	for tick in FightSimulation.INTRO_TICKS:
		if tick == 60:
			saved = sim.snapshot()
		sim.step([CombatInput.new(CombatInput.RIGHT, CombatInput.PUNCH), CombatInput.new()])
		for event in sim.events:
			if event.kind == "announcer":
				cues.append(event.cue)
	s.check(cues == ["round", "1", "fight"], "Vozes Round/One/Fight emitidas uma vez e em ordem")
	s.check(
		sim.fighters[0].x == x and sim.remaining_ticks == 99 * 120,
		"Abertura bloqueia movimento e relógio"
	)
	var expected := sim.state_hash()
	sim.restore(saved)
	for tick in 132:
		sim.step([CombatInput.new(CombatInput.RIGHT, CombatInput.PUNCH), CombatInput.new()])
	s.check(sim.state_hash() == expected, "Snapshot mantém o relógio da chamada")
	s.neutral(sim)
	s.check(sim.fighters[0].move_id == "", "Botões da chamada não vazam para o combate")
	sim.winner = 0
	sim.round_wait = 239
	s.neutral(sim)
	s.check(
		sim.round_number == 2 and sim.intro_ticks == FightSimulation.INTRO_TICKS,
		"Round seguinte repete abertura e preserva sequência"
	)


static func _pause(s: SceneTree) -> void:
	var impact := CombatImpact.new()
	impact.particles = [{"life": 0.2}]
	impact.presentation_paused = true
	impact._process(0.5)
	s.check(
		impact.particles.size() == 1 and impact.particles[0].life == 0.2,
		"Pausa preserva a faísca em vez de apagá-la"
	)
	impact.presentation_paused = false
	impact._process(0.3)
	s.check(impact.particles.is_empty(), "Faísca retoma e termina após despausar")
	impact.free()
