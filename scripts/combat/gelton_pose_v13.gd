class_name GeltonPoseV13
extends RefCounted
## Authored capoeira exposures. Inversions are drawings, never a rotated cutout.


static func select(f: FighterModel) -> Dictionary:
	if f.state == FighterState.Id.IDLE:
		# A measured ginga cycle: 1.6 seconds, rather than a frantic two-cel bounce.
		return {
			"key": "walk",
			"index":
			posmod(int(f.walk_distance * 8 / (210 * FighterModel.SCALE)) + f.state_tick / 24, 8)
		}
	if f.state == FighterState.Id.WALK:
		var index := posmod(int(f.walk_distance * 8 / (210 * FighterModel.SCALE)), 8)
		if f.input.axis_x() == -f.facing:
			index = 7 - index
		return {"key": "walk", "index": index}
	if f.state != FighterState.Id.ATTACK:
		return {}
	var move := f.current_move()
	match str(move.legacy.name):
		"special":
			return {
				"key": "cast",
				"index": FighterPose.move_key(f.move_tick, move, [0, 1, 2], [3, 4], [5, 6, 7])
			}
		"super":
			return {
				"key": "wheel",
				"index":
				FighterPose.move_key(f.move_tick, move, [0, 1, 2], [3, 4, 3, 4, 3], [5, 6, 7])
			}
		"uppercut":
			var phase := move.phase(f.move_tick)
			if phase == "STARTUP":
				return {"key": "rise", "index": 0 if f.move_tick < move.startup else 1}
			if not f.move_motion_started:
				return {"key": "rise", "index": 2}
			if not f.grounded():
				return {
					"key": "rise",
					"index":
					(
						clampi(3 + (f.move_tick - move.startup * 2) / 9, 3, 5)
						if phase == "ACTIVE"
						else 6
					)
				}
			return {"key": "rise", "index": 7}
	return {}
