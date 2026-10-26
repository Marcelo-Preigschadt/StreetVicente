class_name OpenBorCombat
extends RefCounted
## OpenBOR adjust_grabposition / dograb / dothrow adaptation.
## Source and BSD-3-Clause notice: third_party/openbor/README.md.
## Retains the MIT input adapter, credited in third_party/fists_of_fury/.
## Fixed 120 Hz and integer coordinates keep solo/co-op rollback identical.
const UNIT := FighterModel.SCALE
const NORMALS := CombatInput.PUNCH | CombatInput.KICK
const COMBO_WINDOW := 108
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
		var template := source.get_move(("crouchPunch" if step < 2 else "sweep") if low else ("punch" if step < 2 else "kick"), [1, 2, 0, 2][step])
		var move: MoveData = template.duplicate(true)
		move.id = "bor:%d" % i
		move.legacy = template.legacy.duplicate(true)
		move.legacy.cancellable = true
		if step == 3:
			move.damage = roundi(move.damage * 1.2)
			move.push_pixels = 100
			move.legacy.knockdown = true
			move.legacy.launch = 570
		c.moves[move.id] = move
		c.moves["fury:%d" % i] = move
	# Low furniture is struck with the existing low kick drawings. Several
	# fighters' crouching fists are still above a tabletop; don't invent damage
	# above the surface or move their approved limbs to fake the contact.
	for index in 3:
		var source_move := source.get_move("sweep", [1, 0, 2][index])
		var strike: MoveData = source_move.duplicate(true)
		strike.legacy = source_move.legacy.duplicate(true)
		strike.id = "bor:prop:%d" % index
		c.moves[strike.id] = strike
	# A visible grip needs time to read before release. Retiming is session-only
	# and reuses the authored drawings; the versus character data stay intact.
	for strength in 3:
		var original := source.get_move("throw", strength)
		if original == null or original.startup >= 16:
			continue
		var grab: MoveData = original.duplicate(true)
		grab.legacy = original.legacy.duplicate(true)
		var frames: Array = original.legacy.frames
		var timed: Array = []
		for tick in 32:
			timed.append(frames[mini(frames.size() - 1, tick * original.startup * 2 / 32)])
		timed.append_array(frames.slice(original.startup * 2))
		grab.startup = 16
		grab.legacy.frames = timed
		c.moves[grab.id] = grab
	return c


func actor(f: FighterModel) -> Dictionary:
	var key := str(f.slot)
	if not actors.has(key):
		actors[key] = {"index": -1, "last_hit": -10000, "confirmed": false,
			"queued": 0, "queue_until": 0, "chain": 0, "grab_target": -1}
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
	_update_grab(world, f, data)
	if raw.pressed & CombatInput.THROW and gear.interaction < 0:
		_try_grab(world, f, data)
	var mobile := f.state in [FighterState.Id.IDLE, FighterState.Id.WALK, FighterState.Id.CROUCH]
	# Source Player.set_heading: turn with movement, not a nearby background foe.
	if mobile and raw.axis_x() != 0 and gear.interaction_phase != "align":
		f.facing = raw.axis_x()
	if world.tick - int(data.last_hit) > COMBO_WINDOW and f.state != FighterState.Id.ATTACK:
		data.index = -1
		data.chain = 0
		data.confirmed = false
	if raw.pressed & NORMALS:
		data.queued = CombatInput.KICK if raw.pressed & CombatInput.KICK else CombatInput.PUNCH
		data.queue_until = world.tick + 36
	if world.tick > int(data.queue_until):
		data.queued = 0
	if f.state in [FighterState.Id.HITSTUN, FighterState.Id.KO, FighterState.Id.KNOCKDOWN, FighterState.Id.DIZZY]:
		data.queued = 0
		data.confirmed = false
		data.index = -1
	var ready := FighterState.actionable(f.state) or (f.state == FighterState.Id.BLOCK and f.stun_ticks == 0)
	var can_chain := f.state == FighterState.Id.ATTACK and f.move_id.begins_with("bor:") \
		and f.has_contact and f.move_tick >= (f.current_move().startup + f.current_move().active) * 2
	if can_chain and raw.pressed & CombatInput.JUMP and f.grounded():
		f.transition(FighterState.Id.IDLE)
		f.move_id = ""
		ready = true
	if int(data.queued) != 0 and (ready or can_chain):
		var name := ""
		if not f.grounded():
			name = "airKick"
		elif int(data.queued) == CombatInput.KICK:
			if data.confirmed and int(data.index) in [1, 2] and gear.interaction < 0:
				data.index = 2  # F,F,G branches directly into the finisher.
			else:
				name = "sweep" if gear.interaction >= 0 or _low_target(world, f) else "kick"
		var move: MoveData
		if name.is_empty():
			data.index = (int(data.index) + 1) % 4 if data.confirmed else 0
			if _low_target(world, f):
				move = f.character.moves["bor:prop:%d" % (int(data.chain) % 3)]
			else:
				move = f.character.moves["bor:%d" % int(data.index)]
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
	if f.state == FighterState.Id.ATTACK and f.move_id.begins_with("bor:") and f.move_tick <= 8:
		f.x += f.facing * 2 * UNIT
	if f.grounded() and f.state in [FighterState.Id.IDLE, FighterState.Id.WALK]:
		var lane_axis := int(raw.has(CombatInput.DOWN)) - int(raw.has(CombatInput.UP))
		if raw.has(CombatInput.GUARD):
			lane_axis = 0
		var lane_speed := maxi(1, f.character.speed_units * 2 / 3)
		if lane_axis != 0 and raw.axis_x() != 0:
			f.x = old_x + (f.x - old_x) * 181 / 256
			lane_speed = lane_speed * 181 / 256
		f.ground_y = clampi(old_lane + lane_axis * lane_speed, StoryLayout.MIN_LANE * UNIT, StoryLayout.MAX_LANE * UNIT)
		f.y = f.ground_y
		if f.x != old_x or f.ground_y != old_lane:
			f.transition(FighterState.Id.WALK)
	gear.constrain_actor(f, old_x, old_lane)
	var gate := StoryLayout.gate(world.wave_index) * UNIT
	f.x = clampi(f.x, 70 * UNIT, gate)
	if f.state == FighterState.Id.WALK:
		var dx := absi(f.x - old_x)
		var dy := absi(f.ground_y - old_lane)
		f.walk_distance += maxi(dx, dy) + mini(dx, dy) * 3 / 8
	_update_grab(world, f, data)
	var boxes: Array[Rect2i] = f.attack_boxes()
	if f.state == FighterState.Id.ATTACK and str(f.current_move().legacy.get("name", "")) == "throw":
		boxes.clear()  # A linked throw hits its victim at release, never by a distant punch box.
	return {"boxes": boxes, "power": f.current_move() if f.state == FighterState.Id.ATTACK else null}


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
	for prop in world.props:
		if not OpenBorMotion.solid(prop) or absi(int(prop.lane) - f.ground_y) > 42 * UNIT \
			or (int(prop.x) - f.x) * f.facing <= 0:
			continue
		var size := StoryLayout.prop_size(str(prop.kind))
		var gap := maxi(0, absi(int(prop.x) - f.x) - roundi(size.x * .5 * UNIT))
		if gap < nearest and gap <= 150 * UNIT:
			nearest = gap
			low = size.y < 220
	return low


func snapshot() -> Dictionary:
	return actors.duplicate(true)


func restore(data: Dictionary) -> void:
	actors = data.duplicate(true)


static func grab_reach(a: FighterModel, b: FighterModel) -> int:
	return maxi(120 * UNIT, OpenBorMotion._radius(a) + OpenBorMotion._radius(b) + 18 * UNIT)


func _try_grab(world: StorySimulation, f: FighterModel, data: Dictionary) -> void:
	if not f.grounded() or not FighterState.actionable(f.state):
		return
	var move := f.character.get_move("throw", 1)
	if move == null:
		return
	var nearest: FighterModel
	var distance := 200 * UNIT
	for enemy in world.enemies:
		var other: FighterModel = enemy.fighter
		if other.health <= 0 or not other.grounded() or other.invincible_ticks > 0 \
			or other.state in [FighterState.Id.KNOCKDOWN, FighterState.Id.WAKEUP] \
			or absi(other.ground_y - f.ground_y) > OpenBorMotion.BODY_HALF_DEPTH + 6 * UNIT:
			continue
		var gap := absi(other.x - f.x)
		if gap < distance and gap <= grab_reach(f, other):
			nearest = other
			distance = gap
	if nearest == null:
		return
	# OpenBOR adjust_grabposition: midpoint first; if one body is blocked,
	# keep it fixed and move the other. Never drag either actor through scenery.
	var side := 1 if nearest.x >= f.x else -1
	var separation := 82 * UNIT
	var middle := (f.x + nearest.x) / 2
	var lane := (f.ground_y + nearest.ground_y) / 2
	var a := Vector2i(middle - side * separation / 2, lane)
	var b := Vector2i(middle + side * separation / 2, lane)
	if not OpenBorMotion.test_position(world, nearest, b):
		b = Vector2i(nearest.x, nearest.ground_y)
		a = b - Vector2i(side * separation, 0)
	elif not OpenBorMotion.test_position(world, f, a):
		a = Vector2i(f.x, f.ground_y)
		b = a + Vector2i(side * separation, 0)
	if not OpenBorMotion.test_position(world, f, a) or not OpenBorMotion.test_position(world, nearest, b):
		return
	f.x = a.x
	f.ground_y = a.y
	f.y = a.y
	f.facing = side
	nearest.x = b.x
	nearest.ground_y = b.y
	nearest.y = b.y
	nearest.facing = -side
	f.vx = 0
	nearest.vx = 0
	nearest.vy = 0
	f._start_move(move)
	f.invincible_ticks = (move.startup + move.active) * 2
	nearest.transition(FighterState.Id.HITSTUN)
	nearest.stun_ticks = 2
	data.grab_target = nearest.slot
	data.grab_health = nearest.health
	data.queued = 0


func _update_grab(world: StorySimulation, f: FighterModel, data: Dictionary) -> void:
	var id := int(data.get("grab_target", -1))
	if id < 0:
		return
	var target := world._enemy(id)
	if target == null or target.health <= 0 or target.health != int(data.get("grab_health", target.health)) or f.state != FighterState.Id.ATTACK \
		or str(f.current_move().legacy.get("name", "")) != "throw":
		data.grab_target = -1
		return
	if f.current_move().phase(f.move_tick) == "STARTUP":
		target.stun_ticks = 2
		return
	# dothrow: unlink on the authored release frame, then toss independently.
	data.grab_target = -1
	f.hit_targets.append(target.slot)
	var throw_move: MoveData = f.current_move().duplicate(true)
	throw_move.legacy = f.current_move().legacy.duplicate(true)
	throw_move.legacy.knockdown = true
	throw_move.legacy.launch = 720
	throw_move.push_pixels = 0
	world._apply_hero_hit(target, throw_move, f.facing, false, target.x, target.y - 130 * UNIT, "", 0)
	target.knockdown_pending = true
	actor(target).toss = {"owner": f.slot, "direction": f.facing, "age": 0, "hits": []}


func advance_throw(world: StorySimulation, f: FighterModel) -> void:
	var data := actor(f)
	if not data.has("toss"):
		return
	var toss: Dictionary = data.toss
	toss.age += 1
	if (f.grounded() and int(toss.age) > 6) or int(toss.age) > 180:
		data.erase("toss")
		return
	f.x += int(toss.direction) * 1120 * UNIT / 120
	# OpenBOR thrown bodies are projectiles and can knock other enemies down.
	for enemy in world.enemies:
		var target: FighterModel = enemy.fighter
		if target == f or target.health <= 0 or target.slot in toss.hits \
			or absi(target.ground_y - f.ground_y) > 32 * UNIT \
			or absi(target.x - f.x) > 65 * UNIT:
			continue
		toss.hits.append(target.slot)
		var move := MoveData.new()
		move.damage = 80
		move.hitstun = 18
		move.push_pixels = 60
		move.legacy = {"knockdown": true, "launch": 420}
		target.receive_hit(move, int(toss.direction), false, int(toss.owner))
		world.events.append({"id": "%d:toss:%d:%d" % [world.tick, f.slot, target.slot],
			"kind": "hit", "tick": world.tick, "slot": target.slot,
			"character": world.hero.character.id, "move": "throw", "x": target.x, "y": target.y - 100 * UNIT})
