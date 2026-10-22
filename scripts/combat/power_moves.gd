class_name PowerMoves
extends RefCounted
## Authored power reach. All geometry is fixed-point; presentation reads the same profile.
const UPPER := {
	"adriano": [74, 310, 160],
	"marcelo": [84, 350, 170],
	"rafael": [88, 365, 165],
	"gustavo": [78, 330, 165],
	"gelton": [92, 380, 175],
	"marcelino": [90, 365, 170],
	"marcos": [72, 310, 155],
	"joao": [70, 540, 160],
	"tais": [96, 400, 180],
	"luciana": [82, 345, 165],
	"khauany": [92, 390, 175],
	"dienes": [80, 335, 165],
	"ruan": [86, 360, 170]
}


static func configure(c: CharacterData) -> void:
	if c.id in ["marcelo", "adriano", "rafael", "gustavo", "gelton", "marcelino"]:
		# Broad dense projectile fronts match their swept contacts; decorative
		# trails and impact coronas do not create invisible hitboxes.
		for strength in 3:
			for key in ["special", "super"]:
				var revised: MoveData = c.moves["%s:%d" % [key, strength]]
				if not revised.legacy.get("projectile", false) or (c.id == "marcelo" and key == "super"):
					continue
				revised.legacy = revised.legacy.duplicate(true)
				revised.legacy.radius = (128 if key == "super" else 56) if c.id == "adriano" else (146 if key == "super" else 64)
		return
	if c.id == "ruan":
		# Blue-violet plasma nuclei use matching swept physical contacts.
		# Original damage, speed, three waves, cost and voices are preserved.
		for strength in 3:
			for key in ["special", "super"]:
				var storm: MoveData = c.moves["%s:%d" % [key, strength]]
				storm.legacy = storm.legacy.duplicate(true)
				storm.legacy.radius = 152 if key == "super" else 68
		return
	if c.id == "luciana":
		# Broad visible language nuclei use matching swept physical contacts.
		# Original damage, speed, three waves, cost and voices are preserved.
		for strength in 3:
			for key in ["special", "super"]:
				var word: MoveData = c.moves["%s:%d" % [key, strength]]
				word.legacy = word.legacy.duplicate(true)
				word.legacy.radius = 150 if key == "super" else 64
		return
	if c.id == "tais":
		# Visible pressure nuclei have matching swept collision radii. Costs,
		# damage, speed, four-wave cadence and voices retain the original rules.
		for strength in 3:
			for key in ["special", "super"]:
				var pulse: MoveData = c.moves["%s:%d" % [key, strength]]
				pulse.legacy = pulse.legacy.duplicate(true)
				pulse.legacy.radius = 146 if key == "super" else 58
		return
	if c.id != "joao":
		return
	c.legacy = c.legacy.duplicate()
	c.legacy.powers = c.legacy.powers.duplicate()
	c.legacy.voices = c.legacy.voices.duplicate()
	var roll_voice: String = c.legacy.voices.uppercut
	c.legacy.voices.uppercut = c.legacy.voices.super
	c.legacy.voices.super = roll_voice
	c.legacy.powers.uppercut = "Curto-Circuito 301"
	c.legacy.powers.super = "Rolamento Selvagem"
	for strength in 3:
		c.moves["uppercut:%d" % strength].display_name = "Curto-Circuito 301"
		var move: MoveData = c.moves["super:%d" % strength]
		move.legacy = move.legacy.duplicate(true)
		move.active = 90
		move.recovery = 30
		move.legacy.active = move.active
		move.legacy.recovery = move.recovery
		move.legacy.body_roll = true
		move.legacy.effect = "electricRoll"
		move.display_name = "Rolamento Selvagem"
		# Legacy comparison remains index-safe; the normal presenter uses new cels.
		var original: Array = move.legacy.frames.duplicate(true)
		move.legacy.frames = []
		for tick in move.total_ticks():
			move.legacy.frames.append(original[mini(tick, original.size() - 1)])


static func upper_profile(id: String) -> Array:
	return UPPER.get(id, [0, 135, 0])


static func upper_boxes(f: FighterModel) -> Array[Rect2i]:
	var result: Array[Rect2i] = []
	if f.current_move().phase(f.move_tick) != "ACTIVE" or not UPPER.has(f.character.id):
		return result
	var k := float(upper_profile(f.character.id)[2]) / 170.0
	# Interior bands of the visible crescent, rather than an invisible long AABB.
	for b in [
		Rect2i(82, -302, 35, 32),
		Rect2i(112, -268, 32, 46),
		Rect2i(116, -221, 42, 55),
		Rect2i(94, -165, 38, 47),
		Rect2i(62, -117, 25, 31)
	]:
		var band := Rect2i(
			roundi(b.position.x * k), b.position.y, maxi(1, roundi(b.size.x * k)), b.size.y
		)
		result.append(
			BoxMath.world_rect(CharacterMetrics.rect(f.character.id, band), f.x, f.y, f.facing)
		)
	return result
