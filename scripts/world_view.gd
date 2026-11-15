class_name WorldView
extends Node3D
## Desenha o mapa e as unidades a partir dos snapshots da simulação.

var nodes := {}       # id -> Node3D
var info := {}        # id -> Dictionary com o último estado
var proj_pool := []
var mats := {}
var time := 0.0
var score := [0, 0]
var winner := -1
var aim_node: Node3D
var local_hero := 0
var range_ring: MeshInstance3D


func _ready() -> void:
	_build_environment()
	_build_map()
	aim_node = Node3D.new()
	add_child(aim_node)
	range_ring = _ring(1.0, Color(1, 1, 1, 0.25), 0.08)
	add_child(range_ring)
	range_ring.visible = false


# ---------------------------------------------------------------- materiais

func mat(c: Color, emit := 0.0, alpha := 1.0, rough := 0.8) -> StandardMaterial3D:
	var key := "%s_%.2f_%.2f_%.2f" % [c.to_html(), emit, alpha, rough]
	if mats.has(key):
		return mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(c.r, c.g, c.b, alpha)
	m.roughness = rough
	if emit > 0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if emit > 0 else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mats[key] = m
	return m


func _mesh(mesh: Mesh, m: Material, pos := Vector3.ZERO, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	if parent:
		parent.add_child(mi)
	return mi


func _box(size: Vector3, m: Material, pos := Vector3.ZERO, parent: Node3D = null) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	return _mesh(b, m, pos, parent)


func _sphere(r: float, m: Material, pos := Vector3.ZERO, parent: Node3D = null, seg := 16) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2
	s.radial_segments = seg
	s.rings = maxi(4, seg / 2)
	return _mesh(s, m, pos, parent)


func _cyl(top: float, bottom: float, h: float, m: Material, pos := Vector3.ZERO, parent: Node3D = null, seg := 16) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = seg
	return _mesh(c, m, pos, parent)


func _capsule(r: float, h: float, m: Material, pos := Vector3.ZERO, parent: Node3D = null) -> MeshInstance3D:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = h
	return _mesh(c, m, pos, parent)


func _ring(r: float, c: Color, thick := 0.12) -> MeshInstance3D:
	var t := TorusMesh.new()
	t.inner_radius = r - thick
	t.outer_radius = r
	t.rings = 32
	t.ring_segments = 4
	var mi := _mesh(t, mat(c, 2.0, c.a))
	mi.scale = Vector3(1, 0.15, 1)
	return mi


# ---------------------------------------------------------------- cenário

func _build_environment() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.08, 0.1, 0.22)
	sm.sky_horizon_color = Color(0.35, 0.28, 0.4)
	sm.ground_bottom_color = Color(0.05, 0.05, 0.08)
	sm.ground_horizon_color = Color(0.3, 0.25, 0.35)
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.1
	env.glow_hdr_threshold = 1.1
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.15
	env.adjustment_contrast = 1.08
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.light_energy = 1.25
	sun.light_color = Color(1.0, 0.93, 0.85)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 70.0
	add_child(sun)


func _build_map() -> void:
	# Chão com variação de cor
	var noise := FastNoiseLite.new()
	noise.frequency = 0.012
	noise.fractal_octaves = 4
	var tex := NoiseTexture2D.new()
	tex.width = 512
	tex.height = 512
	tex.noise = noise
	tex.seamless = true
	var grad := Gradient.new()
	grad.set_color(0, Color(0.09, 0.2, 0.12))
	grad.set_color(1, Color(0.2, 0.32, 0.16))
	tex.color_ramp = grad
	var gm := StandardMaterial3D.new()
	gm.albedo_texture = tex
	gm.roughness = 0.95
	gm.uv1_scale = Vector3(3, 3, 3)
	var plane := PlaneMesh.new()
	plane.size = Vector2(Data.MAP_HALF * 2 + 30, Data.MAP_HALF * 2 + 30)
	_mesh(plane, gm, Vector3.ZERO, self)
	# Bordas do mapa (penhascos)
	var cliff := mat(Color(0.16, 0.14, 0.18))
	for side in [Vector3(0, 0, -1), Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(1, 0, 0)]:
		var size := Vector3(Data.MAP_HALF * 2 + 30, 6, 6) if side.x == 0 else Vector3(6, 6, Data.MAP_HALF * 2 + 30)
		_box(size, cliff, side * (Data.MAP_HALF + 5) + Vector3(0, 2, 0), self)
	# Rio
	var river := _box(Vector3(10, 0.05, Data.MAP_HALF * 2.9), mat(Color(0.12, 0.45, 0.65), 0.35, 0.85, 0.1), Vector3(0, 0.03, 0), self)
	river.rotation.y = deg_to_rad(45)
	# Rotas
	var lane_m := mat(Color(0.42, 0.36, 0.3), 0.0, 1.0, 0.9)
	var edge_m := mat(Color(0.3, 0.26, 0.22))
	for lane in Data.LANES:
		for i in range(lane.size() - 1):
			var a: Vector2 = lane[i]
			var b: Vector2 = lane[i + 1]
			var mid := (a + b) * 0.5
			var len := a.distance_to(b)
			var ang := -(b - a).angle()
			var e := _box(Vector3(len + 9.5, 0.04, 9.5), edge_m, Vector3(mid.x, 0.04, mid.y), self)
			e.rotation.y = ang
			var s := _box(Vector3(len + 8.0, 0.05, 8.0), lane_m, Vector3(mid.x, 0.05, mid.y), self)
			s.rotation.y = ang
	# Bases
	for team in [0, 1]:
		var p: Vector2 = Data.NEXUS_POS[team]
		var col: Color = Data.TEAM_COLORS[team]
		_cyl(17, 18, 0.3, mat(Color(0.32, 0.3, 0.34)), Vector3(p.x, 0.12, p.y), self, 32)
		_cyl(15, 15, 0.32, mat(col.darkened(0.6)), Vector3(p.x, 0.14, p.y), self, 32)
		var f: Vector2 = Data.FOUNTAIN_POS[team]
		_cyl(Data.FOUNTAIN_RADIUS * 0.55, Data.FOUNTAIN_RADIUS * 0.6, 0.4, mat(col, 1.4, 0.55), Vector3(f.x, 0.2, f.y), self, 32)
		var ring := _ring(Data.FOUNTAIN_RADIUS * 0.6, Color(col.r, col.g, col.b, 0.9), 0.25)
		ring.position = Vector3(f.x, 0.4, f.y)
		add_child(ring)
	# Árvores e rochas (MultiMesh para rodar leve no celular)
	var obs := Data.gen_obstacles()
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.25
	trunk.bottom_radius = 0.4
	trunk.height = 2.0
	var crown := CylinderMesh.new()
	crown.top_radius = 0.0
	crown.bottom_radius = 1.0
	crown.height = 2.2
	crown.radial_segments = 7
	var rock := SphereMesh.new()
	rock.radial_segments = 6
	rock.rings = 3
	var mm_trunk := _multimesh(trunk, mat(Color(0.3, 0.2, 0.14)), obs.size())
	var mm_crown := _multimesh(crown, mat(Color(0.1, 0.32, 0.22)), obs.size() * 2)
	var mm_rock := _multimesh(rock, mat(Color(0.35, 0.34, 0.38)), obs.size())
	var ci := 0
	for i in range(obs.size()):
		var o: Vector3 = obs[i]
		var r := o.z
		var is_rock := (i / 2) % 5 == 0
		if is_rock:
			mm_rock.multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(r * 1.1, r * 0.8, r)), Vector3(o.x, r * 0.3, o.y)))
			mm_trunk.multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
			mm_crown.multimesh.set_instance_transform(ci, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
			mm_crown.multimesh.set_instance_transform(ci + 1, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
		else:
			mm_rock.multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
			mm_trunk.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(o.x, 1.0, o.y)))
			var b := Basis.from_scale(Vector3(r * 1.3, r * 1.1, r * 1.3))
			mm_crown.multimesh.set_instance_transform(ci, Transform3D(b, Vector3(o.x, 2.6 + r * 0.4, o.y)))
			var b2 := Basis(Vector3.UP, float(i)).scaled(Vector3(r, r * 0.9, r))
			mm_crown.multimesh.set_instance_transform(ci + 1, Transform3D(b2, Vector3(o.x, 3.9 + r * 0.6, o.y)))
		ci += 2
	# Marcas dos acampamentos
	for c in Data.CAMPS:
		var p: Vector2 = c[0]
		var rr := _ring(3.5 if c[1] == 0 else 6.0, Color(0.95, 0.75, 0.3, 0.35), 0.2)
		rr.position = Vector3(p.x, 0.08, p.y)
		add_child(rr)


func _multimesh(mesh: Mesh, m: Material, count: int) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = count
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = m
	add_child(mmi)
	return mmi


# ---------------------------------------------------------------- unidades

func _make_unit(kind: int, team: int, sub: int) -> Node3D:
	var root := Node3D.new()
	var body := Node3D.new()
	body.name = "Body"
	root.add_child(body)
	var tc: Color = Data.TEAM_COLORS[team]
	match kind:
		0:
			_make_hero(body, sub, tc)
			var ring := _ring(1.0, Color(tc.r, tc.g, tc.b, 0.9), 0.14)
			ring.position.y = 0.06
			root.add_child(ring)
		1:
			var m := mat(tc.darkened(0.15), 0.0, 1.0, 0.6)
			_capsule(0.38, 1.1, m, Vector3(0, 0.6, 0), body)
			_box(Vector3(0.08, 0.08, 0.7), mat(Color(0.8, 0.8, 0.85), 0.0, 1.0, 0.3), Vector3(0.35, 0.7, 0.3), body)
			_sphere(0.22, mat(Color(0.9, 0.85, 0.75)), Vector3(0, 1.25, 0), body, 8)
		2:
			var m2 := mat(tc.darkened(0.3))
			_cyl(0.15, 0.45, 1.1, m2, Vector3(0, 0.55, 0), body, 8)
			_sphere(0.22, mat(Color(0.9, 0.85, 0.75)), Vector3(0, 1.25, 0), body, 8)
			_sphere(0.16, mat(tc, 3.0), Vector3(0.35, 1.0, 0.3), body, 8)
		3:
			_box(Vector3(1.4, 0.7, 1.6), mat(Color(0.35, 0.25, 0.18)), Vector3(0, 0.6, 0), body)
			var cannon := _cyl(0.22, 0.3, 1.6, mat(Color(0.2, 0.2, 0.22), 0.0, 1.0, 0.3), Vector3(0, 1.1, 0.4), body, 10)
			cannon.rotation.x = deg_to_rad(80)
			_box(Vector3(1.5, 0.15, 0.2), mat(tc, 1.5), Vector3(0, 1.0, -0.7), body)
			for x in [-0.75, 0.75]:
				var w := _cyl(0.35, 0.35, 0.15, mat(Color(0.15, 0.12, 0.1)), Vector3(x, 0.35, 0), body, 10)
				w.rotation.z = deg_to_rad(90)
		4:
			var stone := mat(Color(0.5, 0.48, 0.52))
			_cyl(1.4, 1.8, 1.0, mat(Color(0.3, 0.29, 0.32)), Vector3(0, 0.5, 0), body, 8)
			_cyl(0.9, 1.3, 5.0, stone, Vector3(0, 3.0, 0), body, 8)
			_cyl(1.4, 1.0, 0.6, stone, Vector3(0, 5.7, 0), body, 8)
			var cr := _sphere(0.75, mat(tc, 3.5), Vector3(0, 7.2, 0), body, 4)
			cr.name = "Crystal"
			cr.scale = Vector3(1, 1.6, 1)
		5:
			_cyl(3.2, 3.8, 1.2, mat(Color(0.32, 0.3, 0.35)), Vector3(0, 0.6, 0), body, 10)
			for i in range(4):
				var ang := i * PI / 2 + PI / 4
				var pil := _box(Vector3(0.5, 4.0, 0.5), mat(Color(0.5, 0.48, 0.52)), Vector3(cos(ang) * 2.6, 2.6, sin(ang) * 2.6), body)
				pil.rotation.y = -ang
			var core := _sphere(1.8, mat(tc, 3.0), Vector3(0, 5.0, 0), body, 6)
			core.name = "Crystal"
			core.scale = Vector3(1, 1.4, 1)
		6:
			var fur := mat(Color(0.35, 0.28, 0.4))
			_box(Vector3(1.2, 1.0, 2.0), fur, Vector3(0, 0.9, 0), body)
			_box(Vector3(0.9, 0.8, 0.9), fur, Vector3(0, 1.3, 1.2), body)
			for x in [-0.3, 0.3]:
				_sphere(0.12, mat(Color(1, 0.6, 0.1), 4.0), Vector3(x, 1.45, 1.66), body, 6)
			for p in [Vector3(-0.45, 0.25, 0.7), Vector3(0.45, 0.25, 0.7), Vector3(-0.45, 0.25, -0.7), Vector3(0.45, 0.25, -0.7)]:
				_box(Vector3(0.3, 0.6, 0.3), fur.duplicate(), p, body)
		7:
			var scale_m := mat(Color(0.12, 0.35, 0.4), 0.0, 1.0, 0.4)
			_sphere(2.0, scale_m, Vector3(0, 2.2, 0), body, 10).scale = Vector3(1.1, 0.8, 1.5)
			_sphere(1.0, scale_m, Vector3(0, 3.0, 2.6), body, 10)
			for x in [-0.6, 0.6]:
				var horn := _cyl(0.0, 0.25, 1.4, mat(Color(0.9, 0.85, 0.7)), Vector3(x, 4.0, 2.4), body, 6)
				horn.rotation.x = deg_to_rad(-30)
				_sphere(0.15, mat(Color(0.3, 1.0, 0.9), 5.0), Vector3(x * 0.7, 3.2, 3.5), body, 6)
			for i in range(5):
				_cyl(0.0, 0.35, 1.0, mat(Color(0.3, 1.0, 0.9), 2.0), Vector3(0, 3.6, 1.2 - i * 0.8), body, 4)
	# Efeitos de estado
	var shield := _sphere(1.3 if kind == 0 else 1.0, mat(Color(0.6, 0.85, 1.0), 1.5, 0.25), Vector3(0, 1.1, 0), root, 12)
	shield.name = "Shield"
	shield.visible = false
	var stun := _ring(0.6, Color(1.0, 0.95, 0.3, 1.0), 0.12)
	stun.name = "Stun"
	stun.position.y = 2.6
	stun.visible = false
	root.add_child(stun)
	var recall := _cyl(1.1, 1.1, 4.0, mat(Color(0.4, 0.7, 1.0), 2.0, 0.25), Vector3(0, 2, 0), root, 16)
	recall.name = "Recall"
	recall.visible = false
	return root


func _make_hero(body: Node3D, h: int, tc: Color) -> void:
	var hc: Color = Data.HEROES[h].color
	var skin := mat(Color(0.92, 0.8, 0.68))
	var main := mat(hc, 0.0, 1.0, 0.45)
	var dark := mat(hc.darkened(0.55), 0.0, 1.0, 0.5)
	var metal := mat(Color(0.75, 0.75, 0.8), 0.0, 1.0, 0.25)
	var glow := mat(hc.lightened(0.2), 3.0)
	var trim := mat(tc, 1.6)
	match Data.HEROES[h].shape:
		"warrior":
			_capsule(0.45, 1.5, main, Vector3(0, 1.0, 0), body)
			_box(Vector3(1.1, 0.25, 0.5), metal, Vector3(0, 1.55, 0), body)
			_sphere(0.3, skin, Vector3(0, 2.0, 0), body)
			_cyl(0.0, 0.34, 0.5, dark, Vector3(0, 2.35, 0), body, 8)
			var sword := _box(Vector3(0.12, 0.12, 1.8), glow, Vector3(0.6, 1.1, 0.6), body)
			sword.rotation.x = deg_to_rad(-20)
			_box(Vector3(0.5, 0.1, 0.1), metal, Vector3(0.6, 1.2, -0.25), body)
			_box(Vector3(0.9, 0.05, 0.3), trim, Vector3(0, 0.85, 0), body)
		"tank":
			_box(Vector3(1.5, 1.6, 1.0), main, Vector3(0, 1.1, 0), body)
			for x in [-0.95, 0.95]:
				_sphere(0.45, metal, Vector3(x, 1.8, 0), body, 10)
			_sphere(0.35, skin, Vector3(0, 2.2, 0.05), body)
			_box(Vector3(0.7, 0.25, 0.6), dark, Vector3(0, 2.45, 0), body)
			var sh := _box(Vector3(1.3, 1.6, 0.2), metal, Vector3(-0.2, 1.1, 0.75), body)
			sh.rotation.y = deg_to_rad(15)
			_box(Vector3(0.5, 0.5, 0.22), trim, Vector3(-0.2, 1.2, 0.86), body).rotation.y = deg_to_rad(15)
			for x in [-0.4, 0.4]:
				_box(Vector3(0.45, 0.7, 0.5), dark, Vector3(x, 0.35, 0), body)
		"mage":
			_cyl(0.2, 0.7, 1.7, main, Vector3(0, 0.85, 0), body, 12)
			_sphere(0.28, skin, Vector3(0, 1.95, 0), body)
			_cyl(0.0, 0.45, 0.9, dark, Vector3(0, 2.45, 0), body, 10)
			_box(Vector3(0.9, 0.05, 0.05), trim, Vector3(0, 1.4, 0.25), body)
			var orb := _sphere(0.25, glow, Vector3(0.7, 1.6, 0.3), body, 10)
			orb.name = "Orb"
			var staff := _cyl(0.04, 0.04, 2.2, mat(Color(0.25, 0.15, 0.3)), Vector3(-0.55, 1.1, 0.2), body, 6)
			staff.rotation.z = deg_to_rad(8)
			_sphere(0.14, glow, Vector3(-0.7, 2.25, 0.2), body, 8)
		"marksman":
			_capsule(0.32, 1.5, main, Vector3(0, 1.0, 0), body)
			_sphere(0.27, skin, Vector3(0, 1.95, 0), body)
			_box(Vector3(0.6, 0.2, 0.5), dark, Vector3(0, 2.15, -0.05), body)
			var cape := _box(Vector3(0.8, 1.3, 0.06), dark, Vector3(0, 1.1, -0.38), body)
			cape.rotation.x = deg_to_rad(10)
			var bow := TorusMesh.new()
			bow.inner_radius = 0.65
			bow.outer_radius = 0.72
			var bowm := _mesh(bow, glow, Vector3(0.5, 1.2, 0.4), body)
			bowm.rotation = Vector3(0, deg_to_rad(90), deg_to_rad(90))
			bowm.scale = Vector3(1, 1, 0.35)
			_box(Vector3(0.7, 0.05, 0.3), trim, Vector3(0, 0.9, 0), body)
		"support":
			_cyl(0.25, 0.6, 1.6, main, Vector3(0, 0.8, 0), body, 12)
			_sphere(0.28, skin, Vector3(0, 1.85, 0), body)
			var halo := _ring(0.45, Color(1.0, 0.9, 0.5, 1.0), 0.07)
			halo.name = "Halo"
			halo.position = Vector3(0, 2.4, 0)
			body.add_child(halo)
			for x in [-0.5, 0.5]:
				var wing := _box(Vector3(0.9, 1.2, 0.05), mat(Color(1, 0.95, 0.75), 1.2, 0.7), Vector3(x * 1.3, 1.6, -0.35), body)
				wing.rotation.z = deg_to_rad(-25 if x > 0 else 25)
			var staff2 := _cyl(0.05, 0.05, 2.4, metal, Vector3(0.6, 1.2, 0.2), body, 6)
			staff2.rotation.z = deg_to_rad(-6)
			_sphere(0.2, glow, Vector3(0.65, 2.45, 0.2), body, 10)
			_box(Vector3(0.8, 0.05, 0.3), trim, Vector3(0, 1.0, 0.2), body)


# ---------------------------------------------------------------- snapshots

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
			node = _make_unit(d.kind, d.team, d.sub)
			add_child(node)
			node.position = d.pos
			node.rotation.y = -d.rot + PI / 2
			nodes[id] = node
			d["vis_pos"] = d.pos
		else:
			d["vis_pos"] = info[id].vis_pos
			d["anim"] = info[id].get("anim", 0.0)
			d["lunge"] = info[id].get("lunge", 0.0)
		info[id] = d
	for id in nodes.keys():
		if not seen.has(id):
			nodes[id].queue_free()
			nodes.erase(id)
			info.erase(id)
	# Projéteis
	var np := snap.decode_s16(o)
	o += 2
	while proj_pool.size() < np:
		var p := _sphere(0.3, mat(Color.WHITE, 3.0), Vector3.ZERO, self, 8)
		proj_pool.append(p)
	for k in range(proj_pool.size()):
		var p: MeshInstance3D = proj_pool[k]
		if k < np:
			var kind := snap.decode_s16(o + 4)
			var team := snap.decode_s16(o + 6)
			var hero := snap.decode_s16(o + 8)
			var c: Color = Data.HEROES[hero].color.lightened(0.3) if hero >= 0 else Data.TEAM_COLORS[team]
			p.material_override = mat(c, 4.0)
			p.scale = Vector3.ONE * (1.6 if kind == 1 else 0.7)
			p.position = Vector3(snap.decode_s16(o) / 100.0, 1.3, snap.decode_s16(o + 2) / 100.0)
			p.visible = true
			o += 10
		else:
			p.visible = false


func _process(dt: float) -> void:
	for id in nodes:
		var node: Node3D = nodes[id]
		var d: Dictionary = info[id]
		var flags: int = d.flags
		var dead := flags & 1 != 0
		node.visible = not dead
		if dead:
			continue
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
		var body: Node3D = node.get_node("Body")
		# Animação simples: balanço ao andar e investida ao atacar
		d.anim = d.get("anim", 0.0) + dt * clampf(speed, 0.0, 10.0) * 1.6
		var bob := sin(d.anim) * 0.08 if speed > 0.5 else 0.0
		d.lunge = maxf(0.0, d.get("lunge", 0.0) - dt * 5.0)
		body.position = Vector3(0, absf(bob), d.lunge * 0.6)
		body.rotation.x = clampf(speed * 0.02, 0.0, 0.15)
		if d.kind == 4 or d.kind == 5:
			var cr: Node3D = body.get_node_or_null("Crystal")
			if cr:
				cr.rotation.y += dt * 0.8
				cr.position.y = (7.2 if d.kind == 4 else 5.0) + sin(Time.get_ticks_msec() / 600.0) * 0.15
				cr.visible = flags & 32 == 0 or int(Time.get_ticks_msec() / 400) % 4 != 0
		var orb := body.get_node_or_null("Orb")
		if orb:
			var t := Time.get_ticks_msec() / 400.0
			orb.position = Vector3(cos(t) * 0.8, 1.6 + sin(t * 2) * 0.1, sin(t) * 0.8)
		var halo := body.get_node_or_null("Halo")
		if halo:
			halo.rotation.y += dt * 2.0
		node.get_node("Shield").visible = d.shield > 0
		var stun: Node3D = node.get_node("Stun")
		stun.visible = flags & 2 != 0
		stun.rotation.y += dt * 6.0
		node.get_node("Recall").visible = flags & 8 != 0
	if local_hero and info.has(local_hero) and range_ring.visible:
		range_ring.position = info[local_hero].vis_pos + Vector3(0, 0.1, 0)


func hero_world_pos(id: int) -> Vector3:
	if info.has(id):
		return info[id].vis_pos
	return Vector3.ZERO


# ---------------------------------------------------------------- efeitos

func on_events(evs: Array) -> void:
	for e in evs:
		match e.t:
			"atk":
				if info.has(e.a):
					info[e.a]["lunge"] = 1.0
					var a: Dictionary = info[e.a]
					if a.kind == 0 or a.kind == 1 or a.kind == 6 or a.kind == 7:
						if info.has(e.b) and not (a.kind == 0 and Data.HEROES[a.sub].ranged):
							_flash(info[e.b].vis_pos + Vector3(0, 1, 0), Color(1, 0.9, 0.7), 0.5)
			"cast":
				_cast_fx(e)
			"boom":
				_nova_fx(Vector3(e.x, 0.15, e.z), e.r, Data.TEAM_COLORS[e.team].lightened(0.2))
			"pop":
				_flash(Vector3(e.x, 1.3, e.z), Color(1, 1, 1), 0.8)
			"die":
				_burst(Vector3(e.x, 0.8, e.z), Data.TEAM_COLORS[e.team], 10)
			"kill":
				if info.has(e.b):
					_burst(info[e.b].vis_pos + Vector3(0, 1, 0), Color(1, 0.3, 0.2), 24)
			"tower":
				_burst(Vector3(e.x, 3, e.z), Data.TEAM_COLORS[e.team], 40)
				_nova_fx(Vector3(e.x, 0.2, e.z), 8.0, Data.TEAM_COLORS[e.team])
			"lvl":
				if info.has(e.a):
					_column(info[e.a].vis_pos, Color(1.0, 0.85, 0.3), 0.6)
			"blink":
				_flash(Vector3(e.x, 1.2, e.z), Color(0.7, 0.4, 1.0), 2.0)
			"respawn", "recalled":
				if info.has(e.a):
					_column(info[e.a].pos, Data.TEAM_COLORS[info[e.a].team], 0.5)


func _cast_fx(e: Dictionary) -> void:
	if not info.has(e.a):
		return
	var u: Dictionary = info[e.a]
	if u.kind != 0:
		return
	var a: Dictionary = Data.HEROES[u.sub].abilities[e.ab]
	var hc: Color = Data.HEROES[u.sub].color.lightened(0.25)
	var pos: Vector3 = u.vis_pos
	match a.type:
		"nova":
			_nova_fx(pos + Vector3(0, 0.15, 0), a.radius, hc)
		"blast":
			_telegraph(Vector3(e.x, 0.12, e.z), a.radius, hc, a.delay)
		"heal":
			_nova_fx(pos + Vector3(0, 0.15, 0), a.radius, Color(0.4, 1.0, 0.5))
			_column(pos, Color(0.4, 1.0, 0.5), 0.6)
			if a.has("then"):
				_nova_fx(pos + Vector3(0, 0.2, 0), a.then.radius, hc)
		"buff":
			_column(pos, hc, 0.4)
			if a.get("allies", 0.0) > 0:
				_nova_fx(pos + Vector3(0, 0.15, 0), a.allies, Color(0.6, 0.85, 1.0))
		"dash":
			_flash(pos + Vector3(0, 1, 0), hc, 1.2)
	if info.has(e.a):
		info[e.a]["lunge"] = 1.0


func _tween_free(n: Node3D, dur: float) -> Tween:
	var tw := create_tween()
	tw.tween_interval(dur)
	tw.tween_callback(n.queue_free)
	return tw


func _flash(p: Vector3, c: Color, size: float) -> void:
	var s := _sphere(0.3 * size, mat(c, 4.0, 0.9), p, self, 8)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(s, "scale", Vector3.ONE * 2.2, 0.18)
	tw.chain().tween_callback(s.queue_free)


func _nova_fx(p: Vector3, r: float, c: Color) -> void:
	var disc := _cyl(r, r, 0.06, mat(c, 2.5, 0.5), p, self, 32)
	disc.scale = Vector3(0.2, 1, 0.2)
	var ring := _ring(r, Color(c.r, c.g, c.b, 1.0), 0.3)
	ring.position = p + Vector3(0, 0.1, 0)
	add_child(ring)
	ring.scale = Vector3(0.2, 0.15, 0.2)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(disc, "scale", Vector3(1, 1, 1), 0.22)
	tw.tween_property(ring, "scale", Vector3(1.05, 0.15, 1.05), 0.22)
	tw.tween_property(disc, "position:y", p.y + 0.01, 0.4)
	tw.chain().tween_callback(func(): disc.queue_free(); ring.queue_free())


func _telegraph(p: Vector3, r: float, c: Color, delay: float) -> void:
	var ring := _ring(r, Color(c.r, c.g, c.b, 1.0), 0.2)
	ring.position = p
	add_child(ring)
	var fill := _cyl(r, r, 0.04, mat(c, 1.5, 0.35), p, self, 32)
	fill.scale = Vector3(0.05, 1, 0.05)
	var tw := create_tween()
	tw.tween_property(fill, "scale", Vector3(1, 1, 1), delay)
	tw.tween_callback(func(): ring.queue_free(); fill.queue_free())


func _column(p: Vector3, c: Color, dur: float) -> void:
	var col := _cyl(1.0, 1.2, 5.0, mat(c, 2.5, 0.35), p + Vector3(0, 2.5, 0), self, 16)
	var tw := create_tween()
	tw.tween_property(col, "scale", Vector3(0.1, 1.3, 0.1), dur)
	tw.tween_callback(col.queue_free)


func _burst(p: Vector3, c: Color, amount: int) -> void:
	var parts := CPUParticles3D.new()
	parts.one_shot = true
	parts.amount = amount
	parts.lifetime = 0.7
	parts.explosiveness = 1.0
	parts.direction = Vector3.UP
	parts.spread = 80.0
	parts.initial_velocity_min = 4.0
	parts.initial_velocity_max = 9.0
	parts.gravity = Vector3(0, -14, 0)
	parts.scale_amount_min = 0.15
	parts.scale_amount_max = 0.35
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE
	bm.material = mat(c, 3.0)
	parts.mesh = bm
	parts.position = p
	add_child(parts)
	parts.emitting = true
	_tween_free(parts, 1.2)


# ---------------------------------------------------------------- mira

func show_aim(hero_id: int, ab: Dictionary, dir: Vector2) -> void:
	hide_aim()
	if not info.has(hero_id):
		return
	var pos: Vector3 = info[hero_id].vis_pos
	var c := Color(0.5, 0.85, 1.0, 1.0)
	var rng: float = ab.get("range", 0.0)
	var d := dir.normalized() if dir.length() > 0.01 else Vector2(0, -1)
	var ang := atan2(d.x, d.y)
	match ab.type:
		"skillshot", "dash", "blink":
			var len: float = rng if ab.type == "skillshot" else ab.dist
			var w: float = ab.get("width", 1.0)
			var bar := _box(Vector3(w, 0.03, len), mat(c, 1.5, 0.35), Vector3(0, 0, len / 2), null)
			var holder := Node3D.new()
			holder.position = pos + Vector3(0, 0.12, 0)
			holder.rotation.y = ang
			holder.add_child(bar)
			aim_node.add_child(holder)
		"blast":
			var frac := clampf(dir.length(), 0.0, 1.0)
			var p := pos + Vector3(d.x, 0, d.y) * rng * frac
			var ring := _ring(ab.radius, c, 0.2)
			ring.position = p + Vector3(0, 0.12, 0)
			aim_node.add_child(ring)
			var area := _ring(rng, Color(1, 1, 1, 0.35), 0.1)
			area.position = pos + Vector3(0, 0.1, 0)
			aim_node.add_child(area)
		"nova":
			var ring2 := _ring(ab.radius, c, 0.2)
			ring2.position = pos + Vector3(0, 0.12, 0)
			aim_node.add_child(ring2)
		"heal", "buff":
			var r: float = ab.get("radius", ab.get("allies", 2.0))
			var ring3 := _ring(maxf(r, 2.0), Color(0.5, 1.0, 0.6, 1.0), 0.2)
			ring3.position = pos + Vector3(0, 0.12, 0)
			aim_node.add_child(ring3)


func hide_aim() -> void:
	for c in aim_node.get_children():
		c.queue_free()


func show_range(r: float) -> void:
	range_ring.visible = r > 0
	if r > 0:
		range_ring.scale = Vector3(r, 0.15, r)
