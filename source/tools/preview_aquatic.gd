extends SceneTree
var output=""
var game
func _initialize():call_deferred("run")
func shot(name:String):
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(name+".png"))
func focus(normal:Vector3,zoom:float):
	game.stop_view_transition();game.camera.size=zoom;game.camera.look_at(Vector3(0,11.3,0))
	game.world.desired_rotation=Quaternion(normal,Vector3.UP);game.world.globe.quaternion=game.world.desired_rotation
func run():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):output=arg.trim_prefix("--out=")
	assert(not output.is_empty() and "--art-preview" in OS.get_cmdline_user_args())
	DirAccess.make_dir_recursive_absolute(output)
	game=load("res://main.tscn").instantiate();root.add_child(game)
	await create_timer(1.1).timeout
	game.hud.hide();game.ambience.player.volume_db=-80
	var life=game.world.wildlife;var fish={};var whale={}
	for animal in life.animals:
		if animal.kind=="fish" and animal.anchor.visible and fish.is_empty():fish=animal
		if animal.kind=="whale" and animal.index==0:whale=animal
	assert(not fish.is_empty() and whale.route_valid)
	focus(fish.anchor.position.normalized(),4.5)
	await create_timer(.25).timeout;await shot("fish-underwater")
	whale.phase=3.0;focus(life.whale_direction(whale,3.4),7.0)
	await create_timer(.4).timeout;await shot("whale-underwater")
	whale.phase=10.5;whale.breath_cycle=-1;focus(life.whale_direction(whale,11.5),7.0)
	await create_timer(1.0).timeout;await shot("whale-breathing")
	whale.phase=27.0;focus(life.whale_direction(whale,27.3),7.0)
	await create_timer(.3).timeout;await shot("whale-breach")
	whale.phase=28.7;focus(life.whale_direction(whale,29.3),7.0)
	await create_timer(.6).timeout;await shot("whale-landing")
	game.ambience.shutdown();game.queue_free();await process_frame;await create_timer(.1).timeout
	print("AQUATIC_VISUAL_READY ",output)
	quit()
