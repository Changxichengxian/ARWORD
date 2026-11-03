extends SceneTree
var game
var failed=0
var checks=0
var output=""

func _initialize():
	if not "--qa" in OS.get_cmdline_user_args():quit(2);return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--captures="):output=arg.trim_prefix("--captures=")
	call_deferred("run")

func check(ok:bool,label:String):
	checks+=1
	if not ok:failed+=1
	print("PASS " if ok else "FAIL ",label)

func shot(name:String):
	if output.is_empty():return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(output)
	root.get_texture().get_image().save_png(output.path_join(name+".png"))

func inspect_routes(life):
	var orca
	var jellies=0
	for a in life.animals:
		if a.kind=="orca":orca=a
		if a.species=="jelly" and a.route_valid:jellies+=1
	check(jellies==2 and orca.route_valid,"two jellyfish and the orca have usable routes")
	var safe=true;var surfaces=false;var dives=false
	for step in 150:
		game.world.time+=.5;life._process(.5)
		surfaces=surfaces or orca.state=="surface";dives=dives or orca.depth>1.7
		for part in orca.model.find_children("*","MeshInstance3D",true,false):
			var box=part.get_aabb()
			for i in 8:
				var p=life.to_local(part.to_global(box.get_endpoint(i)));var n=p.normalized()
				if p.length()<game.world.water.floor_radius(n)-.02 or not life.outside_land(n,0.):safe=false
	check(safe and surfaces and dives,"orca clears all land and seabed through dives and surface passes")
	check(life.tidepool.visible and life.outside_land(life.tidepool.normal,1.4),"occupied tidal ledge has clear water around it")

func run():
	game=load("res://main.tscn").instantiate();root.add_child(game);await create_timer(.6).timeout
	var hud=game.hud;var w=game.world;var life=w.wildlife
	check(game.learning.data.black_hole and game.cosmos.black_hole.visible,"new players see the black hole")
	var saved=game.learning.data.duplicate(true);saved.black_hole=false
	var restored=IslandLearning.new();restored.accept_save(saved)
	check(not restored.data.black_hole,"an explicit sun preference survives reopening")
	saved.erase("sky_default_version");restored.accept_save(saved)
	check(restored.data.black_hole,"earlier automatic sun default migrates")
	for enabled in [false,true]:
		game.learning.data.black_hole=enabled;game.cosmos.set_black_hole(enabled);await process_frame
		check(absf(hud.clock_label.get_global_rect().get_center().x-hud.safe_rect.get_center().x)<1,"clock centered in both sky modes")
	life.set_process(false);inspect_routes(life)
	var head=life.tidepool.head.rotation;life.tidepool.notice("seal");life._process(.2)
	check(life.tidepool.head.rotation.distance_to(head)>.05,"seal lifts its head")
	game.preview_nature("tidepool");await create_timer(1.9).timeout;await shot("tidepool")
	game.preview_nature("orca");life._process(.1);await create_timer(1.8).timeout;await shot("orca")
	game.frontier.finish_for_development(true);w.sync_buildings(false);life.refresh_habitats()
	inspect_routes(life)
	game.select_site("windmill");await create_timer(.9).timeout;game.frame_view(Vector3(0,10.8,0),5.8,false)
	check(ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality.mobile")==3,"mobile has its own soft directional shadow setting")
	if not output.is_empty():
		game.process_mode=Node.PROCESS_MODE_DISABLED;hud.hide()
		RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_HARD)
		await shot("windmill-hard")
		RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM)
		await shot("windmill-soft")
	game.closing=true;game.queue_free();await process_frame
	print("MARINE_LIFE_RESULT ",checks," checks / ",failed," failed");quit(int(failed>0))
