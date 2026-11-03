extends "res://tests/worker_motion.gd"
func run():
	var game=load("res://main.tscn").instantiate();root.add_child(game);await create_timer(.5).timeout
	var world=game.world;world.set_process(false)
	if world.move_tween and world.move_tween.is_valid():world.move_tween.kill()
	for chapter in IslandFrontier.CHAPTERS:game.frontier.data.progress[chapter.id]=chapter.need
	world.sync_buildings(false)
	var support_cells=[Vector2i.ZERO,Vector2i(4,-2),Vector2i(2,-3),Vector2i(1,-2)]
	for id in ["sunreach","basalt","tideworks"]:support_cells.append(game.frontier.chapter(id).point)
	for cell in support_cells:
		var wanted=IslandFrontier.point(cell);var p=world.safe_point(wanted,world.WALK_CLEARANCE,wanted);world.place(world.builder,p)
		if world.terrain.chart_at(wanted)!=0:
			# New shore points must use the same full-body rest placement as the game.
			p=world.worker.rest_spot();world.place(world.builder,p)
			check(world.clear_segment(p,p+Vector2(0,IslandWorker.REST_LENGTH),IslandWorker.REST_CLEARANCE),"the complete resting body fits on the new island at "+str(cell))
		for pose in [0,1,3]:
			world.worker.work_left=0;world.worker.waking=0;world.worker.rest_variant=pose;world.worker.rest_time=0
			var count=world.worker.rest_ground_samples
			for frame in range(120):world.worker.update(.016)
			var bottom=skin_bottom(world,true)
			print("GROUND_SUPPORT ",cell," POSE ",pose," GAP ",bottom," OFFSET ",world.worker.rest_ground_offset," PROBES ",world.worker.rest_support.size()," SAMPLES ",world.worker.rest_ground_samples-count)
			check(bottom>=0 and bottom<.05,"the actual resting skin stays close to real terrain at "+str(cell)+" pose "+str(pose))
			check(world.worker.rest_ground_samples-count==1,"support is sampled once for this settled pose")
	print("SUPPORT_RESULT ",passed," passed / ",failed," failed")
	game.closing=true;game.ambience.shutdown();game.speech.stop();game.speech.stream=null;game.queue_free();await process_frame;await process_frame;quit(0 if failed==0 else 1)
