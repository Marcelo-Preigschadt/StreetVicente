class_name FuryCombat
extends RefCounted
## Adapted from Nicolas Bize's Fists of Fury Player/Character (MIT, 2025).
## See third_party/fists_of_fury/LICENSE. Fixed 120 Hz for saves and rollback.
const UNIT := FighterModel.SCALE
const NORMALS := CombatInput.PUNCH | CombatInput.KICK
const COMBO_WINDOW := 144
var actors: Dictionary = {}


static func character(source: CharacterData) -> CharacterData:
	# Session moves never modify the shared versus roster.
	var c: CharacterData = source.duplicate()
	c.legacy = source.legacy
	c.moves = source.moves.duplicate()
	c.walk_by_pose = source.walk_by_pose
	c.speed_units = source.speed_units
	c.back_speed_units = source.speed_units
	for i in 8:
		var step := i % 4
		var low := i >= 4
		var template := source.get_move(("crouchPunch" if step < 2 else "sweep") if low else ("punch" if step < 2 else "kick"), 1 + (step % 2))
		var move: MoveData = template.duplicate(true)
		move.id = "fury:%d" % i
		move.legacy = template.legacy.duplicate(true)
		if step == 3:
			move.damage = roundi(move.damage * 1.2)
			move.push_pixels = 100
			move.legacy.knockdown = true
			move.legacy.launch = 570
		c.moves[move.id] = move
	return c


func actor(f: FighterModel) -> Dictionary:
	var key := str(f.slot)
	if not actors.has(key):
		actors[key] = {"index": -1, "last_hit": -10000, "confirmed": false,
			"queued": 0, "queue_until": 0, "chain": 0}
	return actors[key]


func buffer_input(f: FighterModel, value: CombatInput) -> void:
	var data := actor(f)
	data.frozen_pressed = int(data.get("frozen_pressed", 0)) | value.pressed


func take_input(f: FighterModel, value: CombatInput) -> CombatInput:
	var data := actor(f)
	var result := CombatInput.new(value.held, value.pressed | int(data.get("frozen_pressed", 0)))
	data.frozen_pressed = 0
	return result


func advance(world: StorySimulation, f: FighterModel, gear: StoryObjects, raw: CombatInput) -> Dictionary:
	var data := actor(f)
	var old_x := f.x
	var old_lane := f.ground_y
	var mobile := f.state in [FighterState.Id.IDLE, FighterState.Id.WALK, FighterState.Id.CROUCH]
	# Source Player.set_heading: turn with movement, not a nearby background foe.
	if mobile and raw.axis_x() != 0:
		f.facing = raw.axis_x()
	if world.tick - int(data.last_hit) > COMBO_WINDOW and f.state != FighterState.Id.ATTACK:
		data.index = -1
		data.chain = 0
		data.confirmed = false
	if raw.pressed & NORMALS:
		data.queued = CombatInput.KICK if raw.pressed & CombatInput.KICK else CombatInput.PUNCH
		data.queue_until = world.tick + 22
	if world.tick > int(data.queue_until):
		data.queued = 0
	if f.state in [FighterState.Id.HITSTUN, FighterState.Id.KO, FighterState.Id.KNOCKDOWN, FighterState.Id.DIZZY]:
		data.queued = 0
		data.confirmed = false
		data.index = -1
	var ready := FighterState.actionable(f.state) or (f.state == FighterState.Id.BLOCK and f.stun_ticks == 0)
	var can_chain := f.state == FighterState.Id.ATTACK and f.move_id.begins_with("fury:") \
		and f.has_contact and f.move_tick >= f.current_move().total_ticks() - 10
	if int(data.queued) != 0 and (ready or can_chain):
		var name := ""
		if not f.grounded():
			name = "airKick"
		elif int(data.queued) == CombatInput.KICK:
			name = "sweep" if gear.interaction >= 0 or _low_target(world, f) else "kick"
		var move: MoveData
		if name.is_empty():
			data.index = (int(data.index) + 1) % 4 if data.confirmed else 0
			move = f.character.moves["fury:%d" % (int(data.index) + (4 if _low_target(world, f) else 0))]
		else:
			move = f.character.get_move(name, 1)
			data.index = -1
		data.confirmed = false
		data.queued = 0
		if move != null and (f.grounded() or not f.air_normal_used):
			f._start_move(move)
	var pressed := raw.pressed & ~(NORMALS | CombatInput.THROW | CombatInput.UP | CombatInput.LEFT | CombatInput.RIGHT)
	var held := raw.held & ~(CombatInput.UP | CombatInput.DOWN | CombatInput.THROW)
	if raw.has(CombatInput.GUARD) and raw.has(CombatInput.DOWN):
		held |= CombatInput.DOWN
	if raw.pressed & CombatInput.JUMP:
		pressed |= CombatInput.UP
	f.record_input(CombatInput.new(held, pressed), world.tick)
	f.begin_tick(f.x + f.facing * 1000 * UNIT)
	if f.grounded() and f.state in [FighterState.Id.IDLE, FighterState.Id.WALK]:
		var lane_axis := int(raw.has(CombatInput.DOWN)) - int(raw.has(CombatInput.UP))
		if raw.has(CombatInput.GUARD):
			lane_axis = 0
		var lane_speed := maxi(1, f.character.speed_units * 2 / 3)
		if lane_axis != 0 and raw.axis_x() != 0:
			f.x = old_x + (f.x - old_x) * 181 / 256
			lane_speed = lane_speed * 181 / 256
		f.ground_y = clampi(old_lane + lane_axis * lane_speed, 535 * UNIT, 655 * UNIT)
		f.y = f.ground_y
		if f.x != old_x or f.ground_y != old_lane:
			f.transition(FighterState.Id.WALK)
	gear.constrain_actor(f, old_x, old_lane)
	var gate := mini(3560, 880 + world.wave_index * 820) * UNIT
	f.x = clampi(f.x, 70 * UNIT, gate)
	if f.state == FighterState.Id.WALK:
		var dx := absi(f.x - old_x)
		var dy := absi(f.ground_y - old_lane)
		f.walk_distance += maxi(dx, dy) + mini(dx, dy) * 3 / 8
	return {"boxes": f.attack_boxes(), "power": f.current_move() if f.state == FighterState.Id.ATTACK else null}


func contact(f: FighterModel, tick: int) -> void:
	var data := actor(f)
	data.confirmed = true
	data.last_hit = tick
	data.chain = int(data.chain) + 1


static func _low_target(world: StorySimulation, f: FighterModel) -> bool:
	var nearest := 240 * UNIT
	var low := false
	for enemy in world.enemies:
		var target: FighterModel = enemy.fighter
		var gap := absi(target.x - f.x)
		if target.health > 0 and gap < nearest and absi(target.ground_y - f.ground_y) < 45 * UNIT \
			and (target.x - f.x) * f.facing >= 0:
			var profile: Dictionary = LegacyRoster.catalog.story.enemies[enemy.kind]
			nearest = gap
			low = int(profile.h) < 230 and int(profile.get("fly", 0)) == 0
	return low


func snapshot() -> Dictionary:
	return actors.duplicate(true)


func restore(data: Dictionary) -> void:
	actors = data.duplicate(true)
