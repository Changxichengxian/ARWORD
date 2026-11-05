extends SceneTree
var passed=0
var failed=0
func check(value:bool,label:String):
	if value:passed+=1;print("PASS ",label)
	else:failed+=1;push_error("FAIL "+label)
func _initialize():
	if not "--qa" in OS.get_cmdline_user_args():push_error("QA_REQUIRED: spatial_actor");quit(2);return
	call_deferred("run")
func inspect_world(game):
	var world=game.world
	check(world.navigation.get_point_count()>30,"walkable ground has a connected local navigation mesh")
	var target=game.frontier.target("cottage")
	check(not world.clear_ground(target),"the cottage interior is excluded from walking")
	var start=world.safe_point(target+Vector2(-1.6,0));var finish=world.safe_point(target+Vector2(1.6,0))
	var route=world.walking_route(start,finish);var clear=not route.is_empty();var distance=0.0
	for point in route:
		clear=clear and world.clear_segment(start,point);distance+=start.distance_to(point);start=point
	check(clear,"cross-building travel routes around the solid footprint")
	if game.frontier.done("grove"):check(distance>2.8,"the route keeps the detour instead of cutting through the cottage")
	var stances=true
	for id in IslandFrontier.BUILD_IDS:
		world.work_point=game.frontier.target(id)
		for phase in range(4):stances=stances and world.clear_ground(world.work_stance(phase))
	check(stances,"all work stances stand outside visible structures")
	var rest=world.worker.rest_spot()
	check(world.clear_segment(rest,rest+Vector2(0,IslandWorker.REST_LENGTH),IslandWorker.REST_CLEARANCE),"the smaller resting pose has clear ground along its whole body")
	var minimum=INF;var maximum=-INF
	for id in IslandFrontier.BUILD_IDS:
		game.frontier.data.active=id;world.update_selection_ring()
		var ribbon=world.cursor.get_child(0)
		var mesh=ribbon.mesh
		for vertex in mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			var p=world.globe.to_local(ribbon.to_global(vertex))
			var height=p.length()-world.ground_point(world.terrain.coordinates(p)).length()
			minimum=minf(minimum,height);maximum=maxf(maximum,absf(vertex.y))
	check(minimum>.07 and maximum<.001,"the entire dashed ring floats above the slopes in a single tangent plane")
	check(world.cursor.get_child_count()==1 and not world.ring_material.no_depth_test,"one selection ring keeps normal depth occlusion")
func run():
	var game=load("res://main.tscn").instantiate();root.add_child(game)
	await create_timer(.7).timeout
	var world=game.world
	if world.move_tween and world.move_tween.is_valid():world.move_tween.kill()
	world.set_process(false)
	inspect_world(game)
	for chapter in IslandFrontier.CHAPTERS:game.frontier.data.progress[chapter.id]=chapter.need
	for i in range(3):game.learning.data.build[i]=IslandLearning.NEEDS[i];game.learning.data.development[i]=36
	var started=Time.get_ticks_msec();world.sync_buildings(false);print("FULL_WORLD_NAVIGATION_MS ",Time.get_ticks_msec()-started)
	started=Time.get_ticks_msec();world.sync_buildings(false);print("UNCHANGED_WORLD_SYNC_MS ",Time.get_ticks_msec()-started)
	inspect_world(game)
	check(world.obstacles.size()>=15,"finished buildings, additions and facilities all contribute avoidance footprints")
	check(world.worker.skin_bindings.size()==10 and world.worker.head_pivot!=null,"the continuous skin follows nine body pivots and an independent head")
	var skin=world.actor.find_child("ContinuousBody",true,false)
	check(skin!=null and skin is MeshInstance3D and skin.skin!=null,"the visible body is a skinned continuous mesh")
	var cottage=game.frontier.target("cottage");var start=world.safe_point(cottage+Vector2(-1.6,0));var finish=world.safe_point(cottage+Vector2(1.6,0),world.WALK_CLEARANCE,start)
	world.place(world.builder,start);world.worker.work_left=0;world.work_point=cottage;world.walk_to(finish);world.set_process(true)
	var actual_clear=true;var elapsed=0.0
	while world.move_tween and world.move_tween.is_running() and elapsed<15.0:
		await process_frame;elapsed+=world.get_process_delta_time()
		actual_clear=actual_clear and world.clear_ground(world.terrain.coordinates(world.builder.position),world.WALK_CLEARANCE-.015)
	world.set_process(false)
	check(actual_clear and elapsed<15.0,"the real animated journey remains outside buildings on every sampled frame")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--visual-out="):await visual(game,arg.trim_prefix("--visual-out="))
	print("SPATIAL_ACTOR_RESULT ",passed," passed / ",failed," failed")
	game.closing=true;game.ambience.shutdown();game.speech.stop();game.speech.stream=null;game.queue_free();await process_frame;await process_frame
	quit.call_deferred(0 if failed==0 else 1)
func visual(game,directory:String):
	DirAccess.make_dir_recursive_absolute(directory);game.hud.hide()
	var world=game.world;game.frontier.data.active="cottage";world.update_selection_ring()
	var target=game.frontier.target("cottage");world.work_point=target
	world.desired_rotation=Quaternion(world.surface(target).normalized(),Vector3.UP);world.globe.quaternion=world.desired_rotation
	var position=world.work_stance(0);world.place(world.builder,position,atan2(-(target-position).x,-(target-position).y))
	game.camera.size=6.0;game.camera.look_at(world.globe.to_global(world.surface(target))+Vector3(0,.5,0))
	world.worker.work_left=10;world.worker.waking=0;world.worker.phase=2;world.worker.phase_time=0
	world.worker.update(.12);await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(directory.path_join("cottage-ring-work.png"))
	var start=world.safe_point(target+Vector2(-1.6,0));var finish=world.safe_point(target+Vector2(1.6,0));var route=world.walking_route(start,finish)
	for point in route:world.pebble(world.globe,world.surface(point)+world.surface(point).normalized()*.06,Vector3.ONE*.10,"E9C46A")
	await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(directory.path_join("cottage-route.png"))
