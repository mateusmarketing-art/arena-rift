extends Control
## Menu principal, escolha de herói, sala online e início da partida.

var screen: Control
var game: Game
var status_label: Label
var lobby_list: VBoxContainer
var rooms_list: VBoxContainer
var ip_edit: LineEdit
var hero_buttons := []
var team_buttons := []
var hero_desc: RichTextLabel
var start_btn: Button
var mode := ""
var test_mode := ""


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Net.lobby_changed.connect(_refresh_lobby)
	Net.rooms_changed.connect(_refresh_rooms)
	Net.game_started.connect(_on_game_started)
	Net.message.connect(_on_message)
	Net.joined.connect(func(): if mode == "join": _show_lobby(false))
	for arg in OS.get_cmdline_user_args():
		test_mode = arg
	match test_mode:
		"--autotest", "--shot":
			Net.start_offline()
			if test_mode == "--shot":
				_shots()
			return
		"--autohost":
			Net.my_name = "Host"
			Net.host_room()
			mode = "host"
			_show_lobby(true)
			return
		"--autojoin":
			Net.my_name = "Convidado"
			Net.my_team = 1
			Net.my_hero = 2
			mode = "join"
			Net.join_room("127.0.0.1")
			_show_join()
			return
	_show_main()


func _shots() -> void:
	Engine.time_scale = 3.0
	for i in range(4):
		await get_tree().create_timer([4.0, 75.0, 140.0, 220.0][i] - ([0.0, 4.0, 75.0, 140.0][i])).timeout
		var img := get_viewport().get_texture().get_image()
		img.save_png("/tmp/shot_%d.png" % i)
		print("[teste] captura ", i)
	get_tree().quit()


func _process(_dt: float) -> void:
	if test_mode == "--autohost" and Net.is_host and not Net.in_game and Net.players.size() >= 2:
		Net.start_online()


# ---------------------------------------------------------------- utilitários

func _clear() -> void:
	if screen:
		screen.queue_free()
	screen = Control.new()
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(screen)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
void fragment() {
	vec2 uv = UV;
	vec3 a = vec3(0.04, 0.06, 0.16);
	vec3 b = vec3(0.16, 0.03, 0.06);
	vec3 c = mix(a, b, uv.x * 0.8 + uv.y * 0.2);
	float glow = 0.18 / (0.2 + distance(uv, vec2(0.5, 0.35)));
	c += vec3(0.25, 0.18, 0.06) * glow * 0.35;
	float lines = smoothstep(0.995, 1.0, sin((uv.x + uv.y) * 90.0 + TIME * 0.6));
	c += vec3(0.08) * lines;
	COLOR = vec4(c, 1.0);
}"""
	var sm := ShaderMaterial.new()
	sm.shader = sh
	bg.material = sm
	screen.add_child(bg)


func _center_box(width := 900.0) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.add_child(center)
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(width, 0)
	v.add_theme_constant_override("separation", 18)
	center.add_child(v)
	return v


func _title(parent: Control, text: String, fs := 96) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", Color(1.0, 0.85, 0.42))
	l.add_theme_color_override("font_outline_color", Color(0.25, 0.1, 0.0))
	l.add_theme_constant_override("outline_size", 12)
	parent.add_child(l)
	return l


func _label(parent: Control, text: String, fs := 26, col := Color(0.9, 0.9, 0.95)) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	parent.add_child(l)
	return l


func _btn(parent: Control, text: String, cb: Callable, col := Color(0.75, 0.55, 0.15), h := 84.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, h)
	b.add_theme_font_size_override("font_size", 30)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var s := StyleBoxFlat.new()
		var c := col
		match state:
			"hover": c = col.lightened(0.15)
			"pressed": c = col.darkened(0.2)
			"disabled": c = Color(0.25, 0.25, 0.28)
			"focus": c = col
		s.bg_color = c.darkened(0.45)
		s.border_color = c
		s.set_border_width_all(3)
		s.set_corner_radius_all(16)
		s.set_content_margin_all(12)
		b.add_theme_stylebox_override(state, s)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


# ---------------------------------------------------------------- telas

func _show_main() -> void:
	mode = ""
	Net.stop_discovery()
	_clear()
	var v := _center_box(760)
	_title(v, "ARENA RIFT")
	_label(v, "MOBA 5v5 • Destrua o Nexus inimigo", 28, Color(0.85, 0.85, 0.95))
	var name_box := HBoxContainer.new()
	name_box.add_theme_constant_override("separation", 12)
	v.add_child(name_box)
	var nl := Label.new()
	nl.text = "Seu nome:"
	nl.add_theme_font_size_override("font_size", 28)
	name_box.add_child(nl)
	var ne := LineEdit.new()
	ne.text = Net.my_name
	ne.max_length = 16
	ne.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ne.custom_minimum_size = Vector2(0, 64)
	ne.add_theme_font_size_override("font_size", 28)
	ne.text_changed.connect(func(t): Net.my_name = t if t.strip_edges() != "" else "Jogador"; Net.save_settings())
	name_box.add_child(ne)
	_btn(v, "Jogar contra bots", func(): mode = "offline"; _show_heroes())
	_btn(v, "Criar sala com amigos (Wi‑Fi)", _create_room, Color(0.25, 0.5, 0.95))
	_btn(v, "Entrar na sala de um amigo", func(): mode = "join"; _show_join(), Color(0.25, 0.5, 0.95))
	status_label = _label(v, "", 22, Color(1, 0.7, 0.6))
	_label(v, "v%s • Heróis, mapa e arte originais" % Data.VERSION, 18, Color(0.6, 0.6, 0.7))


func _create_room() -> void:
	if Net.host_room():
		mode = "host"
		_show_lobby(true)


func _hero_picker(parent: Control) -> void:
	hero_buttons.clear()
	team_buttons.clear()
	var teams := HBoxContainer.new()
	teams.add_theme_constant_override("separation", 14)
	parent.add_child(teams)
	for t in [0, 1]:
		var tb := _btn(teams, "Time %s" % Data.TEAM_NAMES[t], func(): Net.set_choice(t, Net.my_hero); _update_picker(), Data.TEAM_COLORS[t], 64)
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tb.toggle_mode = true
		team_buttons.append(tb)
	var grid := HBoxContainer.new()
	grid.add_theme_constant_override("separation", 12)
	parent.add_child(grid)
	for i in range(Data.HEROES.size()):
		var h: Dictionary = Data.HEROES[i]
		var b := _btn(grid, "%s\n%s" % [h.name, h.role_name], func(): Net.set_choice(Net.my_team, i); _update_picker(), h.color, 120)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 24)
		b.toggle_mode = true
		hero_buttons.append(b)
	hero_desc = RichTextLabel.new()
	hero_desc.bbcode_enabled = true
	hero_desc.fit_content = true
	hero_desc.custom_minimum_size = Vector2(0, 150)
	hero_desc.add_theme_font_size_override("normal_font_size", 22)
	hero_desc.add_theme_font_size_override("bold_font_size", 24)
	parent.add_child(hero_desc)
	_update_picker()


func _update_picker() -> void:
	for i in range(hero_buttons.size()):
		hero_buttons[i].button_pressed = i == Net.my_hero
	for t in range(team_buttons.size()):
		team_buttons[t].button_pressed = t == Net.my_team
	var h: Dictionary = Data.HEROES[Net.my_hero]
	var t := "[b][color=#%s]%s, %s[/color][/b] — %s\n%s\n" % [h.color.to_html(false), h.name, h.title, h.role_name, h.desc]
	for a in h.abilities:
		t += "[b]%s[/b] %s   " % [a.key, a.name]
	if hero_desc:
		hero_desc.text = t


func _show_heroes() -> void:
	_clear()
	var v := _center_box(1300)
	_title(v, "Escolha seu herói", 60)
	_hero_picker(v)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	v.add_child(row)
	_btn(row, "Voltar", _show_main, Color(0.4, 0.4, 0.45)).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn(row, "Começar partida", func(): Net.start_offline()).size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _show_lobby(host: bool) -> void:
	Net.stop_discovery()
	_clear()
	var v := _center_box(1300)
	_title(v, "Sala de %s" % (Net.my_name if host else "amigo"), 54)
	if host:
		var ips := Net.local_ips()
		_label(v, "Seus amigos entram pelo mesmo Wi‑Fi (ou pelo seu roteador do celular). IP da sala: %s" % (", ".join(ips) if not ips.is_empty() else "sem Wi‑Fi"), 24, Color(0.7, 0.9, 1.0))
	else:
		_label(v, "Aguardando o anfitrião iniciar a partida...", 24, Color(0.7, 0.9, 1.0))
	_hero_picker(v)
	lobby_list = VBoxContainer.new()
	v.add_child(lobby_list)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	v.add_child(row)
	_btn(row, "Sair da sala", func(): Net.leave(); _show_main(), Color(0.4, 0.4, 0.45)).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if host:
		start_btn = _btn(row, "Iniciar partida (bots completam)", func(): Net.start_online())
		start_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label = _label(v, "", 22, Color(1, 0.7, 0.6))
	_refresh_lobby()


func _refresh_lobby() -> void:
	if lobby_list == null or not is_instance_valid(lobby_list):
		return
	for c in lobby_list.get_children():
		c.queue_free()
	var counts := [0, 0]
	var ids := Net.players.keys()
	ids.sort()
	var line := ""
	for id in ids:
		var p: Dictionary = Net.players[id]
		counts[p.team] += 1
		line += "• %s — %s (%s)%s\n" % [p.name, Data.HEROES[p.hero].name, Data.TEAM_NAMES[p.team], "  [anfitrião]" if id == 1 else ""]
	_label(lobby_list, "Jogadores na sala: %d/10   (Azul %d • Vermelho %d)" % [ids.size(), counts[0], counts[1]], 26)
	var l := _label(lobby_list, line, 22, Color(0.95, 0.95, 1.0))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT


func _show_join() -> void:
	Net.start_discovery()
	_clear()
	var v := _center_box(900)
	_title(v, "Entrar em uma sala", 54)
	_label(v, "Salas encontradas no seu Wi‑Fi:", 26)
	rooms_list = VBoxContainer.new()
	rooms_list.add_theme_constant_override("separation", 10)
	v.add_child(rooms_list)
	_label(v, "Ou digite o IP que aparece na tela do anfitrião:", 24)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	ip_edit = LineEdit.new()
	ip_edit.placeholder_text = "ex.: 192.168.0.12"
	ip_edit.custom_minimum_size = Vector2(0, 72)
	ip_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ip_edit.add_theme_font_size_override("font_size", 30)
	ip_edit.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER_DECIMAL
	row.add_child(ip_edit)
	_btn(row, "Entrar", func(): Net.join_room(ip_edit.text), Color(0.25, 0.5, 0.95), 72).custom_minimum_size.x = 200
	_btn(v, "Voltar", _show_main, Color(0.4, 0.4, 0.45))
	status_label = _label(v, "", 22, Color(1, 0.7, 0.6))
	_refresh_rooms()


func _refresh_rooms() -> void:
	if rooms_list == null or not is_instance_valid(rooms_list):
		return
	for c in rooms_list.get_children():
		c.queue_free()
	if Net.rooms.is_empty():
		_label(rooms_list, "Procurando salas...", 22, Color(0.7, 0.7, 0.8))
	for ip in Net.rooms:
		var r: Dictionary = Net.rooms[ip]
		_btn(rooms_list, "Sala de %s  (%d/10)  —  %s" % [r.name, r.count, ip], func(): Net.join_room(ip), Color(0.3, 0.7, 0.45), 72)


func _on_message(text: String) -> void:
	if test_mode != "":
		print("[teste] mensagem: ", text)
	if status_label and is_instance_valid(status_label):
		status_label.text = text
	if not Net.online and game == null and (mode == "host" or mode == "join") and text.begins_with("A conexão"):
		_show_main()
		if status_label:
			status_label.text = text


# ---------------------------------------------------------------- partida

func _on_game_started(slots: Array, my_peer: int) -> void:
	if test_mode != "":
		print("[teste] partida iniciada, peer %d, humanos %d" % [my_peer, slots.filter(func(x): return not x.bot).size()])
	Net.stop_discovery()
	if screen:
		screen.queue_free()
		screen = null
	game = Game.new()
	game.name = "Game"
	game.autoplay = test_mode == "--autotest" or test_mode == "--shot"
	game.test_log = test_mode != ""
	game.setup(slots, my_peer, not Net.online or Net.is_host)
	game.finished.connect(_on_game_finished)
	get_parent().add_child.call_deferred(game)


func _on_game_finished() -> void:
	game = null
	_show_main()
