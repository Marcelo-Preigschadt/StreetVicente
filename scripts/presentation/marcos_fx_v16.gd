class_name MarcosFXV16
extends RefCounted
## Session locks, reversed memory stacks and kernel rupture. Presentation only.
const BLUE := Color("68caff")
const WHITE := Color("e8faff")
const RED := Color("ff5b66")
static var art: Dictionary = {}


static func load_data() -> void:
	if art.is_empty():
		art = JSON.parse_string(
			FileAccess.get_file_as_string("res://data/characters/marcos-effects-v16.json")
		)


static func cel(
	c: CanvasItem, clip: String, index: int, at: Vector2, size: Vector2,
	facing: int = 1, tint: Color = Color.WHITE
) -> void:
	load_data()
	var sequence: Array = art.clips[clip]
	var frame: Dictionary = art.frames[int(sequence[posmod(index, sequence.size())])]
	var rect: Array = frame.rect
	var pivot := Vector2(float(frame.pivot[0]), float(frame.pivot[1]))
	c.draw_set_transform(at, 0, Vector2(facing, 1))
	c.draw_texture_rect_region(
		LegacyRoster.texture(art.image), Rect2(-pivot * size, size),
		Rect2(rect[0], rect[1], rect[2], rect[3]), tint
	)
	c.draw_set_transform(Vector2.ZERO)


static func charge(c: CanvasItem, f: FighterModel, camera: float) -> void:
	var move := f.current_move()
	var name := str(move.legacy.name)
	var phase := move.phase(f.move_tick)
	var root := Vector2(f.x / 256.0 - camera, f.y / 256.0)
	var hand := Vector2(CombatGeometry.hand(f)) / 256 - Vector2(camera, 0)
	if phase == "STARTUP":
		var amount := clampf(f.move_tick / float(maxi(1, move.startup * 2)), 0, 1)
		cel(c, "charge", mini(1, int(amount * 2)), hand,
			Vector2(64 + amount * 30, 44 + amount * 20), f.facing)
		return
	if phase != "ACTIVE":
		return
	var age := f.move_tick - move.startup * 2
	if name == "uppercut":
		# The actor remains grounded; the stack reverses up the physical lift area.
		cel(c, "stack", mini(3, age / 5), root + Vector2(105 * f.facing, -216),
			Vector2(185, 218), f.facing)
		c.draw_set_transform(root, 0, Vector2(f.facing, 1))
		for i in 3:
			var at := Vector2(78 + i * 12, -112 - i * 64 - mini(12, age))
			c.draw_rect(Rect2(at, Vector2(24, 15)), Color(BLUE, .6))
			c.draw_rect(Rect2(at, Vector2(24, 15)), Color(WHITE, .9), false, 1.5)
		c.draw_set_transform(Vector2.ZERO)
	elif name == "super":
		cel(c, "charge", 2, hand, Vector2(110, 74), f.facing)
		# Circuit fragments mark the hip rotation without hiding the face.
		c.draw_set_transform(root, 0, Vector2(f.facing, 1))
		for i in 4:
			var at := Vector2(-58 + i * 36, -24 - posmod(age * 3 + i * 11, 26))
			c.draw_rect(Rect2(at, Vector2(14, 5)), Color(RED if i % 2 else BLUE, .7))
		c.draw_set_transform(Vector2.ZERO)
	else:
		cel(c, "session", 2, hand, Vector2(112, 75), f.facing)


static func actor(actors: Array, slot: int) -> FighterModel:
	for value in actors:
		if value.slot == slot:
			return value
	return null


static func impact(c: CanvasItem, burst: Dictionary, actors: Array, camera: float) -> void:
	var elapsed := clampf(1 - float(burst.life) / float(burst.max), 0, 1)
	var alpha := 1 - elapsed
	var at := Vector2(float(burst.x) - camera, float(burst.y))
	var facing := int(burst.get("facing", 1))
	var move := str(burst.move)
	if burst.kind == "cast":
		cel(c, "charge", 2 if elapsed < .5 else 3, at, Vector2(88, 59), facing,
			Color(1, 1, 1, alpha))
		return
	if move.begins_with("special"):
		var victim := actor(actors, int(burst.get("slot", -1)))
		if victim != null:
			at = Vector2(victim.x / 256.0 - camera, victim.y / 256.0 - 158)
		cel(c, "session", mini(3, int(elapsed * 4)), at, Vector2(148, 99), facing,
			Color(1, 1, 1, alpha))
		var owner: FighterModel
		for value in actors:
			if value.character.id == "marcos" and value.slot != int(burst.get("slot", -1)):
				owner = value
				break
		if owner != null:
			var start := Vector2(CombatGeometry.hand(owner)) / 256 - Vector2(camera, 0)
			var elbow := start + Vector2(18 * facing, 0)
			c.draw_polyline(PackedVector2Array([start, elbow, Vector2(elbow.x, at.y), at]),
				Color(BLUE, alpha * .7), 2, true)
	elif move.begins_with("uppercut"):
		var blocked: bool = burst.kind == "block"
		cel(c, "stack", mini(3, int(elapsed * 4)), at,
			Vector2(105, 92) if blocked else Vector2(165, 144), facing,
			Color(.7, .85, 1, alpha) if blocked else Color(1, 1, 1, alpha))
	else:
		cel(c, "panic", mini(3, int(elapsed * 4)), at,
			Vector2(230 + elapsed * 55, 155 + elapsed * 37), facing, Color(1, 1, 1, alpha))
