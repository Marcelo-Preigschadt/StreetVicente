class_name CombatImpact
extends Node2D
## Presentation consumes identified events; effects never modify authoritative state.
var particles: Array = []
var seen: Dictionary = {}
var flash: float = 0.0
var super_time: float = 0.0
var super_character: String = "marcelo"
var super_origin := Vector2(410, 420)
var shake: float = 0.0
var camera_x: float = 0.0
var clock: float = 0.0
var presentation_paused: bool = false


func clear() -> void:
	particles.clear()
	seen.clear()
	flash = 0.0
	super_time = 0.0
	shake = 0.0


func consume(events: Array, _simulation: FightSimulation) -> void:
	for e in events:
		var id := str(e.id)
		if seen.has(id):
			continue
		seen[id] = true
		if seen.size() > 100:
			seen.erase(seen.keys()[0])
		if e.kind == "voice" and e.move == "super":
			super_time = 0.65
			super_character = e.character
			super_origin = Vector2(e.x, e.y) / 256.0 - Vector2(0, 150)
			flash = 0.07
		if e.kind in ["hit", "block"]:
			var strong: bool = (
				str(e.get("move", "")).begins_with("super")
				or str(e.get("move", "")).begins_with("uppercut")
				or str(e.get("move", "")).ends_with(":2")
				or (e.get("power_kind", "") != "" and e.get("effect", "") != "sentinelLaser")
			)
			var move := str(e.get("move", ""))
			var clip := (
				"block"
				if e.kind == "block"
				else (
					"power"
					if e.get("power_kind", "") != ""
					else (
						"heavy"
						if strong or "kick" in move.to_lower() or "sweep" in move
						else "light"
					)
				)
			)
			particles.append(
				{
					"x": float(e.x) / FighterModel.SCALE,
					"y": float(e.y) / FighterModel.SCALE,
					"life": 0.24 if strong else 0.16,
					"max": 0.24 if strong else 0.16,
					"blocked": e.kind == "block",
					"strong": strong,
					"clip": clip,
					"smoke": e.character == "gustavo" and e.get("power_kind", "") != "",
					"paint": e.character == "gelton" and e.get("power_kind", "") != "",
					"kinetic": e.character == "marcelino" and e.get("power_kind", "") != "",
					"digital": e.character == "marcos" and e.get("power_kind", "") != "",
					"athletic": e.character == "tais" and e.get("power_kind", "") != "",
					"seed": int(e.get("tick", 0)) % 13,
					"facing": int(e.get("facing", 1 if int(e.get("attacker", 0)) == 0 else -1)),
					"color": LegacyRoster.get_character(str(e.character)).color
				}
			)
			shake = 6.0 if strong else 2.5
			if e.character in ["tais", "luciana", "ruan"] and e.get("power_kind", "") != "":
				shake = 10.0 if move.begins_with("super") else 7.0
			if strong:
				flash = 0.045


func _process(delta: float) -> void:
	if presentation_paused:
		queue_redraw()
		return
	clock += delta
	flash = maxf(0.0, flash - delta)
	super_time = maxf(0.0, super_time - delta)
	shake = maxf(0.0, shake - delta * 35.0)
	for p in particles:
		p.life -= delta
	particles = particles.filter(func(p: Dictionary) -> bool: return p.life > 0.0)
	queue_redraw()


func offset() -> Vector2:
	return Vector2(sin(clock * 133), cos(clock * 97)) * shake


func _draw() -> void:
	for p in particles:
		var origin := Vector2(float(p.x) - camera_x, float(p.y))
		var phase := 1.0 - float(p.life) / float(p.max)
		var color := Color("80e8ff") if p.blocked else Color("ffe599")
		color.a = 1.0 - phase
		draw_set_transform(origin, 0, Vector2(int(p.facing), 1))
		ImpactArtV11.draw(
			self,
			p.clip,
			mini(3, int(phase * 4)),
			(
				.28
				if p.smoke or p.paint or p.kinetic or p.get("digital", false) or p.get("athletic", false)
				else (
					.62
					if p.clip == "power"
					else .48 if p.clip == "heavy" else .43 if p.blocked else .34
				)
			),
			Color(1, 1, 1, minf(1, (1 - phase) * 2.4))
		)
		draw_set_transform(Vector2.ZERO)
		if p.blocked:
			continue
		else:
			# Three exposures: white contact, graphic star, then tapered sparks.
			# Filled cel shapes remain legible against the detailed school stage.
			var fade := pow(1.0 - phase, 1.35)
			var radius := (57.0 if p.strong else 36.0) * (0.7 + phase * 0.8)
			for i in 10 if p.strong else 6:
				var angle := TAU * i / (10.0 if p.strong else 6.0) + float(p.seed) * 0.2
				var direction := Vector2(cos(angle), sin(angle))
				var start := origin + direction * radius * (0.45 + phase)
				var end := start + direction * (12 + phase * 31)
				draw_line(
					start,
					end,
					(
						Color("8edaff" if p.get("digital", false) else "fface6" if p.paint else "caffef" if p.smoke else "fff5c4")
						* Color(1, 1, 1, fade)
					),
					3.5 * (1.0 - phase) + 0.5,
					true
				)
			if phase < 0.25:
				draw_circle(origin, (11 if p.strong else 7) * (1 - phase), Color(1, 1, 1, fade))

	if flash > 0:
		draw_rect(Rect2(0, 112, 1280, 552), Color(0.8, 1, 0.95, flash * 3.0))
