extends RefCounted
## Targeted gameplay regressions; invoked by the existing native suite.


static func run(suite: SceneTree) -> void:
	MarceloPowerFX.load_art()
	suite.check(
		MarceloPowerFX.art.frames.size() == 12, "Atlas preservado para a carga aprovada dos drones"
	)
	suite.check(
		ResourceLoader.exists(MarceloPowerFX.art.image),
		"Atlas de carga dos drones incluído no pacote"
	)
	var marcelo := LegacyRoster.get_character("marcelo")
	var rafael := LegacyRoster.get_character("rafael")
	for facing in [1, -1]:
		var f := FighterModel.new(rafael, 1, 700)
		f.facing = facing
		var empty := BoxMath.world_rect(Rect2i(-58, -280, 8, 8), f.x, f.y, facing)
		var torso := BoxMath.world_rect(Rect2i(-20, -190, 8, 8), f.x, f.y, facing)
		var ghost := false
		var body := false
		for hurt in f.hurtboxes():
			ghost = ghost or BoxMath.overlap(empty, hurt)
			body = body or BoxMath.overlap(torso, hurt)
		suite.check(not ghost, "Rafael: canto vazio ao lado da cabeça não é alvo")
		suite.check(body, "Rafael: tronco desenhado continua vulnerável")
		var sim := FightSimulation.new(marcelo, rafael)
		sim.fighters[0].x = (500 if facing == 1 else 780) * 256
		sim.fighters[1].x = (680 if facing == 1 else 600) * 256
		sim.step([CombatInput.new(0, CombatInput.PUNCH), CombatInput.new()])
		var hit := false
		for tick in 80:
			var boxes := sim.fighters[1].hurtboxes()
			var old_x := sim.fighters[1].x
			suite.neutral(sim)
			for event in sim.events:
				if event.kind != "hit":
					continue
				hit = true
				var point := Vector2i(int(event.x), int(event.y))
				var on_body := false
				for rect in boxes:
					on_body = on_body or rect.has_point(point)
				suite.check(on_body, "Faísca nasce no corpo atingido antes do recuo")
				suite.check(sim.fighters[1].x == old_x, "Contato não teleporta o Rafael no hitstop")
				var saved := sim.snapshot()
				suite.neutral(sim, 35)
				var expected := sim.state_hash()
				sim.restore(saved)
				suite.neutral(sim, 35)
				suite.check(sim.state_hash() == expected, "Rollback preserva dívida de recuo")
				suite.check(
					(sim.fighters[1].x - old_x) * facing > 0, "Recuo progride depois do hitstop"
				)
		suite.check(hit, "Soco do Marcelo conecta no Rafael nos dois lados")
		var miss := FightSimulation.new(marcelo, rafael)
		miss.fighters[0].x = 400 * 256
		miss.fighters[1].x = 700 * 256
		miss.step([CombatInput.new(0, CombatInput.PUNCH), CombatInput.new()])
		suite.neutral(miss, 80)
		suite.check(miss.fighters[1].health == 1000, "Soco fora do alcance visual não causa dano")
	var touch := BoxMath.sweep(Vector2i(0, 0), Vector2i(200, 0), Rect2i(50, -5, 2, 10), 0)
	suite.check(not touch.is_empty(), "CCD detecta alvo fino atravessado entre ticks")
	suite.check(
		BoxMath.sweep(Vector2i(0, 0), Vector2i(100, 100), Rect2i(40, 0, 10, 10), 0).is_empty(),
		"CCD diagonal não acerta canto vazio do bounding box"
	)
	for distance in [106, 130, 180, 280]:
		var sim := FightSimulation.new(marcelo, rafael)
		sim.fighters[0].x = 400 * 256
		sim.fighters[1].x = (400 + distance) * 256
		sim.step([CombatInput.new(0, CombatInput.SPECIAL), CombatInput.new()])
		suite.neutral(sim, 120)
		suite.check(
			sim.fighters[1].health < 1000,
			"Código conecta também a curta distância: " + str(distance)
		)
	var source := FighterModel.new(marcelo, 0, 100)
	source.state = FighterState.Id.ATTACK
	source.move_id = "special:1"
	source.move_tick = source.current_move().startup * 2
	var system := PowerSystem.new()
	system.emit(source, 0)
	system.projectiles[0].vx = 600 * 256
	var near := FighterModel.new(rafael, 2, 350)
	var far := FighterModel.new(rafael, 1, 550)
	near.facing = -1
	far.facing = -1
	var actors: Array[FighterModel] = [source, far, near]
	var contacts := system.advance(actors, 1280, 1)
	suite.check(
		contacts.size() == 1 and contacts[0].defender == 2,
		"CCD escolhe primeiro corpo no trajeto, não a ordem do array"
	)
