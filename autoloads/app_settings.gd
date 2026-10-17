extends Node
## A simulação recebe apenas bits. Dispositivos, preferências e deadzone ficam aqui.
signal controllers_changed
signal menu_action(key: int)
const SAVE_PATH := "user://controllers-v1.json"
const PAD_ACTIONS := [
	"left",
	"right",
	"down",
	"up",
	"jump",
	"punch",
	"kick",
	"guard",
	"special",
	"uppercut",
	"super",
	"throw",
	"drone",
	"custom",
	"counter",
	"punch_strong",
	"kick_strong",
	"pause"
]
const PAD_LABELS := [
	"Esquerda",
	"Direita",
	"Baixo",
	"Cima",
	"Pular",
	"Soco",
	"Chute",
	"Defender",
	"Poder",
	"Gancho",
	"Super",
	"Agarrar",
	"Drone",
	"Custom",
	"Contra-ataque",
	"Soco forte",
	"Chute forte",
	"Start / Pausa"
]
var navigation_previous: Dictionary = {}
var navigation_repeat: Dictionary = {}
var devices: Array[int] = [-1, -1]
var device_names: Dictionary = {}
var profiles: Dictionary = {}
var ui_open := false
var save_error := ""


func _ready() -> void:
	load_profiles()
	Input.joy_connection_changed.connect(_connection_changed)
	refresh_devices()
	Input.use_accumulated_input = false


func keyboard_maps() -> Array:
	# Mesmas teclas físicas do Canvas, inclusive seis botões e força por botão.
	return [
		{
			"left": KEY_A,
			"right": KEY_D,
			"down": KEY_S,
			"up": KEY_W,
			"jump": KEY_SPACE,
			"guard": KEY_R,
			"punch": KEY_F,
			"kick": KEY_G,
			"special": KEY_H,
			"uppercut": KEY_U,
			"super": KEY_Q,
			"throw": KEY_E,
			"drone": KEY_Z,
			"custom": KEY_C,
			"counter": KEY_X,
			"punch_light": KEY_T,
			"punch_strong": KEY_Y,
			"kick_light": KEY_V,
			"kick_strong": KEY_B
		},
		{
			"left": KEY_LEFT,
			"right": KEY_RIGHT,
			"down": KEY_DOWN,
			"up": KEY_UP,
			"jump": KEY_KP_0,
			"guard": KEY_O,
			"punch": KEY_J,
			"kick": KEY_K,
			"special": KEY_L,
			"uppercut": KEY_SEMICOLON,
			"super": KEY_PERIOD,
			"throw": KEY_N,
			"drone": KEY_I,
			"custom": KEY_M,
			"counter": KEY_COMMA,
			"punch_light": KEY_KP_7,
			"punch_strong": KEY_KP_9,
			"kick_light": KEY_KP_4,
			"kick_strong": KEY_KP_6
		}
	]


func device_key(device: int) -> String:
	if device < 0:
		return "keyboard"
	if device not in Input.get_connected_joypads():
		return "unrecognized:%d" % device
	return Input.get_joy_guid(device) + ":" + device_label(device)


func device_label(device: int) -> String:
	if device < 0 or device not in Input.get_connected_joypads():
		return "Somente teclado"
	return str(device_names.get(device, Input.get_joy_name(device)))


func _read_device_name(device: int) -> String:
	# Godot's normalized Web layout name is identical for all standard gamepads.
	# Read the actual Gamepad.id once on connection, never in the 120 Hz sampler.
	if OS.has_feature("web"):
		var raw = JavaScriptBridge.eval(
			(
				"(()=>{try{return navigator.getGamepads()[%d]?.id||'';}catch(e){return '';}})()"
				% device
			),
			true
		)
		if raw is String and not raw.is_empty():
			return raw
	return Input.get_joy_name(device)


func default_profile() -> Dictionary:
	# Godot normaliza XInput e o padrão Web. Genéricos podem remapear tudo.
	return {
		"deadzone": 0.3,
		"bindings":
		{
			"left": {"axis": 0, "sign": -1},
			"right": {"axis": 0, "sign": 1},
			"up": {"axis": 1, "sign": -1},
			"down": {"axis": 1, "sign": 1},
			"jump": {"button": JOY_BUTTON_A},
			"kick": {"button": JOY_BUTTON_B},
			"punch": {"button": JOY_BUTTON_X},
			"special": {"button": JOY_BUTTON_Y},
			"guard": {"button": JOY_BUTTON_LEFT_SHOULDER},
			"punch_strong": {"button": JOY_BUTTON_RIGHT_SHOULDER},
			"kick_strong": {"axis": JOY_AXIS_TRIGGER_RIGHT, "sign": 1},
			"throw": {"button": JOY_BUTTON_BACK},
			"drone": {"button": JOY_BUTTON_LEFT_STICK},
			"counter": {"button": JOY_BUTTON_RIGHT_STICK},
			"pause": {"button": JOY_BUTTON_START}
		}
	}


func profile(device: int) -> Dictionary:
	var result := default_profile()
	var saved: Dictionary = profiles.get(device_key(device), {})
	result.deadzone = clampf(float(saved.get("deadzone", 0.3)), 0.15, 0.65)
	for action in PAD_ACTIONS:
		var binding: Dictionary = saved.get("bindings", {}).get(action, {})
		if valid_binding(binding):
			result.bindings[action] = binding.duplicate()
	return result


func valid_binding(binding: Dictionary) -> bool:
	if binding.get("unbound", false):
		return true
	return (
		(
			binding.has("button")
			and typeof(binding.button) in [TYPE_FLOAT, TYPE_INT]
			and int(binding.button) >= 0
			and int(binding.button) < 128
		)
		or (
			binding.has("axis")
			and int(binding.axis) >= 0
			and int(binding.axis) < 10
			and int(binding.get("sign", 0)) in [-1, 1]
		)
	)


func load_profiles() -> void:
	var raw := ""
	if OS.has_feature("web"):
		var stored = JavaScriptBridge.eval(
			(
				"(()=>{try{return localStorage.getItem('svf-godot-controllers-v1')||'';}"
				+ "catch(e){return '';}})()"
			),
			true
		)
		if stored is String:
			raw = stored
	elif FileAccess.file_exists(SAVE_PATH):
		raw = FileAccess.get_file_as_string(SAVE_PATH)
	if raw.is_empty():
		return
	var data = JSON.parse_string(raw)
	if data is Dictionary:
		profiles = data


func save_profiles() -> void:
	var serialized := JSON.stringify(profiles)
	save_error = ""
	if OS.has_feature("web"):
		var ok = JavaScriptBridge.eval(
			(
				"(()=>{try{localStorage.setItem('svf-godot-controllers-v1',"
				+ JSON.stringify(serialized)
				+ ");return 1;}catch(e){return 0;}})()"
			),
			true
		)
		if int(ok) != 1:
			save_error = "Não foi possível salvar neste navegador."
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		save_error = "Não foi possível salvar as configurações."
	else:
		file.store_string(serialized)
		file.close()


func bind(device: int, action: String, binding: Dictionary) -> Array[String]:
	var displaced: Array[String] = []
	if device < 0 or action not in PAD_ACTIONS or not valid_binding(binding):
		return displaced
	var value := profile(device)
	# Troca a associação anterior em caso de conflito; nunca dispara dois golpes.
	var previous_binding: Dictionary = value.bindings.get(action, {})
	for other in value.bindings.keys():
		if other != action and value.bindings[other] == binding:
			displaced.append(other)
			if previous_binding.is_empty():
				value.bindings[other] = {"unbound": true}
			else:
				value.bindings[other] = previous_binding.duplicate()
	value.bindings[action] = binding.duplicate()
	profiles[device_key(device)] = value
	save_profiles()
	rebuild()
	return displaced


func set_deadzone(device: int, value: float) -> void:
	var entry := profile(device)
	entry.deadzone = clampf(value, 0.15, 0.65)
	profiles[device_key(device)] = entry
	save_profiles()
	rebuild()


func reset_device(device: int) -> void:
	profiles.erase(device_key(device))
	save_profiles()
	rebuild()


func assign_device(slot: int, device: int) -> void:
	var other := 1 - slot
	if device >= 0 and devices[other] == device:
		devices[other] = devices[slot]
	devices[slot] = device
	rebuild()
	controllers_changed.emit()


func refresh_devices() -> void:
	var connected := Input.get_connected_joypads()
	for device in connected:
		device_names[device] = _read_device_name(device)
	for i in 2:
		if devices[i] not in connected:
			devices[i] = -1
	for device in connected:
		if device not in devices:
			var free := devices.find(-1)
			if free >= 0:
				devices[free] = device
	rebuild()
	controllers_changed.emit()


func _connection_changed(_device: int, _connected: bool) -> void:
	refresh_devices()


func _key(action: String, code: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	InputMap.action_add_event(action, event)


func rebuild() -> void:
	var keys := keyboard_maps()
	for slot in 2:
		var names: Array = LocalCombatInput.NAMES.duplicate()
		names.append_array(["punch_light", "punch_strong", "kick_light", "kick_strong", "pause"])
		var config := profile(devices[slot])
		for name in names:
			var action := "p%d_%s" % [slot + 1, name]
			if not InputMap.has_action(action):
				InputMap.add_action(action)
			Input.action_release(action)
			InputMap.action_erase_events(action)
			InputMap.action_set_deadzone(action, config.deadzone)
			if keys[slot].has(name):
				_key(action, keys[slot][name])
			if slot == 1 and name in ["punch", "kick"]:
				_key(action, KEY_KP_8 if name == "punch" else KEY_KP_5)
			if devices[slot] < 0:
				continue
			var binding: Dictionary = config.bindings.get(name, {})
			if binding.has("button"):
				var button := InputEventJoypadButton.new()
				button.device = devices[slot]
				button.button_index = int(binding.button)
				InputMap.action_add_event(action, button)
			elif binding.has("axis"):
				var axis := InputEventJoypadMotion.new()
				axis.device = devices[slot]
				axis.axis = int(binding.axis)
				axis.axis_value = float(binding.sign)
				InputMap.action_add_event(action, axis)
			# D-pad permanece utilizável junto ao analógico padrão. Se remapeado,
			# respeita-se o botão/eixo escolhido (sem ação duplicada no direcional).
			if (
				name in ["left", "right", "up", "down"]
				and binding == default_profile().bindings[name]
			):
				var dpad := InputEventJoypadButton.new()
				dpad.device = devices[slot]
				dpad.button_index = {
					"left": JOY_BUTTON_DPAD_LEFT,
					"right": JOY_BUTTON_DPAD_RIGHT,
					"up": JOY_BUTTON_DPAD_UP,
					"down": JOY_BUTTON_DPAD_DOWN
				}[name]
				InputMap.action_add_event(action, dpad)


func binding_pressed(device: int, binding: Dictionary, zone: float) -> bool:
	if binding.has("button"):
		return Input.is_joy_button_pressed(device, int(binding.button))
	if binding.has("axis"):
		return Input.get_joy_axis(device, int(binding.axis)) * int(binding.sign) > zone
	return false


func _process(_delta: float) -> void:
	if ui_open:
		navigation_previous.clear()
		return
	var now := Time.get_ticks_msec()
	for device in devices:
		if device < 0:
			continue
		var config := profile(device)
		var old: Dictionary = navigation_previous.get(device, {})
		var repeat: Dictionary = navigation_repeat.get(device, {})
		var current := {}
		for action in ["up", "down", "left", "right", "jump", "kick", "pause"]:
			var pressed := binding_pressed(device, config.bindings.get(action, {}), config.deadzone)
			if (
				action in ["left", "right", "up", "down"]
				and config.bindings.get(action, {}) == default_profile().bindings[action]
			):
				pressed = (
					pressed
					or Input.is_joy_button_pressed(
						device,
						{
							"left": JOY_BUTTON_DPAD_LEFT,
							"right": JOY_BUTTON_DPAD_RIGHT,
							"up": JOY_BUTTON_DPAD_UP,
							"down": JOY_BUTTON_DPAD_DOWN
						}[action]
					)
				)
			if action == "pause" and pad_modifier(device) and not config.bindings.has("custom"):
				pressed = false
			current[action] = pressed
			var direction: bool = action in ["up", "down", "left", "right"]
			if (
				pressed
				and (not old.get(action, false) or direction and now >= int(repeat.get(action, 0)))
			):
				menu_action.emit(
					{
						"up": KEY_UP,
						"down": KEY_DOWN,
						"left": KEY_LEFT,
						"right": KEY_RIGHT,
						"jump": KEY_ENTER,
						"kick": KEY_ESCAPE,
						"pause": KEY_PAUSE
					}[action]
				)
				repeat[action] = now + (300 if not old.get(action, false) else 140)
		navigation_previous[device] = current
		navigation_repeat[device] = repeat


func pad_modifier(device: int) -> bool:
	if device < 0:
		return false
	var config := profile(device)
	for binding in config.bindings.values():
		if int(binding.get("axis", -1)) == JOY_AXIS_TRIGGER_LEFT:
			return false
	return Input.get_joy_axis(device, JOY_AXIS_TRIGGER_LEFT) > float(config.deadzone)
