class_name StoryV23Tests
extends RefCounted
const UNIT := FighterModel.SCALE


static func run(s: SceneTree) -> void:
	for id in LegacyRoster.ids():
		var world := StorySimulation.new(LegacyRoster.get_character(id))
		world.enemies.clear()
		s.check(world.hero.meter == 0 and world.hero.campaign_costs, "História começa sem energia: " + id)
		world.step(CombatInput.new(0, CombatInput.SPECIAL | CombatInput.UPPERCUT | CombatInput.SUPER))
		s.check(world.hero.state != FighterState.Id.ATTACK, "Energia vazia bloqueia poderes: " + id)
		for tick in 40:
			world.step(CombatInput.new())
		s.check(world.hero.meter == 0, "Sem recarga passiva: " + id)
		world.hero.meter = 25
		world.step(CombatInput.new(0, CombatInput.SPECIAL))
		s.check(world.hero.move_id == "special:1" and world.hero.meter == 0, "H paga 25 na partida: " + id)
		var duel := FighterModel.new(LegacyRoster.get_character(id), 0, 300)
		s.check(duel.move_cost(duel.character.get_move("special", 1)) == int(duel.character.get_move("special", 1).legacy.get("cost", 0)), "Versus preserva custo original: " + id)

	var world := StorySimulation.new(LegacyRoster.get_character("marcelo"))
	world.wave_index = 2
	world.enemies = [world.enemies[1]]
	var target: FighterModel = world.enemies[0].fighter
	target.x = world.hero.x + 130 * UNIT
	target.ground_y = world.hero.ground_y
	target.y = target.ground_y
	world.step(CombatInput.new(0, CombatInput.PUNCH))
	for tick in 24:
		world.step(CombatInput.new())
	s.check(target.health < target.character.max_health and world.hero.meter >= 8, "Soco em robô carrega energia por contato real")
	var saved := world.snapshot()
	var copy := StorySimulation.new(world.hero.character)
	copy.restore(JSON.parse_string(JSON.stringify(saved)))
	s.check(world.state_hash() == copy.state_hash(), "Energia e regra de custo sobrevivem ao snapshot JSON")
	for kind in LegacyRoster.catalog.story.enemies:
		var atlas := StoryEnemyArt.atlas(kind)
		s.check(atlas.frames.size() >= 16 and FileAccess.file_exists(atlas.file), "Inimigo tem caminhada, golpe, reação e queda: " + kind)
		var f := FighterModel.new(StorySimulation._enemy_character(kind), 10, 100)
		var enemy := {"kind": kind, "fighter": f, "dead_tick": -1, "attack_mode": "melee"}
		f.state = FighterState.Id.WALK
		var first: int = StoryEnemyArt.sample(enemy, 0).index
		f.walk_distance = 70 * UNIT
		var next: int = StoryEnemyArt.sample(enemy, 40).index
		s.check(first != next, "Ciclo muda quadros pelo trajeto, não desliza uma imagem: " + kind)
		f.health = 0
		enemy.dead_tick = 0
		s.check(StoryEnemyArt.sample(enemy, 200).index == int(atlas.sequences.fall[-1]), "Queda tem desfecho próprio: " + kind)
	var coop := CoopStorySimulation.new(LegacyRoster.get_character("marcelo"), LegacyRoster.get_character("khauany"))
	s.check(coop.heroes.all(func(f): return f.campaign_costs and f.meter == 0), "Coop usa a mesma energia e custos nos dois jogadores")
	for wave in 4:
		var bounded := StorySimulation.new(LegacyRoster.get_character("marcelo"))
		bounded.wave_index = wave
		bounded.enemies.clear()
		bounded._spawn_wave()
		var edge := StoryLayout.gate(wave) * UNIT
		for enemy in bounded.enemies:
			var f: FighterModel = enemy.fighter
			s.check(f.x <= edge - 80 * UNIT, "Formação nasce dentro da área acessível da onda")
			f.x = edge + 500 * UNIT
		bounded.step(CombatInput.new())
		for enemy in bounded.enemies:
			s.check(enemy.fighter.x <= edge - 60 * UNIT, "Recuo de máquina não cria alvo inalcançável atrás da barreira")
