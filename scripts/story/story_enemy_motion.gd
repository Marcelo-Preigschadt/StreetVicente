class_name StoryEnemyMotion
extends RefCounted
## Adapted from Fists of Fury reserve_slot / goto_melee_position (Nicolas Bize,
## MIT 2025; third_party/fists_of_fury/LICENSE). Slots are serialized per enemy.
const UNIT := FighterModel.SCALE


static func intent(world: StorySimulation, enemy: Dictionary, actor: FighterModel) -> CombatInput:
	var f: FighterModel = enemy.fighter
	var profile: Dictionary = LegacyRoster.catalog.story.enemies[enemy.kind]
	if f.state not in [FighterState.Id.IDLE, FighterState.Id.WALK]:
		if f.health <= 0 or f.state in [FighterState.Id.KNOCKDOWN, FighterState.Id.KO, FighterState.Id.WAKEUP]:
			enemy.engagement_slot = -1
		return CombatInput.new()
	enemy.cooldown = maxi(0, int(enemy.cooldown) - 1)
	var ranged: bool = profile.get("ranged", false)
	var slot := _reserve(world, enemy, actor, ranged)
	var reach := roundi(float(profile.range) * (.86 if ranged else .72))
	var offsets := [Vector2i(-reach, 0), Vector2i(reach, 0),
		Vector2i(-reach - 150, -65), Vector2i(reach + 150, 65),
		Vector2i(-reach - 280, 60), Vector2i(reach + 280, -60)]
	var offset: Vector2i = offsets[clampi(slot, 0, 5)]
	var gate := mini(3560, 880 + world.wave_index * 820)
	var destination := Vector2i(clampi(actor.x + offset.x * UNIT, 100 * UNIT, (gate - 75) * UNIT),
		clampi(actor.ground_y + offset.y * UNIT, 540 * UNIT, 650 * UNIT))
	var dx := destination.x - f.x
	var dy := destination.y - f.ground_y
	# Walk around the player when changing sides, never through their torso.
	if (f.x - actor.x) * offset.x < 0 and absi(f.x - actor.x) < 170 * UNIT:
		destination.y = clampi(actor.ground_y + (65 if actor.ground_y < 600 * UNIT else -65) * UNIT, 540 * UNIT, 650 * UNIT)
		dy = destination.y - f.ground_y
		if absi(f.ground_y - actor.ground_y) < 38 * UNIT:
			dx = 0
	var lane_step := maxi(1, f.character.speed_units * 2 / 3)
	if absi(dx) > 6 * UNIT and absi(dy) > 3 * UNIT:
		lane_step = lane_step * 181 / 256
	var change := clampi(dy, -lane_step, lane_step)
	f.ground_y += change
	f.y += change
	if f.x != actor.x:
		f.facing = 1 if actor.x > f.x else -1
	var held := 0
	if absi(dx) > 6 * UNIT:
		held = CombatInput.RIGHT if dx > 0 else CombatInput.LEFT
	var edge := 0
	if slot < 2 and absi(f.x - actor.x) <= int(profile.range) * UNIT \
		and absi(actor.ground_y - f.ground_y) <= 24 * UNIT and enemy.cooldown == 0:
		world._prepare_enemy_attack(enemy)
		edge = CombatInput.KICK
		enemy.cooldown = 132 if not profile.get("boss", false) else 84
		held = 0
	return CombatInput.new(held, edge)


static func _reserve(world: StorySimulation, enemy: Dictionary, actor: FighterModel, ranged: bool) -> int:
	var current := int(enemy.get("engagement_slot", -1))
	var target := int(enemy.get("engagement_target", -1))
	var occupied: Array[int] = []
	for other in world.enemies:
		if other.id == enemy.id or other.fighter.health <= 0:
			continue
		var profile: Dictionary = LegacyRoster.catalog.story.enemies[other.kind]
		if bool(profile.get("ranged", false)) == ranged and int(other.get("engagement_target", -1)) == actor.slot:
			occupied.append(int(other.get("engagement_slot", -1)))
	if target == actor.slot and current >= 0 and current not in occupied:
		if current < 2 or (0 in occupied and 1 in occupied):
			return current
	# Stable closest-side reservation, retained through the whole attack.
	var order := [1, 0, 3, 2, 5, 4] if enemy.fighter.x >= actor.x else [0, 1, 2, 3, 4, 5]
	for candidate in order:
		if candidate not in occupied:
			enemy.engagement_slot = candidate
			enemy.engagement_target = actor.slot
			return candidate
	return 5


static func finish(f: FighterModel, profile: Dictionary, old_x: int, old_lane: int) -> void:
	if f.state == FighterState.Id.WALK and f.ground_y != old_lane:
		f.x = old_x + (f.x - old_x) * 181 / 256
	if int(profile.get("fly", 0)) > 0 and not f.knockdown_pending and f.vy >= 0 \
		and f.state in [FighterState.Id.IDLE, FighterState.Id.WALK, FighterState.Id.ATTACK, FighterState.Id.HITSTUN]:
		f.y += clampi(f.ground_y - int(profile.fly) * UNIT - f.y, -4 * UNIT, 4 * UNIT)
		f.vy = 0


static func record_walk(f: FighterModel, old_x: int, old_lane: int) -> void:
	if f.state not in [FighterState.Id.IDLE, FighterState.Id.WALK]:
		return
	var dx := absi(f.x - old_x)
	var dy := absi(f.ground_y - old_lane)
	if dx + dy > 0:
		f.transition(FighterState.Id.WALK)
		f.walk_distance += maxi(dx, dy) + mini(dx, dy) * 3 / 8
	elif f.state == FighterState.Id.WALK:
		f.transition(FighterState.Id.IDLE)
