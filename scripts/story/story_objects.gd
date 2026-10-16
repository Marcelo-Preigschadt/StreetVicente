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


func _init(owner_world: StorySimulation) -> void:
	owner_ref = weakref(owner_world)


func setup(act: int) -> void:
	carry.clear()
	thrown.clear()
	bolts.clear()
	hazards.clear()
	pending_throw = false
	pickup_ticks = 0
	world.props.clear()
	for i in 3:
		var x: int = [640, 1650, 2590][i]
		if act == 0:
			x = [2100, 2650, 3200][i]
			_add_prop("table", x, 595, 160)
			_add_prop("chair", x + 160, 610, 80)
			_add_prop("chair", x - 150, 565, 80)
			if i < 2:
				_add_prop("soda", [1800, 3500][i], 540, 200)
		elif act == 2:
			_add_prop("shelf", x + 240, 550, 110)
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


func input(value: CombatInput) -> CombatInput:
	var f := world.hero
	pickup_ticks = maxi(0, pickup_ticks - 1)
	if (
		f.health <= 0
		or not f.grounded()
		or not FighterState.actionable(f.state)
		or pickup_ticks > 0
	):
		return value
	if not carry.is_empty() and value.pressed & (CombatInput.PUNCH | CombatInput.THROW):
		pending_throw = true
		pickup_ticks = 26
		return CombatInput.new(
			value.held & ~CombatInput.PUNCH,
			(value.pressed & ~CombatInput.PUNCH) | CombatInput.THROW
		)
	if carry.is_empty() and value.pressed & (CombatInput.PUNCH | CombatInput.THROW):
		var nearest: Dictionary = {}
		var distance := 100000000
		for p in world.props:
			if p.get("used", false) or p.hp <= 0 or p.kind not in ["table", "chair", "shelf"]:
				continue
			var gap := absi(int(p.x) - f.x)
			if (
				absi(int(p.lane) - f.ground_y) <= 42 * UNIT
				and gap < (bounds(p).size.x / 2 + 50 * UNIT)
				and gap < distance
			):
				nearest = p
				distance = gap
		if not nearest.is_empty():
			if nearest.kind == "shelf":
				damage(nearest, int(nearest.hp))
			else:
				nearest.used = true
				carry = {"kind": nearest.kind, "id": nearest.id}
				pickup_ticks = 22
			return CombatInput.new(
				value.held & ~(CombatInput.PUNCH | CombatInput.THROW),
				value.pressed & ~(CombatInput.PUNCH | CombatInput.THROW)
			)
	return value


func bounds(prop: Dictionary) -> Rect2i:
	var art: Dictionary = LegacyRoster.catalog.story.props[prop.kind]
	var width := roundi(float(art.width) * UNIT)
	var height := roundi(float(art.height) * UNIT)
	return Rect2i(int(prop.x) - width / 2, int(prop.lane) - height, width, height)


func damage(prop: Dictionary, amount: int) -> void:
	if prop.get("used", false) or prop.hp <= 0:
		return
	prop.hp -= amount
	if prop.kind == "soda" and prop.cooldown <= 0:
		prop.cooldown = 84
		_throw(
			"can",
			int(prop.x),
			int(prop.lane) - 160 * UNIT,
			int(prop.lane),
			world.hero.facing,
			520,
			-500
		)
	if prop.hp <= 0:
		prop.used = true
		if prop.kind == "shelf":
			prop.fall = 1


func step(boxes: Array[Rect2i], move: MoveData) -> void:
	var f := world.hero
	if (
		not carry.is_empty()
		and f.state in [FighterState.Id.HITSTUN, FighterState.Id.KO, FighterState.Id.DIZZY]
	):
		_throw(carry.kind, f.x, f.y - 170 * UNIT, f.ground_y, -f.facing, 100, -100)
		carry.clear()
		pending_throw = false
	if pending_throw:
		if f.state != FighterState.Id.ATTACK or f.current_move().legacy.get("name", "") != "throw":
			pending_throw = false
		elif f.current_move().phase(f.move_tick) == "ACTIVE":
			_throw(
				carry.kind,
				f.x + f.facing * 45 * UNIT,
				f.y - 165 * UNIT,
				f.ground_y,
				f.facing,
				700,
				-340
			)
			carry.clear()
			pending_throw = false
	for p in world.props:
		p.cooldown = maxi(0, int(p.get("cooldown", 0)) - 1)
		if (
			p.kind == "medkit"
			and not p.used
			and f.grounded()
			and absi(int(p.x) - f.x) < 85 * UNIT
			and absi(int(p.lane) - f.ground_y) < 42 * UNIT
		):
			p.used = true
			f.health = mini(1000, f.health + 220)
		if p.get("fall", 0) > 0:
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
	_step_hazards()
	_step_bolts()


func drop_medkit(x: int) -> void:
	_add_prop("medkit", x / UNIT, 625, 1)


func _throw(kind: String, x: int, y: int, lane: int, direction: int, speed: int, lift: int) -> void:
	thrown.append(
		{
			"kind": kind,
			"x": x,
			"y": y,
			"lane": lane,
			"vx": int(direction * speed * UNIT / 120),
			"vy": int(lift * UNIT / 120),
			"age": 0,
			"hits": []
		}
	)


func _step_thrown() -> void:
	var alive: Array = []
	for p in thrown:
		p.age += 1
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
		if p.y >= p.lane:
			if p.kind == "can":
				for enemy in world.enemies:
					var target: FighterModel = enemy.fighter
					if (
						target.slot not in p.hits
						and absi(target.x - int(p.x)) < 210 * UNIT
						and absi(target.ground_y - int(p.lane)) < 65 * UNIT
					):
						_environment_hit(target, 110, int(p.x))
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
		"pending": pending_throw,
		"pickup_ticks": pickup_ticks,
		"thrown": thrown.duplicate(true),
		"bolts": bolts.duplicate(true),
		"hazards": hazards.duplicate(true)
	}


func restore(data: Dictionary) -> void:
	carry = data.get("carry", {}).duplicate(true)
	pending_throw = data.get("pending", false)
	pickup_ticks = int(data.get("pickup_ticks", 0))
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
		if absi(world.hero.ground_y - int(p.lane)) <= 42 * UNIT:
			for hurt in world.hero.hurtboxes():
				if not (
					BoxMath.sweep(from, Vector2i(int(p.x), int(p.y)), hurt, 17 * UNIT).is_empty()
				):
					contact = true
					var move := MoveData.new()
					move.damage = int(p.damage)
					move.hitstun = 13
					world.hero.receive_hit(
						move,
						1 if int(p.vx) > 0 else -1,
						world.hero.blocking(MoveData.Level.MID),
						int(p.owner)
					)
					world.events.append(
						{
							"id": "%d:bolt:%d" % [world.tick, int(p.owner)],
							"kind": "block" if world.hero.state == FighterState.Id.BLOCK else "hit",
							"tick": world.tick,
							"character": world.hero.character.id,
							"move": "enemy_shot",
							"slot": 0,
							"x": world.hero.x,
							"y": world.hero.y - 145 * UNIT
						}
					)
					break
		if not contact and p.age < 360:
			alive.append(p)
	bolts = alive
