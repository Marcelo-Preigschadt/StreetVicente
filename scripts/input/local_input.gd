class_name LocalCombatInput
extends Node
## Captura edges via eventos e polling; não perde um tap curto entre ticks.
const NAMES := [
	"left",
	"right",
	"down",
	"up",
	"punch",
	"kick",
	"guard",
	"special",
	"super",
	"uppercut",
	"throw",
	"drone",
	"strong",
	"light",
	"jump",
	"custom",
	"counter"
]
var pending: Array[int] = [0, 0]
var previous: Array[int] = [0, 0]
var pending_strength: Array[int] = [-1, -1]


func _input(event: InputEvent) -> void:
	if AppSettings.ui_open:
		return
	if event is InputEventKey and event.echo:
		return
	# Analógico contínuo usa a borda do polling, sem repetir UP por ruído de eixo.
	if event is InputEventJoypadMotion:
		return
	for slot in 2:
		for attack in ["punch", "kick"]:
			for strength in [0, 1, 2]:
				var suffix: String = ["_light", "", "_strong"][strength]
				if event.is_action_pressed("p%d_%s%s" % [slot + 1, attack, suffix]):
					pending[slot] |= CombatInput.PUNCH if attack == "punch" else CombatInput.KICK
					pending_strength[slot] = strength
		for bit in NAMES.size():
			if event.is_action_pressed("p%d_%s" % [slot + 1, NAMES[bit]]):
				pending[slot] |= 1 << bit

		if event is InputEventJoypadButton and AppSettings.pad_modifier(event.device):
			var combo := 0
			if (
				event.is_action_pressed("p%d_pause" % [slot + 1])
				and not AppSettings.profile(event.device).bindings.has("custom")
			):
				combo = CombatInput.CUSTOM
			elif (
				event.is_action_pressed("p%d_punch_strong" % [slot + 1])
				and not AppSettings.profile(event.device).bindings.has("super")
			):
				combo = CombatInput.SUPER
			elif (
				event.is_action_pressed("p%d_special" % [slot + 1])
				and not AppSettings.profile(event.device).bindings.has("uppercut")
			):
				combo = CombatInput.UPPERCUT
			elif event.is_action_pressed("p%d_punch" % [slot + 1]):
				combo = CombatInput.SPECIAL
			if combo != 0:
				pending[slot] &= ~(CombatInput.PUNCH | CombatInput.KICK | CombatInput.SPECIAL)
				pending[slot] |= combo


func sample(slot: int) -> CombatInput:
	var held := 0
	for bit in NAMES.size():
		if Input.is_action_pressed("p%d_%s" % [slot + 1, NAMES[bit]]):
			held |= 1 << bit
	var strength := -1
	for attack in ["punch", "kick"]:
		for level in [0, 2]:
			if Input.is_action_pressed(
				"p%d_%s_%s" % [slot + 1, attack, "light" if level == 0 else "strong"]
			):
				held |= CombatInput.PUNCH if attack == "punch" else CombatInput.KICK
				strength = level
	if pending_strength[slot] >= 0:
		strength = pending_strength[slot]
	if strength == 0:
		held |= CombatInput.LIGHT
	elif strength == 2:
		held |= CombatInput.STRONG
	if AppSettings.pad_modifier(AppSettings.devices[slot]):
		if Input.is_action_pressed("p%d_punch" % [slot + 1]):
			held &= ~CombatInput.PUNCH
		if Input.is_action_pressed("p%d_punch_strong" % [slot + 1]):
			held &= ~CombatInput.PUNCH
		if Input.is_action_pressed("p%d_special" % [slot + 1]):
			held &= ~CombatInput.SPECIAL
	var result := CombatInput.new(held, pending[slot] | (held & ~previous[slot]))
	pending_strength[slot] = -1
	pending[slot] = 0
	previous[slot] = held
	return result


func clear() -> void:
	pending_strength = [-1, -1]
	pending = [0, 0]
	previous = [0, 0]
	for slot in 2:
		for action in NAMES + ["punch_light", "punch_strong", "kick_light", "kick_strong", "pause"]:
			Input.action_release("p%d_%s" % [slot + 1, action])
