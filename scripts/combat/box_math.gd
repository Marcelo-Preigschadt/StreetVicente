class_name BoxMath
extends RefCounted


## AABB inteiro. Nenhum Area2D/PhysicsServer participa da simulação reexecutável.
static func world_rect(local: Rect2i, x: int, y: int, facing: int) -> Rect2i:
	var left := local.position.x if facing == 1 else -local.end.x
	return Rect2i(
		x + left * FighterModel.SCALE,
		y + local.position.y * FighterModel.SCALE,
		local.size.x * FighterModel.SCALE,
		local.size.y * FighterModel.SCALE
	)


static func overlap(a: Rect2i, b: Rect2i) -> bool:
	return (
		a.position.x < b.end.x
		and a.end.x > b.position.x
		and a.position.y < b.end.y
		and a.end.y > b.position.y
	)


## Segment vs expanded AABB, fixed-point time of impact. Integer slab clipping
## avoids tunnelling and rejects diagonal near misses of a swept bounding box.
static func sweep(from: Vector2i, to: Vector2i, hurt: Rect2i, radius: int) -> Dictionary:
	var enter := 0
	var leave := 65536
	for axis in 2:
		var origin: int = from[axis]
		var velocity: int = to[axis] - origin
		var low: int = hurt.position[axis] - radius
		var high: int = hurt.end[axis] + radius
		if velocity == 0:
			if origin <= low or origin >= high:
				return {}
			continue
		var first := (low - origin) * 65536
		var last := (high - origin) * 65536
		if velocity < 0:
			var swap := first
			first = -last
			last = -swap
			velocity = -velocity
		enter = maxi(enter, -_floor_div(-first, velocity))
		leave = mini(leave, _floor_div(last, velocity))
		if enter > leave:
			return {}
	var delta := to - from
	@warning_ignore("integer_division")
	var point := from + Vector2i(delta.x * enter / 65536, delta.y * enter / 65536)
	return {"time": enter, "point": point}


static func _floor_div(numerator: int, denominator: int) -> int:
	@warning_ignore("integer_division")
	var value: int = numerator / denominator
	return value - 1 if numerator < 0 and numerator % denominator != 0 else value
