extends SceneTree
var game
var cosmos
var output="../work/qa10"
var failed=0
func _initialize():
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--visual-out="):output=argument.trim_prefix("--visual-out=")
	DirAccess.make_dir_recursive_absolute(output)
	call_deferred("run")
func check(ok:bool,label:String):
	print("PASS " if ok else "FAIL ",label)
	if not ok:failed+=1
func picture(name:String,scene=false)->Image:
	await process_frame;await RenderingServer.frame_post_draw
	var image=root.get_texture().get_image() if scene else cosmos.viewport.get_texture().get_image()
	image.save_png(output.path_join("cosmos-v10-"+name+".png"))
	return image
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
	await create_timer(.5).timeout
	cosmos=game.get_node("Cosmos");cosmos.set_process(false);cosmos.apply_settings({});cosmos.set_sky_seed(103)
	check(cosmos.cloud_texture is NoiseTexture3D and cosmos.cloud_regions.size()==3,"cloud detail is generated procedurally in three spatial volumes")
	check(cosmos.cloud_regions[0].center.z!=cosmos.cloud_regions[1].center.z and cosmos.cloud_regions[2].center.z<-150,"cloud regions have distinct real perspective depths behind the planets")
	await picture("overview",true);var normal=await picture("background")
	var dark=0;var sampled=0
	for y in range(0,normal.get_height(),8):
		for x in range(0,normal.get_width(),8):
			var color=normal.get_pixel(x,y);sampled+=1
			if maxf(color.r,maxf(color.g,color.b))<.06:dark+=1
	print("DARK_SPACE_FRACTION ",float(dark)/sampled)
	check(float(dark)/sampled>.65,"default universe keeps most of its image deeply dark")
	for region in cosmos.cloud_regions:region.material.set_shader_parameter("ray_steps",8)
	var mobile_budget=await picture("mobile-budget")
	check(delta(normal,mobile_budget)<.01,"eight-step cloud integration preserves the sparse composition")
	for region in cosmos.cloud_regions:region.material.set_shader_parameter("ray_steps",12)
	var previous=normal
	for seed_value in [7919,48271]:
		cosmos.set_sky_seed(seed_value);var alternate=await picture("seed-"+str(seed_value))
		await picture("seed-"+str(seed_value)+"-overview",true)
		var difference=delta(previous,alternate);print("SEED_DELTA ",seed_value," ",difference)
		check(difference>.005,"seed "+str(seed_value)+" changes the sparse cloud layout")
		previous=alternate
	cosmos.set_sky_seed(103);var repeat=await picture("repeat-seed")
	check(delta(normal,repeat)<.0001,"a seed reproduces the same cloud and star layout")
	var params=cosmos.settings.duplicate();var prior_seed=cosmos.sky_seed;cosmos.randomize_sky()
	check(cosmos.sky_seed!=prior_seed and cosmos.settings==params,"changing sky preserves the five controls and changes seed")
	cosmos.set_sky_seed(103)
	var old_size=cosmos.viewport.size
	for key in ["nebula","color","band","stars"]:
		var values=cosmos.DEFAULT_SETTINGS.duplicate();values[key]=cosmos.SETTING_LIMITS[key].x
		cosmos.apply_settings(values);var low=await picture(key+"-low")
		values[key]=cosmos.SETTING_LIMITS[key].y;cosmos.apply_settings(values);var high=await picture(key+"-high")
		var change=delta(low,high);print("PIXEL_DELTA ",key," ",change)
		check(change>(.0003 if key=="stars" else .001),key+" changes the rendered sky")
	cosmos.apply_settings({"drift":0});var stopped=cosmos.nebula_clock;var position=cosmos.bodies[0].orbit.position
	cosmos.advance(90)
	check(cosmos.nebula_clock==stopped,"zero drift freezes the nebula phase")
	check(position.distance_to(cosmos.bodies[0].orbit.position)>2,"planets continue orbiting with frozen nebula")
	cosmos.apply_settings({"drift":2});check(cosmos.nebula_clock==stopped,"changing speed does not jump the phase")
	cosmos.advance(60);check(is_equal_approx(cosmos.nebula_clock-stopped,120),"double drift uses an independent accumulated time")
	cosmos.apply_settings({});game.resume_collect();await create_timer(.6).timeout
	await picture("study",true)
	game.explore(true,false);DisplayServer.window_set_size(Vector2i(1080,1920))
	await create_timer(.3).timeout
	print("SPACE_RESOLUTION ",old_size," -> ",cosmos.viewport.size)
	check(cosmos.viewport.size.x>=1080 and cosmos.viewport.size.y>=1920,"desktop enlargement renders planets at physical resolution")
	check(cosmos.viewport.msaa_3d==Viewport.MSAA_4X,"desktop planet edges use four-sample antialiasing")
	await picture("large-overview",true);await picture("large-background")
	print("COSMOS_ART_RESULT ",failed," failures")
	game.closing=true;game.ambience.shutdown();game.speech.stop();game.speech.stream=null
	await process_frame;await process_frame;game.queue_free();await process_frame;await process_frame
	quit(1 if failed else 0)
