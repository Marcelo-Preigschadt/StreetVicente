class_name TaisFXV17
extends RefCounted
## Broad athletic pressure fronts and sustained champion impact; rendering only.
const TEAL := Color("51f5e2")
const GOLD := Color("ffe08a")
const WHITE := Color("f5fffc")
const SUPER_SIZE := Vector2(460, 440)
const SUPER_BLAST := Vector2(620, 500)
static var art: Dictionary = {}


static func load_data() -> void:
	if art.is_empty():
		art = JSON.parse_string(FileAccess.get_file_as_string(
			"res://data/characters/tais-effects-v17.json"))


static func cel(c: CanvasItem, clip: String, index: int, at: Vector2,
	size: Vector2, facing: int = 1, tint: Color = Color.WHITE) -> void:
	load_data()
	var sequence: Array = art.clips[clip]
	var frame: Dictionary = art.frames[int(sequence[posmod(index, sequence.size())])]
	var r: Array = frame.rect
	var pivot := Vector2(float(frame.pivot[0]), float(frame.pivot[1]))
	c.draw_set_transform(at, 0, Vector2(facing, 1))
	c.draw_texture_rect_region(LegacyRoster.texture(frame.image),
		Rect2(-pivot * size, size), Rect2(r[0], r[1], r[2], r[3]), tint)
	c.draw_set_transform(Vector2.ZERO)


static func projectile(c: CanvasItem, p: Dictionary, camera: float) -> void:
	var at := Vector2(p.x / 256.0 - camera, p.y / 256.0)
	var super_move := str(p.move).begins_with("super")
	var age := int(p.age)
	cel(c, "champion" if super_move else "pulse", age / 4, at,
		SUPER_SIZE if super_move else Vector2(280, 230), int(p.facing))
	# The bright nucleus follows the actual projectile centre. The large soft
	# ribbons behind it are historical positions, drawn below the actors.
	PowerFXV10.glow(c, at, float(p.radius) * .68, WHITE, .28)


static func backdrop(c: CanvasItem, world, camera: float) -> void:
	for p in world.projectiles:
		if p.character != "tais" or p.kind != "projectile":
			continue
		var at := Vector2(p.x / 256.0 - camera, p.y / 256.0)
		var super_move := str(p.move).begins_with("super")
		var facing := int(p.facing)
		var distance := absf(float(p.x - p.spawn_x)) / 256
		var length := minf(680 if super_move else 330, distance + 75)
		var spread := 130.0 if super_move else 55.0
		PowerFXV10.glow(c, at, 310 if super_move else 165, TEAL, .24)
		for lane in [-1, 0, 1]:
			var points := PackedVector2Array()
			for j in 14:
				var t := float(j) / 13
				points.append(at + Vector2(-length * t * facing,
					lane * spread * sin(t * PI * .82) + sin(t * TAU) * 12 * t))
			c.draw_polyline(points, Color(TEAL, .19 if super_move else .12),
				30 if super_move else 15, true)
			c.draw_polyline(points, Color(GOLD if lane == 0 else WHITE, .65),
				4.5 if super_move else 2.5, true)
		if super_move and p.age > 10:
			cel(c, "champion", int(p.age) / 4 - 1,
				at - Vector2(minf(distance, 95) * facing, 0),
				SUPER_SIZE * .96, facing, Color(TEAL, .23))
	for f in world.power_actors():
		if f.character.id != "tais" or f.state != FighterState.Id.ATTACK:
			continue
		var move: MoveData = f.current_move()
		if str(move.legacy.name) not in ["super", "uppercut"]:
			continue
		var root := Vector2(f.x / 256.0 - camera, f.ground_y / 256.0 - 15)
		var super_move := str(move.legacy.name) == "super"
		PowerFXV10.glow(c, root - Vector2(0, 145), 255 if super_move else 195, TEAL, .18)
		cel(c, "charge", 1, root,
			Vector2(400, 125) if super_move else Vector2(265, 85),
			f.facing, Color(1, 1, 1, .75))


static func charge(c: CanvasItem, f: FighterModel, camera: float) -> void:
	var move := f.current_move()
	var name := str(move.legacy.name)
	var phase := move.phase(f.move_tick)
	var at := Vector2(CombatGeometry.hand(f)) / 256 - Vector2(camera, 0)
	var amount := clampf(f.move_tick / float(maxi(1, move.startup * 2)), 0, 1)
	var super_move := name == "super"
	if phase == "STARTUP":
		cel(c, "charge", mini(2, int(amount * 3)), at,
			Vector2(150, 140).lerp(Vector2(320, 270) if super_move else Vector2(210, 190), amount),
			f.facing)
	elif phase == "ACTIVE":
		var age := f.move_tick - move.startup * 2
		if name == "uppercut":
			var root := Vector2(f.x / 256.0 - camera, f.y / 256.0)
			cel(c, "rise", age / 6, root + Vector2(90 * f.facing, -205),
				Vector2(350, 450), f.facing)
			cel(c, "charge", 3, at, Vector2(150, 165), f.facing)
		elif age < (42 if super_move else 6):
			cel(c, "charge", 3, at,
				Vector2(270, 255) if super_move else Vector2(190, 180), f.facing)


static func impact(c: CanvasItem, burst: Dictionary, camera: float) -> void:
	var elapsed := clampf(1 - float(burst.life) / float(burst.max), 0, 1)
	var fade := pow(1 - elapsed, .65)
	var at := Vector2(float(burst.x) - camera, float(burst.y))
	var facing := int(burst.get("facing", 1))
	var move := str(burst.move)
	var super_move := move.begins_with("super")
	if burst.kind == "cast":
		cel(c, "charge", 3, at, Vector2(290, 270) if super_move else Vector2(205, 185),
			facing, Color(1, 1, 1, fade))
		return
	var blocked: bool = burst.kind == "block"
	var size := (SUPER_BLAST if super_move else Vector2(370, 440)
		if move.begins_with("uppercut") else Vector2(320, 300))
	if blocked:
		size *= .72
	cel(c, "champion_hit" if super_move else "impact", mini(3, int(elapsed * 4)),
		at, size * (1 + elapsed * .18), facing,
		Color(.65, .85, 1, fade) if blocked else Color(1, 1, 1, fade))
	PowerFXV10.glow(c, at, (240 if super_move else 125) * (1 + elapsed * .25),
		TEAL if blocked else GOLD, fade * .3)
