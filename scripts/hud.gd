class_name Hud
extends Control
## Interface por toque: joystick, ataque, habilidades com mira por arrasto,
## barras de vida, minimapa, placar, loja e mensagens.

signal move_changed(v: Vector2)
signal attack_changed(held: bool)
signal attack_mode_changed(mode: int)
signal level_requested(idx: int)
signal cast_requested(idx: int, dir: Vector2, auto: bool)
signal aim_changed(idx: int, dir: Vector2)
signal recall_requested
signal buy_requested(item: int)
signal leave_requested

var view: WorldView
var camera: Camera3D
var my_id := 0
var my_team := 0
var my_hero := 0
var priv := {}
var board := []
var feed := []
var flip := false

var ui := 1.0
var joy_index := -1
var joy_center := Vector2.ZERO
var joy_pos := Vector2.ZERO
var atk_index := -1
var atk_mode := 0  # 0 = automático, 1 = só tropas, 2 = só torres
var aim_cancel := false
var aim_index := -1
var aim_ab := -1
var aim_start := Vector2.ZERO
var aim_cur := Vector2.ZERO
var key_move := Vector2.ZERO
var key_attack := false

var font: Font
var shop_panel: PanelContainer
var shop_grid: GridContainer
var shop_info: Label
var board_panel: PanelContainer
var board_label: RichTextLabel
var end_panel: PanelContainer
var end_label: Label
var menu_panel: PanelContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fit()
	get_viewport().size_changed.connect(_fit)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = ThemeDB.fallback_font
	_build_panels()


func _fit() -> void:
	position = Vector2.ZERO
	size = get_viewport().get_visible_rect().size


func _build_panels() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.1, 0.93)
	style.border_color = Color(0.85, 0.7, 0.35)
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(18)

	shop_panel = PanelContainer.new()
	shop_panel.add_theme_stylebox_override("panel", style)
	shop_panel.visible = false
	add_child(shop_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	shop_panel.add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	var title := Label.new()
	title.text = "LOJA"
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var close := _button("Fechar", func(): shop_panel.visible = false)
	top.add_child(close)
	shop_info = Label.new()
	shop_info.add_theme_font_size_override("font_size", 22)
	v.add_child(shop_info)
	shop_grid = GridContainer.new()
	shop_grid.columns = 3
	shop_grid.add_theme_constant_override("h_separation", 10)
	shop_grid.add_theme_constant_override("v_separation", 10)
	v.add_child(shop_grid)
	for i in range(Data.ITEMS.size()):
		var it: Dictionary = Data.ITEMS[i]
		var b := _button("%s\n%s\n%d de ouro" % [it.name, _item_stats(it), it.cost], func(): buy_requested.emit(i))
		b.custom_minimum_size = Vector2(280, 110)
		b.name = "Item%d" % i
		shop_grid.add_child(b)

	board_panel = PanelContainer.new()
	board_panel.add_theme_stylebox_override("panel", style)
	board_panel.visible = false
	add_child(board_panel)
	var bv := VBoxContainer.new()
	board_panel.add_child(bv)
	board_label = RichTextLabel.new()
	board_label.bbcode_enabled = true
	board_label.fit_content = true
	board_label.custom_minimum_size = Vector2(980, 420)
	board_label.add_theme_font_size_override("normal_font_size", 24)
	board_label.add_theme_font_size_override("bold_font_size", 26)
	bv.add_child(board_label)
	bv.add_child(_button("Fechar", func(): board_panel.visible = false))

	end_panel = PanelContainer.new()
	end_panel.add_theme_stylebox_override("panel", style)
	end_panel.visible = false
	add_child(end_panel)
	var ev := VBoxContainer.new()
	ev.add_theme_constant_override("separation", 24)
	end_panel.add_child(ev)
	end_label = Label.new()
	end_label.add_theme_font_size_override("font_size", 72)
	end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ev.add_child(end_label)
	ev.add_child(_button("Voltar ao menu", func(): leave_requested.emit()))

	menu_panel = PanelContainer.new()
	menu_panel.add_theme_stylebox_override("panel", style)
	menu_panel.visible = false
	add_child(menu_panel)
	var mv := VBoxContainer.new()
	mv.add_theme_constant_override("separation", 16)
	menu_panel.add_child(mv)
	var ml := Label.new()
	ml.text = "Sair da partida?"
	ml.add_theme_font_size_override("font_size", 32)
	mv.add_child(ml)
	mv.add_child(_button("Continuar jogando", func(): menu_panel.visible = false))
	mv.add_child(_button("Sair para o menu", func(): leave_requested.emit()))


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 22)
	b.custom_minimum_size = Vector2(180, 64)
	b.pressed.connect(cb)
	return b


func _item_stats(it: Dictionary) -> String:
	var parts := []
	if it.has("atk"): parts.append("+%d ataque" % it.atk)
	if it.has("pw"): parts.append("+%d poder" % it.pw)
	if it.has("hp"): parts.append("+%d vida" % it.hp)
	if it.has("armor"): parts.append("+%d armadura" % it.armor)
	if it.has("aspd"): parts.append("+%d%% vel. ataque" % int(it.aspd * 100))
	if it.has("speed"): parts.append("+%.1f velocidade" % it.speed)
	return ", ".join(parts)


# ---------------------------------------------------------------- layout

func _layout() -> Dictionary:
	ui = clampf(size.y / 900.0, 0.6, 2.0)
	var A := Vector2(size.x - 175 * ui, size.y - 160 * ui)  # botão de ataque
	return {
		"joy_home": Vector2(250 * ui, size.y - 230 * ui),
		"joy_r": 125.0 * ui,
		"atk": A, "atk_r": 92.0 * ui,
		# Q, W, E, R em arco em volta do ataque (como no Wild Rift)
		"ab": [A + Vector2(-205, 38) * ui, A + Vector2(-178, -128) * ui, A + Vector2(-42, -212) * ui, A + Vector2(-330, -118) * ui],
		"ab_r": [62.0 * ui, 62.0 * ui, 62.0 * ui, 70.0 * ui],
		# Feitiços de invocador: Flash (D) e Cura (F)
		"sp": [A + Vector2(-340, 62) * ui, A + Vector2(-450, -10) * ui],
		"sp_r": 48.0 * ui,
		"minion": A + Vector2(-62, 112) * ui, "tower": A + Vector2(105, -140) * ui, "tgt_r": 36.0 * ui,
		"cancel": A + Vector2(-190, -420) * ui, "cancel_r": 62.0 * ui,
		"recall": Vector2(size.x * 0.5 - 70 * ui, size.y - 62 * ui),
		"small_r": 42.0 * ui,
		"shop": Vector2(60 * ui, 360 * ui),
		"board": Vector2(size.x - 60 * ui, 60 * ui),
		"menu": Vector2(size.x - 160 * ui, 60 * ui),
		"mini": Rect2(Vector2(14, 14) * ui, Vector2(250, 250) * ui),
	}


func _process(_dt: float) -> void:
	_update_keys()
	queue_redraw()
	if shop_panel.visible:
		shop_panel.position = (size - shop_panel.size) / 2
		var near := _at_base()
		shop_info.text = "Ouro: %d   |   %s   |   Itens: %d/6" % [priv.get("gold", 0), "Na base: pode comprar" if near else "Volte para a base (ou espere renascer) para comprar", priv.get("items", []).size()]
		for i in range(Data.ITEMS.size()):
			var b: Button = shop_grid.get_node("Item%d" % i)
			b.disabled = not near or priv.get("gold", 0) < Data.ITEMS[i].cost or priv.get("items", []).size() >= 6
	board_panel.position = (size - board_panel.size) / 2
	end_panel.position = (size - end_panel.size) / 2
	menu_panel.position = (size - menu_panel.size) / 2
	if view and view.winner >= 0 and not end_panel.visible:
		end_label.text = "VITÓRIA!" if view.winner == my_team else "DERROTA"
		end_label.add_theme_color_override("font_color", Color(1, 0.85, 0.3) if view.winner == my_team else Color(1, 0.35, 0.3))
		end_panel.visible = true
	var now := Time.get_ticks_msec() / 1000.0
	feed = feed.filter(func(f): return now - f.t < 5.0)


func _at_base() -> bool:
	if view == null or not view.info.has(my_id):
		return false
	var d: Dictionary = view.info[my_id]
	if d.flags & 1:
		return true
	var f: Vector2 = Data.FOUNTAIN_POS[my_team]
	return Vector2(d.pos.x, d.pos.z).distance_to(f) < Data.FOUNTAIN_RADIUS + 3


func _update_keys() -> void:
	var k := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): k.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): k.x += 1
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): k.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): k.y += 1
	if k != key_move:
		key_move = k
		if joy_index < 0:
			move_changed.emit(to_world(k.normalized()))
	var ka := Input.is_key_pressed(KEY_SPACE)
	if ka != key_attack:
		key_attack = ka
		if atk_index < 0:
			attack_changed.emit(ka)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1: cast_requested.emit(0, Vector2.ZERO, true)
			KEY_2: cast_requested.emit(1, Vector2.ZERO, true)
			KEY_3: cast_requested.emit(2, Vector2.ZERO, true)
			KEY_4: cast_requested.emit(3, Vector2.ZERO, true)
			KEY_F: cast_requested.emit(4, Vector2.ZERO, true)
			KEY_H: cast_requested.emit(5, Vector2.ZERO, true)
			KEY_U:
				for i in [3, 0, 2, 1]:
					if _can_rank(i):
						level_requested.emit(i)
						break
			KEY_B: recall_requested.emit()
			KEY_P: shop_panel.visible = not shop_panel.visible
			KEY_TAB: _toggle_board()


## Converte direção da tela para o mapa (o time Vermelho vê o mapa girado)
func to_world(v: Vector2) -> Vector2:
	return -v if flip else v


# ---------------------------------------------------------------- toque

func _overlay_open() -> bool:
	return shop_panel.visible or board_panel.visible or end_panel.visible or menu_panel.visible


func _can_rank(idx: int) -> bool:
	var pts: int = priv.get("points", 0)
	if pts <= 0:
		return false
	var ranks: Array = priv.get("ranks", [0, 0, 0, 0])
	var lvl: int = priv.get("lvl", 1)
	var r: int = ranks[idx]
	if idx == 3:
		return r < 3 and lvl >= [5, 9, 13][r]
	return r < 4 and r < ceili(lvl / 2.0)


func _input(event: InputEvent) -> void:
	if _overlay_open():
		if joy_index >= 0 or atk_index >= 0 or aim_index >= 0:
			_release_all()
		return
	var L := _layout()
	if event is InputEventScreenTouch:
		var p: Vector2 = event.position
		if event.pressed:
			# "+" para subir habilidade
			for i in range(4):
				if _can_rank(i) and p.distance_to(L.ab[i] + Vector2(0, -L.ab_r[i] - 20 * ui)) < 30 * ui:
					level_requested.emit(i)
					_handled()
					return
			if p.distance_to(L.atk) < L.atk_r * 1.1 and atk_index < 0:
				atk_index = event.index
				_set_attack_mode(0)
				attack_changed.emit(true)
				_handled()
				return
			for t in [["minion", 1], ["tower", 2]]:
				if p.distance_to(L[t[0]]) < L.tgt_r * 1.25 and atk_index < 0:
					atk_index = event.index
					_set_attack_mode(t[1])
					attack_changed.emit(true)
					_handled()
					return
			for i in range(4):
				if p.distance_to(L.ab[i]) < L.ab_r[i] * 1.15 and aim_index < 0:
					_start_aim(event.index, i, p)
					return
			if p.distance_to(L.sp[0]) < L.sp_r * 1.2 and aim_index < 0:
				_start_aim(event.index, 4, p)
				return
			if p.distance_to(L.sp[1]) < L.sp_r * 1.2:
				cast_requested.emit(5, Vector2.ZERO, true)
				_handled()
				return
			if p.distance_to(L.recall) < L.small_r * 1.3:
				recall_requested.emit()
				_handled()
				return
			if p.distance_to(L.shop) < L.small_r * 1.3:
				shop_panel.visible = true
				_handled()
				return
			if p.distance_to(L.board) < L.small_r * 1.3:
				_toggle_board()
				_handled()
				return
			if p.distance_to(L.menu) < L.small_r * 1.3:
				menu_panel.visible = true
				_handled()
				return
			if p.x < size.x * 0.45 and p.y > size.y * 0.35 and joy_index < 0:
				joy_index = event.index
				joy_center = L.joy_home
				joy_pos = p
				_update_joy(L)
				_handled()
		else:
			if event.index == joy_index:
				joy_index = -1
				move_changed.emit(to_world(key_move.normalized()))
			elif event.index == atk_index:
				atk_index = -1
				attack_changed.emit(key_attack)
				_set_attack_mode(0)
			elif event.index == aim_index:
				var d := (aim_cur - aim_start) / (140.0 * ui)
				var auto := d.length() < 0.22
				var cancel: bool = aim_cur.distance_to(L.cancel) < L.cancel_r * 1.2
				aim_index = -1
				aim_changed.emit(-1, Vector2.ZERO)
				if not cancel:
					cast_requested.emit(aim_ab, to_world(d.limit_length(1.0)), auto)
	elif event is InputEventScreenDrag:
		if event.index == joy_index:
			joy_pos = event.position
			_update_joy(L)
		elif event.index == aim_index:
			aim_cur = event.position
			aim_cancel = aim_cur.distance_to(L.cancel) < L.cancel_r * 1.2
			var d2 := (aim_cur - aim_start) / (140.0 * ui)
			aim_changed.emit(-1 if aim_cancel else aim_ab, to_world(d2.limit_length(1.0)))


func _start_aim(index: int, ab: int, p: Vector2) -> void:
	aim_index = index
	aim_ab = ab
	aim_start = p
	aim_cur = p
	aim_cancel = false
	aim_changed.emit(ab, Vector2.ZERO)
	_handled()


func _update_joy(L: Dictionary) -> void:
	var v: Vector2 = (joy_pos - joy_center) / L.joy_r
	if v.length() > 1.0:
		v = v.normalized()
	move_changed.emit(to_world(v if v.length() > 0.12 else Vector2.ZERO))


func _set_attack_mode(m: int) -> void:
	if atk_mode != m:
		atk_mode = m
		attack_mode_changed.emit(m)


func _handled() -> void:
	get_viewport().set_input_as_handled()


func _release_all() -> void:
	joy_index = -1
	atk_index = -1
	aim_index = -1
	move_changed.emit(Vector2.ZERO)
	attack_changed.emit(false)
	aim_changed.emit(-1, Vector2.ZERO)


func _toggle_board() -> void:
	board_panel.visible = not board_panel.visible
	if board_panel.visible:
		_fill_board()


func _fill_board() -> void:
	var t := ""
	for team in [0, 1]:
		var hexc: String = Data.TEAM_COLORS[team].to_html(false)
		t += "[b][color=#%s]Time %s — %d abates[/color][/b]\n" % [hexc, Data.TEAM_NAMES[team], view.score[team] if view else 0]
		for b in board:
			if b[1] != team:
				continue
			var items := []
			for it in b[9]:
				items.append(Data.ITEMS[it].name)
			var me := " [color=#ffd060](você)[/color]" if b[0] == my_id else ""
			t += "  Nv %2d  %-10s %s  %d / %d / %d   tropas %d%s\n" % [b[4], Data.HEROES[b[2]].name, b[3], b[5], b[6], b[7], b[8], me]
			if not items.is_empty():
				t += "        [color=#a0a0b0]%s[/color]\n" % ", ".join(items)
		t += "\n"
	board_label.text = t


func push_feed(text: String, color: Color) -> void:
	feed.append({"text": text, "color": color, "t": Time.get_ticks_msec() / 1000.0})
	if feed.size() > 5:
		feed.pop_front()


# ---------------------------------------------------------------- desenho

func _draw() -> void:
	if view == null or camera == null:
		return
	var L := _layout()
	_draw_bars()
	_draw_minimap(L.mini)
	_draw_top()
	_draw_controls(L)
	_draw_feed()
	if view.info.has(my_id):
		var me: Dictionary = view.info[my_id]
		if me.flags & 1:
			var secs := int(ceil(me.respawn))
			_text_center(Vector2(size.x / 2, size.y * 0.42), "Renascendo em %d s" % secs, 52, Color(1, 0.9, 0.85))
			_text_center(Vector2(size.x / 2, size.y * 0.42 + 56 * ui), "Aproveite para comprar na loja", 26, Color(0.85, 0.85, 0.9))
		if me.flags & 8:
			var r: float = priv.get("recall", 0.0)
			_text_center(Vector2(size.x / 2, size.y * 0.62), "Voltando para a base... %.1f s" % r, 30, Color(0.6, 0.85, 1.0))


func _text(p: Vector2, s: String, fs: int, c: Color, align := HORIZONTAL_ALIGNMENT_LEFT, w := -1.0) -> void:
	var f := int(fs * ui)
	draw_string_outline(font, p, s, align, w, f, maxi(2, int(4 * ui)), Color(0, 0, 0, 0.85))
	draw_string(font, p, s, align, w, f, c)


func _text_center(p: Vector2, s: String, fs: int, c: Color) -> void:
	var f := int(fs * ui)
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, f).x
	_text(p - Vector2(w / 2, 0), s, fs, c)


func _draw_bars() -> void:
	for id in view.info:
		var d: Dictionary = view.info[id]
		if d.flags & 1:
			continue
		var h := 1.8
		var w := 44.0
		var th := 6.0
		match d.kind:
			0: h = 3.9; w = 104.0; th = 12.0
			3: h = 2.2; w = 56.0
			4: h = 9.2; w = 120.0; th = 10.0
			5: h = 8.0; w = 150.0; th = 12.0
			6: h = 2.6; w = 70.0; th = 8.0
			7: h = 5.5; w = 130.0; th = 11.0
		var wp: Vector3 = d.vis_pos + Vector3(0, h, 0)
		if camera.is_position_behind(wp):
			continue
		var sp := camera.unproject_position(wp)
		if sp.x < -100 or sp.y < -50 or sp.x > size.x + 100 or sp.y > size.y + 50:
			continue
		w *= ui
		th *= ui
		var ratio := clampf(d.hp / maxf(d.max_hp, 1.0), 0.0, 1.0)
		var col: Color
		if id == my_id:
			col = Color(0.35, 0.95, 0.35)
		elif d.team == my_team:
			col = Color(0.3, 0.65, 1.0)
		elif d.team == Data.TEAM_NEUTRAL:
			col = Color(0.95, 0.75, 0.25)
		else:
			col = Color(1.0, 0.3, 0.28)
		var r := Rect2(sp - Vector2(w / 2, 0), Vector2(w, th))
		draw_rect(r.grow(2 * ui), Color(0, 0, 0, 0.8))
		draw_rect(Rect2(r.position, Vector2(w * ratio, th)), col)
		if d.shield > 0:
			var sw := minf(w * (1 - ratio), w * d.shield / maxf(d.max_hp, 1.0))
			draw_rect(Rect2(r.position + Vector2(w * ratio, 0), Vector2(sw, th)), Color(0.95, 0.95, 1.0, 0.9))
		if d.kind == 0:
			# divisões a cada 200 de vida
			var step: float = 200.0 / d.max_hp * w
			var x: float = step
			while x < w * ratio and step > 3:
				draw_line(r.position + Vector2(x, 0), r.position + Vector2(x, th * 0.6), Color(0, 0, 0, 0.6), 1.0)
				x += step
			var lv := Rect2(r.position - Vector2(th * 2.2, th * 0.3), Vector2(th * 2.0, th * 1.6))
			draw_rect(lv, Color(0.08, 0.08, 0.12, 0.95))
			_text_center(lv.position + Vector2(lv.size.x / 2, lv.size.y * 0.82), str(d.level), 15, Color(1, 0.9, 0.6))
			var name: String = Data.HEROES[d.sub].name
			for b in board:
				if b[0] == id:
					name = b[3]
			_text_center(sp - Vector2(0, 6 * ui), name, 17, Color(1, 1, 1, 0.95))
			if d.flags & 2:
				_text_center(sp - Vector2(0, 26 * ui), "ATORDOADO", 15, Color(1, 0.95, 0.3))
		elif (d.kind == 4 or d.kind == 5) and d.flags & 32:
			_text_center(sp - Vector2(0, 6 * ui), "protegida", 14, Color(0.8, 0.8, 0.9, 0.8))


func _mini_pos(r: Rect2, p: Vector3) -> Vector2:
	var x := (p.x / Data.MAP_HALF) * 0.5 + 0.5
	var y := (p.z / Data.MAP_HALF) * 0.5 + 0.5
	if flip:
		x = 1 - x
		y = 1 - y
	return r.position + Vector2(x, y) * r.size


func _draw_minimap(r: Rect2) -> void:
	draw_rect(r.grow(3 * ui), Color(0.85, 0.7, 0.35, 0.9))
	draw_rect(r, Color(0.07, 0.16, 0.1, 0.92))
	var c0 := _mini_pos(r, Vector3(-Data.MAP_HALF, 0, -Data.MAP_HALF))
	var c1 := _mini_pos(r, Vector3(Data.MAP_HALF, 0, Data.MAP_HALF))
	draw_line(c0, c1, Color(0.2, 0.5, 0.75, 0.8), 9 * ui)
	for lane in Data.LANES:
		for i in range(lane.size() - 1):
			draw_line(_mini_pos(r, Vector3(lane[i].x, 0, lane[i].y)), _mini_pos(r, Vector3(lane[i + 1].x, 0, lane[i + 1].y)), Color(0.55, 0.48, 0.38), 5 * ui)
	for id in view.info:
		var d: Dictionary = view.info[id]
		if d.flags & 1:
			continue
		var p := _mini_pos(r, d.pos)
		var col: Color = Color(0.3, 0.65, 1.0) if d.team == my_team else (Color(0.95, 0.75, 0.25) if d.team == 2 else Color(1, 0.3, 0.28))
		match d.kind:
			0:
				draw_circle(p, 8 * ui, Color(0, 0, 0))
				draw_circle(p, 6.5 * ui, Color(0.35, 0.95, 0.35) if id == my_id else col)
			4, 5:
				var s := (7 if d.kind == 4 else 10) * ui
				draw_rect(Rect2(p - Vector2(s, s) / 2, Vector2(s, s)), col)
			6, 7:
				draw_circle(p, (3 if d.kind == 6 else 6) * ui, col)
			_:
				draw_circle(p, 2.0 * ui, col)
	# área da câmera
	if view.info.has(my_id):
		var me := _mini_pos(r, view.info[my_id].vis_pos)
		draw_rect(Rect2(me - Vector2(22, 14) * ui, Vector2(44, 28) * ui), Color(1, 1, 1, 0.5), false, 1.5)


func _draw_top() -> void:
	var cx := size.x / 2
	var box := Rect2(Vector2(cx - 170 * ui, 8 * ui), Vector2(340 * ui, 62 * ui))
	draw_rect(box, Color(0.04, 0.05, 0.09, 0.85))
	var mine: int = view.score[my_team]
	var theirs: int = view.score[1 - my_team]
	_text(Vector2(cx - 150 * ui, 52 * ui), str(mine), 40, Color(0.4, 0.7, 1.0))
	_text(Vector2(cx + 110 * ui, 52 * ui), str(theirs), 40, Color(1.0, 0.4, 0.35))
	var t := int(view.time)
	_text_center(Vector2(cx, 48 * ui), "%02d:%02d" % [t / 60, t % 60], 30, Color(1, 1, 1))
	# KDA e ouro
	for b in board:
		if b[0] == my_id:
			_text(Vector2(size.x - 470 * ui, 52 * ui), "%d / %d / %d" % [b[5], b[6], b[7]], 26, Color(1, 1, 1))
	_text(Vector2(26 * ui, 300 * ui), "Ouro %d" % priv.get("gold", 0), 26, Color(1, 0.85, 0.35))


func _draw_controls(L: Dictionary) -> void:
	# Analógico
	var jc: Vector2 = L.joy_home
	var jp: Vector2 = jc
	if joy_index >= 0:
		jp = jc + (joy_pos - jc).limit_length(L.joy_r)
	draw_circle(jc, L.joy_r, Color(0.05, 0.08, 0.14, 0.35))
	draw_arc(jc, L.joy_r, 0, TAU, 64, Color(0.75, 0.85, 1.0, 0.55), 4 * ui)
	draw_arc(jc, L.joy_r * 0.55, 0, TAU, 48, Color(0.75, 0.85, 1.0, 0.15), 2 * ui)
	draw_circle(jp, L.joy_r * 0.42, Color(0.85, 0.92, 1.0, 0.75))
	draw_arc(jp, L.joy_r * 0.42, 0, TAU, 40, Color(1, 1, 1, 0.9), 3 * ui)
	# Ataque
	var pressed := (atk_index >= 0 and atk_mode == 0) or key_attack
	draw_circle(L.atk, L.atk_r + 6 * ui, Color(0, 0, 0, 0.45))
	draw_circle(L.atk, L.atk_r, Color(0.62, 0.16, 0.1, 0.95 if pressed else 0.8))
	draw_circle(L.atk, L.atk_r * 0.78, Color(0.82, 0.28, 0.16, 0.95 if pressed else 0.8))
	draw_arc(L.atk, L.atk_r, 0, TAU, 56, Color(1, 0.82, 0.45), 5 * ui)
	_sword_icon(L.atk, L.atk_r * 0.55)
	# Alvo: tropa / torre
	_target_btn(L.minion, L.tgt_r, "Tropa", atk_mode == 1)
	_target_btn(L.tower, L.tgt_r, "Torre", atk_mode == 2)
	# Habilidades
	var cds: Array = priv.get("cds", [0, 0, 0, 0, 0, 0])
	var ranks: Array = priv.get("ranks", [0, 0, 0, 0])
	var abilities: Array = Data.HEROES[my_hero].abilities
	var hc: Color = Data.HEROES[my_hero].color
	for i in range(4):
		var c: Vector2 = L.ab[i]
		var rr: float = L.ab_r[i]
		var rank: int = ranks[i] if i < ranks.size() else 0
		var locked := rank <= 0
		draw_circle(c, rr + 5 * ui, Color(0, 0, 0, 0.5))
		draw_circle(c, rr, hc.darkened(0.25) if not locked else Color(0.18, 0.18, 0.2, 0.9))
		draw_circle(c, rr * 0.72, hc.darkened(0.5) if not locked else Color(0.12, 0.12, 0.14, 0.9))
		_ability_icon(c, rr * 0.5, abilities[i].type, Color(1, 1, 1, 0.9 if not locked else 0.3))
		var cd: float = cds[i] if i < cds.size() else 0.0
		if cd > 0 and not locked:
			var frac := clampf(cd / float(abilities[i].cd), 0.0, 1.0)
			_pie(c, rr, frac, Color(0, 0, 0, 0.62))
			_text_center(c + Vector2(0, 12 * ui), "%d" % ceil(cd), 34, Color(1, 1, 1))
		draw_arc(c, rr, 0, TAU, 48, Color(1, 0.85, 0.5) if (cd <= 0 and not locked) else Color(0.45, 0.45, 0.5), 4 * ui)
		_text_center(c + Vector2(rr * 0.62, rr * 0.95), abilities[i].key, 18, Color(1, 0.9, 0.6))
		# Pontinhos de nível da habilidade
		var maxr := 3 if i == 3 else 4
		for k in range(maxr):
			var dp := c + Vector2((k - (maxr - 1) / 2.0) * 13 * ui, rr + 12 * ui)
			draw_circle(dp, 4.5 * ui, Color(1, 0.8, 0.3) if k < rank else Color(0.2, 0.2, 0.25, 0.9))
		if _can_rank(i):
			var up := c + Vector2(0, -rr - 20 * ui)
			draw_circle(up, 22 * ui, Color(0.15, 0.1, 0.02, 0.9))
			draw_circle(up, 18 * ui, Color(1.0, 0.78, 0.25))
			_text_center(up + Vector2(0, 10 * ui), "+", 30, Color(0.25, 0.12, 0.0))
		if aim_index >= 0 and aim_ab == i:
			_draw_aim_stick(c)
	# Feitiços
	var names := ["Flash", "Cura"]
	var cols := [Color(1.0, 0.9, 0.4), Color(0.4, 1.0, 0.55)]
	var maxcd := [Sim.FLASH_CD, Sim.HEAL_CD]
	for j in range(2):
		var c2: Vector2 = L.sp[j]
		var r2: float = L.sp_r
		var cd2: float = cds[4 + j] if cds.size() > 4 + j else 0.0
		draw_circle(c2, r2 + 4 * ui, Color(0, 0, 0, 0.5))
		draw_circle(c2, r2, cols[j].darkened(0.55))
		draw_circle(c2, r2 * 0.55, cols[j].darkened(0.1))
		if cd2 > 0:
			_pie(c2, r2, clampf(cd2 / maxcd[j], 0, 1), Color(0, 0, 0, 0.65))
			_text_center(c2 + Vector2(0, 10 * ui), "%d" % ceil(cd2), 26, Color(1, 1, 1))
		draw_arc(c2, r2, 0, TAU, 40, cols[j] if cd2 <= 0 else Color(0.4, 0.4, 0.45), 3 * ui)
		_text_center(c2 + Vector2(0, r2 + 20 * ui), names[j], 16, Color(1, 1, 1, 0.9))
		if aim_index >= 0 and aim_ab == 4 + j:
			_draw_aim_stick(c2)
	# Cancelar mira
	if aim_index >= 0:
		var cc: Vector2 = L.cancel
		draw_circle(cc, L.cancel_r, Color(0.7, 0.1, 0.1, 0.85 if aim_cancel else 0.45))
		draw_arc(cc, L.cancel_r, 0, TAU, 40, Color(1, 0.6, 0.6), 3 * ui)
		var x: float = L.cancel_r * 0.35
		draw_line(cc - Vector2(x, x), cc + Vector2(x, x), Color(1, 1, 1), 5 * ui)
		draw_line(cc + Vector2(-x, x), cc + Vector2(x, -x), Color(1, 1, 1), 5 * ui)
		_text_center(cc + Vector2(0, L.cancel_r + 24 * ui), "Cancelar", 18, Color(1, 0.85, 0.85))
	# Botões pequenos
	_small_btn(L.recall, L.small_r, "Base", Color(0.25, 0.45, 0.85))
	_small_btn(L.shop, L.small_r, "Loja", Color(0.8, 0.6, 0.15))
	_small_btn(L.board, L.small_r, "Placar", Color(0.35, 0.35, 0.45))
	_small_btn(L.menu, L.small_r, "Menu", Color(0.35, 0.35, 0.45))
	# Nível e experiência
	var lvl: int = priv.get("lvl", 1)
	var xp: float = priv.get("xp", 0.0)
	var nxt: float = priv.get("next", 1.0)
	var bar := Rect2(Vector2(size.x / 2 - 170 * ui, 76 * ui), Vector2(340 * ui, 9 * ui))
	draw_rect(bar.grow(2 * ui), Color(0, 0, 0, 0.75))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(xp / nxt, 0, 1) if lvl < 15 else bar.size.x, bar.size.y)), Color(0.65, 0.4, 1.0))
	_text_center(bar.position + Vector2(bar.size.x / 2, 30 * ui), "Nível %d  •  %s" % [lvl, Data.HEROES[my_hero].name], 18, Color(1, 1, 1))


func _draw_aim_stick(c: Vector2) -> void:
	var d := (aim_cur - aim_start).limit_length(140.0 * ui)
	draw_circle(c, 140.0 * ui, Color(0.4, 0.7, 1.0, 0.12))
	draw_arc(c, 140.0 * ui, 0, TAU, 48, Color(0.6, 0.85, 1.0, 0.5), 2 * ui)
	draw_circle(c + d, 30 * ui, Color(0.85, 0.95, 1.0, 0.85))
	if d.length() < 0.22 * 140.0 * ui:
		_text_center(c - Vector2(0, 158 * ui), "solte para mirar sozinho", 16, Color(1, 1, 1, 0.85))


func _pie(c: Vector2, r: float, frac: float, col: Color) -> void:
	if frac <= 0.0:
		return
	var pts := PackedVector2Array([c])
	var steps := maxi(3, int(40 * frac))
	for k in range(steps + 1):
		var a := -PI / 2 + TAU * frac * k / steps
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(pts, col)


func _sword_icon(c: Vector2, s: float) -> void:
	var col := Color(1, 0.95, 0.85)
	draw_line(c + Vector2(-s, s), c + Vector2(s * 0.8, -s * 0.8), col, 7 * ui)
	draw_line(c + Vector2(-s * 0.45, s * 0.05), c + Vector2(-s * 0.05, s * 0.45), col, 7 * ui)
	draw_line(c + Vector2(-s * 0.8, -s * 0.8), c + Vector2(s, s), Color(col.r, col.g, col.b, 0.55), 5 * ui)


func _ability_icon(c: Vector2, s: float, type: String, col: Color) -> void:
	match type:
		"skillshot":
			draw_line(c + Vector2(-s, s * 0.6), c + Vector2(s, -s * 0.6), col, 6 * ui)
			draw_circle(c + Vector2(s, -s * 0.6), 9 * ui, col)
		"dash", "blink":
			for k in range(3):
				var o := Vector2(-s + k * s * 0.7, 0)
				draw_polyline(PackedVector2Array([c + o + Vector2(0, -s * 0.5), c + o + Vector2(s * 0.45, 0), c + o + Vector2(0, s * 0.5)]), col, 5 * ui)
		"nova":
			draw_arc(c, s, 0, TAU, 32, col, 5 * ui)
			draw_arc(c, s * 0.5, 0, TAU, 24, col, 4 * ui)
		"blast":
			draw_circle(c, s * 0.45, col)
			for k in range(8):
				var a := TAU * k / 8
				draw_line(c + Vector2(cos(a), sin(a)) * s * 0.6, c + Vector2(cos(a), sin(a)) * s, col, 4 * ui)
		"buff":
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s), c + Vector2(s * 0.85, -s * 0.5), c + Vector2(s * 0.7, s * 0.4), c + Vector2(0, s), c + Vector2(-s * 0.7, s * 0.4), c + Vector2(-s * 0.85, -s * 0.5)]), Color(col.r, col.g, col.b, col.a * 0.8))
		"heal":
			draw_rect(Rect2(c - Vector2(s * 0.22, s), Vector2(s * 0.44, s * 2)), col)
			draw_rect(Rect2(c - Vector2(s, s * 0.22), Vector2(s * 2, s * 0.44)), col)


func _target_btn(c: Vector2, r: float, label: String, on: bool) -> void:
	draw_circle(c, r + 3 * ui, Color(0, 0, 0, 0.5))
	draw_circle(c, r, Color(0.55, 0.2, 0.12, 0.9) if on else Color(0.25, 0.22, 0.24, 0.85))
	draw_arc(c, r, 0, TAU, 32, Color(1, 0.8, 0.5), 3 * ui)
	_text_center(c + Vector2(0, 6 * ui), label, 15, Color(1, 1, 1))


func _small_btn(c: Vector2, r: float, label: String, col: Color) -> void:
	draw_circle(c, r, Color(0.05, 0.05, 0.08, 0.85))
	draw_circle(c, r - 4 * ui, col.darkened(0.2))
	_text_center(c + Vector2(0, 7 * ui), label, 16, Color(1, 1, 1))


func _draw_feed() -> void:
	var y := 150.0 * ui
	for f in feed:
		_text_center(Vector2(size.x / 2, y), f.text, 22, f.color)
		y += 30 * ui
