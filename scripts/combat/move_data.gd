class_name MoveData
extends Resource
## Frames de design a 60 Hz. Simulação converte exatamente para ticks de 120 Hz.
enum Level { MID, LOW, OVERHEAD }
@export var id: String = "jab"
@export var display_name: String = "Soco"
@export_range(1, 120) var startup: int = 4
@export_range(1, 120) var active: int = 3
@export_range(1, 240) var recovery: int = 9
@export var damage: int = 44
@export var hitstun: int = 17
@export var blockstun: int = 10
@export var hitstop: int = 3
@export var push_pixels: int = 18
@export var level: Level = Level.MID
@export var airborne: bool = false
@export var hitboxes: Array[HitboxData] = []

func total_ticks() -> int:
	return (startup + active + recovery) * 2

func phase(tick: int) -> String:
	if tick < startup * 2:
		return "STARTUP"
	if tick < (startup + active) * 2:
		return "ACTIVE"
	return "RECOVERY"

func validate() -> bool:
	if id.is_empty() or damage < 0 or hitstun < 1 or blockstun < 1 or hitstop < 0:
		return false
	for box in hitboxes:
		if box.first_frame < startup or box.end_frame > startup + active or box.end_frame <= box.first_frame:
			return false
	return not hitboxes.is_empty()
