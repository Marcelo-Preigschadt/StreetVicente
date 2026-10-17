class_name PresentationV11Tests
extends RefCounted
## Regressions: Q/H identity, authored collision, real status and event deduplication.


static func run(s: SceneTree) -> void:
	var joao := LegacyRoster.get_character("joao")
	s.check(joao.legacy.powers.special == "Super Soco", "H preserva Super Soco")
	s.check(joao.legacy.powers.super == "Rolamento Selvagem", "Q identifica o rolinho")
	for strength in 3:
		s.check(
			joao.get_move("super", strength).legacy.get("body_roll", false), "Q usa corpo rolando"
		)
		for name in ["special", "uppercut"]:
			s.check(
				not joao.get_move(name, strength).legacy.get("body_roll", false),
				"H/U não viram rolinho"
			)
	for command in [CombatInput.SPECIAL, CombatInput.SUPER]:
		var sim := FightSimulation.new(joao, LegacyRoster.get_character("rafael"))
		sim.fighters[0].meter = 100
		sim.step([CombatInput.new(0, command), CombatInput.new()])
		var rolling: bool = command == CombatInput.SUPER
		s.check(
			RollMotion.active(sim.fighters[0]) == rolling, "Comando real H/Q entra no golpe correto"
		)
	var f := FighterModel.new(LegacyRoster.get_character("gustavo"), 0, 450)
	var standing := CharacterArt.frame(f)
	var height: float = standing.frame.rect[3] * standing.frame.scale
	f.state = FighterState.Id.WALK
	for i in 8:
		f.walk_distance = i * 20 * 256
		var art := CharacterArt.frame(f)
		s.check(
			absf(art.frame.rect[3] * art.frame.scale - height) < 9,
			"Gustavo não muda de tamanho ao andar"
		)
	for state in FighterState.Id.values():
		if state == FighterState.Id.ATTACK:
			continue
		f.state = state
		s.check(
			"arcade-v11" in CharacterArt.frame(f).sheet.image, "Gustavo não volta ao corpo antigo"
		)
	for name in [
		"punch",
		"kick",
		"crouchPunch",
		"sweep",
		"airPunch",
		"airKick",
		"special",
		"uppercut",
		"super"
	]:
		f.state = FighterState.Id.ATTACK
		f.move_id = name + ":1"
		for tick in f.current_move().total_ticks():
			f.move_tick = tick
			s.check(
				"arcade-v11" in CharacterArt.frame(f).sheet.image,
				"Sequência completa nova: Gustavo/" + name
			)
			if name not in ["special", "super"]:
				s.check(
					f.attack_boxes().is_empty() == (f.current_move().phase(tick) != "ACTIVE"),
					"Colisão acompanha active: Gustavo/" + name
				)
	var world := FightSimulation.new(f.character, joao)
	f = world.fighters[0]
	f.transition(FighterState.Id.HITSTUN)
	f.stun_ticks = 30
	s.check(FighterStatusV11.dizzy_actors(world).is_empty(), "Hitstun comum não recebe passarinhos")
	f.transition(FighterState.Id.DIZZY)
	f.dizzy_ticks = 80
	s.check(FighterStatusV11.dizzy_actors(world) == [f], "Indicador segue tontura real")
	s.check(FighterStatusV11.head(f).y < 340, "Órbita fica acima da cabeça, não no torso")
	f.dizzy_ticks = 0
	s.check(FighterStatusV11.dizzy_actors(world).is_empty(), "Indicador desaparece ao recuperar")
	var impact := CombatImpact.new()
	for entry in [
		["hit", "punch:0", "", "light"],
		["hit", "kick:2", "", "heavy"],
		["block", "punch:0", "", "block"],
		["hit", "special:1", "projectile", "power"]
	]:
		var event := {
			"id": entry[3],
			"kind": entry[0],
			"move": entry[1],
			"power_kind": entry[2],
			"x": 400 * 256,
			"y": 420 * 256,
			"character": "gustavo"
		}
		impact.consume([event, event], world)
		s.check(impact.particles.back().clip == entry[3], "Efeito corresponde ao contato")
	s.check(impact.particles.size() == 4, "Replay de evento não duplica impacto")
	impact._process(1)
	s.check(
		impact.particles.is_empty() and impact.shake == 0, "Impactos expiram sem tremor residual"
	)
	impact.free()
