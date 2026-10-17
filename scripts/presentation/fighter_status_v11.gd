class_name FighterStatusV11
extends Node2D
## Orbit clocks follow the actual dizzy state: pause, hitstop and recovery stay coherent.
var world
var camera_x := 0.0


static func dizzy_actors(value) -> Array:
	if value == null:
		return []
	return value.power_actors().filter(
		func(f: FighterModel) -> bool: return f.state == FighterState.Id.DIZZY and f.dizzy_ticks > 0
	)


static func head(f: FighterModel) -> Vector2:
	var top := f.y - 300 * 256
	var boxes := f.hurtboxes()
	if not boxes.is_empty():
		top = boxes[0].position.y
		for box in boxes:
			top = mini(top, box.position.y)
	return Vector2(f.x / 256.0, top / 256.0 - 21)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	for f: FighterModel in dizzy_actors(world):
		var origin := head(f) - Vector2(camera_x, 0)
		var time := f.state_tick / 120.0
		var alpha := minf(1, f.dizzy_ticks / 45.0)
		for i in 4:
			var angle := time * 3.0 + i * TAU / 4
			var at := origin + Vector2(cos(angle) * 43, sin(angle) * 9)
			var size := .11 + .018 * sin(angle)
			draw_set_transform(at, 0, Vector2(-1 if sin(angle) > 0 else 1, 1))
			if i % 2 == 0:
				ImpactArtV11.draw(self, "bird", int(time * 10) + i, size, Color(1, 1, 1, alpha))
			else:
				var points := PackedVector2Array()
				for n in 10:
					var a := n * PI / 5 - PI / 2 + sin(time * 2 + i) * .2
					points.append(Vector2(cos(a), sin(a)) * (9 if n % 2 == 0 else 4))
				draw_colored_polygon(points, Color("37232b", alpha))
				for n in points.size():
					points[n] *= .79
				draw_colored_polygon(points, Color("ffe75b", alpha))
				draw_circle(Vector2(-2, -3), 1.5, Color(1, 1, .8, alpha))
		draw_set_transform(Vector2.ZERO)
