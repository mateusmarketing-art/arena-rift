extends SceneTree
## Pré-visualização de modelos: godot --path . --script tests/preview.gd -- <arquivo.glb> <saida.png> [anim,anim,...]

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var path: String = args[0]
	var out: String = args[1]
	var anims: Array = (args[2] if args.size() > 2 else "idle,run,attack,cast").split(",")
	var root := Node3D.new()
	get_root().add_child(root)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.16, 0.18, 0.24)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.6, 0.62, 0.7)
	e.ambient_light_energy = 0.7
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.glow_enabled = true
	env.environment = e
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -30, 0)
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	root.add_child(sun)
	var floor := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(30, 30)
	floor.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.25, 0.35, 0.22)
	floor.material_override = fm
	root.add_child(floor)
	var scene: PackedScene = load(path)
	var n := anims.size()
	for i in range(n):
		var inst := scene.instantiate()
		root.add_child(inst)
		inst.position = Vector3((i - (n - 1) / 2.0) * 2.6, 0, 0)
		inst.rotation_degrees.y = 25 if i % 2 == 0 else -25
		var ap: AnimationPlayer = inst.find_child("AnimationPlayer", true, false)
		if ap and ap.has_animation(anims[i]):
			ap.play(anims[i])
			ap.seek(0.25 if anims[i] != "death" else 0.9, true)
			ap.pause()
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.fov = 40
	await process_frame
	cam.look_at_from_position(Vector3(0, 2.2, 3.2 + n * 1.5), Vector3(0, 1.25, 0))
	cam.current = true
	for i in range(8):
		await process_frame
	get_root().get_texture().get_image().save_png(out)
	print("preview salvo ", out)
	quit()
