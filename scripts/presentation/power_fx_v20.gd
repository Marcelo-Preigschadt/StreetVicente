class_name PowerFXV20
extends RefCounted
## Roster audit: authored signatures, arena-scale supers, trails behind actors.
## All clocks and hit areas are owned by the fixed-step simulation.
const IDS := ["marcelo", "adriano", "rafael", "joao", "gustavo", "gelton", "marcelino", "marcos"]
const COLORS := {"marcelo": Color("60ffc0"), "adriano": Color("ffc44f"),
	"rafael": Color("ffd290"), "joao": Color("c4ff55"), "gustavo": Color("b3a1ff"),
	"gelton": Color("ff69ce"), "marcelino": Color("8cf1ff"), "marcos": Color("68caff")}
static var art: Dictionary = {}


static func load_data(id: String) -> Dictionary:
	if not art.has(id):
		art[id] = JSON.parse_string(FileAccess.get_file_as_string(
			"res://data/characters/%s-effects-v20.json" % id))
	return art[id]


static func clip_for(id: String, kind: String) -> String:
	if kind in ["ultimate", "ultimate_hit"]:
		return kind
	match id:
		"gustavo": return {"charge": "gather", "wave": "wave", "rise": "rise", "impact": "impact"}[kind]
		"gelton": return {"charge": "charge", "wave": "stroke", "rise": "arc", "impact": "splash"}[kind]
		"marcelino": return {"charge": "gather", "wave": "impulse", "rise": "rise", "impact": "impact"}[kind]
		"marcos": return {"charge": "charge", "wave": "session", "rise": "stack", "impact": "panic"}[kind]
		"joao": return "roll" if kind == "impact" else kind
	return kind


static func cel(c: CanvasItem, id: String, kind: String, index: int,
	at: Vector2, size: Vector2, facing: int = 1, tint: Color = Color.WHITE) -> void:
	EffectCelV20.draw(c, load_data(id), clip_for(id, kind), index, at, size, facing, tint)


static func projectile(c: CanvasItem, p: Dictionary, camera: float) -> void:
	var at := Vector2(p.x / 256.0 - camera, p.y / 256.0)
	var super_move := str(p.move).begins_with("super")
	var clip := "ultimate" if super_move and p.character in ["gustavo", "gelton", "marcelino"] else "wave"
	cel(c, p.character, clip, int(p.age) / 5, at,
		Vector2(570, 470) if super_move else Vector2(350, 280), int(p.facing))
	PowerFXV10.glow(c, at, float(p.radius) * .65, Color.WHITE, .22)


static func backdrop(c: CanvasItem, world, camera: float) -> void:
	for p in world.projectiles:
		if p.character not in IDS or p.kind != "projectile":
			continue
		var id := str(p.character)
		var at := Vector2(p.x / 256.0 - camera, p.y / 256.0)
		var super_move := str(p.move).begins_with("super")
		var distance := absf(float(p.x - p.spawn_x)) / 256
		var length := minf(690 if super_move else 340, distance + 65)
		var color: Color = COLORS[id]
		var facing := int(p.facing)
		PowerFXV10.glow(c, at, 280 if super_move else 135, color, .18)
		for i in 5 if super_move else 3:
			var t := float(i + 1) / 6
			var behind := at - Vector2(length * t * facing, 0)
			match id:
				"gustavo":
					cel(c, id, "charge", 3, behind + Vector2(0, sin(p.age * .1 + i) * 38),
						Vector2(180, 130) * (1 - t * .45), facing, Color(color, .32 * (1 - t)))
				"gelton":
					var paint: Color = [Color("ff69ce"), Color("66edff"), Color("ffe561")][i % 3]
					c.draw_line(behind + Vector2(32 * facing, (i - 2) * 30),
						behind + Vector2(-72 * facing, (i - 2) * 38), Color(paint, 1 - t), 12 - t * 7, true)
				"marcelino":
					c.draw_arc(behind, (115 if super_move else 55) * (1 - t * .45),
						-1.25 if facing == 1 else PI - 1.25, 1.25 if facing == 1 else PI + 1.25,
						32, Color(color, .7 * (1 - t)), 5, true)
				"marcelo":
					var y := (i - 2) * (35 if super_move else 17)
					c.draw_polyline(PackedVector2Array([behind + Vector2(40 * facing, y),
						behind + Vector2(0, y), behind + Vector2(0, y - 25),
						behind + Vector2(-45 * facing, y - 25)]), Color(color, .8 * (1 - t)), 4, true)
				_:
					# Banners and parchment retain their respective authored silhouettes.
					cel(c, id, "wave", int(p.age) / 5 - i, behind,
						Vector2(270, 250) if super_move else Vector2(145, 130), facing,
						Color(color, .22 * (1 - t)))
		projectile(c, p, camera)
	for f in world.power_actors():
		if f.character.id not in IDS or f.state != FighterState.Id.ATTACK:
			continue
		var id := str(f.character.id)
		var move: MoveData = f.current_move()
		var name := str(move.legacy.get("name", ""))
		if name not in ["super", "uppercut"]:
			continue
		var root := Vector2(f.x / 256.0 - camera, f.y / 256.0)
		var floor_at := Vector2(root.x, f.ground_y / 256.0 - 8)
		var color: Color = COLORS[id]
		var phase := move.phase(f.move_tick)
		PowerFXV10.glow(c, floor_at - Vector2(0, 140), 255, color, .16)
		if name == "uppercut" and phase == "ACTIVE":
			cel(c, id, "rise", (f.move_tick - move.startup * 2) / 6,
				root + Vector2(95 * f.facing, -210), Vector2(360, 465), f.facing)
		elif name == "super" and id != "joao":
			cel(c, id, "charge", 1, floor_at, Vector2(410, 135), f.facing, Color(1, 1, 1, .65))
		if id == "marcos" and name == "super" and phase == "ACTIVE":
			cel(c, id, "ultimate", mini(3, (f.move_tick - move.startup * 2) / 6),
				root + Vector2(100 * f.facing, -10), Vector2(640, 500), f.facing)
		if id == "joao" and name == "super":
			roll(c, f, camera)


static func charge(c: CanvasItem, f: FighterModel, camera: float, actors: Array) -> void:
	var move := f.current_move()
	var name := str(move.legacy.get("name", ""))
	if name not in ["special", "super", "uppercut", "drone"]:
		return
	var id := str(f.character.id)
	var at := PowerFXV10.hand(f, camera)
	var phase := move.phase(f.move_tick)
	var amount := clampf(f.move_tick / float(maxi(1, move.startup * 2)), 0, 1)
	if phase == "STARTUP":
		cel(c, id, "charge", mini(2, int(amount * 3)), at,
			Vector2(110, 100).lerp(Vector2(285, 245) if name == "super" else Vector2(205, 185), amount), f.facing)
	elif phase == "ACTIVE":
		var age := f.move_tick - move.startup * 2
		if id == "joao" and name == "special":
			cel(c, id, "wave", age / 4, at, Vector2(350, 280), f.facing)
		elif name == "uppercut":
			cel(c, id, "charge", 3, at, Vector2(130, 150), f.facing)
		elif age < (40 if name == "super" else 9):
			cel(c, id, "charge", 3, at, Vector2(245, 210) if name == "super" else Vector2(180, 160), f.facing)
	if id == "joao" and f.roll_phase == RollMotion.SHOCK:
		var root := Vector2(f.x / 256.0 - camera, f.y / 256.0 - 145)
		for target in actors:
			if target.slot == f.roll_target:
				var end := Vector2(target.x / 256.0 - camera, target.y / 256.0 - 150)
				for i in 4:
					PowerFXV10.bolt(c, root + Vector2(0, (i - 2) * 46),
						end + Vector2(0, (i - 2) * 54), COLORS.joao, f.roll_tick / 3 + i * 17, .9)


static func roll(c: CanvasItem, f: FighterModel, camera: float) -> void:
	var at := Vector2(f.x / 256.0 - camera, f.y / 256.0 - 130)
	if f.roll_phase not in [RollMotion.TRAVEL, RollMotion.SHOCK, RollMotion.REBOUND]:
		return
	cel(c, "joao", "roll", f.move_tick / 4, at, Vector2(440, 425), f.facing,
		Color(1, 1, 1, .65 if f.roll_phase == RollMotion.REBOUND else 1))
	for i in 3:
		PowerFXV10.bolt(c, at + Vector2(-70 * f.facing, (i - 1) * 100),
			at + Vector2((-320 - i * 32) * f.facing, (i - 1) * 55),
			COLORS.joao, f.move_tick / 3 + i * 13, .7 - i * .12)


static func impact(c: CanvasItem, b: Dictionary, camera: float) -> void:
	var id := str(b.character)
	var t := clampf(1 - float(b.life) / float(b.max), 0, 1)
	var fade := pow(1 - t, .65)
	var at := Vector2(float(b.x) - camera, float(b.y))
	var facing := int(b.get("facing", 1))
	var super_move := str(b.move).begins_with("super")
	if b.kind == "beam":
		beam(c, Vector2(float(b.origin_x) - camera, float(b.origin_y)), at, fade)
		return
	if b.kind == "cast":
		cel(c, id, "charge", 3, at, Vector2(265, 230) if super_move else Vector2(200, 180), facing, Color(1, 1, 1, fade))
		return
	var size := Vector2(640, 520) if super_move else Vector2(340, 315)
	if str(b.move).begins_with("uppercut"):
		size = Vector2(360, 430)
	if b.kind == "block":
		size *= .72
	var clip := "laser_hit" if id == "marcelo" and b.effect == "sentinelLaser" else "impact"
	if super_move and id in ["gustavo", "gelton", "marcelino", "marcos"]:
		clip = "ultimate_hit"
	if id == "marcos" or id == "joao":
		if str(b.move).begins_with("special"):
			clip = "wave"
		elif str(b.move).begins_with("uppercut"):
			clip = "rise"
	cel(c, id, clip, mini(3, int(t * 4)), at, size * (1 + t * .18), facing, Color(1, 1, 1, fade))
	PowerFXV10.glow(c, at, 230 if super_move else 120, COLORS[id], fade * .25)


static func drone(c: CanvasItem, p: Dictionary, camera: float, clock: float, actors: Array) -> void:
	var at := Vector2(p.x / 256.0 - camera, p.y / 256.0)
	var start := Vector2(p.spawn_x / 256.0 - camera, p.spawn_y / 256.0)
	var exposure := clampf(float(p.age) / 22, 0, 1)
	at = start.lerp(at, 1 - pow(1 - exposure, 3))
	at.y += sin(clock * 7 + float(p.id)) * 1.8 * exposure
	var facing := int(p.facing)
	var alpha := minf(1, exposure * 3)
	var frame := 0 if p.delay > 40 else 1
	if p.fired:
		frame = 2 if p.age - p.fire_tick < 12 else 3
		alpha *= clampf(float(36 - p.age + p.fire_tick) / 18, 0, 1)
	elif p.delay < 38:
		for actor in actors:
			if actor.slot == p.owner or actor.health <= 0:
				continue
			if p.lane_aware and absi(actor.ground_y - int(p.lane_y)) > 48 * 256:
				continue
			var aim := Vector2(actor.x / 256.0 - camera, actor.y / 256.0 - 155)
			facing = 1 if aim.x >= at.x else -1
			c.draw_line(at, aim, Color(COLORS.marcelo, .18), 2, true)
			c.draw_arc(aim, 28, clock * 4, clock * 4 + PI * 1.5, 32, Color("aaffef"), 2, true)
			break
	cel(c, "marcelo", "drone", frame, at, Vector2(155, 135) * lerpf(.4, 1, exposure), facing, Color(1, 1, 1, alpha))


static func beam(c: CanvasItem, from: Vector2, to: Vector2, alpha: float) -> void:
	c.draw_set_transform(Vector2.ZERO)
	for layer in [[48, .09], [27, .20], [13, .65], [6, 1.0]]:
		c.draw_line(from, to, Color(COLORS.marcelo if layer[0] > 6 else Color.WHITE, alpha * layer[1]), layer[0], true)
	cel(c, "marcelo", "laser_hit", 0, from, Vector2(85, 85), 1, Color(1, 1, 1, alpha))
