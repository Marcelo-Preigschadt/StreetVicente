class_name StoryCarryArt
extends RefCounted
static var grips: Dictionary = {}
## Approved complete-body cels, with the prop grip registered to the visible hand.
static func sample(model: FighterModel, gear: StoryObjects, lifting := true) -> Dictionary:
	if gear == null or gear.carry.is_empty():
		return CharacterArt.frame(model)
	if model.state in [FighterState.Id.WALK, FighterState.Id.ATTACK, FighterState.Id.HITSTUN]:
		return CharacterArt.frame(model)
	var proxy := FighterModel.new(model.character, model.slot, 0)
	proxy.restore(model.snapshot())
	if lifting and gear.pickup_ticks > 24:
		proxy.state = FighterState.Id.CROUCH
	else:
		proxy.state = FighterState.Id.ATTACK
		proxy.move_id = model.character.get_move("throw", 1).id
		proxy.move_tick = proxy.current_move().startup * 2
	return CharacterArt.frame(proxy)


static func hand(art: Dictionary, id: String) -> Vector2:
	var collision: Dictionary = art.frame.get("collision", {})
	if collision.has("hand"):
		return Vector2(collision.hand[0], collision.hand[1]) * CharacterMetrics.factor(id)
	if grips.is_empty():
		grips = JSON.parse_string(FileAccess.get_file_as_string("res://data/story/hand-grips-v23.json"))
	var key := frame_key(art, id)
	if grips.has(key):
		return Vector2(grips[key][0], grips[key][1])
	var point := Vector2(55, -165)
	for raw in collision.get("hurt", []):
		if raw[1] > -230 and raw[1] < -110 and raw[0] + raw[2] > point.x:
			point = Vector2(raw[0] + raw[2] - 5, raw[1] + raw[3] / 2)
	return point * CharacterMetrics.factor(id)


static func frame_key(art: Dictionary, id: String) -> String:
	var r: Array = art.frame.rect
	return "%s|%s|%d,%d,%d,%d" % [id, str(art.sheet.image), r[0], r[1], r[2], r[3]]


static func held_bottom(model: FighterModel, gear: StoryObjects) -> Vector2:
	var point := hand(sample(model, gear, false), model.character.id)
	point.x *= model.facing
	return point - StoryLayout.grip(str(gear.carry.kind))
