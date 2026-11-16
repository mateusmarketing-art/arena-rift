class_name Models
extends RefCounted
## Carrega os modelos .glb feitos no Blender, aplica a cor do time e
## controla as animações.

const HEROES := [
	"res://assets/models/hero_kaelor.glb",
	"res://assets/models/hero_brontus.glb",
	"res://assets/models/hero_nyxara.glb",
	"res://assets/models/hero_vesper.glb",
	"res://assets/models/hero_aurelia.glb",
]
const MELEE := "res://assets/models/minion_melee.glb"
const RANGED := "res://assets/models/minion_ranged.glb"
const SIEGE := "res://assets/models/minion_siege.glb"
const MONSTER := "res://assets/models/monster.glb"
const BOSS := "res://assets/models/boss.glb"
const TOWER := "res://assets/models/tower.glb"
const NEXUS := "res://assets/models/nexus.glb"
const TREES := ["res://assets/models/tree_0.glb", "res://assets/models/tree_1.glb", "res://assets/models/tree_2.glb"]
const ROCKS := ["res://assets/models/rock_0.glb", "res://assets/models/rock_1.glb"]
const SLASH := "res://assets/models/vfx_slash.glb"

static var _scenes := {}
static var _mats := {}
static var _meshes := {}


static func scene(path: String) -> PackedScene:
	if not _scenes.has(path):
		_scenes[path] = load(path)
	return _scenes[path]


## Instancia um modelo já com a cor do time e materiais ajustados.
static func make(path: String, team: int) -> Node3D:
	var n: Node3D = scene(path).instantiate()
	_prepare(n, team)
	var ap := anim_player(n)
	if ap:
		for loop_name in ["idle", "run"]:
			if ap.has_animation(loop_name):
				ap.get_animation(loop_name).loop_mode = Animation.LOOP_LINEAR
		if ap.has_animation("idle"):
			ap.play("idle")
	return n


static func anim_player(n: Node) -> AnimationPlayer:
	return n.find_child("AnimationPlayer", true, false)


static func _prepare(n: Node, team: int) -> void:
	if n is MeshInstance3D:
		var mi: MeshInstance3D = n
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		for i in range(mi.mesh.get_surface_count()):
			var m := mi.mesh.surface_get_material(i)
			if m is StandardMaterial3D:
				mi.set_surface_override_material(i, _mat_for(m, team))
	for c in n.get_children():
		_prepare(c, team)


static func _mat_for(m: StandardMaterial3D, team: int) -> StandardMaterial3D:
	var key := "%d_%d" % [m.get_instance_id(), team]
	if _mats.has(key):
		return _mats[key]
	var nm: StandardMaterial3D = m.duplicate()
	var tc: Color = Data.TEAM_COLORS[clampi(team, 0, 2)]
	if m.resource_name == "Team":
		nm.albedo_color = tc
	elif m.resource_name == "TeamGlow":
		nm.albedo_color = tc.lightened(0.3)
		nm.emission_enabled = true
		nm.emission = tc
		nm.emission_energy_multiplier = 2.2
	# Brilho de contorno (estilo dos MOBAs de celular)
	nm.rim_enabled = true
	nm.rim = 0.35
	nm.rim_tint = 0.6
	nm.metallic_specular = 0.45
	_mats[key] = nm
	return nm


## Primeira malha de um .glb (para MultiMesh de árvores e pedras).
static func first_mesh(path: String) -> Mesh:
	if _meshes.has(path):
		return _meshes[path]
	var n := scene(path).instantiate()
	var mi: MeshInstance3D = n.find_children("*", "MeshInstance3D", true, false)[0]
	var mesh: Mesh = mi.mesh
	_meshes[path] = mesh
	n.free()
	return mesh
