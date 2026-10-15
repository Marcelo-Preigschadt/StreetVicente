class_name HitboxData
extends Resource
## Retângulo em pixels, relativo à raiz nos pés, olhando à direita.
## Janela de frames 60 Hz, zero-based, [first_frame, end_frame).
@export var rect := Rect2i(20, -150, 100, 40)
@export_range(0, 240) var first_frame: int = 4
@export_range(1, 240) var end_frame: int = 7


func active(tick: int) -> bool:
	return tick >= first_frame * 2 and tick < end_frame * 2
