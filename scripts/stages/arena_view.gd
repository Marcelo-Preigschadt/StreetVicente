class_name ArenaView
extends Node2D
## Environment animation never displaces a fighter, its ground plane or collision.
var stage_id := "patio"
var clock := 0.0
var paused := false
var impact_offset := Vector2.ZERO


func _process(delta: float) -> void:
	if not paused:
		clock += delta
	queue_redraw()


func _draw() -> void:
	var game := get_parent() as Node2D
	if game == null:
		return
	var area := Rect2(-game.position / game.scale, get_viewport_rect().size / game.scale)
	var arena := ArenaCatalog.get_arena(stage_id)
	var texture := LegacyRoster.texture(arena.image)
	# Anchor at the feet, and reveal scenery across both wide and tall viewports.
	var k := maxf(1.0, maxf(area.size.x / 1280.0, (625.0 - area.position.y) / 625.0)) * 1.015
	var target := Rect2(
		Vector2(640 - 640 * k, 625 - 625 * k) + impact_offset, Vector2(1280, 720) * k
	)
	draw_texture_rect(texture, target, false)
	if target.end.y < area.end.y:
		draw_texture_rect_region(
			texture,
			Rect2(area.position.x, target.end.y, area.size.x, area.end.y - target.end.y),
			Rect2(0, texture.get_height() - 32, texture.get_width(), 32)
		)
	var color := Color(arena.color)
	match arena.kind:
		"leaves":
			for i in 18:
				var x := fposmod(i * 173.0 + clock * (14 + i % 4 * 6), 1450) - 80
				var y := fposmod(i * 53.0 + clock * (11 + i % 3 * 4), 650) + 20
				var at := Vector2(x + sin(clock * .8 + i) * 24, y)
				draw_set_transform(
					at, sin(clock * 1.7 + i), Vector2(1, .5 + absf(sin(clock + i)) * .5)
				)
				draw_colored_polygon(
					PackedVector2Array(
						[Vector2(-6, 0), Vector2(0, -3), Vector2(7, 0), Vector2(0, 3)]
					),
					Color(color, .48)
				)
		"dust":
			for i in 24:
				var at := Vector2(
					fposmod(i * 87.0 + clock * 5, 1280), 200 + fposmod(i * 37.0 - clock * 7, 400)
				)
				draw_circle(at, 1.0 + i % 2 * .5, Color(color, .12 + .07 * sin(clock + i)))
		"night":
			for i in 25:
				var at := Vector2(200 + fposmod(i * 173.0, 1000), 125 + fposmod(i * 41.0, 170))
				draw_circle(at, .8, Color(.8, .94, 1, .2 + absf(sin(clock * .7 + i)) * .5))
			for i in 3:
				var x := fposmod(clock * (5 + i * 2) + i * 400, 1600) - 180
				draw_line(
					Vector2(x, 170 + i * 45),
					Vector2(x + 180, 170 + i * 45),
					Color(.6, .8, 1, .035),
					20,
					true
				)
		"server":
			for column in 10:
				for row in 8:
					var at := Vector2(80 + column * 125, 170 + row * 38)
					var alpha := .07 + .1 * maxf(0, sin(clock * 2.2 + column * 1.7 + row))
					draw_line(
						at, at + Vector2(12 + column % 3 * 7, 0), Color(color, alpha), 2, true
					)
	draw_set_transform(Vector2.ZERO)
