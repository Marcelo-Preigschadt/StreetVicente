class_name StoryV28Tests
extends RefCounted
const UNIT := FighterModel.SCALE


static func clear_world(id: String = "marcelo") -> StorySimulation:
	var world := StorySimulation.new(LegacyRoster.get_character(id))
	world.enemies.clear()
	world.spawn_queue.clear()
	world.props.clear()
	return world


static func recovery(world: StorySimulation) -> bool:
	for tick in 180:
		world.step(CombatInput.new())
		if world.hero.state == FighterState.Id.ATTACK and world.hero.has_contact \
			and world.hero.current_move().phase(world.hero.move_tick) == "RECOVERY":
			return true
	return false


static func run(s: SceneTree) -> void:
	s.check(StoryScenery.decorations(4).size() == StoryScenery.decorations(3).size(), "Tela de campanha concluída conserva cenário final sem acessar ato inexistente")
	for id in LegacyRoster.ids():
		var world := clear_world(id)
		world.objects._add_prop("table", 420, 625, 160)
		world.hero.x = 245 * UNIT
		world.hero.facing = 1
		var damaged := false
		for swing in 6:
			world.step(CombatInput.new(0, CombatInput.PUNCH))
			for tick in 110:
				world.step(CombatInput.new())
			damaged = damaged or int(world.props[0].hp) < 160
			if world.props[0].used:
				break
		s.check(damaged and world.props[0].used, "Soco normal quebra mesa sem E nem alinhamento: " + id)
		var chair := clear_world(id)
		chair.objects._add_prop("chair", 330, 625, 80)
		chair.hero.x = 240 * UNIT
		chair.hero.facing = 1
		chair.step(CombatInput.new(0, CombatInput.KICK))
		var launched := false
		for tick in 110:
			chair.step(CombatInput.new())
			launched = launched or not chair.objects.thrown.is_empty()
		s.check(launched and chair.props[0].used, "Chute comum lança cadeira no contato, sem E: " + id)
		s.check(chair.objects.carry.is_empty() and chair.objects.interaction_phase.is_empty(), "Ataque comum não toma controle para posicionar móvel: " + id)
	var miss := clear_world()
	miss.objects._add_prop("table", 900, 625, 160)
	miss.objects._add_prop("table", 90, 625, 160)
	miss.step(CombatInput.new(0, CombatInput.PUNCH))
	for tick in 100:
		miss.step(CombatInput.new())
	s.check(miss.props.all(func(p): return p.hp == 160), "Soco não danifica móvel distante nem atrás do personagem")
	var branch := clear_world()
	branch._spawn_enemy({"kind": "cleaner", "x": 350, "lane": 625, "cooldown": 99999})
	var victim: FighterModel = branch.enemies[0].fighter
	victim.health = 5000
	victim.state = FighterState.Id.HITSTUN
	victim.stun_ticks = 1000
	branch.step(CombatInput.new(0, CombatInput.PUNCH))
	s.check(recovery(branch), "Primeiro soco confirma antes da ramificação")
	branch.step(CombatInput.new(0, CombatInput.PUNCH))
	s.check(recovery(branch), "Segundo soco confirma com contato real")
	branch.step(CombatInput.new(0, CombatInput.KICK))
	s.check(branch.hero.move_id == "bor:3", "F,F,G ramifica para finalizador sem repetir quatro socos")
	var air := clear_world()
	air._spawn_enemy({"kind": "cleaner", "x": 350, "lane": 625, "cooldown": 99999})
	air.enemies[0].fighter.state = FighterState.Id.HITSTUN
	air.enemies[0].fighter.stun_ticks = 1000
	air.step(CombatInput.new(0, CombatInput.PUNCH))
	s.check(recovery(air), "Contato libera transição aérea na recuperação")
	air.step(CombatInput.new(0, CombatInput.JUMP))
	for tick in 10:
		air.step(CombatInput.new())
	s.check(air.hero.y < air.hero.ground_y, "Salto encadeado sai do chão com animação original")
	var priority := clear_world()
	priority.objects._add_prop("bench", 90, 625, 180)
	priority._spawn_enemy({"kind": "cleaner", "x": 310, "lane": 625, "cooldown": 99999})
	priority.step(CombatInput.new(0, CombatInput.THROW))
	s.check(priority.hero.move_id == "throw:1", "E agarra o inimigo próximo antes de escolher um móvel")
	var rush := clear_world()
	rush._spawn_enemy({"kind": "inspector", "x": 520, "lane": 625, "cooldown": 99999})
	var commander: Dictionary = rush.enemies[0]
	commander.attack_serial = 2
	rush._prepare_enemy_attack(commander)
	commander.fighter.facing = -1
	commander.fighter._start_move(commander.fighter.character.kick)
	commander.fighter.move_tick = commander.fighter.current_move().startup * 2
	var before_x: int = commander.fighter.x
	var before_stride: int = commander.fighter.walk_distance
	rush.step(CombatInput.new(CombatInput.GUARD))
	s.check(commander.fighter.x != before_x and commander.fighter.walk_distance > before_stride, "Investida avança o ciclo dos pés pela distância real, sem deslizar pose congelada")
	for act in 4:
		var world := StorySimulation.new(LegacyRoster.get_character("marcelo"), act)
		s.check(world.props.size() >= 9 and StoryScenery.decorations(act).size() >= 12,
			"Ato tem grupos de móveis interativos e composição de ambiente: %d" % act)
		for prop in world.props:
			s.check(FileAccess.file_exists(LegacyRoster.catalog.story.props[prop.kind].file), "Objeto tem arte empacotada: " + str(prop.kind))
		for wave in 4:
			world.enemies.clear()
			world.wave_index = wave
			world._spawn_wave()
			for enemy in world.enemies:
				s.check(OpenBorMotion.test_position(world, enemy.fighter, Vector2i(enemy.fighter.x, enemy.fighter.ground_y)), "Formação evita móveis no nascimento: %d/%d" % [act, wave])
			for entry in world.spawn_queue:
				s.check(OpenBorMotion.test_position(world, world.hero, Vector2i(int(entry.x) * UNIT, int(entry.lane) * UNIT)), "Reforço também entra em chão livre")
	for kind in ["cleaner", "turnstile", "lab", "vial", "scanner", "archaeologist", "elite", "kungfu"]:
		var profile: Dictionary = LegacyRoster.catalog.story.enemies[kind]
		s.check(int(profile.h) >= 340, "Robô humanoide mantém porte de lutador adulto: " + kind)
		var world := clear_world()
		world._spawn_enemy({"kind": kind, "x": 360, "lane": 625, "cooldown": 99999})
		var seen: Dictionary = {}
		for index in 8:
			world._prepare_enemy_attack(world.enemies[0])
			var enemy: Dictionary = world.enemies[0]
			seen[enemy.attack_mode] = true
			if enemy.attack_mode in ["kick", "sweep", "heavy", "dash"]:
				enemy.fighter._start_move(enemy.fighter.character.kick)
				enemy.fighter.move_tick = enemy.fighter.current_move().startup * 2
				var art := StoryEnemyArt.sample(enemy, 0)
				s.check(str(art.sheet.file).contains("actions.webp"), "Ataque diferente usa desenho próprio: " + str(enemy.attack_mode))
		if not profile.get("ranged", false):
			s.check(seen.size() >= 3, "Inimigo alterna ataques com alcance/tempo distintos: " + kind)
	var legacy := StorySimulation.new(LegacyRoster.get_character("marcelo"))
	var old := legacy.snapshot()
	old.story_revision = 27
	old.props = old.props.filter(func(p): return not p.has("scene_key"))
	var resumed := StorySimulation.new(legacy.hero.character)
	resumed.restore(JSON.parse_string(JSON.stringify(old)))
	var count := resumed.props.size()
	var copied := StorySimulation.new(legacy.hero.character)
	copied.restore(JSON.parse_string(JSON.stringify(resumed.snapshot())))
	s.check(count >= 9 and copied.props.size() == count, "Save anterior recebe móveis sem duplicar na retomada seguinte")
	var same := true
	for tick in 480:
		var value := CombatInput.new(CombatInput.RIGHT if tick < 80 else CombatInput.GUARD, CombatInput.PUNCH if tick % 45 == 0 else 0)
		resumed.step(value)
		copied.step(value)
		same = same and resumed.state_hash() == copied.state_hash()
	s.check(same, "Táticas, mobiliário, combos e tiros mantêm replay determinístico")
