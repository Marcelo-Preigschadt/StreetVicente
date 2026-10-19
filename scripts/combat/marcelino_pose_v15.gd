class_name MarcelinoPoseV15
extends RefCounted
## Exposure follows the new drawings and the simulation's ten-tick wave cadence.


static func select(f: FighterModel) -> Dictionary:
	if f.state != FighterState.Id.ATTACK:
		return {}
	var move := f.current_move()
	var name := str(move.legacy.name)
	if name == "punch":
		return {
			"key": "punch",
			"index": FighterPose.move_key(f.move_tick, move, [0, 1], [2, 3], [4, 5, 6, 7])
		}
	if name != "super":
		return {}
	if move.phase(f.move_tick) == "ACTIVE":
		var age := f.move_tick - move.startup * 2
		# Five releases, each followed by a visible recoil before the next wave.
		return {"key": "super", "index": (3 if age % 10 < 4 else 4) if age < 50 else 5}
	return {
		"key": "super", "index": FighterPose.move_key(f.move_tick, move, [0, 1, 2], [3], [6, 7])
	}
