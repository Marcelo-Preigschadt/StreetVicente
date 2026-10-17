class_name LegacyRoster
extends RefCounted
## Imported data are immutable during a session; images/audio keep their approved pixels.
static var catalog: Dictionary = {}
static var characters: Dictionary = {}
static var textures: Dictionary = {}


static func load_catalog() -> void:
	if not catalog.is_empty():
		return
	catalog = JSON.parse_string(FileAccess.get_file_as_string("res://data/legacy/catalog.json"))
	for raw in catalog.roster:
		var c := CharacterData.new()
		c.id = raw.id
		c.display_name = raw.name
		c.color = Color(raw.color)
		c.legacy = raw
		for frame in raw.animations.walk:
			if frame.pose[0] == "motion":
				c.walk_by_pose[int(frame.pose[1])] = frame
		c.speed_units = roundi(float(raw.speed) * FighterModel.SCALE / 120.0)
		c.back_speed_units = roundi(float(raw.backSpeed) * FighterModel.SCALE / 120.0)
		for key in raw.moves:
			var d: Dictionary = raw.moves[key]
			var move := MoveData.new()
			move.id = key
			move.display_name = d.display_name
			move.startup = int(d.startup)
			move.active = int(d.active)
			move.recovery = int(d.recovery)
			move.damage = roundi(float(d.damage) * float(raw.power))
			move.hitstun = int(d.hitstun)
			move.blockstun = int(d.blockstun)
			move.level = (
				MoveData.Level.LOW
				if d.level == "low"
				else (MoveData.Level.OVERHEAD if d.level == "overhead" else MoveData.Level.MID)
			)
			move.legacy = d
			move.airborne = str(d.name).begins_with("air")

			move.hitstop = 5 if d.name in ["super", "uppercut"] else 3
			move.push_pixels = roundi(float(d.get("push", 160)) / 15.0)
			c.moves[key] = move
		PowerMoves.configure(c)
		c.jab = c.moves["punch:1"]
		c.kick = c.moves["kick:1"]
		c.sweep = c.moves["sweep:1"]
		c.air_kick = c.moves["airKick:1"]
		characters[c.id] = c


static func get_character(id: String) -> CharacterData:
	load_catalog()
	return characters.get(id, characters["marcelo"])


static func ids() -> Array:
	load_catalog()
	var result: Array = []
	for c in catalog.roster:
		if c.category == "teachers":
			result.append(c.id)
	for c in catalog.roster:
		if c.category == "students":
			result.append(c.id)
	return result


static func texture(file: String) -> Texture2D:
	if not textures.has(file):
		textures[file] = load(file)
	return textures[file]
