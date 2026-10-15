class_name TrainingStage
extends Node2D
## Cenário vetorial leve: nenhum asset do jogo original é alterado.

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color("0b1323"))
	for i in 10:
		var x := 35 + i * 140
		draw_rect(Rect2(x, 205, 95, 320), Color("111f33"))
		draw_line(Vector2(x + 47, 205), Vector2(x + 47, 525), Color("1c3047"), 1)
		draw_line(Vector2(x, 315), Vector2(x + 95, 315), Color("1c3047"), 1)
		draw_line(Vector2(x, 420), Vector2(x + 95, 420), Color("1c3047"), 1)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(461, 245), "VICENTE DUTRA", HORIZONTAL_ALIGNMENT_LEFT, -1, 37, Color("263f53"))
	draw_string(font, Vector2(552, 277), "N I T   /   D O J O", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("365367"))
	draw_rect(Rect2(0, 525, 1280, 65), Color("14273b"))
	draw_line(Vector2(0, 590), Vector2(1280, 590), Color("4fe5cd"), 3)
	draw_rect(Rect2(0, 593, 1280, 127), Color("0e1b2d"))
	for x in range(-640, 1921, 120):
		draw_line(Vector2(640 + (x - 640) * 0.45, 593), Vector2(x, 720), Color("1d3346"), 1)
	for y in [611, 642, 688]:
		draw_line(Vector2(0, y), Vector2(1280, y), Color("1d3346"), 1)
	draw_circle(Vector2(640, 619), 4, Color("4fe5cd"))
