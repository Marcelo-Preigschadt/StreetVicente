class_name ControllerPanel
extends PanelContainer
## Painel independente do combate: captura física, remapeamento e diagnóstico.
const KEYBOARD_ID := 100000
var game: Node
var slot := 0
var capture := ""
var status: Label
var signal_label: Label
var feedback: Label
var device_list: OptionButton
var player_list: OptionButton
var deadzone: HSlider
var bind_buttons: Dictionary = {}
var last_focus: Control
var was_paused := false


func _ready() -> void:
	position = Vector2(70, 30)
	size = Vector2(1140, 660)
	var style := StyleBoxFlat.new()
	style.bg_color = ArcadeTheme.INK
	style.border_color = ArcadeTheme.BLUE
	style.set_border_width_all(3)
	style.set_content_margin_all(18)
	add_theme_stylebox_override("panel", style)
	add_theme_color_override("font_color", ArcadeTheme.PAPER)
	add_theme_font_size_override("font_size", 18)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 10)
	add_child(rows)
	var title := Label.new()
	title.text = "CONTROLES USB / CONFIGURAÇÕES"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", ArcadeTheme.GOLD)
	rows.add_child(title)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size.y = 48
	rows.add_child(status)
	var selectors := HBoxContainer.new()
	rows.add_child(selectors)
	player_list = OptionButton.new()
	player_list.add_item("Jogador 1", 0)
	player_list.add_item("Jogador 2", 1)
	player_list.item_selected.connect(
		func(value: int) -> void:
			slot = value
			capture = ""
			refresh()
	)
	selectors.add_child(player_list)
	device_list = OptionButton.new()
	device_list.fit_to_longest_item = false
	device_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	device_list.item_selected.connect(_assign)
	selectors.add_child(device_list)
	var zone_label := Label.new()
	zone_label.text = "Zona morta"
	selectors.add_child(zone_label)
	deadzone = HSlider.new()
	deadzone.min_value = 0.15
	deadzone.max_value = 0.65
	deadzone.step = 0.05
	deadzone.custom_minimum_size.x = 150
	deadzone.value_changed.connect(_deadzone)
	selectors.add_child(deadzone)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 7)
	rows.add_child(grid)
	for i in AppSettings.PAD_ACTIONS.size():
		var action: String = AppSettings.PAD_ACTIONS[i]
		var button := Button.new()
		button.custom_minimum_size = Vector2(357, 37)
		button.pressed.connect(_capture.bind(action))
		grid.add_child(button)
		bind_buttons[action] = button
	signal_label = Label.new()
	rows.add_child(signal_label)
	feedback = Label.new()
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback.custom_minimum_size.y = 44
	feedback.add_theme_color_override("font_color", ArcadeTheme.GOLD)
	rows.add_child(feedback)
	var footer := HBoxContainer.new()
	rows.add_child(footer)
	var reset := Button.new()
	reset.text = "Restaurar padrão USB"
	reset.pressed.connect(
		func() -> void:
			if AppSettings.devices[slot] >= 0:
				AppSettings.reset_device(AppSettings.devices[slot])
				feedback.text = "Botões padrão restaurados."
				refresh()
	)
	footer.add_child(reset)
	var close_button := Button.new()
	close_button.text = "Fechar / Esc"
	close_button.pressed.connect(close)
	footer.add_child(close_button)
	AppSettings.controllers_changed.connect(refresh)
	hide()


func open() -> void:
	was_paused = game.paused
	game.paused = true
	game.input_source.clear()
	game._snap_views()
	AppSettings.ui_open = true
	capture = ""
	feedback.text = (
		"Selecione uma ação e pressione o botão ou eixo. Esc cancela. "
		+ "Ajustes salvos neste navegador."
	)
	show()
	refresh()
	player_list.grab_focus()


func close() -> void:
	capture = ""
	hide()
	AppSettings.ui_open = false
	game.input_source.clear()
	game.paused = was_paused


func refresh() -> void:
	if not is_instance_valid(device_list):
		return
	device_list.clear()
	device_list.add_item("Somente teclado", KEYBOARD_ID)
	var connected := Input.get_connected_joypads()
	for device in connected:
		device_list.add_item("USB %d · %s" % [device, AppSettings.device_label(device)], device)
	var device: int = AppSettings.devices[slot]
	device_list.select(maxi(0, device_list.get_item_index(KEYBOARD_ID if device < 0 else device)))
	status.text = (
		"Conecte o controle e pressione um botão para ativá-lo no navegador. "
		+ "F10 abre este painel."
	)
	if device >= 0:
		status.text = (
			"J%d: %s · %s"
			% [
				slot + 1,
				AppSettings.device_label(device),
				(
					"layout reconhecido"
					if Input.is_joy_known(device)
					else "USB genérico: confira os botões abaixo"
				)
			]
		)
	var config: Dictionary = AppSettings.profile(device)
	deadzone.set_value_no_signal(config.deadzone)
	deadzone.editable = device >= 0
	for i in AppSettings.PAD_ACTIONS.size():
		var action: String = AppSettings.PAD_ACTIONS[i]
		bind_buttons[action].text = (
			AppSettings.PAD_LABELS[i] + "  ·  " + binding_label(config.bindings.get(action, {}))
		)
		if not config.bindings.has(action) and action in ["uppercut", "super", "custom"]:
			bind_buttons[action].text = (
				AppSettings.PAD_LABELS[i]
				+ " · "
				+ {"uppercut": "LT + Poder", "super": "LT + Soco forte", "custom": "LT + Pausa"}[action]
			)
		bind_buttons[action].disabled = device < 0


static func binding_label(binding: Dictionary) -> String:
	if binding.has("button"):
		return "Botão %d" % int(binding.button)
	if binding.has("axis"):
		return "Eixo %d %s" % [int(binding.axis), "+" if int(binding.sign) > 0 else "−"]
	return "atribuir"


func _assign(index: int) -> void:
	var device := device_list.get_item_id(index)
	AppSettings.assign_device(slot, -1 if device == KEYBOARD_ID else device)
	game.input_source.clear()
	capture = ""
	refresh()


func _deadzone(value: float) -> void:
	if AppSettings.devices[slot] >= 0:
		AppSettings.set_deadzone(AppSettings.devices[slot], value)
	feedback.text = (
		"Zona morta: %d%%. Analógico abaixo desse valor fica neutro." % roundi(value * 100)
	)


func _capture(action: String) -> void:
	capture = action
	last_focus = bind_buttons[action]
	feedback.text = (
		"Aguardando entrada para %s… solte e pressione um botão ou mova um eixo." % action
	)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		if capture.is_empty():
			close()
		else:
			capture = ""
			feedback.text = "Captura cancelada."
		get_viewport().set_input_as_handled()
		return
	if capture.is_empty():
		return
	# Outro jogador/dispositivo não pode alterar a associação em captura.
	if event.device != AppSettings.devices[slot]:
		return
	var binding := {}
	if event is InputEventJoypadButton and event.pressed:
		binding = {"button": event.button_index}
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.7:
		binding = {"axis": event.axis, "sign": 1 if event.axis_value > 0 else -1}
	if binding.is_empty():
		return
	var swapped: Array[String] = AppSettings.bind(event.device, capture, binding)
	feedback.text = (
		"%s: %s. Salvo.%s"
		% [
			capture,
			binding_label(binding),
			" Associação anterior trocada para evitar conflito." if not swapped.is_empty() else ""
		]
	)
	if not AppSettings.save_error.is_empty():
		feedback.text = AppSettings.save_error
	capture = ""
	game.input_source.clear()
	refresh()
	if is_instance_valid(last_focus):
		last_focus.grab_focus()
	get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if not visible:
		return
	var device: int = AppSettings.devices[slot]
	var pressed: Array[String] = []
	if device >= 0:
		for i in 32:
			if Input.is_joy_button_pressed(device, i):
				pressed.append(str(i))
		signal_label.text = (
			"Entrada ao vivo: botões [%s]   ·   X %.2f / Y %.2f   ·   zona morta %d%%"
			% [
				", ".join(pressed),
				Input.get_joy_axis(device, 0),
				Input.get_joy_axis(device, 1),
				roundi(deadzone.value * 100)
			]
		)
	else:
		signal_label.text = "Nenhum USB atribuído a este jogador. O teclado continua disponível."
