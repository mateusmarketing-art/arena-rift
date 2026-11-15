class_name Game
extends Node
## Uma partida. No host roda a simulação; nos convidados só desenha o que chega.

signal finished

var slots: Array = []
var my_peer := 1
var my_id := 1
var my_team := 0
var is_server := true
var autoplay := false
var test_log := false

var sim: Sim
var view: WorldView
var hud: Hud
var cam: Camera3D
var input := {"move": Vector2.ZERO, "attack": false, "casts": [], "buy": [], "recall": false}
var peer_hero := {}
var pending_events := []
var snap_t := 0.0
var priv_t := 0.0
var board_t := 0.0
var input_t := 0.0
var cam_target := Vector3.ZERO
var last_snap_ms := 0
var aiming := -1


func setup(p_slots: Array, p_my_peer: int, server: bool) -> void:
	slots = p_slots
	my_peer = p_my_peer
	is_server = server
	for i in range(slots.size()):
		if not slots[i].bot and slots[i].peer == my_peer:
			my_id = i + 1
		if not slots[i].bot:
			peer_hero[slots[i].peer] = i + 1
	my_team = slots[my_id - 1].team


func _ready() -> void:
	name = "Game"
	view = WorldView.new()
	view.local_hero = my_id
	add_child(view)
	cam = Camera3D.new()
	cam.fov = 48
	cam.far = 400
	add_child(cam)
	cam.current = true
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Hud.new()
	hud.view = view
	hud.camera = cam
	hud.my_id = my_id
	hud.my_team = my_team
	hud.my_hero = slots[my_id - 1].hero
	hud.flip = my_team == Data.TEAM_RED
	layer.add_child(hud)
	hud.move_changed.connect(func(v): input.move = v)
	hud.attack_changed.connect(func(h): input.attack = h)
	hud.cast_requested.connect(_on_cast)
	hud.aim_changed.connect(_on_aim)
	hud.recall_requested.connect(_on_recall)
	hud.buy_requested.connect(_on_buy)
	hud.leave_requested.connect(_leave)
	Net.peer_left.connect(_on_peer_left)
	Net.message.connect(func(t): hud.push_feed(t, Color(1, 0.6, 0.5)))
	var spawn: Vector2 = Data.FOUNTAIN_POS[my_team]
	cam_target = Vector3(spawn.x, 0, spawn.y)
	if is_server:
		sim = Sim.new()
		var s2 := slots.duplicate(true)
		if autoplay:
			s2[my_id - 1].bot = true
		sim.setup(s2)
		sim.inputs[my_id] = input
		for p in peer_hero:
			if peer_hero[p] != my_id:
				sim.inputs[peer_hero[p]] = {"move": Vector2.ZERO, "attack": false, "casts": [], "buy": [], "recall": false}
	hud.push_feed("Bem-vindo à Arena! Destrua o Nexus inimigo.", Color(1, 0.9, 0.5))


func _physics_process(dt: float) -> void:
	if is_server:
		sim.tick(dt)
		view.apply(sim.snapshot())
		var evs := sim.take_events()
		view.on_events(evs)
		_feed(evs)
		var me: Sim.U = sim.units[my_id]
		hud.priv = sim.private_info(me)
		board_t -= dt
		if board_t <= 0:
			board_t = 1.0
			hud.board = sim.board()
		if Net.online:
			pending_events.append_array(evs)
			snap_t -= dt
			if snap_t <= 0:
				snap_t = 1.0 / 20.0
				var snap := sim.snapshot()
				_s_snap.rpc(snap.size(), snap.compress(FileAccess.COMPRESSION_ZSTD))
				if not pending_events.is_empty():
					_s_events.rpc(pending_events)
					pending_events = []
			priv_t -= dt
			if priv_t <= 0:
				priv_t = 0.2
				for p in peer_hero:
					if p != my_peer and multiplayer.get_peers().has(p):
						_s_priv.rpc_id(p, sim.private_info(sim.units[peer_hero[p]]))
			if board_t >= 0.99:
				_s_board.rpc(hud.board)
		if test_log and int(sim.time * 30) % 300 == 0:
			print("[autotest] t=%d placar %d x %d nivel %d unidades %d nos %d hud_ok %s" % [sim.time, sim.score[0], sim.score[1], me.level, sim.order.size(), view.nodes.size(), hud.priv.has("gold")])
	else:
		input_t -= dt
		if test_log and Engine.get_physics_frames() % 150 == 0:
			print("[cliente] nos %d tempo %.0f ultimo snapshot ha %d ms ouro %s" % [view.nodes.size(), view.time, Time.get_ticks_msec() - last_snap_ms, hud.priv.get("gold", "-")])
		if input_t <= 0:
			input_t = 1.0 / 20.0
			_c_move.rpc_id(1, input.move, input.attack)


func _process(dt: float) -> void:
	var target := view.hero_world_pos(my_id)
	if target != Vector3.ZERO:
		cam_target = cam_target.lerp(target, 1.0 - exp(-dt * 8.0))
	var off := Vector3(0, 31, 19)
	if my_team == Data.TEAM_RED:
		off = Vector3(0, 31, -19)
	cam.position = cam_target + off
	cam.look_at(cam_target + Vector3(0, 1, 0), Vector3.UP)


# ---------------------------------------------------------------- comandos locais

func _on_cast(idx: int, dir: Vector2, auto: bool) -> void:
	view.hide_aim()
	aiming = -1
	if is_server:
		input.casts.append([idx, dir, auto])
	else:
		_c_cast.rpc_id(1, idx, dir, auto)


func _on_aim(idx: int, dir: Vector2) -> void:
	aiming = idx
	if idx < 0:
		view.hide_aim()
		return
	var ab: Dictionary = Data.HEROES[slots[my_id - 1].hero].abilities[idx]
	view.show_aim(my_id, ab, dir)


func _on_recall() -> void:
	if is_server:
		input.recall = true
	else:
		_c_recall.rpc_id(1)


func _on_buy(item: int) -> void:
	if is_server:
		input.buy.append(item)
	else:
		_c_buy.rpc_id(1, item)


func _on_peer_left(peer: int) -> void:
	if is_server and peer_hero.has(peer):
		var u: Sim.U = sim.units.get(peer_hero[peer])
		if u:
			u.bot = true
			hud.push_feed("%s saiu; um bot assumiu o herói." % u.name, Color(1, 0.7, 0.4))


func _leave() -> void:
	Net.leave()
	finished.emit()
	queue_free()


func _hero_name(id: int) -> String:
	if id >= 1 and id <= slots.size():
		return slots[id - 1].name
	return ""


func _feed(evs: Array) -> void:
	for e in evs:
		match e.t:
			"kill":
				var killer := _hero_name(e.a)
				var victim := _hero_name(e.b)
				var vteam: int = slots[e.b - 1].team if e.b >= 1 and e.b <= slots.size() else 0
				var col := Color(0.45, 0.75, 1.0) if vteam != my_team else Color(1.0, 0.45, 0.4)
				if killer == "":
					hud.push_feed("%s foi abatido" % victim, col)
				else:
					hud.push_feed("%s abateu %s" % [killer, victim], col)
			"tower":
				var mine: bool = e.team == my_team
				hud.push_feed("%s: torre %s destruída!" % [Data.LANE_NAMES[e.lane], "aliada" if mine else "inimiga"], Color(1.0, 0.45, 0.4) if mine else Color(0.45, 0.75, 1.0))
			"boss":
				hud.push_feed("Time %s derrotou o Titã do Rio! +12%% de dano por 90 s" % Data.TEAM_NAMES[e.team], Color(0.5, 1.0, 0.9))
			"boss_spawn":
				hud.push_feed("O Titã do Rio apareceu!", Color(0.5, 1.0, 0.9))
			"lvl":
				if e.a == my_id and e.lvl == 5:
					hud.push_feed("Nível 5: sua habilidade suprema (R) foi liberada!", Color(1, 0.85, 0.3))


# ---------------------------------------------------------------- RPC

@rpc("any_peer", "unreliable_ordered")
func _c_move(mv: Vector2, atk: bool) -> void:
	if not is_server:
		return
	var hid: int = peer_hero.get(multiplayer.get_remote_sender_id(), 0)
	if hid and sim.inputs.has(hid):
		sim.inputs[hid].move = mv.limit_length(1.0)
		sim.inputs[hid].attack = atk


@rpc("any_peer", "reliable")
func _c_cast(idx: int, dir: Vector2, auto: bool) -> void:
	if not is_server:
		return
	var hid: int = peer_hero.get(multiplayer.get_remote_sender_id(), 0)
	if hid and sim.inputs.has(hid):
		sim.inputs[hid].casts.append([clampi(idx, 0, 3), dir.limit_length(1.0), auto])


@rpc("any_peer", "reliable")
func _c_recall() -> void:
	if not is_server:
		return
	var hid: int = peer_hero.get(multiplayer.get_remote_sender_id(), 0)
	if hid and sim.inputs.has(hid):
		sim.inputs[hid].recall = true


@rpc("any_peer", "reliable")
func _c_buy(item: int) -> void:
	if not is_server:
		return
	var hid: int = peer_hero.get(multiplayer.get_remote_sender_id(), 0)
	if hid and sim.inputs.has(hid):
		sim.inputs[hid].buy.append(item)


@rpc("authority", "unreliable_ordered")
func _s_snap(raw_size: int, comp: PackedByteArray) -> void:
	if raw_size <= 0 or raw_size > 65536:
		return
	var buf := comp.decompress(raw_size, FileAccess.COMPRESSION_ZSTD)
	if buf.size() != raw_size:
		return
	last_snap_ms = Time.get_ticks_msec()
	view.apply(buf)


@rpc("authority", "reliable")
func _s_events(evs: Array) -> void:
	view.on_events(evs)
	_feed(evs)


@rpc("authority", "unreliable_ordered")
func _s_priv(d: Dictionary) -> void:
	hud.priv = d


@rpc("authority", "reliable")
func _s_board(b: Array) -> void:
	hud.board = b
