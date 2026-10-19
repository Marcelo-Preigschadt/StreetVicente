class_name MarcosV16Tests
extends RefCounted
## Full new art coverage, crouch continuity and real grounded judo contacts.


static func run(s: SceneTree) -> void:
	var c := LegacyRoster.get_character("marcos")
	var f := FighterModel.new(c, 0, 450)
	var standing := CharacterArt.frame(f)
	var height: float = standing.frame.rect[3] * standing.frame.scale
	s.check(absf(height - 300) < 4, "Marcos mantém porte adulto de 300 px")
	f.state = FighterState.Id.CROUCH
	var crouch: Dictionary = CharacterArt.frame(f).frame
	var low_height: float = crouch.rect[3] * crouch.scale
	s.check(low_height < height * .76, "Marcos agacha dobrando o corpo, sem zoom")
	f.state = FighterState.Id.ATTACK
	f.move_id = "crouchPunch:1"
	for tick in f.current_move().total_ticks():
		f.move_tick = tick
		var art: Dictionary = CharacterArt.frame(f).frame
		s.check(absf(art.rect[3] * art.scale - low_height) < 18,
			"Pegada baixa conserva anatomia em toda a sequência")
		if tick == 0 or tick == f.current_move().total_ticks() - 1:
			s.check(art.source == crouch.source and art.source_cel == crouch.source_cel
				and art.scale == crouch.scale and art.anchor == crouch.anchor
				and art.bottom == crouch.bottom, "Agachar/iniciar/finalizar pegada usa o mesmo desenho")
	for state in FighterState.Id.values():
		if state == FighterState.Id.ATTACK:
			continue
		f.state = state
		var art := CharacterArt.frame(f)
		s.check(art.frame.get("face_revision", 0) == 16 and "marcos/arcade-v16" in art.sheet.image,
			"Todo estado do Marcos usa o conjunto facial revisado")
	for name in ["punch", "kick", "crouchPunch", "sweep", "airPunch", "airKick",
		"special", "uppercut", "super", "throw", "guardCounter"]:
		for strength in 3:
			f.state = FighterState.Id.ATTACK
			f.move_id = "%s:%d" % [name, strength]
			for tick in f.current_move().total_ticks():
				f.move_tick = tick
				var art := CharacterArt.frame(f)
				s.check("marcos/arcade-v16" in art.sheet.image and art.frame.face_revision == 16,
					"Sem fallback ou troca de rosto: Marcos/" + name)
				s.check(art.frame.scale <= 1, "Marcos conserva resolução nativa")
				s.check(f.attack_boxes().is_empty() == (f.current_move().phase(tick) != "ACTIVE"),
					"Contato somente na fase ativa: Marcos/" + name)
	for entry in [["punch", 170], ["crouchPunch", 150], ["kick", 165], ["sweep", 150],
		["throw", 130], ["special", 180], ["super", 190], ["uppercut", 180]]:
		for facing in [-1, 1]:
			var sim := FightSimulation.new(c, LegacyRoster.get_character("rafael"))
			f = sim.fighters[0]
			f.x = 640 * FighterModel.SCALE
			f.facing = facing
			sim.fighters[1].x = f.x + facing * int(entry[1]) * FighterModel.SCALE
			f._start_move(c.get_move(entry[0], 1))
			for tick in 150:
				sim.step([CombatInput.new(), CombatInput.new()])
				s.check(sim.projectiles.is_empty(), "Judô e poderes do Marcos não criam projéteis")
				if entry[0] == "uppercut":
					s.check(f.y == f.ground_y, "Pilha Reversa mantém Marcos apoiado no piso")
			s.check(sim.fighters[1].health < 1000, "Golpe real nos dois sentidos: Marcos/" + entry[0])
	for name in ["special", "super"]:
		var sim := FightSimulation.new(c, LegacyRoster.get_character("rafael"))
		f = sim.fighters[0]
		sim.fighters[1].x = f.x + 180 * FighterModel.SCALE
		f._start_move(c.get_move(name, 1))
		var connected := false
		for tick in 150:
			sim.step([CombatInput.new(), CombatInput.new(CombatInput.GUARD)])
			for event in sim.events:
				if event.kind == "hit" and event.character == "marcos":
					connected = true
		s.check(connected, "Projeção vence defesa alta sem virar projétil: " + name)
		sim = FightSimulation.new(c, LegacyRoster.get_character("rafael"))
		sim.fighters[1].x = sim.fighters[0].x + 180 * FighterModel.SCALE
		sim.fighters[1].y -= 350 * FighterModel.SCALE
		sim.fighters[0]._start_move(c.get_move(name, 1))
		for tick in 45:
			sim.step([CombatInput.new(), CombatInput.new()])
		s.check(sim.fighters[1].health == 1000, "Projeção não captura adversário fora do chão: " + name)
	var guard_sim := FightSimulation.new(c, LegacyRoster.get_character("rafael"))
	guard_sim.fighters[1].x = guard_sim.fighters[0].x + 180 * FighterModel.SCALE
	guard_sim.fighters[0]._start_move(c.get_move("uppercut", 1))
	var blocked := false
	for tick in 150:
		guard_sim.step([CombatInput.new(), CombatInput.new(CombatInput.GUARD)])
		for event in guard_sim.events:
			if event.kind == "block" and event.character == "marcos":
				blocked = true
	s.check(blocked, "Pilha Reversa continua bloqueável")
	f = FighterModel.new(c, 0, 450)
	f.state = FighterState.Id.WALK
	f.input = CombatInput.new(CombatInput.RIGHT)
	f.walk_distance = 54 * FighterModel.SCALE
	s.check(FighterPose.select(f).index == 4, "Tsugi-ashi usa o stride próprio de 108 px")
	var campaign := StorySimulation.new(c)
	var lane := campaign.hero.ground_y
	for tick in 12:
		campaign.step(CombatInput.new(CombatInput.UP))
	s.check(campaign.hero.ground_y < lane and campaign.hero.y == campaign.hero.ground_y,
		"Marcos anda na profundidade sem simular salto")
	s.check(campaign.hero.walk_distance > 0 and CharacterArt.frame(campaign.hero).key == "walk",
		"Deslocamento em profundidade também anima o corpo inteiro do Marcos")
	s.check(c.legacy.style == "Judô", "Modalidade preservada")
	s.check(c.legacy.powers.special == "Sequestro de Sessão", "H preservado")
	s.check(c.legacy.powers.uppercut == "Pilha Reversa", "U preservado")
	s.check(c.legacy.powers.super == "Kernel Panic", "Q preservado")
	s.check(c.legacy.portrait == "res://assets/legacy/runtime/marcos-head-menu-v3.webp",
		"Retrato original preservado")
	s.check(c.legacy.voices.super == "res://assets/legacy/audio/marcos-super-fluid-br-v1.wav",
		"Voz individual aprovada preservada")
	MarcosFXV16.load_data()
	s.check(MarcosFXV16.art.frames.size() == 16, "Dezesseis cels de efeitos digitais próprios")
