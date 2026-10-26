class_name CoopStorySimulation
extends StorySimulation
## Two independently animated heroes, one deterministic campaign world.
const PARTNER_SLOT := 1000000  # Disjoint from all original enemy/prop IDs.
var heroes: Array[FighterModel] = []
var gear: Array = []


func _init(first: CharacterData, second: CharacterData) -> void:
	super(first)
	heroes = [hero, FighterModel.new(OpenBorCombat.character(second), PARTNER_SLOT, 320)]
	heroes[1].ground_y = 590 * UNIT
	heroes[1].y = heroes[1].ground_y
	heroes[1].campaign_costs = true
	heroes[1].meter = 0
	gear = [objects, StoryObjects.new(self)]
	powers.friendly_slots = [0, PARTNER_SLOT]


func players() -> Array[FighterModel]:
	return heroes


func object_sets() -> Array:
	return gear


func power_actors() -> Array[FighterModel]:
	var result: Array[FighterModel] = heroes.duplicate()
	for enemy in enemies:
		result.append(enemy.fighter)
	return result


func _nearest(target: FighterModel) -> FighterModel:
	var nearest := heroes[0]
	var best := 1 << 60
	for actor in heroes:
		var distance := absi(actor.x - target.x) + absi(actor.ground_y - target.ground_y) * 2
		if actor.health > 0 and distance < best:
			best = distance
			nearest = actor
	return nearest


func _party_progress() -> int:
	var progress := 3560 * UNIT
	for actor in heroes:
		if actor.health > 0:
			progress = mini(progress, actor.x)
	return progress


func step_party(values: Array[CombatInput]) -> void:
	assert(values.size() == 2)
	events.clear()
	powers.events.clear()
	if completed or defeated:
		tick += 1  # Online peers must still confirm the terminal result.
		return
	if freeze_ticks > 0:
		for i in 2:
			combat.buffer_input(heroes[i], values[i])
		freeze_ticks -= 1
		tick += 1
		return
	remaining_ticks = maxi(0, remaining_ticks - 1)
	if remaining_ticks == 0:
		defeated = true
		return
	FuryCheckpoint.pump(self)
	var actions: Array = []
	for i in 2:
		hero = heroes[i]
		objects = gear[i]
		var value := combat.take_input(hero, values[i]) if hero.health > 0 else CombatInput.new()
		var partner := heroes[1 - i]
		if hero.health > 0 and partner.health <= 0 and value.pressed & CombatInput.THROW \
			and absi(hero.x - partner.x) < 130 * UNIT and absi(hero.ground_y - partner.ground_y) < 45 * UNIT \
			and FighterState.actionable(hero.state) and hero.grounded():
			partner.health = 300
			partner.invincible_ticks = 120
			partner.transition(FighterState.Id.IDLE)
			value = CombatInput.new(value.held, value.pressed & ~CombatInput.THROW)
			events.append({"id": "%d:revive:%d" % [tick, i], "kind": "revive", "slot": partner.slot})
		actions.append(_move_actor(value))
		hero.x = clampi(hero.x, partner.x - 1040 * UNIT, partner.x + 1040 * UNIT)
	var gate := StoryLayout.gate(wave_index) * UNIT
	var alive := spawn_queue.size()
	for enemy in enemies:
		var f: FighterModel = enemy.fighter
		if f.health <= 0:
			if enemy.dead_tick < 0:
				enemy.dead_tick = tick
				score += 1000 if LegacyRoster.catalog.story.enemies[enemy.kind].get("boss", false) else 100
			f.record_input(CombatInput.new(), tick)
			f.begin_tick(f.x + f.facing * UNIT)
			combat.advance_throw(self, f)
			f.end_tick()
			continue
		alive += 1
		hero = _nearest(f)
		objects = gear[0]
		var profile: Dictionary = LegacyRoster.catalog.story.enemies[enemy.kind]
		var enemy_lane := f.ground_y
		var enemy_x := f.x
		var enemy_input := OpenBorEnemyMotion.intent(self, enemy, hero)
		var delta_lane := hero.ground_y - f.ground_y
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
		for i in 2:
			hero = heroes[i]
			objects = gear[i]
			var boxes: Array[Rect2i] = actions[i].boxes
			var power: MoveData = actions[i].power
			if hero.health > 0 and absi(hero.ground_y - f.ground_y) <= 50 * UNIT:
				var contact := false
				var impact := Vector2i(f.x, f.y - 130 * UNIT)
				for hit in boxes:
					var aligned := hit
					aligned.position.y += f.ground_y - hero.ground_y
					for hurt in f.hurtboxes():
						if BoxMath.overlap(aligned, hurt):
							contact = true
							var overlap := aligned.intersection(hurt)
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
					var aligned := hit
					aligned.position.y += hero.ground_y - f.ground_y
					if hero.slot in f.hit_targets:
						continue
					for hurt in hero.hurtboxes():
						if BoxMath.overlap(aligned, hurt):
							f.hit_targets.append(hero.slot)
							var guarded: bool = (
								hero.blocking(f.current_move().level) and enemy.attack_mode != "grab"
							)
							hero.receive_hit(f.current_move(), f.facing, guarded, f.slot)
							events.append(
								{
									"id": "%d:enemy:%d:%d" % [tick, f.slot, hero.slot],
									"kind": "block" if guarded else "hit",
									"tick": tick,
									"character": hero.character.id,
									"move": enemy.attack_mode,
									"slot": hero.slot,
									"x": hero.x,
									"y": hero.y - 145 * UNIT
								}
							)
							break
		f.x = clampi(f.x, 70 * UNIT, gate - 60 * UNIT)
		f.end_tick()
	for contact in powers.advance(power_actors(), 3600, tick):
		var target := _enemy(int(contact.defender))
		if target != null:
			hero = heroes[0] if int(contact.attacker) == 0 else heroes[1]
			_apply_hero_hit(target, contact.move, int(contact.facing), contact.blocked,
				int(contact.impact_x), int(contact.impact_y), contact.effect, int(contact.entity))
	events.append_array(powers.events)
	powers.events.clear()
	for i in 2:
		hero = heroes[i]
		objects = gear[i]
		objects.step(actions[i].boxes, actions[i].power, i == 0)
		hero.end_tick()
	hero = heroes[0]
	objects = gear[0]
	update_camera((heroes[0].x + heroes[1].x) / 2 - 640 * UNIT)
	if heroes.all(func(actor): return actor.health <= 0):
		defeated = true
		tick += 1
		return
	if alive == 0 and wave_index == 3 and act_index == 3 and boss_phase == 1:
		boss_phase = 2
		for actor in heroes:
			actor.health = mini(1000, actor.health + 200)
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
	elif alive == 0 and _party_progress() >= gate - 180 * UNIT:
		wave_index += 1
		if wave_index == 2:
			objects.drop_medkit(mini(3400 * UNIT, hero.x + 300 * UNIT))
		if wave_index >= 4:
			act_index += 1
			if act_index >= LegacyRoster.catalog.story.acts.size():
				completed = true
			else:
				_new_act()
		else:
			_spawn_wave()
	tick += 1


func _move_actor(value: CombatInput) -> Dictionary:
	value = objects.input(value)
	var action := combat.advance(self, hero, objects, value)
	if powers.emit(hero, tick, true):
		freeze_ticks = maxi(freeze_ticks, 20)
	events.append_array(powers.events)
	powers.events.clear()
	return action


func _apply_hero_hit(target: FighterModel, move: MoveData, facing: int, blocked: bool,
	x: int, y: int, effect: String, entity: int) -> void:
	super(target, move, facing, blocked, x, y, effect, entity)
	if not events.is_empty():
		events[-1].id = str(events[-1].id) + ":" + str(hero.slot)


func _new_act() -> void:
	var partner := heroes[1]
	hero = heroes[0]
	objects = gear[0]
	_start_act()
	heroes[0] = hero
	heroes[1] = FighterModel.new(OpenBorCombat.character(partner.character), PARTNER_SLOT, 320)
	heroes[1].health = mini(1000, partner.health + 300)
	heroes[1].meter = partner.meter
	heroes[1].campaign_costs = true
	heroes[1].ground_y = 590 * UNIT
	heroes[1].y = heroes[1].ground_y
	gear[1] = StoryObjects.new(self)


func retry_act() -> void:
	remaining_ticks = act_start_ticks
	completed = false
	defeated = false
	freeze_ticks = 0
	for actor in heroes:
		actor.health = 1000
	_new_act()


func snapshot() -> Dictionary:
	var data := super()
	data.partner = heroes[1].snapshot()
	data.partner_gear = gear[1].snapshot()
	data.coop = true
	return data


func restore(data: Dictionary) -> void:
	hero = heroes[0]
	objects = gear[0]
	super(data)
	heroes[0] = hero
	heroes[1].restore(SnapshotCodec.integers(data.partner))
	heroes[1].campaign_costs = true
	gear[1].restore(SnapshotCodec.integers(data.get("partner_gear", {})))
	camera_units = int(data.get("camera_units", clampi((heroes[0].x + heroes[1].x) / 2 - 640 * UNIT, 0, StoryLayout.camera_limit(wave_index) * UNIT)))
