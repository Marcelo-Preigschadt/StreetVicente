class_name StoryV27Tests
extends RefCounted
const UNIT := FighterModel.SCALE


static func run(s: SceneTree) -> void:
	var world := StorySimulation.new(LegacyRoster.get_character("marcelo"))
	s.check(world.props.all(func(p): return p.kind not in ["table", "chair"] or p.x >= 2500 * UNIT),
		"Mesas e cadeiras ficam junto à cantina, fora do corredor inicial")
	s.check(world.props.filter(func(p): return p.kind == "table").all(func(p): return p.lane <= 510 * UNIT),
		"Mesas ocupam a faixa de refeições, deixando a passagem frontal livre")
	for kind in LegacyRoster.catalog.story.enemies:
		var atlas := StoryEnemyArt.atlas(kind)
		s.check(int(atlas.get("revision", 0)) == 27 and FileAccess.file_exists(atlas.file),
			"Inimigo usa desenhos novos da mesma direção artística: " + kind)
	for kind in ["cleaner", "turnstile", "inspector"]:
		var atlas := StoryEnemyArt.atlas(kind)
		var low := 10000
		var high := 0
		for index in atlas.sequences.walk:
			var h := int(atlas.frames[index].rect[3])
			low = mini(low, h)
			high = maxi(high, h)
		s.check(float(high - low) / atlas.referenceHeight < .08,
			"Caminhada mantém altura e anatomia sem escala diferente por quadro: " + kind)
		var f := FighterModel.new(StorySimulation._enemy_character(kind), 42, 400)
		f.state = FighterState.Id.WALK
		f.facing = 1
		f.input = CombatInput.new(CombatInput.RIGHT)
		var enemy := {"kind": kind, "fighter": f, "dead_tick": -1, "attack_mode": "melee"}
		var seen: Dictionary = {}
		for distance in 112:
			f.walk_distance = distance * UNIT
			seen[StoryEnemyArt.sample(enemy, 0).index] = true
		s.check(seen.size() == 8, "Oito poses reais no ciclo completo de passos: " + kind)
	# The initial arena occupies the viewport. Moving within it cannot drag
	# the floor while the encounter is locked; unlocking pans at bounded speed.
	world.enemies.clear()
	world.spawn_queue.clear()
	world.hero.x = 900 * UNIT
	world.step(CombatInput.new())
	s.check(world.camera_units == 0, "Câmera mantém o enquadramento da primeira luta")
	world.hero.x = (StoryLayout.gate(0) - 170) * UNIT
	world.step(CombatInput.new())
	s.check(world.wave_index == 1, "Passagem liberada abre a área seguinte")
	var last := world.camera_units
	world.step(CombatInput.new())
	s.check(world.camera_units > last and world.camera_units - last <= 8 * UNIT,
		"Desbloqueio da câmera percorre o cenário sem salto de posição")
	var clone := StorySimulation.new(world.hero.character)
	clone.restore(JSON.parse_string(JSON.stringify(world.snapshot())))
	var equal := true
	for tick in 90:
		world.step(CombatInput.new(CombatInput.GUARD))
		clone.step(CombatInput.new(CombatInput.GUARD))
		equal = equal and world.state_hash() == clone.state_hash()
	s.check(equal, "Enquadramento, arte e combate mantêm replay determinístico ao abrir uma área")
	world.wave_index = 3
	world.enemies.clear()
	world._spawn_wave()
	for enemy in world.enemies:
		s.check(OpenBorMotion.test_position(world, enemy.fighter, Vector2i(enemy.fighter.x, enemy.fighter.ground_y)),
			"Chefe entra na passagem livre, sem nascer dentro das mesas")
