extends SceneTree
var destination=""
func _initialize():call_deferred("run")
func shot(name:String):
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(destination.path_join(name+".png"))
func run():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--visual-out="):destination=arg.trim_prefix("--visual-out=")
	assert(not destination.is_empty() and "--art-preview" in OS.get_cmdline_user_args())
	DirAccess.make_dir_recursive_absolute(destination)
	var game=load("res://main.tscn").instantiate();root.add_child(game)
	await create_timer(3).timeout;await shot("terrain-overview-preview")
	game.resume_collect();game.camera.size=8.5
	game.world.desired_rotation=Quaternion(game.world.builder.position.normalized(),Vector3.UP)
	await create_timer(1).timeout
	game.world.worker.rest_variant=0;game.world.worker.rest_time=0
	await create_timer(1).timeout;await shot("rest-sitting-preview")
	game.world.worker.rest_variant=1;game.world.worker.rest_time=0
	await create_timer(1).timeout;await shot("rest-lying-preview")
	game.world.worker.rest_variant=2;game.world.worker.rest_time=0
	await create_timer(1).timeout;await shot("rest-stretch-preview")
	while game.introducing():game.introduce_word(game.current.id)
	game.answer(game.current.correct)
	await create_timer(3).timeout;await shot("earned-work-preview")
	print("PACING_VISUAL_COMPLETE")
	game.closing=true;game.ambience.shutdown();game.speech.stop();game.speech.stream=null;await create_timer(.10).timeout
	game.queue_free();await process_frame;await process_frame
	quit()
