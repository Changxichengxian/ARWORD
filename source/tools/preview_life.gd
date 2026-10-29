extends SceneTree
func _initialize():call_deferred("run")
func run():
	var output=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):output=arg.trim_prefix("--out=")
	assert(not output.is_empty())
	root.content_scale_size=Vector2i(1100,500);root.size=Vector2i(1100,500)
	var stage=Node3D.new();root.add_child(stage)
	var environment=WorldEnvironment.new();var light=Environment.new();light.background_mode=Environment.BG_COLOR;light.background_color=Color("294A60");light.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;light.ambient_light_color=Color("D4E6F0");light.ambient_light_energy=.6;environment.environment=light;stage.add_child(environment)
	var sun=DirectionalLight3D.new();stage.add_child(sun);sun.rotation_degrees=Vector3(-50,-30,0);sun.light_color=Color("FFF1DC");sun.light_energy=1.5
	var camera=Camera3D.new();stage.add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.keep_aspect=Camera3D.KEEP_WIDTH;camera.size=11.2;camera.position=Vector3(0,3.2,6.5);camera.look_at(Vector3.ZERO);camera.current=true
	var objects=[]
	for i in range(4):
		var model=load("res://assets/models/"+["wild_bird","wild_fish","wild_butterfly","wild_whale"][i]+".glb").instantiate();stage.add_child(model);model.position.x=(i-1.5)*2.7;model.rotation.y=.5;model.scale=Vector3.ONE*([1.7,1.7,2.8,.85][i]);objects.append(model)
	for step in range(90):
		objects[0].find_child("WingL",true,false).rotation.z=sin(step*.17)*.4;objects[0].find_child("WingR",true,false).rotation.z=-sin(step*.17)*.4
		objects[1].find_child("Tail",true,false).rotation.y=sin(step*.2)*.3
		objects[2].find_child("WingL",true,false).rotation.z=-.3-abs(sin(step*.3))*.7;objects[2].find_child("WingR",true,false).rotation.z=.3+abs(sin(step*.3))*.7
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output)
	stage.queue_free();await process_frame
	print("LIFE_VISUAL_READY ",output)
	quit()
