class_name CharacterData
extends Resource
## Identidade e moves são imutáveis durante uma partida; snapshots guardam IDs.
@export var id: String = "prototype"
@export var display_name: String = "Protótipo"
@export var color := Color("4fe5cd")
@export var max_health: int = 1000
@export var speed_pixels_per_tick: int = 3
@export var jab: MoveData
@export var kick: MoveData
@export var sweep: MoveData
@export var air_kick: MoveData

func move_for(id_value: String) -> MoveData:
	for move in [jab, kick, sweep, air_kick]:
		if move != null and move.id == id_value:
			return move
	return null
