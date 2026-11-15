extends Node
## Autoload "Net": sala (lobby), descoberta no Wi-Fi e conexão ENet.

signal lobby_changed
signal rooms_changed
signal game_started(slots: Array, my_peer: int)
signal message(text: String)
signal peer_left(peer: int)
signal joined

var online := false
var is_host := false
var in_game := false
var players := {}      # peer -> {name, team, hero}
var rooms := {}        # ip -> {name, count, t}
var my_name := "Jogador"
var my_team := 0
var my_hero := 0

var _bcast: PacketPeerUDP
var _listen: PacketPeerUDP
var _bcast_t := 0.0


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(func(): message.emit("Não foi possível conectar à sala."); leave())
	multiplayer.server_disconnected.connect(func(): message.emit("A conexão com a sala caiu."); leave())
	_load_settings()


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://config.cfg") == OK:
		my_name = cfg.get_value("player", "name", my_name)
		my_hero = cfg.get_value("player", "hero", 0)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("player", "name", my_name)
	cfg.set_value("player", "hero", my_hero)
	cfg.save("user://config.cfg")


func local_ips() -> Array:
	var out := []
	for ip in IP.get_local_addresses():
		if ip.begins_with("192.168.") or ip.begins_with("10.") or ip.begins_with("172."):
			out.append(ip)
	return out


# ---------------------------------------------------------------- sala

func host_room() -> bool:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(Data.PORT, 9)
	if err != OK:
		message.emit("Não foi possível criar a sala (erro %d)." % err)
		return false
	multiplayer.multiplayer_peer = peer
	online = true
	is_host = true
	players = {1: {"name": my_name, "team": my_team, "hero": my_hero}}
	_bcast = PacketPeerUDP.new()
	_bcast.set_broadcast_enabled(true)
	_bcast.set_dest_address("255.255.255.255", Data.DISCOVERY_PORT)
	lobby_changed.emit()
	return true


func join_room(ip: String) -> void:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip.strip_edges(), Data.PORT)
	if err != OK:
		message.emit("Endereço inválido.")
		return
	multiplayer.multiplayer_peer = peer
	online = true
	is_host = false
	message.emit("Conectando a %s..." % ip)


func leave() -> void:
	if multiplayer.multiplayer_peer and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	online = false
	is_host = false
	in_game = false
	players = {}
	if _bcast:
		_bcast.close()
		_bcast = null


func start_discovery() -> void:
	stop_discovery()
	rooms.clear()
	_listen = PacketPeerUDP.new()
	if _listen.bind(Data.DISCOVERY_PORT) != OK:
		_listen = null


func stop_discovery() -> void:
	if _listen:
		_listen.close()
		_listen = null


func _process(dt: float) -> void:
	if _bcast and is_host and not in_game:
		_bcast_t -= dt
		if _bcast_t <= 0:
			_bcast_t = 1.0
			var msg := "ARENARIFT|%s|%d|%s" % [my_name, players.size(), Data.VERSION]
			_bcast.put_packet(msg.to_utf8_buffer())
	if _listen:
		var changed := false
		while _listen.get_available_packet_count() > 0:
			var pkt := _listen.get_packet().get_string_from_utf8()
			var ip := _listen.get_packet_ip()
			var parts := pkt.split("|")
			if parts.size() >= 3 and parts[0] == "ARENARIFT":
				rooms[ip] = {"name": parts[1], "count": int(parts[2]), "t": Time.get_ticks_msec()}
				changed = true
		var now := Time.get_ticks_msec()
		for ip in rooms.keys():
			if now - rooms[ip].t > 4000:
				rooms.erase(ip)
				changed = true
		if changed:
			rooms_changed.emit()


func _on_peer_connected(_id: int) -> void:
	pass


func _on_peer_disconnected(id: int) -> void:
	if is_host:
		players.erase(id)
		if in_game:
			peer_left.emit(id)
		else:
			_sync()


func _on_connected() -> void:
	_register.rpc_id(1, my_name, my_team, my_hero, Data.VERSION)


@rpc("any_peer", "reliable")
func _register(pname: String, team: int, hero: int, version: String) -> void:
	if not is_host:
		return
	var id := multiplayer.get_remote_sender_id()
	if in_game or players.size() >= 10 or version != Data.VERSION:
		_rejected.rpc_id(id, "Sala cheia, partida em andamento ou versão diferente do jogo.")
		return
	players[id] = {"name": pname.left(16), "team": clampi(team, 0, 1), "hero": clampi(hero, 0, Data.HEROES.size() - 1)}
	_sync()


@rpc("authority", "reliable")
func _rejected(text: String) -> void:
	message.emit(text)
	leave()


func set_choice(team: int, hero: int) -> void:
	my_team = team
	my_hero = hero
	save_settings()
	if not online:
		return
	if is_host:
		players[1] = {"name": my_name, "team": team, "hero": hero}
		_sync()
	else:
		_choice.rpc_id(1, team, hero)


@rpc("any_peer", "reliable")
func _choice(team: int, hero: int) -> void:
	if not is_host:
		return
	var id := multiplayer.get_remote_sender_id()
	if players.has(id):
		players[id].team = clampi(team, 0, 1)
		players[id].hero = clampi(hero, 0, Data.HEROES.size() - 1)
		_sync()


func _sync() -> void:
	_players.rpc(players)
	lobby_changed.emit()


@rpc("authority", "reliable")
func _players(p: Dictionary) -> void:
	players = p
	joined.emit()
	lobby_changed.emit()


# ---------------------------------------------------------------- início

static func build_slots(humans: Array) -> Array:
	# humans: [{peer, name, team, hero}]
	var teams := [[], []]
	for h in humans:
		var t: int = h.team
		if teams[t].size() >= 5:
			t = 1 - t
		teams[t].append(h)
	var slots := []
	for team in [0, 1]:
		var used := {}
		for h in teams[team]:
			used[h.hero] = true
		var team_slots := []
		for h in teams[team]:
			team_slots.append({"team": team, "hero": h.hero, "name": h.name, "bot": false, "peer": h.peer, "role": Data.HEROES[h.hero].role})
		var roles_used := {}
		for s in team_slots:
			roles_used[s.role] = true
		for hero in range(Data.HEROES.size()):
			if team_slots.size() >= 5:
				break
			if used.has(hero):
				continue
			var role: String = Data.HEROES[hero].role
			team_slots.append({"team": team, "hero": hero, "name": "Bot %s" % Data.HEROES[hero].name, "bot": true, "peer": 0, "role": role})
		# Heróis repetidos: completa com quem faltar
		var k := 0
		while team_slots.size() < 5:
			var hero2 := k % Data.HEROES.size()
			team_slots.append({"team": team, "hero": hero2, "name": "Bot %s" % Data.HEROES[hero2].name, "bot": true, "peer": 0, "role": Data.HEROES[hero2].role})
			k += 1
		slots.append_array(team_slots)
	return slots


func start_offline() -> void:
	leave()
	var slots := build_slots([{"peer": 1, "name": my_name, "team": my_team, "hero": my_hero}])
	game_started.emit(slots, 1)


func start_online() -> void:
	if not is_host:
		return
	var humans := []
	var ids := players.keys()
	ids.sort()
	for id in ids:
		var p: Dictionary = players[id]
		humans.append({"peer": id, "name": p.name, "team": p.team, "hero": p.hero})
	in_game = true
	var slots := build_slots(humans)
	_start.rpc(slots)
	game_started.emit(slots, 1)


@rpc("authority", "reliable")
func _start(slots: Array) -> void:
	in_game = true
	game_started.emit(slots, multiplayer.get_unique_id())
