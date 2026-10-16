class_name MarceloPowerFX
extends RefCounted
## Digital ribbons, deployment, lock-on and beam contact are distinct phases.
## Geometry and damage remain exclusively in PowerSystem/CombatGeometry.
const MINT := Color("40ffa4")
const CYAN := Color("75f7ff")
const WHITE := Color("edfff7")


static func code(canvas: CanvasItem, age: int) -> void:
	var phase := int(age / 3) % 4
	var color: Color = [MINT, WHITE, CYAN, MINT][phase]
	var hull := PackedVector2Array(
		[
			Vector2(-112, -8),
			Vector2(-48, -29),
			Vector2(14, -23),
			Vector2(30, 0),
			Vector2(12, 26),
			Vector2(-52, 22),
			Vector2(-112, 9)
		]
	)
	canvas.draw_colored_polygon(hull, Color(MINT, 0.14))
	for band in 3:
		var points := PackedVector2Array()
		for i in 10:
			points.append(Vector2(-128 + i * 16, (band - 1) * 17 + sin((age + i * 4) * 0.25) * 5))
		canvas.draw_polyline(points, Color(MINT, 0.12), 12, true)
		canvas.draw_polyline(points, Color(MINT, 0.65), 4, true)
		canvas.draw_polyline(points, Color(color, 0.8 - band * 0.18), 2.0, true)
	for row in 3:
		for col in 7:
			var x := -114 + col * 19 + (age * 3) % 19
			var y := -16 + row * 17
			var symbol: String = ["0", "1", "{", "}", "[", "]", ";"][(age / 4 + row * 3 + col) % 7]
			canvas.draw_string(
				ThemeDB.fallback_font,
				Vector2(x, y),
				symbol,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				12,
				Color(MINT, 0.35 + float(col) * 0.09)
			)
	canvas.draw_polyline(
		PackedVector2Array(
			[Vector2(3, -27), Vector2(22, -19), Vector2(30, 0), Vector2(21, 20), Vector2(0, 28)]
		),
		Color(MINT, 0.18),
		16,
		true
	)
	canvas.draw_polyline(
		PackedVector2Array(
			[Vector2(3, -27), Vector2(22, -19), Vector2(30, 0), Vector2(21, 20), Vector2(0, 28)]
		),
		Color(MINT, 0.95),
		9,
		true
	)
	canvas.draw_polyline(
		PackedVector2Array(
			[Vector2(3, -27), Vector2(22, -19), Vector2(30, 0), Vector2(21, 20), Vector2(0, 28)]
		),
		color,
		4,
		true
	)
	canvas.draw_line(Vector2(-30, 0), Vector2(26, 0), WHITE, 2.5, true)


static func drone(
	canvas: CanvasItem, p: Dictionary, camera: float, clock: float, actors: Array
) -> void:
	var target := Vector2(float(p.x) / 256 - camera, float(p.y) / 256)
	var start := Vector2(float(p.spawn_x) / 256 - camera, float(p.spawn_y) / 256)
	var exposure := clampf(float(p.age) / 22, 0, 1)
	var eased := 1.0 - pow(1.0 - exposure, 3)
	var origin := start.lerp(target, eased)
	origin.y += sin(clock * 7 + float(p.id)) * 1.8 * exposure
	var alpha := minf(1.0, exposure * 3)
	if p.fired:
		alpha *= clampf(float(36 - int(p.age) + int(p.fire_tick)) / 18, 0, 1)
		origin.y -= float(int(p.age) - int(p.fire_tick)) * 0.12
	var facing := int(p.facing)
	var aim := Vector2.ZERO
	var found := false
	var distance := 1.0e20
	for actor in actors:
		if actor.slot == p.owner or actor.health <= 0:
			continue
		if p.lane_aware and absi(actor.ground_y - int(p.lane_y)) > 48 * 256:
			continue
		var d := absf(float(actor.x) - float(p.x))
		if d < distance:
			distance = d
			aim = Vector2(float(actor.x) / 256 - camera, float(actor.y) / 256 - 155)
			found = true
	if found and not p.fired:
		facing = 1 if aim.x >= origin.x else -1
		if int(p.delay) < 38:
			var lock := 1.0 - float(p.delay) / 38
			canvas.draw_set_transform(Vector2.ZERO)
			for i in 8:
				canvas.draw_line(
					origin.lerp(aim, float(i) / 8),
					origin.lerp(aim, float(i + 0.4) / 8),
					Color(MINT, 0.12 + lock * 0.12),
					1,
					true
				)
			canvas.draw_arc(
				aim,
				19 - lock * 5,
				-PI * 0.8,
				PI * 0.8,
				24,
				Color(CYAN, 0.25 + lock * 0.6),
				1.5,
				true
			)
			canvas.draw_line(aim - Vector2(24, 0), aim - Vector2(12, 0), Color(CYAN, lock), 2, true)
			canvas.draw_line(aim + Vector2(12, 0), aim + Vector2(24, 0), Color(CYAN, lock), 2, true)
	canvas.draw_set_transform(origin, 0, Vector2(facing, 1))
	var frame := int(p.age / 7) % 2
	if p.fired:
		frame = 2 if int(p.age) - int(p.fire_tick) < 12 else 3
	PowerArt.draw(canvas, "drone", frame, lerpf(0.10, 0.28, eased), Color(1, 1, 1, alpha))
	if exposure < 1:
		canvas.draw_arc(
			Vector2.ZERO,
			34 * (1 - exposure) + 12,
			-PI,
			PI,
			24,
			Color(CYAN, (1 - exposure) * 0.7),
			2,
			true
		)
	if not p.fired:
		var charge := 1.0 - float(p.delay) / maxf(1, float(p.warmup))
		canvas.draw_arc(
			Vector2(17, 5), 8, -PI / 2, -PI / 2 + TAU * charge, 20, Color(MINT, alpha), 2, true
		)
		canvas.draw_circle(Vector2(17, 5), 2 + charge * 3, Color(WHITE, charge * alpha))
	else:
		var hot := maxf(0, 1 - float(int(p.age) - int(p.fire_tick)) / 15)
		canvas.draw_line(
			Vector2(17, 5), Vector2(17 + hot * 26, 5), Color(WHITE, hot * alpha), 4, true
		)
	canvas.draw_set_transform(Vector2.ZERO)


static func beam(canvas: CanvasItem, from: Vector2, to: Vector2, alpha: float) -> void:
	canvas.draw_set_transform(Vector2.ZERO)
	canvas.draw_line(from, to, Color(MINT, alpha * 0.11), 22, true)
	canvas.draw_line(from, to, Color(MINT, alpha * 0.32), 10, true)
	canvas.draw_line(from, to, Color(CYAN, alpha * 0.8), 4, true)
	canvas.draw_line(from, to, Color(WHITE, alpha), 1.8, true)
	canvas.draw_circle(to, 5, Color(WHITE, alpha))


static func charge(canvas: CanvasItem, f: FighterModel, camera: float) -> void:
	if f.state != FighterState.Id.ATTACK:
		return
	var move := f.current_move()
	var name: String = move.legacy.get("name", "")
	if name not in ["special", "super", "drone", "uppercut"]:
		return
	var socket := CombatGeometry.hand(f)
	var hand := Vector2(socket) / 256.0 - Vector2(camera, 0)
	var progress := clampf(float(f.move_tick) / maxf(1, move.startup * 2), 0, 1)
	canvas.draw_set_transform(hand, 0, Vector2(f.facing, 1))
	if move.phase(f.move_tick) == "STARTUP":
		for i in 6:
			var angle := i * TAU / 6 + progress * 2
			var p := Vector2(cos(angle), sin(angle)) * (36 * (1 - progress) + 10)
			canvas.draw_line(p, p * 0.65, Color(MINT, 0.3 + progress * 0.6), 2, true)
			canvas.draw_string(
				ThemeDB.fallback_font,
				p,
				["0", "1", "{", "}", "[", "]"][i],
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				12,
				Color(CYAN, 0.4 + progress * 0.5)
			)
		if name in ["drone", "super"]:
			canvas.draw_rect(Rect2(-21, -13, 42, 26), Color(MINT, 0.1))
			canvas.draw_rect(Rect2(-21, -13, 42, 26), Color(CYAN, 0.7), false, 1)
			canvas.draw_line(Vector2(-16, 0), Vector2(16, 0), Color(WHITE, 0.8), 1, true)
	elif move.phase(f.move_tick) == "ACTIVE" and name == "uppercut":
		canvas.draw_set_transform(
			Vector2(float(f.x) / 256 - camera, float(f.y) / 256 - 170), 0, Vector2(f.facing, 1)
		)
		for i in 3:
			canvas.draw_arc(
				Vector2(20, -25),
				65 + i * 10,
				-2.0,
				0.7,
				24,
				Color(MINT, 0.7 - i * 0.2),
				4 - i,
				true
			)
	canvas.draw_set_transform(Vector2.ZERO)


static func burst(canvas: CanvasItem, b: Dictionary, camera: float) -> void:
	var phase := 1.0 - float(b.life) / float(b.max)
	var alpha := 1.0 - phase
	var origin := Vector2(float(b.x) - camera, float(b.y))
	if b.kind == "beam":
		beam(canvas, Vector2(float(b.origin_x) - camera, float(b.origin_y)), origin, alpha)
		return
	canvas.draw_set_transform(origin)
	var laser: bool = b.effect == "sentinelLaser" or b.kind == "laser"
	var count := 10 if b.kind in ["hit", "block"] else 6
	for i in count:
		var angle := TAU * float(i) / count + phase * 0.3
		var ray := Vector2(cos(angle), sin(angle))
		var distance := (16 + phase * 42) if b.kind in ["hit", "block"] else (8 + phase * 23)
		canvas.draw_line(ray * distance * 0.4, ray * distance, Color(MINT, alpha), 2, true)
		if not laser:
			canvas.draw_string(
				ThemeDB.fallback_font,
				ray * distance,
				["0", "1", "{", "}"][i % 4],
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				12,
				Color(CYAN, alpha)
			)
	canvas.draw_circle(Vector2.ZERO, 7 * alpha, Color(WHITE, alpha))
	canvas.draw_set_transform(Vector2.ZERO)
