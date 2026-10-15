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
		if prop.hp <= 0:
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
				index = mini(10, ani.frames.size() - 1)
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
