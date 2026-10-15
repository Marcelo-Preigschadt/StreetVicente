class_name FighterView
extends Node2D
## Manequim original de validação. Substituir por SpriteFrames/Skeleton2D do elenco.
## Toda trigonometria, IK e interpolação deste arquivo são exclusivamente visuais.
var model: FighterModel
var previous_position := Vector2.ZERO
var current_position := Vector2.ZERO
var previous_distance: float = 0.0
var distance: float = 0.0
var debug_boxes: bool = false
var accent := Color("4fe5cd")
var visual_facing: int = 1

func setup(value: FighterModel, tint: Color) -> void:
	model = value
	accent = tint
	sync(true)

func sync(snap: bool = false) -> void:
	previous_position = current_position
	previous_distance = distance
	current_position = Vector2(model.x, model.y) / float(FighterModel.SCALE)
	if model.state == FighterState.Id.WALK:
		distance += absf(current_position.x - previous_position.x)
	if snap:
		previous_position = current_position
		previous_distance = distance

func _process(_delta: float) -> void:
	if model == null:
		return
	var alpha := Engine.get_physics_interpolation_fraction()
	position = previous_position.lerp(current_position, alpha)
	visual_facing = model.facing
	queue_redraw()

func _draw() -> void:
	if model == null:
		return
	var phase := lerpf(previous_distance, distance, Engine.get_physics_interpolation_fraction()) / 150.0 * TAU
	var walking := model.state == FighterState.Id.WALK
	var low := model.state == FighterState.Id.CROUCH or (model.input.has(CombatInput.DOWN) and model.grounded() and model.state == FighterState.Id.BLOCK)
	var bob := sin(phase * 2.0) * 3.0 if walking else sin(model.state_tick / 120.0 * 3.8) * 1.8
	var pelvis := Vector2(-5, -93 if not low else -52) + Vector2(0, bob)
	var shoulder := pelvis + Vector2(6, -60 if not low else -44)
	var head := shoulder + Vector2(2, -25)
	var front_foot := Vector2(34, -4)
	var rear_foot := Vector2(-34, -4)
	if walking:
		front_foot = _gait_foot(phase, 1.0)
		rear_foot = _gait_foot(phase + PI, -1.0)
	if not model.grounded():
		front_foot = Vector2(26, -24)
		rear_foot = Vector2(-25, -38)
	var front_hand := shoulder + Vector2(43, -15)
	var rear_hand := shoulder + Vector2(12, -30)
	var attack_extension := 0.0
	if model.state == FighterState.Id.ATTACK:
		var move := model.current_move()
		var t := float(model.move_tick) / 2.0
		if t < move.startup:
			attack_extension = t / move.startup * 0.15
		elif t < move.startup + move.active:
			attack_extension = 1.0
		else:
			attack_extension = maxf(0.0, 1.0 - (t - move.startup - move.active) / move.recovery)
		if model.move_id == "jab":
			shoulder.x += attack_extension * 12
			front_hand = shoulder + Vector2(105, -1) * maxf(0.35, attack_extension)
		elif model.move_id == "sweep":
			pelvis.y += 35 * attack_extension
			shoulder.y += 35 * attack_extension
			front_foot = front_foot.lerp(Vector2(162, -22), attack_extension)
		else:
			pelvis.x -= 12 * attack_extension
			front_foot = front_foot.lerp(Vector2(162, -88), attack_extension)
			rear_foot = rear_foot.lerp(Vector2(-18, -4), attack_extension)
	if model.state in [FighterState.Id.HITSTUN, FighterState.Id.KO]:
		shoulder.x -= 18
		head.x -= 22
		front_hand += Vector2(-12, 25)
	if model.state == FighterState.Id.BLOCK:
		front_hand = shoulder + Vector2(32, -25)
		rear_hand = shoulder + Vector2(22, -33)
	head = shoulder + Vector2(1, -26)
	var main := accent
	if model.state == FighterState.Id.HITSTUN and model.state_tick < 8:
		main = Color.WHITE
	if model.state == FighterState.Id.KO:
		main = main.darkened(0.55)
	# Sombra continua no piso durante o salto.
	draw_set_transform(Vector2(0, 590 - position.y), 0, Vector2(1, 0.22))
	draw_circle(Vector2.ZERO, 49, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO, 0, Vector2(visual_facing, 1))
	_limb(pelvis + Vector2(-12, 0), rear_foot, 56, 60, -1, main.darkened(0.38), 18)
	_limb(shoulder + Vector2(-4, 0), rear_hand, 33, 35, -1, main.darkened(0.36), 14)
	draw_line(pelvis, shoulder, Color("111c30"), 43, true)
	draw_line(pelvis, shoulder, main.darkened(0.22), 32, true)
	draw_line(pelvis + Vector2(7, -15), shoulder + Vector2(7, 8), main, 6, true)
	draw_circle(pelvis, 17, Color("1b2940"))
	draw_line(pelvis + Vector2(-18, -3), pelvis + Vector2(19, -3), main.lightened(0.2), 7, true)
	_limb(pelvis + Vector2(9, 0), front_foot, 56, 60, 1, main, 19)
	_limb(shoulder + Vector2(5, 0), front_hand, 36, 38, 1, main, 15)
	draw_circle(head, 21, Color("111c30"))
	draw_circle(head, 17, main.lightened(0.12))
	draw_line(head + Vector2(1, -3), head + Vector2(17, -3), Color("122237"), 7, true)
	draw_line(head + Vector2(5, -4), head + Vector2(16, -4), Color("dcfff6"), 2, true)
	draw_circle(front_hand, 11, main.lightened(0.15))
	if attack_extension > 0.7:
		var tip := front_hand if model.move_id == "jab" else front_foot
		draw_arc(tip - Vector2(22, 0), 32, -1.1, 1.1, 12, Color(main, 0.65), 4, true)
	draw_set_transform(Vector2.ZERO)
	if debug_boxes:
		for rect in model.hurtboxes():
			_debug_rect(rect, Color(0.2, 0.8, 1.0, 0.8))
		for rect in model.attack_boxes():
			_debug_rect(rect, Color(1.0, 0.25, 0.3, 0.95))

func _gait_foot(phase: float, side: float) -> Vector2:
	# Stance percorre para trás à velocidade da raiz; swing devolve o pé à frente.
	var q := fposmod(phase / TAU, 1.0)
	var local_x: float
	var lift := 0.0
	if q < 0.6:
		local_x = 45.0 - q / 0.6 * 90.0
	else:
		var t := (q - 0.6) / 0.4
		local_x = lerpf(-45.0, 45.0, smoothstep(0.0, 1.0, t))
		lift = sin(t * PI) * 24.0
	var travel_sign := float(signi(model.vx)) * model.facing
	return Vector2(local_x * travel_sign + side * 7, -4 - lift)

func _limb(root_point: Vector2, tip: Vector2, upper: float, lower: float, bend: int, tint: Color, width: float) -> void:
	var delta := tip - root_point
	var length := clampf(delta.length(), 0.01, upper + lower - 0.01)
	var along := (upper * upper - lower * lower + length * length) / (2 * length)
	var height := sqrt(maxf(0.0, upper * upper - along * along))
	var direction := delta.normalized()
	var joint := root_point + direction * along + direction.orthogonal() * height * bend
	for pair in [[root_point, joint], [joint, tip]]:
		draw_line(pair[0], pair[1], Color("101b2b"), width + 6, true)
		draw_line(pair[0], pair[1], tint, width, true)
	draw_circle(joint, width * 0.48, tint.lightened(0.12))
	draw_circle(tip, width * 0.5, tint)

func _debug_rect(rect: Rect2i, tint: Color) -> void:
	var visual := Rect2(Vector2(rect.position) / FighterModel.SCALE - position, Vector2(rect.size) / FighterModel.SCALE)
	draw_rect(visual, Color(tint, 0.12), true)
	draw_rect(visual, tint, false, 2)
