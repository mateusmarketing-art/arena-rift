extends SceneTree
## Teste rápido usado no GitHub: 3 minutos de partida só com bots.

func _init() -> void:
	var slots := Net_slots()
	var sim := Sim.new()
	sim.setup(slots)
	while sim.time < 180.0:
		sim.tick(1.0 / 30.0)
		sim.take_events()
	var levels := []
	for i in range(1, 11):
		levels.append(sim.units[i].level)
	print("Teste rápido OK: %d s simulados, placar %d x %d, níveis %s, pacote %d bytes" % [
		sim.time, sim.score[0], sim.score[1], levels, sim.snapshot().size()])
	quit()


func Net_slots() -> Array:
	var slots := []
	for team in [0, 1]:
		for h in range(5):
			slots.append({"team": team, "hero": h, "name": "Bot", "bot": true})
	return slots
