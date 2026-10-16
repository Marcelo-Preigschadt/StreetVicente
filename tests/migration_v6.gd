class_name MigrationV6Tests
extends RefCounted
const UNIT := FighterModel.SCALE


static func run(suite: SceneTree) -> void:
	_recovery(suite)
	_art_scale(suite)
	_arcade(suite)
	_story(suite)
	_alpha(suite)


static func _ticks(f: FighterModel, count: int, held: int = 0, mash: bool = false) -> void:
	for tick in count:
		f.record_input(
			CombatInput.new(held, CombatInput.PUNCH if mash and tick % 12 == 0 else 0), tick
		)
		f.begin_tick(1200 * UNIT)
		f.end_tick()


static func _recovery(s: SceneTree) -> void:
	var c := LegacyRoster.get_character("rafael")
	var f := FighterModel.new(c, 1, 700)
	var attacker := FighterModel.new(LegacyRoster.get_character("marcelo"), 0, 400)
	var move := attacker.character.get_move("punch", 1)
	for hit in 7:
		var name := attacker.connect_hit(f, move)
		f.receive_hit(move, 1, false, 0, attacker.combo)
		s.check(attacker.combo == 1 and name.is_empty(), "Golpe isolado não vira combo nem tontura")
		_ticks(f, 160)
		s.check(
			FighterState.actionable(f.state) and f.dizzy_pending == 0,
			"Recuperação finita após hitstun isolado"
		)
	_ticks(f, 600)
	s.check(f.stun_gauge == 0, "Tontura decai sem novos golpes")
	f.health = 1000
	for hit in 3:
		attacker.connect_hit(f, move)
		f.receive_hit(move, 1, false, 0, attacker.combo)
		_ticks(f, 2)
	s.check(
		attacker.combo == 3 and f.dizzy_pending > 0, "Tontura exige combo verdadeiro de três hits"
	)
	_ticks(f, move.hitstun * 2 + 4)
	s.check(
		f.state == FighterState.Id.DIZZY and f.dizzy_pending == 0,
		"Entrada consome tontura pendente uma vez"
	)
	var saved := f.snapshot()
	var remaining := f.dizzy_ticks
	_ticks(f, 100, 0, true)
	s.check(f.dizzy_ticks < remaining - 100, "Comandos aceleram recuperação da tontura")
	var recovered := f.snapshot()
	f.restore(saved)
	_ticks(f, 100, 0, true)
	s.check(
		var_to_bytes(recovered) == var_to_bytes(f.snapshot()),
		"Replay inclui mash, proteção e contadores de reação"
	)
	f.receive_hit(move, 1, false, 0, 3)
	s.check(
		f.dizzy_ticks == 0 and f.dizzy_pending == 0 and f.dizzy_protection > 0,
		"Golpe encerra tontura e concede proteção"
	)
	_ticks(f, 100, CombatInput.RIGHT)
	s.check(
		f.state == FighterState.Id.WALK and f.x > int(recovered.x), "Movimento volta após a reação"
	)
	for phase in 4:
		f.state = FighterState.Id.HITSTUN
		f.hit_duration = 48
		f.stun_ticks = 48 - phase * 12
		f.hit_region = "body"
		s.check(
			c.pose_frame(f).pose == ["reaction", 8 + phase],
			"Reação expõe quatro quadros pelo hitstun real"
		)
	var kd := FighterModel.new(c, 0, 400)
	kd.transition(FighterState.Id.KNOCKDOWN)
	_ticks(kd, 50, 0, true)
	s.check(
		kd.state != FighterState.Id.KNOCKDOWN and kd.state != FighterState.Id.WAKEUP,
		"Quick rise recupera dentro de 50 ticks"
	)


static func _art_scale(s: SceneTree) -> void:
	var c := LegacyRoster.get_character("adriano")
	var f := FighterModel.new(c, 0, 400)
	var art := CharacterArt.frame(f)
	var height := (
		float(art.frame.rect[3])
		* float(art.frame.get("scale", art.sheet.scale))
		* CharacterMetrics.factor(c.id)
	)
	s.check(absf(height - 300) < 1, "Adriano: altura em pé normalizada a 300px")
	for atlas in c.legacy.atlases:
		for frame in c.legacy.atlases[atlas].frames:
			s.check(
				(
					(
						float(frame.get("scale", c.legacy.atlases[atlas].scale))
						* CharacterMetrics.factor(c.id)
					)
					> 0
				),
				"Todos os atlas do Adriano usam o mesmo fator uniforme"
			)
	var box := Rect2i(-33, -264, 66, 264)
	var normalized := CharacterMetrics.rect(c.id, box)
	s.check(
		normalized.size.y == 300 and normalized.end.y == 0,
		"Colisão cresce com a arte e mantém origem nos pés"
	)
	var a := BoxMath.world_rect(normalized, 0, 0, 1)
	var b := BoxMath.world_rect(normalized, 0, 0, -1)
	s.check(a.size == b.size and a.position.x == -b.end.x, "Adriano espelhado mantém colisões")


static func _arcade(s: SceneTree) -> void:
	var run := ArcadeRun.new(LegacyRoster.ids(), "marcelo", "rafael", 700)
	s.check(
		(
			run.opponents.size() == 12
			and run.opponents[0] == "rafael"
			and "marcelo" not in run.opponents
		),
		"Circuito contém os 12 rivais, começando pela escolha"
	)
	var hit := {
		"id": "hit",
		"kind": "hit",
		"attacker": 0,
		"slot": 1,
		"damage": 100,
		"combo": 3,
		"combo_name": "Linha Central",
		"move": "super:1"
	}
	var end := {
		"id": "round",
		"kind": "round_end",
		"round": 1,
		"winner": 0,
		"life": 1000,
		"seconds": 99,
		"ko": true
	}
	run.consume([hit, end, hit, end])
	s.check(
		run.score == 19550,
		"Fórmula original: dano, combo, estilo, round, vida, tempo, Perfect e Super KO"
	)
	run.consume([{"id": "cpu", "kind": "hit", "attacker": 1, "slot": 0, "damage": 1000}])
	s.check(run.score == 19550, "Acerto da CPU não pontua para P1")
	run.consume(
		[
			{
				"id": "draw",
				"kind": "round_end",
				"round": 2,
				"winner": 2,
				"life": 1000,
				"seconds": 50,
				"ko": false
			}
		]
	)
	s.check(run.score == 19550, "Empate não dá bônus")
	run.consume(
		[{"id": "win", "kind": "result", "winner": 0}, {"id": "win", "kind": "result", "winner": 0}]
	)
	s.check(
		run.score == 22550 and run.wins == 1 and run.state == "route",
		"Confronto concede bônus uma vez e abre rota"
	)
	run.advance()
	s.check(
		run.index == 1 and run.score == 22550 and run.breakdown.combat == 0,
		"Próxima luta mantém total e limpa bônus da luta anterior"
	)
	run.consume([{"id": "loss", "kind": "result", "winner": 1}])
	run.continue_run()
	s.check(
		run.score == 0 and run.record == 22550 and run.index == 1 and run.continues == 1,
		"Continue: mesmo rival, zero pontos, recorde preservado"
	)
	for i in range(1, 12):
		run.consume([{"id": "result", "kind": "result", "winner": 0}])
		if i < 11:
			run.advance()
	s.check(
		run.state == "complete" and run.wins == 12 and run.score == 53000,
		"Circuito completo dá 20000 e termina após os 12 rivais"
	)
	var sim := FightSimulation.new(
		LegacyRoster.get_character("marcelo"), LegacyRoster.get_character("rafael")
	)
	sim.wins[0] = 1
	sim.fighters[1].health = 0
	sim.remaining_ticks = 121
	sim.step([CombatInput.new(), CombatInput.new()])
	s.check(
		(
			sim.events.filter(func(e: Dictionary) -> bool: return e.kind == "round_end").size() == 1
			and sim.events[-1].kind == "result"
		),
		"Simulação publica resultado e fim de round autoritativos"
	)
	s.check(sim.events[-2].seconds == 1, "Tempo restante usa teto após o tick final")
	var patterns: Array = LegacyRoster.get_character("marcelo").legacy.combos
	var player := FighterModel.new(LegacyRoster.get_character("marcelo"), 0, 400)
	var target := FighterModel.new(LegacyRoster.get_character("rafael"), 1, 600)
	var completed := ""
	for step in patterns[0].steps:
		var move := player.character.move_for(step)
		completed = player.connect_hit(target, move)
		target.receive_hit(move, 1, false, 0, player.combo)
	s.check(
		completed == patterns[0].name, "Combo de estilo reconhecido pela sequência real de acertos"
	)


static func _story(s: SceneTree) -> void:
	var world := StorySimulation.new(LegacyRoster.get_character("marcelo"))
	world.wave_index = 2
	world.hero.x = 2100 * UNIT
	world.hero.ground_y = 595 * UNIT
	world.hero.y = world.hero.ground_y
	world.step(CombatInput.new(0, CombatInput.PUNCH))
	s.check(world.objects.carry.get("kind", "") == "table", "Soco próximo pega mesa do cenário")
	for tick in 26:
		world.step(CombatInput.new())
	world.step(CombatInput.new(0, CombatInput.PUNCH))
	for tick in 60:
		world.step(CombatInput.new())
		if not world.objects.thrown.is_empty():
			break
	s.check(
		world.objects.carry.is_empty() and not world.objects.thrown.is_empty(),
		"Arremesso libera mesa na fase ativa do movimento"
	)
	var snap := world.snapshot()
	var copy := StorySimulation.new(world.hero.character)
	copy.restore(JSON.parse_string(JSON.stringify(snap)))
	s.check(
		copy.state_hash() == SnapshotCodec.state_hash(snap),
		"JSON restaura objetos, projéteis, inimigos e inteiros sem divergência"
	)
	for tick in 75:
		world.step(CombatInput.new())
		copy.step(CombatInput.new())
	s.check(
		world.state_hash() == copy.state_hash(), "Save/load continua a mesma campanha por 75 ticks"
	)
	var progress := PlayerProgress.new("user://test-progress-v6.json")
	progress.record = 123456
	progress.capture_story(world)
	var loaded := PlayerProgress.new("user://test-progress-v6.json")
	loaded.load_saved()
	s.check(
		loaded.record == 123456 and loaded.valid_checkpoint(),
		"Recorde e checkpoint sobrevivem à reabertura"
	)
	loaded.checkpoint.world = {}
	s.check(not loaded.valid_checkpoint(), "Checkpoint truncado é rejeitado antes de restore")
	DirAccess.remove_absolute("user://test-progress-v6.json")
	var lab := StorySimulation.new(world.hero.character, 1)
	var hazard: Dictionary = lab.objects.hazards[0]
	lab.hero.x = int(hazard.x)
	lab.hero.ground_y = int(hazard.lane)
	lab.hero.y = lab.hero.ground_y
	hazard.clock = int(hazard.warning) - 2
	lab.objects._step_hazards()
	s.check(lab.hero.health == 1000, "Aviso do perigo não causa dano")
	lab.objects._step_hazards()
	s.check(lab.hero.health == 955, "Ácido ativo causa 45 pontos, como no original")
	lab.objects._step_hazards()
	s.check(lab.hero.health == 955, "Perigo tem intervalo de 1,1s entre acertos")
	var run := StorySimulation.new(world.hero.character)
	var phases := 0
	while not run.completed and phases < 25:
		for enemy in run.enemies:
			enemy.fighter.health = 0
		run.hero.x = mini(3560, 880 + run.wave_index * 820) * UNIT
		run.step(CombatInput.new())
		phases += 1
	s.check(
		run.completed and phases == 17, "Quatro atos, 12 ondas, quatro chefes e exoesqueleto final"
	)
	s.check(
		run.score == 9400,
		"História pontua por inimigo/chefe derrotado, sem pontos falsos por dano/objetos"
	)
	var retry := StorySimulation.new(world.hero.character, 2)
	retry.remaining_ticks = 400
	retry.hero.health = 0
	retry.defeated = true
	retry.retry_act()
	s.check(
		(
			retry.act_index == 2
			and retry.wave_index == 0
			and retry.hero.health == 1000
			and retry.remaining_ticks == retry.act_start_ticks
		),
		"Retry reinicia o ato atual com o tempo do checkpoint"
	)


static func _alpha(s: SceneTree) -> void:
	for id in LegacyRoster.ids():
		var f := FighterModel.new(LegacyRoster.get_character(id), 0, 400)
		f.meter = 100
		f.record_input(CombatInput.new(0, CombatInput.CUSTOM), 0)
		f.begin_tick(900 * UNIT)
		s.check(f.custom_ticks == 300 and f.meter == 50, "Custom: 50 de barra e 2,5s — " + id)
		f.receive_hit(f.character.get_move("punch"), -1, true)
		f.record_input(CombatInput.new(0, CombatInput.COUNTER), 1)
		f.begin_tick(900 * UNIT)
		s.check(
			f.move_id == "guardCounter:1" and f.meter == 25,
			"Contra-ataque sai do blockstun, custa 25 — " + id
		)
		f = FighterModel.new(f.character, 0, 400)
		var origin := 0
		for i in 3:
			if i == 2:
				origin = f.x
			f.record_input(
				CombatInput.new(
					CombatInput.RIGHT if i != 1 else 0, CombatInput.RIGHT if i != 1 else 0
				),
				i
			)
			f.begin_tick(900 * UNIT)
			f.end_tick()
		s.check(
			f.state == FighterState.Id.STEP_IN and f.invincible_ticks == 0,
			"Duplo toque avança sem invencibilidade — " + id
		)
		_ticks(f, f.step_duration + 1)
		s.check(
			f.x - origin == f.step_distance and f.state == FighterState.Id.IDLE,
			"Passo respeita distância e duração do estilo — " + id
		)
		var pose := CharacterArt.frame(f)
		s.check(not pose.is_empty(), "Pose de footwork válida — " + id)
