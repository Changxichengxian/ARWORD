extends SceneTree
var passed=0
var failed=0
func check(value:bool,label:String):
	if value:passed+=1;print("PASS ",label)
	else:failed+=1;push_error("FAIL "+label)
func _initialize():call_deferred("run")
func run():
	var game=load("res://main.tscn").instantiate();root.add_child(game)
	await create_timer(.7).timeout
	var water=game.world.water;var normal=Vector3.UP
	check(not "hint_depth_texture" in water.material.shader.code and not "hint_screen_texture" in water.material.shader.code,"ocean composition does not copy opaque color or depth")
	check(water!=null and water.floor_mesh.mesh!=null,"the ocean contains an actual closed seabed mesh")
	var near=water.depth_at(normal);var far=water.depth_at(Vector3.RIGHT)
	check(near<.3 and far>3.0,"a shallow coastal shelf and a deep basin have different real depths")
	check(abs(water.floor_radius(normal)+near-IslandWater.BASE_RADIUS)<.001,"depth queries use the same radial seabed height")
	var maximum_error=0.0;var minimum_depth=INF;var maximum_depth=0.0
	var arrays=water.floor_mesh.mesh.surface_get_arrays(0)
	for vertex in arrays[Mesh.ARRAY_VERTEX]:
		maximum_error=maxf(maximum_error,abs(vertex.length()-water.floor_radius(vertex.normalized())))
		minimum_depth=minf(minimum_depth,IslandWater.BASE_RADIUS-vertex.length());maximum_depth=maxf(maximum_depth,IslandWater.BASE_RADIUS-vertex.length())
	check(maximum_error<.02,"animal depth queries agree with the rendered seabed vertices")
	check(maximum_depth-minimum_depth>2.5,"bathymetry changes geometry rather than only painting the surface")
	var image=water.bed_texture.get_image();var sample=image.get_pixel(16,16).r*IslandWater.MAX_DEPTH
	check(abs(sample-water.map[16*(IslandWater.COLS+1)+16])<.001,"the shader depth map and seabed geometry share the same depth samples")
	check(abs(IslandWater.surface_radius(normal,2)-IslandWater.surface_radius(normal,5))>.002,"surface height really moves with the shared water clock")
	var slot=water.next_ripple
	water.ripple(normal,1.5);check(water.strengths[slot]==1.5,"water can receive a local splash or tap ripple")
	print("WATER_SURFACE_RESULT ",passed," passed / ",failed," failed")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--visual-out="):await visual(game,arg.trim_prefix("--visual-out="))
	game.closing=true;game.ambience.shutdown();game.speech.stop();game.speech.stream=null;await create_timer(.10).timeout
	for player in game.effects:player.stop();player.stream=null
	game.queue_free();await process_frame;await process_frame
	var drain_until=Time.get_ticks_msec()+250
	while Time.get_ticks_msec()<drain_until:await process_frame
	quit(0 if failed==0 else 1)
func snap(directory:String,name:String):
	await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(directory.path_join(name+".png"))
func visual(game,directory:String):
	DirAccess.make_dir_recursive_absolute(directory)
	game.explore();game.world.desired_rotation=Quaternion(Vector3.UP,Vector3(0,.85,.53).normalized())
	await create_timer(1.0).timeout;await snap(directory,"water-full")
	game.camera.size=14;game.camera.look_at(Vector3(0,8,0));game.world.desired_rotation=Quaternion.IDENTITY
	await create_timer(1.0).timeout;await snap(directory,"water-coast")
	game.world.water.ripple(Vector3(-.25,.95,.18).normalized(),2.4)
	await create_timer(.9).timeout;await snap(directory,"water-ripple")
