extends SceneTree
## Regressões de regras, limites de frames e serialização; exit code != 0 em falha.
const DATA: CharacterData = preload("res://data/characters/prototype.tres")
var failures: int = 0
var checks: int = 0


func _initialize() -> void:
	call_deferred("_run")


func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + label)


func neutral(sim: FightSimulation, count: int = 1) -> void:
	for _i in count:
		sim.step([CombatInput.new(), CombatInput.new()])


func close_sim() -> FightSimulation:
	var sim := FightSimulation.new(DATA, DATA)
	sim.fighters[0].x = 500 * FighterModel.SCALE
	sim.fighters[1].x = 610 * FighterModel.SCALE
	return sim


func _run() -> void:
	for move in [DATA.jab, DATA.kick, DATA.sweep, DATA.air_kick]:
		check(move.validate(), "Recurso válido: " + move.id)
	_test_input()
	_test_movement()
	_test_frames()
	_test_contacts()
	_test_buffer()
	_test_replay()
	_test_roster()
	_test_pilot_art()
	_test_powers_rounds()
	_test_story()
	_test_air_kick_v2()
	_test_shared_powers()
	_test_contact_geometry_v3()
	_test_marcelo_uppercut_v4()
	_test_roster_art_v5()
	MigrationV6Tests.run(self)
	Pilot3DTests.run(self)
	print("COMBAT TESTS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _test_input() -> void:
	check(CombatInput.new(CombatInput.LEFT | CombatInput.RIGHT).axis_x() == 0, "SOCD neutro")
	var buffer := CommandBuffer.new()
	buffer.record(CombatInput.new(0, CombatInput.PUNCH), 0)
	buffer.record(CombatInput.new(), 11)
	check(buffer.consume(CombatInput.PUNCH), "Buffer inclui tick 11")
	check(not buffer.consume(CombatInput.PUNCH), "Comando só pode ser consumido uma vez")
	buffer.record(CombatInput.new(0, CombatInput.PUNCH), 20)
	buffer.record(CombatInput.new(), 32)
	check(not buffer.consume(CombatInput.PUNCH), "Buffer expira exatamente em 12 ticks")


func _test_movement() -> void:
	var sim := FightSimulation.new(DATA, DATA)
	var start := sim.fighters[0].x
	sim.step([CombatInput.new(CombatInput.RIGHT), CombatInput.new()])
	check(sim.fighters[0].x == start + 3 * FighterModel.SCALE, "Velocidade de 360 px/s")
	sim.step([CombatInput.new(CombatInput.DOWN), CombatInput.new()])
	check(sim.fighters[0].state == FighterState.Id.CROUCH, "Estado agachar")
	sim.step(
		[CombatInput.new(CombatInput.RIGHT | CombatInput.UP, CombatInput.UP), CombatInput.new()]
	)
	check(sim.fighters[0].y < FighterModel.FLOOR_Y, "Salto inicia no mesmo tick")
	var jump_x := sim.fighters[0].x
	for _i in 8:
		sim.step([CombatInput.new(), CombatInput.new()])
	check(sim.fighters[0].x == jump_x + 24 * FighterModel.SCALE, "Drift aéreo constante")
	neutral(sim, 90)
	check(
		sim.fighters[0].y == FighterModel.FLOOR_Y and sim.fighters[0].vy == 0, "Aterrissagem exata"
	)
	sim.fighters[0].x = FightSimulation.LEFT_WALL
	sim.fighters[1].x = FightSimulation.LEFT_WALL + 10
	neutral(sim)
	check(
		sim.fighters[1].x - sim.fighters[0].x >= FightSimulation.BODY_WIDTH,
		"Pushboxes não atravessam na parede"
	)
	check(sim.fighters[0].x >= FightSimulation.LEFT_WALL, "Parede preservada após push")
	var mirrored := BoxMath.world_rect(Rect2i(20, -50, 80, 20), 0, 0, -1)
	check(mirrored.position.x == -100 * FighterModel.SCALE, "Espelhamento inclui largura do AABB")


func _test_frames() -> void:
	var sim := FightSimulation.new(DATA, DATA)
	sim.step([CombatInput.new(0, CombatInput.PUNCH), CombatInput.new()])
	check(sim.fighters[0].move_tick == 1, "Primeiro tick do golpe é zero na resolução")
	check(sim.fighters[0].attack_boxes().is_empty(), "Sem hitbox no startup")
	neutral(sim, 6)
	check(
		sim.fighters[0].move_tick == 7 and sim.fighters[0].attack_boxes().is_empty(),
		"Startup 4f ocupa ticks 0–7"
	)
	neutral(sim)
	check(not sim.fighters[0].attack_boxes().is_empty(), "Active inicia no tick 8")
	neutral(sim, 5)
	check(not sim.fighters[0].attack_boxes().is_empty(), "Active inclui tick 13")
	neutral(sim)
	check(sim.fighters[0].attack_boxes().is_empty(), "Recovery inicia no tick 14")
	neutral(sim, 18)
	check(sim.fighters[0].move_tick == 32, "4+3+9 frames = 32 ticks")
	neutral(sim)
	check(sim.fighters[0].state == FighterState.Id.IDLE, "Retorna a idle após recovery")


func _test_contacts() -> void:
	var sim := close_sim()
	sim.step([CombatInput.new(0, CombatInput.PUNCH), CombatInput.new()])
	neutral(sim, 8)
	check(sim.fighters[1].health == 956, "Soco aplica dano no primeiro tick ativo")
	check(sim.freeze_ticks == 6, "Hitstop 3f = 6 ticks")
	var age := sim.fighters[0].move_tick
	neutral(sim, 6)
	check(sim.fighters[0].move_tick == age, "Hitstop congela frame data")
	neutral(sim, 40)
	check(sim.fighters[1].health == 956, "Um acerto por alvo por golpe")
	sim = close_sim()
	for tick in 24:
		sim.step(
			[
				CombatInput.new(0, CombatInput.PUNCH if tick == 0 else 0),
				CombatInput.new(CombatInput.RIGHT)
			]
		)
	check(sim.fighters[1].health == 1000, "Segurar para trás bloqueia mid")
	# Validação direta de níveis, sem depender de espaçamento ou startup.
	var target := sim.fighters[1]
	target.transition(FighterState.Id.IDLE)
	target.stun_ticks = 0
	target.input = CombatInput.new(CombatInput.GUARD)
	check(not target.blocking(MoveData.Level.LOW), "Defesa alta perde para low")
	target.input = CombatInput.new(CombatInput.GUARD | CombatInput.DOWN)
	check(target.blocking(MoveData.Level.LOW), "Defesa baixa bloqueia low")
	check(not target.blocking(MoveData.Level.OVERHEAD), "Defesa baixa perde para overhead")
	sim = close_sim()
	sim.step([CombatInput.new(0, CombatInput.PUNCH), CombatInput.new(0, CombatInput.PUNCH)])
	neutral(sim, 8)
	check(
		sim.fighters[0].health == 956 and sim.fighters[1].health == 956,
		"Golpes simultâneos geram trade"
	)
	sim = close_sim()
	sim.fighters[1].health = 1
	sim.step([CombatInput.new(0, CombatInput.PUNCH), CombatInput.new()])
	neutral(sim, 8)
	check(sim.winner == 0 and sim.fighters[1].state == FighterState.Id.KO, "KO encerra partida")
	var hp := sim.fighters[1].health
	neutral(sim, 30)
	check(sim.fighters[1].health == hp, "Partida encerrada não aplica novos golpes")


func _test_buffer() -> void:
	var sim := FightSimulation.new(DATA, DATA)
	sim.step([CombatInput.new(0, CombatInput.PUNCH), CombatInput.new()])
	neutral(sim, 26)
	sim.step([CombatInput.new(0, CombatInput.KICK), CombatInput.new()])
	neutral(sim, 5)
	check(
		sim.fighters[0].move_id == "kick",
		"Input no fim de recovery executa na primeira janela livre"
	)
	sim = FightSimulation.new(DATA, DATA)
	sim.step([CombatInput.new(CombatInput.PUNCH, CombatInput.PUNCH), CombatInput.new()])
	for _i in 90:
		sim.step([CombatInput.new(CombatInput.PUNCH), CombatInput.new()])
	check(sim.fighters[0].state == FighterState.Id.IDLE, "Hold não repete ataque sem novo edge")


func _scripted_input(frame: int) -> Array[CombatInput]:
	var p1 := CombatInput.RIGHT if frame % 200 < 60 else 0
	var p2 := CombatInput.LEFT if frame % 200 < 60 else CombatInput.GUARD
	return [
		CombatInput.new(p1, CombatInput.PUNCH if frame % 53 == 0 else 0),
		CombatInput.new(p2, CombatInput.KICK if frame % 89 == 0 else 0)
	]


func _test_replay() -> void:
	var sim := FightSimulation.new(DATA, DATA)
	for frame in 180:
		sim.step(_scripted_input(frame))
	var saved := sim.snapshot()
	var saved_hash := sim.state_hash()
	for frame in range(180, 500):
		sim.step(_scripted_input(frame))
	var expected := sim.state_hash()
	sim.restore(saved)
	check(sim.state_hash() == saved_hash, "Snapshot restaura hash exato")
	for frame in range(180, 500):
		sim.step(_scripted_input(frame))
	check(sim.state_hash() == expected, "Ressimulação de 320 ticks preserva hash")
	var reference := FightSimulation.new(DATA, DATA)
	sim = FightSimulation.new(DATA, DATA)
	var timeline := ReplayTimeline.new()
	for frame in 80:
		var inputs := _scripted_input(frame)
		if frame == 20:
			inputs[1] = CombatInput.new(CombatInput.LEFT, CombatInput.UP)
		reference.step(inputs)
		timeline.advance(sim, _scripted_input(frame))
	check(
		timeline.correct_and_replay(sim, 20, 1, CombatInput.new(CombatInput.LEFT, CombatInput.UP)),
		"Correção local aceita input atrasado"
	)
	check(
		sim.state_hash() == reference.state_hash(),
		"Replay corrigido coincide com referência sem atraso"
	)
	for frame in range(80, 360):
		timeline.advance(sim, _scripted_input(frame))
	check(timeline.history.size() <= ReplayTimeline.CAPACITY + 1, "Histórico tem limite de memória")
	check(
		not timeline.correct_and_replay(sim, 0, 1, CombatInput.new()),
		"Rejeita correção fora do histórico"
	)


func _test_roster() -> void:
	LegacyRoster.load_catalog()
	check(LegacyRoster.ids().size() == 13, "13 personagens do repositório de origem")
	var move_count := 0
	for id in LegacyRoster.ids():
		var c := LegacyRoster.get_character(id)
		check(not c.legacy.voices.is_empty(), "Voz aprovada: " + id)
		check(ResourceLoader.exists(c.legacy.portrait), "Retrato disponível: " + id)
		for move in c.moves.values():
			move_count += 1
			check(move.validate(), "Frame data importada: " + id + "/" + move.id)
			var valid := true
			for f in move.legacy.frames:
				valid = valid and c.legacy.atlases.has(f.pose[0])
				if valid:
					valid = (
						int(f.pose[1]) >= 0
						and int(f.pose[1]) < c.legacy.atlases[f.pose[0]].frames.size()
					)
			check(valid, "Todos os quadros possuem desenho: " + id + "/" + move.id)
	check(move_count == 432, "432 definições de golpes importadas")
	var sim := FightSimulation.new(
		LegacyRoster.get_character("marcelo"), LegacyRoster.get_character("rafael")
	)
	var initial := sim.fighters[0].x
	sim.step([CombatInput.new(CombatInput.RIGHT), CombatInput.new()])
	check(
		sim.fighters[0].x - initial == roundi(324.0 * 256 / 120),
		"Velocidade do Marcelo convertida para ponto fixo"
	)
	check(
		sim.fighters[0].walk_distance == sim.fighters[0].x - initial,
		"Gait acompanha deslocamento corrigido"
	)
	sim.fighters[0].x = FightSimulation.RIGHT_WALL
	sim.fighters[1].x = 800 * 256
	var stride := sim.fighters[0].walk_distance
	sim.step([CombatInput.new(CombatInput.RIGHT), CombatInput.new()])
	check(
		sim.fighters[0].walk_distance == stride,
		"Pé não avança ciclo quando root está preso na parede"
	)
	sim = FightSimulation.new(
		LegacyRoster.get_character("marcelo"), LegacyRoster.get_character("rafael")
	)
	sim.step([CombatInput.new(0, CombatInput.JUMP), CombatInput.new()])
	check(sim.fighters[0].state == FighterState.Id.PREJUMP, "Espaço inicia prejump de 3f")
	neutral(sim, 6)
	check(not sim.fighters[0].grounded(), "Prejump lança corpo após 6 ticks")
	check(
		sim.fighters[0].state == FighterState.Id.JUMP,
		"Saída de prejump mantém estado aéreo, sem cair no idle do chão"
	)
	neutral(sim, 8)
	check(sim.fighters[0].state == FighterState.Id.JUMP, "Estado Jump persiste durante o voo")
	neutral(sim, 120)
	check(sim.fighters[0].grounded(), "Novo personagem aterrissa na origem dos pés")


func _test_pilot_art() -> void:
	PilotArt.load_data()
	var drawings := 0
	for sheet in PilotArt.data.sheets.values():
		check(ResourceLoader.exists(sheet.image), "Atlas novo incluído: " + str(sheet.image))
		for frame in sheet.frames:
			drawings += 1
			check(
				frame.rect[2] > 0 and frame.rect[3] > 0 and frame.scale > 0,
				"Desenho completo com registro e escala"
			)
	check(drawings == 64, "64 desenhos novos, incluindo oito chaves aéreas dedicadas")
	var f := FighterModel.new(LegacyRoster.get_character("marcelo"), 0, 500)
	for state in FighterState.Id.values():
		if state == FighterState.Id.ATTACK:
			continue
		f.state = state
		check(
			not PilotArt.frame(f).is_empty(), "Apresentação do estado " + FighterState.NAMES[state]
		)
	for move in f.character.moves.values():
		f.state = FighterState.Id.ATTACK
		f.move_id = move.id
		for t in move.total_ticks():
			f.move_tick = t
			check(not PilotArt.frame(f).is_empty(), "Arte cobre tick do golpe " + move.id)


func _test_powers_rounds() -> void:
	var marcelo := LegacyRoster.get_character("marcelo")
	var rafael := LegacyRoster.get_character("rafael")
	var sim := FightSimulation.new(marcelo, rafael)
	sim.fighters[0].meter = 100
	sim.step([CombatInput.new(0, CombatInput.SUPER), CombatInput.new()])
	check(sim.fighters[0].meter == 0, "Enxame consome 100 de barra")
	neutral(sim, 90)
	check(sim.projectiles.size() == 5, "Super gera cinco drones independentes")
	var saved := sim.snapshot()
	var saved_hash := sim.state_hash()
	neutral(sim, 190)
	var expected := sim.state_hash()
	check(sim.fighters[1].health < 1000, "Drones disparam e acertam o alvo")
	sim.restore(saved)
	check(sim.state_hash() == saved_hash, "Snapshot restaura IDs, delay e posição dos drones")
	neutral(sim, 190)
	check(sim.state_hash() == expected, "Replay com drones preserva hash")
	sim = FightSimulation.new(marcelo, rafael)
	sim.fighters[0].x = 500 * 256
	sim.fighters[1].x = 600 * 256
	sim.step([CombatInput.new(0, CombatInput.THROW), CombatInput.new(CombatInput.GUARD)])
	neutral(sim, 20)
	check(sim.fighters[1].health < 1000, "Agarrão conecta contra defesa")
	sim = FightSimulation.new(marcelo, rafael)
	sim.fighters[0].meter = 73
	sim.fighters[1].health = 0
	neutral(sim)
	check(sim.wins[0] == 1, "Round contabiliza vencedor")
	neutral(sim, 240)
	check(sim.round_number == 2 and sim.winner == -1, "Próximo round reinicia lutadores")
	check(sim.fighters[0].meter == 73, "Barra super preservada entre rounds")
	sim.fighters[1].health = 0
	neutral(sim)
	check(sim.match_over and sim.wins[0] == 2, "Melhor de três encerra ao vencer dois rounds")


func _test_story() -> void:
	for act_index in 4:
		var world := StorySimulation.new(LegacyRoster.get_character("marcelo"), act_index)
		check(
			world.enemies.size() == world.act().waves[0].size(),
			"Primeira onda do ato %d" % act_index
		)
		var lane := world.hero.ground_y
		world.step(CombatInput.new(CombatInput.UP))
		check(
			world.hero.ground_y < lane and world.hero.grounded(), "Profundidade é separada do salto"
		)
		world.step(CombatInput.new(0, CombatInput.JUMP))
		for i in 8:
			world.step(CombatInput.new())
		check(not world.hero.grounded(), "Espaço salta na campanha")
		for i in 120:
			world.step(CombatInput.new(CombatInput.RIGHT, CombatInput.PUNCH if i % 40 == 0 else 0))
		check(
			world.tick > 100 and not world.snapshot().enemies.is_empty(),
			"Ato simula IA e estado serializável"
		)


func _test_air_kick_v2() -> void:
	var c := LegacyRoster.get_character("marcelo")
	for facing in [1, -1]:
		for start in [8, 30, 65]:
			var sim := FightSimulation.new(c, LegacyRoster.get_character("rafael"))
			sim.fighters[0].x = (350 if facing == 1 else 950) * 256
			sim.fighters[1].x = (1150 if facing == 1 else 100) * 256
			sim.step([CombatInput.new(0, CombatInput.JUMP), CombatInput.new()])
			neutral(sim, start)
			sim.step([CombatInput.new(0, CombatInput.KICK), CombatInput.new()])
			var f := sim.fighters[0]
			check(f.move_id == "airKick:1", "Voadora contextual na subida/ápice/descida")
			check(PilotArt.frame(f).key == "air", "Voadora usa apenas o novo atlas aéreo")
			var before_y := f.y
			var before_vy := f.vy
			neutral(sim)
			check(
				f.y - before_y == before_vy + 77 or f.grounded(),
				"Golpe não teleporta root nem reinicia arco do pulo"
			)
			check(f.facing == facing, "Direção da voadora é preservada")
			var guard := 0
			while not f.grounded() and guard < 160:
				if f.state == FighterState.Id.ATTACK:
					check(
						PilotArt.frame(f).key == "air",
						"Nenhuma pose de chute no chão durante o voo"
					)
				neutral(sim)
				guard += 1
			check(
				f.state == FighterState.Id.LANDING,
				"Contato com piso termina golpe e entra em aterrissagem"
			)
			check(
				f.move_id == "" and f.attack_boxes().is_empty(),
				"Aterrissagem limpa hitboxes e move aéreo"
			)
			neutral(sim, 12)
			check(
				f.state == FighterState.Id.IDLE,
				"Retorno limpo à guarda sem segundo chute automático"
			)
	var f := FighterModel.new(c, 0, 300)
	f.y -= 150 * 256
	f.state = FighterState.Id.JUMP
	f.air_normal_used = true
	f.record_input(CombatInput.new(0, CombatInput.KICK), 0)
	f.begin_tick(900 * 256)
	check(
		f.state == FighterState.Id.JUMP,
		"Segundo normal aéreo não cai no fallback de golpe terrestre"
	)
	f.move_id = "airKick:1"
	f.state = FighterState.Id.ATTACK
	f.move_tick = c.get_move("airKick").startup * 2
	var hit := f.attack_boxes()[0]
	check(hit.position.y - f.y == -223 * 256, "Hitbox acompanha altura do novo pé estendido")
	check(
		hit.position.x - f.x == 174 * 256 and hit.size.x == 80 * 256,
		"Voadora acerta com a bota, sem corredor ofensivo vazio desde o quadril"
	)


func _test_shared_powers() -> void:
	PowerArt.load_data()
	check(
		PowerArt.data.frames.size() == 16, "16 chaves de VFX: código, drone, fumaça, garfo e livro"
	)
	check(ResourceLoader.exists(PowerArt.data.image), "Atlas de poderes disponível no pacote")
	for id in ["marcelo", "gustavo", "khauany", "dienes"]:
		var sim := FightSimulation.new(
			LegacyRoster.get_character(id), LegacyRoster.get_character("rafael")
		)
		sim.step([CombatInput.new(0, CombatInput.SPECIAL), CombatInput.new()])
		neutral(sim, 40)
		check(not sim.projectiles.is_empty(), "Especial é entidade real: " + id)
		check(sim.projectiles[0].kind == "projectile", "Projétil normal separado de drones/lasers")
		check(
			int(sim.projectiles[0].origin_x) > 410 * 256 + 90 * 256,
			"Emissão sai na posição da mão: " + id
		)
	var sim := FightSimulation.new(
		LegacyRoster.get_character("marcelo"), LegacyRoster.get_character("rafael")
	)
	sim.step([CombatInput.new(0, CombatInput.DRONE), CombatInput.new()])
	neutral(sim, 40)
	var drone: Dictionary = sim.projectiles[0]
	var anchor_x := int(drone.x)
	var anchor_y := int(drone.y)
	neutral(sim, 100)
	check(
		int(drone.x) == anchor_x and int(drone.y) == anchor_y,
		"Sentinela permanece posicionada durante carregamento"
	)
	var found_laser := false
	for i in 160:
		neutral(sim)
		for p in sim.projectiles:
			found_laser = found_laser or p.kind == "laser"
	check(found_laser, "Sentinela emite entidade de laser separada")
	check(sim.fighters[1].health < 1000, "Laser acerta alvo abaixo do drone")
	var world := StorySimulation.new(LegacyRoster.get_character("marcelo"))
	world.step(CombatInput.new(0, CombatInput.SPECIAL))
	for i in 30:
		world.step(CombatInput.new())
	check(
		not world.projectiles.is_empty(),
		"História usa projétil com trajeto, sem dano instantâneo de área"
	)
	var saved := world.snapshot()
	for i in 180:
		world.step(CombatInput.new())
	var expected := var_to_bytes(world.snapshot()).hex_encode().sha256_text()
	world.restore(saved)
	for i in 180:
		world.step(CombatInput.new())
	check(
		var_to_bytes(world.snapshot()).hex_encode().sha256_text() == expected,
		"Snapshot/replay do História preserva entidades, IA e projéteis"
	)
	# A lane mismatch must not damage a target even when screen-space AABBs overlap.
	var source := FighterModel.new(LegacyRoster.get_character("marcelo"), 0, 1500)
	var target := FighterModel.new(LegacyRoster.get_character("rafael"), 1, 1700)
	target.ground_y = 500 * 256
	target.y = target.ground_y
	var system := PowerSystem.new()
	source.move_id = "special:1"
	source.state = FighterState.Id.ATTACK
	source.move_tick = source.current_move().startup * 2
	system.emit(source, 0, true)
	var actors: Array[FighterModel] = [source, target]
	var contacts := 0
	for i in 20:
		contacts += system.advance(actors, 3600, i).size()
	check(contacts == 0, "Projéteis do História respeitam profundidade de lane")
	check(not system.projectiles.is_empty(), "Projétil do História permanece válido após X=1380")


func _test_contact_geometry_v3() -> void:
	preload("res://tests/contact_geometry_v3.gd").run(self)


func _test_marcelo_uppercut_v4() -> void:
	var marcelo := LegacyRoster.get_character("marcelo")
	var rafael := LegacyRoster.get_character("rafael")
	for facing in [1, -1]:
		var sim := FightSimulation.new(marcelo, rafael)
		var f := sim.fighters[0]
		f.x = (400 if facing == 1 else 880) * 256
		sim.fighters[1].x = (900 if facing == 1 else 380) * 256
		sim.step([CombatInput.new(0, CombatInput.UPPERCUT), CombatInput.new()])
		var stages := {}
		var launches := 0
		var was_launched := false
		var saved := {}
		for i in 130:
			if f.state == FighterState.Id.ATTACK:
				var pose := FighterPose.select(f)
				var phase := f.current_move().phase(f.move_tick)
				if phase == "STARTUP":
					check(
						f.grounded() and pose.key == "combat" and pose.index == 8,
						"Gancho comprime antes do impulso"
					)
					stages.startup = true
				elif not f.move_motion_started:
					check(
						f.grounded() and pose.index == 9,
						"Primeiro contato do gancho tem apoio no chão"
					)
					stages.drive = true
				elif not f.grounded():
					if phase == "ACTIVE" or f.vy < -450:
						check(
							pose.key == "combat" and pose.index == 10,
							"Subida mantém punho erguido e perna recolhida"
						)
						stages.rise = true
					else:
						check(
							pose.key == "states" and pose.index in [7, 8],
							"Queda usa desenho aéreo, sem crouch/idle no ar"
						)
						stages.fall = true
				else:
					check(
						pose.key == "combat" and pose.index == 11,
						"Recuperação só apoia os pés depois de tocar o chão"
					)
					stages.landing = true
				if phase == "RECOVERY":
					check(
						f.attack_boxes().is_empty(),
						"Gancho não causa dano durante queda/recuperação"
					)
			if f.move_motion_started and not was_launched:
				launches += 1
			was_launched = f.move_motion_started
			if i == 25:
				saved = sim.snapshot()
			neutral(sim)
		check(
			stages.size() == 5 and launches == 1,
			"Gancho percorre todas as fases com um único lançamento"
		)
		check(
			f.grounded() and f.state == FighterState.Id.IDLE and f.move_id == "",
			"Gancho termina recuperado no chão"
		)
		var expected := sim.state_hash()
		sim.restore(saved)
		neutral(sim, 105)
		check(sim.state_hash() == expected, "Replay restaura fase física e pose do gancho")
		var close := FightSimulation.new(marcelo, rafael)
		close.fighters[0].x = (500 if facing == 1 else 780) * 256
		close.fighters[1].x = (606 if facing == 1 else 674) * 256
		close.step([CombatInput.new(0, CombatInput.UPPERCUT), CombatInput.new()])
		var contacts := 0
		for i in 130:
			neutral(close)
			for event in close.events:
				if event.kind == "hit":
					contacts += 1
		check(
			contacts == 1 and close.fighters[1].health < 1000,
			"Gancho conecta uma vez no Rafael nos dois lados"
		)


func _test_roster_art_v5() -> void:
	CharacterArt.load_data()
	var ui := GameScreen.new()
	var rectangles: Array[Rect2] = []
	for id in LegacyRoster.ids():
		var f := FighterModel.new(LegacyRoster.get_character(id), 0, 400)
		var art := CharacterArt.frame(f)
		check(ResourceLoader.exists(art.sheet.image), "Prévia de seleção disponível: " + id)
		var rect := ui.card_rect(rectangles.size())
		check(Rect2(0, 0, 1280, 686).encloses(rect), "Retrato cabe inteiro na seleção: " + id)
		for old in rectangles:
			check(not rect.intersects(old), "Retratos não se sobrepõem")
		rectangles.append(rect)
	check(ui.vertical_neighbor(0, 1) == 5, "Seleção navega verticalmente na grade")
	check(ui.vertical_neighbor(5, -1) == 0, "Navegação vertical volta à mesma coluna")
	ui.free()
	for id in ["rafael", "gustavo"]:
		check(
			CharacterArt.additions[id].frames.size() == 8, "Oito desenhos completos de soco: " + id
		)
		for facing in [1, -1]:
			var sim := FightSimulation.new(
				LegacyRoster.get_character(id), LegacyRoster.get_character("marcelo")
			)
			sim.fighters[0].x = (450 if facing == 1 else 830) * 256
			sim.fighters[1].x = (630 if facing == 1 else 650) * 256
			sim.step([CombatInput.new(0, CombatInput.PUNCH), CombatInput.new()])
			var hits := 0
			var saved := {}
			for tick in 110:
				var f := sim.fighters[0]
				if f.state == FighterState.Id.ATTACK:
					var art := CharacterArt.frame(f)
					check(art.key == "punch_v5", "Soco usa sequência nova: " + id)
					if f.current_move().phase(f.move_tick) != "ACTIVE":
						check(f.attack_boxes().is_empty(), "Sem dano fora da extensão: " + id)
				for event in sim.events:
					if event.kind == "hit":
						hits += 1
				if tick == 16:
					saved = sim.snapshot()
				neutral(sim)
			check(hits == 1, "Soco novo conecta uma vez nos dois lados: " + id)
			var expected := sim.state_hash()
			sim.restore(saved)
			neutral(sim, 94)
			check(sim.state_hash() == expected, "Replay preserva sequência nova: " + id)
