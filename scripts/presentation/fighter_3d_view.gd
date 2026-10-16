class_name Fighter3DView
extends Node2D
## Isolated orthographic 3D viewport composited into the native 2D game.
## 512 px / 5.12 m = the same 100 px/m used by the visual pose evaluator.
const SIZE := 512
var viewport: SubViewport
var actor: MarceloModel3D
var sprite: Sprite2D
var model: FighterModel
var frozen: bool = false
var evaluated: Dictionary = {}
var previous_pose: Dictionary = {}
var pose_key: String = ""


func _init() -> void:
	viewport = SubViewport.new()
	viewport.name = "Fighter3DViewport"
	viewport.size = Vector2i(SIZE, SIZE)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_2X
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(viewport)
	actor = MarceloModel3D.new()
	viewport.add_child(actor)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 5.12
	camera.position = Vector3(0, 2.0, 8)
	camera.current = true
	viewport.add_child(camera)
	sprite = Sprite2D.new()
	sprite.texture = viewport.get_texture()
	sprite.position = Vector2(0, -200)
	add_child(sprite)


func present(value: FighterModel, enabled: bool) -> void:
	model = value
	visible = enabled
	viewport.render_target_update_mode = (
		SubViewport.UPDATE_ALWAYS
		if enabled and is_visible_in_tree()
		else SubViewport.UPDATE_DISABLED
	)
	if not enabled:
		return
	var fraction := 0.0 if frozen else Engine.get_physics_interpolation_fraction()
	var next_key := "%d:%s" % [model.state, model.move_id]
	if pose_key != next_key:
		previous_pose = evaluated.duplicate()
		pose_key = next_key
	evaluated = Fighter3DPose.sample(model, fraction)
	var blend_ticks := 2.0 if model.state == FighterState.Id.ATTACK else 6.0
	if model.state in [FighterState.Id.HITSTUN, FighterState.Id.KNOCKDOWN, FighterState.Id.KO]:
		blend_ticks = 0.0
	var progress := (
		float(model.move_tick if model.state == FighterState.Id.ATTACK else model.state_tick)
		+ fraction
	)
	if not previous_pose.is_empty() and progress < blend_ticks:
		var weight := smoothstep(0.0, blend_ticks, progress)
		for key in evaluated:
			if evaluated[key] is Vector3:
				evaluated[key] = Vector3(previous_pose[key]).lerp(evaluated[key], weight)
			elif evaluated[key] is float:
				evaluated[key] = lerpf(previous_pose[key], evaluated[key], weight)
	actor.apply_pose(
		evaluated, 0.85 if model.state == FighterState.Id.HITSTUN and model.state_tick < 8 else 0.0
	)
	# Mirroring the final orthographic projection preserves the identity treatment
	# on both sides, while all body motion and depth remain real 3D geometry.
	sprite.flip_h = model.facing < 0


func observation() -> Dictionary:
	var hand: Vector3 = evaluated.get("near_hand", Vector3.ZERO)
	var foot: Vector3 = evaluated.get("near_foot", Vector3.ZERO)
	return {
		"renderer": "skeleton3d",
		"bones": actor.skeleton.get_bone_count(),
		"surfaces": actor.surfaces,
		"vertices": actor.vertex_count,
		"face": MarceloModel3D.FACE_PATH,
		"viewport": [SIZE, SIZE],
		"near_hand": [hand.x, hand.y, hand.z],
		"near_foot": [foot.x, foot.y, foot.z]
	}
