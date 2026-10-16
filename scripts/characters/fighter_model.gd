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
var custom_ticks: int = 0
var custom_moves: int = 0
var tap_direction: int = 0
var tap_ticks: int = 0
var step_cooldown: int = 0
var step_duration: int = 0
var step_distance: int = 0
var step_sign: int = 1
var step_cancel: int = 0
var ground_y: int = FLOOR_Y
var walk_distance: int = 0
var meter: int = 0
var combo: int = 0
var combo_ticks: int = 0
var stun_gauge: int = 0
var dizzy_pending: int = 0
# Todos os contadores abaixo participam do snapshot; apresentação não decide recuperação.
var dizzy_ticks: int = 0
var dizzy_protection: int = 0
var dizzy_escape_cooldown: int = 0
var stun_quiet: int = 0
var stun_decay_ticks: int = 0
var hit_duration: int = 0
var hit_region: String = "body"
var hit_crouched: bool = false
var last_attacker: int = -1
var knockdown_ground_ticks: int = 0
var quick_rise: bool = false
var chain: Array = []
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
	custom_ticks = maxi(0, custom_ticks - 1)
	tap_ticks = maxi(0, tap_ticks - 1)
	step_cooldown = maxi(0, step_cooldown - 1)
	invincible_ticks = maxi(0, invincible_ticks - 1)
	dizzy_protection = maxi(0, dizzy_protection - 1)
	dizzy_escape_cooldown = maxi(0, dizzy_escape_cooldown - 1)
	stun_quiet = maxi(0, stun_quiet - 1)
	if (
		stun_quiet == 0
		and stun_ticks == 0
		and dizzy_pending == 0
		and state != FighterState.Id.DIZZY
	):
		stun_decay_ticks += 1
		if stun_decay_ticks >= 6:
			stun_gauge = maxi(0, stun_gauge - 1)  # 20/s, independente de trocar Idle/Walk.
			stun_decay_ticks = 0
	else:
		stun_decay_ticks = 0
	combo_ticks = maxi(0, combo_ticks - 1)
	if combo_ticks == 0:
		combo = 0
		chain.clear()
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
	if state == FighterState.Id.DIZZY:
		_integrate_air()
		dizzy_ticks = maxi(0, dizzy_ticks - 1)
		if input.pressed != 0 and dizzy_escape_cooldown == 0:
			dizzy_ticks = maxi(0, dizzy_ticks - 7)
			dizzy_escape_cooldown = 11
		if dizzy_ticks == 0:
			_finish_dizzy()
			transition(FighterState.Id.IDLE if grounded() else FighterState.Id.JUMP)
		return
	if state in [FighterState.Id.KNOCKDOWN, FighterState.Id.WAKEUP]:
		_integrate_air()
		if state == FighterState.Id.KNOCKDOWN:
			if grounded():
				knockdown_ground_ticks += 1
				if knockdown_ground_ticks <= 16 and input.pressed != 0:
					quick_rise = true
				if knockdown_ground_ticks >= (14 if quick_rise else 84):
					transition(FighterState.Id.WAKEUP)
					invincible_ticks = 42 if quick_rise else 40
		elif state_tick >= (32 if quick_rise else 36):
			if dizzy_pending > 0:
				dizzy_ticks = dizzy_pending
				dizzy_pending = 0
				stun_gauge = 0
				transition(FighterState.Id.DIZZY)
			else:
				transition(FighterState.Id.IDLE)
		return
	if state == FighterState.Id.KO:
		vx = 0
		_integrate_air()
		return
	if state == FighterState.Id.BLOCK and stun_ticks > 0 and grounded() and meter >= 25:
		if buffer.consume(CombatInput.COUNTER):
			var counter := character.get_move("guardCounter", 1)
			if counter != null:
				stun_ticks = 0
				meter -= 25
				_start_move(counter)
				return
	if state in [FighterState.Id.STEP_IN, FighterState.Id.STEP_BACK]:
		if (
			state == FighterState.Id.STEP_IN
			and state_tick >= step_cancel
			and _legacy_command(false)
		):
			return
		if state_tick < step_duration:
			var before := _step_position(state_tick)
			x += step_sign * (_step_position(state_tick + 1) - before)
			return
		transition(FighterState.Id.IDLE)
	if stun_ticks > 0:
		stun_ticks -= 1
		vx = 0
		_integrate_air()
		return
	if state in [FighterState.Id.HITSTUN, FighterState.Id.BLOCK]:
		if knockdown_pending:
			knockdown_pending = false
			knockdown_ground_ticks = 0
			quick_rise = false
			transition(FighterState.Id.KNOCKDOWN)
			return
		if dizzy_pending > 0:
			dizzy_ticks = dizzy_pending
			dizzy_pending = 0
			stun_gauge = 0
			buffer = CommandBuffer.new()
			transition(FighterState.Id.DIZZY)
			return
		transition(FighterState.Id.IDLE if grounded() else FighterState.Id.JUMP)
	if state == FighterState.Id.ATTACK:
		_attack_motion()
		var custom_cancel: bool = (
			custom_ticks > 0
			and custom_moves < 8
			and grounded()
			and move_tick >= current_move().startup * 2 + 4
			and not current_move().legacy.get("knockdown", false)
		)
		# A short confirmed air chain. A whiff or a repeated normal cannot cancel.
		var air_chain: bool = (
			not grounded() and has_contact and current_move().legacy.get("name", "") == "airPunch"
		)
		if (
			not character.legacy.is_empty()
			and (
				(has_contact and current_move().legacy.get("cancellable", false))
				or custom_cancel
				or air_chain
			)
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
	if grounded() and not input.has(CombatInput.DOWN) and not input.has(CombatInput.GUARD):
		if custom_ticks == 0 and meter >= 50 and buffer.consume(CombatInput.CUSTOM):
			meter -= 50
			custom_ticks = 300
			custom_moves = 0
			chain.clear()
		elif custom_ticks == 0 and step_cooldown == 0 and _double_tap():
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
	if custom_ticks > 0:
		custom_moves += 1
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
	if not character.body_rects.is_empty():
		var body: Array[Rect2i] = []
		for rect in character.body_rects:
			body.append(BoxMath.world_rect(rect, x, y, facing))
		return body
	if not character.legacy.is_empty():
		var result: Array[Rect2i] = []
		var profile := CombatGeometry.frame(self)
		for b in profile.get("hurt", character.pose_frame(self).hurt):
			result.append(
				BoxMath.world_rect(
					CharacterMetrics.rect(
						character.id, Rect2i(int(b[0]), int(b[1]), int(b[2]), int(b[3]))
					),
					x,
					y,
					facing
				)
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
			result.append(
				BoxMath.world_rect(
					CharacterMetrics.rect(character.id, Rect2i(0, -260, reach, 260)), x, y, facing
				)
			)
			return result
		var b = character.pose_frame(self).get("hit")
		if b is Array:
			result.append(
				BoxMath.world_rect(
					CharacterMetrics.rect(
						character.id, Rect2i(int(b[0]), int(b[1]), int(b[2]), int(b[3]))
					),
					x,
					y,
					facing
				)
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
			FighterState.Id.LANDING,
			FighterState.Id.STEP_IN,
			FighterState.Id.STEP_BACK
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


func connect_hit(target: FighterModel, move: MoveData) -> String:
	# Hits separados por um intervalo acionável NÃO compõem um combo.
	var continued := (
		target.stun_ticks > 0
		and target.state == FighterState.Id.HITSTUN
		and target.last_attacker == slot
	)
	combo = combo + 1 if continued else 1
	if not continued:
		chain.clear()
	chain.append(move.id)
	if chain.size() > 12:
		chain.pop_front()
	combo_ticks = maxi(100, move.hitstun * 2 + 30)
	for pattern in character.legacy.get("combos", []):
		var steps: Array = pattern.steps
		if chain.size() >= steps.size() and chain.slice(chain.size() - steps.size()) == steps:
			return str(pattern.name)
	return ""


func scaled_damage(move: MoveData) -> int:
	# Original: -8% por acerto, piso 55%. Inteiros preservam replay.
	return maxi(1, int(move.damage * maxi(55, 100 - (combo - 1) * 8) / 100))


func _finish_dizzy() -> void:
	dizzy_ticks = 0
	dizzy_pending = 0
	stun_gauge = 0
	dizzy_protection = 480  # 4 s sem outra tontura, inclusive ao ser atingido nela.


func receive_hit(
	move: MoveData,
	direction: int,
	guarded: bool,
	attacker: int = -1,
	combo_size: int = 1,
	damage: int = -1,
	region: String = "body"
) -> void:
	custom_ticks = 0
	if state == FighterState.Id.DIZZY:
		_finish_dizzy()
	hit_crouched = grounded() and input.has(CombatInput.DOWN)
	hit_region = region
	last_attacker = attacker
	state_tick = 0  # Outro impacto reinicia a reação mesmo no mesmo estado.
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
		health = maxi(0, health - (move.damage if damage < 0 else damage))
		meter = mini(100, meter + 4)
		stun_quiet = 120
		if dizzy_protection == 0 and move.legacy.get("level", "") != "throw":
			stun_gauge = mini(100, stun_gauge + 18 + int(move.legacy.get("strength", 1)) * 9)
			if combo_size >= 3 and stun_gauge >= 65:
				dizzy_pending = 282
			var chemical := roundi(float(move.legacy.get("dizzyDuration", 0)) * 120.0)
			dizzy_pending = maxi(dizzy_pending, chemical)
		if not move.legacy.is_empty():
			knockdown_pending = move.legacy.get("knockdown", false)
			if move.legacy.has("launch"):
				vy = -roundi(float(move.legacy.launch) * SCALE / 120.0)
		stun_ticks = move.hitstun * 2
		hit_duration = stun_ticks
		transition(FighterState.Id.KO if health == 0 else FighterState.Id.HITSTUN)


func snapshot() -> Dictionary:
	return {
		"dizzy_ticks": dizzy_ticks,
		"dizzy_protection": dizzy_protection,
		"dizzy_escape_cooldown": dizzy_escape_cooldown,
		"stun_quiet": stun_quiet,
		"stun_decay_ticks": stun_decay_ticks,
		"hit_duration": hit_duration,
		"hit_region": hit_region,
		"hit_crouched": hit_crouched,
		"last_attacker": last_attacker,
		"knockdown_ground_ticks": knockdown_ground_ticks,
		"quick_rise": quick_rise,
		"chain": chain.duplicate(),
		"custom_ticks": custom_ticks,
		"custom_moves": custom_moves,
		"tap_direction": tap_direction,
		"tap_ticks": tap_ticks,
		"step_cooldown": step_cooldown,
		"step_duration": step_duration,
		"step_distance": step_distance,
		"step_sign": step_sign,
		"step_cancel": step_cancel,
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
	chain = data.get("chain", []).duplicate()
	for field in [
		"custom_ticks",
		"custom_moves",
		"tap_direction",
		"tap_ticks",
		"step_cooldown",
		"step_duration",
		"step_distance",
		"step_sign",
		"step_cancel",
		"dizzy_ticks",
		"dizzy_protection",
		"dizzy_escape_cooldown",
		"stun_quiet",
		"stun_decay_ticks",
		"hit_duration",
		"hit_region",
		"hit_crouched",
		"last_attacker",
		"knockdown_ground_ticks",
		"quick_rise",
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
		set(field, data.get(field, get(field)))
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
		if custom_ticks > 0 and (custom_moves >= 8 or name in ["throw", "super"]):
			continue
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
			var air_chain: bool = (
				cancel
				and has_contact
				and current_move().legacy.get("name", "") == "airPunch"
				and resolved == "airKick"
			)
			if not air_chain:
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
			and custom_ticks == 0
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
	var authored: Dictionary = FootworkProfile.get_profile(character.id).get("attackAdvance", {})
	var distances: Array = authored.get(str(m.name), [])
	var advance := (
		int(
			(
				distances[int(m.get("strength", 1))]
				if not distances.is_empty()
				else m.get("advance", 0)
			)
		)
		* SCALE
	)
	if grounded() and move_tick < move.startup * 2:
		@warning_ignore("integer_division")
		var before: int = advance * move_tick / (move.startup * 2)
		@warning_ignore("integer_division")
		var after: int = advance * (move_tick + 1) / (move.startup * 2)
		vx = facing * (after - before)
	elif grounded():
		vx = 0
	# Marcelo drives the fist for two design frames on the floor, then launches.
	# All timing is simulation-owned and therefore survives replay/hitstop.
	var launch_tick := move.startup * 2 + (4 if character.id == "marcelo" else 0)
	if m.name == "uppercut" and move_tick >= launch_tick and not move_motion_started:
		move_motion_started = true
		if not m.get("grounded", false):
			vy = roundi(float(m.get("jumpVelocity", -1080)) * SCALE / 120.0)
			vx = facing * roundi(float(m.get("travelSpeed", 135)) * SCALE / 120.0)


func _double_tap() -> bool:
	var direction := input.axis_x()
	if direction == 0 or (input.pressed & (CombatInput.LEFT | CombatInput.RIGHT)) == 0:
		return false
	var profile := FootworkProfile.get_profile(character.id)
	if profile.is_empty():
		return false
	if tap_direction != direction or tap_ticks == 0:
		tap_direction = direction
		tap_ticks = 26
		return false
	var forward := direction == facing
	var data: Dictionary = profile.advance if forward else profile.retreat
	step_duration = roundi(float(data.duration) * 120)
	step_distance = roundi(float(data.distance) * SCALE)
	step_sign = direction
	step_cancel = roundi(float(data.get("cancelAt", data.duration)) * 120)
	step_cooldown = step_duration + 12
	tap_ticks = 0
	vx = 0
	buffer.discard(CombatInput.LEFT | CombatInput.RIGHT)
	transition(FighterState.Id.STEP_IN if forward else FighterState.Id.STEP_BACK)
	x += step_sign * _step_position(1)
	return true


func _step_position(at: int) -> int:
	var t := clampi(at, 0, step_duration)
	@warning_ignore("integer_division")
	return (
		step_distance
		* t
		* t
		* (3 * step_duration - 2 * t)
		/ (step_duration * step_duration * step_duration)
	)
