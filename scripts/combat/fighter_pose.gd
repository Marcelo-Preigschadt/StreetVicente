class_name FighterPose
extends RefCounted
## Shared deterministic exposure schedule for drawing and authored collision data.


static func select(f: FighterModel) -> Dictionary:
	if RollMotion.active(f):
		return RollMotion.pose(f)
	if f.character.id == "luciana":
		var mma := LucianaPoseV18.select(f)
		if not mma.is_empty():
			return mma
	if f.character.id == "tais":
		var savate := TaisPoseV17.select(f)
		if not savate.is_empty():
			return savate
	if f.character.id == "marcos":
		var judo := MarcosPoseV16.select(f)
		if not judo.is_empty():
			return judo
	if f.character.id == "gelton":
		var capoeira := GeltonPoseV13.select(f)
		if not capoeira.is_empty():
			return capoeira
	if f.character.id == "marcelino":
		var kinetic := MarcelinoPoseV15.select(f)
		if not kinetic.is_empty():
			return kinetic
	var sheet := "states"
	var index := 0
	match f.state:
		FighterState.Id.IDLE:
			index = [0, 0, 1, 0][(f.state_tick / 60) % 4]
		FighterState.Id.WALK:
			sheet = "walk"
			index = posmod(int(f.walk_distance * 8 / (160 * FighterModel.SCALE)), 8)
			if f.input.axis_x() == -f.facing:
				index = 7 - index
		FighterState.Id.STEP_IN, FighterState.Id.STEP_BACK:
			sheet = "walk"
			index = int(f.state_tick * 8 / maxi(1, f.step_duration)) % 8
			if f.state == FighterState.Id.STEP_BACK:
				index = 7 - index
		FighterState.Id.CROUCH, FighterState.Id.PREJUMP:
			index = 4
		FighterState.Id.BLOCK:
			index = 5 if f.input.has(CombatInput.DOWN) else 3 if f.stun_ticks > 0 else 2
		FighterState.Id.JUMP:
			index = 6 if f.vy < -450 else 7 if f.vy < 500 else 8
		FighterState.Id.LANDING:
			index = 9
		FighterState.Id.HITSTUN:
			var progress := f.hit_duration - f.stun_ticks
			index = (
				(11 if f.hit_region == "head" else 10)
				if progress * 3 < maxi(1, f.hit_duration)
				else 12
			)
		FighterState.Id.DIZZY:
			index = 13
		FighterState.Id.VICTORY:
			index = 15
		FighterState.Id.KNOCKDOWN, FighterState.Id.KO:
			index = 14
		FighterState.Id.WAKEUP:
			index = 14 if f.state_tick < 10 else 9 if f.state_tick < 24 else 4
		FighterState.Id.ATTACK:
			var move := f.current_move()
			var name: String = move.legacy.name
			var start_keys: Array = [0, 1, 2]
			var active_keys: Array = [3, 4]
			var recovery_keys: Array = [5, 6, 7]
			sheet = "punch"
			if name == "airKick":
				sheet = "air"
				start_keys = [0, 1, 2]
				active_keys = [3, 4]
				recovery_keys = [5, 6, 7]
			elif name == "airPunch":
				sheet = "air_punch"
			elif name == "kick":
				sheet = "combat"
			elif name == "crouchPunch":
				sheet = "low"
				start_keys = [0, 1]
				active_keys = [2]
				recovery_keys = [3, 0]
			elif name == "sweep":
				sheet = "low"
				start_keys = [4, 5]
				active_keys = [6]
				recovery_keys = [7, 4]
			elif (
				name == "uppercut"
				and (
					f.character.id
					in ["marcelo", "rafael", "adriano", "joao", "gustavo", "marcelino"]
				)
			):
				return uppercut(f)
			elif name == "uppercut":
				sheet = "combat"
				start_keys = [8, 9]
				active_keys = [9, 10]
				recovery_keys = [10, 11, 0]
			elif name == "special" and f.character.id == "joao":
				sheet = "punch"  # H remains Super Soco; Q owns the body roll.
			elif name in ["special", "super", "drone"]:
				sheet = "combat"
				start_keys = [12, 13]
				active_keys = [14]
				recovery_keys = [14, 15, 0]
			index = move_key(f.move_tick, move, start_keys, active_keys, recovery_keys)
	return {"key": sheet, "index": index}


static func uppercut(f: FighterModel) -> Dictionary:
	# Grounded compression, driving strike, rise, apex, fall, then landing.
	# Never show planted boots during the physical ascent or crouching midair.
	var phase := f.current_move().phase(f.move_tick)
	if phase == "STARTUP":
		return {"key": "combat", "index": 8}
	if not f.move_motion_started:
		return {"key": "combat", "index": 9}
	if not f.grounded():
		if phase == "ACTIVE" or f.vy < -450:
			return {"key": "combat", "index": 10}
		return {"key": "states", "index": 7 if f.vy < 500 else 8}
	return {"key": "combat", "index": 11}


static func move_key(
	tick: int, move: MoveData, startup: Array, active: Array, recovery: Array
) -> int:
	var keys: Array
	var offset: int
	var duration: int
	if tick < move.startup * 2:
		keys = startup
		offset = tick
		duration = move.startup * 2
	elif tick < (move.startup + move.active) * 2:
		keys = active
		offset = tick - move.startup * 2
		duration = move.active * 2
	else:
		keys = recovery
		offset = tick - (move.startup + move.active) * 2
		duration = move.recovery * 2
	return int(keys[clampi(int(offset * keys.size() / maxi(1, duration)), 0, keys.size() - 1)])
