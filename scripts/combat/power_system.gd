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
	if m.get("body_roll", false):
		if f.move_tick == move.startup * 2:
			events.append(_event("cast", f, tick, m.name, f.x, f.y - 130 * UNIT))
		return super_started

	if not m.get("projectile", false) and not m.get("summon", false):
		if f.move_tick == move.startup * 2 and m.name in ["uppercut", "special", "super"]:
			var source := Vector2i(f.x + f.facing * 110 * UNIT, f.y - 180 * UNIT)
			if f.character.id in ["gustavo", "gelton", "marcelino"]:
				source = CombatGeometry.hand(f)
			events.append(_event("cast", f, tick, m.name, source.x, source.y))
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
	offset = CharacterMetrics.units(f.character.id, offset)
	height = CharacterMetrics.units(f.character.id, height)
	var hand := (
		CombatGeometry.hand(f)
		if (
			f.character.id
			in ["marcelo", "rafael", "adriano", "joao", "gustavo", "gelton", "marcelino"]
		)
		else Vector2i(f.x + f.facing * offset * UNIT, f.y - height * UNIT)
	)
	var x := hand.x
	var y := hand.y
	if drone:
		offset = [-80, 20, 120, 220, 320][i] if m.name == "super" else 115
		height = [245, 295, 325, 295, 245][i] if m.name == "super" else 245
		x = clampi(f.x + f.facing * offset * UNIT, 48 * UNIT, (3552 if lane_aware else 1232) * UNIT)
		y = f.y - height * UNIT
	var warmup := (90 + i * 6 if m.name == "super" else 240) if drone else 0
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
			"spawn_x": hand.x,
			"spawn_y": hand.y,
			"first": true,
			"sweep_x": f.x + f.facing * 42 * UNIT,
			"sweep_y": y,
			"vx": f.facing * roundi(float(m.get("speed", 720)) * UNIT / 120.0),
			"vy": 0,
			"facing": f.facing,
			"age": 0,
			"ttl": 600 if drone else 300,
			"delay": warmup,
			"warmup": warmup,
			"fired": false,
			"fire_tick": -1,
			"radius": CharacterMetrics.units(f.character.id, int(m.get("radius", 26))),
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
					var beam := _laser(p, target)
					spawned.append(beam)
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
		var from := Vector2i(int(p.x), int(p.y))
		if p.get("first", false):
			from = Vector2i(int(p.sweep_x), int(p.sweep_y))
		p.first = false
		p.x += p.vx
		p.y += p.vy
		var to := Vector2i(int(p.x), int(p.y))
		var nearest: Dictionary = {}
		var victim: FighterModel
		var victim_box := Rect2i()
		for target in actors:
			if target.slot == owner.slot or target.health <= 0 or not _same_lane(p, target):
				continue
			for hurt in target.hurtboxes():
				var contact := BoxMath.sweep(from, to, hurt, int(p.radius) * UNIT)
				if not contact.is_empty() and (nearest.is_empty() or contact.time < nearest.time):
					nearest = contact
					victim = target
					victim_box = hurt
		if victim != null:
			var hit: Vector2i = nearest.point
			hit.x = clampi(hit.x, victim_box.position.x, victim_box.end.x)
			hit.y = clampi(hit.y, victim_box.position.y, victim_box.end.y)
			var move := owner.character.move_for(p.move)
			var blocked := victim.blocking(move.level)
			contacts.append(
				{
					"attacker": owner.slot,
					"defender": victim.slot,
					"move": move,
					"facing": int(p.facing),
					"blocked": blocked,
					"projectile": true,
					"entity": int(p.id),
					"impact_x": hit.x,
					"impact_y": hit.y,
					"effect": p.effect,
					"power_kind": p.kind
				}
			)
			if p.kind == "laser":
				events.append(
					{
						"id": "%d:beam:%d" % [tick, int(p.id)],
						"kind": "beam",
						"character": p.character,
						"move": p.move,
						"tick": tick,
						"slot": victim.slot,
						"x": hit.x,
						"y": hit.y,
						"origin_x": p.origin_x,
						"origin_y": p.origin_y,
						"effect": "sentinelLaser",
						"blocked": blocked
					}
				)
		elif p.x >= -150 * UNIT and p.x <= (width + 150) * UNIT:
			alive.append(p)
	projectiles = alive + spawned
	return contacts


func _laser(drone: Dictionary, target: FighterModel) -> Dictionary:
	sequence += 1
	var target_point := Vector2i(target.x, target.y - 145 * UNIT)
	var hurts := target.hurtboxes()
	if not hurts.is_empty():
		# Aim inside a real body rectangle, including crouch and airborne poses.
		var desired := target_point
		var best := 1 << 60
		for hurt in hurts:
			var center := hurt.position + hurt.size / 2
			var distance := absi(center.x - desired.x) + absi(center.y - desired.y)
			if distance < best:
				best = distance
				target_point = center
	var cannon := Vector2i(int(drone.x), int(drone.y))
	var facing := 1 if target_point.x >= cannon.x else -1
	cannon += Vector2i(facing * 18 * UNIT, 5 * UNIT)
	var dy := target_point.y - cannon.y
	var dx := target_point.x - cannon.x
	var distance := maxi(1, maxi(absi(dx), absi(dy)))
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
		"x": cannon.x,
		"y": cannon.y,
		"origin_x": cannon.x,
		"origin_y": cannon.y,
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
		"facing": f.facing,
		"effect":
		str(f.current_move().legacy.get("effect", "")) if f.current_move() != null else "",
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
