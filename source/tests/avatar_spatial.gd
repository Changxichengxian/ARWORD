extends "res://tests/local_avatar.gd"
func run():
	if not "--qa" in OS.get_cmdline_user_args():push_error("QA_REQUIRED: avatar spatial checks require --qa");quit(2);return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--avatar-file="):avatar_file=arg.trim_prefix("--avatar-file=")
	if avatar_file.is_empty():print("SKIP: supply a local --avatar-file");quit();return
	var game=load("res://main.tscn").instantiate();root.add_child(game);await create_timer(.4).timeout
	var world=game.world;world.set_process(false)
	if world.move_tween and world.move_tween.is_valid():world.move_tween.kill()
	for chapter in IslandFrontier.CHAPTERS:game.frontier.data.progress[chapter.id]=chapter.need
	for i in range(3):game.learning.data.build[i]=IslandLearning.NEEDS[i];game.learning.data.development[i]=36
	world.sync_buildings(false)
	var result=world.load_local_avatar(avatar_file);check(result.ok,"local character loads in the completed world")
	if not result.ok:game.queue_free();await process_frame;quit(1);return
	if world.move_tween and world.move_tween.is_valid():world.move_tween.kill()
	check(world.navigation.get_point_count()>30,"wide head and tail leave usable navigation space")
	var cottage=game.frontier.target("cottage");var start=world.safe_point(cottage+Vector2(-2.2,0));var finish=world.safe_point(cottage+Vector2(2.2,0),world.WALK_CLEARANCE,start)
	var route=world.walking_route(start,finish);var path_clear=not route.is_empty();var previous=start
	for point in route:path_clear=path_clear and world.clear_segment(previous,point);previous=point
	check(path_clear,"the complete route respects the measured avatar width")
	world.place(world.builder,start);world.worker.work_left=20;world.worker.phase=0;world.worker.waking=0;world.work_point=cottage;world.walk_to(finish);world.set_process(true)
	Engine.time_scale=4.0
	var elapsed=0.0;var blocked=0;var maximum_radius=0.0;var frames=0
	while world.move_tween and world.move_tween.is_running() and elapsed<60:
		await process_frame;elapsed+=world.get_process_delta_time();frames+=1
		for probe in world.avatar.support_probes:
			var p=world.avatar.probe_point(probe);var local=world.builder.to_local(p);maximum_radius=maxf(maximum_radius,Vector2(local.x,local.z).length())
			var chart=world.terrain.coordinates(world.globe.to_local(p))
			for obstacle in world.obstacles:
				if obstacle.bounds.has_point(chart) and Geometry2D.is_point_in_polygon(chart,obstacle.polygon):blocked+=1
	Engine.time_scale=1.0;world.set_process(false)
	print("AVATAR_ROUTE frames=",frames," seconds=",elapsed," blocked_probes=",blocked," max_radius=",maximum_radius," clearance=",world.avatar.clearance)
	check(elapsed<60 and frames>2 and blocked==0,"the animated head, hair, hands and tail stay out of buildings along the whole journey")
	check(maximum_radius<world.avatar.clearance,"moving body extrema stay inside the navigation clearance")
	check(world.worker.work_left==20,"the longer short-legged journey does not spend earned work seconds")
	print("AVATAR_SPATIAL_RESULT ",passed," passed / ",failed," failed")
	game.closing=true;game.ambience.shutdown();game.speech.stop();game.speech.stream=null;game.queue_free();await process_frame;await process_frame;quit(0 if failed==0 else 1)
