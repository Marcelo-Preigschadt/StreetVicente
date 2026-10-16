# gdlint: disable=max-returns
# Estados exclusivos retornam a exposição determinística diretamente.
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
var body_rects: Array[Rect2i] = []
var legacy: Dictionary = {}
var moves: Dictionary = {}
var walk_by_pose: Dictionary = {}
var speed_units: int = 0
var back_speed_units: int = 0


func move_for(id_value: String) -> MoveData:
	if moves.has(id_value):
		return moves[id_value]
	for move in [jab, kick, sweep, air_kick]:
		if move != null and move.id == id_value:
			return move
	return null


func get_move(name: String, strength: int = 1) -> MoveData:
	return moves.get("%s:%d" % [name, strength])


func pose_frame(fighter: FighterModel) -> Dictionary:
	if legacy.is_empty():
		return {}
	if fighter.state == FighterState.Id.ATTACK:
		var frames: Array = fighter.current_move().legacy.frames
		return frames[clampi(fighter.move_tick, 0, frames.size() - 1)]
	if (
		fighter.state in [FighterState.Id.STEP_IN, FighterState.Id.STEP_BACK]
		and legacy.atlases.has("motion")
	):
		var index := (
			(8 if fighter.state == FighterState.Id.STEP_IN else 10)
			+ int(fighter.state_tick * 100 >= fighter.step_duration * 42)
		)
		if index >= legacy.atlases.motion.frames.size():
			index = int(fighter.state_tick * 8 / maxi(1, fighter.step_duration)) % 8
		return {"pose": ["motion", index], "hurt": legacy.animations.idle[0].hurt}
	var key := "idle"
	match fighter.state:
		FighterState.Id.WALK:
			key = "walk"
		FighterState.Id.PREJUMP, FighterState.Id.LANDING, FighterState.Id.CROUCH:
			key = "crouch"
		FighterState.Id.JUMP:
			key = "jump"
		FighterState.Id.BLOCK:
			key = "lowBlock" if fighter.input.has(CombatInput.DOWN) else "block"
		FighterState.Id.HITSTUN:
			key = "hit"
		FighterState.Id.KO:
			key = "ko"
		FighterState.Id.KNOCKDOWN:
			key = "knockdown"
		FighterState.Id.WAKEUP:
			key = "wake"
		FighterState.Id.DIZZY:
			key = "dizzy"
	var frames: Array = legacy.animations[key]
	if key == "hit":
		var phase := clampi(
			int((fighter.hit_duration - fighter.stun_ticks) * 4 / maxi(1, fighter.hit_duration)),
			0,
			3
		)
		if legacy.atlases.has("reaction"):
			var row := 3 if fighter.hit_crouched else 1 if fighter.hit_region == "head" else 2
			return {"pose": ["reaction", row * 4 + phase], "hurt": frames[0].hurt}
		return frames[mini(frames.size() - 1, phase * 8)]
	if key == "walk":
		var cycle := posmod(
			fighter.walk_distance, maxi(1, roundi(float(legacy.stride) * FighterModel.SCALE))
		)
		var index := int(float(cycle) / (float(legacy.stride) * FighterModel.SCALE) * 8.0) % 8
		if legacy.atlases.has("motion"):
			return {"pose": ["motion", index], "hurt": walk_by_pose.get(index, frames[0]).hurt}
	return frames[fighter.state_tick % frames.size()]
