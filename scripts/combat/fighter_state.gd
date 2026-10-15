class_name FighterState
extends RefCounted
## FSM só contém estados de gameplay; não depende de AnimationTree/SceneTree.
enum Id { IDLE, WALK, CROUCH, JUMP, ATTACK, HITSTUN, BLOCK, KO }
const NAMES := ["IDLE", "WALK", "CROUCH", "JUMP", "ATTACK", "HITSTUN", "BLOCK", "KO"]

static func actionable(state: Id) -> bool:
	return state in [Id.IDLE, Id.WALK, Id.CROUCH, Id.JUMP]

static func can_turn(state: Id, grounded: bool) -> bool:
	return grounded and state in [Id.IDLE, Id.WALK, Id.CROUCH, Id.BLOCK]
