class_name StorySimulation
extends RefCounted
## Campaign simulation: X, lane and jump height remain separate integer coordinates.
const UNIT := FighterModel.SCALE
const PROTOTYPE: CharacterData = preload("res://data/characters/prototype.tres")
var hero: FighterModel
var enemies: Array = []
var props: Array = []
var tick: int = 0
var act_index: int = 0
var wave_index: int = 0
var score: int = 0
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
	hero = FighterModel.new(character, 0, 220)
	hero.meter = 50
	act_index = first_act
	_start_act()


func act() -> Dictionary:
	return LegacyRoster.catalog.story.acts[act_index]


func _start_act() -> void:
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
	for i in 6:
		props.append(
			{
				"id": next_id,
				"kind": "table" if i % 2 == 0 else "chair",
				"x": (480 + i * 470) * UNIT,
				"lane": (595 + i % 2 * 40) * UNIT,
				"hp": 120,
				"hit_ids": []
			}
		)
		next_id += 1
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
			{"id": next_id, "kind": kind, "fighter": f, "cooldown": 40 + i * 25, "dead_tick": -1}
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
	var lane_input := int(value.has(CombatInput.DOWN)) - int(value.has(CombatInput.UP))
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
	if hero.state == FighterState.Id.WALK:
		hero.walk_distance += absi(hero.x - old_x)
	var boxes := hero.attack_boxes()
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
			continue
		alive += 1
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
		if distance > 120 * UNIT:
			enemy_input = CombatInput.RIGHT if hero.x > f.x else CombatInput.LEFT
		elif enemy.cooldown <= 0 and absi(delta_lane) < 48 * UNIT:
			enemy_edge = CombatInput.KICK
			enemy.cooldown = (
				100 if not LegacyRoster.catalog.story.enemies[enemy.kind].get("boss", false) else 65
			)
		f.record_input(CombatInput.new(enemy_input, enemy_edge), tick)
		f.begin_tick(hero.x)
		if absi(delta_lane) <= 50 * UNIT:
			var contact := false
			for hit in boxes:
				for hurt in f.hurtboxes():
					if BoxMath.overlap(hit, hurt):
						contact = true
			if contact and not enemy.id in hero.hit_targets:
				hero.hit_targets.append(enemy.id)
				_apply_hero_hit(f, power, hero.facing, false, f.x, f.y - 130 * UNIT, "", 0)
			for hit in f.attack_boxes():
				if 0 in f.hit_targets:
					continue
				for hurt in hero.hurtboxes():
					if BoxMath.overlap(hit, hurt):
						f.hit_targets.append(0)
						hero.receive_hit(
							f.current_move(), f.facing, hero.blocking(MoveData.Level.MID)
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
	for prop in props:
		if prop.hp <= 0:
			continue
		if (
			power != null
			and not prop.id in hero.hit_targets
			and absi(int(prop.lane) - hero.ground_y) < 70 * UNIT
			and absi(int(prop.x) - hero.x) < 170 * UNIT
			and hero.move_tick >= power.startup * 2
			and hero.move_tick < (power.startup + power.active) * 2
		):
			hero.hit_targets.append(prop.id)
			prop.hp -= power.damage
			if prop.hp <= 0:
				score += 100
				hero.health = mini(1000, hero.health + 60)
	hero.end_tick()
	camera_x = clampf(float(hero.x) / UNIT - 420, 0, 2320)
	if hero.health <= 0:
		defeated = true
	if alive == 0 and hero.x >= gate - 180 * UNIT:
		wave_index += 1
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
		"tick": tick,
		"act": act_index,
		"wave": wave_index,
		"hero": hero.snapshot(),
		"enemies": values,
		"props": props.duplicate(true),
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
	hero.has_contact = true
	if not blocked:
		hero.meter = mini(100, hero.meter + int(move.legacy.get("meter", 8)))
		hero.combo += 1
		hero.combo_ticks = 100
		score += move.damage
	target.receive_hit(move, facing, blocked)
	freeze_ticks = maxi(freeze_ticks, move.hitstop * 2)
	events.append(
		{
			"id": "%d:hit:%d:%d" % [tick, target.slot, entity],
			"kind": "block" if blocked else "hit",
			"tick": tick,
			"character": hero.character.id,
			"move": move.id,
			"slot": target.slot,
			"x": x,
			"y": y,
			"effect": effect,
			"power_kind": "projectile" if entity > 0 else ""
		}
	)


static func _enemy_character(kind: String) -> CharacterData:
	var p: Dictionary = LegacyRoster.catalog.story.enemies[kind]
	var c := CharacterData.new()
	c.id = "enemy_" + kind
	c.max_health = int(p.hp)
	c.speed_pixels_per_tick = maxi(1, roundi(float(p.speed) / 120.0))
	c.jab = PROTOTYPE.jab
	c.kick = PROTOTYPE.kick
	c.sweep = PROTOTYPE.sweep
	c.air_kick = PROTOTYPE.air_kick
	return c


func restore(data: Dictionary) -> void:
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
		f.restore(raw.fighter)
		e.fighter = f
		enemies.append(e)
	props = data.props.duplicate(true)
	powers.restore(data.powers)
	camera_x = clampf(float(hero.x) / UNIT - 420, 0, 2320)
	events.clear()
