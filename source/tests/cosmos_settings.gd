extends SceneTree
var game
var cosmos
var failures=0
var output=""
func _initialize():
	assert("--qa" in OS.get_cmdline_user_args() and DisplayServer.get_name()!="headless")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--visual-out="):output=arg.trim_prefix("--visual-out=");DirAccess.make_dir_recursive_absolute(output)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	call_deferred("run")
func check(ok:bool,label:String):
	if not ok:failures+=1
	print("PASS " if ok else "FAIL ",label)
func shot(name:String,scene=false)->Image:
	await process_frame
	await RenderingServer.frame_post_draw
	var img=root.get_texture().get_image() if scene else cosmos.viewport.get_texture().get_image()
	if not output.is_empty():img.save_png(output.path_join("cosmos-settings-"+name+".png"))
	return img
func delta(a:Image,b:Image)->float:
	var total=0.0;var count=0
	for y in range(0,mini(a.get_height(),b.get_height()),5):
		for x in range(0,mini(a.get_width(),b.get_width()),5):
			var one=a.get_pixel(x,y);var two=b.get_pixel(x,y)
			total+=absf(one.r-two.r)+absf(one.g-two.g)+absf(one.b-two.b);count+=3
	return total/count
func run():
	game=load("res://main.tscn").instantiate();root.add_child(game)
	await create_timer(.5).timeout
	cosmos=game.get_node("Cosmos");cosmos.set_process(false)
	cosmos.apply_settings({})
	await shot("default-overview",true)
	var normal=await shot("default")
	for key in ["nebula","color","band","stars"]:
		var settings=cosmos.DEFAULT_SETTINGS.duplicate();settings[key]=cosmos.SETTING_LIMITS[key].x
		cosmos.apply_settings(settings);var low=await shot(key+"-low")
		settings[key]=cosmos.SETTING_LIMITS[key].y;cosmos.apply_settings(settings);var high=await shot(key+"-high")
		var change=delta(low,high);print("VISUAL_DELTA ",key," ",change)
		check(change>(.0005 if key=="stars" else .001),"live "+key+" parameter changes native rendered pixels")
	cosmos.apply_settings({"nebula":2.5,"color":2.0,"band":2.0,"stars":2.0,"drift":2.0})
	await shot("bold-overview",true)
	await shot("bold")
	cosmos.apply_settings({"nebula":-4,"color":8,"band":-1,"stars":99,"drift":-7})
	check(cosmos.settings.nebula==0 and cosmos.settings.color==2 and is_equal_approx(cosmos.settings.band,.4) and cosmos.settings.stars==2 and cosmos.settings.drift==0,"settings clamp to the agreed slider limits")
	cosmos.apply_settings({"drift":0})
	var cloud_time=cosmos.nebula_clock;var planet=cosmos.bodies[0].orbit.position
	cosmos.advance(90)
	check(cosmos.nebula_clock==cloud_time,"zero drift freezes only the nebula phase")
	check(planet.distance_to(cosmos.bodies[0].orbit.position)>2,"zero drift preserves planet orbits")
	cosmos.apply_settings({"drift":2});cosmos.advance(60)
	check(absf(cosmos.nebula_clock-cloud_time-120)<.001,"double drift advances clouds at twice real time")
	await shot("drifted")
	cosmos.apply_settings({});game.resume_collect();await create_timer(.6).timeout
	await shot("default-study",true)
	print("COSMOS_SETTINGS_RESULT ",failures," failures")
	game.closing=true;game.ambience.shutdown();game.speech.stop();game.speech.stream=null
	await process_frame;await process_frame;game.queue_free();await process_frame;await process_frame
	quit(1 if failures else 0)
