extends SceneTree
var game
var life
var passed=0
var failed=0
var output=""
func _initialize():
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--visual-out="):output=argument.trim_prefix("--visual-out=")
	call_deferred("run")
func check(ok:bool,label:String):
	print("PASS " if ok else "FAIL ",label)
	if ok:passed+=1
	else:failed+=1
func shell_hit(shell:Node3D,start:Vector3,end:Vector3)->bool:
	for mesh in shell.find_children("*","MeshInstance3D",true,false):
		var a=mesh.to_local(shell.get_parent().to_global(start));var b=mesh.to_local(shell.get_parent().to_global(end))
		for s in range(mesh.mesh.get_surface_count()):
			var arrays=mesh.mesh.surface_get_arrays(s);var points=arrays[Mesh.ARRAY_VERTEX];var indices=arrays[Mesh.ARRAY_INDEX]
			for i in range(0,indices.size(),3):
				if Geometry3D.segment_intersects_triangle(a,b,points[indices[i]],points[indices[i+1]],points[indices[i+2]])!=null:return true
	return false
func run():
	game=load("res://main.tscn").instantiate();root.add_child(game)
	await create_timer(.5).timeout
	if game.get("world")==null:push_error("Main scene did not initialize");quit(1);return
	game.explore(true,false);game.hud.hide();game.world.set_process(false);game.world.globe.quaternion=Quaternion.IDENTITY
	life=game.world.wildlife;life.set_process(false);life._process(.01)
	var seen={};var adult={}
	for animal in life.animals:
		if animal.kind=="fish" and animal.anchor.visible:seen[animal.species]=true
		if animal.kind=="whale" and animal.index==0:adult=animal
	print("VISIBLE_SEA_KINDS ",seen.keys())
	check(seen.size()==5,"five distinct aquatic silhouettes have usable routes at the starting island")
	check(not adult.is_empty() and adult.scale>1.5 and adult.route_valid,"the adult whale is substantially larger and has a valid deep-sea route")
	var safe_fish=true;var safe_whale=true;var fish_under=true;var whale_under=true;var visible=0
	for step in range(0,650,5):
		game.world.time=float(step)*.1;life._process(.5)
		for animal in life.animals:
			if not animal.anchor.visible or animal.kind not in ["fish","whale"]:continue
			visible+=1
			for mesh in animal.model.find_children("*","MeshInstance3D",true,false):
				var box=mesh.get_aabb()
				for i in range(8):
					var p=life.to_local(mesh.to_global(box.get_endpoint(i)));var n=p.normalized()
					if p.length()<game.world.water.floor_radius(n)-.04:
						if animal.kind=="fish":safe_fish=false
						else:safe_whale=false
					if animal.kind=="fish" and p.length()>IslandWater.surface_radius(n,game.world.time)+.02:fish_under=false
					if animal.kind=="whale" and animal.state=="swim" and p.length()>IslandWater.surface_radius(n,game.world.time)+.02:whale_under=false
	check(visible>500 and safe_fish,"complete fish meshes remain above the real seabed during their swimming cycles")
	check(safe_whale,"the enlarged whale body and articulated tail avoid the seabed")
	check(fish_under,"fish, rays and turtles stay under the actual moving water surface")
	check(whale_under,"the entire blue whale remains below the surface during normal swimming")
	check(not life.cave.is_empty(),"a deep-water cave is placed outside existing land")
	if not life.cave.is_empty():
		var shell=life.cave.shell
		check(not shell_hit(shell,Vector3(0,.83,-2),Vector3(0,.83,1.2)) and shell_hit(shell,Vector3(0,.83,-2),Vector3(0,.83,3.8)),"the cave has an open entrance, a real recessed chamber and a solid rear wall")
		check(shell_hit(shell,Vector3(1.55,.83,-2),Vector3(1.55,.83,2)),"opaque mouth rocks occlude the sides of the chamber")
		check(not life.cave.has("watcher") and is_instance_valid(game.world.trader_head),"the sea creature lives at the rocket berth; the original underwater passage remains open")
	check(life.scenery.get_child_count()<=30 and life.grass.size()<=18,"underwater scenery remains sparse and bounded")
	if not output.is_empty() and DisplayServer.get_name()!="headless":await visual()
	game.closing=true;game.ambience.shutdown();game.speech.stop();game.speech.stream=null
	game.queue_free();await process_frame;await process_frame
	print("DEEP_SEA_RESULT ",passed," passed / ",failed," failed")
	quit(0 if failed==0 else 1)
func picture(name:String):
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(name+".png"))
func focus(n:Vector3,span:float):
	game.world.globe.quaternion=Quaternion(n,Vector3(0,.78,.63).normalized())
	game.camera.size=span;game.camera.position=Vector3(0,24,21);game.camera.look_at(Vector3(0,8.3,6.4))
func focus_whale_side(animal:Dictionary):
	# A shallow observation angle exposes the waterline and motion. Clouds stay
	# in the actual scene; the camera observes from the whale's opposite side.
	game.world.globe.quaternion=Quaternion(animal.anchor.position.normalized(),Vector3.UP)
	var point:Vector3=animal.anchor.global_position;var up=point.normalized();var side:Vector3=animal.anchor.global_basis.x
	game.camera.size=10.8;game.camera.position=point+up*4.5-side*11.5;game.camera.look_at(point,up)
func visual():
	DirAccess.make_dir_recursive_absolute(output)
	DisplayServer.window_set_position(Vector2i(DisplayServer.screen_get_usable_rect().end.x-100,60))
	var n=life.preview_event("whale");game.world.time+=.6;life._process(.6);focus(n,12)
	await picture("whale-breath")
	n=life.preview_event("whale_breach");life._process(.01);focus(n,12)
	await picture("whale-breach")
	for animal in life.animals:
		if animal.kind=="whale" and animal.index==0:animal.phase=5.0;animal.action_offset=0.0;n=life.whale_direction(animal,5.0)
	life._process(.01);focus(n,12);await picture("whale-underwater")
	# Let the normal patrol and clouds advance until this view is unobstructed.
	for step in range(180):game.world._process(.1);life._process(.1)
	for animal in life.animals:
		if animal.kind!="whale" or animal.index!=0:continue
		# Keep one patrol position and compare the same clear side angle.
		animal.action_offset=18.0-animal.phase;animal.breath_cycle=-1;life._process(.01);life._process(.40);focus_whale_side(animal);await picture("blue-whale-breath-side")
		animal.action_offset=44.0-animal.phase;life._process(.01);focus_whale_side(animal);await picture("blue-whale-breach-side")
		animal.action_offset=5.0-animal.phase;life._process(.01);focus_whale_side(animal);await picture("blue-whale-submerged-side")
	for kind in ["reef","ray","turtle"]:
		for animal in life.animals:
			if animal.kind=="fish" and animal.species==kind and animal.anchor.visible:
				focus(animal.anchor.position.normalized(),7.5);await picture("sea-"+kind);break
	if not life.cave.is_empty():
		life.preview_event("cave");game.world.globe.quaternion=Quaternion.IDENTITY
		var base=life.cave.root;var point=base.global_position;var up=base.global_basis.y;var forward=-base.global_basis.z
		game.camera.size=8.2;game.camera.position=point+up*8+forward*10;game.camera.look_at(point+up*.9,up)
		await picture("underwater-passage")
	game.world.globe.quaternion=Quaternion.IDENTITY;game.camera.size=15;game.camera.position=Vector3(0,24,21);game.camera.look_at(Vector3(0,10,0));await picture("natural-coast")
