class_name EffectCelV20
extends RefCounted
## Cached 2D cels with feathered outer gutters; original pixels remain intact.
static var meshes: Dictionary = {}


static func draw(c: CanvasItem, art: Dictionary, clip: String, index: int,
	at: Vector2, size: Vector2, facing: int = 1, tint: Color = Color.WHITE) -> void:
	var sequence: Array = art.clips[clip]
	var frame: Dictionary = art.frames[int(sequence[posmod(index, sequence.size())])]
	var image: String = frame.get("image", art.get("image", ""))
	var key := image + str(frame.rect) + str(frame.pivot)
	if not meshes.has(key):
		var texture := LegacyRoster.texture(image)
		var r: Array = frame.rect
		var pivot := Vector2(frame.pivot[0], frame.pivot[1])
		var atlas := Vector2(texture.get_width(), texture.get_height())
		var axis := PackedFloat32Array([0, .035, .08, .12, .88, .92, .965, 1])
		var alpha := PackedFloat32Array([0, .12, .65, 1, 1, .65, .12, 0])
		var vertices := PackedVector3Array()
		var colors := PackedColorArray()
		var uv := PackedVector2Array()
		var indices := PackedInt32Array()
		for y in axis.size():
			for x in axis.size():
				var p := Vector2(axis[x], axis[y])
				vertices.append(Vector3(p.x - pivot.x, p.y - pivot.y, 0))
				colors.append(Color(1, 1, 1, alpha[x] * alpha[y]))
				uv.append((Vector2(r[0], r[1]) + p * Vector2(r[2], r[3])) / atlas)
		for y in axis.size() - 1:
			for x in axis.size() - 1:
				var a := y * axis.size() + x
				var d := a + axis.size()
				indices.append_array(PackedInt32Array([a, a + 1, d, a + 1, d + 1, d]))
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_COLOR] = colors
		arrays[Mesh.ARRAY_TEX_UV] = uv
		arrays[Mesh.ARRAY_INDEX] = indices
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		meshes[key] = mesh
	c.draw_set_transform(at, 0, Vector2(facing * size.x, size.y))
	c.draw_mesh(meshes[key], LegacyRoster.texture(image), Transform2D.IDENTITY, tint)
	c.draw_set_transform(Vector2.ZERO)
