extends "res://tests/worker_motion.gd"
var avatar_file=""
var output=""
func run():
	if not "--qa" in OS.get_cmdline_user_args():push_error("QA_REQUIRED: local avatar checks require --qa");quit(2);return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--avatar-file="):avatar_file=arg.trim_prefix("--avatar-file=")
		if arg.begins_with("--avatar-out="):output=arg.trim_prefix("--avatar-out=")
	if avatar_file.is_empty():print("SKIP: supply a local --avatar-file; no third-party model is bundled");quit();return
	var game=load("res://main.tscn").instantiate();root.add_child(game);await create_timer(.6).timeout
	var world=game.world;world.set_process(false);game.hud.hide()
	# Remove only foreground props in this isolated motion inspection; actual ground remains.
	for pool in world.resources:
		for resource in pool:resource.visual.hide()
	world.scenery.hide()
	for cloud in world.clouds:cloud.hide()
	if world.move_tween and world.move_tween.is_valid():world.move_tween.kill()
	var result=world.load_local_avatar(avatar_file);print("AVATAR_LOAD ",result)
	check(result.get("ok",false),"the selected local VRM loads as a real game actor")
	if not result.get("ok",false):game.queue_free();await process_frame;quit(1);return
	if world.move_tween and world.move_tween.is_valid():world.move_tween.kill()
	var avatar=world.avatar;var identity=avatar.get_instance_id();var rejected=world.load_local_avatar("res://assets/frontier_missions.json")
	check(not rejected.ok and world.avatar.get_instance_id()==identity,"a bad file leaves the existing game actor intact")
	check(not world.actor.find_child("ContinuousBody",true,false).visible,"the white fallback is hidden while its motion drivers remain")
	check(avatar.humanoid.size()>=15 and not avatar.foot_probes.is_empty(),"standard humanoid bones and actual skinned foot probes are mapped")
	print("AVATAR_PROBES ",avatar.foot_probes.size()," / ",avatar.support_probes.size()," GAIT ",avatar.gait_ratio," CLEARANCE ",avatar.clearance)
	check(world.worker.gait_ratio()<.65,"the short-legged model gets a shorter stride and slower actual travel")
	var p=world.safe_point(Vector2(.1,.7));world.place(world.builder,p)
	world.globe.quaternion=Quaternion(world.surface(p).normalized(),Vector3.UP)
	game.camera.size=2.5;game.camera.position=world.builder.global_position+Vector3(1.4,1.5,-3.1);game.camera.look_at(world.builder.global_position+Vector3(0,.50,0))
	world.worker.work_left=20;world.worker.waking=0;world.worker.carry.hide();world.set_tool(-1)
	apply_pose(world,{"pose":{},"rotation":Vector3.ZERO,"lift":0.0})
	var standing=avatar_metrics(world);print("STANDING_METRICS ",standing)
	check(standing.gap>=0 and standing.gap<.035 and standing.max-standing.min>1.03 and standing.max-standing.min<1.12,"the full visible skin has the intended height and touches the real terrain")
	check(standing.radius<avatar.clearance,"navigation clearance contains the head, hair and raised tail")
	var lh=world.actor.to_local(avatar.hand_point("left"));var rh=world.actor.to_local(avatar.hand_point("right"))
	print("REST_HANDS ",lh," ",rh)
	check(absf(lh.x-rh.x)<1.2 and lh.y<1.0 and rh.y<1.0,"the source T-pose is retargeted into relaxed lowered arms")
	await shot("standing")
	for action in [["walk",world.worker.locomotion_pose(.08,IslandWorker.WALK_SPEED*avatar.gait_ratio)],["run",world.worker.locomotion_pose(.13,IslandWorker.RUN_SPEED*avatar.gait_ratio)],["axe-raised",world.worker.strike_pose(.48,0)],["axe-impact",world.worker.strike_pose(.64,0)],["pick-impact",world.worker.strike_pose(.64,1)]]:
		world.set_tool(0 if str(action[0]).begins_with("axe") else 1 if str(action[0]).begins_with("pick") else -1)
		apply_pose(world,action[1]);await shot(action[0])
		check(world.tools.Axe.global_position.distance_to(avatar.hand_point("right"))<.001,"tool follows the retargeted hand in "+str(action[0]))
	world.worker.phase=1;world.worker.update(.016);await shot("carrying")
	world.worker.work_left=0;world.worker.waking=0;world.set_tool(-1)
	p=world.worker.rest_spot();world.place(world.builder,p)
	game.camera.position=world.builder.global_position+Vector3(1.4,1.5,-3.1);game.camera.look_at(world.builder.global_position+Vector3(0,.35,0))
	for variant in [0,1]:
		world.worker.rest_variant=variant;world.worker.rest_time=0
		for frame in range(120):world.worker.update(.016)
		var rest=avatar_metrics(world);print("REST_METRICS ",variant," ",rest)
		check(rest.gap>=0 and rest.gap<.05,"the full visible skin remains above actual ground in rest pose "+str(variant))
		await shot("sitting" if variant==0 else "napping")
	world.clear_local_avatar();check(world.avatar==null and world.actor.find_child("ContinuousBody",true,false).visible,"removing the local model restores the white fallback")
	print("LOCAL_AVATAR_RESULT ",passed," passed / ",failed," failed")
	game.closing=true;game.ambience.shutdown();game.speech.stop();game.speech.stream=null;game.queue_free();await process_frame;await process_frame;quit(0 if failed==0 else 1)
func shot(label:String):
	if output.is_empty():return
	DirAccess.make_dir_recursive_absolute(output);await create_timer(.12).timeout;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(label+".png"))
func avatar_metrics(world)->Dictionary:
	var avatar=world.avatar;var min_y=INF;var max_y=-INF;var low=INF;var low_mesh="";var radius=0.0
	for mesh in avatar.meshes:
		if mesh.skin==null:continue
		var binds=[]
		for i in mesh.skin.get_bind_count():
			var bone=avatar.skeleton.find_bone(mesh.skin.get_bind_name(i)) if not mesh.skin.get_bind_name(i).is_empty() else mesh.skin.get_bind_bone(i)
			binds.append(avatar.poses[bone]*mesh.skin.get_bind_pose(i))
		for surface in mesh.mesh.get_surface_count():
			var arrays=mesh.mesh.surface_get_arrays(surface)
			for i in arrays[Mesh.ARRAY_VERTEX].size():
				var point=Vector3.ZERO
				for j in range(4):point+=(binds[arrays[Mesh.ARRAY_BONES][i*4+j]]*arrays[Mesh.ARRAY_VERTEX][i])*arrays[Mesh.ARRAY_WEIGHTS][i*4+j]
				var p=avatar.skeleton.to_global(point);var b=world.builder.to_local(p);min_y=minf(min_y,b.y);max_y=maxf(max_y,b.y);radius=maxf(radius,Vector2(b.x,b.z).length())
				var local=world.globe.to_local(p);var gap=local.length()-world.ground_point(world.terrain.coordinates(local)).length()
				if gap<low:low=gap;low_mesh=mesh.name
	return {"min":min_y,"max":max_y,"gap":low,"lowest_mesh":low_mesh,"radius":radius}
