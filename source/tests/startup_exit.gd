extends SceneTree

var game
func _initialize():call_deferred("run")
func run():
	game=load("res://main.tscn").instantiate();root.add_child(game)
	if not "--exit-before-first-draw" in OS.get_cmdline_user_args():
		if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw
		await process_frame
		game.word_search_query="银行";game.show_word_search()
		await process_frame
		print("EARLY_EXIT search=",game.hud.screen," pending=",game.startup.pending.size())
	await game.request_exit()
	if not game.startup.pending.is_empty():push_error("FAIL unfinished resource reads at exit");quit(1)
	else:print("PASS early exit drains resource reads before engine shutdown")
