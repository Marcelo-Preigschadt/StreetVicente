class_name RoomDirectory
extends Node
## Same token-owned directory as the Canvas game, filtered by Godot protocol.
signal changed
signal failed(message: String)
const URL := "https://rulmufwtytgfmznuduuo.supabase.co/rest/v1/svf_rooms"
const KEY := "sb_publishable_ImcwfTJHChOS_o3gYTOn-Q_mIEB1lhB"
const PROTOCOL := "svf-godot-v25b"
const FIELDS := "code,status,character,game_mode,protocol,created_at,expires_at"
var rooms: Array = []
var game_mode := "versus"
var lease: Dictionary = {}
var refreshing := false
var active := false
var refresh_clock := 0.0
var heartbeat_clock := 0.0


static func token() -> String:
	return Crypto.new().generate_random_bytes(32).hex_encode()


static func normalize(value: String) -> String:
	return value.strip_edges().to_upper().replace(" ", "").replace("-", "")


static func valid_code(value: String) -> bool:
	if value.length() != 8:
		return false
	for letter in value:
		if not letter in "ABCDEFGHJKLMNPQRSTUVWXYZ23456789":
			return false
	return true


static func new_code() -> String:
	var result := ""
	for byte in Crypto.new().generate_random_bytes(8):
		result += "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"[byte % 32]
	return result


func request(query: String = "", method: int = HTTPClient.METHOD_GET,
	body: Dictionary = {}, secret: String = "") -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = 10
	# Fetch already decompresses HTTP bodies in Web builds. Do not decompress twice.
	http.accept_gzip = not OS.has_feature("web")
	add_child(http)
	var headers := PackedStringArray(["apikey: " + KEY, "Content-Type: application/json"])
	if not secret.is_empty():
		headers.append("x-room-token: " + secret)
	if method != HTTPClient.METHOD_GET:
		headers.append("Prefer: return=minimal")
	var error := http.request(URL + query, headers, method,
		JSON.stringify(body) if not body.is_empty() else "")
	if error != OK:
		http.queue_free()
		return {"ok": false, "status": 0, "data": null}
	var result: Array = await http.request_completed
	http.queue_free()
	var json := JSON.new()
	var parsed = null
	var text: String = result[3].get_string_from_utf8()
	if not text.is_empty() and json.parse(text) == OK:
		parsed = json.data
	return {"ok": result[0] == HTTPRequest.RESULT_SUCCESS and result[1] in range(200, 300),
		"status": result[1], "data": parsed}


func start(value: String = "versus") -> void:
	active = true
	if game_mode != value:
		rooms.clear()
		changed.emit()
	game_mode = value
	refresh_clock = 0
	refresh()


func refresh() -> void:
	if refreshing:
		return
	refreshing = true
	var mode := game_mode
	var result := await request("?select=" + FIELDS + "&protocol=eq." + PROTOCOL
		+ "&game_mode=eq." + mode + "&order=created_at.desc&limit=100")
	refreshing = false
	if not active:
		return
	if mode != game_mode:
		refresh()
		return
	if result.ok and result.data is Array:
		rooms = result.data
		changed.emit()
	else:
		failed.emit("Não foi possível atualizar as salas. Tente novamente.")


func register(code: String, character: String, mode: String) -> bool:
	var created := {"code": code, "token": token(), "character": character,
		"status": "waiting", "game_mode": mode}
	lease = created
	var result := await request("", HTTPClient.METHOD_POST, {
		"code": code, "owner_hash": str(created.token).sha256_text(),
		"status": "waiting", "character": character, "protocol": PROTOCOL,
		"game_mode": mode}, created.token)
	if lease != created:
		if result.ok:
			await request("?code=eq." + code, HTTPClient.METHOD_DELETE, {}, created.token)
		return false
	if not result.ok:
		lease = {}
		failed.emit("Não foi possível criar a sala. Tente novamente.")
		return false
	heartbeat_clock = 0
	refresh()
	return true


func update(status: String, character: String) -> void:
	if lease.is_empty():
		return
	lease.status = status
	lease.character = character
	var value := lease.duplicate()
	await request("?code=eq." + str(value.code), HTTPClient.METHOD_PATCH,
		{"status": status, "character": character}, value.token)


func remove() -> void:
	var value := lease
	lease = {}
	if not value.is_empty():
		await request("?code=eq." + str(value.code), HTTPClient.METHOD_DELETE, {}, value.token)


func _process(delta: float) -> void:
	if not active:
		return
	refresh_clock += delta
	heartbeat_clock += delta
	if refresh_clock >= 5:
		refresh_clock = 0
		refresh()
	if heartbeat_clock >= 20 and not lease.is_empty():
		heartbeat_clock = 0
		update(lease.status, lease.character)
