extends SceneTree
var game
func _initialize():call_deferred("run")
func run():
	game=load("res://main.tscn").instantiate();root.add_child(game)
	var phase="wildlife" if "--during-habitat" in OS.get_cmdline_user_args() else "character" if "--before-character" in OS.get_cmdline_user_args() else "wildlife_resources"
	while game.startup.phase!=phase:await process_frame
	game.rewind_building(true)
	var deadline=Time.get_ticks_msec()+15000
	while Time.get_ticks_msec()<deadline and is_instance_valid(game.startup):await process_frame
	for i in range(20):await process_frame
	if "--qa-with-cast" in OS.get_cmdline_user_args():
		while not is_instance_valid(game.world.avatar) and Time.get_ticks_msec()<deadline:await process_frame
	var count=0
	for child in game.world.globe.get_children():
		if child is IslandWildlife:count+=1
	print("REWIND_WILDLIFE_COUNT ",count)
	if "--qa-with-cast" in OS.get_cmdline_user_args() and not is_instance_valid(game.world.avatar):push_error("Character missing after early rewind")
	if count!=1 or is_instance_valid(game.startup):push_error("Duplicate wildlife or stale startup after rewind during loading")
	await game.request_exit()
