extends SceneTree
func _initialize():
	if not "--qa" in OS.get_cmdline_user_args():quit(2);return
	call_deferred("run")
func run():
	var output=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--visual-out="):output=arg.trim_prefix("--visual-out=")
	if output.is_empty():quit(2);return
	DirAccess.make_dir_recursive_absolute(output)
	root.content_scale_size=Vector2i(1500,800);root.size=Vector2i(1500,800)
	var stage=Node3D.new();root.add_child(stage)
	var environment=WorldEnvironment.new();stage.add_child(environment)
	var env=Environment.new();env.background_mode=Environment.BG_COLOR;env.background_color=Color("CAD7CB");env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("ECF2ED");env.ambient_light_energy=.7;environment.environment=env
	var sun=DirectionalLight3D.new();stage.add_child(sun);sun.rotation_degrees=Vector3(-48,-35,0);sun.light_energy=1.2;sun.shadow_enabled=true
	var camera=Camera3D.new();stage.add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=3.5;camera.position=Vector3(0,2.9,5.5);camera.look_at(Vector3(0,.3,0));camera.current=true
	var controller=load("res://scripts/land_wildlife.gd").new();stage.add_child(controller)
	for i in range(4):
		var model=load("res://assets/models/wild_rabbit.glb").instantiate();stage.add_child(model)
		var joints={}
		for name in ["Body","Head","EarL","EarR","ForeL","ForeR","ForePawL","ForePawR","HindL","HindR","HindPawL","HindPawR","Tail"]:joints[name]=model.find_child(name,true,false)
		var rabbit={"joints":joints,"model":model,"state":["sniff","sit","groom","hop"][i],"elapsed":1.,"duration":3.,"fade":1.}
		controller.pose(rabbit,1.2,.43)
		model.position=Vector3((i-1.5)*1.3,.17 if i==3 else 0.,0.)
		model.rotation.y=PI+.38
		var floor_mesh=MeshInstance3D.new();stage.add_child(floor_mesh);var cylinder=CylinderMesh.new();cylinder.top_radius=.49;cylinder.bottom_radius=.49;cylinder.height=.045;floor_mesh.mesh=cylinder;floor_mesh.position=Vector3(model.position.x,-.03,0.)
		var mat=StandardMaterial3D.new();mat.albedo_color=Color("92A57D");floor_mesh.material_override=mat
	for frame in range(8):await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+"/rabbit-poses.png")
	stage.queue_free();await process_frame
	var game=load("res://main.tscn").instantiate();root.add_child(game)
	await create_timer(.8).timeout
	game.set_process(false);game.hud.hide()
	var world=game.world;world.wildlife.set_process(false)
	if world.move_tween and world.move_tween.is_valid():world.move_tween.kill()
	var land=world.wildlife.land_life
	land.refresh_habitat()
	if land.rabbits.is_empty():push_error("No rabbit in actual starting world");quit(1);return
	var rabbit=land.rabbits[0];rabbit.fade=1.;rabbit.state="sit";land.pose(rabbit,1.2,0.);land.place_rabbit(rabbit,0.)
	var up:Vector3=rabbit.anchor.basis.y
	var view=Camera3D.new();world.globe.add_child(view)
	view.fov=52;view.current=true
	for side in range(4):
		var angle=side*PI/2+.4
		view.position=rabbit.anchor.position+up*.80-rabbit.anchor.basis.z*(cos(angle)*1.15)+rabbit.anchor.basis.x*(sin(angle)*1.15)
		view.look_at(world.globe.to_global(rabbit.anchor.position+up*.26),world.globe.global_basis*up)
		for frame in range(4):await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output+"/rabbit-world-"+str(side)+".png")
	print("RABBIT_VISUAL_READY ",output)
	game.closing=true;game.ambience.shutdown();game.speech.stop();game.speech.stream=null
	game.queue_free();await process_frame;await process_frame;quit()
