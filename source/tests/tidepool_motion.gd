extends SceneTree
# Complete articulated meshes are sampled on the actual initial and expanded
# seabed. Shore visits and touches must never award learning or construction.
var game
var failures=0
var checks=0
func _initialize():
	if not "--qa" in OS.get_cmdline_user_args():quit(2);return
	call_deferred("run")
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures+=1
	print("PASS " if ok else "FAIL ",label)
func vertices(model:Node3D)->Array:
	var result=[]
	for part in model.find_children("*","MeshInstance3D",true,false):
		var points={}
		for surface in part.mesh.get_surface_count():
			for v in part.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:points[v]=true
		result.append({"node":part,"points":points.keys()})
	return result
func inspect(life,expanded:bool):
	var pool=life.tidepool
	var meshes=[];var valid=0
	for entry in pool.crabs:
		meshes.append(vertices(entry.model));entry.motion_time=0.;entry.last=Vector3.ZERO
		if entry.route_valid:valid+=1
	check(pool.crabs.size()==3 and valid>=(2 if expanded else 3),"three crabs remain visible with checked descent routes "+str(expanded))
	var seal_mesh=vertices(pool.seal);var states={};var seal_states={}
	var floor_gap=INF;var shell_gap=INF;var seal_low=INF;var seal_out=-INF;var max_jump=0.;var previous={}
	for step in 300:
		pool.animate(step*.1,.1);seal_states[pool.seal_state]=true
		for i in pool.crabs.size():
			var entry=pool.crabs[i];states[str(i)+" "+entry.state]=true
			if previous.has(i):max_jump=maxf(max_jump,entry.model.position.distance_to(previous[i]))
			previous[i]=entry.model.position
			for part in meshes[i]:
				for v in part.points:
					var p:Vector3=pool.to_local(part.node.to_global(v))
					var horizontal=Vector2(p.x,p.z)
					if p.y<-.02 and p.y> -5.5:
						var width=lerpf(.94,1.07,clampf(-p.y/.25,0.,1.)) if p.y>-.25 else lerpf(1.07,.78,clampf((-p.y-.25)/5.25,0.,1.))
						shell_gap=minf(shell_gap,horizontal.length()-pool.rim_radius(horizontal.normalized())*width)
					var gp:Vector3=life.to_local(part.node.to_global(v))
					floor_gap=minf(floor_gap,gp.length()-game.world.water.floor_radius(gp.normalized()))
		for part in seal_mesh:
			for v in part.points:
				var p:Vector3=pool.to_local(part.node.to_global(v));var horizontal=Vector2(p.x,p.z)
				seal_low=minf(seal_low,p.y)
				seal_out=maxf(seal_out,horizontal.length()-pool.rim_radius(horizontal.normalized())*.94)
	var round_trips=0
	for i in pool.crabs.size():
		if states.has(str(i)+" descend") and states.has(str(i)+" forage") and states.has(str(i)+" climb") and states.has(str(i)+" feed"):round_trips+=1
	check(round_trips==valid,"every safe crab route includes a descent, seabed feeding and return")
	check(max_jump<.21,"shore-to-wall-to-seabed transitions remain continuous")
	check(floor_gap>=-.008 and shell_gap>=-.008,"complete crab meshes clear the rock column and physical sea floor")
	check(seal_low>=-.008 and seal_out<=.008,"the seal stays supported inside the shelf throughout its actions")
	check(seal_states.has("scoot") and seal_states.has("stretch") and seal_states.has("sunbathe") and seal_states.has("look"),"seal scoots, stretches, rolls to bask and looks around")
	print("SHORE_CLEARANCE expanded=",expanded," floor=",floor_gap," rock=",shell_gap," seal=",seal_low," largest_step=",max_jump)
func run():
	game=load("res://main.tscn").instantiate();root.add_child(game);await create_timer(.4).timeout
	var life=game.world.wildlife;life.set_process(false);game.world.set_process(false)
	inspect(life,false)
	var pool=life.tidepool;pool.crabs[1].reaction=2.2;pool.notice("seal");pool.animate(30.,.2)
	check(pool.crabs[1].state=="retreat" and pool.attention_blend>.4,"individual crab and seal taps cause smooth distinct reactions")
	game.frontier.finish_for_development(true);game.world.sync_buildings(false);life.refresh_habitats()
	inspect(life,true)
	game.closing=true;game.ambience.shutdown();game.queue_free();await process_frame;await process_frame
	print("TIDEPOOL_MOTION_RESULT ",checks," checks / ",failures," failed");quit(int(failures>0))
