class_name RosterPowersV20Tests
extends RefCounted
## End-to-end power contacts, original kits and isolated exclusions.


static func run(s: SceneTree) -> void:
	for id in PowerFXV20.IDS:
		var c := LegacyRoster.get_character(id)
		var data := PowerFXV20.load_data(id)
		for clip in data.clips.values():
			for index in clip:
				var frame: Dictionary = data.frames[int(index)]
				s.check(ResourceLoader.exists(frame.get("image", data.get("image", ""))), id + " carrega todos os cels VFX")
		for name in ["special", "uppercut", "super"]:
			for facing in [-1, 1]:
				var sim := FightSimulation.new(c, LegacyRoster.get_character("rafael"))
				var f: FighterModel = sim.fighters[0]
				f.x = 640 * 256
				f.facing = facing
				f.meter = 100
				sim.fighters[1].x = f.x + facing * 180 * 256
				f._start_move(c.get_move(name, 1))
				if name == "super":
					s.check(f.meter == 0, id + " gasta 100 de barra no início do super")
				for tick in 440:
					sim.step([CombatInput.new(), CombatInput.new()])
				s.check(sim.fighters[1].health < 1000, id + "/" + name + " acerta nos dois lados")
				s.check(f.grounded(), id + "/" + name + " termina no chão")
				s.check(sim.projectiles.is_empty(), id + "/" + name + " encerra entidades")
		# VFX remains finite and duplicate events cannot restart an impact.
		var view := PowerView.new()
		var event := {"id": id, "kind": "hit", "character": id,
			"move": "super:1", "power_kind": "power", "x": 100, "y": 100}
		view.consume([event, event])
		s.check(view.bursts.size() == 1, id + " deduplica explosão")
		s.check(view.bursts[0].max == .85, id + " dá tempo de ler impacto do super")
		view._process(1)
		s.check(view.bursts.is_empty(), id + " dissipa explosão")
		view.free()
	for id in ["khauany", "dienes"]:
		s.check(id not in PowerFXV20.IDS, id + " permanece fora da revisão")
		var c := LegacyRoster.get_character(id)
		for key in ["special", "super"]:
			var original: Dictionary = c.legacy.moves[key + ":1"]
			s.check(c.get_move(key, 1).legacy.get("radius", 26) == original.get("radius", 26), id + " preserva alcance original")
