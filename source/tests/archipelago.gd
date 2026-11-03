extends SceneTree
var passed=0
var failed=0
var game
var output=""
func _initialize():
	if DisplayServer.get_name()!="headless":DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--visual-out="):output=arg.trim_prefix("--visual-out=")
	call_deferred("run")
func check(ok:bool,label:String):
	if ok:passed+=1;print("PASS ",label)
	else:failed+=1;push_error("FAIL "+label)
func total(values:Dictionary)->int:
	var count=0
	for value in values.values():count+=int(value)
	return count
func test_data():
	var learning=IslandLearning.new()
	var old=learning.data.duplicate(true)
	old.build=[8,7,3];old.development=[15,0,0];old.actions=88;old.work_turns=[21,12,4];old.harvested=[25,18]
	old.words={"gather":{"seen":3,"correct":2,"strength":2,"last":1200,"due":1800,"helped":1}}
	old.bookmarks={"gather":true};old.practice={"read":8,"listen":6,"sentence":4}
	old.frontier={"active":"plateau","progress":{"grove":6,"quarry":6,"sawmill":8,"meadow":3,"kiln":8,"crystal":3,"hill":6,"wetland":2,"plateau":4,"mountain":1},"turns":{"plateau":19,"grove":14},"effort":{"plateau":.375,"cottage":.65}}
	old.study_plan={"book":old.book_id,"capacity":222,"quota":30,"planned_words":2500,"planned_steps":200}
	var reopened=IslandLearning.new()
	check(reopened.accept_save(JSON.parse_string(JSON.stringify(old))),"v0.10 save is accepted without resetting")
	var frontier=IslandFrontier.new(reopened)
	var preserved=true
	for id in old.frontier.progress:preserved=preserved and int(frontier.data.progress[id])==int(old.frontier.progress[id])
	check(preserved and reopened.data.build==old.build and reopened.data.development==old.development,"legacy buildings and all ten previous chapter progress values survive")
	check(is_equal_approx(frontier.data.effort.plateau,.375) and is_equal_approx(frontier.data.effort.cottage,.65) and frontier.data.active=="plateau","legacy partial effort and selected worksite survive")
	check(reopened.data.words.gather.correct==2 and reopened.data.bookmarks.has("gather") and reopened.data.practice.sentence==4,"legacy word, bookmark and practice history survive")
	var empty=true
	for id in ["shipyard","sunreach","coral","basalt","tideworks"]:empty=empty and frontier.data.progress[id]==0
	check(empty and frontier.data.production.is_empty() and frontier.data.deliveries.is_empty(),"new chapters and production counters start empty in an old save")
	var preserved_partial=frontier.data.effort.duplicate(true)
	for book in reopened.wordbooks.books:
		reopened.select_book(book.id)
		var old_quota=clampi(ceili(float(reopened.book_remaining())*2.0/maxi(1,222-frontier.finished_units())),1,48)
		reopened.data.study_plan={"book":book.id,"capacity":222,"quota":old_quota}
		frontier.refresh_plan()
		check(reopened.data.study_plan.capacity==294 and int(reopened.data.study_plan.quota)<=old_quota and frontier.data.effort==preserved_partial,"expanded capacity recalculates "+str(book.id)+" without resetting partial effort")
	frontier.finish_for_development(true)
	check(frontier.cells().size()==57 and frontier.finished_units()==294,"complete map has 57 unique land tiles and 294 construction steps")
	check(frontier.data.production.is_empty() and frontier.data.deliveries.is_empty() and reopened.data.words.gather.correct==2,"one-click completion adds no production or learning records")
	var terrain=IslandTerrain.new();var counts=[0,0,0,0,0];var roundtrip=0.0
	for cell in frontier.cells():
		var p=IslandFrontier.point(cell);counts[terrain.chart_at(p)]+=1
		for offset in [Vector2.ZERO,Vector2(.48,.31),Vector2(-.61,.33),Vector2(.12,-.71)]:
			var q=p+offset;roundtrip=maxf(roundtrip,terrain.coordinates(terrain.point(q)).distance_to(q))
	check(counts==[39,6,6,3,3],"gold ore has its own island; the final berth is on an independent fifth chart")
	check(terrain.point(IslandFrontier.point(Vector2i.ZERO)).normalized().dot(terrain.point(IslandFrontier.point(Vector2i(-20,0))).normalized())<-.5,"new land reaches the opposite hemisphere instead of the original pole")
	check(roundtrip<.003,"all 57 tile centres and nearby points round-trip between chart and globe")
	print("MAX_CHART_ROUNDTRIP ",roundtrip)
func test_geometry(world):
	var missing=0;var max_error=0.0
	for cell in world.land:
		var anchor=world.land[cell];var actual=[]
		for mesh in anchor.get_children():
			if mesh is MeshInstance3D:
				for v in mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:actual.append(anchor.transform*(mesh.transform*v))
		for face in world.ground_faces[cell]:
			for v in face:
				var nearest=INF
				for candidate in actual:nearest=minf(nearest,v.distance_to(candidate))
				if nearest>.002:missing+=1
				max_error=maxf(max_error,nearest)
	check(missing==0 and world.ground_faces.size()==57,"every tile collision triangle matches the actual transformed rendered geometry")
	print("MAX_GEOMETRY_VERTEX_ERROR ",max_error)
func test_sources(world):
	var mismatches=[];var empty=[]
	var ids=IslandFrontier.BUILD_IDS.duplicate()
	for c in IslandFrontier.CHAPTERS:ids.append(c.id)
	for id in ids:
		game.frontier.choose(id)
		for completed in [true,false]:
			if not completed:
				if id in IslandFrontier.BUILD_IDS:game.learning.data.build[game.frontier.site(id)]=0;game.learning.data.development[game.frontier.site(id)]=0
				else:game.frontier.data.progress[id]=0
			for turn in range(6):
				game.frontier.data.turns[id]=turn;world.prepare_resource(false)
				var route=world.production_route;var entry=world.selected_entry
				if entry.is_empty():empty.append(id);continue
				if str(entry.region)!=str(route.source) or str(entry.material)!=str(route.raw):mismatches.append({"site":id,"completed":completed,"turn":turn,"route":route.duplicate(),"actual_region":entry.region,"actual_material":entry.material})
		if id in IslandFrontier.BUILD_IDS:game.learning.data.build[game.frontier.site(id)]=IslandLearning.NEEDS[game.frontier.site(id)];game.learning.data.development[game.frontier.site(id)]=IslandLearning.EXTRA
		else:game.frontier.data.progress[id]=game.frontier.chapter(id).need
	check(empty.is_empty(),"every worksite resolves a real resource both during and after construction")
	check(mismatches.is_empty(),"actual source region and raw material match every construction and production route")
	if not mismatches.is_empty():print("SOURCE_MISMATCHES ",JSON.stringify(mismatches))
	var facilities=true
	for id in ["quarry","sawmill","kiln","meadow","hill","wetland","plateau","crystal","mountain","shipyard","sunreach","coral","basalt","tideworks","goldmine","smelter","rocket"]:
		facilities=facilities and world.facilities.has(id) and world.facilities[id].visible and world.facilities[id].get_child_count()>0
	check(facilities,"completed regions display facilities including the mine and mint")
func test_sea_routes(world):
	var routes_ok=true;var sea_clear=true
	for pair in [["shipyard","sunreach"],["shipyard","basalt"],["sunreach","tideworks"],["basalt","coral"],["goldmine","smelter"],["smelter","rocket"]]:
		var route=world.sea_routes.route(game.frontier.target(pair[0]),game.frontier.target(pair[1]))
		print("SEA_ROUTE ",pair," points ",route.size());routes_ok=routes_ok and route.size()>=2
		if route.is_empty():
			var target_chart=world.terrain.chart_at(game.frontier.target(pair[1]));var deepest=0.0
			for cell in world.land:
				var center=IslandFrontier.point(cell)
				if world.terrain.chart_at(center)!=target_chart:continue
				for i in range(12):deepest=maxf(deepest,world.water.depth_at(world.surface(center+Vector2.from_angle(i*TAU/12)*IslandFrontier.HEX*1.65).normalized()))
			print("EMPTY_ROUTE_COAST ",target_chart," old_search_max_depth ",deepest," origin ",world.sea_routes.coast(world.terrain.chart_at(game.frontier.target(pair[0])),world.surface(game.frontier.target(pair[1])).normalized())," destination ",world.sea_routes.coast(target_chart,world.surface(game.frontier.target(pair[0])).normalized()))
		for index in range(route.size()-1):
			for step in range(129):
				var n=route[index].slerp(route[index+1],float(step)/128).normalized()
				sea_clear=sea_clear and world.water.depth_at(n)>.30
	check(routes_ok,"all six cross-island routes reach a valid coast")
	check(sea_clear,"all sampled ferry route segments stay over water rather than cutting across land")
func test_ferry(world):
	var start=game.frontier.target("shipyard")+Vector2(.8,.7);var end=game.frontier.target("basalt")+Vector2(.8,.7)
	var origin=world.safe_point(start,world.WALK_CLEARANCE,start);var destination=world.safe_point(end,world.WALK_CLEARANCE,end)
	world.place(world.builder,origin);world.worker.work_left=0;world.walk_to(destination)
	check(world.transporting,"cross-chart walking begins an actual ferry journey")
	var elapsed=0.0;var over_water=true
	while world.transporting and elapsed<14:
		await create_timer(.1).timeout;elapsed+=.1
		if world.ferry.visible:
			var normal=world.ferry.position.normalized()
			over_water=over_water and world.water.depth_at(normal)>.30 and world.ferry.basis.y.normalized().dot(normal)>.999
	check(not world.transporting and world.terrain.chart_at(world.terrain.coordinates(world.builder.position))==2,"the real ferry animation arrives on the black-sand island")
	check(over_water,"the animated boat stays on water and upright along the spherical route")
func test_production(world):
	game.frontier.choose("coral");game.next_task();game.exploring=false;game.hud.close();world.prepare_resource(false)
	world.worker.work_left=0;var before=game.frontier.data.production.duplicate(true);var deliveries=game.frontier.data.deliveries.duplicate(true)
	for i in range(600):world._process(.05)
	check(game.frontier.data.production==before and game.frontier.data.deliveries==deliveries,"thirty seconds of idle animation creates no production")
	var route=world.production_route.duplicate(true);var practice=game.learning.data.practice.duplicate(true);var words=game.learning.data.words.duplicate(true)
	game.locked=false;game.learning.data.dev_skip=true;game.skip_learning()
	check(total(game.frontier.data.deliveries)-total(deliveries)==1 and total(game.frontier.data.production)>total(before),"one developer exercise records one delivery and its actual processing chain")
	check(game.learning.data.practice==practice and game.learning.data.words==words,"developer exercise records production without pretending to learn")
	await create_timer(3.4).timeout
	game.frontier.data.turns.coral=0;game.locked=false;game.next_task();game.exploring=false;game.hud.close()
	var word=str(game.current.id);var old_correct=int(game.learning.data.words.get(word,{}).get("correct",0));var old_delivery=total(game.frontier.data.deliveries)
	game.answer(int(game.current.correct))
	check(total(game.frontier.data.deliveries)==old_delivery+1 and int(game.learning.data.words[word].correct)==old_correct+1,"a correct real word exercise records both learning and exactly one delivery")
	var produced=game.frontier.data.production.duplicate(true);var delivered=game.frontier.data.deliveries.duplicate(true)
	for i in range(900):world._process(.05)
	check(game.frontier.data.production==produced and game.frontier.data.deliveries==delivered,"reward work and later idle cannot duplicate a recorded production batch")
	await create_timer(3.4).timeout
	var restored=IslandLearning.new();restored.accept_save(JSON.parse_string(JSON.stringify(game.learning.data)))
	var frontier=IslandFrontier.new(restored)
	check(frontier.data.production==game.frontier.data.production and frontier.data.deliveries==game.frontier.data.deliveries,"production and delivery counters survive a normal save round-trip")
func visual(world):
	if output.is_empty() or DisplayServer.get_name()=="headless":return
	DirAccess.make_dir_recursive_absolute(output);game.explore(true,false);game.hud.hide()
	for id in ["shipyard","sunreach","basalt"]:
		game.frontier.choose(id);world.prepare_resource(false);world.recenter();world.globe.quaternion=world.desired_rotation
		game.camera.size=14.0;game.camera.look_at(Vector3(0,9.5,0))
		await process_frame;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join(id+".png"))
func run():
	test_data()
	if "--data-only" in OS.get_cmdline_user_args():
		print("ARCHIPELAGO_RESULT ",passed," passed / ",failed," failed");quit(0 if failed==0 else 1);return
	game=load("res://main.tscn").instantiate();root.add_child(game)
	if DisplayServer.get_name()!="headless":DisplayServer.window_set_position(Vector2i(DisplayServer.screen_get_usable_rect().end.x-100,60))
	await create_timer(.7).timeout
	var world=game.world;world.set_process(false)
	if world.move_tween and world.move_tween.is_valid():world.move_tween.kill()
	game.frontier.finish_for_development(true);world.sync_buildings(false);await process_frame
	test_geometry(world);test_sources(world);test_sea_routes(world)
	if not "--routes-only" in OS.get_cmdline_user_args():await test_ferry(world);await test_production(world)
	await visual(world)
	print("ARCHIPELAGO_RESULT ",passed," passed / ",failed," failed")
	game.closing=true;game.ambience.shutdown();game.speech.stop();game.speech.stream=null
	if world.move_tween and world.move_tween.is_valid():world.move_tween.kill()
	if world.ferry_tween and world.ferry_tween.is_valid():world.ferry_tween.kill()
	game.queue_free();await process_frame;await process_frame
	quit(0 if failed==0 else 1)
