class_name StorySimulation
extends RefCounted
## Campaign simulation: X, lane and jump height remain separate integer coordinates.
const UNIT := FighterModel.SCALE
const PROTOTYPE: CharacterData = preload("res://data/characters/prototype.tres")
var objects: StoryObjects
var boss_phase: int = 1
var hero: FighterModel
var enemies: Array = []
var props: Array = []
var tick: int = 0
var act_index: int = 0
var wave_index: int = 0
var score: int = 0
var remaining_ticks: int = 900 * 120
var act_start_ticks: int = 900 * 120
var completed: bool = false
var defeated: bool = false
var events: Array = []
var camera_x: float = 0.0
var next_id: int = 1
var freeze_ticks: int = 0
var powers := PowerSystem.new()
var projectiles: Array:
	get:
		return powers.projectiles


func _init(character: CharacterData, first_act: int = 0) -> void:
	LegacyRoster.load_catalog()
	objects = StoryObjects.new(self)
	hero = FighterModel.new(character, 0, 220)
	hero.meter = 50
	act_index = first_act
	_start_act()


func act() -> Dictionary:
	return LegacyRoster.catalog.story.acts[act_index]


func _start_act() -> void:
	act_start_ticks = remaining_ticks
	enemies.clear()
	props.clear()
	powers.projectiles.clear()
	var charge := hero.meter
	var life := mini(1000, hero.health + 300)
	hero = FighterModel.new(hero.character, 0, 220)
	hero.health = life
	hero.meter = charge
	wave_index = 0
	hero.x = 220 * UNIT
	hero.y = 625 * UNIT
	hero.ground_y = 625 * UNIT
	hero.transition(FighterState.Id.IDLE)
	boss_phase = 1
	objects.setup(act_index)
	_spawn_wave()


func _spawn_wave() -> void:
	var kinds: Array = act().waves[wave_index] if wave_index < 3 else [act().boss]
	for i in kinds.size():
		var kind: String = kinds[i]
		var p: Dictionary = LegacyRoster.catalog.story.enemies[kind]
		var c := _enemy_character(kind)
		var f := FighterModel.new(c, next_id, mini(3400, 650 + wave_index * 820 + i * 130))
		f.ground_y = (580 + i % 3 * 30) * UNIT
		f.y = f.ground_y
		if float(p.get("fly", 0)) > 0:
			f.y -= 125 * UNIT
		enemies.append(
			{
				"id": next_id,
				"kind": kind,
				"fighter": f,
				"cooldown": 40 + i * 25,
				"dead_tick": -1,
				"attack_serial": 0,
				"fired": false,
				"attack_mode": "melee"
			}
		)
		next_id += 1


func step(value: CombatInput) -> void:
	events.clear()
	powers.events.clear()
	if completed or defeated:
		return
	if freeze_ticks > 0:
		freeze_ticks -= 1
		tick += 1
		return
	remaining_ticks = maxi(0, remaining_ticks - 1)
	if remaining_ticks == 0:
		defeated = true
		return
	value = objects.input(value)
	var lane_input := int(value.has(CombatInput.DOWN)) - int(value.has(CombatInput.UP))
	var old_lane := hero.ground_y
	var vertical := hero.ground_y - hero.y
	hero.ground_y = clampi(hero.ground_y + lane_input * 2 * UNIT, 535 * UNIT, 655 * UNIT)
	hero.y = hero.ground_y - vertical
	# Up/down address lane; Space (JUMP) addresses height. Low attacks remain available.
	var held := value.held & ~CombatInput.UP
	var pressed := value.pressed & ~CombatInput.UP
	if value.pressed & CombatInput.JUMP:
		pressed |= CombatInput.UP
	if not value.has(CombatInput.GUARD):
		held &= ~CombatInput.DOWN
	var nearest_x := hero.x + hero.facing * 200 * UNIT
	var best := 100000000
	for enemy in enemies:
		var f: FighterModel = enemy.fighter
		if f.health > 0 and absi(f.x - hero.x) < best:
			best = absi(f.x - hero.x)
			nearest_x = f.x
	hero.record_input(CombatInput.new(held, pressed), tick)
	var old_x := hero.x
	hero.begin_tick(nearest_x)
	var gate := mini(3560, 880 + wave_index * 820) * UNIT
	hero.x = clampi(hero.x, 70 * UNIT, gate)
	var traveled := absi(hero.x - old_x)
	if (
		hero.character.id in ["marcos", "tais", "luciana", "ruan"]
		and hero.grounded()
		and hero.state in [FighterState.Id.IDLE, FighterState.Id.WALK]
	):
		traveled += absi(hero.ground_y - old_lane)
		if traveled > 0 and hero.state == FighterState.Id.IDLE:
			hero.transition(FighterState.Id.WALK)
	if hero.state == FighterState.Id.WALK:
		hero.walk_distance += traveled
	var boxes: Array[Rect2i] = []
	if not objects.pending_throw:
		boxes.assign(hero.attack_boxes())
	var power := hero.current_move() if hero.state == FighterState.Id.ATTACK else null
	if powers.emit(hero, tick, true):
		freeze_ticks = maxi(freeze_ticks, 20)
	events.append_array(powers.events)
	powers.events.clear()
	var alive := 0
	for enemy in enemies:
		var f: FighterModel = enemy.fighter
		if f.health <= 0:
			if enemy.dead_tick < 0:
				enemy.dead_tick = tick
				score += (
					1000
					if LegacyRoster.catalog.story.enemies[enemy.kind].get("boss", false)
					else 100
				)
			continue
		alive += 1
		var profile: Dictionary = LegacyRoster.catalog.story.enemies[enemy.kind]
		var delta_lane := hero.ground_y - f.ground_y
		var lift := f.ground_y - f.y
		if (
			absi(delta_lane) > 12 * UNIT
			and f.state not in [FighterState.Id.ATTACK, FighterState.Id.HITSTUN]
		):
			f.ground_y += signi(delta_lane) * UNIT
			f.y = f.ground_y - lift
		var distance := absi(f.x - hero.x)
		var enemy_input := 0
		var enemy_edge := 0
		enemy.cooldown -= 1
		var reach := int(profile.range)
		if distance > reach * UNIT:
			enemy_input = CombatInput.RIGHT if hero.x > f.x else CombatInput.LEFT
		elif (
			enemy.cooldown <= 0
			and absi(delta_lane) < 48 * UNIT
			and FighterState.actionable(f.state)
		):
			_prepare_enemy_attack(enemy)
			enemy_edge = CombatInput.KICK
			enemy.cooldown = (
				100 if not LegacyRoster.catalog.story.enemies[enemy.kind].get("boss", false) else 65
			)
		f.record_input(CombatInput.new(enemy_input, enemy_edge), tick)
		f.begin_tick(hero.x)
		if (
			float(profile.get("fly", 0)) > 0
			and not f.knockdown_pending
			and f.vy >= 0
			and (
				f.state
				in [
					FighterState.Id.IDLE,
					FighterState.Id.WALK,
					FighterState.Id.ATTACK,
					FighterState.Id.HITSTUN
				]
			)
		):
			f.y = f.ground_y - int(profile.fly) * UNIT
			f.vy = 0
		if f.state == FighterState.Id.ATTACK and f.current_move().phase(f.move_tick) == "ACTIVE":
			if enemy.attack_mode == "shot" and not enemy.fired:
				objects.fire_enemy(enemy)
				enemy.fired = true
			elif enemy.attack_mode == "teleport" and not enemy.fired:
				f.x = clampi(hero.x - f.facing * 250 * UNIT, 100 * UNIT, 3500 * UNIT)
				f.invincible_ticks = 22
				enemy.fired = true
			elif enemy.attack_mode == "charge":
				f.x = clampi(f.x + f.facing * 460 * UNIT / 120, 70 * UNIT, 3530 * UNIT)
		if absi(delta_lane) <= 50 * UNIT:
			var contact := false
			for hit in boxes:
				for hurt in f.hurtboxes():
					if BoxMath.overlap(hit, hurt):
						contact = true
			if (
				contact
				and not enemy.id in hero.hit_targets
				and (not RollMotion.active(hero) or RollMotion.can_contact(hero, f))
			):
				hero.hit_targets.append(enemy.id)
				_apply_hero_hit(f, power, hero.facing, false, f.x, f.y - 130 * UNIT, "", 0)
			var enemy_boxes: Array[Rect2i] = []
			if enemy.attack_mode != "shot":
				enemy_boxes.assign(f.attack_boxes())
			for hit in enemy_boxes:
				if 0 in f.hit_targets:
					continue
				for hurt in hero.hurtboxes():
					if BoxMath.overlap(hit, hurt):
						f.hit_targets.append(0)
						var guarded: bool = (
							hero.blocking(f.current_move().level) and enemy.attack_mode != "grab"
						)
						hero.receive_hit(f.current_move(), f.facing, guarded, f.slot)
						events.append(
							{
								"id": "%d:enemy:%d" % [tick, f.slot],
								"kind": "block" if guarded else "hit",
								"tick": tick,
								"character": hero.character.id,
								"move": enemy.attack_mode,
								"slot": 0,
								"x": hero.x,
								"y": hero.y - 145 * UNIT
							}
						)
		f.end_tick()
	for contact in powers.advance(power_actors(), 3600, tick):
		var target := _enemy(int(contact.defender))
		if target != null:
			_apply_hero_hit(
				target,
				contact.move,
				int(contact.facing),
				contact.blocked,
				int(contact.impact_x),
				int(contact.impact_y),
				contact.effect,
				int(contact.entity)
			)
	events.append_array(powers.events)
	powers.events.clear()
	objects.step(boxes, power)
	hero.end_tick()
	camera_x = clampf(float(hero.x) / UNIT - 420, 0, 2320)
	if hero.health <= 0:
		defeated = true
	if alive == 0 and wave_index == 3 and act_index == 3 and boss_phase == 1:
		boss_phase = 2
		hero.health = mini(1000, hero.health + 200)
		var f := FighterModel.new(
			_enemy_character("exo"), next_id, mini(3400, int(hero.x / UNIT) + 650)
		)
		f.ground_y = hero.ground_y
		f.y = f.ground_y
		enemies.append(
			{
				"id": next_id,
				"kind": "exo",
				"fighter": f,
				"cooldown": 65,
				"dead_tick": -1,
				"attack_serial": 0,
				"fired": false,
				"attack_mode": "melee"
			}
		)
		next_id += 1
	elif alive == 0 and hero.x >= gate - 180 * UNIT:
		wave_index += 1
		if wave_index == 2:
			objects.drop_medkit(mini(3400 * UNIT, hero.x + 300 * UNIT))
		if wave_index >= 4:
			act_index += 1
			if act_index >= LegacyRoster.catalog.story.acts.size():
				completed = true
			else:
				_start_act()
		else:
			_spawn_wave()
	tick += 1


func snapshot() -> Dictionary:
	var values: Array = []
	for enemy in enemies:
		var e: Dictionary = enemy.duplicate()
		e.fighter = enemy.fighter.snapshot()
		values.append(e)
	return {
		"remaining_ticks": remaining_ticks,
		"act_start_ticks": act_start_ticks,
		"tick": tick,
		"act": act_index,
		"wave": wave_index,
		"hero": hero.snapshot(),
		"enemies": values,
		"props": props.duplicate(true),
		"objects": objects.snapshot(),
		"boss_phase": boss_phase,
		"score": score,
		"completed": completed,
		"defeated": defeated,
		"freeze": freeze_ticks,
		"powers": powers.snapshot(),
		"next_id": next_id
	}


func power_actors() -> Array[FighterModel]:
	var result: Array[FighterModel] = [hero]
	for enemy in enemies:
		result.append(enemy.fighter)
	return result


func _enemy(slot: int) -> FighterModel:
	for enemy in enemies:
		if int(enemy.id) == slot:
			return enemy.fighter
	return null


func _apply_hero_hit(
	target: FighterModel,
	move: MoveData,
	facing: int,
	blocked: bool,
	x: int,
	y: int,
	effect: String,
	entity: int
) -> void:
	var rolling := RollMotion.active(hero) and entity == 0
	if rolling:
		move = RollMotion.contact_move(hero)
	hero.has_contact = true
	if not blocked:
		hero.meter = mini(100, hero.meter + int(move.legacy.get("meter", 8)))
		hero.connect_hit(target, move)
	target.receive_hit(move, facing, blocked, hero.slot, hero.combo, hero.scaled_damage(move))
	if rolling:
		RollMotion.contact(hero, target, blocked)
	freeze_ticks = maxi(freeze_ticks, move.hitstop * 2)
	events.append(
		{
			"id": "%d:hit:%d:%d" % [tick, target.slot, entity],
			"kind": "block" if blocked else "hit",
			"tick": tick,
			"character": hero.character.id,
			"move": move.id,
			"slot": target.slot,
			"facing": facing,
			"x": x,
			"y": y,
			"effect": "electricRoll" if rolling else effect,
			"power_kind":
			(
				"roll"
				if rolling
				else (
					"projectile"
					if entity > 0
					else (
						"strike"
						if move.legacy.get("name", "") in ["uppercut", "super", "special"]
						else ""
					)
				)
			)
		}
	)


static func _enemy_character(kind: String) -> CharacterData:
	var p: Dictionary = LegacyRoster.catalog.story.enemies[kind]
	var c := CharacterData.new()
	c.id = "enemy_" + kind
	c.max_health = int(p.hp)
	c.speed_units = roundi(float(p.speed) * UNIT / 120)
	c.back_speed_units = c.speed_units
	# Collision dimensions follow each enemy image, rather than the 192px mannequin.
	var w := roundi(float(p.w) * 0.72)
	var h := roundi(float(p.h) * 0.92)
	c.body_rects.assign([Rect2i(-w / 2, -h, w, h)])
	c.jab = PROTOTYPE.jab
	c.kick = PROTOTYPE.kick
	c.sweep = PROTOTYPE.sweep
	c.air_kick = PROTOTYPE.air_kick
	return c


func restore(data: Dictionary) -> void:
	data = SnapshotCodec.integers(data)
	remaining_ticks = int(data.get("remaining_ticks", 900 * 120))
	act_start_ticks = int(data.get("act_start_ticks", remaining_ticks))
	tick = int(data.tick)
	act_index = int(data.act)
	wave_index = int(data.wave)
	score = int(data.score)
	completed = data.completed
	defeated = data.defeated
	freeze_ticks = int(data.freeze)
	next_id = int(data.next_id)
	hero.restore(data.hero)
	enemies.clear()
	for raw in data.enemies:
		var e: Dictionary = raw.duplicate(true)
		var f := FighterModel.new(_enemy_character(e.kind), int(e.id), 0)
		e.fighter = f
		if str(raw.fighter.move_id).begins_with("enemy_"):
			# _prepare increments serial; compensate to reconstruct the same move.
			e.attack_serial = int(e.get("attack_serial", 1)) - 1
			var was_fired: bool = e.get("fired", false)
			_prepare_enemy_attack(e)
			e.fired = was_fired
		f.restore(raw.fighter)
		e.fighter = f
		enemies.append(e)
	props = data.props.duplicate(true)
	boss_phase = int(data.get("boss_phase", 1))
	objects.restore(data.get("objects", {}))
	powers.restore(data.powers)
	camera_x = clampf(float(hero.x) / UNIT - 420, 0, 2320)
	events.clear()


func retry_act() -> void:
	remaining_ticks = act_start_ticks
	completed = false
	defeated = false
	hero.health = 1000
	freeze_ticks = 0
	_start_act()


func _prepare_enemy_attack(enemy: Dictionary) -> void:
	var f: FighterModel = enemy.fighter
	var p: Dictionary = LegacyRoster.catalog.story.enemies[enemy.kind]
	enemy.attack_serial += 1
	enemy.fired = false
	var serial := int(enemy.attack_serial)
	var mode := "shot" if p.get("ranged", false) else "melee"
	match str(enemy.kind):
		"inspector":
			mode = "charge" if serial % 3 == 0 else "grab" if serial % 3 == 2 else "staff"
		"fairRobot":
			mode = "flame"
		"substitute":
			mode = "shot" if serial % 3 == 0 else "staff"
		"aula":
			mode = "shot" if serial % 2 else "teleport"
		"exo":
			mode = "slam" if serial % 2 else "charge"
	enemy.attack_mode = mode
	var move := MoveData.new()
	move.id = "enemy_" + mode
	move.startup = 27 if p.get("boss", false) else 10
	move.active = 45 if mode == "flame" else 33 if mode == "charge" else 15
	move.recovery = 27 if p.get("boss", false) else 15
	move.damage = roundi(float(p.damage) * (1.0 if p.get("boss", false) else 1.65))
	move.hitstun = 18
	move.level = MoveData.Level.LOW if mode == "slam" else MoveData.Level.MID
	move.legacy = {
		"name": mode,
		"knockdown": mode in ["charge", "slam", "grab"],
		"launch": 300 if mode in ["charge", "slam", "grab"] else 0
	}
	var box := HitboxData.new()
	box.rect = Rect2i(0, -int(p.h), int(p.range), int(p.h))
	box.first_frame = move.startup
	box.end_frame = move.startup + move.active
	move.hitboxes.assign([box])
	f.character.kick = move


func state_hash() -> String:
	return SnapshotCodec.state_hash(snapshot())
