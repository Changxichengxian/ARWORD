extends Node

# Keep the dictionary usable while the world is being assembled. All scene-tree
# work stays on the main thread; imported resources are read in the background.
var game
var sky
var held_resources:Array=[]
var arrivals:Array=[]
var marks:Dictionary={}
var pending:Array=[]

func mark(label:String):marks[label]=Time.get_ticks_msec()

func start(owner_game):
	game=owner_game
	var layer=CanvasLayer.new();layer.layer=1;add_child(layer)
	sky=preload("res://scripts/startup_sky.gd").new();layer.add_child(sky)
	mark("search_ready")
	call_deferred("assemble")

func assemble():
	if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw
	else:await get_tree().process_frame
	if game.closing:return
	mark("first_draw")
	pending=["res://scripts/grove.gd","res://scripts/cosmos.gd","res://scripts/wildlife.gd","res://scripts/ambience.gd"]
	var paths=pending
	for file in DirAccess.get_files_at("res://assets/models"):
		var model="res://assets/models/"+str(file).trim_suffix(".import")
		if model.ends_with(".glb") and model not in paths:paths.append(model)
	# Godot 4.5 dummy rendering has no thread-safe material storage. The
	# headless verification path loads on the main thread; native apps use
	# the background loader exercised by the Vulkan startup test.
	if DisplayServer.get_name()=="headless":
		if not await game.startup_turn():return
		for path in paths:held_resources.append(load(path))
		paths.clear()
	else:
		for path in paths:
			if ResourceLoader.load_threaded_request(path)!=OK:push_warning("Could not prefetch "+path)
	while not paths.is_empty():
		await get_tree().process_frame
		if game.closing:return
		for i in range(paths.size()-1,-1,-1):
			var status=ResourceLoader.load_threaded_get_status(paths[i])
			if status==ResourceLoader.THREAD_LOAD_LOADED:
				held_resources.append(ResourceLoader.load_threaded_get(paths[i]));paths.remove_at(i)
			elif status in [ResourceLoader.THREAD_LOAD_FAILED,ResourceLoader.THREAD_LOAD_INVALID_RESOURCE]:
				push_error("Startup resource failed: "+paths[i]);game.hud.toast("星球暂时没有打开，仍可查词");return
	if not await game.startup_turn():return
	game.world=load("res://scripts/grove.gd").new()
	game.world.process_mode=Node.PROCESS_MODE_DISABLED;game.world.hide();game.add_child(game.world)
	game.world.setup_base(game)
	if not await game.startup_turn():return
	game.world.setup_buildings()
	if not await game.startup_turn():return
	game.world.setup_actor()
	if not await game.startup_turn():return
	game.world.finish_setup();game.setup_camera()
	if not await game.startup_turn():return
	game.cosmos=load("res://scripts/cosmos.gd").new();game.cosmos.name="Cosmos";game.add_child(game.cosmos);game.cosmos.setup(game)
	if not await game.startup_turn():return
	game.world.wildlife=load("res://scripts/wildlife.gd").new();game.world.add_child(game.world.wildlife)
	game.world.wildlife.process_mode=Node.PROCESS_MODE_DISABLED
	await game.world.wildlife.setup(game.world,true)
	if not await game.startup_turn():return
	prepare_arrivals()
	game.setup_world_audio();game.hud.attach_world();game.next_task();game.explore(true,false)
	if game.art_preview:game.world.desired_rotation=Quaternion(Vector3.UP,Vector3(0,.85,.53).normalized())
	game.world.show();game.world.process_mode=Node.PROCESS_MODE_INHERIT
	game.world.wildlife.process_mode=Node.PROCESS_MODE_INHERIT
	game.stop_view_transition()
	pull_back(0.)
	if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw
	else:await get_tree().process_frame
	mark("world_reveal")
	# A shader/upload frame can be long. Start the camera on a fresh delta so
	# the first movement is not skipped by that earlier frame.
	await get_tree().process_frame
	await get_tree().process_frame
	var tween=create_tween();tween.tween_method(pull_back,0.,1.,.82).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tween.finished
	if game.closing:return
	game.scene_ready=true;game.hud.set_world_ready(true);layer_free()
	mark("world_ready");held_resources.clear()
	if not await game.startup_turn():return
	await game.initialize_avatar()
	if game.closing:return
	mark("person_start")
	if is_instance_valid(game.world.avatar):
		var avatar=game.world.avatar;var base=avatar.scale
		game.world.avatar_appearing=true;avatar.enabled=false;avatar.scale=base*.025
		if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw
		await get_tree().process_frame
		await get_tree().process_frame
		if game.closing or not is_instance_valid(avatar):return
		var appear=avatar.create_tween();appear.tween_property(avatar,"scale",base,.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		await appear.finished
		if game.closing or not is_instance_valid(avatar):return
		avatar.scale=base;avatar.enabled=true;game.world.avatar_appearing=false
	mark("person_ready")
	# Only the visual children grow. Route anchors, collision clearances and
	# species-specific scale animation retain their original transforms.
	arrivals.sort_custom(func(a,b):return arrival_priority(a)>arrival_priority(b))
	for visual in arrivals:
		if game.closing:return
		if not is_instance_valid(visual):continue
		if not marks.has("animals_start"):mark("animals_start")
		visual.show()
		var pop=visual.create_tween();pop.tween_property(visual,"scale",Vector3.ONE,.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		await get_tree().create_timer(.065).timeout
	await get_tree().create_timer(.32).timeout
	mark("animals_ready")

func layer_free():
	if is_instance_valid(sky):sky.get_parent().queue_free();sky=null

func shutdown():
	# Finish outstanding reads before Godot tears down its resource loaders.
	# Otherwise a script still parsing on a worker can lose its dependencies.
	while not pending.is_empty():
		for i in range(pending.size()-1,-1,-1):
			var status=ResourceLoader.load_threaded_get_status(pending[i])
			if status==ResourceLoader.THREAD_LOAD_LOADED:
				held_resources.append(ResourceLoader.load_threaded_get(pending[i]));pending.remove_at(i)
			elif status in [ResourceLoader.THREAD_LOAD_FAILED,ResourceLoader.THREAD_LOAD_INVALID_RESOURCE]:pending.remove_at(i)
		if not pending.is_empty():await get_tree().process_frame

func pull_back(value:float):
	if game.closing:return
	game.camera.size=lerpf(7.,25.5,value)
	game.camera.position=Vector3(0,17,12).lerp(game.HOME_CAMERA,value)
	game.camera_focus=Vector3(0,10.4,0).lerp(Vector3(0,4.2,0),value)
	game.camera.look_at(game.camera_focus);game.world_zoom=game.camera.size
	game.cosmos.space_camera.position=game.cosmos.CENTER*(.28*(1.-value))
	game.cosmos.update_sky_camera()
	if is_instance_valid(sky):sky.pullback=value;sky.reveal=smoothstep(.02,.42,value)

func prepare_arrivals():
	var wildlife=game.world.wildlife
	for animal in wildlife.animals:wrap_visual(animal.model)
	for crab in wildlife.tidepool.crabs:wrap_visual(crab.model)
	wrap_visual(wildlife.tidepool.seal)
	for rabbit in wildlife.land_life.rabbits:wrap_visual(rabbit.model)

func wrap_visual(model:Node3D):
	if not is_instance_valid(model):return
	var children=model.get_children()
	var visual=Node3D.new();visual.name="ArrivalVisual";model.add_child(visual)
	for child in children:
		if child is Node3D:child.reparent(visual,false)
	visual.hide();visual.scale=Vector3.ONE*.025;arrivals.append(visual)

func arrival_priority(visual:Node3D)->float:
	var model=visual.get_parent()
	if not model.is_visible_in_tree():return -1000.
	var point=model.global_position
	return point.normalized().dot((game.camera.global_position-point).normalized())
