class_name StoryScenery
extends RefCounted
## Authored room groups. Decorations share the world projection but never
## enter combat snapshots; physical furniture is spawned with stable keys.
static var art: Dictionary = {}
const INTERACTIVE := [
	[["bench", 570, 490, 180], ["bin", 1030, 480, 90],
	 ["locker", 1610, 480, 220], ["foodcart", 1910, 480, 150],
	 ["planter", 2210, 480, 100], ["chairstack", 2440, 480, 100],
	 ["bin", 3180, 480, 90]],
	[["cabinet", 440, 480, 220], ["reagentcrate", 780, 490, 100],
	 ["labcart", 1170, 480, 120], ["tank", 1510, 480, 180],
	 ["labbench", 1930, 480, 200], ["instrument", 2310, 480, 100],
	 ["labcart", 2820, 480, 130], ["reagentcrate", 3160, 485, 100],
	 ["washstation", 3480, 480, 180]],
	[["bookcart", 460, 480, 120], ["archivebox", 1180, 480, 80],
	 ["readingdesk", 1450, 480, 180], ["bookcart", 2140, 480, 120],
	 ["archivebox", 2400, 485, 80], ["lectern", 3140, 480, 140],
	 ["globe", 3440, 480, 90]],
	[["serverrack", 420, 480, 240], ["partscrate", 780, 490, 100],
	 ["toolcart", 1150, 480, 140], ["ups", 1470, 480, 160],
	 ["workbench", 1910, 480, 220], ["networkcabinet", 2260, 480, 180],
	 ["partscrate", 2580, 490, 100], ["toolcart", 2880, 480, 140],
	 ["serverrack", 3210, 480, 240], ["ups", 3480, 480, 160]]
]
# kind, x, floor lane (or wall anchor), scale, casts floor shadow.
const DECORATIONS := [
	[["locker", 40, 428, .92, true], ["chairstack", 380, 430, .9, true],
	 ["planter", 790, 430, .78, true], ["trophycase", 1280, 430, .88, true],
	 ["barrier", 1780, 430, .82, true],
	 ["foodcart", 2120, 430, .88, true], ["bin", 2390, 430, .78, true],
	 ["chairstack", 2590, 435, .84, true], ["planter", 3030, 430, .78, true],
	 ["locker", 3660, 430, .92, true],
	 ["planter", -35, 765, .7, true], ["bin", 1580, 795, .72, true],
	 ["planter", 2740, 765, .7, true], ["barrier", 3700, 770, .72, true]],
	[["cabinet", 60, 430, .92, true], ["vent", 430, 260, .8, false],
	 ["washstation", 650, 430, .95, true], ["caution", 1030, 430, .85, true],
	 ["instrument", 1340, 430, .85, true], ["tank", 1760, 430, .95, true],
	 ["vent", 2080, 270, .85, false], ["cabinet", 2490, 430, .9, true],
	 ["caution", 2680, 430, .82, true], ["instrument", 3080, 430, .85, true],
	 ["tank", 3700, 430, .95, true], ["reagentcrate", -25, 715, .8, true],
	 ["reagentcrate", 1600, 730, .75, true], ["caution", 2760, 750, .7, true]],
	[["shelf", 30, 430, .92, true], ["bust", 350, 430, .9, true],
	 ["armillary", 610, 430, .9, true], ["globe", 1080, 430, .9, true],
	 ["lectern", 1400, 430, .9, true], ["bust", 1920, 430, .9, true],
	 ["shelf", 2320, 430, .92, true], ["armillary", 2630, 430, .9, true],
	 ["globe", 3040, 430, .9, true], ["shelf", 3670, 430, .92, true],
	 ["bookstack", -10, 708, .95, true], ["archivebox", 990, 735, .9, true],
	 ["bookstack", 2190, 710, .95, true], ["archivebox", 3660, 735, .9, true]],
	[["serverrack", 10, 430, .92, true], ["wallmonitor", 400, 320, .85, false],
	 ["coolingfan", 660, 430, .95, true], ["networkcabinet", 1040, 430, .92, true],
	 ["wallmonitor", 1390, 310, .9, false], ["serverrack", 1720, 430, .92, true],
	 ["coolingfan", 2180, 430, .95, true], ["wallmonitor", 2520, 315, .9, false],
	 ["networkcabinet", 2860, 430, .92, true], ["serverrack", 3660, 430, .92, true],
	 ["cablespool", -20, 730, .85, true], ["partscrate", 990, 730, .85, true],
	 ["cablespool", 2180, 730, .85, true], ["partscrate", 3670, 730, .85, true]]
]


static func load_data() -> void:
	if art.is_empty():
		art = JSON.parse_string(FileAccess.get_file_as_string("res://data/story/scenery-v28.json"))


static func apply(story: Dictionary) -> void:
	load_data()
	for kind in art.props:
		var item: Dictionary = art.props[kind]
		story.props[kind] = {"file": item.file, "width": item.size[0], "height": item.size[1]}


static func size(kind: String) -> Vector2:
	load_data()
	if not art.props.has(kind):
		return Vector2.ZERO
	var dimensions: Array = art.props[kind].size
	return Vector2(dimensions[0], dimensions[1])


static func populate(world: StorySimulation) -> void:
	for index in INTERACTIVE[world.act_index].size():
		var key := "v28:%d:%d" % [world.act_index, index]
		if world.props.any(func(p: Dictionary): return p.get("scene_key", "") == key):
			continue
		var item: Array = INTERACTIVE[world.act_index][index]
		world.objects._add_prop(str(item[0]), int(item[1]), int(item[2]), int(item[3]))
		world.props[-1].scene_key = key


static func decorations(act: int) -> Array:
	act = clampi(act, 0, DECORATIONS.size() - 1)
	var result: Array = []
	for index in DECORATIONS[act].size():
		var item: Array = DECORATIONS[act][index]
		result.append({"id": index, "kind": item[0], "x": int(item[1]) * FighterModel.SCALE,
			"lane": int(item[2]) * FighterModel.SCALE, "scale": float(item[3]),
			"shadow": bool(item[4]), "hp": 1, "used": false})
	return result
