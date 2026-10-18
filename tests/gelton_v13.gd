class_name GeltonV13Tests
extends RefCounted
## Capoeira: no old poses, correct low proportions, real contacts and five Q waves.


static func run(s: SceneTree) -> void:
	var c := LegacyRoster.get_character("gelton")
	var f := FighterModel.new(c, 0, 640)
	var height: float = CharacterArt.frame(f).frame.rect[3] * CharacterArt.frame(f).frame.scale
	for tick in 192:
		f.state_tick = tick
		var frame: Dictionary = CharacterArt.frame(f).frame
		s.check(absf(frame.rect[3] * frame.scale - height) < 14, "Ginga mantém escala do Gelton")
		s.check(FighterPose.select(f).index == tick / 24, "Ginga tem oito exposições em 1,6 s")
	f.state = FighterState.Id.CROUCH
	var crouch: Dictionary = CharacterArt.frame(f).frame
	var low_height: float = crouch.rect[3] * crouch.scale
	s.check(low_height < height * .76, "Negativa dobra corpo sem ampliar cabeça")
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
		"Negativa e palmada baixa usam mesma guarda"
	)
	for tick in f.current_move().total_ticks():
		f.move_tick = tick
		var frame: Dictionary = CharacterArt.frame(f).frame
		s.check(
			absf(frame.rect[3] * frame.scale - low_height) < 18,
			"Palmada baixa mantém proporção durante toda a sequência"
		)
	for state in FighterState.Id.values():
		if state == FighterState.Id.ATTACK:
			continue
		f.state = state
		s.check("arcade-v13" in CharacterArt.frame(f).sheet.image, "Gelton sem fallback em estado")
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
				"arcade-v13" in art.sheet.image and art.frame.scale <= 1,
				"Sequência inteira nova, sem ampliar pixels: Gelton/" + name
			)
			if name not in ["special", "super"]:
				s.check(
					f.attack_boxes().is_empty() == (f.current_move().phase(tick) != "ACTIVE"),
					"Colisão apenas no active: Gelton/" + name
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
				sim.fighters[1].health < 1000, "Contato real nos dois lados: Gelton/" + entry[0]
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
				s.check(powers.projectiles.size() == wave + 1, "Q preserva cinco ondas, H uma")
				var p: Dictionary = powers.projectiles.back()
				s.check(
					p.x == socket.x and p.y == socket.y,
					"Tinta nasce na palma ou pé registrado em cada cel, nos dois lados"
				)
				s.check(p.effect == "artPaint", "Poder continua tinta, sem substituição por fumaça")
	s.check(c.legacy.powers.special == "Pincelada Cromática", "H preservado")
	s.check(c.legacy.powers.uppercut == "Aú das Cores", "U preservado")
	s.check(c.legacy.powers.super == "Roda das Artes", "Q preservado")
