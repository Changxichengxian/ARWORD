extends SceneTree
var failed=0
func _initialize():
	if not "--qa" in OS.get_cmdline_user_args():quit(2);return
	call_deferred("run")
func check(ok:bool,label:String):
	if ok:print("PASS ",label)
	else:failed+=1;push_error("FAIL "+label)
func run():
	var game=load("res://main.tscn").instantiate();root.add_child(game)
	var world=game.world;var life=world.wildlife;var land=life.land_life
	var continuously_visible=true
	# Exercise natural startup without a manual habitat refresh. The worker
	# initially occupies the grass, then walks clear while navigation stays fixed.
	for step in range(8):
		await create_timer(.5).timeout
		if step>=1:
			continuously_visible=continuously_visible and land.rabbits.size()==1
			for rabbit in land.rabbits:continuously_visible=continuously_visible and rabbit.anchor.is_visible_in_tree() and rabbit.model.scale.x>.1
	if "--qa-with-cast" in OS.get_cmdline_user_args():
		check(is_instance_valid(world.avatar) and world.avatar.is_fish,"rabbit startup is exercised with the real fish character loaded")
	check(continuously_visible,"natural startup keeps one visible rabbit after the worker clears the grass")
	life.set_process(false)
	if world.move_tween and world.move_tween.is_valid():world.move_tween.kill()
	check(land.rabbits.size()==1 and land.rabbits[0].anchor.visible,"initial real island has one visible meadow rabbit")
	var cover=PackedVector2Array([Vector2(-6,-6),Vector2(6,-6),Vector2(6,6),Vector2(-6,6),Vector2(-6,-6)])
	world.obstacles.append({"id":"qa_temporary_cover","bounds":Rect2(-Vector2.ONE*6,Vector2.ONE*12),"polygon":cover})
	land.refresh_habitat()
	var hidden=true
	for rabbit in land.rabbits:hidden=hidden and not rabbit.anchor.visible
	check(hidden,"a temporarily unavailable habitat safely hides its resident")
	world.obstacles.pop_back()
	for step in range(16):land.animate(step*.1,.1)
	check(land.rabbits.size()==1 and land.rabbits[0].anchor.visible,"rabbit returns automatically when temporary obstruction clears")
	var before=JSON.stringify(game.learning.data)
	var states={};var safe=true;var planted=true;var maximum_lift=0.;var moved=0.;var known_route=[]
	for frame in range(1800):
		var old=[]
		for rabbit in land.rabbits:old.append({"p":rabbit.point,"state":rabbit.state})
		land.animate(frame/60.,1./60.)
		for i in range(land.rabbits.size()):
			var rabbit=land.rabbits[i];states[rabbit.state]=true
			if known_route.is_empty() and rabbit.state=="hop" and rabbit.from!=rabbit.to:known_route=[rabbit.from,rabbit.to]
			var current_safe=land.grass_safe(rabbit.point,false) and rabbit.anchor.transform.is_finite()
			if safe and not current_safe:print("RABBIT_UNSAFE frame=",frame," point=",rabbit.point," state=",rabbit.state," from=",rabbit.from," to=",rabbit.to," ground=",world.clear_ground(rabbit.point,land.CLEARANCE,false)," kind=",world.terrain.kind(world.terrain.cell_at(rabbit.point)))
			safe=safe and current_safe
			moved+=old[i].p.distance_to(rabbit.point)
			if old[i].state!="hop" and rabbit.state!="hop" and old[i].p!=rabbit.point:planted=false
			maximum_lift=maxf(maximum_lift,rabbit.anchor.position.distance_to(land.ground(rabbit.point)))
	check(safe,"all rabbit footpoints stay on clear gently sloped grass")
	check(planted and moved>.3 and maximum_lift>.12,"rabbit translates during real lifted hops and remains planted during rest")
	check(states.has("groom") and states.has("sniff") and states.has("sit") and states.has("hop"),"rabbit alternates sniffing, grooming, sitting and hopping")
	if not land.rabbits.is_empty():
		var rabbit=land.rabbits[0]
		if not known_route.is_empty():
			var a:Vector2=known_route[0];var b:Vector2=known_route[1];var middle=a.lerp(b,.5)
			check(land.safe_route(a,b,false),"observed rabbit route clears actual terrain and scenery")
			var polygon=PackedVector2Array([middle+Vector2(-.12,-.12),middle+Vector2(.12,-.12),middle+Vector2(.12,.12),middle+Vector2(-.12,.12),middle+Vector2(-.12,-.12)])
			world.obstacles.append({"id":"qa_rabbit_obstacle","bounds":Rect2(middle-Vector2.ONE*.12,Vector2.ONE*.24),"polygon":polygon})
			check(not land.safe_route(a,b,false),"new blocking building footprint rejects a previously safe hop")
			world.obstacles.pop_back()
			var actor_position:Vector3=world.builder.position;world.builder.position=land.ground(b)
			check(not land.safe_route(a,b),"a character entering the destination blocks the rabbit route")
			world.builder.position=actor_position
			rabbit.from=a;rabbit.to=b;rabbit.point=a;rabbit.state="hop";rabbit.elapsed=.30;rabbit.duration=.66;rabbit.hops_left=1
			rabbit.turn_from=rabbit.heading;rabbit.hop_heading=(land.ground(b)-land.ground(a)).normalized()
			land.notice(rabbit)
			check(rabbit.state=="hop" and rabbit.pending_alert,"tapping an airborne rabbit queues attention without snapping it down")
			for frame in range(24):land.animate(31.+frame/60.,1./60.)
			check(rabbit.state=="alert","queued attention begins after the rabbit lands")
		else:check(false,"rabbit has a measurable clear hop route")
	check(JSON.stringify(game.learning.data)==before,"all rabbit actions leave learning and construction records unchanged")
	for c in IslandFrontier.CHAPTERS:game.frontier.data.progress[c.id]=c.need
	world.sync_buildings(false);land.refresh_habitat()
	check(land.rabbits.size()==2,"expanded real island has a finite maximum of two rabbits")
	for rabbit in land.rabbits:check(land.grass_safe(rabbit.point,false),"expanded rabbit habitat clears finished building footprints")
	print("RABBIT_RESULT ",failed," failed; states=",states," moved=",moved)
	game.closing=true;game.ambience.shutdown();game.speech.stop();game.speech.stream=null
	game.queue_free();await process_frame;await process_frame;await create_timer(.1).timeout
	quit.call_deferred(0 if failed==0 else 1)
