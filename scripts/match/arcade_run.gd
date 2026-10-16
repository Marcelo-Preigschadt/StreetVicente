class_name ArcadeRun
extends RefCounted
## Port das regras de src/arcade.js (4.8). Exclusivo da CPU local, fora do rollback.
const ROUTE_TICKS := 672  # 5,6 segundos a 120 Hz; Enter/Start adianta.
const STOPS := [
	"PORTÃO",
	"PÁTIO",
	"CANTINA",
	"BIBLIOTECA",
	"LAB. QUÍMICA",
	"QUADRA",
	"SALA DE ARTES",
	"AUDITÓRIO",
	"LAB. FÍSICA",
	"SALA 301",
	"LAB. INFORMÁTICA",
	"NÚCLEO DO NIT"
]
var player_id: String
var opponents: Array = []
var index: int = 0
var score: int = 0
var record: int = 0
var wins: int = 0
var perfects: int = 0
var continues: int = 0
var state: String = "fighting"
var breakdown: Dictionary = {}
var seen: Dictionary = {}
var rounds: Dictionary = {}
var last_hit: String = ""


func _init(roster: Array, player: String, first: String, previous_record: int = 0) -> void:
	assert(player in roster and first in roster and first != player)
	player_id = player
	opponents = [first]
	for id in roster:
		if id not in [player, first]:
			opponents.append(id)
	record = maxi(0, previous_record)
	_begin_attempt()


func _begin_attempt() -> void:
	breakdown = {
		"combat": 0,
		"combo": 0,
		"round": 0,
		"life": 0,
		"time": 0,
		"perfect": 0,
		"super": 0,
		"match": 0,
		"clear": 0
	}
	seen.clear()
	rounds.clear()
	last_hit = ""


func _add(kind: String, points: int) -> void:
	var amount := maxi(0, points)
	breakdown[kind] += amount
	score += amount
	record = maxi(record, score)


func consume(events: Array) -> void:
	for e in events:
		if state != "fighting" or seen.has(e.id):
			continue
		seen[e.id] = true
		match e.kind:
			"round":
				last_hit = ""
			"hit":
				if e.get("attacker", -1) == 0 and e.slot == 1:
					_add("combat", clampi(int(e.get("damage", 0)), 0, 1000) * 10)
					_add(
						"combo",
						(
							maxi(0, int(e.get("combo", 1)) - 1) * 50
							+ (500 if not str(e.get("combo_name", "")).is_empty() else 0)
						)
					)
					last_hit = str(e.move).get_slice(":", 0)
			"round_end":
				if rounds.has(e.round):
					continue
				rounds[e.round] = true
				if e.winner == 0:
					_add("round", 1000)
					_add("life", clampi(int(e.life), 0, 1000) * 5)
					_add("time", maxi(0, int(e.seconds)) * 50)
					if int(e.life) == 1000:
						_add("perfect", 5000)
						perfects += 1
					if last_hit == "super" and e.ko:
						_add("super", 2000)
			"result":
				if e.winner != 0:
					state = "defeated"
				else:
					_add("match", 3000)
					wins += 1
					state = "route" if index + 1 < opponents.size() else "complete"
					if state == "complete":
						_add("clear", 20000)


func advance() -> void:
	assert(state == "route")
	index += 1
	state = "fighting"
	_begin_attempt()


func continue_run() -> void:
	assert(state in ["defeated", "fighting"])
	score = 0
	continues += 1
	state = "fighting"
	_begin_attempt()
