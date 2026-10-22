class_name RuanFXV19
extends RefCounted
## Forked blue-violet plasma fronts and a sustained lightning corona; rendering only.
const BLUE := Color("55b9ff")
const VIOLET := Color("af7bff")
const WHITE := Color("effaff")
const SUPER_SIZE := Vector2(480, 460)
const SUPER_BLAST := Vector2(640, 540)
static var art: Dictionary = {}
static var meshes: Dictionary = {}


static func frame_mesh(frame_id: int) -> ArrayMesh:
	if meshes.has(frame_id):
		return meshes[frame_id]
	var frame: Dictionary = art.frames[frame_id]
	var r: Array = frame.rect
	var pivot := Vector2(float(frame.pivot[0]), float(frame.pivot[1]))
	var texture := LegacyRoster.texture(frame.image)
	var atlas := Vector2(texture.get_width(), texture.get_height())
	# A cached 2D presentation mesh smoothly extinguishes the outer atlas edge.
	# Source pixels and the opaque electrical nucleus are preserved. This also
	# prevents neighboring cels and hard rectangular glow crops from appearing.
	var axis := PackedFloat32Array([0, .035, .08, .12, .88, .92, .965, 1])
	var opacity := PackedFloat32Array([0, .12, .65, 1, 1, .65, .12, 0])
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var uv := PackedVector2Array()
	var indices := PackedInt32Array()
	for y in axis.size():
		for x in axis.size():
			var point := Vector2(axis[x], axis[y])
			vertices.append(Vector3(point.x - pivot.x, point.y - pivot.y, 0))
			colors.append(Color(1, 1, 1, opacity[x] * opacity[y]))
			uv.append((Vector2(r[0], r[1]) + point * Vector2(r[2], r[3])) / atlas)
	for y in axis.size() - 1:
		for x in axis.size() - 1:
			var a := y * axis.size() + x
			var b := a + 1
			var d := a + axis.size()
			indices.append_array(PackedInt32Array([a, b, d, b, d + 1, d]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	meshes[frame_id] = mesh
	return mesh


static func load_data() -> void:
	if art.is_empty():
		art = JSON.parse_string(FileAccess.get_file_as_string(
			"res://data/characters/ruan-effects-v19.json"))


static func cel(c: CanvasItem, clip: String, index: int, at: Vector2,
	size: Vector2, facing: int = 1, tint: Color = Color.WHITE) -> void:
	load_data()
	var sequence: Array = art.clips[clip]
	var frame_id := int(sequence[posmod(index, sequence.size())])
	var frame: Dictionary = art.frames[frame_id]
	c.draw_set_transform(at, 0, Vector2(facing * size.x, size.y))
	c.draw_mesh(frame_mesh(frame_id), LegacyRoster.texture(frame.image), Transform2D.IDENTITY, tint)
	c.draw_set_transform(Vector2.ZERO)


static func projectile(c: CanvasItem, p: Dictionary, camera: float) -> void:
	var at := Vector2(p.x / 256.0 - camera, p.y / 256.0)
	var super_move := str(p.move).begins_with("super")
	var age := int(p.age)
	cel(c, "champion" if super_move else "pulse", age / 4, at,
		SUPER_SIZE if super_move else Vector2(320, 260), int(p.facing))
	# The bright nucleus follows the actual projectile centre. The large soft
	# ribbons behind it are historical positions, drawn below the actors.
	PowerFXV10.glow(c, at, float(p.radius) * .68, WHITE, .28)


static func backdrop(c: CanvasItem, world, camera: float) -> void:
	for p in world.projectiles:
		if p.character != "ruan" or p.kind != "projectile":
			continue
		var at := Vector2(p.x / 256.0 - camera, p.y / 256.0)
		var super_move := str(p.move).begins_with("super")
		var facing := int(p.facing)
		var distance := absf(float(p.x - p.spawn_x)) / 256
		var length := minf(680 if super_move else 330, distance + 75)
		var spread := 130.0 if super_move else 55.0
		PowerFXV10.glow(c, at, 310 if super_move else 165, BLUE, .24)
		# Forked electrical paths join the current front to its release history.
		# These branches render below actors; the authored nucleus owns contact.
		for lane in [-1, 0, 1]:
			var points := PackedVector2Array()
			for j in 14:
				var t := float(j) / 13
				var zig := (1 if j % 2 else -1) * (22 if super_move else 12) * sin(t * PI)
				points.append(at + Vector2(-length * t * facing,
					lane * spread * t + zig))
			c.draw_polyline(points, Color(BLUE, .22), 28 if super_move else 14, true)
			c.draw_polyline(points, Color(VIOLET, .65), 10 if super_move else 6, true)
			c.draw_polyline(points, Color(WHITE, .85), 3.5 if super_move else 2, true)
			if super_move and distance > 90:
				var branch := points[5]
				c.draw_polyline(PackedVector2Array([branch,
					branch + Vector2(-30 * facing, -38 - lane * 23),
					branch + Vector2(-65 * facing, -24 - lane * 23),
					branch + Vector2(-110 * facing, -90 - lane * 30)]), Color(BLUE, .65), 5, true)
		if super_move and p.age > 10:
			cel(c, "champion", int(p.age) / 4 - 1,
				at - Vector2(minf(distance, 95) * facing, 0),
				SUPER_SIZE * .96, facing, Color(BLUE, .23))
	for f in world.power_actors():
		if f.character.id != "ruan" or f.state != FighterState.Id.ATTACK:
			continue
		var move: MoveData = f.current_move()
		if str(move.legacy.name) not in ["super", "uppercut"]:
			continue
		var root := Vector2(f.x / 256.0 - camera, f.ground_y / 256.0 - 15)
		var super_move := str(move.legacy.name) == "super"
		PowerFXV10.glow(c, root - Vector2(0, 145), 255 if super_move else 195, BLUE, .18)
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
				Vector2(370, 470), f.facing)
			cel(c, "charge", 3, at, Vector2(150, 165), f.facing)
		elif age < (32 if super_move else 6):
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
		BLUE if blocked else VIOLET, fade * .3)
