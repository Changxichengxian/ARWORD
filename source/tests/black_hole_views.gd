extends SceneTree

var failures=0
var captures=""
func _initialize():call_deferred("run")

func check(value:bool,label:String):
	print("PASS " if value else "FAIL ",label)
	if not value:failures+=1

func frame(sky,label:String)->Image:
	await RenderingServer.frame_post_draw
	var img=sky.viewport.get_texture().get_image()
	if not captures.is_empty():img.save_png(captures.path_join(label+".png"))
	return img

func run():
	if not "--qa" in OS.get_cmdline_user_args() or DisplayServer.get_name()=="headless":quit(2);return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--captures="):captures=arg.trim_prefix("--captures=")
	if not captures.is_empty():DirAccess.make_dir_recursive_absolute(captures)
	var game=load("res://main.tscn").instantiate();root.add_child(game)
	var sky=load("res://scripts/cosmos.gd").new();game.add_child(sky)
	sky.setup_backdrop(game);sky.set_process(false);sky.set_sky_seed(831);sky.set_opening_view(0.)
	await frame(sky,"warm")
	var before=await frame(sky,"before-population")
	sky.populate()
	var after=await frame(sky,"after-population")
	check(before.get_data()==after.get_data() and before.get_data().count(200)>0,"the visible star field renders exactly the same pixels when deferred objects are added")
	sky.queue_free();await process_frame
	sky=game.cosmos;sky.set_process(false);sky.set_black_hole(true)
	# Use the same entry and drag handlers as the observatory. Unlock its prerequisite in the isolated world.
	game.frontier.finish_for_development(true)
	check(sky.enter_observatory(0,true),"open black hole")
	sky.observation_zoom=1.12
	sky.clock=7.;sky.advance(0.)
	var heights=[]
	var last:Image
	var continuous=true
	for target in [-1.40,-.0606,-.0603,-.0600,-.0597,-.0594,.53,1.40]:
		sky.rotate_observation(Vector2(0.,(target-sky.observation_pitch)/.0025))
		sky.advance_observation(5.)
		heights.append((sky.space_camera.position-sky.CENTER).normalized().dot(sky.black_hole.basis.y))
		var current=await frame(sky,"view-%02d"%heights.size())
		if heights.size()>=3 and heights.size()<=6:
			var changed=0
			var samples=0
			for y in range(0,current.get_height(),4):
				for x in range(0,current.get_width(),4):
					if absf(current.get_pixel(x,y).r-last.get_pixel(x,y).r)>.12:changed+=1
					samples+=1
			continuous=continuous and changed<samples*.02
		last=current
	check(continuous,"adjacent rendered frames stay continuous through the disk midplane")
	check(heights[0]<-.95 and heights[-1]>.98,"drag reaches both high angles in the disk frame")
	sky.zoom_observation(2.05);sky.advance_observation(5.)
	await frame(sky,"upper-wide")
	sky.observation_zoom=1.12
	var saved=sky.debris.multimesh.get_instance_transform(5)
	sky.advance(.4)
	check(sky.debris.visible and not sky.debris.material_override.emission_enabled and saved.origin.distance_to(sky.debris.multimesh.get_instance_transform(5).origin)>.1,"non-emitting stones orbit the disk")
	sky.observation_pitch=0.;sky.advance_observation(5.)
	var with_rocks=await frame(sky,"with-rocks")
	sky.debris.hide()
	var bare=await frame(sky,"without-rocks")
	var occluded=0
	for y in range(0,bare.get_height(),2):
		for x in range(0,bare.get_width(),2):
			if bare.get_pixel(x,y).r-with_rocks.get_pixel(x,y).r>.22:occluded+=1
	check(occluded>4,"foreground rock silhouettes cover bright pixels on the disk")
	sky.leave_observatory()
	print("BLACK_HOLE_VIEWS_RESULT ",failures," failed")
	game.closing=true;game.ambience.shutdown();game.speech.stop();game.speech.stream=null
	game.queue_free();await process_frame;await process_frame
	await create_timer(.3).timeout
	quit(int(failures>0))
