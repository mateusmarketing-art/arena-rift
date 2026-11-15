class_name Sim
extends RefCounted
## Simulação autoritativa da partida. Roda só no aparelho que hospeda.

class U:
	var id := 0
	var kind := "hero"
	var team := 0
	var pos := Vector2.ZERO
	var rot := 0.0
	var hp := 100.0
	var max_hp := 100.0
	var base_hp := 100.0
	var armor := 0.0
	var atk := 10.0
	var aspd := 1.0
	var arange := 1.5
	var speed := 5.0
	var radius := 0.6
	var ranged := false
	var attack_cd := 0.0
	var target := 0
	var lane := -1
	var wp := 1
	var dead := false
	var respawn_t := 0.0
	var level := 1
	var xp := 0.0
	var gold := 500.0
	var hero := -1
	var role := ""
	var cds := [0.0, 0.0, 0.0, 0.0]
	var shield := 0.0
	var shield_t := 0.0
	var slow := 0.0
	var slow_t := 0.0
	var stun_t := 0.0
	var haste := 1.0
	var haste_t := 0.0
	var aspd_mul := 1.0
	var aspd_t := 0.0
	var dash_v := Vector2.ZERO
	var dash_t := 0.0
	var dash_ab := {}
	var dash_hit := {}
	var recall_t := 0.0
	var kills := 0
	var deaths := 0
	var assists := 0
	var cs := 0
	var items := []
	var b_hp := 0.0
	var b_atk := 0.0
	var b_pw := 0.0
	var b_armor := 0.0
	var b_aspd := 0.0
	var b_speed := 0.0
	var hero_hits := {}
	var tier := 0
	var home := Vector2.ZERO
	var camp := -1
	var name := ""
	var bot := true
	var peer := 0
	var last_hero_dmg := -99.0
	var last_dmg := -99.0
	var gold_value := 0.0
	var xp_value := 0.0
	var bot_state := {}
	var path := PackedVector2Array()
	var path_goal := Vector2(1e9, 1e9)
	var path_i := 0

var units := {}
var order := []  # ids em ordem de criação, para iteração estável
var next_id := 1
var time := 0.0
var projectiles := []
var delayed := []
var events := []
var obstacles := []
var wave_t := 12.0
var wave_n := 0
var score := [0, 0]
var winner := -1
var inputs := {}
var camps := []
var team_buff_t := [0.0, 0.0]
var slots := []


func setup(p_slots: Array) -> void:
	slots = p_slots
	obstacles = Data.gen_obstacles()
	_build_grid()
	# Heróis primeiro: o id do herói é sempre índice do slot + 1
	for i in range(p_slots.size()):
		var s: Dictionary = p_slots[i]
		var u := _new_unit("hero", s.team)
		u.hero = s.hero
		var h: Dictionary = Data.HEROES[u.hero]
		u.name = s.name
		u.bot = s.bot
		u.peer = s.get("peer", 0)
		u.role = s.get("role", h.role)
		u.lane = Data.ROLE_LANE.get(u.role, 1)
		u.base_hp = h.hp
		u.ranged = h.ranged
		u.arange = h.range
		u.radius = 0.75
		_recalc_hero(u)
		u.hp = u.max_hp
		u.pos = _fountain_spot(u)
	# Torres e Nexus
	for team in [0, 1]:
		for lane in range(3):
			var path := Data.lane_path(lane, team)
			for t in range(2):
				var tw := _new_unit("tower", team)
				tw.tier = t
				tw.lane = lane
				tw.pos = Data.point_along(path, Data.TOWER_DIST[t])
				tw.max_hp = 2300.0 if t == 1 else 2600.0
				tw.hp = tw.max_hp
				tw.armor = 45
				tw.atk = 150
				tw.aspd = 0.85
				tw.arange = 9.5
				tw.radius = 1.6
				tw.ranged = true
				tw.speed = 0
				tw.name = "Torre"
		var nx := _new_unit("nexus", team)
		nx.pos = Data.NEXUS_POS[team]
		nx.max_hp = 4200
		nx.hp = nx.max_hp
		nx.armor = 50
		nx.atk = 180
		nx.aspd = 0.9
		nx.arange = 10.0
		nx.radius = 3.0
		nx.ranged = true
		nx.speed = 0
		nx.name = "Nexus"
	for i in range(Data.CAMPS.size()):
		var c: Array = Data.CAMPS[i]
		camps.append({"pos": c[0], "kind": c[1], "t": 25.0 if c[1] == 0 else 150.0, "id": 0})


func _new_unit(kind: String, team: int) -> U:
	var u := U.new()
	u.id = next_id
	next_id += 1
	u.kind = kind
	u.team = team
	units[u.id] = u
	order.append(u.id)
	return u


func _fountain_spot(u: U) -> Vector2:
	var f: Vector2 = Data.FOUNTAIN_POS[u.team]
	var idx := (u.id - 1) % 5
	return f + Vector2(cos(idx * 1.25), sin(idx * 1.25)) * 3.0


func _recalc_hero(u: U) -> void:
	var h: Dictionary = Data.HEROES[u.hero]
	u.b_hp = 0; u.b_atk = 0; u.b_pw = 0; u.b_armor = 0; u.b_aspd = 0; u.b_speed = 0
	for it in u.items:
		var d: Dictionary = Data.ITEMS[it]
		u.b_hp += d.get("hp", 0)
		u.b_atk += d.get("atk", 0)
		u.b_pw += d.get("pw", 0)
		u.b_armor += d.get("armor", 0)
		u.b_aspd += d.get("aspd", 0)
		u.b_speed += d.get("speed", 0)
	var ratio := u.hp / u.max_hp if u.max_hp > 0 else 1.0
	u.max_hp = h.hp + h.hp_lvl * (u.level - 1) + u.b_hp
	u.hp = clampf(ratio * u.max_hp, 1.0, u.max_hp)
	u.atk = h.atk + h.atk_lvl * (u.level - 1) + u.b_atk
	u.armor = h.armor + 3.0 * (u.level - 1) + u.b_armor
	u.aspd = h.aspd * (1.0 + 0.02 * (u.level - 1)) + u.b_aspd
	u.speed = h.speed + u.b_speed


# ---------------------------------------------------------------- consultas

func get_u(id: int) -> U:
	return units.get(id)


func alive(id: int) -> bool:
	var u: U = units.get(id)
	return u != null and not u.dead


var _vuln := {}
var _vuln_dirty := true


func vulnerable(u: U) -> bool:
	if u.kind != "tower" and u.kind != "nexus":
		return true
	if _vuln_dirty:
		_rebuild_vuln()
	return _vuln.get(u.id, true)


func _rebuild_vuln() -> void:
	_vuln_dirty = false
	_vuln.clear()
	var outer_alive := {}
	var inner_alive := [false, false]
	for id in order:
		var o: U = units[id]
		if o.kind == "tower" and not o.dead:
			if o.tier == 0:
				outer_alive["%d_%d" % [o.team, o.lane]] = true
			else:
				inner_alive[o.team] = true
	for id in order:
		var o: U = units[id]
		if o.kind == "tower":
			_vuln[o.id] = o.tier == 0 or not outer_alive.has("%d_%d" % [o.team, o.lane])
		elif o.kind == "nexus":
			_vuln[o.id] = not inner_alive[o.team]


func targetable(u: U) -> bool:
	if u == null or u.dead:
		return false
	return vulnerable(u)


var _alive: Array = []


func _refresh_alive() -> void:
	_alive.clear()
	for id in order:
		var u: U = units[id]
		if not u.dead:
			_alive.append(u)


func enemies_in(pos: Vector2, team: int, r: float, structures := true) -> Array:
	var out := []
	for u: U in _alive:
		if u.dead or u.team == team:
			continue
		if not structures and (u.kind == "tower" or u.kind == "nexus"):
			continue
		if not targetable(u):
			continue
		if u.pos.distance_to(pos) <= r + u.radius:
			out.append(u)
	return out


func allies_in(pos: Vector2, team: int, r: float, heroes_only := true) -> Array:
	var out := []
	for u: U in _alive:
		if u.dead or u.team != team:
			continue
		if heroes_only and u.kind != "hero":
			continue
		if u.pos.distance_to(pos) <= r + u.radius:
			out.append(u)
	return out


func nearest_enemy(u: U, r: float, prefer_heroes := false, structures := true) -> U:
	var best: U = null
	var bd := 1e9
	for e: U in enemies_in(u.pos, u.team, r, structures):
		var d: float = u.pos.distance_to(e.pos)
		if prefer_heroes and e.kind == "hero":
			d -= 100.0
		if d < bd:
			bd = d
			best = e
	return best


# ---------------------------------------------------------------- dano

func damage(src: U, dst: U, amount: float) -> void:
	if dst == null or dst.dead or amount <= 0:
		return
	if not vulnerable(dst):
		return
	if src and src.team < 2 and team_buff_t[src.team] > time:
		amount *= 1.12
	if src and src.kind != "hero" and (dst.kind == "tower" or dst.kind == "nexus"):
		amount *= 0.85
	if src and src.kind == "hero" and src.role == "jungle" and (dst.kind == "monster" or dst.kind == "boss"):
		amount *= 1.7
		heal(src, amount * 0.12)
	amount *= 100.0 / (100.0 + maxf(dst.armor, 0.0))
	if dst.shield > 0:
		var a := minf(dst.shield, amount)
		dst.shield -= a
		amount -= a
	dst.hp -= amount
	dst.last_dmg = time
	if dst.recall_t > 0:
		dst.recall_t = 0
		events.append({"t": "recall_cancel", "a": dst.id})
	if src:
		if src.kind == "hero":
			dst.hero_hits[src.id] = time
			if dst.kind == "hero":
				src.last_hero_dmg = time
		if dst.kind == "monster" or dst.kind == "boss":
			if dst.target == 0 or not alive(dst.target):
				dst.target = src.id
	if dst.hp <= 0:
		_kill(src, dst)


func heal(u: U, amount: float) -> void:
	if u.dead:
		return
	u.hp = minf(u.max_hp, u.hp + amount)


func _kill(src: U, dst: U) -> void:
	dst.hp = 0
	dst.dead = true
	dst.target = 0
	dst.dash_t = 0
	var killer_hero: U = src if src and src.kind == "hero" else null
	if killer_hero == null:
		# Crédito para o último herói que bateu nos últimos 8 s
		var best_t := -1.0
		for hid in dst.hero_hits:
			if dst.hero_hits[hid] > time - 8.0 and dst.hero_hits[hid] > best_t:
				var h: U = units.get(hid)
				if h and h.team != dst.team:
					best_t = dst.hero_hits[hid]
					killer_hero = h
	var kteam := src.team if src else (1 - dst.team if dst.team < 2 else 0)
	match dst.kind:
		"hero":
			dst.deaths += 1
			dst.respawn_t = 6.0 + 2.2 * dst.level + time / 120.0
			dst.recall_t = 0
			if killer_hero:
				kteam = killer_hero.team
				killer_hero.kills += 1
				killer_hero.gold += 300
				_give_xp(killer_hero, 110.0 + 35.0 * dst.level)
			if kteam < 2:
				score[kteam] += 1
			for hid in dst.hero_hits:
				if dst.hero_hits[hid] > time - 10.0 and (killer_hero == null or hid != killer_hero.id):
					var a: U = units.get(hid)
					if a and a.team != dst.team:
						a.assists += 1
						a.gold += 120
						_give_xp(a, 50.0 + 15.0 * dst.level)
			dst.hero_hits.clear()
			events.append({"t": "kill", "a": killer_hero.id if killer_hero else (src.id if src else 0), "b": dst.id})
		"melee", "ranged", "siege":
			if killer_hero and src == killer_hero:
				killer_hero.gold += dst.gold_value
				killer_hero.cs += 1
			_share_xp(dst.pos, 1 - dst.team, dst.xp_value, 14.0)
			_remove(dst)
		"monster", "boss":
			var team := killer_hero.team if killer_hero else kteam
			if dst.kind == "boss":
				team_buff_t[team] = time + 90.0
				for id in order:
					var h: U = units.get(id)
					if h and h.kind == "hero" and h.team == team:
						h.gold += 120
						_give_xp(h, 120)
				events.append({"t": "boss", "team": team})
			elif killer_hero:
				killer_hero.gold += 80
				killer_hero.cs += 4
			_share_xp(dst.pos, team, dst.xp_value, 14.0)
			for c in camps:
				if c.id == dst.id:
					c.id = 0
					c.t = 150.0 if c.kind == 1 else 60.0
			_remove(dst)
		"tower":
			_vuln_dirty = true
			for id in order:
				var h: U = units.get(id)
				if h and h.kind == "hero" and h.team != dst.team:
					h.gold += 150
			events.append({"t": "tower", "team": dst.team, "lane": dst.lane, "x": dst.pos.x, "z": dst.pos.y})
		"nexus":
			winner = 1 - dst.team
			events.append({"t": "win", "team": winner})


func _remove(u: U) -> void:
	units.erase(u.id)
	order.erase(u.id)
	events.append({"t": "die", "a": u.id, "x": u.pos.x, "z": u.pos.y, "team": u.team})


func _share_xp(pos: Vector2, team: int, amount: float, r: float) -> void:
	if team > 1:
		return
	var hs := allies_in(pos, team, r)
	if hs.is_empty():
		return
	var each := amount * (1.0 + 0.15 * (hs.size() - 1)) / hs.size()
	for h: U in hs:
		_give_xp(h, each)


func _give_xp(h: U, amount: float) -> void:
	if h.level >= 15:
		return
	h.xp += amount
	while h.level < 15 and h.xp >= Data.xp_to_next(h.level):
		h.xp -= Data.xp_to_next(h.level)
		h.level += 1
		_recalc_hero(h)
		h.hp = minf(h.max_hp, h.hp + Data.HEROES[h.hero].hp_lvl)
		events.append({"t": "lvl", "a": h.id, "lvl": h.level})


func apply_effects(src: U, dst: U, a: Dictionary) -> void:
	if a.has("stun"):
		dst.stun_t = maxf(dst.stun_t, a.stun * (0.6 if dst.kind == "boss" else 1.0))
		dst.recall_t = 0
	if a.has("slow"):
		dst.slow = maxf(dst.slow if dst.slow_t > 0 else 0.0, a.slow)
		dst.slow_t = maxf(dst.slow_t, a.get("slow_dur", 1.5))


func ability_damage(u: U, a: Dictionary) -> float:
	return a.get("d", 0) + a.get("dl", 0) * (u.level - 1) + a.get("r", 0.6) * (u.b_atk + u.b_pw)


# ---------------------------------------------------------------- comandos

func buy(u: U, item: int) -> bool:
	if item < 0 or item >= Data.ITEMS.size() or u.items.size() >= 6:
		return false
	var cost: float = Data.ITEMS[item].cost
	if u.gold < cost:
		return false
	if not u.dead and u.pos.distance_to(Data.FOUNTAIN_POS[u.team]) > Data.FOUNTAIN_RADIUS + 3:
		return false
	u.gold -= cost
	u.items.append(item)
	_recalc_hero(u)
	events.append({"t": "buy", "a": u.id, "item": item})
	return true


func start_recall(u: U) -> void:
	if u.dead or u.stun_t > 0:
		return
	u.recall_t = 4.0
	u.target = 0
	events.append({"t": "recall", "a": u.id})


func can_cast(u: U, idx: int) -> bool:
	if u.dead or u.stun_t > 0 or u.dash_t > 0:
		return false
	if idx == 3 and u.level < 5:
		return false
	return u.cds[idx] <= 0


## dir: direção do arrasto (comprimento 0..1). auto = mirar sozinho.
func cast(u: U, idx: int, dir: Vector2, auto: bool) -> bool:
	if idx < 0 or idx > 3 or not can_cast(u, idx):
		return false
	var a: Dictionary = Data.HEROES[u.hero].abilities[idx]
	var rng: float = a.get("range", 0.0)
	var point := u.pos
	if auto or dir.length() < 0.15:
		var t := _auto_target(u, a)
		if t:
			dir = (t.pos - u.pos)
			point = t.pos
			if dir.length() > rng and rng > 0:
				point = u.pos + dir.normalized() * rng
			dir = dir.normalized()
		else:
			dir = Vector2.from_angle(u.rot)
			point = u.pos + dir * rng * 0.7
	else:
		var frac := clampf(dir.length(), 0.0, 1.0)
		dir = dir.normalized()
		point = u.pos + dir * rng * frac
	if dir.length() < 0.01:
		dir = Vector2.from_angle(u.rot)
	u.rot = dir.angle()
	u.recall_t = 0
	u.cds[idx] = a.cd * (1.0 - minf(0.3, u.b_pw / 400.0))
	_exec(u, a, dir, point)
	events.append({"t": "cast", "a": u.id, "ab": idx, "x": point.x, "z": point.y, "dx": dir.x, "dz": dir.y})
	return true


func _auto_target(u: U, a: Dictionary) -> U:
	var rng: float = a.get("range", 0.0)
	match a.type:
		"skillshot", "blast", "dash":
			var r := rng + 2.0
			var t := nearest_enemy(u, r, true, false)
			if t and t.kind != "hero":
				var th := nearest_enemy(u, r, true, false)
				t = th
			return t
		"blink":
			return null
	return null


func _exec(u: U, a: Dictionary, dir: Vector2, point: Vector2) -> void:
	match a.type:
		"skillshot":
			projectiles.append({
				"team": u.team, "src": u.id, "pos": u.pos + dir * 0.8, "vel": dir * float(a.speed),
				"left": float(a.range), "width": float(a.width), "dmg": ability_damage(u, a),
				"ab": a, "pierce": a.get("pierce", false), "hit": {}, "kind": 1, "hero": u.hero,
			})
		"dash":
			var dist: float = a.dist
			u.dash_t = 0.22
			u.dash_v = dir * dist / 0.22
			u.dash_ab = a
			u.dash_hit = {}
			u.target = 0
		"blink":
			var dest := u.pos + dir * float(a.dist)
			events.append({"t": "blink", "a": u.id, "x": u.pos.x, "z": u.pos.y})
			u.pos = _clamp_map(dest)
			_push_out(u)
		"nova":
			_nova(u, u.pos, a)
		"blast":
			delayed.append({"at": time + float(a.delay), "src": u.id, "team": u.team, "pos": point, "ab": a,
				"dmg": ability_damage(u, a)})
			if a.get("leap", false):
				var d := point - u.pos
				var t: float = a.delay
				u.dash_t = t
				u.dash_v = d / t
				u.dash_ab = {}
				u.dash_hit = {}
		"buff":
			var targets := [u]
			if a.get("allies", 0.0) > 0:
				targets = allies_in(u.pos, u.team, a.allies)
			for t: U in targets:
				if a.has("shield"):
					t.shield = maxf(t.shield, a.shield + a.get("sl", 0) * (u.level - 1) + 0.3 * u.b_pw)
					t.shield_t = a.dur
				if a.has("haste"):
					t.haste = a.haste
					t.haste_t = a.dur
				if a.has("aspd"):
					t.aspd_mul = a.aspd
					t.aspd_t = a.dur
		"heal":
			var amt: float = a.heal + a.get("hl", 0) * (u.level - 1) + 0.4 * u.b_pw
			for t: U in allies_in(u.pos, u.team, a.radius):
				heal(t, amt)
	if a.has("then"):
		_exec(u, a.then, dir, point)


func _nova(u: U, center: Vector2, a: Dictionary) -> void:
	var dmg := ability_damage(u, a)
	for e: U in enemies_in(center, u.team, a.radius, false):
		apply_effects(u, e, a)
		damage(u, e, dmg)


# ---------------------------------------------------------------- loop

func tick(dt: float) -> void:
	if winner >= 0:
		return
	time += dt
	# Ondas de tropas
	wave_t -= dt
	if wave_t <= 0:
		wave_t = 30.0
		_spawn_wave()
	# Acampamentos
	for i in range(camps.size()):
		var c: Dictionary = camps[i]
		if c.id == 0:
			c.t -= dt
			if c.t <= 0:
				_spawn_monster(i)
	_refresh_alive()
	var ids := order.duplicate()
	for id in ids:
		var u: U = units.get(id)
		if u == null:
			continue
		_timers(u, dt)
		if u.dead:
			if u.kind == "hero":
				u.respawn_t -= dt
				u.gold += 2.0 * dt
				if u.respawn_t <= 0:
					_respawn(u)
			continue
		match u.kind:
			"hero":
				u.gold += 3.0 * dt
				_hero_think(u, dt)
			"melee", "ranged", "siege":
				_minion_think(u, dt)
			"tower", "nexus":
				_tower_think(u, dt)
			"monster", "boss":
				_monster_think(u, dt)
	_tick_projectiles(dt)
	_tick_delayed()
	_separate()


func _timers(u: U, dt: float) -> void:
	u.attack_cd -= dt
	for i in range(4):
		u.cds[i] = maxf(0.0, u.cds[i] - dt)
	if u.stun_t > 0:
		u.stun_t -= dt
	if u.slow_t > 0:
		u.slow_t -= dt
		if u.slow_t <= 0:
			u.slow = 0
	if u.shield_t > 0:
		u.shield_t -= dt
		if u.shield_t <= 0:
			u.shield = 0
	if u.haste_t > 0:
		u.haste_t -= dt
		if u.haste_t <= 0:
			u.haste = 1.0
	if u.aspd_t > 0:
		u.aspd_t -= dt
		if u.aspd_t <= 0:
			u.aspd_mul = 1.0
	if u.kind == "hero" and not u.dead:
		var f: Vector2 = Data.FOUNTAIN_POS[u.team]
		if u.pos.distance_to(f) < Data.FOUNTAIN_RADIUS:
			heal(u, u.max_hp * 0.12 * dt)
		elif time - u.last_dmg > 6.0:
			heal(u, u.max_hp * 0.008 * dt)
		var ef: Vector2 = Data.FOUNTAIN_POS[1 - u.team]
		if u.pos.distance_to(ef) < Data.FOUNTAIN_RADIUS:
			u.hp -= 600 * dt
			if u.hp <= 0:
				_kill(null, u)


func _respawn(u: U) -> void:
	u.dead = false
	u.hp = u.max_hp
	u.pos = _fountain_spot(u)
	u.stun_t = 0
	u.slow_t = 0
	u.slow = 0
	u.target = 0
	u.bot_state = {}
	events.append({"t": "respawn", "a": u.id})


func _spawn_wave() -> void:
	wave_n += 1
	var kinds := ["melee", "melee", "melee", "ranged", "ranged"]
	if wave_n % 3 == 0:
		kinds.append("siege")
	for team in [0, 1]:
		for lane in range(3):
			var path := Data.lane_path(lane, team)
			for k in range(kinds.size()):
				var kind: String = kinds[k]
				var m: Dictionary = Data.MINIONS[kind]
				var u := _new_unit(kind, team)
				var scale := 1.0 + 0.04 * (wave_n - 1)
				u.max_hp = m.hp * scale
				u.hp = u.max_hp
				u.atk = m.atk * (1.0 + 0.03 * (wave_n - 1))
				u.aspd = m.aspd
				u.arange = m.range
				u.speed = m.speed
				u.armor = m.armor
				u.radius = m.radius
				u.ranged = m.ranged
				u.gold_value = m.gold
				u.xp_value = m.xp
				u.lane = lane
				u.wp = 1
				var start := Data.point_along(path, 6.0 + k * 1.6)
				var side := (k % 2) * 1.2 - 0.6
				var dirv := (path[1] - path[0]).normalized()
				u.pos = start + Vector2(-dirv.y, dirv.x) * side
				u.rot = dirv.angle()


func _spawn_monster(i: int) -> void:
	var c: Dictionary = camps[i]
	var boss: bool = c.kind == 1
	var u := _new_unit("boss" if boss else "monster", Data.TEAM_NEUTRAL)
	var scale := 1.0 + time / 600.0
	u.max_hp = (3600.0 if boss else 800.0) * scale
	u.hp = u.max_hp
	u.atk = (85.0 if boss else 34.0) * scale
	u.aspd = 0.7
	u.arange = 2.6 if boss else 1.8
	u.armor = 30 if boss else 15
	u.speed = 6.5
	u.radius = 2.0 if boss else 1.0
	u.xp_value = 160.0 if boss else 70.0
	u.pos = c.pos
	u.home = c.pos
	u.camp = i
	u.name = "Titã do Rio" if boss else "Fera da Selva"
	c.id = u.id
	if boss:
		events.append({"t": "boss_spawn", "x": c.pos.x, "z": c.pos.y})


# ---------------------------------------------------------------- movimento

func _clamp_map(p: Vector2) -> Vector2:
	return p.clamp(Vector2(-Data.MAP_HALF, -Data.MAP_HALF), Vector2(Data.MAP_HALF, Data.MAP_HALF))


func move_unit(u: U, dir: Vector2, dt: float) -> void:
	if u.stun_t > 0 or dir.length() < 0.01:
		return
	if dir.length() > 1.0:
		dir = dir.normalized()
	dir = _steer(u, dir)
	_move_raw(u, dir, dt)


func _move_raw(u: U, dir: Vector2, dt: float) -> void:
	if u.stun_t > 0:
		return
	var spd := u.speed * u.haste * (1.0 - (u.slow if u.slow_t > 0 else 0.0))
	u.pos = _clamp_map(u.pos + dir * spd * dt)
	u.rot = lerp_angle(u.rot, dir.angle(), minf(1.0, dt * 14.0))
	_push_out(u)


const CELL := 2.0
var grid := AStarGrid2D.new()


func _build_grid() -> void:
	var n := int(ceil(Data.MAP_HALF * 2.0 / CELL)) + 1
	grid.region = Rect2i(0, 0, n, n)
	grid.cell_size = Vector2(CELL, CELL)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	for x in range(n):
		for y in range(n):
			var w := _cell_world(Vector2i(x, y))
			for o in obstacles:
				if w.distance_to(Vector2(o.x, o.y)) < o.z + 1.1:
					grid.set_point_solid(Vector2i(x, y), true)
					break


func _cell_world(c: Vector2i) -> Vector2:
	return Vector2(c.x * CELL - Data.MAP_HALF, c.y * CELL - Data.MAP_HALF)


func _world_cell(p: Vector2) -> Vector2i:
	var n := grid.region.size.x - 1
	return Vector2i(clampi(roundi((p.x + Data.MAP_HALF) / CELL), 0, n), clampi(roundi((p.y + Data.MAP_HALF) / CELL), 0, n))


func _free_cell(c: Vector2i) -> Vector2i:
	if not grid.is_point_solid(c):
		return c
	for r in range(1, 4):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				var k := c + Vector2i(dx, dy)
				if grid.is_in_boundsv(k) and not grid.is_point_solid(k):
					return k
	return c


func blocked(a: Vector2, b: Vector2, rad: float) -> bool:
	for o in obstacles:
		var c := Vector2(o.x, o.y)
		if Data.dist_to_segment(c, a, b) < o.z + rad + 0.15:
			return true
	return false


func move_to(u: U, p: Vector2, dt: float, stop := 0.3) -> bool:
	var d := p - u.pos
	if d.length() <= stop:
		return true
	if u.kind == "hero" or u.kind == "monster" or u.kind == "boss":
		if blocked(u.pos, p, u.radius):
			if u.path.is_empty() or u.path_goal.distance_to(p) > 3.0 or u.path_i >= u.path.size():
				u.path = grid.get_point_path(_free_cell(_world_cell(u.pos)), _free_cell(_world_cell(p)))
				for i in range(u.path.size()):
					u.path[i] -= Vector2(Data.MAP_HALF, Data.MAP_HALF)
				u.path_goal = p
				u.path_i = 1 if u.path.size() > 1 else 0
			# Pula pontos já visíveis
			while u.path_i < u.path.size() - 1 and not blocked(u.pos, u.path[u.path_i + 1], u.radius):
				u.path_i += 1
			if u.path_i < u.path.size():
				var wpt := u.path[u.path_i]
				if u.pos.distance_to(wpt) < 0.8:
					u.path_i += 1
				var dirw := (wpt - u.pos)
				if dirw.length() > 0.01:
					_move_raw(u, dirw.normalized(), dt)
				return false
		else:
			u.path = PackedVector2Array()
	var step := d.normalized()
	if d.length() < u.speed * dt:
		step *= d.length() / (u.speed * dt)
	move_unit(u, step, dt)
	return false


func _steer(u: U, dir: Vector2) -> Vector2:
	var out := dir.normalized()
	for o in obstacles:
		var c := Vector2(o.x, o.y)
		var to := c - u.pos
		var dist := to.length()
		var clear: float = o.z + u.radius + 1.6
		if dist > clear + 2.5 or dist < 0.01:
			continue
		var ahead := to.dot(out)
		if ahead <= 0:
			continue
		var lateral := absf(to.cross(out))
		if lateral < clear:
			var side := 1.0 if to.cross(out) < 0 else -1.0
			var perp := Vector2(-out.y, out.x) * side
			out = (out + perp * (1.0 - lateral / clear) * 1.6).normalized()
	return out


func _push_out(u: U) -> void:
	for o in obstacles:
		var c := Vector2(o.x, o.y)
		var r: float = o.z + u.radius
		var d := u.pos - c
		if d.length() < r:
			u.pos = c + (d.normalized() if d.length() > 0.01 else Vector2.RIGHT) * r
	if u.kind == "tower" or u.kind == "nexus":
		return
	for id in order:
		var s: U = units.get(id)
		if s == null or s.dead or (s.kind != "tower" and s.kind != "nexus"):
			continue
		var r2 := s.radius + u.radius
		var d2 := u.pos - s.pos
		if d2.length() < r2:
			u.pos = s.pos + (d2.normalized() if d2.length() > 0.01 else Vector2.RIGHT) * r2


func _separate() -> void:
	var mob := []
	for id in order:
		var u: U = units[id]
		if not u.dead and u.kind != "tower" and u.kind != "nexus" and u.dash_t <= 0:
			mob.append(u)
	for i in range(mob.size()):
		var a: U = mob[i]
		for j in range(i + 1, mob.size()):
			var b: U = mob[j]
			var r := (a.radius + b.radius) * 0.85
			var d := b.pos - a.pos
			var l := d.length()
			if l < r and l > 0.001:
				var push := d / l * (r - l) * 0.5
				a.pos -= push
				b.pos += push


# ---------------------------------------------------------------- ataques

func _in_range(u: U, t: U) -> bool:
	return u.pos.distance_to(t.pos) <= u.arange + t.radius + u.radius * 0.5


func _try_attack(u: U, t: U) -> bool:
	if u.stun_t > 0:
		return false
	u.rot = (t.pos - u.pos).angle()
	if u.attack_cd > 0:
		return true
	u.attack_cd = 1.0 / maxf(0.2, u.aspd * u.aspd_mul)
	u.recall_t = 0
	if u.ranged:
		projectiles.append({"team": u.team, "src": u.id, "target": t.id, "pos": u.pos,
			"speed": 30.0 if u.kind == "hero" else 24.0, "dmg": u.atk, "kind": 0,
			"hero": u.hero if u.kind == "hero" else -1})
	else:
		damage(u, t, u.atk)
	events.append({"t": "atk", "a": u.id, "b": t.id})
	return true


func _chase_attack(u: U, t: U, dt: float) -> void:
	if _in_range(u, t):
		_try_attack(u, t)
	else:
		move_to(u, t.pos, dt, u.arange * 0.8)


func _tick_projectiles(dt: float) -> void:
	var keep := []
	for p in projectiles:
		if p.kind == 0:
			var t: U = units.get(p.target)
			if t == null or t.dead:
				continue
			var d: Vector2 = t.pos - p.pos
			var step: float = p.speed * dt
			if d.length() <= step + t.radius * 0.5:
				damage(units.get(p.src), t, p.dmg)
				continue
			p.pos += d.normalized() * step
			keep.append(p)
		else:
			var step2: Vector2 = p.vel * dt
			p.pos += step2
			p.left -= step2.length()
			var src: U = units.get(p.src)
			var done := false
			for e: U in enemies_in(p.pos, p.team, p.width * 0.5, false):
				if p.hit.has(e.id):
					continue
				p.hit[e.id] = true
				if src:
					apply_effects(src, e, p.ab)
					damage(src, e, p.dmg)
				else:
					damage(null, e, p.dmg)
				if not p.pierce:
					done = true
					break
				p.dmg *= 0.8
			if done or p.left <= 0:
				events.append({"t": "pop", "x": p.pos.x, "z": p.pos.y, "hero": p.hero})
				continue
			keep.append(p)
	projectiles = keep


func _tick_delayed() -> void:
	var keep := []
	for d in delayed:
		if time >= d.at:
			var src: U = units.get(d.src)
			for e: U in enemies_in(d.pos, d.team, d.ab.radius, false):
				if src:
					apply_effects(src, e, d.ab)
				damage(src, e, d.dmg)
			events.append({"t": "boom", "x": d.pos.x, "z": d.pos.y, "r": d.ab.radius, "team": d.team})
		else:
			keep.append(d)
	delayed = keep


# ---------------------------------------------------------------- IA

func _hero_think(u: U, dt: float) -> void:
	if u.dash_t > 0:
		u.dash_t -= dt
		u.pos = _clamp_map(u.pos + u.dash_v * dt)
		if not u.dash_ab.is_empty():
			for e: U in enemies_in(u.pos, u.team, 1.4, false):
				if not u.dash_hit.has(e.id):
					u.dash_hit[e.id] = true
					apply_effects(u, e, u.dash_ab)
					damage(u, e, ability_damage(u, u.dash_ab))
		if u.dash_t <= 0:
			_push_out(u)
		return
	if u.recall_t > 0:
		u.recall_t -= dt
		if u.recall_t <= 0:
			u.pos = _fountain_spot(u)
			events.append({"t": "recalled", "a": u.id})
		return
	var inp: Dictionary
	if u.bot:
		inp = Bot.think(self, u, dt)
	else:
		inp = inputs.get(u.id, {})
	# Comandos pontuais (casts, compra, voltar)
	for c in inp.get("casts", []):
		cast(u, c[0], c[1], c[2])
	if inp.get("recall", false):
		start_recall(u)
		inp["recall"] = false
	for it in inp.get("buy", []):
		buy(u, it)
	if not u.bot:
		inp["casts"] = []
		inp["buy"] = []
	if u.stun_t > 0 or u.recall_t > 0:
		return
	var mv: Vector2 = inp.get("move", Vector2.ZERO)
	var focus: int = inp.get("focus", 0)
	if mv.length() > 0.15:
		u.target = 0
		move_unit(u, mv, dt)
		return
	if focus and alive(focus) and targetable(units[focus]):
		_chase_attack(u, units[focus], dt)
		return
	if inp.get("attack", false):
		var t: U = null
		if u.target and alive(u.target) and targetable(units[u.target]) and u.pos.distance_to(units[u.target].pos) < u.arange + 5:
			t = units[u.target]
		else:
			t = nearest_enemy(u, u.arange + 4.0, true)
		if t:
			u.target = t.id
			_chase_attack(u, t, dt)
	var goto = inp.get("goto", null)
	if goto != null:
		move_to(u, goto, dt, 0.6)


func _minion_think(u: U, dt: float) -> void:
	if u.stun_t > 0:
		return
	var t: U = null
	if u.target and alive(u.target) and targetable(units[u.target]):
		var cur: U = units[u.target]
		if u.pos.distance_to(cur.pos) < 10.0:
			t = cur
	# Defender heróis aliados atacados
	var helper: U = null
	for e: U in enemies_in(u.pos, u.team, 8.0, false):
		if e.kind == "hero" and time - e.last_hero_dmg < 1.5:
			helper = e
			break
	if helper and (t == null or t.kind != "hero"):
		t = helper
	if t == null:
		var best: U = null
		var bd := 1e9
		for e: U in enemies_in(u.pos, u.team, 7.5):
			if e.team == Data.TEAM_NEUTRAL:
				continue
			var d := u.pos.distance_to(e.pos)
			if e.kind == "hero":
				d += 6.0
			if d < bd:
				bd = d
				best = e
		t = best
	if t:
		u.target = t.id
		_chase_attack(u, t, dt)
		return
	u.target = 0
	var path := Data.lane_path(u.lane, u.team)
	if u.wp >= path.size():
		var nx := _enemy_nexus(u.team)
		if nx:
			move_to(u, nx.pos, dt, 2.0)
		return
	if move_to(u, path[u.wp], dt, 2.5):
		u.wp += 1


func _enemy_nexus(team: int) -> U:
	for id in order:
		var u: U = units[id]
		if u.kind == "nexus" and u.team != team:
			return u
	return null


func _tower_think(u: U, dt: float) -> void:
	var t: U = null
	if u.target and alive(u.target):
		var cur: U = units[u.target]
		if _in_range(u, cur):
			t = cur
	for e: U in enemies_in(u.pos, u.team, u.arange):
		if e.kind == "hero" and time - e.last_hero_dmg < 1.0:
			# Herói atacou um aliado embaixo da torre
			for a: U in allies_in(u.pos, u.team, u.arange):
				if a.hero_hits.get(e.id, -99.0) > time - 1.0:
					t = e
					break
	if t == null:
		var best: U = null
		var bd := 1e9
		for e: U in enemies_in(u.pos, u.team, u.arange):
			if e.team == Data.TEAM_NEUTRAL:
				continue
			var d := u.pos.distance_to(e.pos) + (20.0 if e.kind == "hero" else 0.0)
			if d < bd:
				bd = d
				best = e
		t = best
	if t:
		u.target = t.id
		var was := u.attack_cd
		_try_attack(u, t)
		if was <= 0 and t.kind == "hero":
			pass
	else:
		u.target = 0


func _monster_think(u: U, dt: float) -> void:
	if u.stun_t > 0:
		return
	var leash := 12.0 if u.kind == "monster" else 16.0
	if u.target and alive(u.target):
		var t: U = units[u.target]
		if t.pos.distance_to(u.home) > leash or u.pos.distance_to(u.home) > leash:
			u.target = 0
		else:
			_chase_attack(u, t, dt)
			return
	u.target = 0
	if move_to(u, u.home, dt, 0.5):
		heal(u, u.max_hp * 0.25 * dt)
	else:
		heal(u, u.max_hp * 0.1 * dt)


# ---------------------------------------------------------------- rede

const STRIDE := 13
const HEADER := 12  # bytes: tempo (float), placar x2, vencedor, n unidades


## Estado compacto em inteiros de 16 bits para caber em poucos pacotes UDP.
func snapshot() -> PackedByteArray:
	var n := order.size()
	var buf := PackedByteArray()
	buf.resize(HEADER + n * STRIDE * 2 + 2 + projectiles.size() * 10)
	buf.encode_float(0, time)
	buf.encode_s16(4, score[0])
	buf.encode_s16(6, score[1])
	buf.encode_s16(8, winner)
	buf.encode_s16(10, n)
	var o := HEADER
	for id in order:
		var u: U = units[id]
		var flags := 0
		if u.dead: flags |= 1
		if u.stun_t > 0: flags |= 2
		if u.slow_t > 0: flags |= 4
		if u.recall_t > 0: flags |= 8
		if u.haste_t > 0 or u.aspd_t > 0: flags |= 16
		if (u.kind == "tower" or u.kind == "nexus") and not vulnerable(u): flags |= 32
		if u.dash_t > 0: flags |= 64
		if u.team < 2 and team_buff_t[u.team] > time: flags |= 128
		var sub := u.hero
		if u.kind == "tower": sub = u.tier
		buf.encode_s16(o, u.id % 32000)
		buf.encode_s16(o + 2, Data.KIND_CODE[u.kind])
		buf.encode_s16(o + 4, u.team)
		buf.encode_s16(o + 6, sub)
		buf.encode_s16(o + 8, roundi(u.pos.x * 100.0))
		buf.encode_s16(o + 10, roundi(u.pos.y * 100.0))
		buf.encode_s16(o + 12, roundi(wrapf(u.rot, -PI, PI) * 10000.0))
		buf.encode_s16(o + 14, mini(ceili(u.hp), 32000))
		buf.encode_s16(o + 16, mini(ceili(u.max_hp), 32000))
		buf.encode_s16(o + 18, flags)
		buf.encode_s16(o + 20, u.level)
		buf.encode_s16(o + 22, mini(ceili(u.shield), 32000))
		buf.encode_s16(o + 24, mini(ceili(u.respawn_t * 10.0), 32000))
		o += STRIDE * 2
	buf.encode_s16(o, projectiles.size())
	o += 2
	for p in projectiles:
		buf.encode_s16(o, roundi(p.pos.x * 100.0))
		buf.encode_s16(o + 2, roundi(p.pos.y * 100.0))
		buf.encode_s16(o + 4, p.kind)
		buf.encode_s16(o + 6, p.team)
		buf.encode_s16(o + 8, p.hero)
		o += 10
	return buf


func private_info(u: U) -> Dictionary:
	return {
		"gold": int(u.gold), "xp": u.xp, "next": Data.xp_to_next(u.level), "lvl": u.level,
		"cds": u.cds.duplicate(), "items": u.items.duplicate(), "respawn": u.respawn_t,
		"atk": u.atk, "armor": u.armor, "pw": u.b_pw, "speed": u.speed, "recall": u.recall_t,
	}


func board() -> Array:
	var out := []
	for id in order:
		var u: U = units[id]
		if u.kind == "hero":
			out.append([u.id, u.team, u.hero, u.name, u.level, u.kills, u.deaths, u.assists, u.cs, u.items.duplicate(), u.bot])
	return out


func take_events() -> Array:
	var e := events
	events = []
	return e
