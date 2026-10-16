class_name Pilot3DTests
extends RefCounted
## Pose correctness and simulation/presentation isolation, not implementation mirrors.


static func run(suite: SceneTree) -> void:
	var f := FighterModel.new(LegacyRoster.get_character("marcelo"), 0, 450)
	var rig := MarceloModel3D.new()
	suite.root.add_child(rig)
	suite.check(rig.skeleton.get_bone_count() == 18, "Piloto usa esqueleto 3D completo")
	var torso: MeshInstance3D = rig.skeleton.get_child(0)
	suite.check(torso.mesh.get_aabb().size.z > 0.3, "Tronco tem volume real em profundidade")
	suite.check(
		MarceloModel3D.FACE_PATH == f.character.legacy.portrait,
		"Cabeça usa o mesmo rosto aprovado da seleção"
	)
	for state in FighterState.NAMES.size():
		f.state = state
		f.move_id = "punch:0"
		for tick in [0, 6, 18, 40]:
			f.state_tick = tick
			var pose := Fighter3DPose.sample(f)
			suite.check(
				Vector3(pose.head).distance_to(pose.hip) < 1.5,
				"Queda/levantamento preservam comprimento do tronco"
			)
			rig.apply_pose(pose)
			rig.skeleton.force_update_all_bone_transforms()
			if (
				f.state
				not in [FighterState.Id.KNOCKDOWN, FighterState.Id.KO, FighterState.Id.WAKEUP]
			):
				var hand := rig.skeleton.get_bone_global_pose(rig.bones.near_hand).origin
				suite.check(
					hand.distance_to(pose.near_hand) < 0.001,
					"Bind pose mantém mão no alvo da animação"
				)
			for bone in rig.skeleton.get_bone_count():
				suite.check(
					rig.skeleton.get_bone_pose(bone).is_finite(),
					"Transformação finita em todos os estados"
				)
	for move_id in f.character.moves:
		f.state = FighterState.Id.ATTACK
		f.move_id = move_id
		for tick in f.current_move().total_ticks():
			f.move_tick = tick
			var pose := Fighter3DPose.sample(f)
			for key in ["head", "near_hand", "far_hand", "near_foot", "far_foot"]:
				suite.check(
					Vector3(pose[key]).is_finite(),
					"IK finito em startup, active e recovery: " + move_id
				)
			var move := f.current_move()
			if move.legacy.name == "airKick":
				f.y = f.ground_y - 80 * 256
				pose = Fighter3DPose.sample(f)
				suite.check(
					pose.near_foot.y > 0.1 and pose.far_foot.y > 0.1, "Voadora não planta pés no ar"
				)
		f.y = f.ground_y
	var sim := FightSimulation.new(f.character, LegacyRoster.get_character("rafael"))
	for i in 100:
		suite.neutral(sim)
		var before := sim.state_hash()
		for subframe in [0.0, 0.33, 0.75]:
			rig.apply_pose(Fighter3DPose.sample(sim.fighters[0], subframe))
		suite.check(sim.state_hash() == before, "Amostragem do rig não altera estado autoritativo")
	var tip := Fighter3DPose.joint(Vector3.ZERO, Vector3(2, 0, 0), 0.8, 0.8, Vector3.DOWN)
	suite.check(tip.is_finite(), "IK satura alcance inalcançável sem NaN")
	rig.queue_free()
