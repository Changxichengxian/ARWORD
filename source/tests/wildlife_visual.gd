extends SceneTree
# Internal model review only: same articulated models and small-animal poses as the game.
var output=""
var stage:Node3D
var camera:Camera3D
var animator:IslandWildlife
const ITEMS=[
	["bird","wild_bird",2.0],["turtle","wild_turtle",1.7],["ray","wild_ray",2.6],
	["gold","wild_fish",1.1],["silver","wild_silver_fish",1.3],["reef","wild_reef_fish",1.3],
	["butterfly","wild_butterfly",.95],["whale","wild_whale",5.6],["orca","wild_orca",4.7],["jelly","wild_jelly",1.35],
	["dolphin","wild_dolphin",2.8],["seahorse","wild_seahorse",1.3],["puffer","wild_puffer",1.2],["squid","wild_squid",1.8],["tidepool","",2.9]]

func _initialize():
	if not "--qa" in OS.get_cmdline_user_args():quit(2);return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--visual-out="):output=arg.trim_prefix("--visual-out=")
	call_deferred("run")

func pose(animal:Dictionary,t:float):
	if animal.species=="tidepool":
		animal.model.notice("seal" if t>6. else "crab");animal.model.animate(t,0.)
	elif animal.species=="bird":animator.animate_bird(animal,t)
	elif animal.species=="butterfly":animator.animate_butterfly(animal,t)
	elif animal.species in ["whale","orca"]:
		var orca=animal.species=="orca"
		animal.tail.rotation.x=sin(t*(1.75 if orca else .92))*(.22 if orca else .15)
		var fluke=animal.model.find_child("Fluke",true,false)
		if fluke:fluke.rotation.x=sin(t*(1.75 if orca else .92)-.55)*.15
		animal.model.rotation.z=sin(t*.45)*.04
	else:animator.animate_fish(animal,t)

func run():
	assert(not output.is_empty())
	DirAccess.make_dir_recursive_absolute(output)
	root.content_scale_size=Vector2i(1500,760);root.size=Vector2i(1500,760)
	stage=Node3D.new();root.add_child(stage)
	animator=IslandWildlife.new();stage.add_child(animator);animator.set_process(false);animator.add_child(animator.tidepool);animator.tidepool.hide()
	animator.add_child(animator.land_life);animator.land_life.hide()
	var env_node=WorldEnvironment.new();var env=Environment.new()
	env.background_mode=Environment.BG_COLOR;env.background_color=Color("B5CFD5")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("EAF4F4");env.ambient_light_energy=.65
	env_node.environment=env;stage.add_child(env_node)
	var key=DirectionalLight3D.new();stage.add_child(key);key.rotation_degrees=Vector3(-45,-30,0);key.light_color=Color("FFF4DF");key.light_energy=1.4
	var fill=DirectionalLight3D.new();stage.add_child(fill);fill.rotation_degrees=Vector3(-25,130,0);fill.light_color=Color("C1DBF7");fill.light_energy=.55
	camera=Camera3D.new();stage.add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.keep_aspect=Camera3D.KEEP_WIDTH;camera.current=true
	for item in ITEMS:
		var models=[]
		var size=float(item[2]);camera.size=size*3.6
		camera.position=Vector3(0,size*1.3,-size*2.7);camera.look_at(Vector3.ZERO)
		for i in 3:
			var anchor=Node3D.new();stage.add_child(anchor);anchor.position.x=(i-1)*size*1.15
			anchor.rotation.y=-.45 if i!=2 else -.9
			var model=load("res://scripts/tidepool.gd").new() if item[0]=="tidepool" else load("res://assets/models/"+item[1]+".glb").instantiate();anchor.add_child(model)
			var animal={"model":model,"species":item[0],"scale":1.,"startle":0.,"state":""}
			animator.bind_joints(animal);pose(animal,([1.,8.,18.][i] if item[0]=="tidepool" else [.7,2.2,6.1][i]));models.append(anchor)
		await process_frame;await process_frame;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join(item[0]+".png"))
		for model in models:model.queue_free()
		await process_frame
	stage.queue_free();await process_frame
	print("WILDLIFE_VISUAL_READY ",output);quit()
