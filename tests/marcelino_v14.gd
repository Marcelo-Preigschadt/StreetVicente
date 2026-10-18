class_name MarcelinoV14Tests
extends RefCounted
## User regressions: crouch zoom, legacy fallback, palm release and power identity.


static func run(s: SceneTree) -> void:
	var c := LegacyRoster.get_character("marcelino")
	var f := FighterModel.new(c, 0, 450)
	var standing: Dictionary = CharacterArt.frame(f).frame
	var standing_height: float = standing.rect[3] * standing.scale
	f.state = FighterState.Id.CROUCH
	var crouch: Dictionary = CharacterArt.frame(f).frame
	var crouch_height: float = crouch.rect[3] * crouch.scale
	s.check(crouch_height < standing_height * .76, "Marcelino agacha sem ampliar o corpo")
	f.state = FighterState.Id.ATTACK
	f.move_id = "crouchPunch:1"
	f.move_tick = 0
	var first: Dictionary = CharacterArt.frame(f).frame
	s.check(
		(
			first.source == crouch.source
			and first.source_cel == crouch.source_cel
			and first.scale == crouch.scale
			and first.anchor == crouch.anchor
			and first.bottom == crouch.bottom
		),
		"Agachar e iniciar soco baixo compartilham desenho, tamanho e raiz"
	)
	for tick in f.current_move().total_ticks():
		f.move_tick = tick
		var frame: Dictionary = CharacterArt.frame(f).frame
		s.check(
			absf(frame.rect[3] * frame.scale - crouch_height) < 10,
			"Soco agachado mantém proporção em preparação, contato e recuperação"
		)
	for state in FighterState.Id.values():
		if state == FighterState.Id.ATTACK:
			continue
		f.state = state
		s.check(
			"arcade-v14" in CharacterArt.frame(f).sheet.image, "Marcelino sem fallback em estado"
		)
	for name in [
		"punch",
		"kick",
		"crouchPunch",
		"sweep",
		"airPunch",
		"airKick",
		"special",
		"uppercut",
		"super"
	]:
		f.state = FighterState.Id.ATTACK
		f.move_id = name + ":1"
		for tick in f.current_move().total_ticks():
			f.move_tick = tick
			var art := CharacterArt.frame(f)
			s.check(
				"arcade-v14" in art.sheet.image and art.frame.scale <= 1,
				"Sequência inteira nova, sem ampliar pixels: Marcelino/" + name
			)
			if name not in ["special", "super"]:
				s.check(
					f.attack_boxes().is_empty() == (f.current_move().phase(tick) != "ACTIVE"),
					"Colisão apenas no active: Marcelino/" + name
				)
	for entry in [["punch", 170], ["crouchPunch", 170], ["kick", 220], ["sweep", 220]]:
		for facing in [-1, 1]:
			var sim := FightSimulation.new(c, LegacyRoster.get_character("rafael"))
			f = sim.fighters[0]
			f.x = 640 * 256
			f.facing = facing
			sim.fighters[1].x = f.x + facing * int(entry[1]) * 256
			f._start_move(c.get_move(entry[0], 1))
			for tick in 110:
				sim.step([CombatInput.new(), CombatInput.new()])
			s.check(
				sim.fighters[1].health < 1000, "Contato real nos dois lados: Marcelino/" + entry[0]
			)
	for name in ["special", "super"]:
		for facing in [-1, 1]:
			f = FighterModel.new(c, 0, 640)
			f.facing = facing
			f._start_move(c.get_move(name, 1))
			var powers := PowerSystem.new()
			var count := 5 if name == "super" else 1
			for wave in count:
				f.move_tick = f.current_move().startup * 2 + wave * 10
				var socket := CombatGeometry.hand(f)
				powers.emit(f, wave + 1)
				s.check(powers.projectiles.size() == wave + 1, "Q preserva cinco impulsos, H um")
				var p: Dictionary = powers.projectiles.back()
				s.check(
					p.x == socket.x and p.y == socket.y,
					"Impulso nasce nas mãos registrado em cada cel, nos dois lados"
				)
				s.check(p.effect == "physicsImpulse", "Poder mantém efeito physicsImpulse")

	for name in ["special", "super"]:
		for guard in [false, true]:
			var sim := FightSimulation.new(c, LegacyRoster.get_character("rafael"))
			f = sim.fighters[0]
			f._start_move(c.get_move(name, 1))
			sim.fighters[1].x = f.x + 380 * 256
			var contacts := 0
			for tick in 240:
				sim.step([CombatInput.new(), CombatInput.new(CombatInput.GUARD if guard else 0)])
				for e in sim.events:
					if e.kind == ("block" if guard else "hit") and e.character == "marcelino":
						contacts += 1
			s.check(contacts > 0, "Impulso tem contato real e defesa: " + name)
			s.check(sim.fighters[1].health < 1000, "Acerto/defesa aplica dano ou chip")
	s.check(c.legacy.powers.special == "Impulso Linear", "H preservado")
	s.check(c.legacy.powers.uppercut == "Joelhada Cinética", "U preservado")
	s.check(c.legacy.powers.super == "Lei da Ação e Reação", "Q preservado")
