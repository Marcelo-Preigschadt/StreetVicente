class_name ArcadeV9Tests
extends RefCounted


static func run(s: SceneTree) -> void:
	var f := FighterModel.new(LegacyRoster.get_character("joao"), 0, 400)
	for state in [
		FighterState.Id.IDLE,
		FighterState.Id.WALK,
		FighterState.Id.BLOCK,
		FighterState.Id.CROUCH,
		FighterState.Id.JUMP,
		FighterState.Id.HITSTUN,
		FighterState.Id.KNOCKDOWN,
		FighterState.Id.VICTORY
	]:
		f.state = state
		s.check(ArcadeArt.has_frame(f), "João usa corpo novo no estado %d" % state)
	for name in [
		"punch", "kick", "crouchPunch", "sweep", "airPunch", "airKick", "uppercut", "special"
	]:
		f.state = FighterState.Id.ATTACK
		f.move_id = name + ":1"
		for tick in f.current_move().total_ticks():
			f.move_tick = tick
			var frame := CharacterArt.frame(f)
			var revision := "powers-v10" if name == "special" else "arcade-v9"
			s.check(revision in frame.sheet.image, "Sem retorno à arte antiga durante %s" % name)
			if name != "special":
				s.check(
					f.attack_boxes().is_empty() == (f.current_move().phase(tick) != "ACTIVE"),
					"Contato somente no active: João/%s" % name
				)
	for id in ["joao", "adriano"]:
		var c := LegacyRoster.get_character(id)
		var fighter := FighterModel.new(c, 0, 400)
		var guard := CharacterArt.frame(fighter)
		var height: float = guard.frame.rect[3] * guard.frame.scale * CharacterMetrics.factor(id)
		fighter.state = FighterState.Id.WALK
		for i in 8:
			fighter.walk_distance = i * 20 * 256
			var art := CharacterArt.frame(fighter)
			var walk_height: float = (
				art.frame.rect[3] * art.frame.scale * CharacterMetrics.factor(id)
			)
			s.check(
				absf(walk_height - height) < 9,
				"Caminhada preserva altura da guarda: %s/%d" % [id, i]
			)
			# No full-body vertical stretch: one sheet scale for every walking cel.
			s.check(art.frame.scale == art.sheet.scale, "Escala uniforme por folha")
	var buffer := CommandBuffer.new()
	buffer.record(CombatInput.new(CombatInput.STRONG, CombatInput.PUNCH), 0)
	buffer.record(CombatInput.new(), 10)
	s.check(buffer.strength(CombatInput.PUNCH) == 2, "Buffer mantém força após soltar Y")
	var restored := CommandBuffer.new()
	restored.restore(buffer.snapshot())
	s.check(restored.strength(CombatInput.PUNCH) == 2, "Snapshot inclui força do comando")
	# A queued strong attack survives neutral inputs during the final recovery ticks.
	var sim := FightSimulation.new(
		LegacyRoster.get_character("joao"), LegacyRoster.get_character("rafael")
	)
	var actor: FighterModel = sim.fighters[0]
	actor.transition(FighterState.Id.HITSTUN)
	actor.stun_ticks = 5
	actor.hit_duration = 5
	sim.step([CombatInput.new(CombatInput.STRONG, CombatInput.PUNCH), CombatInput.new()])
	s.neutral(sim, 7)
	s.check(actor.move_id == "punch:2", "Soco forte no buffer não vira médio após hitstun")
