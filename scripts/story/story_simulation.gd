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
var power_world: FightSimulation


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
	wave_index = 0
	hero.x = 220 * UNIT
	hero.y = 625 * UNIT
	hero.ground_y = 625 * UNIT
	hero.health = mini(1000, hero.health + 300)
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
		var c := CharacterData.new()
		c.id = "enemy_" + kind
		c.max_health = int(p.hp)
		c.speed_pixels_per_tick = maxi(1, roundi(float(p.speed) / 120.0))
		c.jab = PROTOTYPE.jab
		c.kick = PROTOTYPE.kick
		c.sweep = PROTOTYPE.sweep
		c.air_kick = PROTOTYPE.air_kick
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
	hero.begin_tick(nearest_x)
	var gate := mini(3560, 880 + wave_index * 820) * UNIT
	hero.x = clampi(hero.x, 70 * UNIT, gate)
	var boxes := hero.attack_boxes()
	var power := hero.current_move() if hero.state == FighterState.Id.ATTACK else null
	if power != null and hero.move_tick == 0:
		events.append(
			{
				"id": "%d:voice" % tick,
				"kind": "voice",
				"character": hero.character.id,
				"move": power.legacy.get("name", "punch"),
				"slot": 0,
				"x": hero.x,
				"y": hero.y
			}
		)
	var area_power: bool = (
		power != null
		and power.legacy.get("projectile", false)
		and hero.move_tick >= power.startup * 2
		and hero.move_tick < (power.startup + power.active) * 2
	)
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
			var contact: bool = (
				area_power
				and distance < (700 if power.legacy.name == "super" else 390) * UNIT
				and signi(f.x - hero.x) == hero.facing
			)
			for hit in boxes:
				for hurt in f.hurtboxes():
					if BoxMath.overlap(hit, hurt):
						contact = true
			if contact and not enemy.id in hero.hit_targets:
				hero.hit_targets.append(enemy.id)
				hero.has_contact = true
				hero.meter = mini(100, hero.meter + 10)
				hero.combo += 1
				hero.combo_ticks = 100
				f.receive_hit(power, hero.facing, false)
				freeze_ticks = 4
				score += power.damage
				events.append(
					{
						"id": "%d:hit:%d" % [tick, enemy.id],
						"kind": "hit",
						"character": hero.character.id,
						"move": power.id,
						"slot": 1,
						"x": f.x,
						"y": f.y - 130 * UNIT
					}
				)
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
		"freeze": freeze_ticks
	}
