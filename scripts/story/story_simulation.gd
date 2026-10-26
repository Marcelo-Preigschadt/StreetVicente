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
var camera_units: int = 0
var camera_x: float:
	get:
		return float(camera_units) / UNIT
	set(value):
		camera_units = roundi(value * UNIT)
var next_id: int = 1
var freeze_ticks: int = 0
var powers := PowerSystem.new()
var combat := OpenBorCombat.new()
var spawn_queue: Array = []
var spawn_due: int = 0
var projectiles: Array:
	get:
		return powers.projectiles


func _init(character: CharacterData, first_act: int = 0) -> void:
	LegacyRoster.load_catalog()
	objects = StoryObjects.new(self)
	hero = FighterModel.new(OpenBorCombat.character(character), 0, 220)
	hero.campaign_costs = true
	hero.meter = 0
	act_index = first_act
	_start_act()


func act() -> Dictionary:
	return LegacyRoster.catalog.story.acts[act_index]


func _start_act() -> void:
	act_start_ticks = remaining_ticks
	combat.actors.clear()
	enemies.clear()
	props.clear()
	powers.projectiles.clear()
	var charge := hero.meter
	var life := mini(1000, hero.health + 300)
	hero = FighterModel.new(OpenBorCombat.character(hero.character), 0, 220)
	hero.health = life
	hero.campaign_costs = true
	hero.meter = charge
	wave_index = 0
	hero.x = 220 * UNIT
	hero.y = 625 * UNIT
	hero.ground_y = 625 * UNIT
	hero.transition(FighterState.Id.IDLE)
	camera_units = 0
	boss_phase = 1
	objects.setup(act_index)
	_spawn_wave()


func _spawn_wave() -> void:
	FuryCheckpoint.begin(self)


func _spawn_enemy(entry: Dictionary) -> void:
	var kind: String = entry.kind
	var p: Dictionary = LegacyRoster.catalog.story.enemies[kind]
	var f := FighterModel.new(_enemy_character(kind), next_id, int(entry.x))
	f.ground_y = int(entry.lane) * UNIT
	f.y = f.ground_y - int(p.get("fly", 0)) * UNIT
	enemies.append({"id": next_id, "kind": kind, "fighter": f,
		"cooldown": int(entry.cooldown), "dead_tick": -1, "spawn_tick": tick,
		"attack_serial": 0, "fired": false, "attack_mode": "melee",
		"engagement_slot": -1, "engagement_target": -1})
	next_id += 1


func step(value: CombatInput) -> void:
	events.clear()
	powers.events.clear()
	if completed or defeated:
		return
	if freeze_ticks > 0:
		combat.buffer_input(hero, value)
		freeze_ticks -= 1
		tick += 1
		return
	remaining_ticks = maxi(0, remaining_ticks - 1)
	if remaining_ticks == 0:
		defeated = true
		return
	FuryCheckpoint.pump(self)
	value = combat.take_input(hero, value)
	value = objects.input(value)
	var action := combat.advance(self, hero, objects, value)
	var gate := StoryLayout.gate(wave_index) * UNIT
	var boxes: Array[Rect2i] = action.boxes
	var power: MoveData = action.power
	if powers.emit(hero, tick, true):
		freeze_ticks = maxi(freeze_ticks, 20)
	events.append_array(powers.events)
	powers.events.clear()
	var alive := spawn_queue.size()
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
			f.record_input(CombatInput.new(), tick)
			f.begin_tick(f.x + f.facing * UNIT)
			combat.advance_throw(self, f)
			f.end_tick()
			continue
		alive += 1
		var profile: Dictionary = LegacyRoster.catalog.story.enemies[enemy.kind]
		var enemy_lane := f.ground_y
		var enemy_x := f.x
		var enemy_input := OpenBorEnemyMotion.intent(self, enemy, hero)
		f.record_input(enemy_input, tick)
		f.begin_tick(hero.x)
		OpenBorEnemyMotion.finish(f, profile, enemy_x, enemy_lane)
		combat.advance_throw(self, f)
		objects.constrain_actor(f, enemy_x, enemy_lane)
		OpenBorEnemyMotion.record_walk(f, enemy_x, enemy_lane)
		if f.state == FighterState.Id.ATTACK and f.current_move().phase(f.move_tick) == "ACTIVE":
			if enemy.attack_mode == "shot" and not enemy.fired:
				objects.fire_enemy(enemy)
				enemy.fired = true
			elif enemy.attack_mode == "teleport" and not enemy.fired:
				f.x = clampi(hero.x - f.facing * 250 * UNIT, 100 * UNIT, 3500 * UNIT)
				f.invincible_ticks = 22
				enemy.fired = true
			elif enemy.attack_mode in ["charge", "dash"]:
				var from_x := f.x
				f.x = clampi(f.x + f.facing * 460 * UNIT / 120, 70 * UNIT, 3530 * UNIT)
				objects.constrain_actor(f, from_x, f.ground_y)
				f.walk_distance += absi(f.x - from_x)
				if f.x == from_x:
					f.move_tick = (f.current_move().startup + f.current_move().active) * 2
		if absi(hero.ground_y - f.ground_y) <= 42 * UNIT:
			var contact := false
			var impact := Vector2i(f.x, f.y - 130 * UNIT)
			for hit in boxes:
				for hurt in f.hurtboxes():
					if BoxMath.overlap(hit, hurt):
						contact = true
						var overlap := hit.intersection(hurt)
						impact = overlap.position + overlap.size / 2
			if (
				contact
				and not enemy.id in hero.hit_targets
				and (not RollMotion.active(hero) or RollMotion.can_contact(hero, f))
			):
				hero.hit_targets.append(enemy.id)
				_apply_hero_hit(f, power, hero.facing, f.blocking(power.level), impact.x, impact.y, "", 0)
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
						break  # One contact per victim, not one per overlapping hurtbox row.
		f.x = clampi(f.x, 70 * UNIT, gate - 60 * UNIT)
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
	update_camera(hero.x - 420 * UNIT)
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
				"spawn_tick": tick,
				"engagement_slot": -1,
				"engagement_target": -1,
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
		"story_revision": 28,
		"camera_units": camera_units,
		"combat": combat.snapshot(),
		"spawn_queue": spawn_queue.duplicate(true),
		"spawn_due": spawn_due,
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


func players() -> Array[FighterModel]:
	return [hero]


func object_sets() -> Array:
	return [objects]


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
	combat.contact(hero, tick)
	if not blocked:
		if move_cost_earns_energy(move):
			hero.meter = mini(100, hero.meter + maxi(8, int(move.legacy.get("meter", 8))))
		hero.connect_hit(target, move)
	target.receive_hit(move, facing, blocked, hero.slot, hero.combo, hero.scaled_damage(move))
	# Ordinary campaign machines use the source hurt/fall/recover cycle; no
	# long versus dizziness lock after the player's fourth confirmed normal.
	if not LegacyRoster.catalog.story.enemies[target.character.id.trim_prefix("enemy_")].get("boss", false):
		target.dizzy_pending = 0
		target.stun_gauge = 0
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
	combat.restore(data.get("combat", {}))
	spawn_queue = data.get("spawn_queue", []).duplicate(true)
	spawn_due = int(data.get("spawn_due", tick))
	hero.campaign_costs = true
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
	if int(data.get("story_revision", 23)) < 24:
		objects.migrate_layout()
	boss_phase = int(data.get("boss_phase", 1))
	objects.restore(data.get("objects", {}))
	if int(data.get("story_revision", 23)) < 27:
		objects.migrate_stage()
	if int(data.get("story_revision", 23)) < 28:
		StoryScenery.populate(self)
	powers.restore(data.powers)
	camera_units = int(data.get("camera_units", clampi(hero.x - 420 * UNIT, 0, StoryLayout.camera_limit(wave_index) * UNIT)))
	events.clear()


func update_camera(target: int) -> void:
	target = clampi(target, 0, StoryLayout.camera_limit(wave_index) * UNIT)
	camera_units += clampi(target - camera_units, -8 * UNIT, 8 * UNIT)


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
	if not p.get("ranged", false) and not p.get("boss", false):
		var pattern: Array = ["melee", "kick", "heavy", "sweep"]
		if str(enemy.kind) in ["cleaner", "kungfu"]:
			pattern = ["melee", "kick", "dash", "sweep"]
		elif str(enemy.kind) == "elite":
			pattern = ["kick", "heavy", "dash", "melee"]
		mode = str(pattern[(serial - 1 + int(enemy.id) % 2) % pattern.size()])
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
	move.startup = 28 if p.get("boss", false) else 20
	move.active = 45 if mode == "flame" else 33 if mode == "charge" else 6
	move.recovery = 24 if p.get("boss", false) else 18
	if mode == "melee":
		move.startup = 14
		move.recovery = 14
	elif mode == "heavy":
		move.startup = 32
		move.recovery = 30
	elif mode == "sweep":
		move.startup = 25
	elif mode == "dash":
		move.startup = 26
		move.active = 16
		move.recovery = 28
	elif mode == "shot":
		move.startup = 30
	move.damage = roundi(float(p.damage) * (1.2 if mode == "heavy" else .85 if mode == "melee" else 1.0))
	move.hitstun = 18
	move.level = MoveData.Level.LOW if mode in ["slam", "sweep"] else MoveData.Level.OVERHEAD if mode == "heavy" else MoveData.Level.MID
	move.legacy = {
		"name": mode,
		"knockdown": mode in ["charge", "slam", "grab", "heavy"],
		"launch": 300 if mode in ["charge", "slam", "grab", "heavy"] else 0
	}
	var box := HitboxData.new()
	# The arm strikes at chest height; a whole torso-sized rectangle caused
	# invisible hits during unrelated poses. Charges/slams retain body contact.
	box.rect = Rect2i(35, -roundi(float(p.h) * .76), maxi(45, int(p.range) - 35), roundi(float(p.h) * .25))
	if mode == "kick":
		box.rect = Rect2i(45, -roundi(float(p.h) * .61), maxi(60, int(p.range) - 30), roundi(float(p.h) * .2))
	elif mode == "sweep":
		box.rect = Rect2i(35, -95, maxi(80, int(p.range) - 15), 80)
	elif mode == "heavy":
		box.rect = Rect2i(25, -roundi(float(p.h) * .74), int(p.range), roundi(float(p.h) * .4))
	elif mode == "dash":
		box.rect = Rect2i(0, -roundi(float(p.h) * .76), 145, roundi(float(p.h) * .56))
	if mode in ["charge", "grab", "flame"]:
		box.rect = Rect2i(0, -int(p.h) * 3 / 4, int(p.range), int(p.h) * 3 / 4)
	elif mode == "slam":
		box.rect = Rect2i(0, -90, int(p.range), 90)
	box.first_frame = move.startup
	box.end_frame = move.startup + move.active
	move.hitboxes.assign([box])
	f.character.kick = move
	f.character.air_kick = move


func state_hash() -> String:
	return SnapshotCodec.state_hash(snapshot())


static func move_cost_earns_energy(move: MoveData) -> bool:
	return str(move.legacy.get("name", "")) not in ["special", "uppercut", "drone", "super"]
