extends SceneTree
var frames: Dictionary = {}


func _initialize() -> void:
	call_deferred("run")


func remember(f: FighterModel) -> void:
	var art := CharacterArt.frame(f)
	var frame: Dictionary = art.frame
	var key := StoryCarryArt.frame_key(art, f.character.id)
	frames[key] = {"image": art.sheet.image, "rect": frame.rect,
		"anchor": frame.anchor, "bottom": frame.bottom,
		"x": frame.get("x", 0), "y": frame.get("y", 0),
		"scale": float(frame.get("scale", art.sheet.scale)) * CharacterMetrics.factor(f.character.id),
		"width": float(f.character.legacy.get("visualWidth", 1.0))}


func run() -> void:
	LegacyRoster.load_catalog()
	for id in LegacyRoster.ids():
		var f := FighterModel.new(LegacyRoster.get_character(id), 0, 0)
		f.state = FighterState.Id.WALK
		for distance in range(0, 500, 2):
			f.walk_distance = distance * FighterModel.SCALE
			remember(f)
		f.state = FighterState.Id.ATTACK
		f.move_id = f.character.get_move("throw", 1).id
		for tick in f.current_move().total_ticks():
			f.move_tick = tick
			remember(f)
	var file := FileAccess.open("res://.tools/story-grip-sources.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(frames))
	print("Registered ", frames.size(), " approved carry/walk cels")
	quit()
