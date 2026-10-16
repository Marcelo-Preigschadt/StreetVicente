# gdlint: disable=max-returns
# Rejeita checkpoints incompletos antes de reconstruir qualquer entidade.
class_name PlayerProgress
extends RefCounted
## Preferências/progresso locais. Armazenamento indisponível nunca bloqueia a partida.
const FILE := "user://progress-v1.json"
const RECORD_KEY := "svf-arcade-record-v1"  # Mesmo origin do Pages: importa o recorde Canvas.
const STORY_KEY := "svf-godot-story-v1"
var file_path: String = FILE
var record: int = 0
var checkpoint: Dictionary = {}


func _init(path: String = FILE) -> void:
	file_path = path


func load_saved() -> void:
	if FileAccess.file_exists(file_path):
		var raw = JSON.parse_string(FileAccess.get_file_as_string(file_path))
		if raw is Dictionary and raw.get("schema", 0) == 1:
			record = _score(raw.get("record", 0))
			if raw.get("checkpoint", {}) is Dictionary:
				checkpoint = raw.get("checkpoint", {})
	if OS.has_feature("web"):
		var value = (
			JavaScriptBridge
			. eval(
				"(()=>{try{return localStorage.getItem('svf-arcade-record-v1')}catch(e){return null}})()",
				true
			)
		)
		if value != null:
			record = maxi(record, _score(value))
		value = JavaScriptBridge.eval(
			"(()=>{try{return localStorage.getItem('svf-godot-story-v1')}catch(e){return null}})()",
			true
		)
		if value is String:
			var parsed = JSON.parse_string(value)
			if parsed is Dictionary:
				checkpoint = parsed
	if not valid_checkpoint():
		checkpoint.clear()


static func _score(value: Variant) -> int:
	var number := str(value).to_float()
	return (
		int(number)
		if (
			is_finite(number)
			and floor(number) == number
			and number >= 0
			and number <= 9007199254740991.0
		)
		else 0
	)


func valid_checkpoint() -> bool:
	if (
		checkpoint.get("schema", 0) != 1
		or checkpoint.get("character", "") not in LegacyRoster.ids()
		or int(checkpoint.get("act", -1)) not in range(4)
	):
		return false
	var data: Variant = checkpoint.get("world", {})
	if not data is Dictionary:
		return false
	for key in [
		"tick",
		"act",
		"wave",
		"hero",
		"enemies",
		"props",
		"score",
		"completed",
		"defeated",
		"freeze",
		"powers",
		"next_id"
	]:
		if not data.has(key):
			return false
	if (
		not data.hero is Dictionary
		or not data.enemies is Array
		or not data.props is Array
		or not data.powers is Dictionary
	):
		return false
	if (
		int(data.act) != int(checkpoint.act)
		or int(data.wave) not in range(4)
		or data.enemies.size() > 32
		or data.props.size() > 64
	):
		return false
	if (
		data.hero.get("character", "") != checkpoint.character
		or int(data.hero.get("slot", -1)) != 0
	):
		return false
	var expected := (
		FighterModel.new(LegacyRoster.get_character(checkpoint.character), 0, 0).snapshot().keys()
	)
	for key in expected:
		if not data.hero.has(key):
			return false
	for enemy in data.enemies:
		if (
			not enemy is Dictionary
			or not enemy.get("fighter", {}) is Dictionary
			or enemy.get("kind", "") not in LegacyRoster.catalog.story.enemies
		):
			return false
		for key in expected:
			if not enemy.fighter.has(key):
				return false
	return data.powers.get("projectiles", []) is Array


func save() -> void:
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"schema": 1, "record": record, "checkpoint": checkpoint}))
		file.flush()
	if OS.has_feature("web"):
		# JSON string escaping prevents names/dialogues from becoming JavaScript code.
		JavaScriptBridge.eval(
			(
				(
					"(()=>{try{localStorage.setItem('svf-arcade-record-v1',%s);"
					+ "localStorage.setItem('svf-godot-story-v1',%s)}catch(e){}})()"
				)
				% [JSON.stringify(str(record)), JSON.stringify(JSON.stringify(checkpoint))]
			),
			true
		)


func capture_story(world: StorySimulation) -> void:
	if world.completed:
		checkpoint.clear()
	elif not world.defeated:
		checkpoint = {
			"schema": 1,
			"character": world.hero.character.id,
			"act": world.act_index,
			"world": world.snapshot()
		}
	save()
