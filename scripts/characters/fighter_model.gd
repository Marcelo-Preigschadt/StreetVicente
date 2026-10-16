# gdlint: disable=max-returns
# Explicit early exits keep mutually exclusive combat states isolated.
class_name FighterModel
extends RefCounted
## Estado serializável, ponto fixo 1/256 px, velocidade em unidades por tick.
## Não usa delta variável, física de nós, relógio, RNG global ou animação como autoridade.
const SCALE := 256
const FLOOR_Y := 590 * SCALE
const GRAVITY := 64  # 3600 px/s², integrado a 120 Hz.
const JUMP_SPEED := -2560  # -1200 px/s.
var ground_y: int = FLOOR_Y
var walk_distance: int = 0
var meter: int = 0
var combo: int = 0
var combo_ticks: int = 0
var stun_gauge: int = 0
var dizzy_pending: int = 0
var knockdown_pending: bool = false
var invincible_ticks: int = 0
var has_contact: bool = false
var emitted_waves: int = 0
var move_motion_started: bool = false
var jump_vx: int = 0
var air_normal_used: bool = false
var push_remaining: int = 0
var push_ticks: int = 0
var character: CharacterData
var slot: int
var x: int
var y: int = FLOOR_Y
var vx: int = 0
var vy: int = 0
var facing: int = 1
var health: int
var state: FighterState.Id = FighterState.Id.IDLE
var state_tick: int = 0
var stun_ticks: int = 0
var move_id: String = ""
var move_tick: int = 0
var hit_targets: Array = []
var input := CombatInput.new()
var buffer := CommandBuffer.new()


func _init(data: CharacterData, player_slot: int, spawn_x: int) -> void:
	character = data
	slot = player_slot
	x = spawn_x * SCALE
	facing = 1 if slot == 0 else -1
	health = data.max_health
	if not data.legacy.is_empty():
		ground_y = 625 * SCALE
	y = ground_y


func grounded() -> bool:
	return y >= ground_y


func transition(next: FighterState.Id) -> void:
	if state != next:
		state = next
		state_tick = 0


func current_move() -> MoveData:
	return character.move_for(move_id)


func record_input(value: CombatInput, tick: int) -> void:
	input = value
	buffer.record(value, tick)


func begin_tick(opponent_x: int) -> void:
	invincible_ticks = maxi(0, invincible_ticks - 1)
	if push_ticks > 0:
		@warning_ignore("integer_division")
		var displacement: int = push_remaining / push_ticks
		x += displacement
		push_remaining -= displacement
		push_ticks -= 1
	if state == FighterState.Id.PREJUMP:
		if state_tick < 6:
			return
		vy = -3072  # -1440 px/s.
		vx = jump_vx
		air_normal_used = false
		transition(FighterState.Id.JUMP)
		x += vx
		_integrate_air()
		return
	if state == FighterState.Id.LANDING:
		if state_tick < 8:
			return
		transition(FighterState.Id.IDLE)
	combo_ticks = maxi(0, combo_ticks - 1)
	if combo_ticks == 0:
		combo = 0
	if state in [FighterState.Id.KNOCKDOWN, FighterState.Id.WAKEUP, FighterState.Id.DIZZY]:
		_integrate_air()
		if (
			state_tick
			>= (
				84
				if state == FighterState.Id.KNOCKDOWN
				else 36 if state == FighterState.Id.WAKEUP else maxi(120, dizzy_pending)
			)
		):
			if state == FighterState.Id.KNOCKDOWN:
				transition(FighterState.Id.WAKEUP)
				invincible_ticks = 40
			else:
				dizzy_pending = 0
				stun_gauge = 0
				transition(FighterState.Id.IDLE)
		return
	if state == FighterState.Id.KO:
		vx = 0
		_integrate_air()
		return
	if stun_ticks > 0:
		stun_ticks -= 1
		vx = 0
		_integrate_air()
		return
	if state in [FighterState.Id.HITSTUN, FighterState.Id.BLOCK]:
		if knockdown_pending:
			knockdown_pending = false
			transition(FighterState.Id.KNOCKDOWN)
			return
		if dizzy_pending > 0:
			transition(FighterState.Id.DIZZY)
			return
		transition(FighterState.Id.IDLE if grounded() else FighterState.Id.JUMP)
	if state == FighterState.Id.ATTACK:
		_attack_motion()
		if (
			not character.legacy.is_empty()
			and has_contact
			and current_move().legacy.get("cancellable", false)
		):
			if _legacy_command(true):
				x += vx
				_integrate_air()
				return
		if move_tick < current_move().total_ticks():
			x += vx
			_integrate_air()
			return
		move_id = ""
		transition(FighterState.Id.IDLE if grounded() else FighterState.Id.JUMP)
	if FighterState.can_turn(state, grounded()) and x != opponent_x:
		facing = 1 if opponent_x > x else -1
	if not FighterState.actionable(state):
		return
	if not character.legacy.is_empty() and _legacy_command(false):
		pass
	elif character.legacy.is_empty() and buffer.consume(CombatInput.KICK):
		_start_move(
			(
				character.air_kick
				if not grounded()
				else (character.sweep if input.has(CombatInput.DOWN) else character.kick)
			)
		)
	elif character.legacy.is_empty() and grounded() and buffer.consume(CombatInput.PUNCH):
		_start_move(character.jab)
	elif grounded() and (buffer.consume(CombatInput.UP) or buffer.consume(CombatInput.JUMP)):
		if character.legacy.is_empty():
			vy = JUMP_SPEED
			vx = input.axis_x() * _move_speed()
			transition(FighterState.Id.JUMP)
		else:
			jump_vx = input.axis_x() * roundi(float(character.legacy.jumpSpeed) * SCALE / 120.0)
			vx = 0
			transition(FighterState.Id.PREJUMP)
	elif grounded():
		vx = input.axis_x() * (_move_speed())
		if input.has(CombatInput.GUARD):
			vx = 0
			transition(FighterState.Id.BLOCK)
		elif input.has(CombatInput.DOWN):
			vx = 0
			transition(FighterState.Id.CROUCH)
		else:
			transition(FighterState.Id.WALK if vx != 0 else FighterState.Id.IDLE)
	x += vx
	_integrate_air()


func _integrate_air() -> void:
	if not grounded() or vy < 0:
		vy += GRAVITY if character.legacy.is_empty() else 77  # 4320 px/s², arredondado.
		y += vy
		if y >= ground_y:
			y = ground_y
			vy = 0
			vx = 0
			air_normal_used = false
			buffer.discard(CombatInput.PUNCH | CombatInput.KICK)
			if state == FighterState.Id.ATTACK and not character.legacy.is_empty():
				if current_move().airborne:
					hit_targets.clear()
			if state == FighterState.Id.JUMP:
				transition(
					FighterState.Id.IDLE if character.legacy.is_empty() else FighterState.Id.LANDING
				)
			elif state == FighterState.Id.ATTACK and not character.legacy.is_empty():
				if str(current_move().legacy.name).begins_with("air"):
					move_id = ""
					transition(FighterState.Id.LANDING)


func _start_move(move: MoveData) -> void:
	if not grounded() and move.airborne:
		air_normal_used = true
	move_id = move.id
	move_tick = 0
	hit_targets.clear()
	has_contact = false
	emitted_waves = 0
	move_motion_started = false
	if not move.legacy.is_empty():
		meter -= int(move.legacy.get("cost", 0))
		invincible_ticks = int(round(float(move.legacy.get("invincibility", 0)) * 120.0))
	if grounded():
		vx = 0
	transition(FighterState.Id.ATTACK)


func end_tick() -> void:
	state_tick += 1
	if state == FighterState.Id.ATTACK:
		move_tick += 1


func hurtboxes() -> Array[Rect2i]:
	if (
		state in [FighterState.Id.KO, FighterState.Id.KNOCKDOWN, FighterState.Id.WAKEUP]
		or invincible_ticks > 0
	):
		return []
	if not character.legacy.is_empty():
		var result: Array[Rect2i] = []
		var profile := CombatGeometry.frame(self)
		for b in profile.get("hurt", character.pose_frame(self).hurt):
			result.append(
				BoxMath.world_rect(Rect2i(int(b[0]), int(b[1]), int(b[2]), int(b[3])), x, y, facing)
			)
		return result
	var low := grounded() and input.has(CombatInput.DOWN) and state != FighterState.Id.ATTACK
	var boxes: Array[Rect2i] = []
	# Cabeça, tronco, pernas separados; perfis por quadro podem substituir este protótipo.
	for rect in (
		[Rect2i(-22, -112, 44, 36), Rect2i(-30, -78, 60, 42), Rect2i(-36, -38, 72, 38)]
		if low
		else [Rect2i(-22, -192, 44, 42), Rect2i(-28, -150, 56, 84), Rect2i(-34, -66, 68, 66)]
	):
		boxes.append(BoxMath.world_rect(rect, x, y, facing))
	return boxes


func attack_boxes() -> Array[Rect2i]:
	var result: Array[Rect2i] = []
	if state != FighterState.Id.ATTACK:
		return result
	var registered = CombatGeometry.attack(self)
	if registered != null:
		return registered
	if not current_move().hitboxes.is_empty():
		for box in current_move().hitboxes:
			if box.active(move_tick):
				result.append(BoxMath.world_rect(box.rect, x, y, facing))
		return result
	if not current_move().legacy.is_empty():
		var move := current_move()
		if move.legacy.get("level", "") == "throw" and move.phase(move_tick) == "ACTIVE":
			var reach := int(move.legacy.get("range", 135))
			result.append(BoxMath.world_rect(Rect2i(0, -260, reach, 260), x, y, facing))
			return result
		var b = character.pose_frame(self).get("hit")
		if b is Array:
			result.append(
				BoxMath.world_rect(Rect2i(int(b[0]), int(b[1]), int(b[2]), int(b[3])), x, y, facing)
			)
		return result
	for box in current_move().hitboxes:
		if box.active(move_tick):
			result.append(BoxMath.world_rect(box.rect, x, y, facing))
	return result


func blocking(level: MoveData.Level) -> bool:
	if not grounded() or stun_ticks > 0 and state != FighterState.Id.BLOCK:
		return false
	if (
		state
		in [
			FighterState.Id.ATTACK,
			FighterState.Id.KO,
			FighterState.Id.KNOCKDOWN,
			FighterState.Id.WAKEUP,
			FighterState.Id.DIZZY,
			FighterState.Id.PREJUMP,
			FighterState.Id.LANDING
		]
	):
		return false
	var back := input.axis_x() == -facing
	if not (back or input.has(CombatInput.GUARD)):
		return false
	if level == MoveData.Level.LOW:
		return input.has(CombatInput.DOWN)
	if level == MoveData.Level.OVERHEAD:
		return not input.has(CombatInput.DOWN)
	return true


func receive_hit(move: MoveData, direction: int, guarded: bool) -> void:
	move_id = ""
	vx = 0
	# Keep the defender at the contact point during hitstop. Recoil resumes with
	# simulation ticks and is serialized, instead of teleporting before the flash.
	push_remaining = direction * move.push_pixels * SCALE
	push_ticks = 12 if not guarded else 8
	if guarded:
		stun_ticks = move.blockstun * 2
		if not move.legacy.is_empty():
			health = maxi(1, health - roundi(move.damage * float(move.legacy.get("chip", 0))))
		transition(FighterState.Id.BLOCK)
	else:
		health = maxi(0, health - move.damage)
		meter = mini(100, meter + 4)
		stun_gauge += (move.damage >> 1) + 12
		if stun_gauge >= 220:
			dizzy_pending = 180
		if not move.legacy.is_empty():
			dizzy_pending = maxi(
				dizzy_pending, roundi(float(move.legacy.get("dizzyDuration", 0)) * 120.0)
			)
			knockdown_pending = move.legacy.get("knockdown", false)
			if move.legacy.has("launch"):
				vy = -roundi(float(move.legacy.launch) * SCALE / 120.0)
		stun_ticks = move.hitstun * 2
		transition(FighterState.Id.KO if health == 0 else FighterState.Id.HITSTUN)


func snapshot() -> Dictionary:
	return {
		"ground_y": ground_y,
		"walk_distance": walk_distance,
		"meter": meter,
		"combo": combo,
		"combo_ticks": combo_ticks,
		"stun_gauge": stun_gauge,
		"dizzy_pending": dizzy_pending,
		"knockdown_pending": knockdown_pending,
		"invincible_ticks": invincible_ticks,
		"has_contact": has_contact,
		"emitted_waves": emitted_waves,
		"move_motion_started": move_motion_started,
		"jump_vx": jump_vx,
		"air_normal_used": air_normal_used,
		"push_remaining": push_remaining,
		"push_ticks": push_ticks,
		"slot": slot,
		"character": character.id,
		"x": x,
		"y": y,
		"vx": vx,
		"vy": vy,
		"facing": facing,
		"health": health,
		"state": int(state),
		"state_tick": state_tick,
		"stun_ticks": stun_ticks,
		"move_id": move_id,
		"move_tick": move_tick,
		"hit_targets": hit_targets.duplicate(),
		"held": input.held,
		"pressed": input.pressed,
		"buffer": buffer.snapshot()
	}


func restore(data: Dictionary) -> void:
	assert(data.character == character.id and data.slot == slot)
	for field in [
		"ground_y",
		"walk_distance",
		"meter",
		"combo",
		"combo_ticks",
		"stun_gauge",
		"dizzy_pending",
		"knockdown_pending",
		"invincible_ticks",
		"has_contact",
		"emitted_waves",
		"move_motion_started",
		"jump_vx",
		"air_normal_used",
		"push_remaining",
		"push_ticks"
	]:
		set(field, data[field])
	x = data.x
	y = data.y
	vx = data.vx
	vy = data.vy
	facing = data.facing
	health = data.health
	state = data.state
	state_tick = data.state_tick
	stun_ticks = data.stun_ticks
	move_id = data.move_id
	move_tick = data.move_tick
	hit_targets = data.hit_targets.duplicate()
	input = CombatInput.new(data.held, data.pressed)
	buffer.restore(data.buffer)


func _move_speed() -> int:
	if character.speed_units == 0:
		return character.speed_pixels_per_tick * SCALE
	return character.back_speed_units if input.axis_x() == -facing else character.speed_units


func _legacy_command(cancel: bool) -> bool:
	var strength := 2 if input.has(CombatInput.STRONG) else 0 if input.has(CombatInput.LIGHT) else 1
	var choices := [
		[CombatInput.SUPER, "super"],
		[CombatInput.SPECIAL, "special"],
		[CombatInput.UPPERCUT, "uppercut"],
		[CombatInput.THROW, "throw"],
		[CombatInput.DRONE, "drone"],
		[CombatInput.KICK, "kick"],
		[CombatInput.PUNCH, "punch"]
	]
	for pair in choices:
		var name: String = pair[1]
		var resolved := name
		if name in ["punch", "kick"]:
			resolved = (
				("airPunch" if name == "punch" else "airKick")
				if not grounded()
				else (
					("crouchPunch" if name == "punch" else "sweep")
					if input.has(CombatInput.DOWN)
					else name
				)
			)
		if not grounded() and air_normal_used and name in ["punch", "kick"]:
			continue
		if not grounded() and name in ["uppercut", "throw"]:
			continue
		var move := character.get_move(resolved, strength)
		if move == null:
			continue
		if int(move.legacy.get("cost", 0)) > meter:
			continue
		if (
			cancel
			and name in ["punch", "kick"]
			and current_move().legacy.name == resolved
			and int(current_move().legacy.strength) >= strength
		):
			continue
		if buffer.consume(pair[0]):
			_start_move(move)
			return true
	return false


func _attack_motion() -> void:
	var move := current_move()
	if move.legacy.is_empty():
		return
	var m := move.legacy
	var advance := int(m.get("advance", 0)) * SCALE
	if grounded() and move_tick < move.startup * 2:
		@warning_ignore("integer_division")
		var before: int = advance * move_tick / (move.startup * 2)
		@warning_ignore("integer_division")
		var after: int = advance * (move_tick + 1) / (move.startup * 2)
		vx = facing * (after - before)
	elif grounded():
		vx = 0
	if m.name == "uppercut" and move_tick >= move.startup * 2 and not move_motion_started:
		move_motion_started = true
		if not m.get("grounded", false):
			vy = roundi(float(m.get("jumpVelocity", -1080)) * SCALE / 120.0)
			vx = facing * roundi(float(m.get("travelSpeed", 135)) * SCALE / 120.0)
