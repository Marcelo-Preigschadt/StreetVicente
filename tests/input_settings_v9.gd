extends SceneTree
## Eventos físicos sintéticos verificam o adaptador; não substituem um USB real.
var failures := 0
var source: Node
var settings: Node
var saved_profiles: Dictionary


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL INPUT V9: " + message)


func key_event(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	# _input entrega imediatamente a borda, inclusive tap entre ticks.
	source._input(event)


func run() -> void:
	settings = root.get_node("AppSettings")
	source = load("res://scripts/input/local_input.gd").new()
	root.add_child(source)
	saved_profiles = settings.profiles.duplicate(true)
	settings.profiles = {}
	for pair in [
		[KEY_T, CombatInput.PUNCH, 0],
		[KEY_F, CombatInput.PUNCH, 1],
		[KEY_Y, CombatInput.PUNCH, 2],
		[KEY_V, CombatInput.KICK, 0],
		[KEY_G, CombatInput.KICK, 1],
		[KEY_B, CombatInput.KICK, 2]
	]:
		source.clear()
		key_event(pair[0], true)
		key_event(pair[0], false)
		var result: CombatInput = source.sample(0)
		check((result.pressed & int(pair[1])) != 0, "Tap curto preservado")
		var strength := (
			2 if result.has(CombatInput.STRONG) else 0 if result.has(CombatInput.LIGHT) else 1
		)
		check(strength == pair[2], "Força do botão original preservada")
	for pair in [
		[KEY_R, CombatInput.GUARD],
		[KEY_H, CombatInput.SPECIAL],
		[KEY_U, CombatInput.UPPERCUT],
		[KEY_Q, CombatInput.SUPER],
		[KEY_Z, CombatInput.DRONE]
	]:
		source.clear()
		key_event(pair[0], true)
		check((source.sample(0).pressed & int(pair[1])) != 0, "Atalho Canvas preservado")
		key_event(pair[0], false)
	# Simula dois dispositivos distintos: não há dependência de índices contíguos.
	var test_devices: Array[int] = [6, 19]
	settings.devices = test_devices
	settings.rebuild()
	# Os atalhos LT do Canvas percorrem o mesmo adaptador do USB remapeável.
	for pair in [
		[JOY_BUTTON_Y, CombatInput.UPPERCUT],
		[JOY_BUTTON_RIGHT_SHOULDER, CombatInput.SUPER],
		[JOY_BUTTON_START, CombatInput.CUSTOM]
	]:
		source.clear()
		var trigger := InputEventJoypadMotion.new()
		trigger.device = 6
		trigger.axis = JOY_AXIS_TRIGGER_LEFT
		trigger.axis_value = 1.0
		Input.parse_input_event(trigger)
		var action := InputEventJoypadButton.new()
		action.device = 6
		action.button_index = pair[0]
		action.pressed = true
		Input.parse_input_event(action)
		source._input(action)
		check((source.sample(0).pressed & int(pair[1])) != 0, "Atalho LT funciona")
		var release := action.duplicate() as InputEventJoypadButton
		release.pressed = false
		Input.parse_input_event(release)
		var neutral_axis := trigger.duplicate() as InputEventJoypadMotion
		neutral_axis.axis_value = 0
		Input.parse_input_event(neutral_axis)
	var swap: Array[String] = settings.bind(6, "punch", {"button": JOY_BUTTON_B})
	check("kick" in swap, "Remapeamento troca conflito")
	check(
		settings.profile(6).bindings.kick.button == JOY_BUTTON_X,
		"Ação deslocada recebe botão anterior"
	)
	check(
		settings.profile(19).bindings.punch.button == JOY_BUTTON_X,
		"Outro dispositivo mantém seu mapa"
	)
	settings.bind(6, "custom", {"button": JOY_BUTTON_Y})
	check(
		settings.profile(6).bindings.special.get("unbound", false),
		"Ação sem associação não ressuscita padrão em conflito"
	)
	settings.set_deadzone(6, 0.5)
	settings.profiles.clear()
	settings.load_profiles()
	check(is_equal_approx(settings.profile(6).deadzone, 0.5), "Zona morta persiste em disco")
	check(settings.profile(6).bindings.punch.button == JOY_BUTTON_B, "Botão persiste em disco")
	for pair in [[6, 0], [19, 1]]:
		source.clear()
		var button := InputEventJoypadButton.new()
		button.device = pair[0]
		button.button_index = JOY_BUTTON_B if pair[1] == 0 else JOY_BUTTON_X
		button.pressed = true
		Input.parse_input_event(button)
		source._input(button)
		check((source.sample(pair[1]).pressed & CombatInput.PUNCH) != 0, "USB recebe slot correto")
		check(
			(source.sample(1 - pair[1]).pressed & CombatInput.PUNCH) == 0,
			"USB não vaza ao outro jogador"
		)
		var released := button.duplicate() as InputEventJoypadButton
		released.pressed = false
		Input.parse_input_event(released)
	var no_devices: Array[int] = [-1, -1]
	settings.devices = no_devices
	settings.profiles = saved_profiles
	settings.save_profiles()
	settings.rebuild()
	source.clear()
	var game: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.choose_menu(0)
	game.controls.open()
	check(game.paused and settings.ui_open, "Configurações pausam combate")
	game.controls.close()
	check(not game.paused and not settings.ui_open, "Fechar restaura pausa anterior")
	game.paused = true
	game.controls.open()
	game.controls.close()
	check(game.paused, "Abrir durante pausa mantém pausa")
	game._controller_changed()
	check(game.paused, "Troca/desconexão pausa luta")
	for node in game.audio.get_children():
		if node is AudioStreamPlayer:
			node.stop()
			node.stream = null
	game.queue_free()
	source.queue_free()
	await process_frame
	await process_frame
	print(
		(
			"INPUT V9: legacy keys, strengths, remap/swap, disk reload, "
			+ "two devices, pause passed; %d failures" % failures
		)
	)
	quit(0 if failures == 0 else 1)
