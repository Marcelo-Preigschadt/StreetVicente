class_name PowerView
extends Node2D
var sim: FightSimulation
var camera_x: float = 0.0


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if sim == null:
		return
	for p in sim.projectiles:
		var origin := Vector2(
			float(p.x) / FighterModel.SCALE - camera_x, float(p.y) / FighterModel.SCALE
		)
		var c := LegacyRoster.get_character(p.character)
		var color := c.color
		var pulse := float(int(p.age) % 12) / 12.0
		draw_set_transform(origin, 0, Vector2(signi(int(p.vx)), 1))
		if p.drone:
			draw_colored_polygon(
				PackedVector2Array(
					[
						Vector2(-25, -12),
						Vector2(15, -12),
						Vector2(29, 0),
						Vector2(15, 12),
						Vector2(-25, 12)
					]
				),
				Color("273c43")
			)
			draw_line(Vector2(-16, -16), Vector2(16, -16), color, 5, true)
			var rotor := sin(float(p.age) * 1.7) * 18.0
			draw_line(
				Vector2(-18 - rotor, -22), Vector2(-18 + rotor, -22), Color("d8faff"), 3, true
			)
			draw_line(Vector2(15 - rotor, -22), Vector2(15 + rotor, -22), Color("d8faff"), 3, true)
			if p.delay > 0:
				draw_arc(
					Vector2.ZERO,
					35,
					-PI / 2,
					-PI / 2 + TAU * (1.0 - float(p.delay) / float(p.get("warmup", 240))),
					24,
					Color(color, 0.6),
					2,
					true
				)
			draw_circle(Vector2(13, 0), 6, Color("e5ffb1"))
			if p.delay <= 0:
				draw_line(Vector2(-80, 0), Vector2(0, 0), Color(color, 0.8), 5, true)
		elif p.character == "khauany":
			for y in [-12, 0, 12]:
				draw_line(Vector2(-25, y), Vector2(22, y), Color("e9e4ff"), 3, true)
			draw_line(Vector2(8, -12), Vector2(8, 12), color, 4, true)
		elif p.character == "dienes":
			draw_set_transform(origin, sin(float(p.age) * 0.1) * 0.35, Vector2(signi(int(p.vx)), 1))
			draw_rect(Rect2(-20, -24, 38, 48), Color("e75d9f"))
			draw_rect(Rect2(-15, -20, 28, 40), Color("ffe7ed"))
			draw_line(Vector2(-13, -15), Vector2(10, -15), color, 3)
		elif p.character == "gustavo":
			for i in 6:
				draw_circle(
					Vector2(-i * 10, sin(float(p.age + i * 9) * 0.1) * 16),
					15 + (i % 3) * 4,
					Color(color, 0.4 + (i % 2) * 0.2)
				)
		elif p.character in ["ruan", "joao"]:
			var points := PackedVector2Array()
			for i in 8:
				points.append(Vector2(-75 + i * 14, (-1 if i % 2 else 1) * (6 + pulse * 18)))
			draw_polyline(points, color, 5, true)
			draw_polyline(points, Color.WHITE, 2, true)
		elif p.character in ["rafael", "adriano"]:
			draw_rect(Rect2(-24, -28, 46, 56), Color("c9a15c"))
			draw_rect(Rect2(-18, -23, 34, 46), Color("f8e3ae"), false, 3)
			draw_string(
				ThemeDB.fallback_font,
				Vector2(-10, 9),
				"IV" if p.character == "rafael" else "A",
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				24,
				Color("725128")
			)
		elif p.character == "marcelo":
			draw_string(
				ThemeDB.fallback_font,
				Vector2(-45, 10),
				["</>", "0xFF", "NIT", "{}", "1010"][int(p.age / 5) % 5],
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				34,
				color
			)
		elif p.character == "luciana":
			draw_string(
				ThemeDB.fallback_font,
				Vector2(-40, 10),
				"A!",
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				40,
				color
			)
		elif p.character == "gelton":
			for i in 4:
				draw_line(
					Vector2(-60, i * 10 - 15),
					Vector2(20 - i * 8, i * 8 - 16),
					Color.from_hsv(float(i) / 4, 0.7, 1),
					8,
					true
				)
		else:
			draw_arc(Vector2.ZERO, 24 + pulse * 10, -1.4, 1.4, 20, color, 6, true)
			draw_line(Vector2(-60, 0), Vector2(16, 0), Color(color, 0.7), 3, true)
		draw_set_transform(Vector2.ZERO)
