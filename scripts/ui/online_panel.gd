class_name OnlinePanel
extends Control
## Native, keyboard-accessible room browser. The canvas game stays entirely Godot.
var game
var mode := "versus"
var code: LineEdit
var room_list: ItemList
var status_label: Label
var mode_buttons: Array[Button] = []
var actions: Array[Button] = []
var resume_button: Button


func setup(value) -> void:
	game = value
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(1280, 720)
	var theme := Theme.new()
	theme.default_font_size = 20
	theme.set_color("font_color", "Button", ArcadeTheme.PAPER)
	theme.set_color("font_hover_color", "Button", ArcadeTheme.GOLD)
	theme.set_color("font_pressed_color", "Button", ArcadeTheme.INK)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("142442") if state == "normal" else Color("243e64")
		if state == "pressed":
			style.bg_color = ArcadeTheme.BLUE
		style.border_color = ArcadeTheme.BLUE if state in ["hover", "focus"] else Color("385777")
		style.set_border_width_all(2)
		style.set_corner_radius_all(5)
		theme.set_stylebox(state, "Button", style)
	self.theme = theme
	for i in 2:
		var button := _button("VERSUS 1 × 1" if i == 0 else "HISTÓRIA COOPERATIVA",
			Rect2(76 + i * 555, 135, 535, 43), func(): _set_mode("versus" if i == 0 else "story"))
		button.toggle_mode = true
		mode_buttons.append(button)
	actions.append(_button("BUSCAR PARTIDA", Rect2(76, 235, 325, 50), func(): _begin("quick")))
	actions.append(_button("CRIAR SALA", Rect2(76, 300, 325, 50), func(): _begin("create")))
	code = LineEdit.new()
	code.position = Vector2(76, 393)
	code.size = Vector2(325, 49)
	code.placeholder_text = "CÓDIGO DE 8 CARACTERES"
	code.max_length = 12
	code.alignment = HORIZONTAL_ALIGNMENT_CENTER
	code.add_theme_font_size_override("font_size", 22)
	code.text_submitted.connect(func(_text): _begin("join"))
	add_child(code)
	actions.append(_button("ENTRAR COM CÓDIGO", Rect2(76, 455, 325, 50), func(): _begin("join")))
	actions.append(_button("ATUALIZAR SALAS", Rect2(454, 531, 725, 40), func(): game.directory.refresh()))
	room_list = ItemList.new()
	room_list.position = Vector2(454, 234)
	room_list.size = Vector2(725, 280)
	room_list.fixed_icon_size = Vector2(32, 32)
	room_list.add_theme_font_size_override("font_size", 18)
	room_list.add_theme_constant_override("v_separation", 14)
	room_list.item_activated.connect(_join_item)
	add_child(room_list)
	status_label = Label.new()
	status_label.position = Vector2(78, 586)
	status_label.size = Vector2(1100, 55)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_color_override("font_color", ArcadeTheme.GOLD)
	status_label.add_theme_font_size_override("font_size", 19)
	add_child(status_label)
	resume_button = _button("RETOMAR MINHA SALA", Rect2(454, 641, 400, 39),
		func(): game.net_session.resume_ticket(OnlineSession.saved_ticket()))
	_button("VOLTAR", Rect2(973, 641, 206, 39), func(): game.close_online())
	game.directory.changed.connect(_refresh_rooms)
	game.directory.failed.connect(func(message): status_label.text = message)
	_set_mode("versus")
	visible = false


func _button(text: String, rect: Rect2, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.position = rect.position
	button.size = rect.size
	button.pressed.connect(action)
	add_child(button)
	return button


func _set_mode(value: String) -> void:
	mode = value
	if not game.net_session.active():
		game.net_session.status = ""
	for i in 2:
		mode_buttons[i].set_pressed_no_signal((i == 0) == (value == "versus"))
	if game.screen == "online":
		game.directory.start(mode)
	status_label.text = "Crie uma sala, entre pelo código ou escolha uma sala disponível."
	_refresh_rooms()


func _begin(kind: String) -> void:
	code.release_focus()
	game.net_session.begin(kind, mode, code.text)


func _join_item(index: int) -> void:
	if index < 0 or index >= room_list.item_count or room_list.is_item_disabled(index):
		return
	code.text = str(room_list.get_item_metadata(index))
	_begin("join")


func _refresh_rooms() -> void:
	if room_list == null:
		return
	room_list.clear()
	for room in game.directory.rooms:
		var character := LegacyRoster.get_character(room.character)
		var label := "%s    %s    %s" % [room.code, character.display_name,
			"AGUARDANDO JOGADOR" if room.status == "waiting" else "JOGANDO"]
		var index := room_list.add_item(label)
		room_list.set_item_metadata(index, room.code)
		room_list.set_item_disabled(index, room.status != "waiting")
	if room_list.item_count == 0:
		room_list.add_item("Nenhuma sala disponível. Crie uma para começar.")
		room_list.set_item_disabled(0, true)


func _process(_delta: float) -> void:
	visible = game.screen == "online"
	if not visible:
		return
	var busy: bool = game.net_session.active()
	for button in actions:
		button.disabled = busy
	for button in mode_buttons:
		button.disabled = busy
	code.editable = not busy
	resume_button.visible = not busy and not OnlineSession.saved_ticket().is_empty()
	if not game.net_session.status.is_empty():
		status_label.text = game.net_session.status
