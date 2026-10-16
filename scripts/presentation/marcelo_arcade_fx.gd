class_name MarceloArcadeFX
extends RefCounted
## Native port of the original fight-fx.js: bracket core, circuit packets and rise.
## Curves/gradients are presentation only. No clock or visual drives collision.
const GREEN := Color("b8ed68")
const LIGHT := Color("e6ffc4")
const WHITE := Color("f6fff0")
static var glow_texture: GradientTexture2D


static func glow(canvas: CanvasItem, origin: Vector2, radius: float, alpha: float) -> void:
	if glow_texture == null:
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.22, 0.55, 1.0])
		gradient.colors = PackedColorArray(
			[Color(1, 1, 1, 1), Color(1, 1, 1, 0.65), Color(1, 1, 1, 0.15), Color(1, 1, 1, 0)]
		)
		glow_texture = GradientTexture2D.new()
		glow_texture.gradient = gradient
		glow_texture.width = 128
		glow_texture.height = 128
		glow_texture.fill = GradientTexture2D.FILL_RADIAL
		glow_texture.fill_from = Vector2(0.5, 0.5)
		glow_texture.fill_to = Vector2(1, 0.5)
	canvas.draw_texture_rect(
		glow_texture,
		Rect2(origin - Vector2.ONE * radius, Vector2.ONE * radius * 2),
		false,
		Color(GREEN, alpha)
	)


static func cubic(a: Vector2, b: Vector2, c: Vector2, d: Vector2, t: float) -> Vector2:
	var u := 1.0 - t
	return a * u * u * u + b * 3 * u * u * t + c * 3 * u * t * t + d * t * t * t


static func wave(canvas: CanvasItem, age: int, origin: Vector2, facing: int) -> void:
	canvas.draw_set_transform(origin, 0, Vector2(facing, 1))
	var t := float(age) / 120.0
	var radius := 26.0
	# Preserve the original round execution core and three tapered trailing ribbons.
	# Vertex alpha gives a fading tail without a new painted flame silhouette.
	for ribbon in 3:
		var wobble := sin(t * 15 + ribbon * 2) * radius * 0.3
		var points := PackedVector2Array()
		var colors := PackedColorArray()
		for i in 33:
			var u := float(i) / 32
			var p := cubic(
				Vector2(10, 0),
				Vector2(-39, -radius * (0.5 + ribbon * 0.2)),
				Vector2(-91, wobble - 10),
				Vector2(-140, wobble),
				u
			)
			points.append(p)
			colors.append(Color(GREEN, (1 - u) * 0.21))
		for i in range(1, 32):
			var u := 1 - float(i) / 32
			points.append(
				cubic(
					Vector2(10, 0),
					Vector2(-31, radius * (0.5 + ribbon * 0.1)),
					Vector2(-70, wobble + 9),
					Vector2(-140, wobble),
					u
				)
			)
			colors.append(Color(GREEN, (1 - u) * 0.21))
		canvas.draw_polygon(points, colors)
	glow(canvas, Vector2.ZERO, radius * 2.35, 0.62)
	# Ink silhouette, cel-shaded center and a small white glint keep the core crisp.
	canvas.draw_set_transform(origin, 0, Vector2(facing, 0.82))
	canvas.draw_circle(Vector2.ZERO, 27, Color("103523"), true, -1, true)
	for ring in 13:
		var u := float(ring) / 12
		canvas.draw_circle(
			Vector2(4 * u, -3 * u), 26 - ring * 1.65, GREEN.lerp(WHITE, u * 0.92), true, -1, true
		)
	canvas.draw_set_transform(origin, 0, Vector2(facing, 1))
	for side in [-1, 1]:
		var x: float = side * radius
		canvas.draw_polyline(
			PackedVector2Array(
				[
					Vector2(x * 0.22, -radius * 0.42),
					Vector2(x * 0.52, -radius * 0.42),
					Vector2(x * 0.65, 0),
					Vector2(x * 0.52, radius * 0.42),
					Vector2(x * 0.22, radius * 0.42)
				]
			),
			Color("103523"),
			4,
			true
		)
		canvas.draw_polyline(
			PackedVector2Array(
				[
					Vector2(x * 0.22, -radius * 0.42),
					Vector2(x * 0.52, -radius * 0.42),
					Vector2(x * 0.65, 0),
					Vector2(x * 0.52, radius * 0.42),
					Vector2(x * 0.22, radius * 0.42)
				]
			),
			WHITE,
			1.5,
			true
		)
	canvas.draw_arc(Vector2.ZERO, 33, -1.2, 1.2, 20, WHITE, 3, true)
	var packets: Array[Vector2] = []
	for i in 3:
		var x := -36.0 - i * 35 - fmod(t * 50, 30)
		var y := sin(t * 9 + i * 1.8) * 18
		canvas.draw_polyline(
			PackedVector2Array(
				[
					Vector2(x - 19, y + 8),
					Vector2(x - 7, y + 8),
					Vector2(x - 7, y - 7),
					Vector2(x + 10, y - 7)
				]
			),
			Color(GREEN, 0.9 - i * 0.2),
			2,
			true
		)
		canvas.draw_circle(Vector2(x + 10, y - 7), 2, LIGHT)
		packets.append(origin + Vector2((x - 2) * facing, y - 13))
	canvas.draw_set_transform(Vector2.ZERO)
	for i in 3:
		text(canvas, packets[i], "01" if i % 2 else "10", 15, Color(LIGHT, 0.85 - i * 0.16))


static func text(canvas: CanvasItem, at: Vector2, value: String, size: int, color: Color) -> void:
	# Counter-mirroring the letters keeps binary/brace glyphs readable on both sides.
	var font := ThemeDB.fallback_font
	var width := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	at.x -= width / 2
	canvas.draw_string_outline(
		font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 3, Color("103523")
	)
	canvas.draw_string(font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


static func charge(canvas: CanvasItem, f: FighterModel, camera: float) -> void:
	var move := f.current_move()
	if move.phase(f.move_tick) != "STARTUP":
		return
	var progress := clampf(float(f.move_tick) / maxf(1, move.startup * 2), 0, 1)
	var hand := Vector2(CombatGeometry.hand(f)) / 256.0 - Vector2(camera, 0)
	canvas.draw_set_transform(hand)
	var radius := 10 + progress * 14
	glow(canvas, Vector2.ZERO, radius * 2.3, progress * 0.45)
	var rect := Rect2(-radius * 1.25, -radius * 0.88, radius * 2.5, radius * 1.76)
	canvas.draw_rect(rect, Color("103523"))
	canvas.draw_rect(rect, GREEN, false, 2)
	text(canvas, Vector2(0, radius * 0.33), "{ }", int(radius * 1.1), LIGHT)
	canvas.draw_set_transform(Vector2.ZERO)


static func rise(canvas: CanvasItem, f: FighterModel, camera: float) -> void:
	var move := f.current_move()
	var phase := move.phase(f.move_tick)
	var hand := Vector2(CombatGeometry.hand(f)) / 256.0 - Vector2(camera, 0)
	if phase == "STARTUP":
		canvas.draw_set_transform(hand)
		glow(canvas, Vector2.ZERO, 24, 0.45)
		canvas.draw_set_transform(Vector2.ZERO)
		return
	if phase != "ACTIVE":
		return
	var root := Vector2(float(f.x) / 256 - camera, float(f.y) / 256)
	canvas.draw_set_transform(root, 0, Vector2(f.facing, 1))
	var fist := Vector2((hand.x - root.x) * f.facing, hand.y - root.y)
	# Original ascending Firewall, reshaped to meet the actual raised fist. The
	# bright edge runs outside the face/torso rather than covering the character.
	for layer in 3:
		var points := PackedVector2Array()
		var colors := PackedColorArray()
		var width := 13.0 + layer * 9
		for i in 25:
			var u := float(i) / 24
			points.append(
				cubic(
					Vector2(38 - width, -28),
					Vector2(112 - width, -105),
					Vector2(fist.x + 72 - width, fist.y + 70),
					fist,
					u
				)
			)
			colors.append(Color(GREEN, sin(u * PI) * (0.27 - layer * 0.055)))
		for i in range(1, 25):
			var u := 1 - float(i) / 24
			points.append(
				cubic(
					Vector2(38 + width, -28),
					Vector2(130 + width, -110),
					Vector2(fist.x + 40 + width, fist.y + 60),
					fist,
					u
				)
			)
			colors.append(Color(LIGHT, sin(u * PI) * (0.3 - layer * 0.06)))
		canvas.draw_polygon(points, colors)
	var edge := PackedVector2Array()
	for i in 25:
		var u := float(i) / 24
		edge.append(
			cubic(Vector2(53, -48), Vector2(159, -133), Vector2(fist.x + 56, fist.y + 64), fist, u)
		)
	canvas.draw_polyline(edge, Color(GREEN, 0.25), 11, true)
	canvas.draw_polyline(edge, LIGHT, 3, true)
	for i in 4:
		var u := 0.22 + i * 0.17
		var point := cubic(
			Vector2(53, -48), Vector2(159, -133), Vector2(fist.x + 56, fist.y + 64), fist, u
		)
		canvas.draw_polyline(
			PackedVector2Array(
				[
					point + Vector2(-12, 8),
					point + Vector2(-12, -4),
					point + Vector2(3, -4),
					point + Vector2(3, -13)
				]
			),
			Color(GREEN, 0.75),
			2,
			true
		)
	glow(canvas, fist, 29, 0.55)
	canvas.draw_set_transform(Vector2.ZERO)


static func impact(canvas: CanvasItem, kind: String, phase: float, alpha: float) -> void:
	if kind == "cast":
		canvas.draw_set_transform(Vector2.ZERO)
		return
	if kind == "block":
		canvas.draw_arc(Vector2.ZERO, 19 + phase * 27, -1.2, 1.2, 24, Color(LIGHT, alpha), 3, true)
		return
	# Graphic contact star and outward circuit fragments, not another flying wave.
	glow(canvas, Vector2.ZERO, 75, alpha * 0.5)
	for layer in 2:
		var points := PackedVector2Array()
		for i in 16:
			var angle := i * PI / 8
			var radius := (12.0 if i % 2 else 45.0 + (i % 3) * 8) * (1 + phase * 0.4)
			points.append(Vector2(cos(angle), sin(angle)) * radius * (1.0 if layer == 0 else 0.62))
		canvas.draw_colored_polygon(points, Color(GREEN if layer == 0 else WHITE, alpha))
	for i in 7:
		var direction := Vector2(cos(i * TAU / 7), sin(i * TAU / 7))
		var point := direction * (25 + phase * 68)
		canvas.draw_line(point, point + direction * 14, Color(LIGHT, alpha), 2, true)
		canvas.draw_rect(Rect2(point, Vector2(5, 5)), Color(GREEN, alpha))
