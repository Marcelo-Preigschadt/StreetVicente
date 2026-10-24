class_name OnlineSession
extends Node
## Two seats, host-authoritative lobby/control and deterministic peer simulation.
signal changed
signal prepare_game
signal reset_presentation
signal committed(events: Array)
const VERSION := "svf-godot-v25b"
const TICKET := "svf-online-godot-v22"
var directory: RoomDirectory
var relay: RealtimeRelay
var phase := "closed"
var status := ""
var room := ""
var slot := 0
var local_id := ""
var remote_id := ""
var game_mode := "versus"
var pair: Array = ["marcelo", "rafael"]
var confirmed: Array = [false, false]
var loaded: Array = [false, false]
var finished: Array = [false, false]
var stage := "patio"
var match_id := ""
var sync_id := 0
var lobby_revision := 0
var choice_serial := 0
var choice_versions: Array = [0, 0]
var proposed := ""
var proposed_ready := false
var user_paused := false
var world
var timeline: RollbackSession
var rtt := 0
var last_seen := 0
var last_send := 0
var last_ping := 0
var last_hello := 0
var last_save := 0
var last_hash := -1
var last_confirmed_hash := ""
var generation := 0
var initial_registered := false
var stalled_since := 0
var last_control := 0
var sync_packet: Dictionary = {}
var prepare_packet: Dictionary = {}


func setup(value: RoomDirectory) -> void:
	directory = value
	relay = RealtimeRelay.new()
	add_child(relay)
	relay.joined.connect(_joined)
	relay.packet.connect(_receive)
	relay.interrupted.connect(_interrupted)


func active() -> bool:
	return phase not in ["closed", "error"]


func _status(value: String) -> void:
	status = value
	changed.emit()


func begin(kind: String, mode: String, code: String = "") -> void:
	leave()
	generation += 1
	var current := generation
	game_mode = "story" if mode == "story" else "versus"
	directory.start(game_mode)
	phase = "connecting"
	_status("Conectando ao serviço de salas…")
	if kind == "quick":
		var response := await directory.request("?select=" + RoomDirectory.FIELDS
			+ "&protocol=eq." + VERSION + "&game_mode=eq." + game_mode
			+ "&status=eq.waiting&order=created_at.asc&limit=1")
		if current != generation:
			return
		if not response.ok:
			fail("Não foi possível buscar uma partida. Tente novamente.")
			return
		kind = "join" if response.data is Array and not response.data.is_empty() else "create"
		if kind == "join":
			code = response.data[0].code
	slot = 0 if kind == "create" else 1
	room = RoomDirectory.new_code() if slot == 0 else RoomDirectory.normalize(code)
	if not RoomDirectory.valid_code(room):
		fail("Digite os 8 caracteres do código da sala.")
		return
	if slot == 1:
		var response := await directory.request("?select=" + RoomDirectory.FIELDS
			+ "&code=eq." + room + "&protocol=eq." + VERSION + "&game_mode=eq." + game_mode)
		if current != generation:
			return
		if not response.ok or not response.data is Array:
			fail("Não foi possível consultar a sala. Verifique a conexão e tente novamente.")
			return
		if response.data.is_empty():
			fail("Sala não encontrada, expirada ou de outra versão do jogo.")
			return
		if response.data[0].status != "waiting":
			fail("Essa sala já está ocupada. Escolha outra sala.")
			return
	pair = ["marcelo", "rafael"]
	confirmed = [false, false]
	loaded = [false, false]
	finished = [false, false]
	world = null
	timeline = null
	match_id = ""
	sync_id = 0
	lobby_revision = 0
	choice_serial = 0
	choice_versions = [0, 0]
	proposed = ""
	proposed_ready = false
	user_paused = false
	initial_registered = false
	prepare_packet = {}
	last_hash = -1
	last_confirmed_hash = ""
	local_id = "host:" + room if slot == 0 else RoomDirectory.token().left(32)
	remote_id = "" if slot == 0 else "host:" + room
	last_seen = Time.get_ticks_msec()
	relay.open(room, local_id)
	_status("Criando sala…" if slot == 0 else "Entrando na sala…")


func _joined() -> void:
	last_seen = Time.get_ticks_msec()
	if slot == 0 and not initial_registered:
		initial_registered = true
		var current := generation
		var ok := await directory.register(room, pair[0], game_mode)
		if current != generation:
			return
		if not ok:
			fail("Não foi possível registrar a sala. Tente criar novamente.")
			return
		phase = "lobby"
		_status("Sala " + room + " criada. Aguardando outro jogador…")
		_save_ticket()
	elif slot == 1:
		_hello()
	else:
		_send({"t": "host_back"})
		_status("Reconectado. Aguardando o outro jogador…")


func _send(value: Dictionary, target: String = "") -> bool:
	var body := value.duplicate()
	body.to = remote_id if target.is_empty() else target
	body.protocol = VERSION
	body.game_mode = game_mode
	return relay.send(body)


func _hello() -> void:
	last_hello = Time.get_ticks_msec()
	_send({"t": "hello", "recover": world != null or not match_id.is_empty()})


func _welcome() -> void:
	_send({"t": "welcome", "pair": pair, "confirmed": confirmed,
		"serials": choice_versions,
		"stage": stage, "revision": lobby_revision,
		"epoch": match_id, "in_game": world != null})


func _valid_pair(value: Variant) -> bool:
	return value is Array and value.size() == 2 and value[0] is String and value[1] is String \
		and value[0] in LegacyRoster.ids() and value[1] in LegacyRoster.ids() and value[0] != value[1]


func _receive(message: Dictionary) -> void:
	if not active() or message.get("to") != local_id or message.get("protocol") != VERSION \
		or message.get("game_mode") != game_mode or not message.get("from") is String:
		return
	var sender: String = message.from
	var type := str(message.get("t", ""))
	if type == "hello" and slot == 0:
		if not remote_id.is_empty() and sender != remote_id:
			_send({"t": "busy"}, sender)
			return
		remote_id = sender
		last_seen = Time.get_ticks_msec()
		_welcome()
		if world != null:
			_synchronize()
		else:
			phase = "lobby"
			_status("Jogador conectado. Cada um confirma seu próprio personagem.")
		return
	if sender != remote_id:
		return
	last_seen = Time.get_ticks_msec()
	if type == "busy":
		fail("A sala já tem dois jogadores. Escolha outra sala.")
		return
	if type == "host_back" and slot == 1:
		_hello()
		return
	if type == "welcome" and slot == 1:
		if not _valid_pair(message.get("pair")) or not _valid_flags(message.get("confirmed")):
			return
		var new_incarnation: bool = message.get("in_game", false) and str(message.get("epoch", "")) != match_id
		if int(message.get("revision", -1)) < lobby_revision and not new_incarnation:
			return
		pair = message.pair.duplicate()
		confirmed = message.confirmed.duplicate()
		if message.get("serials") is Array and message.serials.size() == 2:
			choice_versions = message.serials.duplicate()
		lobby_revision = int(message.revision)
		if message.get("stage", "") in ArenaCatalog.IDS:
			stage = message.stage
		if message.get("in_game", false):
			if match_id != str(message.epoch):
				match_id = str(message.epoch)
				sync_id = 0
			if world == null:
				match_id = str(message.epoch)
				phase = "preparing"
				prepare_game.emit()
		else:
			world = null
			timeline = null
			phase = "lobby"
			_status("Conectado. Escolha seu personagem e confirme com Enter.")
		_save_ticket()
		return
	if type == "ping":
		_send({"t": "pong", "sent": message.get("sent", 0)})
		return
	if type == "pong":
		rtt = clampi(Time.get_ticks_msec() - int(message.get("sent", 0)), 0, 30000)
		return
	if type == "leave":
		if slot == 0:
			remote_id = ""
			world = null
			timeline = null
			confirmed = [false, false]
			choice_versions[1] = 0
			lobby_revision += 1
			match_id = ""
			phase = "lobby"
			directory.update("waiting", pair[0])
			_status("O outro jogador saiu. A sala está disponível novamente.")
		else:
			fail("O anfitrião encerrou a sala. Você pode entrar em outra partida.")
		return
	if type == "choice" and slot == 0 and phase == "lobby":
		var character := str(message.get("character", ""))
		var serial := int(message.get("serial", -1))
		if serial <= int(choice_versions[1]):
			return
		choice_versions[1] = serial
		if character in LegacyRoster.ids() and character != pair[0]:
			pair[1] = character
			confirmed[1] = bool(message.get("ready", false))
			lobby_revision += 1
			_welcome()
			changed.emit()
			_maybe_prepare()
		else:
			confirmed[1] = false
			lobby_revision += 1
			_welcome()
		return
	if type == "prepare" and slot == 1 and _valid_pair(message.get("pair")):
		if str(message.get("epoch", "")).is_empty() or message.get("stage") not in ArenaCatalog.IDS:
			return
		if world != null and str(message.epoch) == match_id:
			_send({"t": "loaded", "epoch": match_id})
			return
		if phase != "lobby":
			return
		if not message.get("serials") is Array or message.serials.size() != 2 \
			or int(message.serials[1]) != choice_serial or not proposed_ready \
			or message.pair[1] != proposed:
			_send({"t": "cancel_prepare", "epoch": message.get("epoch", "")})
			_send({"t": "choice", "character": proposed, "ready": proposed_ready, "serial": choice_serial})
			return
		# Prepare is the authoritative ready acknowledgement. A separate welcome
		# may arrive late; it must neither gate loading nor erase a prepared world.
		pair = message.pair.duplicate()
		confirmed = [true, true]
		choice_versions = message.serials.duplicate()
		lobby_revision = maxi(lobby_revision, int(message.get("revision", lobby_revision)))
		stage = str(message.get("stage", "patio"))
		match_id = str(message.get("epoch", ""))
		phase = "preparing"
		prepare_game.emit()
		return
	if world == null or message.get("epoch") != match_id:
		return
	if type == "cancel_prepare" and slot == 0 and phase == "preparing":
		_back_to_selection()
	elif type == "loaded" and slot == 0:
		if phase == "preparing":
			loaded[1] = true
			if loaded[0]:
				_synchronize()
		elif phase == "syncing" and not sync_packet.is_empty():
			_send(sync_packet)
	elif type == "sync" and slot == 1:
		var serial := int(message.get("sync", -1))
		var state = message.get("state")
		if serial == sync_id and timeline != null:
			_send({"t": "synced", "epoch": match_id, "sync": sync_id})
			return
		if serial < sync_id or not state is Dictionary or not _valid_snapshot(state):
			return
		if SnapshotCodec.state_hash(SnapshotCodec.integers(state)) != message.get("hash"):
			return
		sync_id = serial
		last_hash = -1
		world.restore(state)
		timeline = RollbackSession.new()
		timeline.setup(world, slot)
		user_paused = bool(message.get("paused", false))
		phase = "syncing"
		reset_presentation.emit()
		_send({"t": "synced", "epoch": match_id, "sync": sync_id})
		_save_ticket()
	elif type == "synced" and slot == 0 and int(message.get("sync", -1)) == sync_id:
		_send({"t": "run", "epoch": match_id, "sync": sync_id, "paused": user_paused})
		phase = "paused" if user_paused else "playing"
		_status("Partida pausada pelos jogadores." if user_paused else "Conectado")
	elif type == "run" and slot == 1 and int(message.get("sync", -1)) == sync_id:
		user_paused = bool(message.get("paused", false))
		phase = "paused" if user_paused else "playing"
		_status("Partida pausada pelos jogadores." if user_paused else "Conectado")
	elif type == "inputs" and int(message.get("sync", -1)) == sync_id and timeline != null:
		if not timeline.ingest(message):
			if not timeline.fault.is_empty():
				_request_recovery()
	elif type == "recover" and slot == 0:
		_synchronize()
	elif type == "pause" and slot == 0:
		user_paused = bool(message.get("paused", true))
		_synchronize()
	elif type == "finished":
		finished[1 - slot] = true
		_maybe_finish()
	elif type == "hash" and slot == 0 and timeline != null and int(message.get("sync", -1)) == sync_id:
		var at := int(message.get("at", -1))
		if at < 0 or at > timeline.confirmed_tick() + 1:
			return
		var state := timeline.checkpoint(at)
		if not state.is_empty() and SnapshotCodec.state_hash(state) != message.get("hash"):
			_synchronize()
	elif type == "selection" and slot == 1:
		_back_to_selection()


func _valid_flags(value: Variant) -> bool:
	return value is Array and value.size() == 2 and value[0] is bool and value[1] is bool


func selection_character() -> String:
	if slot == 1 and int(choice_versions[1]) < choice_serial and not proposed.is_empty():
		return proposed
	return str(pair[slot])


func choose(character: String, ready: bool = false) -> void:
	if phase != "lobby" or character not in LegacyRoster.ids():
		return
	if character == pair[1 - slot]:
		_status("Esse personagem já foi escolhido pelo outro jogador.")
		return
	if slot == 0:
		choice_versions[0] = int(choice_versions[0]) + 1
		pair[0] = character
		confirmed[0] = ready
		lobby_revision += 1
		directory.update("waiting", character)
		_welcome()
		changed.emit()
		_maybe_prepare()
	else:
		choice_serial += 1
		proposed = character
		proposed_ready = ready
		_send({"t": "choice", "character": character, "ready": ready, "serial": choice_serial})


func set_stage(value: String) -> void:
	if slot == 0 and phase == "lobby" and value in ArenaCatalog.IDS:
		stage = value
		lobby_revision += 1
		_welcome()
		changed.emit()


func _maybe_prepare() -> void:
	if slot != 0 or phase != "lobby" or remote_id.is_empty() or not confirmed.all(func(v): return v):
		return
	match_id = RoomDirectory.token().left(32)
	loaded = [false, false]
	finished = [false, false]
	sync_id = 0
	phase = "preparing"
	lobby_revision += 1
	last_control = Time.get_ticks_msec()
	directory.update("playing", pair[0])
	prepare_packet = {"t": "prepare", "pair": pair, "stage": stage, "epoch": match_id,
		"serials": choice_versions, "revision": lobby_revision}
	_send(prepare_packet)
	prepare_game.emit()


func attach_world(value) -> void:
	world = value
	loaded[slot] = true
	if slot == 1:
		last_control = Time.get_ticks_msec()
		_send({"t": "loaded", "epoch": match_id})
	elif loaded[1]:
		_synchronize()


func _synchronize() -> void:
	if slot != 0 or world == null or remote_id.is_empty():
		return
	var state: Dictionary = timeline.checkpoint() if timeline != null else world.snapshot()
	if state.is_empty():
		state = world.snapshot()
	world.restore(state)
	timeline = RollbackSession.new()
	timeline.setup(world, slot)
	sync_id += 1
	last_hash = -1
	phase = "syncing"
	reset_presentation.emit()
	sync_packet = {"t": "sync", "epoch": match_id, "sync": sync_id, "state": state,
		"hash": SnapshotCodec.state_hash(state), "paused": user_paused}
	last_control = Time.get_ticks_msec()
	_send(sync_packet)
	_status("Sincronizando os jogadores…")
	_save_ticket()


func _valid_snapshot(state: Dictionary) -> bool:
	if world == null or not state.has("tick") or not _same_shape(state, world.snapshot()) \
		or int(state.tick) < 0:
		return false
	if game_mode == "versus":
		if state.get("schema") != 1 or state.fighters.size() != 2 or state.wins.size() != 2:
			return false
		for i in 2:
			if state.fighters[i].character != pair[i] or int(state.fighters[i].slot) != i:
				return false
		return true
	return state.hero.character == pair[0] and state.partner.character == pair[1] \
		and int(state.hero.slot) == 0 and int(state.partner.slot) == CoopStorySimulation.PARTNER_SLOT \
		and state.get("coop") == true and (int(state.act) in range(4) \
			or (int(state.act) == 4 and state.completed == true))


func _same_shape(value: Variant, sample: Variant, depth: int = 0) -> bool:
	if depth > 20:
		return false
	if sample is int or sample is float:
		return (value is int or value is float) and is_finite(float(value)) \
			and absf(float(value)) < 4503599627370496.0 and float(value) == float(int(value))
	if typeof(value) != typeof(sample):
		return false
	if sample is Dictionary:
		if value.size() > 512:
			return false
		for key in sample:
			if not value.has(key) or not _same_shape(value[key], sample[key], depth + 1):
				return false
	elif sample is Array:
		if value.size() > 512:
			return false
		if not sample.is_empty():
			for item in value:
				if not _same_shape(item, sample[0], depth + 1):
					return false
	return true


func advance(value: CombatInput) -> void:
	if timeline == null or phase != "playing":
		return
	timeline.advance(value)
	var events := timeline.drain_events()
	if not events.is_empty():
		committed.emit(events)


func pause_game(value: bool) -> void:
	if world == null or remote_id.is_empty():
		return
	if slot == 0:
		user_paused = value
		_synchronize()
	else:
		_send({"t": "pause", "epoch": match_id, "paused": value})


func finish() -> void:
	if world == null:
		return
	var state: Dictionary = timeline.checkpoint() if timeline != null else {}
	var ended: bool = bool(state.get("match_over", false)) if world is FightSimulation else bool(state.get("completed", false)) or bool(state.get("defeated", false))
	if not ended:
		return
	finished[slot] = true
	_send({"t": "finished", "epoch": match_id})
	_maybe_finish()
	_status("Aguardando o outro jogador voltar à seleção…")


func _maybe_finish() -> void:
	if slot == 0 and finished.all(func(v): return v):
		_send({"t": "selection", "epoch": match_id})
		_back_to_selection()


func _back_to_selection() -> void:
	world = null
	timeline = null
	match_id = ""
	confirmed = [false, false]
	loaded = [false, false]
	finished = [false, false]
	choice_serial = 0
	choice_versions = [0, 0]
	proposed = ""
	proposed_ready = false
	user_paused = false
	sync_id = 0
	lobby_revision += 1
	phase = "lobby"
	if slot == 0:
		directory.update("waiting", pair[0])
		_welcome()
	_status("Escolham os personagens para a próxima partida.")
	_save_ticket()


func _interrupted() -> void:
	if not active():
		return
	phase = "reconnecting"
	_status("Conexão interrompida. Reconectando à mesma sala…")


func _request_recovery() -> void:
	last_control = Time.get_ticks_msec()
	if slot == 0:
		_synchronize()
	else:
		phase = "syncing"
		_send({"t": "recover", "epoch": match_id})


func _process(_delta: float) -> void:
	if not active():
		return
	var now := Time.get_ticks_msec()
	if relay.connected and slot == 1 and phase in ["connecting", "reconnecting"] and now - last_hello > 1000:
		_hello()
	if relay.connected and not remote_id.is_empty():
		if phase == "preparing" and now - last_control > 1000:
			last_control = now
			if slot == 0 and not prepare_packet.is_empty():
				_send(prepare_packet)
			elif slot == 1 and world != null:
				_send({"t": "loaded", "epoch": match_id})
		if phase == "syncing" and now - last_control > 2000:
			last_control = now
			if slot == 0 and not sync_packet.is_empty():
				_send(sync_packet)
			elif slot == 1:
				_send({"t": "recover", "epoch": match_id})
		if phase == "playing" and timeline != null and not timeline.can_advance():
			if stalled_since == 0:
				stalled_since = now
			elif now - stalled_since > 1500 and now - last_seen < 1000:
				stalled_since = 0
				_request_recovery()
		else:
			stalled_since = 0
		if now - last_ping > 1000:
			last_ping = now
			_send({"t": "ping", "sent": now})
		if phase == "playing" and timeline != null and now - last_send >= 33:
			last_send = now
			var payload := timeline.packet()
			payload.t = "inputs"
			payload.epoch = match_id
			payload.sync = sync_id
			_send(payload)
			var at := (timeline.confirmed_tick() + 1) / 120 * 120
			if at > last_hash:
				last_hash = at
				var state := timeline.checkpoint(at)
				if not state.is_empty():
					last_confirmed_hash = SnapshotCodec.state_hash(state)
					_send({"t": "hash", "epoch": match_id, "sync": sync_id,
						"at": at, "hash": last_confirmed_hash})
		if now - last_seen > 2000 and world != null and phase in ["playing", "paused"]:
			phase = "reconnecting"
			_status("Aguardando a conexão do outro jogador. A partida foi preservada.")
		elif phase == "reconnecting" and now - last_seen < 1000 and world != null:
			_request_recovery()
	if now - last_save > 2000:
		last_save = now
		_save_ticket()


func leave() -> void:
	generation += 1
	if relay != null:
		if relay.connected:
			_send({"t": "leave", "epoch": match_id})
		relay.close()
	if directory != null:
		directory.remove()
	phase = "closed"
	world = null
	timeline = null
	remote_id = ""
	_clear_ticket()
	changed.emit()


func fail(message: String) -> void:
	leave()
	phase = "error"
	_status(message)


func _save_ticket() -> void:
	if not OS.has_feature("web") or not active() or room.is_empty():
		return
	var state: Dictionary = timeline.checkpoint() if timeline != null else {}
	var data := {"room": room, "slot": slot, "id": local_id, "remote": remote_id,
		"pair": pair, "mode": game_mode, "stage": stage, "epoch": match_id,
		"owner": directory.lease, "state": state, "paused": user_paused,
		"expires": int(Time.get_unix_time_from_system()) + 180}
	JavaScriptBridge.eval("try {sessionStorage.setItem('" + TICKET + "',"
		+ JSON.stringify(JSON.stringify(data)) + ")} catch(e) {}", true)


static func saved_ticket() -> Dictionary:
	if not OS.has_feature("web"):
		return {}
	var raw = JavaScriptBridge.eval("sessionStorage.getItem('" + TICKET + "') || ''", true)
	if raw == null or str(raw).is_empty():
		return {}
	var data = JSON.parse_string(str(raw))
	return data if data is Dictionary and int(data.get("expires", 0)) > int(Time.get_unix_time_from_system()) else {}


func resume_ticket(data: Dictionary) -> void:
	if not RoomDirectory.valid_code(str(data.get("room", ""))) or not _valid_pair(data.get("pair")):
		return
	if int(data.get("slot", -1)) not in [0, 1] or data.get("mode") not in ["versus", "story"] \
		or data.get("stage") not in ArenaCatalog.IDS:
		return
	generation += 1
	var current := generation
	phase = "connecting"
	_status("Verificando a sala salva…")
	var response := await directory.request("?select=" + RoomDirectory.FIELDS
		+ "&code=eq." + str(data.room) + "&protocol=eq." + VERSION)
	if current != generation:
		return
	if not response.ok or not response.data is Array or response.data.is_empty():
		fail("Essa sala expirou. Crie uma sala ou entre em outra partida.")
		return
	room = data.room
	slot = int(data.get("slot", 0))
	local_id = str(data.id)
	remote_id = str(data.remote)
	pair = data.pair
	game_mode = str(data.mode)
	stage = str(data.stage)
	match_id = str(data.get("epoch", ""))
	user_paused = bool(data.get("paused", false))
	directory.lease = data.get("owner", {})
	directory.start(game_mode)
	initial_registered = true
	phase = "reconnecting"
	if data.get("state") is Dictionary and not data.state.is_empty() and not match_id.is_empty():
		prepare_game.emit()
		if world != null and _valid_snapshot(data.state):
			world.restore(data.state)
			timeline = RollbackSession.new()
			timeline.setup(world, slot)
			if slot == 0:
				match_id = RoomDirectory.token().left(32)  # New host incarnation rejects old packets.
	last_seen = Time.get_ticks_msec()
	relay.open(room, local_id)
	_status("Retomando a sala " + room + "…")


func _clear_ticket() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("sessionStorage.removeItem('" + TICKET + "')", true)


func observation() -> Dictionary:
	var data := {"phase": phase, "room": room, "slot": slot, "mode": game_mode,
		"pair": pair, "ready": confirmed, "rtt": rtt, "stage": stage,
		"connected": relay != null and relay.connected, "partner": not remote_id.is_empty(),
		"sync": sync_id, "status": status, "confirmed_hash": last_confirmed_hash}
	data.hash_tick = last_hash
	if timeline != null:
		data.merge(timeline.observation())
	return data
