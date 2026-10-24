class_name StoryV25Tests
extends RefCounted
const UNIT := FighterModel.SCALE


static func run(s: SceneTree) -> void:
	var c := LegacyRoster.get_character("marcelo")
	var world := StorySimulation.new(c)
	world.enemies.clear()
	world.props.clear()
	# New movement is free-facing, with diagonal normalization and no lane
	# control during attacks. The original versus data remains shared/immutable.
	world.step(CombatInput.new(CombatInput.LEFT))
	s.check(world.hero.facing == -1, "Campanha vira na direção do movimento")
	world.step(CombatInput.new(CombatInput.RIGHT, CombatInput.PUNCH))
	var lane := world.hero.ground_y
	for tick in 12:
		world.step(CombatInput.new(CombatInput.DOWN))
	s.check(world.hero.ground_y == lane, "Ataque mantém pés e profundidade durante a animação")
	s.check(not c.moves.has("fury:0") and world.hero.character.moves.has("fury:0"), "Adaptação não altera os moves do versus")
	# Four confirmed normals and the knockdown finisher on a full-height target.
	var fight := StorySimulation.new(c)
	fight.enemies.clear()
	fight.props.clear()
	fight._spawn_enemy({"kind": "lab", "x": 360, "lane": 625, "cooldown": 99999})
	var target: FighterModel = fight.enemies[0].fighter
	target.health = 5000
	var steps: Array = []
	for step in 4:
		fight.freeze_ticks = 0
		fight.hero.transition(FighterState.Id.IDLE)
		fight.hero.stun_ticks = 0
		fight.hero.x = 220 * UNIT
		fight.hero.facing = 1
		target.x = 350 * UNIT
		target.ground_y = fight.hero.ground_y
		target.y = target.ground_y
		target.invincible_ticks = 0
		target.stun_ticks = 1000
		target.state = FighterState.Id.HITSTUN
		fight.step(CombatInput.new(0, CombatInput.PUNCH))
		steps.append(fight.hero.move_id)
		var before := target.health
		for tick in 85:
			fight.step(CombatInput.new())
			if target.health < before:
				break
		s.check(target.health < before, "Normal confirmado por colisão real: %d" % step)
	s.check(steps == ["fury:0", "fury:1", "fury:2", "fury:3"], "Combo importado progride soco/soco/chute/finalizador")
	s.check(target.knockdown_pending and target.vy < 0, "Quarto golpe derruba e lança o inimigo")
	# Real contact-frame object interaction, then airborne save/replay.
	var objects := StorySimulation.new(c)
	objects.wave_index = 2
	objects.enemies.clear()
	var chair: Dictionary = objects.props[1]
	objects.hero.x = int(chair.x) - 90 * UNIT
	objects.hero.ground_y = int(chair.lane)
	objects.hero.y = objects.hero.ground_y
	objects.step(CombatInput.new(0, CombatInput.THROW))
	s.check(objects.objects.thrown.is_empty() and objects.objects.carry.is_empty(), "E prepara chute; cadeira continua no chão no startup")
	for tick in 80:
		objects.step(CombatInput.new())
		if not objects.objects.thrown.is_empty():
			break
	s.check(not objects.objects.thrown.is_empty(), "Cadeira vira projétil apenas no contato do chute")
	var copy := StorySimulation.new(c)
	copy.restore(JSON.parse_string(JSON.stringify(objects.snapshot())))
	for tick in 140:
		var value := CombatInput.new(CombatInput.RIGHT if tick < 35 else 0)
		objects.step(value)
		copy.step(value)
		s.check(objects.state_hash() == copy.state_hash(), "Projétil e combo continuam idênticos após JSON")
	# Source checkpoint queue: simultaneous cap without losing any wave member.
	var checkpoint := StorySimulation.new(c)
	checkpoint.enemies.clear()
	checkpoint.wave_index = 1
	checkpoint._spawn_wave()
	s.check(checkpoint.enemies.size() == 3 and checkpoint.spawn_queue.size() == 1, "Checkpoint limita três inimigos e conserva reforço na fila")
	checkpoint.enemies[0].fighter.health = 0
	for tick in 61:
		checkpoint.step(CombatInput.new(CombatInput.GUARD))
	s.check(checkpoint.spawn_queue.is_empty() and checkpoint.enemies.size() == 4, "Reforço entra quando uma posição é liberada")
	var legacy := checkpoint.snapshot()
	legacy.objects.carry = {"kind": "chair", "id": int(legacy.props[1].id), "source_x": legacy.props[1].x, "source_lane": legacy.props[1].lane}
	legacy.props[1].used = true
	var migrated := StorySimulation.new(c)
	migrated.restore(legacy)
	s.check(migrated.objects.carry.is_empty() and not migrated.props[1].used, "Save antigo devolve móvel ao chão sem pose de soco")
