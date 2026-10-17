class_name GustavoV12Tests
extends RefCounted
## User regressions: crouch zoom, legacy fallback, palm release and power identity.


static func run(s: SceneTree) -> void:
	var c := LegacyRoster.get_character("gustavo")
	var f := FighterModel.new(c, 0, 450)
	var standing: Dictionary = CharacterArt.frame(f).frame
	var standing_height: float = standing.rect[3] * standing.scale
	f.state = FighterState.Id.CROUCH
	var crouch: Dictionary = CharacterArt.frame(f).frame
	var crouch_height: float = crouch.rect[3] * crouch.scale
	s.check(crouch_height < standing_height * .76, "Gustavo agacha sem ampliar o corpo")
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
	ArcadeArt.load_data()
	for sheet in ArcadeArt.data.gustavo.sheets.values():
		for frame in sheet.frames:
			s.check(frame.scale <= 1, "Gustavo usa resolução de origem sem ampliar pixels")
	for name in ["punch", "crouchPunch", "sweep"]:
		for facing in [-1, 1]:
			var sim := FightSimulation.new(c, LegacyRoster.get_character("rafael"))
			f = sim.fighters[0]
			f.x = 640 * 256
			sim.fighters[1].x = f.x + facing * 170 * 256
			f.facing = facing
			f._start_move(c.get_move(name, 1))
			for tick in 100:
				sim.step([CombatInput.new(), CombatInput.new()])
			s.check(sim.fighters[1].health < 1000, "Contato real espelhado: Gustavo/" + name)
	for name in ["special", "super"]:
		for facing in [-1, 1]:
			f = FighterModel.new(c, 0, 640)
			f.facing = facing
			f._start_move(c.get_move(name, 1))
			f.move_tick = f.current_move().startup * 2
			var socket := CombatGeometry.hand(f)
			var powers := PowerSystem.new()
			powers.emit(f, 1)
			s.check(powers.projectiles.size() == 1, "Fumaça sai no quadro ativo")
			s.check(
				powers.projectiles[0].x == socket.x and powers.projectiles[0].y == socket.y,
				"Névoa/Reação em Cadeia nasce na palma desenhada nos dois lados"
			)
	s.check(c.legacy.powers.special == "Névoa Atômica", "H mantém o poder do Gustavo")
	s.check(c.legacy.powers.uppercut == "Reação Exotérmica", "U mantém o gancho do Gustavo")
	s.check(c.legacy.powers.super == "Reação em Cadeia", "Q mantém o especial do Gustavo")
