extends SceneTree
## Foto de grupo: godot --path . --script tests/lineup.gd -- saida.png anim arquivo1.glb arquivo2.glb ...

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	var anim: String = args[1]
	var files := args.slice(2)
	var root := Node3D.new()
	get_root().add_child(root)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.12, 0.14, 0.2)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.65, 0.68, 0.78)
	e.ambient_light_energy = 0.75
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.glow_enabled = true
	env.environment = e
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -35, 0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	root.add_child(sun)
	var floor := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 40)
	floor.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.22, 0.32, 0.2)
	floor.material_override = fm
	root.add_child(floor)
	var n := files.size()
	for i in range(n):
		var inst: Node3D = load(files[i]).instantiate()
		root.add_child(inst)
		inst.position = Vector3((i - (n - 1) / 2.0) * 2.2, 0, 0)
		inst.rotation_degrees.y = 15
		var ap: AnimationPlayer = inst.find_child("AnimationPlayer", true, false)
		if ap and ap.has_animation(anim):
			ap.play(anim)
			ap.seek(0.3, true)
			ap.pause()
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.fov = 38
	await process_frame
	cam.look_at_from_position(Vector3(0, 2.4, 4.0 + n * 1.55), Vector3(0, 1.25, 0))
	cam.current = true
	for i in range(8):
		await process_frame
	get_root().get_texture().get_image().save_png(out)
	print("foto salva ", out)
	quit()
