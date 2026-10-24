class_name RealtimeRelay
extends Node
## Phoenix JSON v1 over TLS. Works in Web exports and networks blocking WebRTC.
signal joined
signal packet(value: Dictionary)
signal interrupted
var socket: WebSocketPeer
var room := ""
var peer_id := ""
var topic := ""
var connected := false
var enabled := false
var connecting := false
var reference := 0
var join_ref := ""
var heartbeat := 0.0
var retry := 0.0
var attempt := 0
var opened_at := 0


func open(code: String, id: String) -> void:
	close()
	room = code
	peer_id = id
	topic = "realtime:svf-godot-v24-" + code
	enabled = true
	_connect()


func _connect() -> void:
	socket = WebSocketPeer.new()
	socket.inbound_buffer_size = 1048576
	socket.outbound_buffer_size = 1048576
	connecting = false
	connected = false
	opened_at = Time.get_ticks_msec()
	var url := "wss://rulmufwtytgfmznuduuo.supabase.co/realtime/v1/websocket?apikey="
	url += RoomDirectory.KEY + "&vsn=1.0.0"
	if socket.connect_to_url(url) != OK:
		_disconnect()


func _write(event: String, data: Dictionary, channel: String = "") -> bool:
	if socket == null or socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return false
	reference += 1
	return socket.send_text(JSON.stringify({"topic": topic if channel.is_empty() else channel,
		"event": event, "payload": data, "ref": str(reference),
		"join_ref": join_ref if channel.is_empty() else null})) == OK


func send(value: Dictionary) -> bool:
	if not connected or socket.get_current_outbound_buffered_amount() > 262144:
		return false
	var data := value.duplicate()
	data.from = peer_id
	return _write("broadcast", {"type": "broadcast", "event": "game", "payload": data})


func _disconnect() -> void:
	var was_connected := connected or connecting
	connected = false
	connecting = false
	if socket != null:
		socket.close()
		socket = null
	retry = minf(8, pow(2, attempt))
	attempt += 1
	if was_connected:
		interrupted.emit()


func close() -> void:
	enabled = false
	connected = false
	connecting = false
	if socket != null:
		socket.close(1000)
		socket = null
	attempt = 0
	retry = 0


func _process(delta: float) -> void:
	if not enabled:
		return
	if socket == null:
		retry -= delta
		if retry <= 0:
			_connect()
		return
	socket.poll()
	var state := socket.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		if not connecting:
			connecting = true
			join_ref = str(reference + 1)
			_write("phx_join", {"config": {"broadcast": {"ack": false, "self": false},
				"presence": {"enabled": false}, "private": false}})
		while socket != null and socket.get_available_packet_count() > 0:
			var raw := socket.get_packet()
			if raw.size() > 524288:
				continue
			var value = JSON.parse_string(raw.get_string_from_utf8())
			if not value is Dictionary or value.get("topic", "") != topic:
				continue
			if value.get("event") == "phx_reply" and value.get("ref") == join_ref:
				if value.get("payload", {}).get("status", "") == "ok":
					connected = true
					attempt = 0
					heartbeat = 0
					joined.emit()
				else:
					_disconnect()
			elif value.get("event") == "broadcast":
				var payload = value.get("payload", {})
				if payload is Dictionary and payload.get("event") == "game":
					var body = payload.get("payload")
					if body is Dictionary and body.get("from", "") != peer_id:
						packet.emit(body)
			elif value.get("event") in ["phx_error", "phx_close"]:
				_disconnect()
		heartbeat += delta
		if connected and heartbeat > 20:
			heartbeat = 0
			_write("heartbeat", {}, "phoenix")
	elif state == WebSocketPeer.STATE_CLOSED:
		_disconnect()
	if socket != null and not connected and Time.get_ticks_msec() - opened_at > 12000:
		_disconnect()
