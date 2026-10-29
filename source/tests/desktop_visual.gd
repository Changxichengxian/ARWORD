extends SceneTree
func _initialize():call_deferred("run")
func run():
	var out=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--visual-out="):out=arg.trim_prefix("--visual-out=")
	assert(not out.is_empty() and "--art-preview" in OS.get_cmdline_user_args())
	DirAccess.make_dir_recursive_absolute(out)
	var game=load("res://main.tscn").instantiate();root.add_child(game)
	await create_timer(3).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join("expanded-island-preview.png"))
	game.resume_collect()
	await create_timer(2).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join("worksite-preview.png"))
	print("VISUAL_CAPTURE_COMPLETE fps=",Engine.get_frames_per_second()," draws=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)," objects=",Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	quit()
