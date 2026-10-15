extends Node
## Mapeamento fica na borda do sistema. A simulação só recebe máscaras de bits.


func _ready() -> void:
	_bind_player(0, [KEY_A, KEY_D, KEY_S, KEY_W, KEY_F, KEY_G, KEY_H])
	_bind_player(1, [KEY_LEFT, KEY_RIGHT, KEY_DOWN, KEY_UP, KEY_J, KEY_K, KEY_L])
	_key("debug_boxes", KEY_F1)
	_key("dummy_mode", KEY_F2)
	_key("reset_match", KEY_R)
	_key("fullscreen", KEY_F11)
	_key("pause_match", KEY_ESCAPE)
	Input.use_accumulated_input = false


func _key(action: String, code: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var event := InputEventKey.new()
	event.physical_keycode = code
	InputMap.action_add_event(action, event)


func _bind_player(slot: int, keys: Array) -> void:
	var names := ["left", "right", "down", "up", "punch", "kick", "guard"]
	for i in names.size():
		_key("p%d_%s" % [slot + 1, names[i]], keys[i])
	for pair in [
		["left", JOY_BUTTON_DPAD_LEFT],
		["right", JOY_BUTTON_DPAD_RIGHT],
		["down", JOY_BUTTON_DPAD_DOWN],
		["up", JOY_BUTTON_DPAD_UP],
		["punch", JOY_BUTTON_X],
		["kick", JOY_BUTTON_A],
		["guard", JOY_BUTTON_LEFT_SHOULDER]
	]:
		var button := InputEventJoypadButton.new()
		button.device = slot
		button.button_index = pair[1]
		InputMap.action_add_event("p%d_%s" % [slot + 1, pair[0]], button)
	for pair in [
		["left", JOY_AXIS_LEFT_X, -1.0],
		["right", JOY_AXIS_LEFT_X, 1.0],
		["up", JOY_AXIS_LEFT_Y, -1.0],
		["down", JOY_AXIS_LEFT_Y, 1.0]
	]:
		var axis := InputEventJoypadMotion.new()
		axis.device = slot
		axis.axis = pair[1]
		axis.axis_value = pair[2]
		InputMap.action_add_event("p%d_%s" % [slot + 1, pair[0]], axis)
