class_name KhauanyFXV21
extends RefCounted
## Silver fork volleys, ascending cutlery crescent and five-wave banquet storm.
const VIOLET := Color("a984ff")
const ICE := Color("a9d7ff")
const WHITE := Color("f5efff")
const VOLLEY_SIZE := Vector2(350, 280)
const SUPER_SIZE := Vector2(570, 470)
const SUPER_BLAST := Vector2(650, 540)
static var art: Dictionary = {}


static func load_data() -> void:
	if art.is_empty():
		art = JSON.parse_string(FileAccess.get_file_as_string(
			"res://data/characters/khauany-effects-v21.json"))


static func cel(c: CanvasItem, clip: String, index: int, at: Vector2,
	size: Vector2, facing: int = 1, tint: Color = Color.WHITE) -> void:
	load_data()
	EffectCelV20.draw(c, art, clip, index, at, size, facing, tint)


static func projectile(c: CanvasItem, p: Dictionary, camera: float) -> void:
	# The broad silver front and historical wake draw below actors. A small
	# foreground glint marks its swept collision nucleus without hiding faces.
	var at := Vector2(p.x / 256.0 - camera, p.y / 256.0)
	PowerFXV10.glow(c, at, float(p.radius) * .52, WHITE, .13)


static func backdrop(c: CanvasItem, world, camera: float) -> void:
	for p in world.projectiles:
		if p.character != "khauany" or p.kind != "projectile":
			continue
		var at := Vector2(p.x / 256.0 - camera, p.y / 256.0)
		var super_move := str(p.move).begins_with("super")
		var facing := int(p.facing)
		var distance := absf(float(p.x - p.spawn_x)) / 256
		var size := SUPER_SIZE if super_move else VOLLEY_SIZE
		var clip := "champion" if super_move else "pulse"
		PowerFXV10.glow(c, at, 265 if super_move else 145, VIOLET, .22)
		# Previous positions of the same fork fan form an actual travelling wake.
		# No ornamental tail receives a collision box.
		for ghost in range(3, 0, -1):
			var behind := minf(distance, ghost * (90 if super_move else 48))
			if behind < 12:
				continue
			cel(c, clip, int(p.age) / 5 - ghost,
				at - Vector2(behind * facing, 0), size * (1 - ghost * .06),
				facing, Color(1, 1, 1, .12 / ghost))
		cel(c, clip, int(p.age) / 5, at, size, facing)
	for f in world.power_actors():
		if f.character.id != "khauany" or f.state != FighterState.Id.ATTACK:
			continue
		if str(f.current_move().legacy.name) not in ["super", "uppercut"]:
			continue
		var root := Vector2(f.x / 256.0 - camera, f.ground_y / 256.0 - 12)
		var super_move := str(f.current_move().legacy.name) == "super"
		PowerFXV10.glow(c, root - Vector2(0, 150), 245 if super_move else 180, VIOLET, .16)
		cel(c, "charge", 1, root, Vector2(380, 110) if super_move else Vector2(240, 80),
			f.facing, Color(1, 1, 1, .6))


static func charge(c: CanvasItem, f: FighterModel, camera: float) -> void:
	var move := f.current_move()
	var name := str(move.legacy.name)
	var phase := move.phase(f.move_tick)
	var at := Vector2(CombatGeometry.hand(f)) / 256 - Vector2(camera, 0)
	var amount := clampf(f.move_tick / float(maxi(1, move.startup * 2)), 0, 1)
	var super_move := name == "super"
	if phase == "STARTUP":
		cel(c, "charge", mini(2, int(amount * 3)), at,
			Vector2(120, 120).lerp(Vector2(300, 270) if super_move else Vector2(205, 185), amount), f.facing)
	elif phase == "ACTIVE":
		var age := f.move_tick - move.startup * 2
		if name == "uppercut":
			var root := Vector2(f.x / 256.0 - camera, f.y / 256.0)
			cel(c, "rise", age / 6, root + Vector2(92 * f.facing, -205),
				Vector2(360, 465), f.facing)
			cel(c, "charge", 3, at, Vector2(120, 130), f.facing)
		elif age < (48 if super_move else 6):
			cel(c, "charge", 3, at,
				Vector2(260, 235) if super_move else Vector2(175, 165), f.facing)


static func impact(c: CanvasItem, burst: Dictionary, camera: float) -> void:
	var elapsed := clampf(1 - float(burst.life) / float(burst.max), 0, 1)
	var fade := pow(1 - elapsed, .65)
	var at := Vector2(float(burst.x) - camera, float(burst.y))
	var facing := int(burst.get("facing", 1))
	var move := str(burst.move)
	var super_move := move.begins_with("super")
	if burst.kind == "cast":
		cel(c, "charge", 3, at, Vector2(270, 250) if super_move else Vector2(190, 180),
			facing, Color(1, 1, 1, fade))
		return
	var blocked: bool = burst.kind == "block"
	var size := (SUPER_BLAST if super_move else Vector2(365, 440)
		if move.begins_with("uppercut") else Vector2(340, 315))
	if blocked:
		size *= .72
	cel(c, "champion_hit" if super_move else "impact", mini(3, int(elapsed * 4)),
		at, size * (1 + elapsed * .18), facing,
		Color(.7, .8, 1, fade) if blocked else Color(1, 1, 1, fade))
	PowerFXV10.glow(c, at, (245 if super_move else 125) * (1 + elapsed * .25),
		ICE if blocked else VIOLET, fade * .25)
