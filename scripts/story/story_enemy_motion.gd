class_name StoryEnemyMotion
extends RefCounted
## Shared deterministic approach and recovery rules for solo and co-op.
const UNIT := FighterModel.SCALE


static func intent(world: StorySimulation, enemy: Dictionary, actor: FighterModel) -> CombatInput:
	var f: FighterModel = enemy.fighter
	var profile: Dictionary = LegacyRoster.catalog.story.enemies[enemy.kind]
	var mobile := f.state in [FighterState.Id.IDLE, FighterState.Id.WALK]
	var rank := _rank(world, enemy, actor)
	var lane_offset := (18 if int(enemy.id) % 2 == 0 else -18) if rank == 0 else (42 if rank % 2 else -42)
	var destination := clampi(actor.ground_y + lane_offset * UNIT, 535 * UNIT, 655 * UNIT)
	if mobile:
		var change := clampi(destination - f.ground_y, -maxi(1, f.character.speed_units * 181 / 256), maxi(1, f.character.speed_units * 181 / 256))
		f.ground_y += change
		f.y += change
		# Airborne machines cannot use the grounded turning rule in FighterModel.
		if f.x != actor.x:
			f.facing = 1 if actor.x > f.x else -1
	var distance := absi(f.x - actor.x)
	var reach := int(profile.range)
	var stand_off := roundi(reach * .86) if rank == 0 else maxi(reach, 190) + rank * 145
	var held := 0
	var edge := 0
	enemy.cooldown -= 1
	if mobile and distance > (stand_off + 6) * UNIT:
		held = CombatInput.RIGHT if actor.x > f.x else CombatInput.LEFT
	elif mobile and rank > 0 and distance < (stand_off - 18) * UNIT:
		held = CombatInput.LEFT if actor.x > f.x else CombatInput.RIGHT
	if rank == 0 and distance <= reach * UNIT and absi(actor.ground_y - f.ground_y) < 48 * UNIT \
		and enemy.cooldown <= 0 and mobile:
		world._prepare_enemy_attack(enemy)
		edge = CombatInput.KICK
		enemy.cooldown = 126 if not profile.get("boss", false) else 65
	return CombatInput.new(held, edge)


static func _rank(world: StorySimulation, enemy: Dictionary, actor: FighterModel) -> int:
	var f: FighterModel = enemy.fighter
	var side := 1 if f.x >= actor.x else -1
	var ranged: bool = LegacyRoster.catalog.story.enemies[enemy.kind].get("ranged", false)
	var rank := 0
	for other in world.enemies:
		var peer: FighterModel = other.fighter
		var profile: Dictionary = LegacyRoster.catalog.story.enemies[other.kind]
		if int(other.id) >= int(enemy.id) or peer.health <= 0 or bool(profile.get("ranged", false)) != ranged:
			continue
		if absi(peer.x - actor.x) > 650 * UNIT or (1 if peer.x >= actor.x else -1) != side:
			continue
		var nearest := world.players()[0]
		var best := 1 << 60
		for player in world.players():
			var gap := absi(player.x - peer.x) + 2 * absi(player.ground_y - peer.ground_y)
			if player.health > 0 and gap < best:
				nearest = player
				best = gap
		if nearest.slot == actor.slot:
			rank += 1
	return rank


static func finish(f: FighterModel, profile: Dictionary, old_x: int, old_lane: int) -> void:
	if f.state == FighterState.Id.WALK and f.ground_y != old_lane:
		f.x = old_x + (f.x - old_x) * 181 / 256
	if int(profile.get("fly", 0)) > 0 and not f.knockdown_pending and f.vy >= 0 \
		and f.state in [FighterState.Id.IDLE, FighterState.Id.WALK, FighterState.Id.ATTACK, FighterState.Id.HITSTUN]:
		# Take off after a knockdown instead of teleporting to cruising height.
		f.y += clampi(f.ground_y - int(profile.fly) * UNIT - f.y, -4 * UNIT, 4 * UNIT)
		f.vy = 0


static func record_walk(f: FighterModel, old_x: int, old_lane: int) -> void:
	if f.state not in [FighterState.Id.IDLE, FighterState.Id.WALK]:
		return
	var dx := absi(f.x - old_x)
	var dy := absi(f.ground_y - old_lane)
	if dx + dy > 0:
		if f.state == FighterState.Id.IDLE:
			f.transition(FighterState.Id.WALK)
		f.walk_distance += maxi(dx, dy) + mini(dx, dy) * 3 / 8
