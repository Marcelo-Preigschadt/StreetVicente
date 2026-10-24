class_name StoryV24Tests
extends RefCounted
const UNIT := FighterModel.SCALE


static func run(s: SceneTree) -> void:
	LegacyRoster.load_catalog()
	for kind in StoryLayout.PROP_SIZES:
		var size := StoryLayout.prop_size(kind)
		var texture := LegacyRoster.texture(LegacyRoster.catalog.story.props[kind].file)
		var source_ratio := float(texture.get_width()) / texture.get_height()
		s.check(absf(size.x / size.y - source_ratio) < .012, "Móvel conserva a proporção da imagem: " + kind)
	s.check(StoryLayout.prop_size("chair").y / 300.0 > .52, "Encosto de cadeira adulto supera metade da altura do lutador")
	s.check(StoryLayout.prop_size("table").y / 300.0 > .40, "Tampo da mesa tem altura proporcional ao lutador")
	var world := StorySimulation.new(LegacyRoster.get_character("marcelo"))
	var enemy: Dictionary = world.enemies[1]
	var f: FighterModel = enemy.fighter
	f.ground_y = 540 * UNIT
	f.y = f.ground_y
	for state in [FighterState.Id.HITSTUN, FighterState.Id.ATTACK, FighterState.Id.KNOCKDOWN, FighterState.Id.WAKEUP]:
		f.state = state
		var lane := f.ground_y
		var input := StoryEnemyMotion.intent(world, enemy, world.hero)
		s.check(f.ground_y == lane and input.held == 0, "IA não arrasta máquina durante reação/queda: " + FighterState.NAMES[state])
	f.state = FighterState.Id.WAKEUP
	f.state_tick = 0
	s.check(StoryEnemyArt.sample(enemy, 100).index == 15, "Recuperação começa deitada, sem salto para a pose em pé")
	f.state_tick = 35
	s.check(StoryEnemyArt.sample(enemy, 135).index == 0, "Recuperação termina na pose neutra")
	var drone: Dictionary = world.enemies[0]
	var flyer: FighterModel = drone.fighter
	flyer.x = world.hero.x + 200 * UNIT
	drone.cooldown = 0
	var input := StoryEnemyMotion.intent(world, drone, world.hero)
	flyer.record_input(input, 0)
	flyer.begin_tick(world.hero.x)
	s.check(flyer.facing == -1, "Drone voando olha para o alvo")
	s.check(flyer.move_id == "enemy_shot", "Drone usa ataque de máquina, não o chute aéreo do manequim")
	var original: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/story/enemy-animation-v23.json"))
	var cleaner := StoryEnemyArt.atlas("cleaner")
	s.check(cleaner.frames[9].bottom < original.enemies.cleaner.frames[9].bottom - 20, "Arco elétrico não desloca a base do robô")
	var crowd := StorySimulation.new(LegacyRoster.get_character("marcelo"))
	crowd.hero.x = 400 * UNIT
	for machine in crowd.enemies:
		machine.fighter.x = 520 * UNIT
		machine.cooldown = 0
	var first := StoryEnemyMotion.intent(crowd, crowd.enemies[1], crowd.hero)
	var second := StoryEnemyMotion.intent(crowd, crowd.enemies[2], crowd.hero)
	s.check(first.pressed == CombatInput.KICK and second.pressed == 0, "Máquinas no mesmo lado não atacam empilhadas")
	s.check(second.held == CombatInput.RIGHT, "Segunda máquina abre espaço na aproximação")
	var ranged := StorySimulation.new(crowd.hero.character)
	ranged.enemies.clear()
	ranged.wave_index = 1
	ranged._spawn_wave()
	for machine in ranged.enemies:
		machine.fighter.x = ranged.hero.x + 200 * UNIT
		machine.cooldown = 0
	var front_drone := StoryEnemyMotion.intent(ranged, ranged.enemies[1], ranged.hero)
	var back_drone := StoryEnemyMotion.intent(ranged, ranged.enemies[3], ranged.hero)
	s.check(front_drone.pressed == CombatInput.KICK and back_drone.pressed == 0 and back_drone.held == CombatInput.RIGHT, "Drones também se distribuem em posições distintas")
	var legacy := world.snapshot()
	legacy.erase("story_revision")
	legacy.props[1].x = 1040 * UNIT
	legacy.props[2].x = 1260 * UNIT
	var resumed := StorySimulation.new(world.hero.character)
	resumed.restore(legacy)
	s.check(resumed.props[1].x == 985 * UNIT and resumed.props[2].x == 1315 * UNIT, "Save antigo reposiciona cadeiras para a escala adulta")
	var copy := StorySimulation.new(crowd.hero.character)
	copy.restore(JSON.parse_string(JSON.stringify(crowd.snapshot())))
	for tick in 180:
		var held := CombatInput.new(CombatInput.GUARD)
		crowd.step(held)
		copy.step(held)
		s.check(crowd.state_hash() == copy.state_hash(), "Aproximação/voo conserva rollback após JSON")
