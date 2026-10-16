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
		var slide := clampf((0.5 - impact.super_time) * 10, 0, 1)
		var alpha := minf(1.0, impact.super_time * 5)
		ArcadeTheme.plate(
			self, Rect2(-90 + slide * 90, 205, 1370, 222), Color(ArcadeTheme.INK, alpha * 0.8), 60
		)
		draw_line(Vector2(0, 208), Vector2(1280, 208), Color(c.color, alpha), 3, true)
		draw_line(Vector2(0, 424), Vector2(1280, 424), Color(c.color, alpha), 3, true)
		draw_texture_rect(
			LegacyRoster.texture(c.legacy.portrait),
			Rect2(70 - (1 - slide) * 160, 214, 207, 207),
			false,
			Color(1, 1, 1, alpha)
		)
		ArcadeTheme.title(self, Vector2(327, 278), "SUPER!", 43, Color(ArcadeTheme.PAPER, alpha))
		ArcadeTheme.title(
			self,
			Vector2(326, 342),
			str(c.legacy.powers.get("super", "SUPER")).to_upper(),
			36,
			Color(c.color, alpha)
		)
		draw_string(
			ThemeDB.fallback_font,
			Vector2(330, 386),
			c.display_name.to_upper(),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			22,
			Color(ArcadeTheme.PAPER, alpha)
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
