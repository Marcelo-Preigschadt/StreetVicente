class_name StoryEntityView
extends Node2D
var presenter
var entity: Dictionary
var kind := "enemy"
var previous := Vector2.ZERO
var current := Vector2.ZERO


func sync(snap := false) -> void:
	previous = current
	var lane: float
	if kind == "enemy":
		var f: FighterModel = entity.fighter
		if material == null and StoryDirection.PROFILES.get(str(entity.kind), {}).get("atlas", "") == "guard":
			var paint := ShaderMaterial.new()
			paint.shader = preload("res://shaders/enemy_palette.gdshader")
			paint.set_shader_parameter("armor_tint", Color(str(StoryDirection.PROFILES[entity.kind].get("palette", "559b85"))))
			material = paint
		current = Vector2(f.x, f.y) / FighterModel.SCALE
		lane = float(f.ground_y) / FighterModel.SCALE
	else:
		current = Vector2(float(entity.x), float(entity.lane if kind in ["prop", "decor"] else entity.y)) / FighterModel.SCALE
		lane = float(entity.lane) / FighterModel.SCALE
	if snap:
		previous = current
	z_index = roundi(lane)
	scale = Vector2.ONE * StoryLayout.depth(lane) * (float(entity.get("scale", 1.0)) if kind == "decor" else 1.0)


func _process(_delta: float) -> void:
	position = previous.lerp(current, presenter.render_alpha()) - Vector2(presenter.render_camera(), 0)
	queue_redraw()


func _draw() -> void:
	if entity.is_empty():
		return
	if kind == "enemy":
		_draw_enemy()
	elif kind == "debris":
		_draw_debris()
	else:
		_draw_prop()


func _draw_enemy() -> void:
	var f: FighterModel = entity.fighter
	var profile: Dictionary = LegacyRoster.catalog.story.enemies[entity.kind]
	var selected := StoryEnemyArt.sample(entity, presenter.world.tick)
	var frame: Dictionary = selected.frame
	var sheet: Dictionary = selected.sheet
	var rect: Array = frame.rect
	var k := float(sheet.scale) * float(frame.get("scaleCorrection", 1.0))
	var age: int = maxi(0, presenter.world.tick - int(entity.dead_tick))
	var alpha := clampf((presenter.world.tick - int(entity.get("spawn_tick", -24))) / 24.0, 0, 1) if f.health > 0 else clampf((132.0 - age) / 55.0, 0, 1)
	draw_set_transform(Vector2.ZERO, 0, Vector2(f.facing, 1))
	var tint := Color(1.6, 1.6, 1.6, alpha) if f.state == FighterState.Id.HITSTUN and f.state_tick < 6 else Color(1, 1, 1, alpha)
	draw_texture_rect_region(LegacyRoster.texture(sheet.file),
		Rect2(-float(frame.anchorX) * k, -float(frame.bottom) * k, float(rect[2]) * k, float(rect[3]) * k),
		Rect2(rect[0], rect[1], rect[2], rect[3]), tint)
	draw_set_transform(Vector2.ZERO)
	if f.health > 0:
		if profile.get("boss", false) and f.state == FighterState.Id.ATTACK and f.current_move().phase(f.move_tick) == "STARTUP":
			var warning := float(f.move_tick) / maxi(1, f.current_move().startup * 2)
			draw_set_transform(Vector2(0, float(f.ground_y - f.y) / FighterModel.SCALE), 0, Vector2(1, .22))
			draw_arc(Vector2.ZERO, 55 + 15 * warning, 0, TAU * warning, 32, Color(1, .3, .12, .75), 5, true)
			draw_set_transform(Vector2.ZERO)
		if profile.get("boss", false) or (f.health < f.character.max_health and f.stun_quiet > 0):
			var top := -float(profile.h) - 13
			draw_rect(Rect2(-35, top, 70, 5), Color("192a31"))
			draw_rect(Rect2(-35, top, 70.0 * f.health / f.character.max_health, 5), Color(profile.color))


func _draw_prop() -> void:
	var item := str(entity.kind)
	var art: Dictionary = LegacyRoster.catalog.story.props[item]
	var size := StoryLayout.prop_size(item)
	var tint := Color(1, .98, .94, 1) if presenter.world.act_index == 0 else Color.WHITE
	var offset := Vector2.ZERO
	var angle := 0.0
	if kind in ["prop", "decor"]:
		if int(entity.get("fall", 0)) > 0:
			angle = minf(PI / 2, float(entity.fall) / 102 * PI / 2)
		offset = Vector2(-size.x / 2, -size.y)
	else:
		angle = float(entity.age) * (.025 if item == "table" else .045) * int(entity.get("direction", 1))
		var support := (absf(sin(angle)) * size.x + absf(cos(angle)) * size.y) / 2
		var floor_delta := float(entity.lane) / FighterModel.SCALE - current.y
		var adjustment := minf(0, floor_delta - support)
		draw_set_transform(Vector2(0, adjustment), angle)
		offset = -size / 2
		if entity.get("landed", false):
			tint.a = clampf((30.0 - int(entity.rest)) / 20, 0, 1)
	if kind in ["prop", "decor"]:
		draw_set_transform(Vector2.ZERO, angle)
	draw_texture_rect(LegacyRoster.texture(art.file), Rect2(offset, size), false, tint)
	draw_set_transform(Vector2.ZERO)
	if item in ["serverrack", "networkcabinet", "ups", "instrument"]:
		for i in 4:
			if (presenter.world.tick / 18 + int(entity.get("id", 0)) + i * 3) % 5 < 3:
				draw_circle(Vector2(size.x * .12, -size.y * (.38 + i * .08)), 1.5, Color(.3, 1, .65, .75))


func _draw_debris() -> void:
	var texture := LegacyRoster.texture(LegacyRoster.catalog.story.props[entity.kind].file)
	var full := StoryLayout.prop_size(str(entity.kind))
	var part := int(entity.part)
	var region := Rect2((part % 2) * texture.get_width() / 2.0,
		(part / 2) * texture.get_height() / 2.0, texture.get_width() / 2.0, texture.get_height() / 2.0)
	var tint := Color(1, .96, .9, clampf((110.0 - int(entity.age)) / 35, 0, 1))
	draw_set_transform(Vector2.ZERO, int(entity.direction) * int(entity.age) * .06)
	draw_texture_rect_region(texture, Rect2(-full / 4, full / 2), region, tint)
	draw_set_transform(Vector2.ZERO)
