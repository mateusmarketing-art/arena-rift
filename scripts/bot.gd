class_name Bot
extends RefCounted
## IA dos heróis controlados pelo computador. Devolve o mesmo formato de
## comando que um jogador humano manda: move/goto/focus/casts/recall/buy.


static func think(sim: Sim, u: Sim.U, _dt: float) -> Dictionary:
	var out := {"casts": [], "buy": []}
	var st: Dictionary = u.bot_state
	var fountain: Vector2 = Data.FOUNTAIN_POS[u.team]
	var hp_ratio := u.hp / u.max_hp
	var at_base := u.pos.distance_to(fountain) < Data.FOUNTAIN_RADIUS

	# Compras na base
	if at_base:
		var build: Array = Data.BUILDS.get(u.role, Data.BUILDS.mid)
		if u.items.size() < build.size():
			var nxt: int = build[u.items.size()]
			if u.gold >= Data.ITEMS[nxt].cost:
				out.buy.append(nxt)
		if hp_ratio < 0.95:
			st["healing"] = true
			return out
	st.erase("healing")

	var enemy_heroes := []
	for e: Sim.U in sim.enemies_in(u.pos, u.team, 15.0, false):
		if e.kind == "hero":
			enemy_heroes.append(e)

	# Recuar com vida baixa
	if hp_ratio < 0.28 or st.get("retreat", false):
		st["retreat"] = hp_ratio < 0.6
		var close := false
		for e: Sim.U in enemy_heroes:
			if e.pos.distance_to(u.pos) < 11.0:
				close = true
		if not close and u.pos.distance_to(fountain) > 30.0 and sim.time - u.last_dmg > 1.5:
			out.recall = true
			return out
		_use_escape(sim, u, out, fountain)
		out.goto = fountain
		return out

	# Lutar contra heróis
	var foe := _pick_fight(sim, u, enemy_heroes, hp_ratio)
	if foe:
		_cast_at(sim, u, foe, out)
		out.focus = foe.id
		return out

	if u.lane < 0:
		return _jungle(sim, u, out)
	return _lane(sim, u, out)


static func _pick_fight(sim: Sim, u: Sim.U, heroes: Array, hp_ratio: float) -> Sim.U:
	var best: Sim.U = null
	var best_score := -1e9
	for e: Sim.U in heroes:
		var d := u.pos.distance_to(e.pos)
		var er := e.hp / e.max_hp
		if d > 13.0:
			continue
		# Não mergulhar embaixo de torre inimiga sem tropas
		if _enemy_tower_threat(sim, u, e.pos) and er > 0.25:
			continue
		var allies := sim.allies_in(u.pos, u.team, 12.0).size()
		var foes := sim.enemies_in(e.pos, u.team, 10.0, false).filter(func(x): return x.kind == "hero").size()
		var advantage := hp_ratio - er + 0.2 * (allies - foes) + 0.05 * (u.level - e.level)
		if advantage < -0.15 and er > 0.3:
			continue
		var score := -d - er * 10.0 + advantage * 8.0
		if score > best_score:
			best_score = score
			best = e
	return best


static func _enemy_tower_threat(sim: Sim, u: Sim.U, p: Vector2) -> bool:
	for id in sim.order:
		var t: Sim.U = sim.units[id]
		if (t.kind != "tower" and t.kind != "nexus") or t.team == u.team or t.dead:
			continue
		if t.pos.distance_to(p) < t.arange + 1.5:
			# Seguro se o alvo atual da torre é uma tropa aliada
			var cur: Sim.U = sim.units.get(t.target)
			if cur and cur.kind != "hero" and cur.team == u.team:
				return false
			var minions := 0
			for a: Sim.U in sim.allies_in(t.pos, u.team, t.arange, false):
				if a.kind != "hero":
					minions += 1
			return minions < 2
	return false


static func _cast_at(sim: Sim, u: Sim.U, foe: Sim.U, out: Dictionary) -> void:
	var abilities: Array = Data.HEROES[u.hero].abilities
	var d := u.pos.distance_to(foe.pos)
	for i in [3, 0, 2, 1]:
		if not sim.can_cast(u, i):
			continue
		var a: Dictionary = abilities[i]
		var rng: float = a.get("range", 0.0)
		var ok := false
		match a.type:
			"skillshot":
				ok = d <= rng * 0.85
			"blast":
				ok = d <= rng + a.radius * 0.5
			"dash":
				ok = a.get("d", 0) > 0 and d <= rng + 1.0 and d > 2.0
			"nova":
				ok = d <= a.radius * 0.9
			"buff":
				ok = d < 9.0
			"heal":
				var hurt := false
				for al: Sim.U in sim.allies_in(u.pos, u.team, a.radius):
					if al.hp / al.max_hp < 0.6:
						hurt = true
				ok = hurt
			"blink":
				ok = false
		if i == 3 and ok and foe.hp / foe.max_hp > 0.75 and a.type != "heal":
			ok = sim.allies_in(foe.pos, u.team, 10.0).size() > 1 or foe.hp < ability_value(sim, u, a) * 1.3
		if ok:
			var lead := foe.pos - u.pos
			if a.type == "blast":
				out.casts.append([i, lead / maxf(rng, 0.1), false])
			else:
				out.casts.append([i, lead.normalized(), false])
			return


static func ability_value(sim: Sim, u: Sim.U, a: Dictionary) -> float:
	return sim.ability_damage(u, a)


static func _use_escape(sim: Sim, u: Sim.U, out: Dictionary, to: Vector2) -> void:
	var abilities: Array = Data.HEROES[u.hero].abilities
	for i in range(3):
		var a: Dictionary = abilities[i]
		if (a.type == "blink" or (a.type == "dash" and a.get("d", 0) == 0) or (a.type == "buff" and a.has("haste"))) and sim.can_cast(u, i):
			if u.pos.distance_to(to) > 12.0 and sim.time - u.last_dmg < 2.0:
				out.casts.append([i, (to - u.pos).normalized(), false])
				return


static func _lane(sim: Sim, u: Sim.U, out: Dictionary) -> Dictionary:
	# 1. tropas inimigas por perto
	var best: Sim.U = null
	var bd := 1e9
	for e: Sim.U in sim.enemies_in(u.pos, u.team, 12.0, false):
		if e.kind == "hero" or e.team == Data.TEAM_NEUTRAL:
			continue
		if _enemy_tower_threat(sim, u, e.pos):
			continue
		# Prioriza o último golpe
		var d := u.pos.distance_to(e.pos) + e.hp / 40.0
		if e.hp < u.atk * 1.1:
			d -= 8.0
		if d < bd:
			bd = d
			best = e
	if best:
		out.focus = best.id
		return out
	# 2. torre inimiga vulnerável com tropas aliadas tankando
	for id in sim.order:
		var t: Sim.U = sim.units[id]
		if (t.kind == "tower" or t.kind == "nexus") and t.team != u.team and not t.dead and sim.vulnerable(t):
			if t.pos.distance_to(u.pos) < 16.0 and not _enemy_tower_threat(sim, u, t.pos):
				out.focus = t.id
				return out
	# 3. ir para a frente da rota (tropa aliada mais adiantada)
	var path := Data.lane_path(u.lane, u.team)
	var front := _lane_front(sim, u, path)
	out.goto = front
	return out


static func _lane_front(sim: Sim, u: Sim.U, path: PackedVector2Array) -> Vector2:
	var best_prog := -1.0
	var best_pos := Vector2.ZERO
	for id in sim.order:
		var m: Sim.U = sim.units[id]
		if m.team != u.team or m.lane != u.lane or m.dead:
			continue
		if m.kind != "melee" and m.kind != "ranged" and m.kind != "siege":
			continue
		var prog := _progress(path, m.pos)
		if prog > best_prog:
			best_prog = prog
			best_pos = m.pos
	# Sem tropas: espera na torre aliada mais avançada
	var tower_prog := 0.0
	var tower_pos: Vector2 = path[0]
	for id in sim.order:
		var t: Sim.U = sim.units[id]
		if t.kind == "tower" and t.team == u.team and t.lane == u.lane and not t.dead:
			var p := _progress(path, t.pos)
			if p > tower_prog:
				tower_prog = p
				tower_pos = t.pos
	if best_prog < 0:
		return tower_pos + (path[path.size() - 1] - tower_pos).normalized() * 3.0
	var back := Data.point_along(path, maxf(0.0, best_prog - (2.0 if u.kind == "hero" and not u.ranged else 5.0)))
	return back


static func _progress(path: PackedVector2Array, p: Vector2) -> float:
	var acc := 0.0
	var best := 1e9
	var best_prog := 0.0
	for i in range(path.size() - 1):
		var a := path[i]
		var b := path[i + 1]
		var ab := b - a
		var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		var d := p.distance_to(a + ab * t)
		if d < best:
			best = d
			best_prog = acc + ab.length() * t
		acc += ab.length()
	return best_prog


static func _jungle(sim: Sim, u: Sim.U, out: Dictionary) -> Dictionary:
	var st: Dictionary = u.bot_state
	# Monstro mais próximo do lado aliado (ou guardião do rio a partir do nível 6)
	var best: Sim.U = null
	var bd := 1e9
	for id in sim.order:
		var m: Sim.U = sim.units[id]
		if (m.kind != "monster" and m.kind != "boss") or m.dead:
			continue
		if m.kind == "boss" and (u.level < 7 or sim.allies_in(m.pos, u.team, 20.0).size() < 2):
			continue
		var own_side := (m.home.x < m.home.y) == (u.team == Data.TEAM_BLUE)
		var d := u.pos.distance_to(m.pos) + (0.0 if own_side else 25.0)
		if d < bd:
			bd = d
			best = m
	if best and bd < 70.0:
		if u.pos.distance_to(best.pos) < 6.0:
			var abilities: Array = Data.HEROES[u.hero].abilities
			for i in range(3):
				var a: Dictionary = abilities[i]
				if sim.can_cast(u, i) and (a.type == "nova" or a.type == "buff"):
					out.casts.append([i, (best.pos - u.pos).normalized(), false])
					break
		out.focus = best.id
		return out
	# Sem monstros: ajudar a rota com mais inimigos (gank) ou o meio
	if not st.has("gank_lane") or sim.time > st.get("gank_until", 0.0):
		st["gank_lane"] = randi() % 3
		st["gank_until"] = sim.time + 25.0
	var lane_u := u.lane
	u.lane = st.gank_lane
	var r := _lane(sim, u, out)
	u.lane = lane_u
	return r
