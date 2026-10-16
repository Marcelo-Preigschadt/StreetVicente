class_name Fighter3DPose
extends RefCounted
## Presentation-only IK in meters (100 screen pixels/m). No Node/physics feedback.
## The pose is sampled from authoritative ticks; pause/hitstop/restore freeze it.


static func sample(f: FighterModel, fraction: float = 0.0) -> Dictionary:
	var clock := (float(f.state_tick) + fraction) / 120.0
	var breath := sin(clock * TAU / 2.4) * 0.012
	var p := {
		"hip": Vector3(-0.10, 1.48 + breath, 0),
		"chest": Vector3(-0.04, 2.23 + breath, 0),
		"head": Vector3(0.04, 2.73 + breath, 0),
		"near_hand": Vector3(0.24, 2.24 + breath, 0.32),
		"far_hand": Vector3(0.83, 2.26 + breath, -0.08),
		"near_foot": Vector3(0.56, 0.11, 0.25),
		"far_foot": Vector3(-0.56, 0.11, -0.22),
		"twist": 0.0,
		"roll": 0.0,
		"palm": true,
		"tail": sin(clock * 2.5) * 0.025
	}
	var moving := (
		f.state in [FighterState.Id.WALK, FighterState.Id.STEP_IN, FighterState.Id.STEP_BACK]
	)
	if moving:
		var stride := 1.60
		var phase := float(f.walk_distance) / (256.0 * 100.0 * stride)
		var direction := float(signi(f.vx) * f.facing)
		if f.state in [FighterState.Id.STEP_IN, FighterState.Id.STEP_BACK]:
			phase = float(f.state_tick) / maxi(1, f.step_duration)
		p.near_foot = foot(phase, direction, 0.25)
		p.far_foot = foot(phase + 0.5, direction, -0.22)
		p.hip.y += absf(sin(phase * TAU)) * 0.025
		p.chest.x += sin(phase * TAU) * 0.025
		p.twist = sin(phase * TAU) * 0.12
		p.tail = sin(phase * TAU - 0.7) * 0.14 - direction * 0.10
	if f.state in [FighterState.Id.CROUCH, FighterState.Id.PREJUMP, FighterState.Id.LANDING]:
		lower(p, 0.58 if f.state == FighterState.Id.CROUCH else 0.28)
	if not f.grounded():
		p.near_foot = Vector3(0.37, 0.40, 0.25)
		p.far_foot = Vector3(-0.10, 0.63, -0.22)
		p.tail = -0.32 if f.vy < 0 else -0.15
	if f.state == FighterState.Id.BLOCK:
		if f.input.has(CombatInput.DOWN):
			lower(p, 0.55)
		p.near_hand = p.chest + Vector3(0.31, 0.35, 0.30)
		p.far_hand = p.chest + Vector3(0.43, 0.27, -0.02)
		p.palm = false
	if f.state == FighterState.Id.ATTACK:
		attack(p, f, fraction)
	if f.state == FighterState.Id.HITSTUN:
		var reaction := 1.0 - float(f.hit_duration - f.stun_ticks) / maxf(1, f.hit_duration)
		p.chest.x -= 0.22 * reaction
		p.head.x -= 0.32 * reaction
		p.near_hand += Vector3(-0.12, -0.20, 0) * reaction
		p.far_hand += Vector3(-0.13, -0.12, 0) * reaction
	if f.state == FighterState.Id.DIZZY:
		p.head += Vector3(sin(clock * 3) * 0.07, -0.12, 0)
		p.near_hand = Vector3(0.28, 1.54, 0.3)
		p.far_hand = Vector3(-0.24, 1.64, -0.1)
	if f.state in [FighterState.Id.KNOCKDOWN, FighterState.Id.KO, FighterState.Id.WAKEUP]:
		var down := 1.0
		if f.state == FighterState.Id.KNOCKDOWN and not f.grounded():
			down = clampf(float(f.state_tick) / 14.0, 0, 1)
		if f.state == FighterState.Id.WAKEUP:
			down = 1.0 - smoothstep(0.0, 32.0, f.state_tick)
		p.roll = -PI * 0.48 * down
		p.hip.y -= 1.12 * down
	return p


static func foot(phase: float, direction: float, depth: float) -> Vector3:
	# Stance has exactly the opposite root speed; swing returns the foot off ground.
	var t := fposmod(phase, 1.0)
	var x := 0.48 - t / 0.60 * 0.96
	var y := 0.11
	if t >= 0.60:
		var swing := (t - 0.60) / 0.40
		x = lerpf(-0.48, 0.48, smoothstep(0.0, 1.0, swing))
		y += sin(swing * PI) * 0.19
	return Vector3(x * direction, y, depth)


static func lower(p: Dictionary, amount: float) -> void:
	for key in ["hip", "chest", "head", "near_hand", "far_hand"]:
		p[key].y -= amount
	p.chest.x += amount * 0.25
	p.head.x += amount * 0.36


static func attack(p: Dictionary, f: FighterModel, fraction: float) -> void:
	var move := f.current_move()
	var name: String = move.legacy.get("name", "punch")
	var tick := float(f.move_tick) + fraction
	var startup := float(move.startup * 2)
	var active_end := float((move.startup + move.active) * 2)
	var extension := 0.0
	if tick < startup:
		# Load the strike first, then accelerate through the last half of startup.
		extension = smoothstep(startup * 0.42, startup, tick)
	elif tick < active_end:
		extension = 1.0
	else:
		extension = 1.0 - smoothstep(active_end, float(move.total_ticks()), tick)
	var load := sin(clampf(tick / maxf(1, startup), 0, 1) * PI) * (1.0 - extension)
	p.twist = -load * 0.25 + extension * 0.16
	p.tail += load * 0.12 - extension * 0.14
	p.palm = false
	var tip := Vector3(1.56, 2.28, 0.26)
	if name in ["crouchPunch", "sweep"]:
		lower(p, 0.65)
	if name in ["punch", "airPunch", "crouchPunch", "guardCounter"]:
		if name == "crouchPunch":
			tip = Vector3(1.72, 1.78, 0.24)
		p.hip.x += extension * 0.10
		p.chest.x += extension * 0.48 - load * 0.08
		p.head.x += extension * 0.35
		p.near_hand = p.near_hand.lerp(tip, extension)
		p.far_hand = p.chest + Vector3(0.18, 0.19, -0.1)
	elif name in ["kick", "airKick", "sweep"]:
		var target := Vector3(2.05, 2.08, 0.20)
		if name == "airKick":
			target = Vector3(2.14, 1.90, 0.20)
		elif name == "sweep":
			target = Vector3(1.92, 0.43, 0.20)
		p.hip.x += extension * 0.39
		p.chest.x -= extension * 0.12
		p.head.x -= extension * 0.22
		var chamber := Vector3(0.40, 1.28, 0.25)
		p.near_foot = p.near_foot.lerp(chamber, load)
		p.near_foot = p.near_foot.lerp(target, extension)
		p.near_hand = p.chest + Vector3(-0.05, 0.11, 0.32)
	elif name == "uppercut":
		if tick < startup:
			lower(p, load * 0.38)
		if not f.grounded() and move.phase(f.move_tick) == "RECOVERY":
			p.near_hand = Vector3(0.45, 2.36, 0.28)
		else:
			p.near_hand = p.near_hand.lerp(Vector3(0.88, 3.24, 0.25), extension)
		p.chest.x += extension * 0.14
	elif name in ["special", "super", "drone"]:
		p.palm = true
		# Authoritative release socket is shared with the projectile system.
		var hand := CombatGeometry.hand(f)
		var socket := Vector3((hand.x - f.x) * f.facing / 25600.0, (f.y - hand.y) / 25600.0, 0.23)
		p.near_hand = p.near_hand.lerp(Vector3(0.10, 1.85, 0.30), load)
		p.near_hand = p.near_hand.lerp(socket - Vector3(0.12, 0, 0), extension)
		p.chest.x += extension * 0.16
		p.far_hand = p.chest + Vector3(0.12, 0.03, -0.08)


static func joint(
	a: Vector3, b: Vector3, upper: float, lower_length: float, bend: Vector3
) -> Vector3:
	var delta := b - a
	var length := clampf(delta.length(), 0.001, upper + lower_length - 0.001)
	var direction := delta.normalized()
	var side := (bend - direction * bend.dot(direction)).normalized()
	if side.length_squared() < 0.01:
		side = Vector3.FORWARD
	var along := (upper * upper - lower_length * lower_length + length * length) / (2.0 * length)
	return a + direction * along + side * sqrt(maxf(0, upper * upper - along * along))
