class_name GameAudio
extends Node
var enabled: bool = true
var streams: Dictionary = {}
var selection: AudioStreamPlayer
var voice: AudioStreamPlayer
var effects: Array[AudioStreamPlayer] = []


func _ready() -> void:
	selection = AudioStreamPlayer.new()
	voice = AudioStreamPlayer.new()
	add_child(selection)
	add_child(voice)
	for i in 5:
		var p := AudioStreamPlayer.new()
		p.volume_db = -9
		add_child(p)
		effects.append(p)


func play(file: String, channel: String = "effect") -> void:
	if not enabled or file.is_empty():
		return
	var p: AudioStreamPlayer = (
		selection if channel == "selection" else voice if channel == "voice" else effects[0]
	)
	if channel == "effect":
		for candidate in effects:
			if not candidate.playing:
				p = candidate
				break
	p.stop()
	if not streams.has(file):
		streams[file] = load(file)
	p.stream = streams[file]
	p.play()


func select_character(id: String) -> void:
	var c := LegacyRoster.get_character(id)
	play(c.legacy.voices.get("select", ""), "selection")


func consume(events: Array) -> void:
	for e in events:
		if e.kind == "announcer":
			var cue := str(e.cue)
			play(
				LegacyRoster.catalog.sounds.get(cue if cue == "ko" else "announcer-" + cue, ""),
				"effect" if cue == "ko" else "voice"
			)
		elif e.kind == "voice":
			var c := LegacyRoster.get_character(e.character)
			if e.move in ["special", "uppercut", "super", "drone"]:
				play(c.legacy.voices.get(e.move, ""), "voice")
		elif e.kind in ["hit", "block"]:
			var kind := (
				"block"
				if e.kind == "block"
				else (
					"power"
					if e.get("power_kind", "") != ""
					else (
						"heavy"
						if (
							"kick" in str(e.get("move", "")).to_lower()
							or str(e.get("move", "")).ends_with(":2")
						)
						else "light"
					)
				)
			)
			play("res://assets/audio/v11/impact-%s.ogg" % kind)
		elif e.kind == "laser":
			play(LegacyRoster.catalog.sounds.get("special", ""))
