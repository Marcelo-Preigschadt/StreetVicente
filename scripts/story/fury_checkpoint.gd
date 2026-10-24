class_name FuryCheckpoint
extends RefCounted
## Adapted from Fists of Fury Checkpoint's queued enemy_data and active limit.
## Nicolas Bize, MIT 2025; third_party/fists_of_fury/LICENSE.
const UNIT := FighterModel.SCALE
const MAX_ACTIVE := 3


static func begin(world: StorySimulation) -> void:
	world.spawn_queue.clear()
	var kinds: Array = world.act().waves[world.wave_index] if world.wave_index < 3 else [world.act().boss]
	var edge := mini(3560, 880 + world.wave_index * 820)
	var start := mini(650 + world.wave_index * 820, edge - 80 - mini(2, kinds.size() - 1) * 90)
	for i in kinds.size():
		world.spawn_queue.append({"kind": kinds[i], "x": start + (i % 3) * 90,
			"lane": 565 + (i % 3) * 35, "cooldown": 60 + i * 28})
	world.spawn_due = world.tick
	pump(world)


static func pump(world: StorySimulation) -> void:
	if world.tick < world.spawn_due:
		return
	var active := 0
	for enemy in world.enemies:
		if enemy.fighter.health > 0:
			active += 1
	while active < MAX_ACTIVE and not world.spawn_queue.is_empty():
		var entry: Dictionary = world.spawn_queue.pop_front()
		world._spawn_enemy(entry)
		active += 1
	world.spawn_due = world.tick + 60
