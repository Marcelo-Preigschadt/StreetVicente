class_name StoryV26Tests
extends RefCounted
const UNIT := FighterModel.SCALE


static func arena() -> StorySimulation:
	var world := StorySimulation.new(LegacyRoster.get_character("marcelo"))
	world.enemies.clear()
	world.spawn_queue.clear()
	world.props.clear()
	world.wave_index = 2
	return world


static func run(s: SceneTree) -> void:
	# Reproduce the table failure at its exact footprint, using ordinary input.
	var world := arena()
	world.objects._add_prop("table", 700, 585, 160)
	var table: Dictionary = world.props[0]
	var rect := OpenBorMotion.footprint(table)
	world.hero.x = rect.position.x - 2 * UNIT
	world.hero.ground_y = 585 * UNIT
	world.hero.y = world.hero.ground_y
	for i in 80:
		world.step(CombatInput.new(CombatInput.RIGHT))
	s.check(world.hero.x == rect.position.x, "Mesa bloqueia pelo chão, sem penetrar a base")
	var start_lane := world.hero.ground_y
	for i in 75:
		world.step(CombatInput.new(CombatInput.RIGHT | CombatInput.DOWN))
	s.check(world.hero.ground_y > start_lane + 40 * UNIT and world.hero.x > rect.position.x + 20 * UNIT,
		"Movimento diagonal desliza pela borda da mesa e sai do bloqueio")
	# An old save can put a body inside furniture. Moving toward an exit must work.
	world.hero.x = int(table.x)
	world.hero.ground_y = int(table.lane)
	world.hero.y = world.hero.ground_y
	for i in 90:
		world.step(CombatInput.new(CombatInput.DOWN))
	s.check(world.hero.ground_y >= rect.end.y, "Sobreposição de save antigo permite sair da mesa")
	# Fast displacement must stop at the first crossed face, even if the endpoint
	# is already on the far side of the object.
	var before := rect.position.x - 20 * UNIT
	world.hero.x = rect.end.x + 100 * UNIT
	world.hero.ground_y = 585 * UNIT
	world.hero.y = world.hero.ground_y
	world.objects.constrain_actor(world.hero, before, world.hero.ground_y)
	s.check(world.hero.x == rect.position.x, "Colisão varrida segura deslocamento rápido pela mesa")
	# Real throw: link only a nearby grounded enemy, release once on the authored
	# throw frame, then travel independently and collide with a second enemy.
	var fight := arena()
	fight._spawn_enemy({"kind": "lab", "x": 310, "lane": 625, "cooldown": 99999})
	fight._spawn_enemy({"kind": "lab", "x": 550, "lane": 625, "cooldown": 99999})
	var target: FighterModel = fight.enemies[0].fighter
	var bystander: FighterModel = fight.enemies[1].fighter
	var hp := target.health
	var other_hp := bystander.health
	fight.step(CombatInput.new(0, CombatInput.THROW))
	s.check(fight.hero.move_id == "throw:1" and target.health == hp, "Agarrão vincula alvo próximo sem dano antes da soltura")
	s.check(absi(target.x - fight.hero.x) == 82 * UNIT, "Agarrão alinha os dois corpos na distância do vínculo")
	var held_copy := arena()
	held_copy.restore(JSON.parse_string(JSON.stringify(fight.snapshot())))
	var link_replay_ok := true
	var release_x := target.x
	var released := false
	for i in 140:
		fight.step(CombatInput.new())
		held_copy.step(CombatInput.new())
		link_replay_ok = link_replay_ok and fight.state_hash() == held_copy.state_hash()
		if target.health < hp:
			released = true
			break
	s.check(released and target.vy < 0 and target.knockdown_pending, "Soltura arremessa o alvo em arco com queda")
	s.check(link_replay_ok, "Save feito durante agarrão preserva vínculo e instante exato da soltura")
	var copy := arena()
	copy.restore(JSON.parse_string(JSON.stringify(fight.snapshot())))
	var replay_ok := true
	for i in 160:
		fight.step(CombatInput.new())
		copy.step(CombatInput.new())
		replay_ok = replay_ok and fight.state_hash() == copy.state_hash()
	s.check(replay_ok, "Vínculo, corpo arremessado e colisão sobrevivem a save JSON/rollback")
	s.check(target.x > release_x + 120 * UNIT, "Corpo arremessado mantém impulso independente da reação")
	s.check(bystander.health < other_hp, "Corpo arremessado atinge outro inimigo")
	var empty := arena()
	empty.step(CombatInput.new(0, CombatInput.THROW))
	s.check(empty.hero.state != FighterState.Id.ATTACK, "Agarrão vazio não causa ataque invisível à distância")
	# AI must reach the player around the table using its own controls/collision,
	# rather than the browser QA teaching a route to hide a navigation defect.
	var navigation := arena()
	navigation.objects._add_prop("table", 700, 585, 160)
	navigation.hero.x = 470 * UNIT
	navigation.hero.ground_y = 585 * UNIT
	navigation.hero.y = navigation.hero.ground_y
	navigation._spawn_enemy({"kind": "lab", "x": 940, "lane": 585, "cooldown": 0})
	var reached := false
	for i in 1000:
		navigation.step(CombatInput.new(CombatInput.GUARD))
		var foe: FighterModel = navigation.enemies[0].fighter
		if absi(foe.x - navigation.hero.x) < 200 * UNIT and absi(foe.ground_y - navigation.hero.ground_y) < 28 * UNIT:
			reached = true
			break
	s.check(reached, "IA contorna mesa e volta à distância de combate sem teleporte")
	# Snapshot during co-op: each player has an independent controller/link.
	var coop := CoopStorySimulation.new(LegacyRoster.get_character("tais"), LegacyRoster.get_character("marcos"))
	var clone := CoopStorySimulation.new(LegacyRoster.get_character("tais"), LegacyRoster.get_character("marcos"))
	for i in 90:
		coop.step_party([CombatInput.new(CombatInput.RIGHT), CombatInput.new(CombatInput.UP)])
	clone.restore(JSON.parse_string(JSON.stringify(coop.snapshot())))
	var coop_ok := true
	for i in 240:
		var values: Array[CombatInput] = [CombatInput.new(CombatInput.GUARD, CombatInput.PUNCH if i % 28 == 0 else 0), CombatInput.new(CombatInput.GUARD)]
		coop.step_party(values)
		clone.step_party(values)
		coop_ok = coop_ok and coop.state_hash() == clone.state_hash()
	s.check(coop_ok, "Novo controle mantém campanha cooperativa determinística")
