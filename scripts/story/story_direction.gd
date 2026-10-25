class_name StoryDirection
extends RefCounted
## Shared campaign art/profile definitions. Approved player art is untouched.
static var art: Dictionary = {}
const PROFILES := {
	"snack": {"name": "Drone de vigilância", "atlas": "drone", "h": 105, "w": 150, "fly": 140},
	"cleaner": {"name": "Guarda da cantina", "atlas": "guard", "h": 270, "w": 140, "range": 155, "palette": "559b85"},
	"turnstile": {"name": "Sentinela de acesso", "atlas": "guard", "h": 282, "w": 150, "range": 165, "palette": "d69a52"},
	"lab": {"atlas": "guard", "h": 275, "palette": "659ac5"},
	"vial": {"name": "Androide de reagentes", "atlas": "guard", "h": 250, "w": 135, "palette": "ac799d"},
	"scanner": {"atlas": "guard", "h": 265, "palette": "9a7dba"},
	"book": {"name": "Drone de arquivo", "atlas": "drone", "h": 105, "fly": 155},
	"archaeologist": {"atlas": "drone", "h": 120, "fly": 165},
	"projector": {"name": "Drone projetor", "atlas": "drone", "h": 120, "fly": 145},
	"elite": {"atlas": "guard", "h": 285, "palette": "5a9eaf"},
	"kungfu": {"atlas": "guard", "h": 280, "palette": "b87564"},
	"inspector": {"atlas": "heavy", "h": 315, "w": 195},
	"fairRobot": {"atlas": "heavy", "h": 340, "w": 220},
	"substitute": {"atlas": "heavy", "h": 305, "w": 185},
	"aula": {"atlas": "heavy", "h": 305, "w": 190},
	"exo": {"atlas": "heavy", "h": 355, "w": 235}
}


static func load_data() -> void:
	if art.is_empty():
		art = JSON.parse_string(FileAccess.get_file_as_string("res://data/story/art-v27.json"))


static func apply(story: Dictionary) -> void:
	load_data()
	for kind in PROFILES:
		story.enemies[kind].merge(PROFILES[kind], true)
	for kind in art.props:
		story.props[kind].file = art.props[kind].file


static func atlas(kind: String) -> Dictionary:
	load_data()
	var result: Dictionary = art.atlases[PROFILES[kind].atlas].duplicate()
	result.scale = float(PROFILES[kind].h) / float(result.referenceHeight)
	return result


static func prop_size(kind: String) -> Vector2:
	load_data()
	if not art.props.has(kind):
		return Vector2.ZERO
	var size: Array = art.props[kind].size
	return Vector2(size[0], size[1])
