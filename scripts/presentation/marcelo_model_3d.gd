class_name MarceloModel3D
extends Node3D
## Authored mesh surfaces, native Skeleton3D, no sprites or billboard body parts.
## The head is a curved/extruded relief using the unchanged approved portrait.
## This deliberate fixed-camera identity treatment is not a 360-degree head scan.
const FACE_PATH := "res://assets/legacy/runtime/marcelo-head-menu-v3.webp"
const TOON := preload("res://assets/shaders/fighter_toon.gdshader")
const INK := preload("res://assets/shaders/fighter_ink.gdshader")
var skeleton: Skeleton3D
var skin: Skin
var bones: Dictionary = {}
var materials: Array[ShaderMaterial] = []
var surfaces: int = 0
var vertex_count: int = 0
var bind_poses: Dictionary = {}


func _init() -> void:
	skeleton = Skeleton3D.new()
	skeleton.name = "MarceloRig"
	add_child(skeleton)
	skin = Skin.new()
	for entry in [
		["pelvis", ""],
		["chest", "pelvis"],
		["neck", "chest"],
		["head", "neck"],
		["near_upper", "chest"],
		["near_lower", "near_upper"],
		["near_hand", "near_lower"],
		["far_upper", "chest"],
		["far_lower", "far_upper"],
		["far_hand", "far_lower"],
		["near_thigh", "pelvis"],
		["near_shin", "near_thigh"],
		["near_foot", "near_shin"],
		["far_thigh", "pelvis"],
		["far_shin", "far_thigh"],
		["far_foot", "far_shin"],
		["tail_near", "pelvis"],
		["tail_far", "pelvis"]
	]:
		var index := skeleton.get_bone_count()
		skeleton.add_bone(entry[0])
		bones[entry[0]] = index
		if not str(entry[1]).is_empty():
			skeleton.set_bone_parent(index, bones[entry[1]])
		skeleton.set_bone_rest(index, Transform3D.IDENTITY)
		skin.add_bind(index, Transform3D.IDENTITY)
	# Conventional bind pose: vertices in skeleton space, inverse global binds,
	# and parent-relative bone rests. This also makes the rig editable/exportable.
	bind_poses = transforms(
		{
			"hip": Vector3(-0.10, 1.48, 0),
			"chest": Vector3(-0.04, 2.23, 0),
			"head": Vector3(0.04, 2.73, 0),
			"near_hand": Vector3(0.24, 2.24, 0.32),
			"far_hand": Vector3(0.83, 2.26, -0.08),
			"near_foot": Vector3(0.56, 0.11, 0.25),
			"far_foot": Vector3(-0.56, 0.11, -0.22),
			"twist": 0.0,
			"roll": 0.0,
			"tail": 0.0
		}
	)
	for key in bones:
		var index: int = bones[key]
		var rest: Transform3D = bind_poses[key]
		skin.set_bind_pose(index, rest.affine_inverse())
		var parent := skeleton.get_bone_parent(index)
		if parent >= 0:
			rest = bind_poses[skeleton.get_bone_name(parent)].affine_inverse() * rest
		skeleton.set_bone_rest(index, rest)
	build()


func material(color: String, identity: bool = false) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = TOON
	mat.set_shader_parameter("base_color", Color(color))
	mat.set_shader_parameter("use_identity", identity)
	if identity:
		mat.set_shader_parameter("identity_texture", load(FACE_PATH))
	var ink := ShaderMaterial.new()
	ink.shader = INK
	mat.next_pass = ink
	materials.append(mat)
	return mat


func build() -> void:
	var coat := material("262c33")
	var shirt := material("20252b")
	var pants := material("252b32")
	var leather := material("242a30")
	var seam := material("65717a")
	var flesh := material("be805c")
	var hair := material("251b17")
	coat.set_shader_parameter("cloth", true)
	pants.set_shader_parameter("cloth", true)
	# Tailored coat: broad shoulders, waist taper, open front and separate lapels.
	rings(
		"chest",
		[
			[0, -0.72, 0, 0.28, 0.20],
			[0, -0.55, 0, 0.29, 0.22],
			[0, -0.30, 0, 0.37, 0.24],
			[0, -0.07, 0, 0.47, 0.24],
			[0, 0.07, 0, 0.40, 0.21],
			[0, 0.16, 0, 0.21, 0.17]
		],
		coat
	)
	rings(
		"chest",
		[
			[0.06, -0.71, 0.23, 0.12, 0.025],
			[0.06, -0.20, 0.25, 0.22, 0.025],
			[0.06, 0.09, 0.21, 0.12, 0.025]
		],
		shirt
	)
	for sign_value in [-1, 1]:
		var s := float(sign_value)
		panel(
			"chest",
			[
				Vector3(s * 0.15, 0.13, 0.26),
				Vector3(s * 0.34, -0.02, 0.26),
				Vector3(s * 0.20, -0.42, 0.28),
				Vector3(s * 0.07, -0.28, 0.29)
			],
			coat
		)
		# Raised edge stitches/lapel seams catch the comic key light.
		line_mesh(
			"chest", Vector3(s * 0.17, 0.10, 0.275), Vector3(s * 0.11, -0.32, 0.30), 0.012, seam
		)
	rings("pelvis", [[0, -0.19, 0, 0.31, 0.21], [0, 0.04, 0, 0.31, 0.20]], pants)
	rings("pelvis", [[0, -0.01, 0, 0.32, 0.225], [0, 0.045, 0, 0.32, 0.225]], leather)
	rings("neck", [[0, -0.08, 0, 0.13, 0.13], [0, 0.16, 0, 0.13, 0.13]], flesh)
	for side in ["near", "far"]:
		rings(
			side + "_upper",
			[
				[0, -0.04, 0, 0.21, 0.19],
				[0, 0.16, 0, 0.215, 0.18],
				[0, 0.39, 0, 0.16, 0.15],
				[0, 0.61, 0, 0.14, 0.135]
			],
			coat
		)
		rings(
			side + "_lower",
			[[0, -0.05, 0, 0.15, 0.14], [0, 0.22, 0, 0.17, 0.14], [0, 0.43, 0, 0.125, 0.12]],
			coat
		)
		rings(
			side + "_lower",
			[[0, 0.40, 0, 0.12, 0.11], [0, 0.53, 0, 0.105, 0.09], [0, 0.63, 0, 0.085, 0.075]],
			flesh
		)
		rings(
			side + "_hand",
			[
				[0, -0.06, 0, 0.095, 0.085],
				[0, 0.06, 0.025, 0.115, 0.095],
				[0, 0.20, 0.015, 0.105, 0.08],
				[0, 0.24, 0, 0.075, 0.065]
			],
			flesh
		)
		# Four distinct knuckle/finger forms and thumb; no mitten sphere.
		for finger in 4:
			var x := (finger - 1.5) * 0.051
			rings(
				side + "_hand",
				[[x, 0.14, 0.075, 0.028, 0.027], [x, 0.23, 0.066, 0.026, 0.025]],
				flesh,
				8
			)
		rings(
			side + "_hand",
			[[-0.10, 0.04, 0.04, 0.04, 0.04], [-0.14, 0.12, 0.04, 0.035, 0.035]],
			flesh,
			8
		)
		rings(
			side + "_thigh",
			[
				[0, -0.08, 0, 0.225, 0.23],
				[0, 0.19, 0, 0.25, 0.22],
				[0, 0.46, 0, 0.205, 0.19],
				[0, 0.85, 0, 0.155, 0.15]
			],
			pants
		)
		rings(
			side + "_shin",
			[
				[0, -0.05, 0, 0.16, 0.15],
				[0, 0.23, 0, 0.175, 0.15],
				[0, 0.58, 0, 0.125, 0.13],
				[0, 0.78, 0, 0.12, 0.12]
			],
			pants
		)
		# Boots have a shaped toe, ankle shaft, outsole, tongue and laces.
		rings(
			side + "_foot",
			[
				[0.04, -0.065, 0, 0.24, 0.15],
				[0.04, 0.015, 0, 0.25, 0.15],
				[0.015, 0.09, 0, 0.21, 0.14],
				[-0.07, 0.22, 0, 0.13, 0.12]
			],
			leather
		)
		rings(side + "_foot", [[0.04, -0.08, 0, 0.25, 0.16], [0.04, -0.04, 0, 0.25, 0.16]], shirt)
		for i in 4:
			line_mesh(
				side + "_foot",
				Vector3(-0.08, 0.06 + i * 0.025, 0.143),
				Vector3(0.07, 0.075 + i * 0.025, 0.143),
				0.008,
				seam
			)
		var depth := 0.10 if side == "near" else -0.13
		rings(
			"tail_" + side,
			[
				[0.12, 0, depth, 0.20, 0.06],
				[0.15, 0.34, depth, 0.24, 0.075],
				[0.24, 0.68, depth, 0.32, 0.08],
				[0.34, 0.99, depth, 0.35, 0.07]
			],
			coat
		)
	# Cranial volume behind the face relief; the head remains genuine mesh geometry.
	rings(
		"head",
		[
			[-0.07, -0.20, -0.05, 0.14, 0.15],
			[-0.06, -0.04, -0.05, 0.24, 0.19],
			[-0.05, 0.15, -0.05, 0.23, 0.18],
			[-0.04, 0.25, -0.04, 0.15, 0.13]
		],
		hair,
		24
	)
	face(material("ffffff", true))


func rings(bone: String, profile: Array, mat: ShaderMaterial, segments: int = 16) -> void:
	var vertices := PackedVector3Array()
	var uv := PackedVector2Array()
	var indices := PackedInt32Array()
	for row in profile:
		for i in segments:
			var angle := TAU * i / segments
			vertices.append(
				Vector3(row[0] + cos(angle) * row[3], row[1], row[2] + sin(angle) * row[4])
			)
			uv.append(
				Vector2(float(i) / segments, float(vertices.size() / segments) / profile.size())
			)
	for row in range(profile.size() - 1):
		for i in segments:
			var a := row * segments + i
			var b := row * segments + (i + 1) % segments
			indices.append_array(
				PackedInt32Array([a, b, a + segments, b, b + segments, a + segments])
			)
	# Close caps; clockwise Godot front faces.
	for i in range(1, segments - 1):
		indices.append_array(PackedInt32Array([0, i + 1, i]))
		var end := (profile.size() - 1) * segments
		indices.append_array(PackedInt32Array([end, end + i, end + i + 1]))
	surface(bone, vertices, uv, indices, mat)


func panel(bone: String, points: Array, mat: ShaderMaterial) -> void:
	var vertices := PackedVector3Array(points)
	var uv := PackedVector2Array([Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN])
	surface(bone, vertices, uv, PackedInt32Array([0, 2, 1, 0, 3, 2]), mat)


func line_mesh(bone: String, a: Vector3, b: Vector3, width: float, mat: ShaderMaterial) -> void:
	var offset := Vector3(width, 0, 0)
	panel(bone, [a - offset, a + offset, b + offset, b - offset], mat)


func face(mat: ShaderMaterial) -> void:
	# UVs are original portrait coordinates, not a newly painted/generated face.
	var contour := PackedVector2Array(
		[
			Vector2(55, 70),
			Vector2(79, 43),
			Vector2(118, 24),
			Vector2(165, 20),
			Vector2(214, 26),
			Vector2(243, 44),
			Vector2(256, 68),
			Vector2(251, 94),
			Vector2(246, 117),
			Vector2(248, 142),
			Vector2(266, 162),
			Vector2(263, 174),
			Vector2(249, 180),
			Vector2(258, 203),
			Vector2(247, 225),
			Vector2(224, 246),
			Vector2(184, 256),
			Vector2(140, 247),
			Vector2(109, 227),
			Vector2(91, 198),
			Vector2(70, 174),
			Vector2(55, 142),
			Vector2(46, 110)
		]
	)
	var vertices := PackedVector3Array()
	var uv := PackedVector2Array()
	var indices := PackedInt32Array()
	var center := Vector2(153, 139)
	for ring in 7:
		var radius := (ring + 0.005) / 6.005
		for point in contour:
			var pixel := center.lerp(point, radius)
			var depth := 0.07 + 0.18 * sqrt(maxf(0, 1 - radius * radius))
			vertices.append(Vector3((pixel.x - 153) * 0.0022, (139 - pixel.y) * 0.0022, depth))
			uv.append(pixel / 320.0)
	for ring in 6:
		for i in contour.size():
			var a := ring * contour.size() + i
			var b := ring * contour.size() + (i + 1) % contour.size()
			indices.append_array(
				PackedInt32Array(
					[a, a + contour.size(), b, b, a + contour.size(), b + contour.size()]
				)
			)
	surface("head", vertices, uv, indices, mat)


func surface(
	bone: String,
	vertices: PackedVector3Array,
	uv: PackedVector2Array,
	indices: PackedInt32Array,
	mat: ShaderMaterial
) -> void:
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in vertices.size():
		builder.set_smooth_group(0)
		builder.set_uv(uv[i])
		builder.set_bones(PackedInt32Array([bones[bone], 0, 0, 0]))
		builder.set_weights(PackedFloat32Array([1, 0, 0, 0]))
		builder.add_vertex(bind_poses[bone] * vertices[i])
	for index in indices:
		builder.add_index(index)
	builder.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.name = bone + "_surface_%d" % surfaces
	mesh.mesh = builder.commit()
	mesh.material_override = mat
	mesh.skin = skin
	mesh.skeleton = NodePath("..")
	mesh.custom_aabb = AABB(Vector3(-4, -2, -2), Vector3(8, 8, 4))
	skeleton.add_child(mesh)
	surfaces += 1
	vertex_count += vertices.size()


func transforms(p: Dictionary) -> Dictionary:
	var goals: Dictionary = {}
	goals.pelvis = Transform3D(Basis(Vector3.UP, -0.20), p.hip)
	goals.chest = Transform3D(Basis(Vector3.UP, p.twist - 0.35), p.chest)
	goals.neck = Transform3D(Basis.IDENTITY, p.head + Vector3(0, -0.27, 0))
	goals.head = Transform3D(
		Basis(Vector3.FORWARD, clampf((p.head.x - p.chest.x) * 0.18, -0.08, 0.08)), p.head
	)
	for side in ["far", "near"]:
		var depth := 0.23 if side == "near" else -0.23
		var shoulder: Vector3 = p.chest + Vector3(-0.14 if side == "near" else 0.12, 0, depth)
		var hand: Vector3 = p[side + "_hand"]
		var elbow := Fighter3DPose.joint(shoulder, hand, 0.61, 0.63, Vector3(-0.1, -1, depth))
		goals[side + "_upper"] = segment(shoulder, elbow)
		goals[side + "_lower"] = segment(elbow, hand, 0.63)
		goals[side + "_hand"] = segment(hand, hand + (hand - elbow).normalized() * 0.2)
		var hip: Vector3 = p.hip + Vector3(-0.10 if side == "far" else 0.08, 0, depth)
		var ankle: Vector3 = p[side + "_foot"]
		var knee := Fighter3DPose.joint(hip, ankle, 0.85, 0.78, Vector3(1, 0, depth * 0.5))
		goals[side + "_thigh"] = segment(hip, knee)
		goals[side + "_shin"] = segment(knee, ankle, 0.78)
		var kick_angle := -0.25 if ankle.y > 0.9 else 0.0
		goals[side + "_foot"] = Transform3D(Basis(Vector3.FORWARD, kick_angle), ankle)
		goals["tail_" + side] = Transform3D(
			Basis(Vector3.FORWARD, PI + float(p.tail)), p.hip + Vector3(-0.12, -0.03, depth)
		)
	var roll := Basis(Vector3.FORWARD, p.roll)
	var pivot: Vector3 = p.hip
	for key in bones:
		var global_pose: Transform3D = goals[key]
		if absf(p.roll) > 0.001:
			global_pose = Transform3D(
				roll * global_pose.basis, pivot + roll * (global_pose.origin - pivot)
			)
		goals[key] = global_pose
	return goals


func apply_pose(p: Dictionary, flash: float = 0.0) -> void:
	var goals := transforms(p)
	for key in bones:
		var index: int = bones[key]
		var parent := skeleton.get_bone_parent(index)
		var relative: Transform3D = goals[key]
		if parent >= 0:
			relative = goals[skeleton.get_bone_name(parent)].affine_inverse() * relative
		skeleton.set_bone_pose_position(index, relative.origin)
		skeleton.set_bone_pose_rotation(
			index, relative.basis.orthonormalized().get_rotation_quaternion()
		)
		skeleton.set_bone_pose_scale(index, relative.basis.get_scale())
	for mat in materials:
		mat.set_shader_parameter("hit_flash", flash)


static func segment(a: Vector3, b: Vector3, rest_length: float = -1.0) -> Transform3D:
	var y := (b - a).normalized()
	var z := Vector3.FORWARD.cross(y).cross(y).normalized()
	if z.length_squared() < 0.01:
		z = Vector3.RIGHT
	var x := y.cross(z).normalized()
	z = x.cross(y).normalized()
	var length_scale := (b - a).length() / rest_length if rest_length > 0 else 1.0
	return Transform3D(Basis(x, y * length_scale, z), a)
