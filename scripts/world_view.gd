class_name WorldView
extends Node3D
## Desenha o mapa e as unidades (modelos do Blender) a partir dos snapshots.

var nodes := {}       # id -> Node3D
var info := {}        # id -> Dictionary com o último estado
var projs := {}       # id -> Node3D
var time := 0.0
var score := [0, 0]
var winner := -1
var local_hero := 0
var local_team := 0
var aim_node: Node3D
var range_node: MeshInstance3D

static var fx_shader: Shader
static var water_shader: Shader
static var ground_shader: Shader

const FX_CODE := """shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 color : source_color = vec4(1.0);
uniform float alpha = 1.0;
uniform int mode = 0;
uniform float fill = 0.25;
uniform float progress = 1.0;
uniform float spin = 0.0;
void fragment() {
	float a = 1.0;
	vec2 uv = UV - 0.5;
	float c = cos(TIME * spin), s = sin(TIME * spin);
	uv = vec2(uv.x * c - uv.y * s, uv.x * s + uv.y * c);
	float d = length(uv) * 2.0;
	if (mode == 1) {
		float edge = smoothstep(0.84, 0.96, d) * (1.0 - smoothstep(0.96, 1.0, d));
		float inner = fill * (1.0 - step(progress, d)) * (0.6 + 0.4 * d);
		a = (edge + inner) * step(d, 1.0);
	} else if (mode == 2) {
		vec2 q = abs(UV - 0.5) * 2.0;
		a = max(smoothstep(0.8, 1.0, q.x), smoothstep(0.97, 1.0, q.y)) + fill;
	} else if (mode == 3) {
		a = pow(1.0 - clamp(d, 0.0, 1.0), 1.5);
	} else if (mode == 4) {
		float ang = atan(uv.y, uv.x);
		float sw = 0.5 + 0.5 * sin(ang * 3.0 + d * 9.0);
		a = sw * (1.0 - smoothstep(0.7, 1.0, d)) * smoothstep(0.0, 0.25, d);
	} else if (mode == 5) {
		a = smoothstep(0.0, 0.25, UV.x) * (1.0 - smoothstep(0.7, 1.0, UV.x)) * (1.0 - abs(UV.y - 0.5) * 1.4);
	}
	ALBEDO = color.rgb;
	ALPHA = clamp(a, 0.0, 1.0) * alpha * color.a;
}"""

const WATER_CODE := """shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never;
uniform sampler2D noise_tex : repeat_enable;
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = wpos.xz * 0.06;
	float n1 = texture(noise_tex, p + vec2(TIME * 0.02, TIME * 0.03)).r;
	float n2 = texture(noise_tex, p * 1.7 - vec2(TIME * 0.035, TIME * 0.01)).r;
	float n = (n1 + n2) * 0.5;
	vec3 deep = vec3(0.04, 0.22, 0.33);
	vec3 light = vec3(0.18, 0.62, 0.72);
	ALBEDO = mix(deep, light, smoothstep(0.35, 0.75, n));
	float foam = smoothstep(0.72, 0.8, n);
	ALBEDO += foam * 0.35;
	ROUGHNESS = 0.08;
	METALLIC = 0.0;
	SPECULAR = 0.9;
	ALPHA = 0.78;
	NORMAL_MAP = vec3(0.5 + (n1 - n2) * 0.6, 0.5 + (n2 - n1) * 0.6, 1.0);
}"""

const GROUND_CODE := """shader_type spatial;
uniform sampler2D mask_tex : filter_linear, repeat_disable;
uniform sampler2D noise_tex : repeat_enable;
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec4 m = texture(mask_tex, UV);
	float n = texture(noise_tex, wpos.xz * 0.025).r;
	float n2 = texture(noise_tex, wpos.xz * 0.11).r;
	float n3 = texture(noise_tex, wpos.xz * 0.45).r;
	vec3 grass = mix(vec3(0.11, 0.27, 0.12), vec3(0.25, 0.42, 0.16), n);
	grass = mix(grass, vec3(0.32, 0.45, 0.2), smoothstep(0.65, 0.85, n2) * 0.5);
	grass *= 0.82 + 0.3 * n3;
	vec2 g = wpos.xz * vec2(0.55, 0.42);
	g.x += floor(g.y) * 0.5;
	vec2 f = fract(g);
	float tile = smoothstep(0.0, 0.08, f.x) * smoothstep(1.0, 0.92, f.x) * smoothstep(0.0, 0.1, f.y) * smoothstep(1.0, 0.9, f.y);
	vec3 dirt = mix(vec3(0.4, 0.31, 0.22), vec3(0.52, 0.42, 0.3), n3);
	vec3 stone = mix(vec3(0.46, 0.43, 0.4), vec3(0.58, 0.55, 0.5), n3);
	vec3 road = mix(dirt, mix(dirt * 0.75, stone, tile), smoothstep(0.55, 0.9, m.r));
	vec3 plaza = mix(vec3(0.34, 0.33, 0.38), vec3(0.5, 0.49, 0.55), tile * (0.7 + 0.3 * n3));
	vec3 bed = vec3(0.12, 0.2, 0.2);
	vec3 c = mix(grass, road, m.r);
	c = mix(c, plaza, m.b);
	c = mix(c, bed, m.g);
	c = mix(vec3(0.03, 0.06, 0.04), c, m.a);
	ALBEDO = c;
	ROUGHNESS = 0.92;
}"""


func _ready() -> void:
	if fx_shader == null:
		fx_shader = Shader.new()
		fx_shader.code = FX_CODE
		water_shader = Shader.new()
		water_shader.code = WATER_CODE
		ground_shader = Shader.new()
		ground_shader.code = GROUND_CODE
	_build_environment()
	_build_map()
	aim_node = Node3D.new()
	add_child(aim_node)
	range_node = _decal(Vector3.ZERO, 1.0, Color(1, 1, 1, 0.35), 1, 0.0)
	range_node.visible = false


# ---------------------------------------------------------------- utilidades

func fx_mat(c: Color, mode := 0, fill := 0.25, a := 1.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = fx_shader
	m.set_shader_parameter("color", c)
	m.set_shader_parameter("mode", mode)
	m.set_shader_parameter("fill", fill)
	m.set_shader_parameter("alpha", a)
	return m


func std(c: Color, emit := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	if emit > 0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	return m


func _mi(mesh: Mesh, m: Material, pos := Vector3.ZERO, parent: Node = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(parent if parent else self).add_child(mi)
	return mi


func _decal(pos: Vector3, r: float, c: Color, mode := 1, fill := 0.25, parent: Node = null) -> MeshInstance3D:
	var pm := PlaneMesh.new()
	pm.size = Vector2(2, 2)
	var mi := _mi(pm, fx_mat(c, mode, fill), pos + Vector3(0, 0.06, 0), parent)
	mi.scale = Vector3(r, 1, r)
	return mi


func _sphere(r: float, m: Material, pos := Vector3.ZERO, parent: Node = null) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = 1.0
	s.height = 2.0
	s.radial_segments = 16
	s.rings = 8
	var mi := _mi(s, m, pos, parent)
	mi.scale = Vector3.ONE * r
	return mi


func _alpha_tween(mi: GeometryInstance3D, from: float, to: float, dur: float, free := true) -> Tween:
	var m: ShaderMaterial = mi.material_override
	var tw := create_tween()
	tw.tween_method(func(v): m.set_shader_parameter("alpha", v), from, to, dur)
	if free:
		tw.tween_callback(mi.queue_free)
	return tw


# ---------------------------------------------------------------- cenário

func _build_environment() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.2, 0.32, 0.55)
	sm.sky_horizon_color = Color(0.62, 0.66, 0.7)
	sm.ground_bottom_color = Color(0.1, 0.12, 0.1)
	sm.ground_horizon_color = Color(0.4, 0.42, 0.4)
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.65
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.2
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.18
	env.adjustment_contrast = 1.06
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58, -40, 0)
	sun.light_energy = 1.35
	sun.light_color = Color(1.0, 0.95, 0.86)
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	sun.directional_shadow_max_distance = 55.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	add_child(sun)


func _noise_tex() -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.frequency = 0.02
	noise.fractal_octaves = 4
	var tex := NoiseTexture2D.new()
	tex.width = 256
	tex.height = 256
	tex.seamless = true
	tex.noise = noise
	return tex


func _build_map() -> void:
	var noise := _noise_tex()
	var span := (Data.MAP_HALF + 15.0) * 2.0
	var plane := PlaneMesh.new()
	plane.size = Vector2(span, span)
	var gm := ShaderMaterial.new()
	gm.shader = ground_shader
	gm.set_shader_parameter("mask_tex", load("res://assets/textures/map_mask.png"))
	gm.set_shader_parameter("noise_tex", noise)
	var ground := MeshInstance3D.new()
	ground.mesh = plane
	ground.material_override = gm
	add_child(ground)
	# Rio
	var water := PlaneMesh.new()
	water.size = Vector2(13, Data.MAP_HALF * 2.9)
	var wm := ShaderMaterial.new()
	wm.shader = water_shader
	wm.set_shader_parameter("noise_tex", noise)
	var w := MeshInstance3D.new()
	w.mesh = water
	w.material_override = wm
	w.position = Vector3(0, 0.12, 0)
	w.rotation.y = deg_to_rad(45)
	w.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(w)
	# Fontes (área de cura das bases)
	for team in [0, 1]:
		var f: Vector2 = Data.FOUNTAIN_POS[team]
		var c: Color = Data.TEAM_COLORS[team]
		var d := _decal(Vector3(f.x, 0.02, f.y), Data.FOUNTAIN_RADIUS, Color(c.r, c.g, c.b, 0.7), 1, 0.08)
		d.material_override.set_shader_parameter("spin", 0.3)
		_mi(_cyl_mesh(Data.FOUNTAIN_RADIUS * 0.35, 0.3), std(c, 1.6), Vector3(f.x, 0.15, f.y))
	# Marcas dos acampamentos
	for c in Data.CAMPS:
		var p: Vector2 = c[0]
		_decal(Vector3(p.x, 0.01, p.y), 4.0 if c[1] == 0 else 7.0, Color(0.95, 0.75, 0.3, 0.5), 1, 0.08)
	# Árvores e pedras (as mesmas posições usadas na colisão)
	var obs := Data.gen_obstacles()
	var groups := {}
	for i in range(obs.size()):
		var o: Vector3 = obs[i]
		var is_rock := (i / 2) % 5 == 0
		var path: String = Models.ROCKS[i % 2] if is_rock else Models.TREES[(i / 2) % 3]
		var sc := o.z / (1.25 if is_rock else 1.15)
		var b := Basis(Vector3.UP, float(i) * 1.7).scaled(Vector3(sc, sc * (1.0 if is_rock else 1.1), sc))
		if not groups.has(path):
			groups[path] = []
		groups[path].append(Transform3D(b, Vector3(o.x, 0, o.y)))
	# Moldura de floresta além da borda do mapa
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var k := 0
	var edge := Data.MAP_HALF
	var t := -edge - 8.0
	while t <= edge + 8.0:
		for side in range(4):
			var off := rng.randf_range(3.0, 12.0)
			var p := Vector2.ZERO
			match side:
				0: p = Vector2(t, -edge - off)
				1: p = Vector2(t, edge + off)
				2: p = Vector2(-edge - off, t)
				3: p = Vector2(edge + off, t)
			var path2: String = Models.TREES[k % 3]
			var sc2 := rng.randf_range(1.1, 1.7)
			k += 1
			# Sem árvores grandes perto das bases (tapariam a câmera)
			if p.distance_to(Data.FOUNTAIN_POS[0]) < 34.0 or p.distance_to(Data.FOUNTAIN_POS[1]) < 34.0:
				path2 = Models.ROCKS[k % 2]
				sc2 = rng.randf_range(0.8, 1.3)
			if not groups.has(path2):
				groups[path2] = []
			groups[path2].append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc2, sc2 * 1.15, sc2)), Vector3(p.x, 0, p.y)))
		t += 4.5
	for path in groups:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = Models.first_mesh(path)
		var list: Array = groups[path]
		mm.instance_count = list.size()
		for j in range(list.size()):
			mm.set_instance_transform(j, list[j])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		add_child(mmi)


func _cyl_mesh(r: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 24
	return c


# ---------------------------------------------------------------- unidades

func _model_path(kind: int, sub: int) -> String:
	match kind:
		0: return Models.HEROES[sub]
		1: return Models.MELEE
		2: return Models.RANGED
		3: return Models.SIEGE
		4: return Models.TOWER
		5: return Models.NEXUS
		6: return Models.MONSTER
		7: return Models.BOSS
	return Models.MELEE


func _make_unit(id: int, kind: int, team: int, sub: int) -> Node3D:
	var root := Node3D.new()
	var model := Models.make(_model_path(kind, sub), team)
	model.name = "Model"
	root.add_child(model)
	# Escala visual (legibilidade no celular, como nos MOBAs)
	match kind:
		0: model.scale = Vector3.ONE * 1.35
		1, 2: model.scale = Vector3.ONE * 1.2
		3: model.scale = Vector3.ONE * 1.1
		6: model.scale = Vector3.ONE * 1.1
	if kind == 0:
		var col: Color
		if id == local_hero:
			col = Color(0.35, 1.0, 0.45)
		elif team == local_team:
			col = Color(0.35, 0.7, 1.0)
		else:
			col = Color(1.0, 0.3, 0.25)
		var ring := _decal(Vector3.ZERO, 1.5, Color(col.r, col.g, col.b, 0.9), 1, 0.12, root)
		ring.name = "Ring"
	elif kind in [1, 2, 3]:
		var tc: Color = Color(0.35, 0.7, 1.0) if team == local_team else Color(1.0, 0.3, 0.25)
		_decal(Vector3.ZERO, 0.75 if kind != 3 else 1.3, Color(tc.r, tc.g, tc.b, 0.6), 1, 0.05, root)
	# Efeitos de estado
	var shield := _sphere(1.0, fx_mat(Color(0.5, 0.8, 1.0, 0.35), 0), Vector3(0, 1.2, 0), root)
	shield.scale = Vector3(1.25, 1.45, 1.25) if kind == 0 else Vector3.ONE * 0.9
	shield.name = "Shield"
	shield.visible = false
	var stun := Node3D.new()
	stun.name = "Stun"
	stun.position.y = 3.0 if kind == 0 else 2.2
	stun.visible = false
	root.add_child(stun)
	for i in range(3):
		var star := _sphere(0.13, std(Color(1.0, 0.9, 0.3), 3.0), Vector3(cos(i * 2.1) * 0.5, 0, sin(i * 2.1) * 0.5), stun)
		star.scale = Vector3(0.13, 0.13, 0.13)
	var recall := MeshInstance3D.new()
	recall.mesh = _cyl_mesh(1.1, 5.0)
	recall.material_override = fx_mat(Color(0.35, 0.65, 1.0, 0.5), 0)
	recall.position.y = 2.5
	recall.name = "Recall"
	recall.visible = false
	root.add_child(recall)
	var buff := _decal(Vector3.ZERO, 1.6, Color(1.0, 0.75, 0.3, 0.8), 4, 0.0, root)
	buff.name = "Buff"
	buff.material_override.set_shader_parameter("spin", 3.0)
	buff.visible = false
	return root


func apply(snap: PackedByteArray) -> void:
	if snap.size() < Sim.HEADER:
		return
	time = snap.decode_float(0)
	score = [snap.decode_s16(4), snap.decode_s16(6)]
	winner = snap.decode_s16(8)
	var n := snap.decode_s16(10)
	var seen := {}
	var o := Sim.HEADER
	for k in range(n):
		var id := snap.decode_s16(o)
		var d := {
			"kind": snap.decode_s16(o + 2), "team": snap.decode_s16(o + 4), "sub": snap.decode_s16(o + 6),
			"pos": Vector3(snap.decode_s16(o + 8) / 100.0, 0, snap.decode_s16(o + 10) / 100.0),
			"rot": snap.decode_s16(o + 12) / 10000.0, "hp": float(snap.decode_s16(o + 14)),
			"max_hp": float(snap.decode_s16(o + 16)), "flags": snap.decode_s16(o + 18),
			"level": snap.decode_s16(o + 20), "shield": float(snap.decode_s16(o + 22)),
			"respawn": snap.decode_s16(o + 24) / 10.0,
		}
		o += Sim.STRIDE * 2
		seen[id] = true
		var node: Node3D = nodes.get(id)
		if node == null:
			node = _make_unit(id, d.kind, d.team, d.sub)
			add_child(node)
			node.position = d.pos
			node.rotation.y = -d.rot + PI / 2
			nodes[id] = node
			d["vis_pos"] = d.pos
			d["ap"] = Models.anim_player(node.get_node("Model"))
			d["state"] = "idle"
			d["action_until"] = 0.0
			d["dead_t"] = 0.0
		else:
			var old: Dictionary = info[id]
			for key in ["vis_pos", "ap", "state", "action_until", "dead_t"]:
				d[key] = old[key]
		info[id] = d
	for id in nodes.keys():
		if not seen.has(id):
			_retire(id)
	# Projéteis
	var np := snap.decode_s16(o)
	o += 2
	var pseen := {}
	for k in range(np):
		var px := snap.decode_s16(o) / 100.0
		var pz := snap.decode_s16(o + 2) / 100.0
		var kind := snap.decode_s16(o + 4)
		var team := snap.decode_s16(o + 6)
		var hero := snap.decode_s16(o + 8)
		var pid := snap.decode_s16(o + 10)
		o += 12
		pseen[pid] = true
		var y := 1.5 if hero != -3 else 4.0
		var target := Vector3(px, y, pz)
		var pn: Node3D = projs.get(pid)
		if pn == null:
			pn = _make_projectile(kind, team, hero)
			add_child(pn)
			pn.position = target
			pn.set_meta("target", target)
			projs[pid] = pn
		else:
			var prev: Vector3 = pn.get_meta("target")
			if prev.distance_to(target) > 0.05:
				pn.look_at(pn.position + (target - prev).normalized(), Vector3.UP)
			pn.set_meta("target", target)
	for pid in projs.keys():
		if not pseen.has(pid):
			var pn2: Node3D = projs[pid]
			projs.erase(pid)
			pn2.queue_free()


func _retire(id: int) -> void:
	var node: Node3D = nodes[id]
	var d: Dictionary = info[id]
	nodes.erase(id)
	info.erase(id)
	var ap: AnimationPlayer = d.get("ap")
	if ap and ap.has_animation("death") and node.visible:
		ap.play("death", 0.1)
		for c in node.get_children():
			if c.name != "Model":
				c.visible = false
		var tw := create_tween()
		tw.tween_interval(1.1)
		tw.tween_property(node, "position:y", -1.5, 0.6)
		tw.tween_callback(node.queue_free)
	else:
		if d.kind == 4 or d.kind == 5:
			_burst(d.pos + Vector3(0, 3, 0), Data.TEAM_COLORS[d.team], 40, 1.5)
		node.queue_free()


func _make_projectile(kind: int, team: int, hero: int) -> Node3D:
	var root := Node3D.new()
	var c: Color
	if hero >= 0:
		c = Data.HEROES[hero].color.lightened(0.35)
	else:
		c = Data.TEAM_COLORS[team].lightened(0.25)
	var is_arrow := hero == 3
	var big := kind >= 1
	var size := 0.32 if not big else 0.6
	if kind == 4 and hero == 3:
		size = 1.1
	if is_arrow:
		var shaft := BoxMesh.new()
		shaft.size = Vector3(0.12, 0.12, 1.6 if big else 1.0)
		_mi(shaft, std(c, 3.0), Vector3.ZERO, root).scale = Vector3.ONE * (1.6 if kind == 4 else 1.0)
		var head := PrismMesh.new()
		head.size = Vector3(0.35, 0.5, 0.12)
		var hm := _mi(head, std(Color(1, 0.95, 0.8), 4.0), Vector3(0, 0, -0.9 if big else -0.6), root)
		hm.rotation.x = deg_to_rad(-90)
	else:
		_sphere(size, std(c, 4.0), Vector3.ZERO, root)
		_sphere(size * 1.9, fx_mat(Color(c.r, c.g, c.b, 0.5), 3), Vector3.ZERO, root)
	if hero == -2:
		root.get_child(0).material_override = std(Color(0.2, 0.2, 0.22))
	# Rastro
	var trail := CPUParticles3D.new()
	trail.amount = 16 if big else 8
	trail.lifetime = 0.35
	trail.local_coords = false
	trail.gravity = Vector3.ZERO
	trail.initial_velocity_min = 0.0
	trail.initial_velocity_max = 0.4
	trail.spread = 180
	trail.scale_amount_min = size * 0.6
	trail.scale_amount_max = size * 1.1
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	trail.scale_amount_curve = curve
	var qm := SphereMesh.new()
	qm.radius = 0.5
	qm.height = 1.0
	qm.radial_segments = 8
	qm.rings = 4
	qm.material = fx_mat(Color(c.r, c.g, c.b, 0.55), 0)
	trail.mesh = qm
	root.add_child(trail)
	trail.emitting = true
	return root


func _process(dt: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	for pid in projs:
		var pn: Node3D = projs[pid]
		pn.position = pn.position.lerp(pn.get_meta("target"), 1.0 - exp(-dt * 22.0))
	for id in nodes:
		var node: Node3D = nodes[id]
		var d: Dictionary = info[id]
		var flags: int = d.flags
		var dead := flags & 1 != 0
		var ap: AnimationPlayer = d.ap
		if dead:
			if d.state != "death":
				d.state = "death"
				d.dead_t = now
				if ap and ap.has_animation("death"):
					ap.play("death", 0.1)
				for c in node.get_children():
					if c.name != "Model":
						c.visible = false
			node.visible = now - d.dead_t < 2.5
			continue
		if d.state == "death":
			d.state = "idle"
			node.visible = true
			node.position = d.pos
			d.vis_pos = d.pos
			if node.has_node("Ring"):
				node.get_node("Ring").visible = true
		var prev: Vector3 = d.vis_pos
		var target: Vector3 = d.pos
		var k := 1.0 - exp(-dt * (30.0 if flags & 64 else 14.0))
		if prev.distance_to(target) > 12.0:
			prev = target
		var np := prev.lerp(target, k)
		var speed := prev.distance_to(np) / maxf(dt, 0.001)
		d.vis_pos = np
		node.position = np
		var want: float = -d.rot + PI / 2
		node.rotation.y = lerp_angle(node.rotation.y, want, 1.0 - exp(-dt * 16.0))
		# Animação
		if ap:
			if now < d.action_until:
				pass
			elif speed > 0.8 and ap.has_animation("run"):
				if d.state != "run":
					ap.play("run", 0.12)
					d.state = "run"
				ap.speed_scale = clampf(speed / 6.5, 0.7, 1.6)
			elif d.state != "idle":
				ap.play("idle", 0.2)
				ap.speed_scale = 1.0
				d.state = "idle"
		elif d.kind == 3:
			node.get_node("Model").position.y = absf(sin(now * 9.0)) * 0.05 * minf(speed, 1.0)
		node.get_node("Shield").visible = d.shield > 0
		var stun: Node3D = node.get_node("Stun")
		stun.visible = flags & 2 != 0
		stun.rotation.y += dt * 6.0
		node.get_node("Recall").visible = flags & 8 != 0
		node.get_node("Buff").visible = flags & 16 != 0
	if local_hero and info.has(local_hero) and range_node.visible:
		range_node.position = info[local_hero].vis_pos + Vector3(0, 0.07, 0)
	if aim_node.get_child_count() > 0 and info.has(local_hero):
		aim_node.position = info[local_hero].vis_pos


func hero_world_pos(id: int) -> Vector3:
	if info.has(id):
		return info[id].vis_pos
	return Vector3.ZERO


func _play(id: int, anim: String, speed := 1.0) -> void:
	if not info.has(id):
		return
	var d: Dictionary = info[id]
	var ap: AnimationPlayer = d.ap
	if ap and ap.has_animation(anim) and not (d.flags & 1):
		ap.play(anim, 0.05)
		ap.speed_scale = speed
		d.state = anim
		d.action_until = Time.get_ticks_msec() / 1000.0 + ap.get_animation(anim).length / speed * 0.9


# ---------------------------------------------------------------- efeitos

func on_events(evs: Array) -> void:
	for e in evs:
		match e.t:
			"atk":
				if info.has(e.a):
					var a: Dictionary = info[e.a]
					_play(e.a, "attack", 1.5)
					var melee: bool = a.kind == 1 or a.kind == 6 or a.kind == 7 or (a.kind == 0 and not Data.HEROES[a.sub].ranged)
					if melee and info.has(e.b):
						var tp: Vector3 = info[e.b].vis_pos
						var c: Color = Data.HEROES[a.sub].color.lightened(0.4) if a.kind == 0 else Color(1, 0.95, 0.85)
						_slash(a.vis_pos + Vector3(0, 1.2, 0), (tp - a.vis_pos), 1.6 if a.kind == 0 else 1.0, c, 0.18)
			"cast":
				_play(e.a, "cast", 1.3)
				_cast_fx(e)
			"boom":
				_boom_fx(e)
			"pop":
				var pc: Color = Data.HEROES[e.hero].color.lightened(0.3) if e.hero >= 0 else Color(1, 1, 1)
				_flash(Vector3(e.x, 1.4, e.z), pc, 1.2)
			"kill":
				if info.has(e.b):
					_burst(info[e.b].vis_pos + Vector3(0, 1.2, 0), Color(1, 0.35, 0.25), 26, 1.0)
			"tower":
				_burst(Vector3(e.x, 4, e.z), Data.TEAM_COLORS[e.team], 50, 1.6)
				_shock(Vector3(e.x, 0, e.z), 9.0, Data.TEAM_COLORS[e.team], 0.6)
				_spikes(Vector3(e.x, 0, e.z), 3.5, 8, Color(0.4, 0.38, 0.42))
			"lvl":
				if info.has(e.a):
					_column(info[e.a].vis_pos, Color(1.0, 0.8, 0.3), 0.7, 1.2)
			"blink":
				_flash(Vector3(e.x, 1.2, e.z), Color(0.7, 0.35, 1.0), 2.5)
				_burst(Vector3(e.x, 1.2, e.z), Color(0.7, 0.35, 1.0), 14, 0.8)
			"flash":
				_flash(Vector3(e.x, 1.2, e.z), Color(1.0, 0.95, 0.5), 2.0)
			"flash_end":
				_flash(Vector3(e.x, 1.2, e.z), Color(1.0, 0.95, 0.5), 2.5)
				_burst(Vector3(e.x, 1.2, e.z), Color(1.0, 0.95, 0.6), 12, 0.7)
			"heal":
				if info.has(e.a):
					_heal_fx(info[e.a].vis_pos, 2.5)
				if e.b and info.has(e.b):
					_heal_fx(info[e.b].vis_pos, 2.0)
			"respawn", "recalled":
				if info.has(e.a):
					_column(info[e.a].pos, Data.TEAM_COLORS[info[e.a].team], 0.6, 1.5)


func _cast_fx(e: Dictionary) -> void:
	if not info.has(e.a):
		return
	var u: Dictionary = info[e.a]
	if u.kind != 0:
		return
	var h: int = u.sub
	var ab: int = e.ab
	var a: Dictionary = Data.HEROES[h].abilities[ab]
	var hc: Color = Data.HEROES[h].color.lightened(0.3)
	var pos: Vector3 = u.vis_pos
	var dir := Vector3(e.dx, 0, e.dz)
	var point := Vector3(e.x, 0, e.z)
	match a.type:
		"dash":
			_slash(pos + Vector3(0, 1.0, 0), dir, 2.4, hc, 0.3)
			_dust(pos, 10)
			if a.get("d", 0) > 0:
				_trail_line(pos, pos + dir * a.dist, hc, 1.4)
		"nova":
			_shock(pos, a.radius, hc, 0.45)
			if h == 0:
				for i in range(3):
					_slash(pos + Vector3(0, 1.0, 0), Vector3(cos(i * 2.1), 0, sin(i * 2.1)), a.radius, hc, 0.4, 14.0)
			else:
				_spikes(pos, a.radius * 0.7, 10 if ab == 3 else 7, Color(0.42, 0.4, 0.36))
				_dust(pos, 20)
		"blast":
			var tele := _decal(point, a.radius, Color(hc.r, hc.g, hc.b, 0.95), 1, 0.3)
			var m: ShaderMaterial = tele.material_override
			var tw := create_tween()
			tw.tween_method(func(v): m.set_shader_parameter("progress", v), 0.0, 1.0, a.delay)
			tw.tween_callback(tele.queue_free)
			if h == 2:
				var well := _decal(point, a.radius * 1.1, Color(0.6, 0.3, 1.0, 0.8), 4, 0.0)
				well.material_override.set_shader_parameter("spin", -4.0)
				_alpha_tween(well, 1.0, 0.0, a.delay + 0.5)
		"buff":
			if a.has("shield"):
				_shock(pos, 2.5, Color(0.5, 0.8, 1.0), 0.35)
			if a.has("aspd"):
				_burst(pos + Vector3(0, 1, 0), hc, 16, 0.8)
			if a.get("allies", 0.0) > 0:
				_shock(pos, a.allies, Color(1.0, 0.85, 0.4), 0.5)
		"heal":
			_heal_fx(pos, a.radius)
			if ab == 3:
				_column(pos, Color(1.0, 0.9, 0.5), 1.2, 4.0)
			if a.has("then"):
				_shock(pos, a.then.radius, Color(1.0, 0.85, 0.4), 0.5)
		"skillshot":
			_flash(pos + Vector3(0, 1.4, 0) + dir * 0.8, hc, 1.6)


func _boom_fx(e: Dictionary) -> void:
	var p := Vector3(e.x, 0, e.z)
	var h: int = e.get("hero", -1)
	var c: Color = Data.HEROES[h].color.lightened(0.3) if h >= 0 else Data.TEAM_COLORS[e.team]
	_shock(p, e.r, c, 0.4)
	_flash(p + Vector3(0, 1.0, 0), c, e.r * 0.9)
	_burst(p + Vector3(0, 0.6, 0), c, 18 + int(e.r * 4), 1.0 + e.r * 0.15)
	if h == 0:
		_spikes(p, e.r * 0.8, 8, Color(0.45, 0.42, 0.4))
		_dust(p, 24)
	elif h == 2 and e.get("abi", 0) == 3:
		_column(p, Color(0.6, 0.3, 1.0), 0.8, e.r * 0.8)


func _flash(p: Vector3, c: Color, size: float) -> void:
	var s := _sphere(0.35 * size, fx_mat(Color(c.r, c.g, c.b, 0.9), 3), p)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(s, "scale", Vector3.ONE * 0.8 * size, 0.22)
	tw.tween_method(func(v): s.material_override.set_shader_parameter("alpha", v), 1.0, 0.0, 0.25)
	tw.chain().tween_callback(s.queue_free)


func _shock(p: Vector3, r: float, c: Color, dur: float) -> void:
	var ring := _decal(p, r * 0.2, Color(c.r, c.g, c.b, 1.0), 1, 0.5)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector3(r, 1, r), dur * 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_method(func(v): ring.material_override.set_shader_parameter("alpha", v), 1.0, 0.0, dur)
	tw.chain().tween_callback(ring.queue_free)


func _slash(p: Vector3, dir: Vector3, r: float, c: Color, dur: float, spin := 0.0) -> void:
	var holder := Node3D.new()
	add_child(holder)
	holder.position = p
	if dir.length() > 0.01:
		holder.rotation.y = atan2(dir.x, dir.z)
	var slash: Node3D = Models.scene(Models.SLASH).instantiate()
	holder.add_child(slash)
	var mat := fx_mat(Color(c.r, c.g, c.b, 1.0), 0)
	for mi in slash.find_children("*", "MeshInstance3D", true, false):
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	slash.scale = Vector3.ONE * r * 0.6
	slash.rotation.z = deg_to_rad(randf_range(-25, 25))
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(slash, "scale", Vector3.ONE * r, dur)
	tw.tween_property(holder, "rotation:y", holder.rotation.y + (spin if spin != 0.0 else 0.6), dur)
	tw.tween_method(func(v): mat.set_shader_parameter("alpha", v), 1.0, 0.0, dur)
	tw.chain().tween_callback(holder.queue_free)


func _trail_line(a: Vector3, b: Vector3, c: Color, w: float) -> void:
	var len := a.distance_to(b)
	if len < 0.1:
		return
	var pm := PlaneMesh.new()
	pm.size = Vector2(w, len)
	var mi := _mi(pm, fx_mat(Color(c.r, c.g, c.b, 0.8), 5, 0.0), (a + b) / 2 + Vector3(0, 0.1, 0))
	mi.rotation.y = atan2(b.x - a.x, b.z - a.z)
	mi.rotate_object_local(Vector3.UP, PI / 2)
	_alpha_tween(mi, 1.0, 0.0, 0.4)


func _column(p: Vector3, c: Color, dur: float, r := 1.0) -> void:
	var col := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r * 0.6
	cm.bottom_radius = r
	cm.height = 7.0
	cm.cap_top = false
	cm.cap_bottom = false
	col.mesh = cm
	col.material_override = fx_mat(Color(c.r, c.g, c.b, 0.6), 0)
	col.position = p + Vector3(0, 3.5, 0)
	col.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(col)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(col, "scale", Vector3(0.2, 1.2, 0.2), dur)
	tw.tween_method(func(v): col.material_override.set_shader_parameter("alpha", v), 1.0, 0.0, dur)
	tw.chain().tween_callback(col.queue_free)


func _heal_fx(p: Vector3, r: float) -> void:
	var c := Color(0.45, 1.0, 0.55)
	_shock(p, r, c, 0.6)
	_column(p, c, 0.8, 1.0)
	var parts := _particles(p + Vector3(0, 0.3, 0), c, 18, 1.0)
	parts.direction = Vector3.UP
	parts.spread = 25
	parts.gravity = Vector3(0, 2, 0)
	parts.initial_velocity_min = 2.0
	parts.initial_velocity_max = 4.0
	parts.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	parts.emission_sphere_radius = 1.0
	parts.emitting = true


func _spikes(p: Vector3, r: float, count: int, c: Color) -> void:
	var m := std(c)
	m.roughness = 0.9
	for i in range(count):
		var a := TAU * i / count + randf() * 0.3
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = 0.45
		cm.height = randf_range(1.2, 2.2)
		cm.radial_segments = 5
		var mi := MeshInstance3D.new()
		mi.mesh = cm
		mi.material_override = m
		var pos := p + Vector3(cos(a), 0, sin(a)) * r * randf_range(0.6, 1.0)
		mi.position = pos + Vector3(0, -cm.height, 0)
		mi.rotation = Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.3, 0.3))
		add_child(mi)
		var tw := create_tween()
		tw.tween_property(mi, "position:y", cm.height * 0.35, 0.12).set_ease(Tween.EASE_OUT)
		tw.tween_interval(0.7)
		tw.tween_property(mi, "position:y", -cm.height, 0.4)
		tw.tween_callback(mi.queue_free)


func _particles(p: Vector3, c: Color, amount: int, size: float) -> CPUParticles3D:
	var parts := CPUParticles3D.new()
	parts.one_shot = true
	parts.amount = amount
	parts.lifetime = 0.8
	parts.explosiveness = 0.9
	parts.local_coords = false
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 6
	sm.rings = 3
	sm.material = fx_mat(Color(c.r, c.g, c.b, 0.9), 0)
	parts.mesh = sm
	parts.scale_amount_min = 0.12 * size
	parts.scale_amount_max = 0.3 * size
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	parts.scale_amount_curve = curve
	parts.position = p
	add_child(parts)
	var tw := create_tween()
	tw.tween_interval(1.6)
	tw.tween_callback(parts.queue_free)
	return parts


func _burst(p: Vector3, c: Color, amount: int, size: float) -> void:
	var parts := _particles(p, c, amount, size)
	parts.direction = Vector3.UP
	parts.spread = 85
	parts.initial_velocity_min = 3.0 * size
	parts.initial_velocity_max = 8.0 * size
	parts.gravity = Vector3(0, -12, 0)
	parts.emitting = true


func _dust(p: Vector3, amount: int) -> void:
	var parts := _particles(p + Vector3(0, 0.3, 0), Color(0.75, 0.65, 0.5), amount, 2.2)
	parts.mesh.material = std(Color(0.55, 0.48, 0.38))
	parts.direction = Vector3.UP
	parts.spread = 80
	parts.initial_velocity_min = 1.5
	parts.initial_velocity_max = 4.0
	parts.gravity = Vector3(0, -3, 0)
	parts.emitting = true


# ---------------------------------------------------------------- mira

const AIM_COLOR := Color(0.35, 0.75, 1.0, 0.85)


func show_aim(hero_id: int, ab: Dictionary, dir: Vector2) -> void:
	hide_aim()
	if not info.has(hero_id):
		return
	aim_node.position = info[hero_id].vis_pos
	var rng: float = ab.get("range", 0.0)
	var d := dir.normalized() if dir.length() > 0.01 else Vector2(0, -1)
	var ang := atan2(d.x, d.y)
	var holder := Node3D.new()
	holder.rotation.y = ang
	aim_node.add_child(holder)
	match ab.type:
		"skillshot", "dash", "blink":
			var len: float = minf(rng if ab.type == "skillshot" else ab.dist, 30.0)
			var w: float = ab.get("width", 1.1)
			var pm := PlaneMesh.new()
			pm.size = Vector2(w, len)
			_mi(pm, fx_mat(AIM_COLOR, 2, 0.18), Vector3(0, 0.1, len / 2), holder)
			var tip := PrismMesh.new()
			tip.size = Vector3(w * 1.6, 1.0, 0.02)
			var t := _mi(tip, fx_mat(AIM_COLOR, 0, 0.0, 0.6), Vector3(0, 0.12, len + 0.4), holder)
			t.rotation.x = deg_to_rad(90)
			if ab.type != "skillshot":
				_decal(Vector3(0, 0.05, len), 0.9, AIM_COLOR, 1, 0.3, holder)
		"blast":
			var frac := clampf(dir.length(), 0.0, 1.0)
			_decal(Vector3.ZERO, rng, Color(1, 1, 1, 0.5), 1, 0.06, aim_node)
			_decal(Vector3(d.x, 0, d.y) * rng * frac + Vector3(0, 0.02, 0), ab.radius, AIM_COLOR, 1, 0.3, aim_node)
		"nova":
			_decal(Vector3.ZERO, ab.radius, AIM_COLOR, 1, 0.25, aim_node)
		"heal", "buff":
			var r: float = ab.get("radius", ab.get("allies", 2.0))
			_decal(Vector3.ZERO, maxf(r, 2.0), Color(0.5, 1.0, 0.6, 0.85), 1, 0.2, aim_node)


func hide_aim() -> void:
	for c in aim_node.get_children():
		c.queue_free()


func show_range(r: float) -> void:
	range_node.visible = r > 0
	if r > 0:
		range_node.scale = Vector3(r, 1, r)
