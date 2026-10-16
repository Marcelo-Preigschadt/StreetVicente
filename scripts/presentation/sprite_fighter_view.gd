class_name SpriteFighterView
extends FighterView
## Approved complete-body drawings; frame selection comes from the simulation.
var camera_x: float = 0.0
var use_new_art: bool = true
var impact_offset := Vector2.ZERO
var trails: Array = []
var trail_clock: float = 0.0


func setup(value: FighterModel, tint: Color) -> void:
	trails.clear()
	trail_clock = 0.0
	super.setup(value, tint)


func _process(_delta: float) -> void:
	if model == null:
		return
	var alpha := Engine.get_physics_interpolation_fraction()
	position = (
		previous_position.lerp(current_position, alpha) - Vector2(camera_x, 0) + impact_offset
	)
	trail_clock += _delta
	for ghost in trails:
		ghost.life -= _delta
	trails = trails.filter(func(g: Dictionary) -> bool: return g.life > 0.0)
	if model.state == FighterState.Id.ATTACK and trail_clock > 0.035 and use_new_art:
		var move := model.current_move()
		if move.phase(model.move_tick) == "ACTIVE":
			trails.append(
				{
					"pose": CharacterArt.frame(model),
					"life": 0.12,
					"position": position,
					"facing": model.facing
				}
			)
			trail_clock = 0.0
	queue_redraw()


func _draw() -> void:
	if model == null:
		return
	var sheet: Dictionary
	var frame: Dictionary
	if use_new_art and CharacterArt.has_frame(model):
		var art := CharacterArt.frame(model)
		sheet = art.sheet
		frame = art.frame
	else:
		var selected := model.character.pose_frame(model)
		if selected.is_empty():
			return
		var pose: Array = selected.pose
		var sheets: Dictionary = model.character.legacy.atlases
		sheet = sheets.get(str(pose[0]), sheets.base)
		var frames: Array = sheet.frames
		frame = frames[clampi(int(pose[1]), 0, frames.size() - 1)]
	var tex := LegacyRoster.texture(sheet.image)
	var src: Array = frame.rect
	var factor := (
		float(frame.get("scale", sheet.scale)) * CharacterMetrics.factor(model.character.id)
	)
	var width_factor := float(model.character.legacy.get("visualWidth", 1.0))
	draw_set_transform(
		Vector2(0, model.ground_y / float(FighterModel.SCALE) - position.y), 0, Vector2(1, 0.15)
	)
	draw_circle(Vector2.ZERO, 65, Color(0.01, 0.02, 0.03, 0.42))
	for ghost in trails:
		var gf: Dictionary = ghost.pose.frame
		var gs: Dictionary = ghost.pose.sheet
		var r: Array = gf.rect
		var k := float(gf.get("scale", gs.scale)) * CharacterMetrics.factor(model.character.id)
		draw_set_transform(
			Vector2(ghost.position) - position, 0, Vector2(int(ghost.facing) * width_factor, 1)
		)
		draw_texture_rect_region(
			LegacyRoster.texture(gs.image),
			Rect2(
				(float(gf.get("x", 0)) - float(gf.anchor)) * k,
				(float(gf.get("y", 0)) - float(gf.bottom)) * k,
				float(r[2]) * k,
				float(r[3]) * k
			),
			Rect2(r[0], r[1], r[2], r[3]),
			Color(model.character.color, float(ghost.life) * 1.6)
		)
	draw_set_transform(Vector2.ZERO, 0, Vector2(model.facing * width_factor, 1))
	var target := Rect2(
		(float(frame.x) - float(frame.anchor)) * factor,
		(float(frame.y) - float(frame.bottom)) * factor,
		float(src[2]) * factor,
		float(src[3]) * factor
	)
	var tint := (
		Color(1.8, 1.8, 1.8, 1)
		if model.state == FighterState.Id.HITSTUN and model.state_tick < 8
		else Color.WHITE
	)
	draw_texture_rect_region(
		tex, target, Rect2(float(src[0]), float(src[1]), float(src[2]), float(src[3])), tint
	)
	draw_set_transform(Vector2.ZERO)
	if debug_boxes:
		for rect in model.hurtboxes():
			_show_box(rect, Color("58deff"))
		for rect in model.attack_boxes():
			_show_box(rect, Color("ff6475"))


func _show_box(rect: Rect2i, color: Color) -> void:
	var local := Rect2(
		Vector2(rect.position) / FighterModel.SCALE - position - Vector2(camera_x, 0),
		Vector2(rect.size) / FighterModel.SCALE
	)
	draw_rect(local, Color(color, 0.12))
	draw_rect(local, color, false, 2)
