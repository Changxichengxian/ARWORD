extends SceneTree
var game
var cosmos
var failed=0
var output="../work/qa11/cosmos"
func _initialize():
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	DirAccess.make_dir_recursive_absolute(output)
	call_deferred("run")
func check(ok:bool,label:String):
	print("PASS " if ok else "FAIL ",label)
	if not ok:failed+=1
func picture(name:String,scene=false)->Image:
	await process_frame;await RenderingServer.frame_post_draw
	var image=root.get_texture().get_image() if scene else cosmos.viewport.get_texture().get_image()
	image.save_png(output.path_join(name+".png"));return image
func delta(a:Image,b:Image)->float:
	var total=0.0;var count=0
	for y in range(0,mini(a.get_height(),b.get_height()),5):
		for x in range(0,mini(a.get_width(),b.get_width()),5):
			var first=a.get_pixel(x,y);var second=b.get_pixel(x,y)
			total+=absf(first.r-second.r)+absf(first.g-second.g)+absf(first.b-second.b);count+=3
	return total/count
func run():
	game=load("res://main.tscn").instantiate();root.add_child(game)
	DisplayServer.window_set_position(Vector2i(DisplayServer.screen_get_usable_rect().end.x-100,60))
	await create_timer(1.0).timeout
	cosmos=game.get_node("Cosmos");cosmos.set_process(false);cosmos.apply_settings({});cosmos.set_sky_seed(103);cosmos.advance(0)
	var seed=cosmos.sky_seed;var settings=cosmos.settings.duplicate();var saved=JSON.stringify(game.learning.data)
	var overview=await picture("daily-background");await picture("daily-overview",true)
	var dark=0;var sampled=0
	for y in range(0,overview.get_height(),7):
		for x in range(0,overview.get_width(),7):
			var pixel=overview.get_pixel(x,y);sampled+=1
			if maxf(pixel.r,maxf(pixel.g,pixel.b))<.06:dark+=1
	check(float(dark)/sampled>.75,"daily universe remains mostly deep black")
	print("DAILY_DARK_FRACTION ",float(dark)/sampled)
	check(cosmos.observation_targets().size()==3,"three distinct observation targets are available")
	check(not cosmos.enter_observatory(-1) and not cosmos.observatory_active,"invalid observation target leaves the normal view intact")
	var last:Image
	for i in range(3):
		check(cosmos.enter_observatory(i),"enter target "+str(i))
		for frame in range(90):cosmos.advance(1.0/60)
		var target=await picture("target-"+str(i));await picture("target-"+str(i)+"-screen",true)
		check(cosmos.canvas.layer==4 and cosmos.space_camera.position.length()>15,"observatory moves a real perspective camera and covers the island")
		check(cosmos.cloud_regions[i].material.get_shader_parameter("ray_steps")==36,"desktop observation uses detailed volume integration")
		if i>0:check(delta(last,target)>.008,"target "+str(i)+" has a distinct volume and palette")
		last=target
	cosmos.cloud_regions[2].material.set_shader_parameter("ray_steps",24)
	var mobile=await picture("target-2-mobile-budget")
	check(delta(last,mobile)<.01,"mobile sample budget retains detailed observation structure")
	cosmos.update_observation_quality()
	cosmos.rotate_observation(Vector2(130,-50));cosmos.zoom_observation(.8)
	for frame in range(90):cosmos.advance(1.0/60)
	var orbited=await picture("target-2-orbit")
	check(delta(last,orbited)>.006,"orbit and zoom change the 3D cloud structure")
	cosmos.apply_settings({"drift":0});var phase=cosmos.nebula_clock;var planet=cosmos.bodies[0].orbit.position
	cosmos.advance(20)
	check(cosmos.nebula_clock==phase and planet.distance_to(cosmos.bodies[0].orbit.position)>.1,"stopped cloud drift does not stop the solar system")
	cosmos.apply_settings(settings);cosmos.leave_observatory()
	check(not cosmos.observatory_active and cosmos.canvas.layer==-10 and cosmos.space_camera.position==Vector3.ZERO,"leaving restores the normal camera and display layer")
	check(cosmos.settings==settings and cosmos.sky_seed==seed,"observatory preserves saved settings and the current sky")
	check(JSON.stringify(game.learning.data)==saved,"observation does not alter learning or construction progress")
	cosmos.set_sky_seed(7919);cosmos.advance(0);await picture("daily-seed-7919")
	cosmos.enter_observatory(1)
	for frame in range(90):cosmos.advance(1.0/60)
	await picture("target-1-seed-7919")
	cosmos.leave_observatory();game.resume_collect();await create_timer(.6).timeout
	await picture("daily-study",true)
	await model_picture()
	print("OBSERVATORY_RESULT ",failed," failures")
	game.closing=true;game.ambience.shutdown();game.speech.stop();game.speech.stream=null
	await process_frame;await process_frame;game.queue_free();await process_frame;await process_frame
	quit(1 if failed else 0)
func model_picture():
	var view=SubViewport.new();view.size=Vector2i(800,900);view.own_world_3d=true;view.msaa_3d=Viewport.MSAA_4X;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
	var stage=Node3D.new();view.add_child(stage)
	var env=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("ABC8CD");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color("DCE9E6");env.environment.ambient_light_energy=.7;stage.add_child(env)
	var sun=DirectionalLight3D.new();stage.add_child(sun);sun.rotation_degrees=Vector3(-40,-35,-15);sun.light_energy=1.6;sun.shadow_enabled=true
	var model=load("res://assets/models/telescope.glb").instantiate();stage.add_child(model)
	check(model.get_child_count()>0,"original telescope GLB loads as a 3D model")
	var camera=Camera3D.new();stage.add_child(camera);camera.position=Vector3(4,3.5,5);camera.look_at(Vector3(0,1.2,0));camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=4.2;camera.current=true
	await process_frame;await RenderingServer.frame_post_draw;view.get_texture().get_image().save_png(output.path_join("telescope-model.png"))
	view.queue_free();await process_frame
