class_name StoryLayout
extends RefCounted
## Shared foreground projection: people, collision art, powers and furniture.
const SCALE := 0.80
const ORIGIN := Vector2(128, 125)
const Z_BASE := -1000
const PROP_SIZES := {
	# A standing fighter is 300 units tall. Preserve each source image's
	# aspect ratio: chair back 57%, table top 45%, vending machine 103%.
	"table": Vector2(246, 136), "chair": Vector2(113, 172),
	"soda": Vector2(171, 310), "shelf": Vector2(191, 320),
	"tank": Vector2(129, 190), "cabinet": Vector2(192, 300),
	"medkit": Vector2(56, 42), "can": Vector2(19, 34)
}


static func prop_size(kind: String) -> Vector2:
	return PROP_SIZES.get(kind, Vector2(70, 120))


static func depth(lane: float) -> float:
	return lerpf(0.96, 1.04, clampf((lane - 535.0) / 120.0, 0.0, 1.0))


static func grip(kind: String) -> Vector2:
	var size := prop_size(kind)
	return Vector2(0, -size.y * (0.86 if kind == "table" else 0.68))
