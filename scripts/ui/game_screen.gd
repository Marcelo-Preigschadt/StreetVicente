class_name GameScreen
extends Node2D
const MINT := Color("69e6c2")
const GOLD := Color("ffbd63")
var game: Node
var font: Font


func _ready() -> void:
	font = ThemeDB.fallback_font


func _process(_delta: float) -> void:
	queue_redraw()


func text_at(at: Vector2, value: String, size: int = 20, color: Color = Color.WHITE) -> void:
	draw_string(font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func panel(rect: Rect2, color: Color = Color("111e2b")) -> void:
	draw_rect(rect, color)


func _draw() -> void:
	if game == null:
		return
	if game.screen == "menu":
		_menu()
	elif game.screen == "selection":
		_selection()
	elif game.screen == "online":
		_online()
	else:
		_hud()


func _menu() -> void:
	draw_texture_rect(
		LegacyRoster.texture(LegacyRoster.catalog.arena),
		Rect2(0, 0, 1280, 720),
		false,
		Color(0.32, 0.4, 0.43)
	)
	panel(Rect2(35, 35, 660, 650), Color(0.02, 0.04, 0.06, 0.91))
	text_at(Vector2(75, 110), "STREET VICENTE", 56, MINT)
	text_at(Vector2(77, 165), "FIGHTER", 64, GOLD)
	text_at(Vector2(80, 205), "PROFESSORES E ALUNOS / VICENTE DUTRA", 17, Color("a6bbbd"))
	for i in game.MENU.size():
		var rect := Rect2(75, 245 + i * 57, 570, 48)
		panel(rect, Color("284a48") if game.menu_index == i else Color("152329"))
		text_at(
			rect.position + Vector2(18, 32),
			game.MENU[i],
			24,
			MINT if game.menu_index == i else Color.WHITE
		)
	text_at(Vector2(78, 674), "W/S ou setas: navegar    Enter: selecionar    F11: tela cheia", 16)
	text_at(Vector2(78, 626), "F3: demonstração no treino · F4: comparar arte", 16, GOLD)
	PilotArt.load_data()
	var atlas: Dictionary = PilotArt.data.sheets.states
	var pose: Dictionary = atlas.frames[0]
	var r: Array = pose.rect
	var s := float(pose.scale) * 1.3
	draw_texture_rect_region(
		LegacyRoster.texture(atlas.image),
		Rect2(
			960 - float(pose.anchor) * s,
			680 - float(pose.bottom) * s,
			float(r[2]) * s,
			float(r[3]) * s
		),
		Rect2(r[0], r[1], r[2], r[3])
	)


func card_rect(index: int) -> Rect2:
	var ids := LegacyRoster.ids()
	var teachers := 0
	for id in ids:
		if LegacyRoster.get_character(id).legacy.category == "teachers":
			teachers += 1
	if index < teachers:
		return Rect2(64 + index * 129, 250, 116, 135)
	return Rect2(64 + (index - teachers) * 129, 454, 116, 135)


func _selection() -> void:
	panel(Rect2(0, 0, 1280, 720), Color("0b151e"))
	text_at(Vector2(55, 62), "ESCOLHA SEU LUTADOR", 38, MINT)
	text_at(
		Vector2(55, 103),
		"JOGADOR %d  /  %s" % [game.selection_slot + 1, game.mode.to_upper()],
		22,
		GOLD
	)
	text_at(Vector2(64, 233), "PROFESSORES", 18, MINT)
	text_at(Vector2(64, 438), "ALUNOS", 18, GOLD)
	var ids := LegacyRoster.ids()
	for i in ids.size():
		var c := LegacyRoster.get_character(ids[i])
		var box := card_rect(i)
		panel(box, Color("253942"))
		draw_texture_rect(
			LegacyRoster.texture(c.legacy.portrait),
			Rect2(box.position + Vector2(3, 3), Vector2(box.size.x - 6, 100)),
			false
		)
		text_at(
			box.position + Vector2(5, 120),
			c.display_name.replace("Prof. ", "").replace("Prof ", "").replace("Aluno ", ""),
			14
		)
		if i == game.cursor:
			draw_rect(box.grow(3), MINT if game.selection_slot == 0 else GOLD, false, 4)
		if game.selection_slot == 1 and ids[i] == game.selected[0]:
			draw_rect(box, Color(0, 0, 0, 0.7))
	var active := LegacyRoster.get_character(ids[game.cursor])
	text_at(Vector2(64, 155), active.display_name + "  /  " + str(active.legacy.style), 25)
	text_at(Vector2(64, 191), active.legacy.selection_quote, 18, Color("b9ced0"))
	text_at(Vector2(64, 635), "A/D ou setas: escolher    Enter: confirmar    Esc: voltar", 19)
	text_at(
		Vector2(64, 674),
		"13 personagens · Marcelo com nova arte · Demais personagens: arte original",
		15,
		Color("8da9ae")
	)


func _hud() -> void:
	var story_mode: bool = game.screen == "story"
	if not story_mode and game.sim == null:
		return
	var a: FighterModel = game.story.hero if story_mode else game.sim.fighters[0]
	var b: FighterModel = null if story_mode else game.sim.fighters[1]
	panel(Rect2(0, 0, 1280, 112), Color(0.025, 0.045, 0.06, 0.96))
	_draw_player(a, 35, MINT)
	if b != null:
		_draw_player(b, 720, GOLD)
	if story_mode:
		var act: Dictionary = LegacyRoster.catalog.story.acts[mini(game.story.act_index, 3)]
		text_at(Vector2(725, 36), act.place, 25, GOLD)
		text_at(
			Vector2(725, 68),
			"ONDA %d / 4     PONTOS %d" % [mini(game.story.wave_index + 1, 4), game.story.score],
			19
		)
	else:
		text_at(Vector2(605, 54), "%02d" % ceili(game.sim.remaining_ticks / 120.0), 38)
		text_at(Vector2(594, 83), "ROUND %d" % game.sim.round_number, 14, MINT)
		text_at(Vector2(580, 105), "%d    :    %d" % [game.sim.wins[0], game.sim.wins[1]], 17)
	panel(Rect2(0, 664, 1280, 56), Color(0.02, 0.04, 0.05, 0.96))
	text_at(
		Vector2(24, 687),
		(
			"P1 A/D · W pulo · S baixo · F/G golpes · T código · Y ascendente"
			+ " · U enxame · E agarrar · Q drone"
		),
		15,
		MINT
	)
	text_at(
		Vector2(24, 709),
		(
			"Shift forte / Ctrl leve · H defesa · F3 demonstração · F4 comparar arte"
			+ " · F1 caixas · Esc pausa/menu · R reiniciar"
		),
		14,
		Color("b1c5c7")
	)
	if story_mode:
		text_at(
			Vector2(30, 140),
			"W/S: profundidade    Espaço: pular    Destrua objetos para recuperar vida",
			17,
			GOLD
		)
	if game.mode == "training" and not story_mode:
		text_at(
			Vector2(28, 145),
			(
				"ALVO: "
				+ ["JOGADOR 2", "PARADO", "DEFESA ALTA", "DEFESA BAIXA"][game.dummy_mode]
				+ " / F2"
			),
			16,
			GOLD
		)
		if game.demo:
			text_at(Vector2(28, 170), "DEMONSTRAÇÃO / F3 para assumir controle", 16, MINT)
	if a.combo >= 2:
		text_at(Vector2(100, 183), "%d HITS" % a.combo, 32, MINT)
	if b != null and b.combo >= 2:
		text_at(Vector2(1020, 183), "%d HITS" % b.combo, 32, GOLD)
	var message := ""
	if game.paused:
		message = "PAUSA / Enter continuar / Esc menu"
	elif story_mode and game.story.completed:
		message = "NIT RESGATADO! / Enter voltar"
	elif story_mode and game.story.defeated:
		message = "FIM DE JOGO / R tentar novamente / Esc menu"
	elif not story_mode and game.sim.winner >= 0:
		message = (
			"EMPATE"
			if game.sim.winner == 2
			else game.sim.fighters[game.sim.winner].character.display_name + " VENCEU"
		)
		if game.sim.match_over:
			message += " / Enter seleção"
	if not message.is_empty():
		panel(Rect2(0, 285, 1280, 120), Color(0.02, 0.04, 0.06, 0.9))
		text_at(Vector2(160, 354), message, 30, GOLD)


func _draw_player(f: FighterModel, x: int, color: Color) -> void:
	draw_texture_rect(
		LegacyRoster.texture(f.character.legacy.portrait), Rect2(x, 14, 62, 62), false
	)
	text_at(Vector2(x + 75, 35), f.character.display_name, 22, color)
	panel(Rect2(x + 75, 48, 440, 17), Color("273d43"))
	panel(Rect2(x + 77, 50, 436.0 * f.health / f.character.max_health, 13), color)
	panel(Rect2(x + 75, 78, 440, 8), Color("273d43"))
	panel(Rect2(x + 75, 78, 440.0 * f.meter / 100.0, 8), Color("7e9aff"))
	text_at(
		Vector2(x + 75, 105),
		str(f.character.legacy.style) + " / SUPER %d" % f.meter,
		14,
		Color("bfd0d3")
	)


func _online() -> void:
	panel(Rect2(0, 0, 1280, 720), Color("0b151e"))
	text_at(Vector2(70, 90), "ONLINE 1 x 1", 40, MINT)
	text_at(Vector2(70, 160), "ONLINE EM MIGRAÇÃO", 28, GOLD)
	text_at(Vector2(70, 220), "O combate local está disponível no menu.", 24)
	text_at(
		Vector2(70, 270), "As sessões online serão liberadas após os testes de rede e rollback.", 21
	)
	text_at(Vector2(70, 340), "Esc: voltar", 24, MINT)
