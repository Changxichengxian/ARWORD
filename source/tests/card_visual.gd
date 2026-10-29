extends SceneTree

var output=""
func _initialize():call_deferred("run")
func snap(label:String):
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(label+".png"))
func run():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--visual-out="):output=arg.trim_prefix("--visual-out=")
	assert(not output.is_empty() and "--qa" in OS.get_cmdline_user_args())
	DirAccess.make_dir_recursive_absolute(output)
	var game=load("res://main.tscn").instantiate();root.add_child(game)
	await create_timer(1).timeout
	game.select_site(game.frontier.data.active)
	await create_timer(.5).timeout;await snap("card-open")
	game.explore()
	await create_timer(.12).timeout;await snap("card-leaving")
	await create_timer(.5).timeout;await snap("card-closed")
	game.select_site(game.frontier.data.active)
	await create_timer(.12).timeout;await snap("card-entering")
	await create_timer(.5).timeout;await snap("card-restored")
	print("CARD_VISUAL_COMPLETE")
	game.request_exit()
