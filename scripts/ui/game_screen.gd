class_name GameScreen
extends Node2D
## Game-native arcade screens. All portraits, voices and identity come from roster.
const BLUE := ArcadeTheme.BLUE
const RED := ArcadeTheme.RED
const GOLD := ArcadeTheme.GOLD
const PAPER := ArcadeTheme.PAPER
const INK := ArcadeTheme.INK
const DESCRIPTIONS := [
	"Pratique golpes, poderes e combos sem limite de tempo.",
	"12 adversários, rota pela escola, bônus e recorde salvo.",
	"Dois jogadores, um computador. Escolham seus lutadores.",
	"Atravesse a escola e liberte o servidor central.",
	"Escolha a dupla e configure o adversário de treino.",
	"Versus e História cooperativa. Crie uma sala e convide outra pessoa."
]
var game: Node
var font: Font
var clock: float = 0
var last_screen: String = ""
var entrance: float = 0
var preview_models: Dictionary = {}
var damage_trails: Dictionary = {}


func _ready() -> void:
	font = ThemeDB.fallback_font
	ArcadeTheme.load_data()


func _process(delta: float) -> void:
	clock += delta
	if game != null and game.screen != last_screen:
		last_screen = game.screen
		entrance = 1.0
	entrance = maxf(0, entrance - delta * 3.8)
	for trail in damage_trails.values():
		trail.wait = maxf(0, float(trail.wait) - delta)
		if trail.wait <= 0:
			trail.value = move_toward(float(trail.value), float(trail.hp), delta * 1.4)
	queue_redraw()


func text_at(at: Vector2, value: String, size: int = 20, color: Color = Color.WHITE) -> void:
	draw_string(font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func centered(at: Vector2, value: String, size: int, color: Color) -> void:
	text_at(
		at - Vector2(font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x / 2, 0),
		value,
		size,
		color
	)


func panel(rect: Rect2, color: Color = INK) -> void:
	draw_rect(rect, color)


func wrapped(at: Vector2, value: String, width: float, size: int, color: Color) -> void:
	var line := ""
	var y := at.y
	for word in value.split(" "):
		var next := word if line.is_empty() else line + " " + word
		if (
			not line.is_empty()
			and font.get_string_size(next, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width
		):
			text_at(Vector2(at.x, y), line, size, color)
			y += size + 5
			line = word
		else:
			line = next
	text_at(Vector2(at.x, y), line, size, color)


func _draw() -> void:
	if game == null:
		return
	if game.screen == "menu":
		_menu()
	elif game.screen == "selection":
		_selection()
	elif game.screen == "stage_selection":
		_stage_selection()
	elif game.screen in ["arcade_route", "arcade_result"]:
		_arcade_summary()
	elif game.screen in ["story_dialog", "story_resume"]:
		_story_dialog()
	elif game.screen == "online":
		_online()
	else:
		_hud()
	_utilities()
	if entrance > 0:
		# Short edge wipe never obscures hitboxes or delays input/simulation.
		ArcadeTheme.plate(
			self,
			Rect2(1280 - entrance * 170, 0, entrance * 220, 720),
			Color(BLUE, entrance * 0.28),
			60
		)


func menu_rect(index: int) -> Rect2:
	return Rect2(74, 264 + index * 60, 532, 49)


func _menu() -> void:
	ArcadeTheme.backdrop(self, clock)
	draw_texture_rect_region(
		LegacyRoster.texture(ArenaCatalog.get_arena(game.stage_id).image),
		Rect2(620, 0, 660, 720),
		Rect2(310, 0, 660, 720),
		Color(0.4, 0.4, 0.6, 0.3)
	)
	ArcadeTheme.plate(self, Rect2(660, 0, 620, 720), Color(0.12, 0.23, 0.44, 0.62), 180)
	for i in 5:
		draw_line(Vector2(800 + i * 95, 0), Vector2(480 + i * 95, 720), Color(BLUE, 0.12), 3, true)
	_preview("rafael", Vector2(1155, 666), 1.12, -1, 0.9)
	_preview("marcelo", Vector2(875, 678), 1.58, 1)
	ArcadeTheme.title(self, Vector2(72, 108), "STREET VICENTE", 71, PAPER, 6)
	ArcadeTheme.title(self, Vector2(69, 205), "FIGHTER", 103, GOLD, 7)
	ArcadeTheme.plate(self, Rect2(78, 222, 420, 24), RED, 8)
	text_at(Vector2(95, 240), "PROFESSORES + ALUNOS / VICENTE DUTRA", 15, INK)
	for i in game.MENU.size():
		var active: bool = game.menu_index == i
		var rect := menu_rect(i)
		var offset := 9.0 + sin(clock * 8) * 2 if active else 0.0
		rect.position.x += offset
		ArcadeTheme.plate(self, rect.grow(2), INK, 12)
		ArcadeTheme.plate(self, rect, GOLD if active else Color("202c4a"), 12)
		if active:
			draw_line(
				rect.position + Vector2(14, 3),
				rect.position + Vector2(rect.size.x - 9, 3),
				PAPER,
				2,
				true
			)
		text_at(rect.position + Vector2(20, 34), "%02d" % (i + 1), 20, INK if active else BLUE)
		text_at(rect.position + Vector2(65, 33), game.MENU[i], 23, INK if active else PAPER)
		if active:
			text_at(rect.position + Vector2(490, 33), ">", 26, INK)
	ArcadeTheme.plate(self, Rect2(1000, 32, 280, 36), BLUE, 16)
	text_at(Vector2(1032, 57), "13 LUTADORES / 2D V11", 18, INK)
	text_at(Vector2(1000, 92), "RECORDE  %08d" % game.progress.record, 15, GOLD)
	wrapped(Vector2(88, 648), DESCRIPTIONS[game.menu_index], 540, 16, PAPER)
	_footer("W/S NAVEGAR     ENTER CONFIRMAR")


func card_rect(index: int) -> Rect2:
	var teachers := 0
	for id in LegacyRoster.ids():
		if LegacyRoster.get_character(id).legacy.category == "teachers":
			teachers += 1
	if index < teachers:
		var row: int = index / 5
		var columns := mini(5, teachers - row * 5)
		var start := 640.0 - (columns * 100 - 8) / 2.0
		return Rect2(start + (index % 5) * 100, 203 + row * 118, 92, 106)
	var students := LegacyRoster.ids().size() - teachers
	return Rect2(640.0 - (students * 108 - 6) / 2.0 + (index - teachers) * 108, 495, 102, 106)


func vertical_neighbor(index: int, direction: int) -> int:
	var center := card_rect(index).get_center()
	var best := -1
	var cost := 1.0e20
	for i in LegacyRoster.ids().size():
		var target := card_rect(i).get_center()
		if (target.y - center.y) * direction <= 0:
			continue
		var score := absf(target.x - center.x) + absf(target.y - center.y) * 0.8
		if score < cost:
			cost = score
			best = i
	return index if best < 0 else best


func _selection() -> void:
	ArcadeTheme.backdrop(self, clock)
	ArcadeTheme.plate(self, Rect2(0, 118, 328, 568), Color(0.12, 0.4, 0.67, 0.45), 48)
	ArcadeTheme.plate(self, Rect2(952, 118, 328, 568), Color(0.64, 0.14, 0.28, 0.35), -48)
	ArcadeTheme.title(self, Vector2(338, 70), "ESCOLHA SEU LUTADOR", 41, PAPER)
	centered(
		Vector2(640, 110),
		"JOGADOR %d  /  %s" % [game.selection_slot + 1, game.mode.to_upper()],
		20,
		BLUE if game.selection_slot == 0 else RED
	)
	var ids := LegacyRoster.ids()
	var left: String = ids[game.cursor] if game.selection_slot == 0 else game.selected[0]
	var right: String = ids[game.cursor] if game.selection_slot == 1 else game.selected[1]
	if right == left and game.selection_slot == 0:
		right = "rafael" if left != "rafael" else "marcelo"
	_preview(left, Vector2(180, 564), 1.02, 1)
	_preview(right, Vector2(1100, 564), 1.02, -1)
	_nameplate(left, Vector2(30, 602), BLUE, "1P")
	_nameplate(right, Vector2(963, 602), RED, "2P")
	centered(Vector2(640, 178), "PROFESSORES", 17, BLUE)
	centered(Vector2(640, 475), "ALUNOS", 17, GOLD)
	for i in ids.size():
		var c := LegacyRoster.get_character(ids[i])
		var box := card_rect(i)
		var active: bool = i == game.cursor
		var locked: bool = ids[i] == game.selected[1 - game.selection_slot] if game.online_active() else game.selection_slot == 1 and ids[i] == game.selected[0]
		panel(box.grow(3), INK)
		_portrait(c, Rect2(box.position + Vector2(2, 2), Vector2(box.size.x - 4, 78)))
		panel(Rect2(box.position + Vector2(0, 80), Vector2(box.size.x, 26)), Color("17233e"))
		centered(box.position + Vector2(box.size.x / 2, 98), _short_name(c), 13, PAPER)
		if locked:
			panel(box, Color(0.02, 0.04, 0.15, 0.48))
			ArcadeTheme.plate(self, Rect2(box.position + Vector2(0, 0), Vector2(37, 24)), BLUE, 5)
			text_at(box.position + Vector2(5, 18), "1P", 15, INK)
		if active:
			var color: Color = BLUE if game.selection_slot == 0 else RED
			draw_rect(box.grow(5), Color(color, 0.18), false, 8)
			draw_rect(box.grow(3), color, false, 3)
			ArcadeTheme.plate(
				self, Rect2(box.position + Vector2(-3, -19), Vector2(45, 23)), color, 5
			)
			text_at(box.position + Vector2(3, -2), "%dP" % (game.selection_slot + 1), 15, INK)
	centered(Vector2(640, 647), "13 LUTADORES • CADA UM COM SEU ESTILO", 14, Color("a8bad9"))
	if game.online_active():
		var net: OnlineSession = game.net_session
		var label := "SALA %s · 1P %s / 2P %s" % [net.room,
			"PRONTO" if net.confirmed[0] else "ESCOLHENDO", "PRONTO" if net.confirmed[1] else "ESCOLHENDO"]
		centered(Vector2(640, 668), label, 15, GOLD)
		_footer("A/D · W/S ESCOLHER     ENTER PRONTO / CANCELAR     F5 CENÁRIO: " + net.stage.to_upper() + "     ESC SAIR")
	else:
		_footer("A/D ESCOLHER     W/S LINHA     ENTER CONFIRMAR     ESC VOLTAR")


func _short_name(c: CharacterData) -> String:
	return c.display_name.replace("Prof. ", "").replace("Prof ", "").replace("Aluno ", "")


func _nameplate(id: String, at: Vector2, color: Color, tag: String) -> void:
	var c := LegacyRoster.get_character(id)
	ArcadeTheme.plate(self, Rect2(at + Vector2(0, -27), Vector2(285, 36)), color, 12)
	ArcadeTheme.title(self, at + Vector2(12, 0), _short_name(c).to_upper(), 27, PAPER, 2)
	text_at(at + Vector2(250, -2), tag, 16, INK)
	wrapped(at + Vector2(6, 32), str(c.legacy.style), 280, 16, color)
	wrapped(at + Vector2(6, 56), str(c.legacy.selection_quote), 276, 14, PAPER)


func _portrait(c: CharacterData, rect: Rect2) -> void:
	var texture := LegacyRoster.texture(c.legacy.portrait)
	var side := minf(texture.get_width(), texture.get_height())
	var source := Rect2(
		(texture.get_width() - side) / 2, (texture.get_height() - side) / 2, side, side
	)
	# Crop square portraits into a consistent wide headshot without stretching faces.
	var h := side * rect.size.y / rect.size.x
	source.position.y += (side - h) * 0.32
	source.size.y = h
	draw_texture_rect_region(texture, rect, source)


func _preview(
	id: String, root: Vector2, scale_factor: float, facing: int, alpha: float = 1.0
) -> void:
	if not preview_models.has(id):
		preview_models[id] = FighterModel.new(LegacyRoster.get_character(id), 0, 0)
	var f: FighterModel = preview_models[id]
	f.state_tick = int(clock * 120)
	var pose := CharacterArt.frame(f)
	var sheet: Dictionary = pose.sheet
	var frame: Dictionary = pose.frame
	var r: Array = frame.rect
	var k := float(frame.get("scale", sheet.scale)) * scale_factor * CharacterMetrics.factor(id)
	draw_set_transform(
		root, 0, Vector2(facing * float(f.character.legacy.get("visualWidth", 1.0)), 1)
	)
	draw_texture_rect_region(
		LegacyRoster.texture(sheet.image),
		Rect2(
			(float(frame.get("x", 0)) - float(frame.anchor)) * k,
			(float(frame.get("y", 0)) - float(frame.bottom)) * k,
			float(r[2]) * k,
			float(r[3]) * k
		),
		Rect2(r[0], r[1], r[2], r[3]),
		Color(1, 1, 1, alpha)
	)
	draw_set_transform(Vector2.ZERO)


func _footer(value: String) -> void:
	panel(Rect2(0, 686, 1280, 34), INK)
	text_at(Vector2(20, 709), value, 12, PAPER)


func _hud() -> void:
	var story_mode: bool = game.screen == "story"
	if not story_mode and game.sim == null:
		return
	if not story_mode and not game.paused:
		_round_call()
	var a: FighterModel = game.story.hero if story_mode else game.sim.fighters[0]
	var b: FighterModel = game.story.players()[1] if story_mode and game.story.players().size() == 2 else null if story_mode else game.sim.fighters[1]
	_draw_player(a, false, BLUE)
	if b != null:
		_draw_player(b, true, RED)
	if b != null and not story_mode:
		ArcadeTheme.plate(self, Rect2(579, 8, 122, 86), INK, 12)
		centered(Vector2(640, 57), "%02d" % ceili(game.sim.remaining_ticks / 120.0), 40, PAPER)
		centered(Vector2(640, 79), "ROUND %d" % game.sim.round_number, 12, GOLD)
		for side in 2:
			for win in 2:
				draw_circle(
					Vector2(550 + side * 160 + win * (14 if side == 1 else -14), 86),
					4,
					GOLD if game.sim.wins[side] > win else Color("3c4256")
				)
	elif b == null:
		var act: Dictionary = LegacyRoster.catalog.story.acts[mini(game.story.act_index, 3)]
		ArcadeTheme.plate(self, Rect2(720, 15, 560, 65), INK, 15)
		text_at(Vector2(760, 40), str(act.place), 22, GOLD)
		text_at(
			Vector2(760, 65),
			"ONDA %d / 4     PONTOS %d" % [mini(game.story.wave_index + 1, 4), game.story.score],
			16,
			PAPER
		)
	_footer("A/D MOVER · W/S PROFUNDIDADE · ESPAÇO SALTAR · T/F/Y SOCOS · V/G/B CHUTES · R DEFESA · E OBJETO · ESC PAUSA"
		if story_mode else "A/D MOVER · W PULAR · T/F/Y SOCOS · V/G/B CHUTES · R DEFESA · H PODER · U GANCHO · Q ESPECIAL · ESC PAUSA")
	if game.mode == "training" and not story_mode:
		ArcadeTheme.plate(self, Rect2(16, 108, 625, 27), Color(INK, 0.85), 7)
		text_at(
			Vector2(28, 128),
			(
				"TREINO  /  ALVO: "
				+ ["JOGADOR 2", "PARADO", "DEFESA ALTA", "DEFESA BAIXA"][game.dummy_mode]
				+ "  /  F2 ALVO · F8 REINICIAR · F3 DEMO"
			),
			13,
			GOLD
		)
		if game.demo:
			text_at(Vector2(28, 151), "DEMONSTRAÇÃO / F3 PARA ASSUMIR", 13, BLUE)
	if game.arcade != null and not story_mode:
		ArcadeTheme.plate(self, Rect2(22, 106, 1236, 30), Color(INK, 0.88), 8)
		text_at(Vector2(36, 128), "PONTOS  %08d" % game.arcade.score, 17, GOLD)
		centered(Vector2(640, 128), "CIRCUITO  %02d / 12" % (game.arcade.index + 1), 15, PAPER)
		text_at(Vector2(970, 128), "RECORDE  %08d" % game.progress.record, 15, BLUE)
	if story_mode and not game.online_active():
		ArcadeTheme.plate(self, Rect2(16, 105, 694, 30), Color(INK, .9), 7)
		text_at(
			Vector2(28, 125),
			(
				"W/S PROFUNDIDADE · ESPAÇO SALTAR · E PEGAR/ARREMESSAR · TURNO %02d:%02d"
				% [
					int(game.story.remaining_ticks / 7200),
					int(game.story.remaining_ticks / 120) % 60
				]
			),
			13,
			GOLD
		)
	if story_mode:
		var local_slot: int = game.net_session.slot if game.online_active() else 0
		var actor: FighterModel = game.story.players()[local_slot]
		var gear: StoryObjects = game.story.object_sets()[local_slot]
		var prompt := ""
		if not gear.carry.is_empty():
			prompt = "LEVANTANDO…" if gear.pickup_ticks > 0 and not gear.pending_throw else "F / E  ·  ARREMESSAR"
		elif actor.grounded() and FighterState.actionable(actor.state):
			var closest := 1 << 60
			for prop in game.story.props:
				if prop.get("used", false) or prop.hp <= 0 or prop.kind not in ["table", "chair", "shelf"]:
					continue
				if absi(int(prop.lane) - actor.ground_y) > 42 * FighterModel.SCALE or absi(int(prop.x) - actor.x) >= gear.bounds(prop).size.x / 2 + 50 * FighterModel.SCALE:
					continue
				var score := maxi(0, absi(int(prop.x) - actor.x) - gear.bounds(prop).size.x / 2) + 3 * absi(int(prop.lane) - actor.ground_y)
				if score < closest:
					closest = score
					prompt = "E  ·  LEVANTAR MESA" if prop.kind == "table" else "E  ·  PEGAR CADEIRA" if prop.kind == "chair" else "E  ·  DERRUBAR ESTANTE"
		if not prompt.is_empty():
			ArcadeTheme.plate(self, Rect2(451, 643, 378, 30), Color(INK, .9), 8)
			centered(Vector2(640, 665), prompt, 16, GOLD)
	for f in [a, b]:
		if f != null and f.campaign_costs:
			text_at(Vector2(40 if f == a else 870, 633), "H / U  25  ·  Z  40  ·  Q  100  /  ACERTE INIMIGOS", 12, BLUE if f == a else RED)
		if f != null and f.custom_ticks > 0:
			text_at(Vector2(52 if f == a else 987, 602), "CUSTOM  %d/8" % f.custom_moves, 21, GOLD)
		if f != null and f.state == FighterState.Id.DIZZY:
			text_at(Vector2(52 if f == a else 970, 247), "MEXA / APERTE PARA RECUPERAR", 14, GOLD)
		if f != null and f.combo >= 2:
			var x := 54 if f == a else 1025
			ArcadeTheme.title(
				self, Vector2(x, 204), str(f.combo), 66, GOLD if f.combo >= 5 else PAPER
			)
			ArcadeTheme.title(self, Vector2(x + 70, 202), "HITS!", 26, BLUE if f == a else RED, 3)
	if game.online_active():
		ArcadeTheme.plate(self, Rect2(390, 90, 560, 24), Color(INK, .9), 7)
		text_at(Vector2(400, 105), "SALA " + game.net_session.room + " · VOCÊ: " + str(game.net_session.slot + 1) + "P · " + str(game.net_session.rtt) + " ms", 14, BLUE)
		if story_mode:
			ArcadeTheme.plate(self, Rect2(16, 108, 900, 46), Color(INK, .9), 7)
			text_at(Vector2(28, 125), "W/S PROFUNDIDADE · ESPAÇO SALTAR · E PEGAR/ARREMESSAR · TURNO %02d:%02d" % [int(game.story.remaining_ticks / 7200), int(game.story.remaining_ticks / 120) % 60], 13, GOLD)
			text_at(Vector2(28, 147), "ATO %d · PONTOS %08d" % [mini(game.story.act_index + 1, 4), game.story.score], 14, PAPER)
			text_at(Vector2(400, 147), "COOP · ONDA " + str(mini(game.story.wave_index + 1, 4)) + "/4 · E: AJUDAR PARCEIRO CAÍDO", 13, GOLD)
	var message := ""
	if game.online_active() and game.net_session.phase not in ["playing", "paused"]:
		message = game.net_session.status
	elif game.online_active() and game.net_session.phase == "playing" and game.paused:
		message = "AGUARDANDO A REDE…"
	elif game.paused:
		message = "PAUSA  /  ENTER CONTINUAR  /  ESC MENU"
	elif story_mode and game.story.completed:
		message = "NIT RESGATADO! / ENTER VOLTAR"
	elif story_mode and game.story.defeated:
		message = "FIM DE JOGO / ENTER SELEÇÃO" if game.online_active() else "FIM DE JOGO / F8 REPETIR ATO"
	elif not story_mode and game.sim.winner >= 0 and game.sim.round_wait >= 90:
		message = (
			"EMPATE"
			if game.sim.winner == 2
			else game.sim.fighters[game.sim.winner].character.display_name.to_upper() + " VENCEU"
		)
		if game.sim.match_over:
			message += (
				" / ENTER ROTA"
				if game.arcade != null and game.arcade.state == "route"
				else " / ENTER CONTINUAR" if game.arcade != null else " / ENTER SELEÇÃO"
			)
	if not message.is_empty():
		var inspect: bool = game.paused and (game.mode == "training" or game.qa)
		if inspect:
			panel(Rect2(0, 682, 1280, 38), INK)
			centered(Vector2(640, 708), message, 22, GOLD)
		else:
			panel(Rect2(0, 281, 1280, 126), Color(INK, 0.92))
			ArcadeTheme.title(self, Vector2(120, 358), message, 36, GOLD)


func _round_call() -> void:
	var sim: FightSimulation = game.sim
	var label := ""
	var color := GOLD
	var slide := 0.0
	if sim.intro_ticks > 0:
		var fight := sim.intro_ticks <= FightSimulation.FIGHT_TICKS
		label = "FIGHT!" if fight else "ROUND %d" % sim.round_number
		var elapsed := (
			(FightSimulation.FIGHT_TICKS if fight else FightSimulation.INTRO_TICKS)
			- sim.intro_ticks
		)
		slide = pow(maxf(0, 1.0 - elapsed / 18.0), 3) * (680 if fight else -680)
		color = PAPER if fight else GOLD
	elif sim.winner >= 0 and sim.round_wait < 90:
		label = "TIME OVER" if sim.remaining_ticks <= 0 else "K.O."
		color = RED
	if label.is_empty():
		return
	var width := ArcadeTheme.title_font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 94).x
	ArcadeTheme.title(self, Vector2(640 - width / 2 + slide, 352), label, 94, color, 8)
	draw_line(Vector2(436 + slide, 375), Vector2(844 + slide, 375), BLUE, 4, true)
	if sim.winner >= 0 and sim.winner != 2 and sim.round_wait >= 50:
		if sim.fighters[sim.winner].health == sim.fighters[sim.winner].character.max_health:
			centered(Vector2(640, 414), "PERFECT", 28, GOLD)


func _draw_player(f: FighterModel, right: bool, color: Color) -> void:
	var base := 718.0 if right else 24.0
	var x := base if right else base + 88
	var id := f.character.id + str(f.slot)
	var hp := float(f.health) / f.character.max_health
	var memory: Dictionary = damage_trails.get(id, {"value": hp, "hp": hp, "wait": 0.0})
	if hp < float(memory.hp):
		memory.wait = 0.22
	if hp > float(memory.hp):
		memory.value = hp
	memory.hp = hp
	damage_trails[id] = memory
	var trail := float(memory.value)
	ArcadeTheme.plate(self, Rect2(base - 10, 11, 548, 86), Color(INK, 0.92), 15)
	_portrait(f.character, Rect2(1190 if right else 24, 15, 66, 61))
	text_at(Vector2(x, 32), f.character.display_name.to_upper(), 18, PAPER)
	var rect := Rect2(x, 43, 430, 24)
	panel(rect.grow(2), PAPER)
	panel(rect, Color("3c2541"))
	var trail_rect := Rect2(rect.position, Vector2(430 * trail, 24))
	var hp_rect := Rect2(rect.position, Vector2(430 * hp, 24))
	if right:
		trail_rect.position.x += 430 * (1 - trail)
		hp_rect.position.x += 430 * (1 - hp)
	panel(trail_rect, RED)
	panel(hp_rect, GOLD)
	panel(Rect2(hp_rect.position, Vector2(hp_rect.size.x, 5)), PAPER)
	for i in 9:
		draw_line(Vector2(x + (i + 1) * 43, 44), Vector2(x + (i + 1) * 43, 66), Color(INK, 0.22), 1)
	# Super meters sit on the bottom corners, leaving the stage open.
	var meter_x := 855.0 if right else 35.0
	ArcadeTheme.plate(self, Rect2(meter_x - 7, 638, 402, 39), INK, 12)
	var fill := 288.0 * f.meter / 100
	panel(Rect2(meter_x + 87, 651, 288, 13), Color("293050"))
	panel(
		Rect2(meter_x + 87 + (288 - fill if right else 0), 651, fill, 13),
		color if f.meter < 100 else GOLD
	)
	text_at(Vector2(meter_x + 4, 664), "ENERGIA" if f.campaign_costs else "SUPER", 16 if f.campaign_costs else 19, color if f.meter < 100 else GOLD)
	if f.meter == 100:
		text_at(Vector2(meter_x + 193, 663), "MAX", 12, INK)
	text_at(Vector2(x, 88), str(f.character.legacy.style).to_upper(), 12, color)


func _online() -> void:
	ArcadeTheme.backdrop(self, clock)
	ArcadeTheme.title(self, Vector2(75, 88), "ONLINE VICENTE", 55, PAPER)
	text_at(Vector2(78, 118), "DUAS PESSOAS. OS MESMOS LUTADORES. UMA PARTIDA SINCRONIZADA.", 17, BLUE)
	ArcadeTheme.plate(self, Rect2(55, 198, 367, 363), Color(INK, .8), 12)
	text_at(Vector2(78, 220), "JOGAR ONLINE", 17, GOLD)
	text_at(Vector2(455, 220), "SALAS · ENTER OU DOIS CLIQUES PARA ENTRAR", 17, GOLD)
	_footer("ESC VOLTAR")


func _arcade_summary() -> void:
	ArcadeTheme.backdrop(self, clock)
	var run: ArcadeRun = game.arcade
	if run == null:
		return
	ArcadeTheme.title(
		self,
		Vector2(55, 82),
		(
			"ROTA VICENTE"
			if run.state == "route"
			else "CIRCUITO CONCLUÍDO!" if run.state == "complete" else "CONTINUAR?"
		),
		56,
		GOLD
	)
	text_at(
		Vector2(58, 122), "PONTOS  %08d      RECORDE  %08d" % [run.score, run.record], 24, PAPER
	)
	if run.state == "route":
		# Serpentina em três corredores; o crachá percorre os setores vencidos.
		var positions: Array[Vector2] = []
		for i in 12:
			var row: int = i / 4
			var col := i % 4 if row % 2 == 0 else 3 - i % 4
			positions.append(Vector2(148 + col * 248, 205 + row * 143))
		for i in 11:
			draw_line(positions[i], positions[i + 1], Color(BLUE, 0.45), 5, true)
		for i in 12:
			var point := positions[i]
			var active: bool = i == run.index + 1
			ArcadeTheme.plate(
				self, Rect2(point - Vector2(85, 39), Vector2(170, 93)), GOLD if active else INK, 10
			)
			var character := LegacyRoster.get_character(run.opponents[i])
			draw_texture_rect(
				LegacyRoster.texture(character.legacy.portrait),
				Rect2(point - Vector2(25, 32), Vector2(50, 50)),
				false,
				Color(1, 1, 1, 0.4 if i <= run.index else 1)
			)
			centered(point + Vector2(0, 37), ArcadeRun.STOPS[i], 12, INK if active else PAPER)
			if i <= run.index:
				centered(point + Vector2(0, 4), "VENCEU", 16, GOLD)
		var t := clampf(game.route_ticks / float(ArcadeRun.ROUTE_TICKS), 0, 1)
		var badge: Vector2 = positions[run.index].lerp(
			positions[run.index + 1], t * t * (3 - 2 * t)
		)
		draw_circle(badge + Vector2(0, -57), 20, GOLD)
		centered(badge + Vector2(0, -51), "1P", 17, INK)
		text_at(Vector2(1040, 225), "PRÓXIMO", 18, BLUE)
		wrapped(
			Vector2(1040, 263),
			LegacyRoster.get_character(run.opponents[run.index + 1]).display_name,
			200,
			24,
			PAPER
		)
		_preview(run.player_id, Vector2(1135, 592), 0.8, -1)
	else:
		_preview(run.player_id, Vector2(1015, 613), 1.35, -1)
		text_at(
			Vector2(70, 180),
			"VITÓRIAS %d / 12     PERFECTS %d" % [run.wins, run.perfects],
			23,
			BLUE
		)
		var labels := {
			"combat": "Dano",
			"combo": "Combos",
			"round": "Rounds",
			"life": "Vida",
			"time": "Tempo",
			"perfect": "Perfect",
			"super": "Super KO",
			"match": "Confronto",
			"clear": "Circuito"
		}
		var row := 0
		for kind in labels:
			text_at(Vector2(80, 227 + row * 39), str(labels[kind]), 20, PAPER)
			text_at(Vector2(438, 227 + row * 39), "+ %06d" % run.breakdown[kind], 20, GOLD)
			row += 1
		if run.state == "defeated":
			text_at(Vector2(70, 630), "CONTINUAR ZERA OS PONTOS E MANTÉM O RECORDE.", 17, PAPER)
	ArcadeTheme.plate(self, action_rect(), GOLD, 12)
	centered(
		action_rect().position + Vector2(140, 30),
		(
			"PRÓXIMA LUTA"
			if run.state == "route"
			else "CONTINUAR" if run.state == "defeated" else "MENU"
		),
		20,
		INK
	)

	_footer(
		(
			"ENTER / START PRÓXIMA LUTA   ·   ESC MENU"
			if run.state == "route"
			else "ENTER / START CONTINUAR   ·   ESC MENU"
		)
	)


func _story_dialog() -> void:
	ArcadeTheme.backdrop(self, clock)
	if game.screen == "story_resume":
		var saved: Dictionary = game.progress.checkpoint
		var chapter: Dictionary = LegacyRoster.catalog.story.acts[int(saved.act)]
		ArcadeTheme.title(self, Vector2(80, 125), "RETOMAR O RESGATE", 63, GOLD)
		wrapped(Vector2(85, 210), chapter.title, 720, 31, PAPER)
		text_at(
			Vector2(85, 285),
			(
				"ATO %d   ·   %s"
				% [int(saved.act) + 1, LegacyRoster.get_character(saved.character).display_name]
			),
			24,
			BLUE
		)
		text_at(Vector2(85, 345), "Progresso salvo neste navegador.", 22, PAPER)
		_preview(saved.character, Vector2(1010, 635), 1.4, -1)
		_footer("ENTER / START RETOMAR   ·   N NOVA CAMPANHA   ·   ESC MENU")
		return
	var chapter: Dictionary = game.story.act()
	draw_texture_rect(
		LegacyRoster.texture(chapter.background),
		Rect2(0, 0, 1280, 720),
		false,
		Color(0.4, 0.4, 0.55, 0.5)
	)
	ArcadeTheme.title(self, Vector2(65, 102), "ATO %d" % (game.story.act_index + 1), 57, GOLD)
	wrapped(Vector2(67, 155), chapter.title, 900, 34, PAPER)
	_preview(chapter.speaker, Vector2(1080, 656), 1.4, -1)
	ArcadeTheme.plate(self, Rect2(55, 255, 790, 346), Color(INK, 0.95), 18)
	text_at(
		Vector2(83, 298),
		LegacyRoster.get_character(chapter.speaker).display_name.to_upper(),
		23,
		BLUE
	)
	wrapped(Vector2(83, 344), chapter.quote, 710, 24, PAPER)
	wrapped(Vector2(83, 460), chapter.action, 705, 18, PAPER)
	wrapped(Vector2(83, 542), "OBJETIVO: " + str(chapter.objective), 705, 18, GOLD)
	_footer("ENTER / START INICIAR ATO   ·   ESC MENU   ·   CHECKPOINT AUTOMÁTICO")


func action_rect() -> Rect2:
	return Rect2(930, 624, 280, 45)


func fullscreen_rect() -> Rect2:
	return Rect2(1050, 675, 205, 35)


func controls_rect() -> Rect2:
	return Rect2(833, 675, 205, 35)


func _utilities() -> void:
	ArcadeTheme.plate(self, audio_rect(), INK, 7)
	centered(
		audio_rect().position + Vector2(75, 20),
		"ÁUDIO " + ("ON" if game.stage_audio.enabled else "OFF") + " · F9",
		13,
		GOLD
	)
	if game.screen in ["menu", "fight"]:
		ArcadeTheme.plate(self, stage_rect(), Color(INK, .85), 7)
		centered(
			stage_rect().position + Vector2(177, 19),
			ArenaCatalog.get_arena(game.stage_id).name + ("" if game.online_active() else " · F5"),
			12,
			BLUE
		)
	for item in [[controls_rect(), "CONTROLE USB · F10"], [fullscreen_rect(), "TELA CHEIA · F11"]]:
		ArcadeTheme.plate(self, item[0], Color("202c4a"), 8)
		centered(item[0].position + Vector2(102, 23), item[1], 15, GOLD)


func arena_card_rect(index: int) -> Rect2:
	return Rect2(42 + index * 309, 385, 285, 188)


func _stage_selection() -> void:
	panel(Rect2(0, 0, 1280, 720), Color(INK, .65))
	ArcadeTheme.title(self, Vector2(52, 74), "ESCOLHA A ARENA", 48, PAPER)
	var arena := ArenaCatalog.get_arena(ArenaCatalog.IDS[game.stage_cursor])
	panel(Rect2(43, 106, 738, 250), INK)
	_arena_preview(arena.image, Rect2(46, 109, 732, 244))
	ArcadeTheme.plate(self, Rect2(808, 144, 430, 49), GOLD, 14)
	text_at(Vector2(826, 176), arena.name, 20, INK)
	wrapped(Vector2(817, 222), arena.place, 396, 22, PAPER)
	text_at(Vector2(817, 272), "AMBIENTE: " + arena.track, 17, BLUE)
	wrapped(Vector2(817, 304), game.stage_audio.observation().track, 398, 16, PAPER)
	text_at(Vector2(817, 345), "F6 ARQUIVO LOCAL  ·  DEL REMOVER", 15, GOLD)
	for i in ArenaCatalog.IDS.size():
		var c := ArenaCatalog.get_arena(ArenaCatalog.IDS[i])
		var rect := arena_card_rect(i)
		panel(rect.grow(5), GOLD if i == game.stage_cursor else INK)
		_arena_preview(c.image, Rect2(rect.position, Vector2(rect.size.x, 145)))
		panel(Rect2(rect.position + Vector2(0, 145), Vector2(rect.size.x, 43)), INK)
		text_at(rect.position + Vector2(9, 173), c.name, 15, PAPER)
		if i == game.stage_cursor:
			ArcadeTheme.plate(self, Rect2(rect.position + Vector2(8, 8), Vector2(90, 25)), GOLD, 8)
			text_at(rect.position + Vector2(18, 26), "PRONTO", 14, INK)
	centered(
		Vector2(640, 625),
		(
			"ÁUDIO  %d%%   /   −  +  VOLUME   /   F9 LIGAR/DESLIGAR"
			% roundi(game.stage_audio.level * 100)
		),
		17,
		GOLD
	)
	centered(Vector2(640, 657), game.stage_audio.file_status, 15, PAPER)
	_footer("A/D OU DIRECIONAL ESCOLHER  ·  ENTER/START CONFIRMAR  ·  ESC/B VOLTAR")


func _arena_preview(path: String, rect: Rect2) -> void:
	var texture := LegacyRoster.texture(path)
	var source := texture.get_size()
	var k := maxf(rect.size.x / source.x, rect.size.y / source.y)
	var crop := rect.size / k
	draw_texture_rect_region(texture, rect, Rect2((source - crop) / 2, crop))


func music_file_rect() -> Rect2:
	return Rect2(808, 323, 230, 35)


func audio_rect() -> Rect2:
	return Rect2(1107, 108, 150, 28)


func stage_rect() -> Rect2:
	return Rect2(901, 143, 355, 27)
