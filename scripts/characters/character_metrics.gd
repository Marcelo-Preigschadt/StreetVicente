class_name CharacterMetrics
extends RefCounted


## Retira a redução 0,88 herdada do Adriano. Mesmo fator em desenho, corpo e poderes.
## Razão inteira mantém a geometria determinística; nenhuma textura é deformada.
static func factor(id: String) -> float:
	return 25.0 / 22.0 if id == "adriano" else 1.0


static func units(id: String, value: int) -> int:
	if id != "adriano":
		return value
	@warning_ignore("integer_division")
	return value * 25 / 22


static func rect(id: String, value: Rect2i) -> Rect2i:
	var left := units(id, value.position.x)
	var top := units(id, value.position.y)
	return Rect2i(left, top, units(id, value.end.x) - left, units(id, value.end.y) - top)
