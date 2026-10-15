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
