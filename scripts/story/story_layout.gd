class_name StoryLayout
extends RefCounted
## Shared foreground projection: people, collision art, powers and furniture.
const SCALE := 0.80
const ORIGIN := Vector2(128, 125)
const Z_BASE := -1000
const MIN_LANE := 480
const MAX_LANE := 665
const GATES := [1440, 2160, 2880, 3560]
const PROP_SIZES := {
	# A standing fighter is 300 units tall. Preserve each source image's
	# aspect ratio: chair back 57%, table top 45%, vending machine 103%.
	"table": Vector2(246, 136), "chair": Vector2(113, 172),
	"soda": Vector2(171, 310), "shelf": Vector2(191, 320),
	"tank": Vector2(129, 190), "cabinet": Vector2(192, 300),
	"medkit": Vector2(56, 42), "can": Vector2(19, 34)
}


static func prop_size(kind: String) -> Vector2:
	var revised := StoryDirection.prop_size(kind)
	if revised != Vector2.ZERO:
		return revised
	return PROP_SIZES.get(kind, Vector2(70, 120))


static func gate(wave: int) -> int:
	return GATES[clampi(wave, 0, 3)]


static func camera_limit(wave: int) -> int:
	return maxi(0, gate(wave) - 1440)


static func floor_left(camera: float) -> float:
	return -camera * SCALE


static func zone(x: int, act: int = 0) -> String:
	if act == 1:
		return "QUÍMICA" if x < 1700 else "REAGENTES" if x < 3000 else "REATOR"
	if act == 2:
		return "BIBLIOTECA" if x < 1700 else "ARQUIVO" if x < 3000 else "ACERVO"
	if act >= 3:
		return "NIT" if x < 1700 else "REDE" if x < 3000 else "SERVIDOR"
	return "CORREDOR" if x < 1700 else "CANTINA" if x < 3000 else "BLOCO A"


static func depth(lane: float) -> float:
	return lerpf(0.96, 1.04, clampf((lane - MIN_LANE) / float(MAX_LANE - MIN_LANE), 0.0, 1.0))


static func grip(kind: String) -> Vector2:
	var size := prop_size(kind)
	return Vector2(0, -size.y * (0.86 if kind == "table" else 0.68))
