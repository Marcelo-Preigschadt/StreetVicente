class_name OpenBorEnemyMotion
extends RefCounted
## OpenBOR normal_find_target/common_try_normalattack ordering, deterministic
## attack throttling and footprint routing for the Street Vicente campaign.
const UNIT := FighterModel.SCALE


static func intent(world: StorySimulation, enemy: Dictionary, target: FighterModel) -> CombatInput:
	var f: FighterModel = enemy.fighter
	if f.state not in [FighterState.Id.IDLE, FighterState.Id.WALK, FighterState.Id.BLOCK]:
		return CombatInput.new()
	var profile: Dictionary = LegacyRoster.catalog.story.enemies[enemy.kind]
	enemy.cooldown = maxi(0, int(enemy.cooldown) - 1)
	var dx := target.x - f.x
	var dz := target.ground_y - f.ground_y
	if dx != 0:
		f.facing = 1 if dx > 0 else -1
	var ranged: bool = profile.get("ranged", false)
	var reach := roundi(float(profile.range) * (.78 if ranged else .70)) * UNIT
	# Short defensive responses. Integer state is preserved by rollback/save.
	var armored: bool = str(enemy.kind) in ["turnstile", "lab", "elite", "inspector", "exo"]
	var threatened := target.state == FighterState.Id.ATTACK and absi(dx) < 250 * UNIT \
		and absi(dz) < 42 * UNIT and target.current_move().phase(target.move_tick) == "STARTUP"
	if not threatened:
		enemy.threat_since = -1
	elif int(enemy.get("threat_since", -1)) < 0:
		enemy.threat_since = world.tick
	var reacting: bool = threatened and world.tick - int(enemy.get("threat_since", world.tick)) >= 12
	if armored and reacting and world.tick >= int(enemy.get("defend_after", 0)):
		var incoming := target.current_move()
		var cover := clampi((incoming.startup + incoming.active) * 2 - target.move_tick + 8, 28, 84)
		enemy.guard_until = world.tick + cover
		enemy.defend_after = world.tick + 210
	if world.tick < int(enemy.get("guard_until", 0)):
		enemy.behavior = "guard"
		return CombatInput.new(CombatInput.GUARD)
	var attackers := 0
	var attack_budget := clampi(world.players().filter(func(p: FighterModel): return p.health > 0).size(), 1, 2)
	for other in world.enemies:
		if other.id != enemy.id and other.fighter.health > 0 and other.fighter.state == FighterState.Id.ATTACK:
			attackers += 1
	# OpenBOR range is tested on the floor plane before selecting an attack.
	# A recovering/invulnerable target isn't attacked by the normal AI.
	if absi(dx) <= int(profile.range) * UNIT and absi(dz) <= OpenBorMotion.BODY_HALF_DEPTH \
		and enemy.cooldown == 0 and attackers < attack_budget and target.health > 0 \
		and target.invincible_ticks == 0 and target.state not in [FighterState.Id.KNOCKDOWN, FighterState.Id.WAKEUP]:
		world._prepare_enemy_attack(enemy)
		enemy.cooldown = (126 if ranged else 94) + int(enemy.id) % 3 * 18 if not profile.get("boss", false) else 80
		enemy.behavior = "attack"
		return CombatInput.new(0, CombatInput.KICK)
	var side := -1 if dx > 0 else 1
	# Keep a stable approach side; waiting actors use depth rather than pushing
	# another enemy across the hero. No position reservation or teleportation.
	var offset_z := 0
	enemy.behavior = "approach"
	var rank := 0
	for other in world.enemies:
		if other.id == enemy.id or other.fighter.health <= 0 or int(other.id) > int(enemy.id):
			continue
		var same_side: bool = (other.fighter.x - target.x) * side > 0
		if same_side and absi(other.fighter.ground_y - target.ground_y) < 80 * UNIT:
			rank += 1
	if attackers >= attack_budget or int(enemy.cooldown) > 65:
		offset_z = (-42 if int(enemy.id) % 2 else 42) * UNIT
		enemy.behavior = "reposition"
		if int(enemy.attack_serial) > 0:
			reach += (65 if ranged else 45) * UNIT
	if not armored and not ranged and reacting and world.tick >= int(enemy.get("defend_after", 0)):
		enemy.evade_until = world.tick + 30
		enemy.defend_after = world.tick + 210
	if world.tick < int(enemy.get("evade_until", 0)):
		offset_z = (-58 if int(enemy.id) % 2 else 58) * UNIT
		enemy.behavior = "sidestep"
	if rank > 0:
		reach += rank * 80 * UNIT
		offset_z = (-45 if int(enemy.id) % 2 else 45) * UNIT
		if not ranged and world.tick >= int(enemy.get("flank_after", 0)):
			enemy.flank_until = world.tick + 150
			enemy.flank_after = world.tick + 420
			enemy.flank_side = -side
	if world.tick < int(enemy.get("flank_until", 0)):
		enemy.behavior = "flank"
		offset_z = (-66 if target.ground_y > 570 * UNIT else 66) * UNIT
		if absi(dz) > 46 * UNIT:
			side = int(enemy.flank_side)
			reach = 150 * UNIT
	var goal := Vector2i(target.x + side * reach, clampi(target.ground_y + offset_z, (StoryLayout.MIN_LANE + 6) * UNIT, (StoryLayout.MAX_LANE - 6) * UNIT))
	goal.x = clampi(goal.x, 90 * UNIT, (StoryLayout.gate(world.wave_index) - 90) * UNIT)
	# The ideal attack distance can lie inside a table. End the approach on
	# the target's side of that footprint instead of routing back into it.
	for prop in world.props:
		if OpenBorMotion.solid(prop) and OpenBorMotion.inside(OpenBorMotion.footprint(prop), goal):
			var rect := OpenBorMotion.footprint(prop)
			goal.x = rect.position.x - 8 * UNIT if target.x < int(prop.x) else rect.end.x + 8 * UNIT
	if not enemy.has("route"):
		enemy.route = {}
	goal = OpenBorMotion.waypoint(world, f, goal, enemy.route)
	dx = goal.x - f.x
	dz = goal.y - f.ground_y
	var lane_speed := maxi(1, f.character.speed_units * 2 / 3)
	if absi(dx) > 6 * UNIT and absi(dz) > 3 * UNIT:
		lane_speed = lane_speed * 181 / 256
	var lane_step := clampi(dz, -lane_speed, lane_speed)
	f.ground_y += lane_step
	f.y += lane_step
	var held := 0
	if absi(dx) > 6 * UNIT:
		held = CombatInput.RIGHT if dx > 0 else CombatInput.LEFT
	return CombatInput.new(held)


static func finish(f: FighterModel, profile: Dictionary, old_x: int, old_lane: int) -> void:
	if int(profile.get("fly", 0)) > 0 and f.state in [FighterState.Id.IDLE, FighterState.Id.WALK]:
		f.x = old_x + f.input.axis_x() * f.character.speed_units
		f.vx = 0
	if f.state in [FighterState.Id.IDLE, FighterState.Id.WALK] and f.ground_y != old_lane:
		f.x = old_x + (f.x - old_x) * 181 / 256
	if int(profile.get("fly", 0)) > 0 and not f.knockdown_pending and f.vy >= 0 \
		and f.state in [FighterState.Id.IDLE, FighterState.Id.WALK, FighterState.Id.ATTACK, FighterState.Id.HITSTUN]:
		f.y += clampi(f.ground_y - int(profile.fly) * UNIT - f.y, -4 * UNIT, 4 * UNIT)
		f.vy = 0


static func record_walk(f: FighterModel, old_x: int, old_lane: int) -> void:
	if f.state not in [FighterState.Id.IDLE, FighterState.Id.WALK]:
		return
	var dx := absi(f.x - old_x)
	var dz := absi(f.ground_y - old_lane)
	if dx + dz > 0:
		f.transition(FighterState.Id.WALK)
		f.walk_distance += maxi(dx, dz) + mini(dx, dz) * 3 / 8
	elif f.state == FighterState.Id.WALK:
		f.transition(FighterState.Id.IDLE)
