class_name StageAudio
extends Node
## Two bounded decks. Music comes only from a file explicitly chosen by the player.
## No audio upload, external request, purchase or generated soundtrack is involved.
var players: Array[AudioStreamPlayer] = []
var ambiences: Array[AudioStreamPlayer] = []
var tracks: Dictionary = {}
var active := 0
var stage_id := ""
var enabled := true
var level := 0.65
var elapsed := 1.0
var voice_duck := 0.0
var poll_clock := 0.0
var file_status := "MP3 / OGG • arquivo local"
var file_dialog: FileDialog
var pending_arena := ""
var game: Node
const FADE := 0.8
const MAX_BYTES := 12 * 1024 * 1024


func _ready() -> void:
	for i in 2:
		var p := AudioStreamPlayer.new()
		var a := AudioStreamPlayer.new()
		add_child(p)
		add_child(a)
		p.volume_db = -80
		a.volume_db = -80
		players.append(p)
		ambiences.append(a)
	_load_preferences()


func _load_preferences() -> void:
	var text := ""
	if OS.has_feature("web"):
		text = str(
			(
				JavaScriptBridge
				. eval(
					"(()=>{try{return localStorage.getItem('svf-presentation-v11')||'';}catch(e){return '';}})()",
					true
				)
			)
		)
	elif FileAccess.file_exists("user://presentation-v11.json"):
		text = FileAccess.get_file_as_string("user://presentation-v11.json")
	var data = JSON.parse_string(text) if not text.is_empty() else null
	if data is Dictionary:
		enabled = data.get("music", true)
		level = clampf(float(data.get("level", .65)), 0, 1)


func save_preferences() -> void:
	var text := JSON.stringify({"music": enabled, "level": level})
	if OS.has_feature("web"):
		JavaScriptBridge.eval(
			(
				"(()=>{try{localStorage.setItem('svf-presentation-v11',"
				+ JSON.stringify(text)
				+ ");}catch(e){}})()"
			),
			true
		)
	else:
		var file := FileAccess.open("user://presentation-v11.json", FileAccess.WRITE)
		if file != null:
			file.store_string(text)


func toggle() -> void:
	enabled = not enabled
	save_preferences()


func set_level(value: float) -> void:
	level = clampf(value, 0, 1)
	save_preferences()


func choose_music() -> void:
	pending_arena = stage_id
	if OS.has_feature("web"):
		# An ordinary file input requires the user's gesture. It never leaves the browser.
		(
			JavaScriptBridge
			. eval(
				"""(()=>{
 const old=document.getElementById('svf-music-file'); if(old) old.remove();
 const input=document.createElement('input'); input.type='file';
 input.id='svf-music-file'; input.accept='.mp3,.ogg,audio/mpeg,audio/ogg';
 input.style.display='none'; document.body.appendChild(input);
 input.onchange=()=>{const f=input.files[0]; if(!f)return;
 if(f.size>12582912){window.svfMusicSelection=JSON.stringify({error:'Arquivo maior que 12 MB'});return;}
 const reader=new FileReader(); reader.onload=()=>{
 window.svfMusicSelection=JSON.stringify({name:f.name,data:String(reader.result).split(',')[1]});};
 reader.readAsDataURL(f);}; input.click();
})()""",
				true
			)
		)
	else:
		if file_dialog == null:
			file_dialog = FileDialog.new()
			file_dialog.access = FileDialog.ACCESS_FILESYSTEM
			file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
			file_dialog.filters = PackedStringArray(["*.mp3,*.ogg ; Música MP3 / OGG"])
			file_dialog.title = "Escolha a música desta arena"
			file_dialog.file_selected.connect(_file_selected)
			add_child(file_dialog)
		file_dialog.popup_centered_ratio(.65)


func _file_selected(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_BYTES:
		file_status = "Arquivo indisponível ou maior que 12 MB"
		return
	load_music(file.get_buffer(file.get_length()), path.get_file(), pending_arena)


func load_music(bytes: PackedByteArray, filename: String, arena: String) -> bool:
	if bytes.is_empty() or bytes.size() > MAX_BYTES or not ArenaCatalog.IDS.has(arena):
		file_status = "Arquivo indisponível ou maior que 12 MB"
		return false
	var stream: AudioStream
	match filename.get_extension().to_lower():
		"ogg":
			stream = AudioStreamOggVorbis.load_from_buffer(bytes)
		"mp3":
			var mp3 := AudioStreamMP3.new()
			mp3.data = bytes
			stream = mp3
		_:
			file_status = "Escolha um MP3 ou OGG"
			return false
	if stream == null or stream.get_length() <= 0:
		file_status = "Não foi possível ler a música"
		return false
	stream.loop = true
	tracks[arena] = {"stream": stream, "name": filename.substr(0, 70)}
	file_status = "Arquivo local • fica apenas nesta sessão"
	if arena == stage_id:
		stage_id = ""
		play_arena(arena)
	return true


func remove_music() -> void:
	tracks.erase(stage_id)
	var previous := stage_id
	stage_id = ""
	play_arena(previous)


func play_arena(id: String) -> void:
	if stage_id == id:
		return
	var arena := ArenaCatalog.get_arena(id)
	stage_id = arena.id
	active = 1 - active
	elapsed = 0
	var ambient := load(arena.ambience) as AudioStreamOggVorbis
	if ambient == null:
		push_error("Stage ambience missing: " + id)
		return
	ambient.loop = true
	players[active].stop()
	ambiences[active].stop()
	players[active].stream = tracks.get(id, {}).get("stream")
	ambiences[active].stream = ambient
	players[active].volume_db = -80
	ambiences[active].volume_db = -80
	if players[active].stream != null:
		players[active].play()
	ambiences[active].play()


func _process(delta: float) -> void:
	if players.is_empty():
		return
	poll_clock += delta
	if OS.has_feature("web") and poll_clock >= .25:
		poll_clock = 0
		var payload := str(
			(
				JavaScriptBridge
				. eval(
					"(()=>{const p=window.svfMusicSelection||'';window.svfMusicSelection='';return p;})()",
					true
				)
			)
		)
		if not payload.is_empty():
			var result = JSON.parse_string(payload)
			if result is Dictionary:
				if result.has("error"):
					file_status = result.error
				else:
					load_music(Marshalls.base64_to_raw(result.data), result.name, pending_arena)
	elapsed = minf(FADE, elapsed + delta)
	var speaking: bool = game != null and (game.audio.voice.playing or game.audio.selection.playing)
	voice_duck = move_toward(voice_duck, 4.0 if speaking else 0.0, delta * 16)
	for i in 2:
		var fade := elapsed / FADE if i == active else 1.0 - elapsed / FADE
		var gain := fade * level if enabled else 0.0
		players[i].volume_db = maxf(-80, linear_to_db(maxf(.0001, gain)) - 10 - voice_duck)
		ambiences[i].volume_db = maxf(-80, linear_to_db(maxf(.0001, gain)) - 4)
		if i != active and elapsed >= FADE:
			players[i].stop()
			ambiences[i].stop()


func stop_all() -> void:
	for player in players + ambiences:
		player.stop()
		player.stream = null
	tracks.clear()


func observation() -> Dictionary:
	if players.is_empty():
		return {}
	return {
		"stage": stage_id,
		"enabled": enabled,
		"level": level,
		"playing": players[active].playing,
		"ambience_playing": ambiences[active].playing,
		"position": players[active].get_playback_position(),
		"decks": int(players[0].playing) + int(players[1].playing),
		"track": tracks.get(stage_id, {}).get("name", "Sem música • F6: arquivo local"),
		"local_tracks": tracks.size(),
		"gain_db": players[active].volume_db
	}
