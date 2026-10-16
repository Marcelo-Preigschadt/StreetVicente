class_name PowerBackdrop
extends Node2D
## Inserted above the stage and below the fighters; keeps character silhouettes lit.
var impact: CombatImpact


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if impact.super_time > 0:
		draw_rect(
			Rect2(0, 112, 1280, 552), Color(0.0, 0.025, 0.055, minf(0.65, impact.super_time * 2.0))
		)
		var c := LegacyRoster.get_character(impact.super_character)
		for i in 18:
			var x := fposmod(i * 83.0 + impact.clock * 500, 1480) - 100
			draw_line(
				Vector2(x, 120),
				Vector2(x - 240, 655),
				Color(c.color, impact.super_time * 0.45),
				2,
				true
			)
		draw_string(
			ThemeDB.fallback_font,
			Vector2(440, 210),
			str(c.legacy.powers.get("super", "SUPER")),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			32,
			Color(c.color, minf(1.0, impact.super_time * 4))
		)
		if impact.super_character == "marcelo":
			for i in 15:
				var x := 50.0 + i * 85
				var y := 130.0 + fposmod(impact.clock * 310 + i * 37, 490)
				for j in 4:
					draw_string(
						ThemeDB.fallback_font,
						Vector2(x, y - j * 20),
						["0", "1", "{", "}"][(i + j) % 4],
						HORIZONTAL_ALIGNMENT_LEFT,
						-1,
						16,
						Color(0.25, 1, 0.65, impact.super_time * (1.4 - j * 0.25))
					)
