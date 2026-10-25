class_name StoryView
extends Node2D
var world: StorySimulation
var presentation_frozen := false
var entities: Dictionary = {}
var previous_camera := 0.0
var current_camera := 0.0
var last_tick := -1
var last_world: StorySimulation


func sync(snap := false) -> void:
	if world == null:
		return
	snap = snap or last_world != world or world.tick < last_tick
	last_world = world
	last_tick = world.tick
	previous_camera = current_camera
	current_camera = world.camera_x
	if snap:
		previous_camera = current_camera
	var retained: Dictionary = {}
	for enemy in world.enemies:
		if enemy.fighter.health > 0 or enemy.dead_tick < 0 or world.tick - int(enemy.dead_tick) < 132:
			_bind("enemy:" + str(enemy.id), "enemy", enemy, retained, snap)
	for prop in world.props:
		if (not prop.get("used", false) and prop.hp > 0) or int(prop.get("fall", 0)) in range(1, 181):
			_bind("prop:" + str(prop.id), "prop", prop, retained, snap)
	for gear in world.object_sets():
		for prop in gear.thrown:
			_bind("thrown:" + str(prop.get("id", str(prop.age) + ":" + str(prop.x))), "thrown", prop, retained, snap)
	for gear in world.object_sets():
		for i in gear.debris.size():
			var piece: Dictionary = gear.debris[i]
			_bind("debris:%d:%d" % [world.object_sets().find(gear), int(piece.id)], "debris", piece, retained, snap)
	for key in entities.keys():
		if not retained.has(key):
			entities[key].queue_free()
			entities.erase(key)


func _bind(key: String, kind: String, value: Dictionary, retained: Dictionary, snap: bool) -> void:
	if not entities.has(key):
		var entity := StoryEntityView.new()
		entity.presenter = self
		entity.kind = kind
		add_child(entity)
		entities[key] = entity
		entity.entity = value
		entity.sync(true)
	else:
		entities[key].entity = value
		entities[key].sync(snap)
	retained[key] = true


func render_alpha() -> float:
	return 1.0 if presentation_frozen else Engine.get_physics_interpolation_fraction()


func render_camera() -> float:
	return lerpf(previous_camera, current_camera, render_alpha())


func _process(_delta: float) -> void:
	position = StoryLayout.ORIGIN
	scale = Vector2.ONE * StoryLayout.SCALE
	z_index = StoryLayout.Z_BASE
	queue_redraw()


func _draw() -> void:
	if world == null:
		return
	var camera := render_camera()
	var act: Dictionary = LegacyRoster.catalog.story.acts[mini(world.act_index, 3)]
	var texture: Texture2D
	if world.act_index == 0:
		texture = LegacyRoster.texture("res://assets/stages/v27/corridor.png")
		var canteen := LegacyRoster.texture("res://assets/stages/v27/canteen.png")
		# Both architectural panels and the continuous ground plane use the
		# actors' world projection. Furniture cannot slide against the pavement.
		_paint(texture, Rect2(StoryLayout.floor_left(camera), 440 - 864 * .578, 1728, 864))
		_paint(canteen, Rect2(1728 + StoryLayout.floor_left(camera), 440 - 864 * .548, 1728, 864))
	else:
		texture = LegacyRoster.texture(str(act.background))
		_paint(texture, Rect2(StoryLayout.floor_left(camera), -40, 3456, 800))
	var floor_rect := Rect2(Vector2(StoryLayout.floor_left(camera), 440), Vector2(3456, 320))
	var floor_source := Rect2(0, texture.get_height() * .585, texture.get_width(), texture.get_height() * .415)
	draw_texture_rect_region(texture, _local(floor_rect), floor_source)
	for enemy in world.enemies:
		var f: FighterModel = enemy.fighter
		if f.health <= 0 and enemy.dead_tick >= 0 and world.tick - int(enemy.dead_tick) > 100:
			continue
		_shadow(Vector2(float(f.x) / FighterModel.SCALE - camera, float(f.ground_y) / FighterModel.SCALE),
			45 if LegacyRoster.catalog.story.enemies[enemy.kind].get("fly", 0) > 0 else 54)
	for prop in world.props:
		if prop.get("used", false) or prop.hp <= 0:
			continue
		var size := StoryLayout.prop_size(str(prop.kind))
		_shadow(Vector2(float(prop.x) / FighterModel.SCALE - camera, float(prop.lane) / FighterModel.SCALE), size.x * .46)
	for gear in world.object_sets():
		for prop in gear.thrown:
			_shadow(Vector2(float(prop.x) / FighterModel.SCALE - camera, float(prop.lane) / FighterModel.SCALE), StoryLayout.prop_size(str(prop.kind)).x * .35)
	_draw_hazards(camera)


func _local(rect: Rect2) -> Rect2:
	return Rect2((rect.position - StoryLayout.ORIGIN) / StoryLayout.SCALE, rect.size / StoryLayout.SCALE)


func _paint(texture: Texture2D, rect: Rect2) -> void:
	draw_texture_rect(texture, _local(rect), false)


func _shadow(at: Vector2, radius: float) -> void:
	draw_set_transform(at, 0, Vector2(1, .18))
	draw_circle(Vector2.ZERO, radius, Color(0.035, 0.025, 0.025, .18))
	draw_circle(Vector2.ZERO, radius * .65, Color(0.02, 0.015, 0.02, .16))
	draw_set_transform(Vector2.ZERO)


func _draw_hazards(camera: float) -> void:
	for h in world.objects.hazards:
		var cycle := int(h.clock) % int(h.period)
		var active: bool = cycle >= int(h.warning) and cycle < int(h.warning) + int(h.active)
		var warning: bool = cycle < int(h.warning)
		var x := float(h.x) / FighterModel.SCALE - camera
		var y := float(h.lane) / FighterModel.SCALE
		var w := float(h.width)
		var color := Color("80dfff") if h.kind == "frost" else Color("a7ed48") if h.kind == "acid" else Color("ffac56")
		if active or warning:
			draw_rect(Rect2(x - w / 2, y - 9, w, 18), Color(color, .4 if active else .16))
			for i in 8:
				draw_line(Vector2(x - w / 2 + i * w / 8, y - 8), Vector2(x - w / 2 + i * w / 8 + 11, y + 8), Color(color, .8), 3, true)
		if active:
			if h.kind == "cable":
				var line := PackedVector2Array()
				for i in 10:
					line.append(Vector2(x + sin(float(world.tick + i * 7)) * w * .32, y - i * 28))
				draw_polyline(line, Color(color, .35), 12, true)
				draw_polyline(line, Color.WHITE, 3, true)
			else:
				for i in 9:
					draw_circle(Vector2(x - w * .45 + i * w / 10, y - 13 - sin(world.tick * .1 + i) * 6), 10, Color(color, .75))
	for p in world.objects.bolts:
		var at := Vector2(float(p.x) / FighterModel.SCALE - camera, float(p.y) / FighterModel.SCALE)
		var color := Color(p.color)
		var tail := Vector2(float(p.vx), float(p.vy)).normalized() * 32
		draw_line(at - tail, at, Color(color, .3), 23, true)
		draw_line(at - tail, at, color, 10, true)
		draw_circle(at, 4, Color.WHITE)
