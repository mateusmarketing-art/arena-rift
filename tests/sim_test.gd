extends SceneTree
## Partida 5v5 completa só com bots, sem gráficos. Uso:
## godot --headless --path . --script tests/sim_test.gd

func _init() -> void:
	var slots := []
	for team in [0, 1]:
		for h in range(5):
			slots.append({"team": team, "hero": h, "name": "Bot %s" % Data.HEROES[h].name, "bot": true})
	var sim := Sim.new()
	sim.setup(slots)
	var dt := 1.0 / 30.0
	var next_report := 60.0
	var max_units := 0
	var t0 := Time.get_ticks_msec()
	var stuck := {}
	var last_pos := {}
	while sim.winner < 0 and sim.time < 40.0 * 60.0:
		sim.tick(dt)
		sim.take_events()
		max_units = maxi(max_units, sim.order.size())
		if sim.time >= next_report:
			next_report += 60.0
			var towers := [0, 0]
			for id in sim.order:
				var u: Sim.U = sim.units[id]
				if u.kind == "tower" and not u.dead:
					towers[u.team] += 1
			var lv := []
			for i in range(1, 11):
				var h: Sim.U = sim.units[i]
				lv.append("%d" % h.level)
				var key := i
				if last_pos.has(key) and last_pos[key].distance_to(h.pos) < 1.0 and not h.dead and h.pos.distance_to(Data.FOUNTAIN_POS[h.team]) > 12:
					stuck[key] = stuck.get(key, 0) + 1
				last_pos[key] = h.pos
			print("min %2d | placar %d x %d | torres %d x %d | unidades %3d | niveis %s" % [
				int(sim.time / 60), sim.score[0], sim.score[1], towers[0], towers[1], sim.order.size(), ",".join(lv)])
	var snap := sim.snapshot()
	print("vencedor: ", Data.TEAM_NAMES[sim.winner] if sim.winner >= 0 else "nenhum", " em ", int(sim.time / 60), " min")
	print("max unidades: ", max_units, " | snapshot bytes: ", snap.size(), " | parados(min): ", stuck)
	for b in sim.board():
		print("  %s %-8s nv%2d %2d/%2d/%2d cs %3d itens %s" % [Data.TEAM_NAMES[b[1]], Data.HEROES[b[2]].name, b[4], b[5], b[6], b[7], b[8], b[9]])
	var ms := Time.get_ticks_msec() - t0
	print("tempo real: %d ms (%.2f ms por ciclo)" % [ms, ms / (sim.time * 30.0)])
	quit(0 if sim.winner >= 0 else 1)
