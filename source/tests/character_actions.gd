extends SceneTree

const DT=1.0/60.0
var passed=0
var failed=0

func check(ok:bool,label:String):
	if ok:passed+=1;print("PASS ",label)
	else:failed+=1;push_error("FAIL "+label)

func _initialize():
	if not "--qa" in OS.get_cmdline_user_args():quit(2);return
	call_deferred("run")

func stop_motion(world):
	if world.move_tween and world.move_tween.is_valid():world.move_tween.kill()
	if world.ferry_tween and world.ferry_tween.is_valid():world.ferry_tween.kill()
	world.transporting=false;world.ferry_walking=false
	world.worker.transport_suspended=false;world.worker.visit_target=Vector2.INF
	world.worker.pending_work.clear();world.worker.waking=0

func tick(world,dt:float):
	world.time+=dt;world.worker.update(dt)

func nearby_start(world,finish:Vector2)->Vector2:
	var best=Vector2.INF;var nearest=INF
	for id in world.navigation.get_point_ids():
		var point=world.navigation.get_point_position(id);var distance=point.distance_to(finish)
		if distance>=.40 and distance<.90 and distance<nearest and world.clear_segment(point,finish):
			best=point;nearest=distance
	return best

func check_carry(world)->Dictionary:
	var worker=world.worker
	stop_motion(world)
	var target=world.terrain.coordinates(world.builder.position)
	worker.configure_work({"target":target,"origin":target,"kind":0,"harvest":true})
	worker.work_left=12.0;worker.next_phase()
	var finish=world.work_stance(1);var start=nearby_start(world,finish)
	check(start.is_finite() and not world.walking_route(start,finish).is_empty(),"the real navigation graph supplies a short reachable carrying route")
	if not start.is_finite():return {}
	world.place(world.builder,start);world.motion_previous=world.builder.position
	world.travelled=0;world.motion_speed=0;worker.gait_distance=0;worker.gait_phase=0;worker.gait_amount=0
	check(worker.phase==1 and worker.phase_time==0 and not worker.carry_travel_started,"entering the carrying phase starts with a stationary pickup")
	tick(world,.20)
	check(worker.phase==1 and not worker.carry_travel_started and is_equal_approx(worker.phase_time,.20) and is_equal_approx(worker.work_left,11.80) and not world.move_tween.is_running(),"the first pickup portion spends only stationary work time")
	# A long frame must stop at pickup completion, not skip through the route.
	tick(world,.40)
	check(worker.carry_travel_started and worker.phase==1 and is_equal_approx(worker.phase_time,IslandWorker.PICKUP_TIME) and is_equal_approx(worker.work_left,11.65) and world.move_tween.is_running(),"pickup reaches 0.35 seconds before starting the actual carrying route")
	var budget=worker.work_left;var clock=worker.phase_time;var position=world.builder.position
	var kept=true;var gait_moved=false;var frames=0
	while world.move_tween and world.move_tween.is_running() and frames<240:
		await process_frame
		if not world.move_tween.is_running():break
		# Use the real world movement sampler and worker update, while automatic
		# processing stays disabled so there is exactly one update per sample.
		world._process(DT);frames+=1
		kept=kept and worker.work_left==budget and worker.phase_time==clock and worker.phase==1
		gait_moved=gait_moved or absf(worker.gait_phase)>.05
	check(frames>2 and frames<240 and world.builder.position.distance_to(position)>.30,"carrying traverses the short route through the real movement tween")
	check(kept and gait_moved,"walking moves the feet while preserving both carry progress and earned work seconds")
	if world.move_tween and world.move_tween.is_running():stop_motion(world);return {}
	tick(world,.30)
	check(worker.phase==1 and is_equal_approx(worker.phase_time,.65) and is_equal_approx(worker.work_left,11.35),"arrival resumes the remaining set-down time")
	tick(world,.50)
	check(worker.phase==2 and worker.phase_time==0 and is_equal_approx(worker.work_left,11.0),"pickup and set-down together spend exactly one work second before construction")
	return {"start":start,"target":target}

func check_transport(world):
	stop_motion(world)
	var worker=world.worker
	worker.work_left=8.0;worker.phase=1;worker.phase_time=.35;worker.carry_travel_started=true;worker.stroke_time=.22
	worker.suspend_for_transport(true);world.transporting=true
	for walking in [false,true]:
		world.ferry_walking=walking
		tick(world,.75)
		check(worker.work_left==8.0 and worker.phase==1 and worker.phase_time==.35 and worker.stroke_time==.22 and not worker.carry.visible,"boat "+("boarding" if walking else "sailing")+" preserves the working budget and production phase")
	world.transporting=false;world.ferry_walking=false;worker.suspend_for_transport(false)

func check_gait(world):
	stop_motion(world)
	var worker=world.worker
	worker.work_left=0;worker.rest_variant=2;worker.rest_time=0
	world.travelled=3.0;worker.gait_distance=3.0;worker.gait_phase=.71
	var before=worker.gait_phase;var point=world.builder.position
	for speed in [IslandWorker.WALK_SPEED,IslandWorker.RUN_SPEED,IslandWorker.CARRY_SPEED,0.0]:
		world.motion_speed=speed;tick(world,.04)
	check(worker.gait_phase==before and world.builder.position==point,"changing speed without new travel cannot switch the supporting foot")
	world.travelled+=.12;tick(world,.04)
	var advanced=worker.gait_phase
	tick(world,.04);tick(world,.04)
	check(advanced!=before and worker.gait_phase==advanced,"one new travel increment advances gait once, then repeated updates leave its phase alone")

func check_wake(world,route:Dictionary):
	var worker=world.worker
	for variant in [0,1]:
		stop_motion(world);world.place(world.builder,route.start)
		world.motion_previous=world.builder.position;world.motion_speed=0
		worker.work_left=0;worker.rest_variant=variant;worker.rest_time=0
		for i in range(24):tick(world,.05)
		var captured={}
		for name in world.limbs:captured[name]=world.limbs[name].rotation
		var rotation=world.actor.rotation;var lift=world.actor.position.y;var position=world.builder.position
		worker.visit(route.target)
		check(worker.wake_pose==captured and worker.wake_rotation==rotation and worker.wake_lift==lift and worker.wake_grounded,"visiting from "+("sitting" if variant==0 else "lying")+" captures the actual starting body pose")
		check(worker.waking>0 and not world.move_tween.is_running() and world.builder.position==position,"a resting visitor begins getting up before starting travel")
		worker.work_left=12.0
		var kept=true;var stationary=true;var steps=0
		while worker.waking>0 and steps<60:
			var before=worker.waking
			tick(world,.025);steps+=1
			kept=kept and worker.work_left==12.0 and worker.waking<before
			if worker.waking>0:stationary=stationary and not world.move_tween.is_running() and world.builder.position==position
		check(steps>5 and steps<60 and kept and stationary,"the full getting-up transition preserves work seconds and remains at the resting spot")
		check(worker.waking==0 and world.move_tween.is_running(),"travel starts only when the getting-up transition finishes")
	stop_motion(world)

func check_redirected_wake(world,route:Dictionary):
	var worker=world.worker
	for request in ["visit","grant"]:
		stop_motion(world);world.place(world.builder,route.start)
		world.motion_previous=world.builder.position;world.motion_speed=0
		worker.work_left=0;worker.rest_variant=0;worker.rest_time=0
		for i in range(24):tick(world,.05)
		# Earn actual work from a seated pose, then interrupt partway through
		# getting up. The original goal and the replacement must be distinct.
		worker.grant("word",route.target,{},0)
		tick(world,.15)
		var original_goal:Vector2=world.work_stance(0)
		var original_point:Vector2=world.work_point
		var target=Vector2.INF;var goal=Vector2.INF
		for id in world.navigation.get_point_ids():
			var candidate:Vector2=world.navigation.get_point_position(id)
			if candidate.distance_to(route.start)>1.50 or candidate.distance_squared_to(route.target)<.01:continue
			world.work_point=candidate
			var stance:Vector2=world.work_stance(0)
			if stance.distance_to(original_goal)>.25 and stance.distance_to(route.start)>.30 and not world.walking_route(route.start,stance).is_empty():
				target=candidate;goal=stance;break
		world.work_point=original_point
		check(target.is_finite() and worker.waking>0 and worker.work_left==12.0,"mid-wake "+request+" starts with earned work and a distinct reachable replacement goal")
		if not target.is_finite():stop_motion(world);continue
		var remaining=worker.waking;var duration=worker.wake_duration
		var captured=worker.wake_pose.duplicate(true);var position=world.builder.position
		var expected_budget=12.0
		if request=="visit":worker.visit(target)
		else:
			worker.grant("word",target,{},0);expected_budget=24.0
		check(worker.waking==remaining and worker.wake_duration==duration and worker.wake_pose==captured and not world.move_tween.is_running() and world.builder.position==position and worker.work_left==expected_budget,"mid-wake "+request+" keeps the captured rise without restarting it or starting travel")
		var kept=true;var stationary=true;var steps=0
		while worker.waking>0 and steps<60:
			var before=worker.waking
			tick(world,.025);steps+=1
			kept=kept and worker.work_left==expected_budget and worker.waking<before
			if worker.waking>0:stationary=stationary and not world.move_tween.is_running() and world.builder.position==position
		check(steps>0 and steps<60 and kept and stationary and worker.waking==0 and world.move_tween.is_running() and worker.destination==target and world.walk_goal.distance_to(goal)<.001,"mid-wake "+request+" finishes the existing rise before routing to the latest target with its budget intact")
		var frames=0
		while world.move_tween and world.move_tween.is_running() and frames<300:
			await process_frame
			if not world.move_tween.is_running():break
			world._process(DT);frames+=1
			kept=kept and worker.work_left==expected_budget
		check(frames>0 and frames<300 and kept and worker.work_left==expected_budget and world.builder.position.distance_to(world.ground_point(goal))<.01,"mid-wake "+request+" actually reaches the replacement goal without charging travel time")
		stop_motion(world)

func check_expressions(world):
	stop_motion(world)
	var worker=world.worker;var stable=worker.expression
	worker.work_left=0;worker.rest_variant=1;worker.rest_time=2
	for key in ["effort","focus","relax","sleep"]:worker.expression[key]=0.0
	worker.expression.look=Vector2.ZERO
	tick(world,.05);var first=float(worker.expression.sleep)
	for i in range(20):tick(world,.05)
	var asleep=float(worker.expression.sleep)
	check(is_same(stable,worker.expression) and first>0 and first<asleep and asleep<=1,"actual resting updates smoothly increase sleep in the same expression dictionary")
	worker.work_left=12.0;worker.phase=2;worker.phase_time=0;worker.stroke_time=0
	tick(world,.05)
	check(worker.expression.sleep<asleep and worker.expression.focus>0,"returning to actual work smoothly replaces sleep with concentration")
	var sample=worker.expression.duplicate(true);var budget=worker.work_left;var phase_time=worker.phase_time
	worker.update_skin();worker.update_skin();tick(world,0)
	check(worker.expression==sample and worker.work_left==budget and worker.phase_time==phase_time,"reapplying the skeleton or a zero-time update does not integrate expressions or work twice")
	var bounded=true
	for key in ["effort","focus","relax","sleep"]:bounded=bounded and is_finite(worker.expression[key]) and worker.expression[key]>=0 and worker.expression[key]<=1
	check(bounded and worker.expression.look.is_finite() and absf(worker.expression.look.x)<=1 and absf(worker.expression.look.y)<=1,"motion expression outputs stay finite and within their public ranges")

func run():
	var game=load("res://main.tscn").instantiate();root.add_child(game)
	game.closing=true;game.ambience.shutdown();game.speech.stop();game.speech.stream=null
	var world=game.world;world.set_process(false)
	if world.wildlife:world.wildlife.set_process(false)
	game.cosmos.set_process(false)
	await process_frame;await process_frame
	stop_motion(world)
	var learning=JSON.stringify(game.learning.data)
	var route=await check_carry(world)
	check_transport(world);check_gait(world)
	if not route.is_empty():
		check_wake(world,route)
		await check_redirected_wake(world,route)
	check_expressions(world)
	check(JSON.stringify(game.learning.data)==learning,"pickup, carrying, rest, waking and facial motion leave all learning and construction records unchanged")
	print("CHARACTER_ACTIONS_RESULT ",passed," passed / ",failed," failed")
	game.queue_free();await process_frame;await process_frame
	quit.call_deferred(0 if failed==0 else 1)
