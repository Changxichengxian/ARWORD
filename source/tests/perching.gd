extends SceneTree

var failures=0
var game
func _initialize():call_deferred("run")
func check(ok:bool,label:String):
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func face(point:Vector3,size:float,offset=Vector3(0,5,7)):
	var world=game.world
	world.globe.quaternion=Quaternion(point.normalized(),Vector3.UP);world.desired_rotation=world.globe.quaternion
	var target=world.globe.to_global(point)
	game.camera.position=target+offset;game.camera.look_at(target);game.camera.size=size
func snap(name:String):
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--captures=") and DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(arg.trim_prefix("--captures=").path_join(name+".png"))
func run():
	if "--qa" not in OS.get_cmdline_user_args():quit(2);return
	game=load("res://main.tscn").instantiate();root.add_child(game)
	await create_timer(.6).timeout
	var world=game.world;var life=world.wildlife
	game.explore(true,false);game.stop_view_transition()
	var history=JSON.stringify(game.learning.data)
	var job=world.worker.work_left
	life.set_process(false)
	var animals=life.animals.filter(func(a):return a.kind in ["bird","butterfly"])
	for a in animals:
		check(a.support!=Vector3.ZERO,"starting island has a landing site for "+a.kind)
		if a.support==Vector3.ZERO:continue
		var largest_step=0.
		var approach_wings=[]
		for i in 480:
			var previous:Vector3=a.last
			life._process(.05)
			if previous!=Vector3.ZERO:largest_step=maxf(largest_step,a.last.distance_to(previous))
			if a.perch_phase=="landing":approach_wings.append(a.left.rotation.z)
			if a.perch_phase=="perched":break
		check(a.perch_phase=="perched" and a.last.distance_to(a.support)<.003,a.kind+" reaches the surface and stays on it")
		var foot=world.ground_point(a.home)
		if a.kind=="bird":
			check(absf(a.last.distance_to(foot)-a.scale*.219)<.004,"webbed feet reach the terrain")
			check(largest_step<=.191 and approach_wings.size()>30 and approach_wings.max()-approach_wings.min()>.55,"continuous approach with braking wingbeats")
		else:
			var center=a.flower.find_child("Center",true,false)
			var bloom=life.to_local(center.to_global(Vector3(0,center.mesh.get_aabb().end.y,0)))
			check(a.last.distance_to(bloom)<.025,"butterfly rests on the imported flower center")
		var wing=a.left.rotation
		for i in 8:life._process(.05)
		if a.kind=="butterfly":check(a.left.rotation.distance_to(wing)>.002 and a.left.rotation.distance_to(wing)<.23,"wings breathe slowly while landed")
		face(a.support,2.45,Vector3(1.5,6,-5) if a.kind=="bird" else Vector3(0,5,7))
		await snap(a.kind+"-perched")
		game.tap_world(game.camera.unproject_position(a.anchor.global_position))
		check(a.perch_phase=="takeoff" and a.startle>0.,"tapping the visible "+a.kind+" starts a startled takeoff")
		var departure_wings=[]
		for i in 16:
			life._process(.05);departure_wings.append(a.left.rotation.z)
		check(a.lift>.25 and a.last.distance_to(a.support)>.12,a.kind+" departs from its landing site")
		if a.kind=="bird":
			check(departure_wings.max()-departure_wings.min()>.6 and a.leg_l.rotation.x<-.1,"gull unfolds, beats its wings and draws up its feet")
			var previous:Vector3=a.last;life._process(.8)
			check(a.last.distance_to(previous)<.35,"a stalled frame cannot skip the rest of the climb")
	if "--qa-with-cast" in OS.get_cmdline_user_args():
		var actor=world.avatar;check(is_instance_valid(actor),"personal test character is installed")
		if actor:
			face(world.builder.position,3.2)
			var head=actor.skeleton.to_global(actor.skeleton.get_bone_global_pose(actor.humanoid.head).origin)
			game.tap_world(game.camera.unproject_position(head))
			world.time+=.20;actor.update_pose()
			check(actor.greeting_weight()>.95,"tapping the character triggers the head and face response")
			await snap("greeting")
	check(JSON.stringify(game.learning.data)==history and world.worker.work_left==job,"taps leave study, inventory and paid work intact")
	game.frontier.finish_for_development(true);world.sync_buildings(false);life.refresh_habitats()
	var supports=[]
	for a in life.animals:
		if a.kind in ["bird","butterfly"] and a.support!=Vector3.ZERO:supports.append(a.support)
	check(supports.size()==10,"four gulls and six butterflies have landing sites after expansion")
	var patterns={}
	for a in life.animals:
		if a.kind=="butterfly":patterns[a.model.scene_file_path]=true
	check(patterns.size()==4,"four distinct butterfly patterns share the working flight rig")
	var first_tracks={}
	for i in game.ambience.tracks.size():
		var music=load("res://scripts/ambience.gd").new();game.add_child(music);music.setup(game)
		first_tracks[music.tracks[music.track_index]]=true;music.shutdown();music.free()
	check(first_tracks.size()>=game.ambience.tracks.size()-1,"opening music rotates through the selected folder")
	print("PERCHING_RESULT ",failures," failed")
	game.closing=true;game.ambience.shutdown();game.queue_free();await process_frame;await process_frame;quit(int(failures>0))
