class_name ArenaCatalog
extends RefCounted
## Presentation metadata is deliberately outside snapshots / fighting rules.
const IDS := ["patio", "nit", "cobertura", "servidor"]
const STORY := ["patio", "nit", "cobertura", "servidor"]
const DATA := {
	"patio":
	{
		"name": "PÁTIO / PÔR DO SOL",
		"place": "O último sinal já tocou.",
		"kind": "leaves",
		"color": "ffbb66",
		"track": "Vento e pássaros"
	},
	"nit":
	{
		"name": "NIT / AFTER CLASS",
		"place": "A sala virou arena.",
		"kind": "dust",
		"color": "bfe9a0",
		"track": "Ambiente da sala"
	},
	"cobertura":
	{
		"name": "COBERTURA / NOITE",
		"place": "A cidade assiste à luta.",
		"kind": "night",
		"color": "88ccff",
		"track": "Vento da cobertura"
	},
	"servidor":
	{
		"name": "NÚCLEO / SERVIDOR CENTRAL",
		"place": "O coração do NIT está em jogo.",
		"kind": "server",
		"color": "59eaff",
		"track": "Ventilação do núcleo"
	}
}


static func get_arena(id: String) -> Dictionary:
	var key := id if IDS.has(id) else "patio"
	var result: Dictionary = DATA[key].duplicate()
	result.id = key
	result.image = (
		LegacyRoster.catalog.arena if key == "nit" else "res://assets/stages/v11/%s.webp" % key
	)
	result.ambience = "res://assets/audio/v11/%s-ambience.ogg" % key
	return result


static func opponent_arena(id: String) -> String:
	return (
		{
			"marcelo": "servidor",
			"marcos": "servidor",
			"gustavo": "nit",
			"rafael": "nit",
			"ruan": "cobertura",
			"joao": "cobertura"
		}
		. get(id, "patio")
	)
