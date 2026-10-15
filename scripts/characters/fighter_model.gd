class_name FighterModel
extends RefCounted
## Estado serializável, ponto fixo 1/256 px, velocidade em unidades por tick.
## Não usa delta variável, física de nós, relógio, RNG global ou animação como autoridade.
const SCALE := 256
const FLOOR_Y := 590 * SCALE
const GRAVITY := 64 # 3600 px/s², integrado a 120 Hz.
const JUMP_SPEED := -2560 # -1200 px/s.
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

func grounded() -> bool:
	return y >= FLOOR_Y

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
		transition(FighterState.Id.IDLE if grounded() else FighterState.Id.JUMP)
	if state == FighterState.Id.ATTACK:
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
	if buffer.consume(CombatInput.KICK):
		_start_move(character.air_kick if not grounded() else (character.sweep if input.has(CombatInput.DOWN) else character.kick))
	elif grounded() and buffer.consume(CombatInput.PUNCH):
		_start_move(character.jab)
	elif grounded() and buffer.consume(CombatInput.UP):
		vy = JUMP_SPEED
		vx = input.axis_x() * character.speed_pixels_per_tick * SCALE
		transition(FighterState.Id.JUMP)
	elif grounded():
		vx = input.axis_x() * character.speed_pixels_per_tick * SCALE
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
		vy += GRAVITY
		y += vy
		if y >= FLOOR_Y:
			y = FLOOR_Y
			vy = 0
			vx = 0
			if state == FighterState.Id.JUMP:
				transition(FighterState.Id.IDLE)

func _start_move(move: MoveData) -> void:
	move_id = move.id
	move_tick = 0
	hit_targets.clear()
	if grounded():
		vx = 0
	transition(FighterState.Id.ATTACK)

func end_tick() -> void:
	state_tick += 1
	if state == FighterState.Id.ATTACK:
		move_tick += 1

func hurtboxes() -> Array[Rect2i]:
	if state == FighterState.Id.KO:
		return []
	var low := grounded() and input.has(CombatInput.DOWN) and state != FighterState.Id.ATTACK
	var boxes: Array[Rect2i] = []
	# Cabeça, tronco, pernas separados; perfis por quadro podem substituir este protótipo.
	for rect in ([Rect2i(-22, -112, 44, 36), Rect2i(-30, -78, 60, 42), Rect2i(-36, -38, 72, 38)] if low else
		[Rect2i(-22, -192, 44, 42), Rect2i(-28, -150, 56, 84), Rect2i(-34, -66, 68, 66)]):
		boxes.append(BoxMath.world_rect(rect, x, y, facing))
	return boxes

func attack_boxes() -> Array[Rect2i]:
	var result: Array[Rect2i] = []
	if state != FighterState.Id.ATTACK:
		return result
	for box in current_move().hitboxes:
		if box.active(move_tick):
			result.append(BoxMath.world_rect(box.rect, x, y, facing))
	return result

func blocking(level: MoveData.Level) -> bool:
	if not grounded() or stun_ticks > 0 and state != FighterState.Id.BLOCK:
		return false
	if state == FighterState.Id.ATTACK or state == FighterState.Id.KO:
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
	x += direction * move.push_pixels * SCALE
	if guarded:
		stun_ticks = move.blockstun * 2
		transition(FighterState.Id.BLOCK)
	else:
		health = maxi(0, health - move.damage)
		stun_ticks = move.hitstun * 2
		transition(FighterState.Id.KO if health == 0 else FighterState.Id.HITSTUN)

func snapshot() -> Dictionary:
	return {"slot": slot, "character": character.id, "x": x, "y": y, "vx": vx, "vy": vy,
		"facing": facing, "health": health, "state": int(state), "state_tick": state_tick,
		"stun_ticks": stun_ticks, "move_id": move_id, "move_tick": move_tick,
		"hit_targets": hit_targets.duplicate(), "held": input.held, "pressed": input.pressed,
		"buffer": buffer.snapshot()}

func restore(data: Dictionary) -> void:
	assert(data.character == character.id and data.slot == slot)
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
