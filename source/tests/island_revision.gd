extends SceneTree
var failures=0
var count=0
var output=""
var game
func _initialize():
	if not "--qa" in OS.get_cmdline_user_args():quit(2);return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--captures="):output=arg.trim_prefix("--captures=")
	call_deferred("run")

func check(ok:bool,label:String):
	count+=1
	if not ok:failures+=1
	print("PASS " if ok else "FAIL ",label)

func capture(label:String):
	if output.is_empty():return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(output)
	root.get_texture().get_image().save_png(output.path_join(label+".png"))

func run():
	game=load("res://main.tscn").instantiate();root.add_child(game)
	await create_timer(.4).timeout
	game.cosmos.set_sky_seed(103)
	game.space_settings();game.toggle_central_body()
	check(game.cosmos.sun.visible and not game.learning.data.black_hole,"the sun remains selectable")
	game.toggle_central_body();game.hud.close()
	check(game.learning.data.black_hole and game.cosmos.black_hole.visible and not game.cosmos.sun.visible,"central body switches from settings")
	var reloaded=IslandLearning.new();reloaded.accept_save(JSON.parse_string(JSON.stringify(game.learning.data)))
	check(reloaded.data.black_hole,"central body preference survives save decoding")
	await create_timer(.3).timeout;await capture("black-hole")
	game.open_observatory(true);await create_timer(1.15).timeout
	await capture("black-hole-close")
	check(game.cosmos.primary_close and game.cosmos.observatory_active,"the central body has an unobstructed inspection view")
	game.close_observatory()
	game.frontier.finish_for_development(true);game.world.sync_buildings(false)
	var w=game.world
	var origin=w.safe_point(game.frontier.target("shipyard")+Vector2(.8,.7),w.WALK_CLEARANCE,game.frontier.target("shipyard"))
	var destination=w.safe_point(game.frontier.target("basalt")+Vector2(.8,.7),w.WALK_CLEARANCE,game.frontier.target("basalt"))
	w.place(w.builder,origin);w.walk_to(destination)
	var prior=w.builder.position;var longest=0.;var walking_steps=0;var hidden=false
	var trip=w.ferry_tween;trip.pause()
	for i in 2400:
		if not w.transporting:break
		trip.custom_step(1./60)
		longest=maxf(longest,w.builder.position.distance_to(prior));prior=w.builder.position
		if w.ferry_walking:walking_steps+=1
		if not w.ferry.visible or not w.actor.visible:hidden=true
	print("FERRY_MAX_STEP ",longest)
	check(not w.transporting and walking_steps>10 and longest<.19 and not hidden,"approach, cross the ramp, sail and walk away continuously")
	var parked=w.ferry.position
	w.walk_to(origin)
	check(w.transporting and w.ferry.visible and w.ferry.position.distance_to(parked)<.01,"return trip uses the same boat at the last berth")
	if w.ferry_tween:w.ferry_tween.kill()
	game.learning.data.bookmarks["harbor"]=true;game.learning.data.practice.read=9
	game.frontier.choose("windmill");game.next_task()
	game.confirm_rewind(false);game.show_developer()
	check(game.frontier.done("windmill"),"backing out of rewind keeps the building")
	game.rewind_building(false)
	check(not game.frontier.done("windmill") and game.frontier.done("shipyard"),"redo one site leaves the other sites complete")
	game.show_rocket();game.enter_trench()
	await create_timer(4.).timeout;await capture("trench")
	check(game.trench_camera.current and game.world.globe.to_local(game.trench_camera.global_position).length()<IslandWater.BASE_RADIUS,"observation camera is physically below sea level")
	game.leave_trench();game.hud.close()
	game.open_observatory()
	for i in 3:
		game.cosmos.select_observation_target(i);await create_timer(1.05).timeout;await capture("telescope-"+str(i))
	game.close_observatory()
	var titles={}
	for i in 4:
		titles[game.ambience.track_index]=true;game.ambience.player.finished.emit()
	check(titles.size()==4,"four distinct tracks advance through the finished signal")
	game.rewind_building(true)
	check(game.frontier.cells().size()==IslandFrontier.START.size()+IslandFrontier.ROCKET_CELLS.size() and game.world.land.size()==game.frontier.cells().size() and game.frontier.finished_units()==0,"reset returns both the save and rendered terrain to the landing")
	check(game.learning.data.bookmarks.has("harbor") and game.learning.data.practice.read==9 and game.learning.data.black_hole,"rewinding preserves learning, favorites and appearance")
	check(not game.frontier.rocket_open() and game.frontier.data.voyage.paid==0,"fresh voyage after reset")
	print("ISLAND_REVISION_RESULT ",count," checks / ",failures," failed")
	game.closing=true;game.queue_free();await process_frame;quit(int(failures>0))
