class_name CombatInput
extends RefCounted
## Um pacote por tick. pressed é explícito: dois taps entre ticks não viram hold.
const LEFT := 1
const RIGHT := 2
const DOWN := 4
const UP := 8
const PUNCH := 16
const KICK := 32
const GUARD := 64
const SPECIAL := 128
const SUPER := 256
const UPPERCUT := 512
const THROW := 1024
const DRONE := 2048
const STRONG := 4096
const LIGHT := 8192
const JUMP := 16384
const CUSTOM := 32768
const COUNTER := 65536
const ALL := 131071

var held: int = 0
var pressed: int = 0


func _init(p_held: int = 0, p_pressed: int = 0) -> void:
	held = p_held & ALL
	pressed = p_pressed & ALL


func axis_x() -> int:
	# SOCD neutro: esquerda + direita não gera prioridade dependente da ordem.
	return int((held & RIGHT) != 0) - int((held & LEFT) != 0)


func has(flag: int) -> bool:
	return (held & flag) != 0


func serialize() -> Array:
	return [held, pressed]
