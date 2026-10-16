class_name ArcadeTheme
extends RefCounted
## Shared native Godot graphic language: ink, slanted plates, cel highlights.
const INK := Color("090d22")
const PAPER := Color("fff3d6")
const BLUE := Color("54c8ff")
const RED := Color("ff586b")
const GOLD := Color("ffcb59")
static var title_font: FontVariation
static var background: GradientTexture2D


static func load_data() -> void:
	if title_font != null:
		return
	title_font = FontVariation.new()
	title_font.base_font = ThemeDB.fallback_font
	title_font.variation_embolden = 1.2
	title_font.variation_transform = Transform2D(Vector2(1, 0), Vector2(-0.16, 1), Vector2.ZERO)
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color("111a39"), Color("272044")])
	background = GradientTexture2D.new()
	background.gradient = gradient
	background.width = 128
	background.height = 128
	background.fill_from = Vector2.ZERO
	background.fill_to = Vector2.ONE


static func plate(canvas: CanvasItem, rect: Rect2, color: Color, bevel: float = 12) -> void:
	var p := rect.position
	var s := rect.size
	canvas.draw_colored_polygon(
		PackedVector2Array(
			[
				p + Vector2(bevel, 0),
				p + Vector2(s.x, 0),
				p + Vector2(s.x - bevel, s.y),
				p + Vector2(0, s.y)
			]
		),
		color
	)


static func title(
	canvas: CanvasItem, at: Vector2, value: String, size: int, color: Color, outline: int = 5
) -> void:
	load_data()
	canvas.draw_string_outline(
		title_font, at + Vector2(3, 5), value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline + 2, INK
	)
	canvas.draw_string_outline(
		title_font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, INK
	)
	canvas.draw_string(title_font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


static func backdrop(canvas: CanvasItem, clock: float) -> void:
	load_data()
	canvas.draw_texture_rect(background, Rect2(0, 0, 1280, 720), false)
	for i in 9:
		var x := -150.0 + i * 190 + fmod(clock * 12, 190)
		plate(canvas, Rect2(x, 0, 95, 720), Color(0.3, 0.27, 0.56, 0.12), 160)
	for row in 12:
		for col in 13:
			canvas.draw_circle(Vector2(1030 + col * 22, 5 + row * 22), 2.5, Color(BLUE, 0.12))
	for row in 7:
		for col in 10:
			canvas.draw_circle(Vector2(col * 22, 560 + row * 22), 2, Color(RED, 0.13))
