class_name OnlineV22Tests
extends RefCounted
## Network faults are applied to packets, never to a second gameplay authority.

class ProbeRelay extends RealtimeRelay:
	var outbox: Array = []

	func send(value: Dictionary) -> bool:
		var packet := value.duplicate(true)
		packet.from = peer_id
		outbox.append(packet)
		return true

	func take(type: String) -> Dictionary:
		for i in outbox.size():
			if outbox[i].get("t") == type:
				return JSON.parse_string(JSON.stringify(outbox.pop_at(i)))
		return {}


static func _handshake(s: SceneTree) -> void:
	var peers: Array[OnlineSession] = []
	var loads := [0, 0]
	for i in 2:
		var peer := OnlineSession.new()
		peer.slot = i
		peer.phase = "lobby"
		peer.local_id = "host:ABCDEFGH" if i == 0 else "guest"
		peer.remote_id = "guest" if i == 0 else "host:ABCDEFGH"
		peer.directory = RoomDirectory.new()
		peer.add_child(peer.directory)
		peer.relay = ProbeRelay.new()
		peer.add_child(peer.relay)
		peer.relay.peer_id = peer.local_id
		peer.relay.connected = true
		peers.append(peer)
	var host := peers[0]
	var guest := peers[1]
	var outbound_host := host.relay as ProbeRelay
	var outbound_guest := guest.relay as ProbeRelay
	host.prepare_game.connect(func():
		loads[0] += 1
		host.attach_world(FightSimulation.new(LegacyRoster.get_character("marcelo"), LegacyRoster.get_character("rafael"))))
	guest.prepare_game.connect(func():
		loads[1] += 1
		guest.attach_world(FightSimulation.new(LegacyRoster.get_character("marcelo"), LegacyRoster.get_character("rafael"))))
	host.confirmed = [true, true]
	host.choice_versions = [1, 1]
	guest.choice_serial = 1
	guest.proposed = "rafael"
	guest.proposed_ready = true
	guest.confirmed = [true, false]  # Deliberately withhold the last lobby acknowledgement.
	host._maybe_prepare()
	var lost := outbound_host.take("prepare")
	host.last_control = Time.get_ticks_msec() - 1001
	host._process(0)
	var prepare := outbound_host.take("prepare")
	s.check(not prepare.is_empty() and prepare.epoch == lost.epoch, "Prepare perdido é reenviado com a mesma partida")
	guest._receive(prepare)
	s.check(guest.world != null and guest.phase == "preparing", "Prepare confirma prontidão local sem depender de welcome anterior")
	var stale := {"t": "welcome", "to": guest.local_id, "from": host.local_id,
		"protocol": OnlineSession.VERSION, "game_mode": "versus", "pair": host.pair,
		"confirmed": [true, true], "serials": [1, 1], "revision": int(prepare.revision) - 1,
		"stage": "patio", "epoch": "", "in_game": false}
	guest._receive(stale)
	s.check(guest.world != null and guest.phase == "preparing", "Welcome atrasado não apaga o mundo preparado")
	outbound_guest.take("loaded")  # Lose the first loading acknowledgement.
	guest._receive(prepare)
	s.check(loads[1] == 1 and not outbound_guest.take("loaded").is_empty(), "Prepare duplicado confirma sem carregar duas vezes")
	guest.last_control = Time.get_ticks_msec() - 1001
	guest._process(0)
	var loaded := outbound_guest.take("loaded")
	s.check(not loaded.is_empty(), "Confirmação de carregamento também tem reenvio")
	host._receive(loaded)
	var serial := host.sync_id
	host._receive(loaded)
	s.check(host.phase == "syncing" and host.sync_id == serial, "Loaded duplicado não cria outra sincronização")
	guest._receive(outbound_host.take("sync"))
	outbound_guest.take("synced")  # Lose the synchronization acknowledgement too.
	outbound_host.outbox.clear()
	host.last_control = Time.get_ticks_msec() - 2001
	host._process(0)
	guest._receive(outbound_host.take("sync"))
	host._receive(outbound_guest.take("synced"))
	guest._receive(outbound_host.take("run"))
	s.check(host.phase == "playing" and guest.phase == "playing", "Handshake conclui apesar de perdas e reordenação")
	host._receive(loaded)
	s.check(host.sync_id == serial and host.phase == "playing", "Loaded tardio não interrompe uma partida em andamento")
	guest.world = null
	guest.timeline = null
	guest.phase = "lobby"
	guest.choice_serial = 2
	guest.proposed_ready = false
	guest._receive(prepare)
	s.check(guest.world == null and not outbound_guest.take("cancel_prepare").is_empty(), "Prepare antigo não força jogador que cancelou prontidão")
	for peer in peers:
		peer.free()


static func _input(tick: int, slot: int) -> CombatInput:
	var held := 0
	var edge := 0
	if tick % 280 < 95:
		held = CombatInput.RIGHT if slot == 0 else CombatInput.LEFT
	elif tick % 280 > 220:
		held = CombatInput.LEFT if slot == 0 else CombatInput.RIGHT
	if tick % 97 == 0:
		edge = CombatInput.PUNCH
	elif tick % 131 == 0:
		edge = CombatInput.KICK
	elif tick % 211 == 0:
		edge = CombatInput.SPECIAL
	elif tick % 397 == 0:
		edge = CombatInput.UPPERCUT
	elif tick % 173 == 0:
		held |= CombatInput.GUARD
	return CombatInput.new(held, edge)


static func _exercise(s: SceneTree, coop: bool) -> void:
	var first := LegacyRoster.get_character("khauany")
	var second := LegacyRoster.get_character("ruan")
	var worlds: Array = []
	var peers: Array[RollbackSession] = []
	for slot in 2:
		var world = CoopStorySimulation.new(first, second) if coop else FightSimulation.new(first, second)
		worlds.append(world)
		var peer := RollbackSession.new()
		peer.setup(world, slot)
		peers.append(peer)
	var records: Array = [{}, {}]
	for slot in 2:
		for tick in RollbackSession.DELAY:
			records[slot][tick] = [0, 0]
	var wire: Array = []
	var seen: Array = [{}, {}]
	for wall_tick in 1100:
		for slot in 2:
			var peer := peers[slot]
			var frame := int(worlds[slot].tick)
			var value := _input(frame, slot)
			if peer.can_advance():
				records[slot][frame + RollbackSession.DELAY] = value.serialize()
			peer.advance(value)
			if wall_tick % 4 == 0 and wall_tick % 36 != 0 and not (slot == 1 and wall_tick in range(360, 450)):
				var delay := 1 + (wall_tick * 7 + slot * 11) % 15
				wire.append({"due": wall_tick + delay, "to": 1 - slot, "body": peer.packet()})
			for event in peer.drain_events():
				s.check(not seen[slot].has(event.id), "Rollback não repete evento confirmado: " + str(coop) + " " + JSON.stringify(event))
				seen[slot][event.id] = true
		var pending: Array = []
		for packet in wire:
			if packet.due <= wall_tick:
				s.check(peers[int(packet.to)].ingest(packet.body), "Aceita pacotes atrasados e reordenados")
			else:
				pending.append(packet)
		wire = pending
	for packet in wire:
		peers[int(packet.to)].ingest(packet.body)
	for pass_index in 2:
		peers[0].ingest(peers[1].packet())
		peers[1].ingest(peers[0].packet())
	var common := mini(peers[0].confirmed_tick(), peers[1].confirmed_tick()) + 1
	var oracle = CoopStorySimulation.new(first, second) if coop else FightSimulation.new(first, second)
	for tick in common:
		var inputs: Array[CombatInput] = []
		for slot in 2:
			var raw: Array = records[slot][tick]
			inputs.append(CombatInput.new(raw[0], raw[1]))
		if coop:
			oracle.step_party(inputs)
		else:
			oracle.step(inputs)
	for slot in 2:
		s.check(SnapshotCodec.state_hash(peers[slot].checkpoint(common)) == oracle.state_hash(),
			"Dois peers convergem ao oráculo offline: " + ("coop" if coop else "versus"))
		s.check(peers[slot].fault.is_empty(), "Jitter/perda redundante não encerra a sessão")
		s.check(peers[slot].rollbacks > 0, "Correção tardia realmente ressimula comandos")
		s.check(int(worlds[slot].tick) - peers[slot].remote_through <= RollbackSession.MAX_PREDICTION,
			"Previsão tem limite finito")
	var snapshot: Dictionary = oracle.snapshot()
	oracle.restore(SnapshotCodec.integers(JSON.parse_string(JSON.stringify(snapshot))))
	s.check(oracle.state_hash() == SnapshotCodec.state_hash(snapshot), "Checkpoint sobrevive a JSON e reconexão")
	var session := OnlineSession.new()
	session.pair = [first.id, second.id]
	session.game_mode = "story" if coop else "versus"
	session.world = CoopStorySimulation.new(first, second) if coop else FightSimulation.new(first, second)
	s.check(session._valid_snapshot(JSON.parse_string(JSON.stringify(snapshot))), "Snapshot jogado é válido para peer recém-carregado")
	var invalid := snapshot.duplicate(true)
	if coop:
		invalid.partner.erase("x")
	else:
		invalid.fighters[1].erase("x")
	s.check(not session._valid_snapshot(invalid), "Snapshot incompleto não chega ao restore")
	session.free()


static func run(s: SceneTree) -> void:
	_handshake(s)
	_exercise(s, false)
	_exercise(s, true)
	var c := LegacyRoster.get_character("marcelo")
	var net := RollbackSession.new()
	var world := FightSimulation.new(c, LegacyRoster.get_character("ruan"))
	net.setup(world, 0)
	for tick in 50:
		net.advance(CombatInput.new())
	s.check(not net.can_advance(), "Conexão sem confirmação para no limite de previsão")
	var before := world.tick
	net.advance(CombatInput.new(0, CombatInput.PUNCH))
	s.check(world.tick == before, "Espera de rede não avança o mundo")
	var frames: Array = []
	for tick in 90:
		frames.append([tick, 0, 0])
	net.ingest({"frames": frames.slice(0, 45), "ack": 100})
	net.ingest({"frames": frames.slice(45), "ack": 100})
	net.advance(CombatInput.new())
	s.check(net.local_frames[before + RollbackSession.DELAY][1] == CombatInput.PUNCH,
		"Tap ocorrido durante espera não desaparece")
	var count := net.remote_frames.size()
	s.check(not net.ingest({"frames": [[123.5, 0, 0]], "ack": 0}), "Recusa tick fracionário")
	s.check(not net.ingest({"frames": [[123, CombatInput.ALL + 1, 0]], "ack": 0}), "Recusa bits fora do protocolo")
	s.check(net.remote_frames.size() == count, "Pacote inválido não altera o histórico")
	var coop := CoopStorySimulation.new(c, LegacyRoster.get_character("khauany"))
	coop.heroes[0].x = 120 * 256
	coop.heroes[1].x = 200 * 256
	coop.heroes[1].ground_y = coop.heroes[0].ground_y
	coop.heroes[1].y = coop.heroes[1].ground_y
	for enemy in coop.enemies:
		enemy.fighter.x = 3200 * 256
	coop.heroes[0].meter = 100
	coop.heroes[0]._start_move(c.get_move("super", 1))
	for tick in 240:
		coop.step_party([CombatInput.new(), CombatInput.new()])
	s.check(coop.heroes[1].health == 1000, "Drones e projéteis não atacam o parceiro")
	coop.heroes[1].health = 0
	coop.heroes[1].transition(FighterState.Id.KO)
	coop.heroes[1].x = coop.heroes[0].x + 80 * 256
	coop.step_party([CombatInput.new(0, CombatInput.THROW), CombatInput.new()])
	s.check(coop.heroes[1].health == 300 and not coop.defeated, "E ajuda o parceiro caído")
	var campaign := CoopStorySimulation.new(c, LegacyRoster.get_character("khauany"))
	for enemy in campaign.enemies:
		enemy.fighter.health = 0
	campaign.heroes[0].x = 730 * 256
	campaign.heroes[1].x = 70 * 256
	campaign.step_party([CombatInput.new(), CombatInput.new()])
	s.check(campaign.wave_index == 0, "Portão espera o segundo herói vivo")
	var clock := campaign.remaining_ticks
	for wave in 18:
		for enemy in campaign.enemies:
			enemy.fighter.health = 0
		var gate := mini(3560, 880 + campaign.wave_index * 820)
		for actor in campaign.heroes:
			actor.x = (gate - 150) * 256
		campaign.step_party([CombatInput.new(), CombatInput.new()])
		if campaign.completed:
			break
	s.check(campaign.completed and campaign.act_index == 4 and campaign.boss_phase == 2,
		"Dupla atravessa os quatro atos e a segunda fase do chefe")
	s.check(campaign.remaining_ticks < clock and campaign.heroes[1].character.id == "khauany",
		"Transição de ato preserva identidade da dupla e relógio compartilhado")
	var completed_session := OnlineSession.new()
	completed_session.game_mode = "story"
	completed_session.pair = ["marcelo", "khauany"]
	completed_session.world = CoopStorySimulation.new(c, LegacyRoster.get_character("khauany"))
	s.check(completed_session._valid_snapshot(campaign.snapshot()), "Conclusão do ato final também permite checkpoint online")
	completed_session.free()
	s.check(RoomDirectory.valid_code(RoomDirectory.new_code()), "Código aleatório usa alfabeto legível")
	s.check(not RoomDirectory.valid_code("X';DROP;"), "Código inválido nunca vira consulta ao diretório")
	var session := OnlineSession.new()
	var directory := RoomDirectory.new()
	session.setup(directory)
	session.slot = 0
	session.phase = "lobby"
	session.local_id = "host:test"
	session.remote_id = "guest"
	session.choice_versions = [2, 9]
	var message := {"to": session.local_id, "from": "guest", "protocol": OnlineSession.VERSION,
		"game_mode": "versus", "t": "leave"}
	session._receive(message)
	s.check(session.choice_versions[1] == 0 and session.remote_id.is_empty(), "Nova vaga não herda serial do visitante anterior")
	session.free()
	directory.free()
