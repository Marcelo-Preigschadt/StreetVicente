class_name StoryObjects
extends RefCounted
## Objetos/perigos autoritativos. Origem nos pés, lane independente, swept AABB.
const UNIT := FighterModel.SCALE
var owner_ref: WeakRef
var world: StorySimulation:
	get:
		return owner_ref.get_ref()
var carry: Dictionary = {}
var thrown: Array = []
var hazards: Array = []
var bolts: Array = []
var pending_throw: bool = false
var pickup_ticks: int = 0
var interaction: int = -1
var interaction_phase := ""
var interaction_x: int = 0
var interaction_clock: int = 0
var debris: Array = []


func _init(owner_world: StorySimulation) -> void:
	owner_ref = weakref(owner_world)


func setup(act: int) -> void:
	carry.clear()
	thrown.clear()
	bolts.clear()
	hazards.clear()
	pending_throw = false
	pickup_ticks = 0
	interaction = -1
	interaction_phase = ""
	interaction_clock = 0
	debris.clear()
	world.props.clear()
	if act == 0:
		# Two seating groups on the foreground floor; the vending machine stays by the wall.
		for x in [1150, 2600]:
			_add_prop("table", x, 560, 160)
			_add_prop("chair", x - 165, 590, 80)
			_add_prop("chair", x + 165, 535, 80)
		_add_prop("soda", 3260, 540, 200)
	elif act == 2:
		for x in [800, 1690, 2760]:
			_add_prop("shelf", x, 548, 110)
	for i in 3:
		var x: int = [640, 1650, 2590][i]
		if act in [1, 3]:
			hazards.append(
				{
					"id": world.next_id,
					"kind": "cable" if act == 3 else "frost" if i % 2 else "acid",
					"x": (x + (320 if act == 3 else 280)) * UNIT,
					"lane": (560 if act == 3 else 595) * UNIT,
					"width": 150 if act == 3 else 190,
					"clock": i * (204 if act == 3 else 144),
					"period": 780 if act == 3 else 840,
					"warning": 150 if act == 3 else 156,
					"active": 192 if act == 3 else 288,
					"hits": {}
				}
			)
			world.next_id += 1


func _add_prop(kind: String, x: int, lane: int, hp: int) -> void:
	world.props.append(
		{
			"id": world.next_id,
			"kind": kind,
			"x": x * UNIT,
			"lane": lane * UNIT,
			"hp": hp,
			"used": false,
			"hit_ids": [],
			"cooldown": 0,
			"fall": 0,
			"hits": []
		}
	)
	world.next_id += 1


func migrate_layout() -> void:
	if world.act_index != 0:
		return
	for prop in world.props:
		if prop.kind != "chair" or prop.get("used", false):
			continue
		for table_x in [1150, 2600]:
			if int(prop.x) == (table_x - 110) * UNIT:
				prop.x = (table_x - 165) * UNIT
			elif int(prop.x) == (table_x + 110) * UNIT:
				prop.x = (table_x + 165) * UNIT


func input(value: CombatInput) -> CombatInput:
	var f := world.hero
	if interaction_phase == "align":
		interaction_clock += 1
		if value.axis_x() != 0 or value.has(CombatInput.UP) or value.has(CombatInput.DOWN) \
			or interaction_clock > 120 or f.state not in [FighterState.Id.IDLE, FighterState.Id.WALK]:
			interaction = -1
			interaction_phase = ""
			return value
		var gap := interaction_x - f.x
		if absi(gap) > 3 * UNIT:
			return CombatInput.new(CombatInput.RIGHT if gap > 0 else CombatInput.LEFT)
		interaction_phase = "strike"
		return CombatInput.new(0, CombatInput.KICK)
	if value.pressed & CombatInput.THROW and f.grounded() and FighterState.actionable(f.state):
		var nearest := nearby(f)
		if not nearest.is_empty():
			interaction = int(nearest.id)
			f.facing = 1 if int(nearest.x) >= f.x else -1
			# The stance comes from this character's authored contact frame. A
			# short visible backstep puts the actual foot onto the object.
			interaction_x = int(nearest.x) - f.facing * maxi(_kick_reach(f), roundi(StoryLayout.prop_size(str(nearest.kind)).x * .38 * UNIT) + 20 * UNIT)
			interaction_phase = "align"
			interaction_clock = 0
			world.combat.actor(f).queued = 0
			return CombatInput.new()
	return value


func _kick_reach(f: FighterModel) -> int:
	var proxy := FighterModel.new(f.character, f.slot, 0)
	proxy.facing = 1
	proxy.ground_y = 0
	proxy.y = 0
	proxy._start_move(f.character.get_move("sweep", 1))
	proxy.move_tick = proxy.current_move().startup * 2
	var boxes := proxy.attack_boxes()
	if boxes.is_empty():
		return 150 * UNIT
	return boxes[0].position.x + boxes[0].size.x / 2


func nearby(f: FighterModel) -> Dictionary:
	var result: Dictionary = {}
	var best := 1 << 60
	for prop in world.props:
		if prop.get("used", false) or prop.hp <= 0 or prop.kind == "medkit":
			continue
		var gap := maxi(0, absi(int(prop.x) - f.x) - bounds(prop).size.x / 2)
		var lane := absi(int(prop.lane) - f.ground_y)
		if gap <= 80 * UNIT and lane <= 40 * UNIT and gap + lane * 3 < best:
			result = prop
			best = gap + lane * 3
	return result


func bounds(prop: Dictionary) -> Rect2i:
	var size := StoryLayout.prop_size(str(prop.kind))
	var width := roundi(size.x * UNIT)
	var height := roundi(size.y * UNIT)
	return Rect2i(int(prop.x) - width / 2, int(prop.lane) - height, width, height)


func constrain_actor(actor: FighterModel, old_x: int, old_lane: int) -> void:
	OpenBorMotion.constrain(world, actor, old_x, old_lane)


func damage(prop: Dictionary, amount: int) -> void:
	if prop.get("used", false) or prop.hp <= 0:
		return
	prop.hp -= amount
	world.events.append({"id": "%d:prop:%d" % [world.tick, int(prop.id)], "kind": "hit",
		"tick": world.tick, "slot": -1, "character": world.hero.character.id,
		"move": "object", "x": int(prop.x), "y": int(prop.lane) - 80 * UNIT})
	if prop.kind == "soda" and prop.cooldown <= 0:
		prop.cooldown = 84
		_throw("can", int(prop.x), int(prop.lane) - 160 * UNIT,
			int(prop.lane), world.hero.facing, 520, -500)
	if prop.hp <= 0:
		prop.used = true
		world.score += 25
		if prop.kind == "shelf":
			prop.fall = 1
		else:
			_break(prop)
		if int(prop.id) % 3 == 0:
			_add_prop("medkit", int(prop.x) / UNIT, int(prop.lane) / UNIT, 1)


func _break(prop: Dictionary) -> void:
	# Pieces keep the object's original texture; no unrelated placeholder art.
	for i in 4:
		debris.append({"id": world.next_id, "kind": prop.kind, "part": i, "x": int(prop.x),
			"y": int(prop.lane) - 55 * UNIT, "lane": int(prop.lane),
			"vx": (i * 2 - 3) * 135, "vy": -350 - i * 95,
			"age": 0, "direction": -1 if i % 2 else 1})
		world.next_id += 1


func step(boxes: Array[Rect2i], move: MoveData, advance_environment: bool = true) -> void:
	var f := world.hero
	# An interaction is executed on the kick's contact frame, not on keydown.
	if interaction >= 0 and interaction_phase == "strike":
		if f.state != FighterState.Id.ATTACK:
			interaction = -1
			interaction_phase = ""
		elif f.current_move().phase(f.move_tick) == "ACTIVE":
			for prop in world.props.duplicate():
				if int(prop.id) != interaction or prop.get("used", false) or prop.hp <= 0:
					continue
				var contact := false
				for box in boxes:
					if BoxMath.overlap(box, bounds(prop)):
						contact = true
				if contact and absi(int(prop.lane) - f.ground_y) <= 42 * UNIT:
					f.hit_targets.append(prop.id)
					if prop.kind == "chair":
						prop.used = true
						_throw("chair", int(prop.x), int(prop.lane) - 86 * UNIT,
							int(prop.lane), f.facing, 650, -400)
					else:
						damage(prop, maxi(80, f.current_move().damage))
					interaction = -1
					interaction_phase = ""
					break
	for p in world.props.duplicate():
		if advance_environment:
			p.cooldown = maxi(0, int(p.get("cooldown", 0)) - 1)
		if (
			p.kind == "medkit"
			and f.health > 0
			and not p.used
			and f.grounded()
			and absi(int(p.x) - f.x) < 85 * UNIT
			and absi(int(p.lane) - f.ground_y) < 42 * UNIT
		):
			p.used = true
			f.health = mini(1000, f.health + 220)
		if advance_environment and p.get("fall", 0) > 0:
			p.fall += 1
			if p.fall in range(102, 181):
				for target in world.power_actors():
					if (
						target.slot not in p.hits
						and absi(target.ground_y - int(p.lane)) < 65 * UNIT
						and target.x > int(p.x) - 100 * UNIT
						and target.x < int(p.x) + 250 * UNIT
					):
						p.hits.append(target.slot)
						_environment_hit(target, 140, int(p.x))
		if (
			move == null
			or p.get("used", false)
			or p.kind == "medkit"
			or p.id in f.hit_targets
			or absi(int(p.lane) - f.ground_y) > 42 * UNIT
		):
			continue
		for box in boxes:
			if BoxMath.overlap(box, bounds(p)):
				f.hit_targets.append(p.id)
				damage(p, move.damage)
				break
	_step_thrown()
	_step_debris()
	if advance_environment:
		_step_hazards()
		_step_bolts()


func _step_debris() -> void:
	var kept: Array = []
	for piece in debris:
		piece.age += 1
		piece.x += int(piece.vx)
		piece.vy += 50
		piece.y = mini(int(piece.lane), int(piece.y) + int(piece.vy))
		if int(piece.y) >= int(piece.lane):
			piece.vx = int(piece.vx) * 240 / 256
			piece.vy = 0
		if piece.age < 110:
			kept.append(piece)
	debris = kept


func drop_medkit(x: int) -> void:
	_add_prop("medkit", x / UNIT, 625, 1)


func _throw(kind: String, x: int, y: int, lane: int, direction: int, speed: int, lift: int) -> void:
	thrown.append(
		{
			"id": world.next_id,
			"kind": kind,
			"x": x,
			"y": y,
			"lane": lane,
			"vx": int(direction * speed * UNIT / 120),
			"vy": int(lift * UNIT / 120),
			"age": 0,
			"landed": false,
			"direction": direction,
			"hits": []
		}
	)
	world.next_id += 1


func _step_thrown() -> void:
	var alive: Array = []
	for p in thrown:
		p.age += 1
		if p.get("landed", false):
			p.rest += 1
			if p.rest < 30:
				alive.append(p)
			continue
		var from := Vector2i(int(p.x), int(p.y))
		p.x += int(p.vx)
		p.vy += 64
		p.y += int(p.vy)
		for enemy in world.enemies:
			var target: FighterModel = enemy.fighter
			if (
				target.health <= 0
				or target.slot in p.hits
				or absi(target.ground_y - int(p.lane)) > 42 * UNIT
			):
				continue
			for hurt in target.hurtboxes():
				if not (
					BoxMath
					. sweep(
						from,
						Vector2i(int(p.x), int(p.y)),
						hurt,
						(40 if p.kind == "can" else 65) * UNIT
					)
					. is_empty()
				):
					p.hits.append(target.slot)
					_environment_hit(
						target,
						110 if p.kind == "can" else 190 if p.kind == "table" else 125,
						int(p.x)
					)
					break
		var half_height := roundi(StoryLayout.prop_size(str(p.kind)).y * UNIT / 2)
		if p.y + half_height >= p.lane:
			if p.kind == "can":
				for enemy in world.enemies:
					var target: FighterModel = enemy.fighter
					if (
						target.slot not in p.hits
						and absi(target.x - int(p.x)) < 210 * UNIT
						and absi(target.ground_y - int(p.lane)) < 65 * UNIT
					):
						_environment_hit(target, 110, int(p.x))
			p.y = int(p.lane) - half_height
			p.landed = true
			p.rest = 0
			alive.append(p)
			continue
		if p.age < 300:
			alive.append(p)
	thrown = alive


func _step_hazards() -> void:
	for h in hazards:
		h.clock += 1
		var cycle := int(h.clock) % int(h.period)
		if cycle < h.warning or cycle >= int(h.warning) + int(h.active):
			continue
		var height := 260 if h.kind == "cable" else 28
		var rect := Rect2i(
			int(h.x) - int(h.width) * UNIT / 2,
			int(h.lane) - height * UNIT,
			int(h.width) * UNIT,
			height * UNIT
		)
		for target in world.power_actors():
			if (
				target.health <= 0
				or absi(target.ground_y - int(h.lane)) > 55 * UNIT
				or world.tick - int(h.hits.get(str(target.slot), -10000)) < 132
			):
				continue
			for hurt in target.hurtboxes():
				if BoxMath.overlap(rect, hurt):
					h.hits[str(target.slot)] = world.tick
					_environment_hit(
						target,
						45 if h.kind == "acid" else 22 if h.kind == "frost" else 48,
						int(h.x),
						72 if h.kind == "frost" else 26
					)
					break


func _environment_hit(target: FighterModel, amount: int, x: int, stun: int = 26) -> void:
	if target.health <= 0 or target.invincible_ticks > 0:
		return
	var move := MoveData.new()
	move.damage = amount
	move.hitstun = int(stun / 2)
	move.push_pixels = 5
	target.receive_hit(move, 1 if target.x >= x else -1, false)
	world.events.append(
		{
			"id": "%d:object:%d:%d" % [world.tick, target.slot, x],
			"kind": "hit",
			"tick": world.tick,
			"character": world.hero.character.id,
			"move": "object",
			"slot": target.slot,
			"x": target.x,
			"y": target.y - 90 * UNIT
		}
	)


func snapshot() -> Dictionary:
	return {
		"carry": carry.duplicate(true),
		"interaction": interaction,
		"interaction_phase": interaction_phase,
		"interaction_x": interaction_x,
		"interaction_clock": interaction_clock,
		"debris": debris.duplicate(true),
		"pending": pending_throw,
		"pickup_ticks": pickup_ticks,
		"thrown": thrown.duplicate(true),
		"bolts": bolts.duplicate(true),
		"hazards": hazards.duplicate(true)
	}


func restore(data: Dictionary) -> void:
	# A save from the old hold mechanic returns the furniture to the floor.
	var old_carry: Dictionary = data.get("carry", {})
	if not old_carry.is_empty():
		for prop in world.props:
			if int(prop.id) == int(old_carry.get("id", -1)):
				prop.used = false
				prop.x = int(old_carry.get("source_x", world.hero.x))
				prop.lane = int(old_carry.get("source_lane", world.hero.ground_y))
	carry.clear()
	interaction = int(data.get("interaction", -1))
	interaction_phase = str(data.get("interaction_phase", ""))
	interaction_x = int(data.get("interaction_x", 0))
	interaction_clock = int(data.get("interaction_clock", 0))
	debris = data.get("debris", []).duplicate(true)
	pending_throw = false
	pickup_ticks = 0
	thrown = data.get("thrown", []).duplicate(true)
	bolts = data.get("bolts", []).duplicate(true)
	hazards = data.get("hazards", []).duplicate(true)


func fire_enemy(enemy: Dictionary) -> void:
	var f: FighterModel = enemy.fighter
	var profile: Dictionary = LegacyRoster.catalog.story.enemies[enemy.kind]
	var origin := Vector2i(
		f.x + f.facing * 70 * UNIT,
		f.y - int(profile.h) * UNIT / 2 if profile.get("fly", 0) > 0 else f.ground_y - 160 * UNIT
	)
	var target := Vector2i(world.hero.x, world.hero.y - 145 * UNIT)
	var dx := target.x - origin.x
	var dy := target.y - origin.y
	var duration := maxi(
		1, int(maxi(absi(dx), absi(dy)) / ((820 if enemy.kind == "scanner" else 460) * UNIT / 120))
	)
	bolts.append(
		{
			"x": origin.x,
			"y": origin.y,
			"vx": int(dx / duration),
			"vy": int(dy / duration),
			"lane": f.ground_y,
			"age": 0,
			"damage": roundi(float(profile.damage) * (1.0 if profile.get("boss", false) else 1.65)),
			"color": profile.color,
			"owner": f.slot
		}
	)


func _step_bolts() -> void:
	var alive: Array = []
	for p in bolts:
		p.age += 1
		var from := Vector2i(int(p.x), int(p.y))
		p.x += int(p.vx)
		p.y += int(p.vy)
		var contact := false
		for player in world.players():
			if player.health <= 0 or contact:
				continue
			if absi(player.ground_y - int(p.lane)) <= 42 * UNIT:
				for hurt in player.hurtboxes():
					if not (
						BoxMath.sweep(from, Vector2i(int(p.x), int(p.y)), hurt, 17 * UNIT).is_empty()
					):
						contact = true
						var move := MoveData.new()
						move.damage = int(p.damage)
						move.hitstun = 13
						player.receive_hit(
							move,
							1 if int(p.vx) > 0 else -1,
							player.blocking(MoveData.Level.MID),
							int(p.owner)
						)
						world.events.append(
							{
								"id": "%d:bolt:%d" % [world.tick, int(p.owner)],
								"kind": "block" if player.state == FighterState.Id.BLOCK else "hit",
								"tick": world.tick,
								"character": player.character.id,
								"move": "enemy_shot",
								"slot": player.slot,
								"x": player.x,
								"y": player.y - 145 * UNIT
							}
						)
						break
		if not contact and p.age < 360:
			alive.append(p)
	bolts = alive
