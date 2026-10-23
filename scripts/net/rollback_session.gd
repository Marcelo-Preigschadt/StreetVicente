class_name RollbackSession
extends RefCounted
## Deterministic input exchange: delayed local input, held-only prediction,
## rollback and committed presentation events. Transport and UI stay outside.
const DELAY := 6
const MAX_PREDICTION := 24
const CAPACITY := 360
const INPUT_MASK := CombatInput.ALL
var world
var slot := 0
var origin := 0
var local_frames: Dictionary = {}
var remote_frames: Dictionary = {}
var history: Dictionary = {}
var remote_through := -1
var remote_ack := -1
var presented := -1
var pending_held := 0
var pending_pressed := 0
var rollbacks := 0
var replayed_ticks := 0
var fault := ""


func setup(value, local_slot: int) -> void:
	world = value
	slot = local_slot
	origin = int(world.tick)
	local_frames.clear()
	remote_frames.clear()
	history.clear()
	for tick in range(origin, origin + DELAY):
		local_frames[tick] = [0, 0]
		remote_frames[tick] = [0, 0]
	remote_through = origin + DELAY - 1
	remote_ack = origin + DELAY - 1
	presented = origin - 1
	pending_held = 0
	pending_pressed = 0
	fault = ""


func latch(value: CombatInput) -> void:
	pending_held = value.held
	pending_pressed |= value.pressed


func can_advance() -> bool:
	return fault.is_empty() and int(world.tick) <= remote_through + MAX_PREDICTION


func advance(value: CombatInput) -> bool:
	latch(value)
	if not can_advance():
		return false
	var tick := int(world.tick)
	local_frames[tick + DELAY] = [pending_held, pending_pressed]
	pending_pressed = 0
	_step(tick)
	# Retain a confirmed predecessor for reconstructing held input after pruning.
	var oldest := tick - CAPACITY
	for frames in [local_frames, remote_frames, history]:
		frames.erase(oldest)
	return true


func _remote_at(tick: int) -> Array:
	if remote_frames.has(tick):
		return remote_frames[tick]
	for previous in range(tick - 1, maxi(origin - 1, tick - CAPACITY), -1):
		if remote_frames.has(previous):
			return [int(remote_frames[previous][0]), 0]
	return [0, 0]


func _step(tick: int) -> void:
	var own: Array = local_frames.get(tick, [0, 0])
	var other := _remote_at(tick)
	var values: Array[CombatInput] = [CombatInput.new(), CombatInput.new()]
	values[slot] = CombatInput.new(int(own[0]), int(own[1]))
	values[1 - slot] = CombatInput.new(int(other[0]), int(other[1]))
	var before: Dictionary = world.snapshot()
	if world is FightSimulation:
		world.step(values)
	else:
		world.step_party(values)
	history[tick] = {"before": before, "remote": other.duplicate(),
		"events": world.events.duplicate(true)}


func packet() -> Dictionary:
	var end := int(world.tick) + DELAY
	var frames: Array = []
	for tick in range(maxi(origin, end - 20), end):
		if local_frames.has(tick):
			frames.append([tick, local_frames[tick][0], local_frames[tick][1]])
	# A lost burst must not leave a permanent hole once it leaves the recent tail.
	for tick in range(maxi(origin, remote_ack + 1), mini(end - 20, remote_ack + 21)):
		if local_frames.has(tick):
			frames.append([tick, local_frames[tick][0], local_frames[tick][1]])
	return {"frames": frames, "ack": remote_through, "tick": int(world.tick)}


func ingest(payload: Dictionary) -> bool:
	var frames = payload.get("frames")
	if not frames is Array or frames.size() > 48:
		return false
	var earliest := int(world.tick)
	# Validate the complete packet before mutating the timeline.
	for item in frames:
		if not item is Array or item.size() != 3:
			return false
		for number in item:
			if not (number is int or number is float) or float(number) != float(int(number)):
				return false
		if int(item[0]) < 0 or int(item[0]) > int(world.tick) + CAPACITY:
			return false
		if int(item[1]) < 0 or int(item[1]) > INPUT_MASK or int(item[2]) < 0 or int(item[2]) > INPUT_MASK:
			return false
		var at := int(item[0])
		var actual := [int(item[1]), int(item[2])]
		if remote_frames.has(at) and remote_frames[at] != actual:
			fault = "O outro jogador enviou comandos conflitantes. Ressincronizando…"
			return false
	for item in frames:
		var at := int(item[0])
		if at < origin or at < int(world.tick) - CAPACITY + 2:
			continue
		var actual := [int(item[1]), int(item[2])]
		remote_frames[at] = actual
		if history.has(at) and history[at].remote != actual:
			earliest = mini(earliest, at)
	while remote_frames.has(remote_through + 1):
		remote_through += 1
	var ack = payload.get("ack", origin - 1)
	if ack is int or ack is float:
		remote_ack = maxi(remote_ack, mini(int(ack), int(world.tick) + DELAY - 1))
	if earliest < int(world.tick):
		if earliest <= presented or not history.has(earliest):
			fault = "A conexão atrasou além do histórico disponível. Ressincronizando…"
			return false
		var end := int(world.tick)
		world.restore(history[earliest].before)
		for tick in range(earliest, end):
			_step(tick)
		rollbacks += 1
		replayed_ticks += end - earliest
	return true


func confirmed_tick() -> int:
	return mini(int(world.tick) - 1, mini(remote_through, remote_ack))


func drain_events() -> Array:
	var result: Array = []
	var end := confirmed_tick()
	for tick in range(presented + 1, end + 1):
		if history.has(tick):
			result.append_array(history[tick].events)
	presented = maxi(presented, end)
	return result


func checkpoint(at: int = -1) -> Dictionary:
	var next := confirmed_tick() + 1 if at < 0 else at
	if next == int(world.tick):
		return world.snapshot()
	if history.has(next):
		return history[next].before.duplicate(true)
	return {}


func observation() -> Dictionary:
	return {"tick": int(world.tick), "confirmed": confirmed_tick(),
		"remote_through": remote_through, "ack": remote_ack,
		"rollback_count": rollbacks, "replayed_ticks": replayed_ticks,
		"prediction": maxi(0, int(world.tick) - remote_through),
		"delay": DELAY, "stalled": not can_advance(), "fault": fault}
