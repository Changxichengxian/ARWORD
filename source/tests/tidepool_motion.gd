extends SceneTree
# Same actual coast, seabed and articulated models as the game; isolated save.
var game
var failures=0
var checks=0
var output=""
var captures={}
func _initialize():
	if not "--qa" in OS.get_cmdline_user_args():quit(2);return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--visual-out="):output=arg.trim_prefix("--visual-out=")
	call_deferred("run")
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures+=1
	print("PASS " if ok else "FAIL ",label)
func vertices(model:Node3D)->Array:
	var result=[]
	for part in model.find_children("*","MeshInstance3D",true,false):
		var points=[]
		for surface in part.mesh.get_surface_count():
			var mesh_points=part.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			for i in range(0,mesh_points.size(),maxi(1,mesh_points.size()/80)):points.append(mesh_points[i])
		result.append({"node":part,"points":points})
	return result
func picture(entry,label):
	if output.is_empty() or DisplayServer.get_name()=="headless" or captures.has(label):return
	captures[label]=true
	var point:Vector3=entry.model.global_position;var up:Vector3=game.world.globe.global_basis*entry.point.normalized()
	var side:Vector3=game.world.globe.global_basis*game.world.wildlife.tangent_axes(entry.point.normalized())[0]
	game.camera.position=point+up*4.+side*2.;game.camera.look_at(point,up);game.camera.size=3.1
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(label+".png"))
func inspect(life,expanded:bool):
	var pool=life.tidepool;pool.random.seed=4701
	var charts={};var developed=true
	for home in pool.homes:
		charts[home.chart]=true
		developed=developed and game.world.land.has(home.cell)
	check(developed,"every shore belongs to developed land")
	check(pool.homes.size()>0 and (not expanded or charts.size()==4),"usable coasts include all developed island regions "+str(expanded))
	var residents=pool.crabs+[pool.seal_mover];var meshes=[]
	for entry in residents:meshes.append(vertices(entry.model))
	var states={};var visits={};var floor_gap=INF;var land_gap=INF;var max_jump=0.;var previous={}
	var before=JSON.stringify(game.learning.data)
	var nearest_seal=INF
	for step in 2400:
		pool.animate(step*.25,.25)
		for crab in pool.crabs:
			nearest_seal=minf(nearest_seal,crab.model.position.distance_to(pool.seal.position))
		for index in residents.size():
			var entry=residents[index];states[str(index)+" "+entry.phase]=true
			if entry.phase=="rest":visits[str(index)+"/"+str(entry.home.chart)]=true
			if previous.has(index):max_jump=maxf(max_jump,entry.point.distance_to(previous[index]))
			previous[index]=entry.point
			if index==3 and not expanded and entry.phase in ["rest","travel"]:await picture(entry,entry.phase)
			if step%12!=0 or entry.surface=="shore":continue
			for part in meshes[index]:
				for v in part.points:
					var p:Vector3=pool.to_local(part.node.to_global(v));var n=p.normalized()
					if entry.surface=="seabed":floor_gap=minf(floor_gap,p.length()-game.world.water.floor_radius(n))
					elif entry.surface=="land":
						var coordinate=game.world.terrain.coordinates(n)
						if game.world.on_land(coordinate):land_gap=minf(land_gap,p.length()-game.world.ground_point(coordinate).length())
	var complete=true
	for i in range(4):complete=complete and states.has(str(i)+" rest") and states.has(str(i)+" depart") and states.has(str(i)+" forage")
	check(complete,"all three crabs and the seal visit shore and return underwater "+str(expanded))
	check(nearest_seal>1.0,"seal and crabs keep room through shore transitions and replanning "+str(expanded))
	check(max_jump<.15,"coastal movement stays continuous "+str(expanded))
	check(floor_gap>-.055 and land_gap>-.055,"animal meshes stay above the real seabed and dry ground "+str(expanded))
	check(JSON.stringify(game.learning.data)==before,"animal activity never awards or changes learning and construction "+str(expanded))
	if expanded:
		var remote=true
		for i in 4:
			var reached=false
			for chart in [1,2,3]:reached=reached or visits.has(str(i)+"/"+str(chart))
			remote=remote and reached
		check(remote,"every resident can visit a newly developed island")
	print("SHORE_CLEARANCE expanded=",expanded," floor=",floor_gap," land=",land_gap," jump=",max_jump," visits=",visits)
func run():
	game=load("res://main.tscn").instantiate();root.add_child(game);await create_timer(.4).timeout
	var life=game.world.wildlife;life.set_process(false);game.world.set_process(false)
	var pool=life.tidepool
	check(pool.find_child("IntertidalLedge",true,false)==null,"no dedicated crab and seal island is created")
	await inspect(life,false)
	pool.crabs[1].reaction=2.2;pool.notice("seal");pool.animate(30.,.2)
	check(pool.crabs[1].state=="retreat" and pool.attention_blend>.4,"individual taps retain crab and seal reactions")
	game.frontier.finish_for_development(true);game.world.sync_buildings(false);life.refresh_habitats()
	await inspect(life,true)
	game.closing=true;game.ambience.shutdown();game.queue_free();await process_frame;await process_frame
	print("TIDEPOOL_MOTION_RESULT ",checks," checks / ",failures," failed");quit(int(failures>0))
