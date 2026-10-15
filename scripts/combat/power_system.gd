class_name PowerSystem
extends RefCounted
## Shared integer entity simulation for Versus and Story. No drawing, clock or Nodes.
const UNIT := FighterModel.SCALE
const LASER_STEP := 16 * UNIT  # 1920 px/s at 120 Hz.
var projectiles: Array = []
var sequence: int = 0
var events: Array = []


func emit(f: FighterModel, tick: int, lane_aware: bool = false) -> bool:
	if f.state != FighterState.Id.ATTACK or f.current_move().legacy.is_empty():
		return false
	var move := f.current_move()
	var m := move.legacy
	if f.move_tick == 0:
		events.append(_event("voice", f, tick, m.name, f.x, f.y))
	var super_started: bool = f.move_tick == 0 and m.name == "super"
	if not m.get("projectile", false) and not m.get("summon", false):
		if f.move_tick == move.startup * 2 and m.name in ["uppercut", "special", "super"]:
			events.append(
				_event("cast", f, tick, m.name, f.x + f.facing * 110 * UNIT, f.y - 180 * UNIT)
			)
		return super_started
	var waves := int(m.get("waves", 3 if m.name == "super" else 1))
	var drone: bool = f.character.id == "marcelo" and m.name in ["super", "drone"]
	if drone:
		waves = 5 if m.name == "super" else 1
	if f.emitted_waves >= waves or f.move_tick < move.startup * 2 + f.emitted_waves * 10:
		return super_started
	sequence += 1
	var i := f.emitted_waves
	var profile: Dictionary = f.character.legacy.get("projectile", {})
	var offset := int(profile.get("offset", 150))
	var height := int(profile.get("height", 185))
	if drone:
		offset = 85 + (i % 3) * 90
		height = 175 + (i / 3) * 90 + (i % 2) * 40
	var x := f.x + f.facing * offset * UNIT
	var y := f.y - height * UNIT
	var warmup := (80 if m.name == "super" else 240) if drone else 0
	projectiles.append(
		{
			"id": sequence,
			"owner": f.slot,
			"character": f.character.id,
			"move": move.id,
			"kind": "drone" if drone else "projectile",
			"drone": drone,
			"x": x,
			"y": y,
			"origin_x": x,
			"origin_y": y,
			"vx": f.facing * roundi(float(m.get("speed", 720)) * UNIT / 120.0),
			"vy": 0,
			"facing": f.facing,
			"age": 0,
			"ttl": 600 if drone else 300,
			"delay": warmup,
			"warmup": warmup,
			"fired": false,
			"fire_tick": -1,
			"radius": int(m.get("radius", 26)),
			"effect": str(m.get("effect", f.character.id)),
			"lane_y": f.ground_y,
			"lane_aware": lane_aware
		}
	)
	events.append(_event("cast", f, tick, m.name, x, y))
	f.emitted_waves += 1
	return super_started


func advance(actors: Array[FighterModel], width: int, tick: int) -> Array:
	var contacts: Array = []
	var alive: Array = []
	var spawned: Array = []
	for p in projectiles:
		p.age += 1
		if p.age > p.ttl:
			continue
		var owner := _actor(actors, int(p.owner))
		if owner == null:
			continue
		if p.drone:
			if p.delay > 0:
				p.delay -= 1
			elif not p.fired:
				var target := _target(actors, p)
				if target != null:
					p.fired = true
					p.fire_tick = p.age
					spawned.append(_laser(p, target))
					events.append(
						_event(
							"laser",
							owner,
							tick,
							owner.character.move_for(p.move).legacy.name,
							int(p.x),
							int(p.y)
						)
					)
			if not p.fired or p.age - p.fire_tick < 36:
				alive.append(p)
			continue
		p.x += p.vx
		p.y += p.vy
		if p.x < -150 * UNIT or p.x > (width + 150) * UNIT:
			continue
		var radius := int(p.radius) * UNIT
		var box := Rect2i(int(p.x) - radius, int(p.y) - radius, radius * 2, radius * 2)
		var connected := false
		for target in actors:
			if target.slot == owner.slot or target.health <= 0 or not _same_lane(p, target):
				continue
			for hurt in target.hurtboxes():
				if not BoxMath.overlap(box, hurt):
					continue
				var move := owner.character.move_for(p.move)
				contacts.append(
					{
						"attacker": owner.slot,
						"defender": target.slot,
						"move": move,
						"facing": int(p.facing),
						"blocked": target.blocking(move.level),
						"projectile": true,
						"entity": int(p.id),
						"impact_x": clampi(int(p.x), hurt.position.x, hurt.end.x),
						"impact_y": clampi(int(p.y), hurt.position.y, hurt.end.y),
						"effect": p.effect,
						"power_kind": p.kind
					}
				)
				connected = true
				break
			if connected:
				break
		if not connected:
			alive.append(p)
	projectiles = alive + spawned
	return contacts


func _laser(drone: Dictionary, target: FighterModel) -> Dictionary:
	sequence += 1
	var dy := target.y - (85 if target.input.has(CombatInput.DOWN) else 145) * UNIT - int(drone.y)
	var dx := target.x - int(drone.x)
	var distance := maxi(1, maxi(absi(dx), absi(dy)))
	var facing := 1 if dx >= 0 else -1
	drone.facing = facing
	@warning_ignore("integer_division")
	var vx: int = dx * LASER_STEP / distance
	@warning_ignore("integer_division")
	var vy: int = dy * LASER_STEP / distance
	return {
		"id": sequence,
		"owner": drone.owner,
		"character": drone.character,
		"move": drone.move,
		"kind": "laser",
		"drone": false,
		"x": drone.x,
		"y": drone.y,
		"origin_x": drone.x,
		"origin_y": drone.y,
		"vx": vx,
		"vy": vy,
		"facing": facing,
		"age": 0,
		"ttl": 90,
		"delay": 0,
		"warmup": 0,
		"radius": 10,
		"effect": "sentinelLaser",
		"lane_y": drone.lane_y,
		"lane_aware": drone.lane_aware
	}


static func _event(
	kind: String, f: FighterModel, tick: int, move: String, x: int, y: int
) -> Dictionary:
	return {
		"id": "%d:%s:%d:%d" % [tick, kind, f.slot, f.emitted_waves],
		"kind": kind,
		"character": f.character.id,
		"move": move,
		"tick": tick,
		"slot": f.slot,
		"x": x,
		"y": y
	}


static func _actor(actors: Array[FighterModel], slot: int) -> FighterModel:
	for f in actors:
		if f.slot == slot:
			return f
	return null


static func _same_lane(p: Dictionary, target: FighterModel) -> bool:
	return not p.lane_aware or absi(int(p.lane_y) - target.ground_y) <= 48 * UNIT


static func _target(actors: Array[FighterModel], p: Dictionary) -> FighterModel:
	var nearest: FighterModel
	var distance := 100000000
	for f in actors:
		if f.slot == p.owner or f.health <= 0 or not _same_lane(p, f):
			continue
		var d := absi(f.x - int(p.x))
		if d < distance:
			distance = d
			nearest = f
	return nearest


func snapshot() -> Dictionary:
	return {"sequence": sequence, "projectiles": projectiles.duplicate(true)}


func restore(data: Dictionary) -> void:
	sequence = int(data.sequence)
	projectiles = data.projectiles.duplicate(true)
	events.clear()
