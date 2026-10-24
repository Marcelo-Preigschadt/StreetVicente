class_name OpenBorMotion
extends RefCounted
## Fixed-point port of OpenBOR testmove/common_trymove. See third_party/openbor/.
const UNIT := FighterModel.SCALE
const MIN_LANE := 535 * UNIT
const MAX_LANE := 655 * UNIT


static func footprint(prop: Dictionary) -> Rect2i:
	var half_x := roundi(StoryLayout.prop_size(str(prop.kind)).x * .38 * UNIT) + 18 * UNIT
	var half_z := (32 if prop.kind == "table" else 24) * UNIT
	return Rect2i(int(prop.x) - half_x, int(prop.lane) - half_z, half_x * 2, half_z * 2)


static func solid(prop: Dictionary) -> bool:
	return not prop.get("used", false) and int(prop.hp) > 0 and prop.kind not in ["can", "medkit"]


static func inside(rect: Rect2i, point: Vector2i) -> bool:
	return point.x > rect.position.x and point.x < rect.end.x \
		and point.y > rect.position.y and point.y < rect.end.y


static func test_position(world: StorySimulation, actor: FighterModel, point: Vector2i) -> bool:
	var gate := mini(3560, 880 + world.wave_index * 820) * UNIT
	if point.x < 70 * UNIT or point.x > gate or point.y < MIN_LANE or point.y > MAX_LANE:
		return false
	for prop in world.props:
		if solid(prop) and inside(footprint(prop), point):
			return false
	return true


static func constrain(world: StorySimulation, actor: FighterModel, old_x: int, old_z: int) -> void:
	var lift := actor.ground_y - actor.y
	var position := Vector2i(old_x, old_z)
	var wanted := Vector2i(actor.x, actor.ground_y)
	wanted.x = clampi(wanted.x, 70 * UNIT, mini(3560, 880 + world.wave_index * 820) * UNIT)
	wanted.y = clampi(wanted.y, MIN_LANE, MAX_LANE)
	var blockers: Array[Rect2i] = []
	for prop in world.props:
		if solid(prop) and lift < roundi(StoryLayout.prop_size(str(prop.kind)).y * UNIT):
			blockers.append(footprint(prop))
	# Separate x/z tests preserve tangential movement along an obstacle. A body
	# already overlapping (old save, landing or pushback) can always move out.
	position.x = _axis(position, wanted.x, blockers, true)
	position.y = _axis(position, wanted.y, blockers, false)
	if actor.state in [FighterState.Id.IDLE, FighterState.Id.WALK] and actor.grounded():
		var people: Array[Rect2i] = []
		for other in world.power_actors():
			if other == actor or other.health <= 0 or not other.grounded() \
				or other.state in [FighterState.Id.KNOCKDOWN, FighterState.Id.WAKEUP]:
				continue
			people.append(Rect2i(other.x - 65 * UNIT, other.ground_y - 18 * UNIT, 130 * UNIT, 36 * UNIT))
		var start := Vector2i(old_x, old_z)
		start.x = _axis(start, position.x, people, true)
		start.y = _axis(start, position.y, people, false)
		position = start
	actor.x = position.x
	actor.ground_y = position.y
	actor.y = position.y - lift


static func _axis(from: Vector2i, desired: int, rectangles: Array[Rect2i], horizontal: bool) -> int:
	var origin := from.x if horizontal else from.y
	var result := desired
	for rect in rectangles:
		var cross := from.y if horizontal else from.x
		var low_cross := rect.position.y if horizontal else rect.position.x
		var high_cross := rect.end.y if horizontal else rect.end.x
		if cross <= low_cross or cross >= high_cross:
			continue
		var low := rect.position.x if horizontal else rect.position.y
		var high := rect.end.x if horizontal else rect.end.y
		if origin <= low and result > low:
			result = low
		elif origin >= high and result < high:
			result = high
		elif origin > low and origin < high:
			var depth := mini(origin - low, high - origin)
			if result > low and result < high and mini(result - low, high - result) > depth:
				result = origin
	return result


static func waypoint(world: StorySimulation, actor: FighterModel, destination: Vector2i, route: Dictionary) -> Vector2i:
	# Deterministic local visibility route; collision remains authoritative.
	# Retain the chosen side until past the rectangle, avoiding left/right jitter.
	if route.has("obstacle"):
		for prop in world.props:
			if int(prop.id) != int(route.obstacle) or not solid(prop):
				continue
			var rect := footprint(prop).grow(8 * UNIT)
			var direction := int(route.get("direction", 1))
			var beyond := rect.end.x + 4 * UNIT if direction > 0 else rect.position.x - 4 * UNIT
			if (actor.x - beyond) * direction < -6 * UNIT:
				var lane := int(route.lane)
				return Vector2i(actor.x if absi(actor.ground_y - lane) > 4 * UNIT else beyond, lane)
		route.erase("obstacle")
	var direction := 1 if destination.x >= actor.x else -1
	for prop in world.props:
		if not solid(prop):
			continue
		var rect := footprint(prop).grow(8 * UNIT)
		var near_x := rect.position.x if direction > 0 else rect.end.x
		if (near_x - actor.x) * direction < -4 * UNIT or (destination.x - near_x) * direction < 0:
			continue
		var progress := float(near_x - actor.x) / maxi(1, absi(destination.x - actor.x)) * direction
		var crossing := lerpf(actor.ground_y, destination.y, clampf(progress, 0, 1))
		if crossing <= rect.position.y or crossing >= rect.end.y:
			continue
		var top := rect.position.y - 4 * UNIT
		var bottom := rect.end.y + 4 * UNIT
		var top_ok := top >= MIN_LANE
		var bottom_ok := bottom <= MAX_LANE
		if not top_ok and not bottom_ok:
			continue
		var use_top := top_ok and (not bottom_ok or absi(actor.ground_y - top) + absi(destination.y - top) < absi(actor.ground_y - bottom) + absi(destination.y - bottom))
		route.obstacle = prop.id
		route.lane = top if use_top else bottom
		route.direction = direction
		return Vector2i(actor.x, int(route.lane))
	return destination
