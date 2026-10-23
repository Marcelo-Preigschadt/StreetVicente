class_name StoryView
extends Node2D
var world: StorySimulation


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if world == null:
		return
	var camera := world.camera_x
	var a: Dictionary = LegacyRoster.catalog.story.acts[mini(world.act_index, 3)]
	draw_texture_rect(
		LegacyRoster.texture(a.background), Rect2(-camera * 0.6, 80, 2700, 650), false
	)
	for prop in world.props:
		if prop.get("used", false) or prop.hp <= 0:
			continue
		var art: Dictionary = LegacyRoster.catalog.story.props[prop.kind]
		draw_texture_rect(
			LegacyRoster.texture(art.file),
			Rect2(
				float(prop.x) / FighterModel.SCALE - camera - float(art.width) / 2,
				float(prop.lane) / FighterModel.SCALE - float(art.height),
				float(art.width),
				float(art.height)
			),
			false
		)
	_draw_objects(camera)
	var ordered: Array = world.enemies.duplicate()
	ordered.sort_custom(
		func(ae: Dictionary, be: Dictionary) -> bool:
			return ae.fighter.ground_y < be.fighter.ground_y
	)
	for enemy in ordered:
		var f: FighterModel = enemy.fighter
		if f.health <= 0 and world.tick - int(enemy.dead_tick) > 80:
			continue
		var data: Dictionary = LegacyRoster.catalog.story.enemies[enemy.kind]
		var alpha := 1.0 if f.health > 0 else 0.35
		var x := float(f.x) / FighterModel.SCALE - camera
		var y := float(f.y) / FighterModel.SCALE
		draw_set_transform(Vector2(x, y), 0, Vector2(f.facing, 1))
		if data.animation != null:
			var ani: Dictionary = data.animation
			var index := 0
			if f.state == FighterState.Id.WALK:
				index = (f.state_tick / 12) % mini(8, ani.frames.size())
			elif f.state == FighterState.Id.ATTACK:
				index = mini(
					8 if f.current_move().phase(f.move_tick) == "STARTUP" else 10,
					ani.frames.size() - 1
				)
			elif f.state == FighterState.Id.HITSTUN:
				index = mini(11, ani.frames.size() - 1)
			var frame: Dictionary = ani.frames[index]
			var r: Array = frame.rect
			var scale_value := float(ani.scale)
			draw_texture_rect_region(
				LegacyRoster.texture(ani.file),
				Rect2(
					-float(frame.anchorX) * scale_value,
					-float(frame.bottom) * scale_value,
					float(r[2]) * scale_value,
					float(r[3]) * scale_value
				),
				Rect2(r[0], r[1], r[2], r[3]),
				Color(1, 1, 1, alpha)
			)
		else:
			draw_texture_rect(
				LegacyRoster.texture(data.image),
				Rect2(-float(data.w) / 2, -float(data.h), float(data.w), float(data.h)),
				false,
				Color(1, 1, 1, alpha)
			)
		draw_set_transform(Vector2.ZERO)
		if f.health > 0:
			draw_rect(Rect2(x - 35, y - float(data.h) - 13, 70, 5), Color("192a31"))
			draw_rect(
				Rect2(x - 35, y - float(data.h) - 13, 70.0 * f.health / f.character.max_health, 5),
				Color(data.color)
			)


func _draw_objects(camera: float) -> void:
	for p in world.props:
		if int(p.get("fall", 0)) <= 0 or int(p.fall) > 180:
			continue
		var art: Dictionary = LegacyRoster.catalog.story.props.shelf
		var at := Vector2(
			float(p.x) / FighterModel.SCALE - camera, float(p.lane) / FighterModel.SCALE
		)
		draw_rect(Rect2(at + Vector2(-100, -12), Vector2(350, 24)), Color(1, 0.3, 0.2, 0.28))
		draw_set_transform(at, minf(PI / 2, float(p.fall) / 102 * PI / 2))
		draw_texture_rect(
			LegacyRoster.texture(art.file),
			Rect2(-float(art.width) / 2, -float(art.height), float(art.width), float(art.height)),
			false
		)
		draw_set_transform(Vector2.ZERO)
	for h in world.objects.hazards:
		var cycle := int(h.clock) % int(h.period)
		var active: bool = cycle >= int(h.warning) and cycle < int(h.warning) + int(h.active)
		var warning: bool = cycle < int(h.warning)
		var x := float(h.x) / FighterModel.SCALE - camera
		var y := float(h.lane) / FighterModel.SCALE
		var w := float(h.width)
		var color := (
			Color("80dfff")
			if h.kind == "frost"
			else Color("a7ed48") if h.kind == "acid" else Color("ffac56")
		)
		if active or warning:
			draw_rect(Rect2(x - w / 2, y - 9, w, 18), Color(color, 0.4 if active else 0.16))
			for i in 8:
				draw_line(
					Vector2(x - w / 2 + i * w / 8, y - 8),
					Vector2(x - w / 2 + i * w / 8 + 11, y + 8),
					Color(color, 0.8),
					3,
					true
				)
		if active:
			if h.kind == "cable":
				var line := PackedVector2Array()
				for i in 10:
					line.append(Vector2(x + sin(float(world.tick + i * 7)) * w * 0.32, y - i * 28))
				draw_polyline(line, Color(color, 0.35), 12, true)
				draw_polyline(line, Color.WHITE, 3, true)
			else:
				for i in 9:
					draw_circle(
						Vector2(x - w * 0.45 + i * w / 10, y - 13 - sin(world.tick * 0.1 + i) * 6),
						10,
						Color(color, 0.75)
					)
	var all_thrown: Array = []
	for gear in world.object_sets():
		all_thrown.append_array(gear.thrown)
	for p in all_thrown:
		var art: Dictionary = LegacyRoster.catalog.story.props[p.kind]
		var size := (
			Vector2(float(art.width), float(art.height))
			* (0.7 if p.kind in ["chair", "table"] else 1.0)
		)
		draw_set_transform(
			Vector2(float(p.x) / FighterModel.SCALE - camera, float(p.y) / FighterModel.SCALE),
			float(p.age) * 0.08
		)
		draw_texture_rect(LegacyRoster.texture(art.file), Rect2(-size / 2, size), false)
		draw_set_transform(Vector2.ZERO)
	for p in world.objects.bolts:
		var at := Vector2(float(p.x) / FighterModel.SCALE - camera, float(p.y) / FighterModel.SCALE)
		var color := Color(p.color)
		var tail := Vector2(float(p.vx), float(p.vy)).normalized() * 32
		draw_line(at - tail, at, Color(color, 0.3), 23, true)
		draw_line(at - tail, at, color, 10, true)
		draw_circle(at, 4, Color.WHITE)
	for i in world.object_sets().size():
		var gear: StoryObjects = world.object_sets()[i]
		if not gear.carry.is_empty():
			var art: Dictionary = LegacyRoster.catalog.story.props[gear.carry.kind]
			var f: FighterModel = world.players()[i]
			var size := Vector2(float(art.width), float(art.height))
			var at := Vector2(
				float(f.x) / FighterModel.SCALE - camera + f.facing * 90,
				float(f.y) / FighterModel.SCALE - 180
			)
			draw_texture_rect(LegacyRoster.texture(art.file), Rect2(at - size / 2, size), false)
