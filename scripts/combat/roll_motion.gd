class_name RollMotion
extends RefCounted
## João: startup → travel → three contact pulses → physical rebound → recovery.
## Target ID, direction, pulse counters and clock live in FighterModel snapshots.
const TRAVEL := 1
const SHOCK := 2
const REBOUND := 3
const RECOVER := 4
const MAX_TRAVEL := 144
const PULSE_TICKS := 9


static func active(f: FighterModel) -> bool:
	return (
		f.state == FighterState.Id.ATTACK
		and not f.move_id.is_empty()
		and f.current_move().legacy.get("body_roll", false)
	)


static func start(f: FighterModel) -> void:
	f.roll_phase = 0
	f.roll_tick = 0
	f.roll_hits = 0
	f.roll_target = -1
	f.roll_direction = f.facing


static func step(f: FighterModel) -> void:
	f.facing = f.roll_direction
	if f.roll_phase == 0:
		f.vx = 0
		f._integrate_air()
		if f.move_tick >= f.current_move().startup * 2:
			f.roll_phase = TRAVEL
			f.roll_tick = 0
			f.vy = 0
		return
	f.roll_tick += 1
	if f.roll_phase == TRAVEL:
		f.vx = (
			f.roll_direction
			* roundi((1000 + int(f.current_move().legacy.strength) * 100) * 256.0 / 120)
		)
		f.x += f.vx
		f.vy = 0
		if f.roll_tick >= MAX_TRAVEL:
			rebound(f, false)
	elif f.roll_phase == SHOCK:
		f.vx = 0
		f.vy = 0
		if f.roll_tick in [PULSE_TICKS, PULSE_TICKS * 2]:
			f.hit_targets.clear()
		if f.roll_tick > PULSE_TICKS * 2 + 2:
			rebound(f, false)
	elif f.roll_phase == REBOUND:
		f.x += f.vx
		f._integrate_air()
		if f.grounded():
			f.roll_phase = RECOVER
			f.roll_tick = 0
			f.vx = 0
	elif f.roll_phase == RECOVER:
		f._integrate_air()
		if f.roll_tick >= 22 and f.grounded():
			f.roll_phase = 0
			f.move_id = ""
			f.vx = 0
			f.transition(FighterState.Id.IDLE)


static func rebound(f: FighterModel, blocked: bool) -> void:
	f.roll_phase = REBOUND
	f.roll_tick = 0
	f.vx = -f.roll_direction * roundi((510.0 if blocked else 360.0) * 256 / 120)
	f.vy = roundi(-680.0 * 256 / 120)
	f.hit_targets.clear()


static func boxes(f: FighterModel) -> Array[Rect2i]:
	var result: Array[Rect2i] = []
	if (
		f.roll_phase == TRAVEL
		or f.roll_phase == SHOCK and f.roll_tick in [PULSE_TICKS, PULSE_TICKS * 2]
	):
		var rect := Rect2i(-20, -235, 145, 205)
		if f.roll_phase == SHOCK:
			# Contact arcs bridge to the already struck torso, including recoil cels.
			rect = Rect2i(-20, -285, 245, 270)
		result.append(BoxMath.world_rect(rect, f.x, f.y, f.facing))
	return result


static func can_contact(f: FighterModel, target: FighterModel) -> bool:
	if f.roll_phase == SHOCK:
		return target.slot == f.roll_target
	# A guard fist must not stop the body roll far away from the opponent's torso.
	return absi(target.x - f.x) <= 180 * FighterModel.SCALE


static func contact_move(f: FighterModel) -> MoveData:
	var base := f.current_move()
	var move := base.duplicate(true) as MoveData
	move.legacy = base.legacy.duplicate()
	move.legacy.erase("launch")
	move.damage = maxi(1, roundi(base.damage * (0.5 if f.roll_hits == 2 else 0.25)))
	move.hitstun = 25
	move.hitstop = 4 if f.roll_hits == 2 else 3
	move.push_pixels = 16 if f.roll_hits == 2 else 0
	move.legacy.knockdown = f.roll_hits == 2
	move.legacy.stun_points = 8
	move.legacy.meter = 3
	if f.roll_hits == 2:
		move.legacy.launch = 360
	return move


static func contact(f: FighterModel, target: FighterModel, blocked: bool) -> void:
	if not active(f):
		return
	if blocked:
		rebound(f, true)
		return
	f.roll_hits += 1
	f.roll_target = target.slot
	if f.roll_hits == 1:
		f.roll_phase = SHOCK
		f.roll_tick = 0
		f.vx = 0
		f.vy = 0
	elif f.roll_hits >= 3:
		rebound(f, false)


static func pose(f: FighterModel) -> Dictionary:
	var index := 0
	if f.roll_phase == 0:
		index = 0 if f.move_tick < f.current_move().startup else 1
	elif f.roll_phase in [TRAVEL, SHOCK]:
		index = 2 + (f.move_tick / 4) % 4
	elif f.roll_phase == REBOUND:
		index = 2 + (f.move_tick / 6) % 4
	elif f.roll_phase == RECOVER:
		index = 6 if f.roll_tick < 12 else 7
	return {"key": "roll", "index": index}
