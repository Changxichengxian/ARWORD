extends Node

# Load small pieces on the main thread after the first UI frame. Concurrent
# script/model loads can share dependencies and stall Android rendering.
var game
var sky
var held_resources:Array=[]
var arrivals:Array=[]
var growing:Array=[]
var marks:Dictionary={}
var pending:Array=[]
var failed=false
var phase="waiting"
var phase_started=0
var phase_active_ms=0
var last_tick=0
const CAMERA_SECONDS=.72
var camera_elapsed=0.0
var camera_running=false

func mark(label:String):marks[label]=Time.get_ticks_msec()

func start(owner_game):
	game=owner_game
	var layer=CanvasLayer.new();layer.layer=1;add_child(layer)
	sky=preload("res://scripts/startup_sky.gd").new();layer.add_child(sky)
	set_phase("waiting");set_process(true)
	mark("search_ready")
	call_deferred("assemble")

func assemble():
	if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw
	else:await get_tree().process_frame
	if game.closing:return
	mark("first_draw")
	# Only read what the initial world actually uses. Animal models and habitat
	# planning belong after the first visible planet, not in a global preload.
	set_phase("world")
	if not await game.startup_turn():return
	game.world=load("res://scripts/grove.gd").new()
	game.world.process_mode=Node.PROCESS_MODE_DISABLED;game.world.hide();game.add_child(game.world)
	game.world.setup_base(game);mark("base_ready")
	if not await game.startup_turn():return
	await game.world.setup_buildings(true);mark("buildings_ready")
	if not await game.startup_turn():return
	game.world.setup_actor();mark("rig_ready")
	if not await game.startup_turn():return
	game.world.finish_setup();game.setup_camera();mark("geometry_ready")
	game.hud.attach_world();game.next_task();game.explore(true,false)
	if game.art_preview:game.world.desired_rotation=Quaternion(Vector3.UP,Vector3(0,.85,.53).normalized())
	game.stop_view_transition();pull_back(0.)
	game.world.show();game.world.process_mode=Node.PROCESS_MODE_INHERIT
	# Reveal on the first renderable frame. Space, audio and living things do
	# not hold the planet behind the black canvas.
	layer_free();set_phase("reveal")
	if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw
	else:await get_tree().process_frame
	mark("world_reveal")
	camera_running=true;mark("camera_start")
	set_phase("space")
	if not await game.startup_turn():return
	game.cosmos=load("res://scripts/cosmos.gd").new();game.cosmos.name="Cosmos";game.add_child(game.cosmos);game.cosmos.setup(game)
	pull_back(camera_progress());mark("space_ready")
	if not await game.startup_turn():return
	game.setup_world_audio();mark("audio_ready")
	game.scene_ready=true;game.hud.set_world_ready(true);mark("world_ready")
	# The camera moves while the remaining space/audio is prepared. Waiting
	# here never postpones world_reveal, which has already been drawn.
	while camera_running and not game.closing:await get_tree().process_frame
	if game.closing:return
	set_phase("character")
	if not await game.startup_turn():return
	await game.initialize_avatar()
	if game.closing:return
	mark("person_start")
	if is_instance_valid(game.world.avatar):
		var avatar=game.world.avatar;var base=avatar.scale
		game.world.avatar_appearing=true;avatar.enabled=false
		var arrival=begin_arrival(avatar,base,.78)
		while not arrival.done and not game.closing:await get_tree().process_frame
		if game.closing or not is_instance_valid(avatar):return
		avatar.scale=base;avatar.enabled=true;game.world.avatar_appearing=false
	mark("person_ready");set_phase("wildlife_resources")
	pending=[]
	for file in DirAccess.get_files_at("res://assets/models"):
		var model=str(file).trim_suffix(".import").trim_suffix(".remap")
		if model.ends_with(".glb") and (model.begins_with("wild_") or model in ["sea_coral.glb","sea_grass.glb","sea_relic.glb","sea_cave.glb","tidal_ledge.glb"]):
			var path="res://assets/models/"+model
			if path not in pending:pending.append(path)
	pending.sort()
	while not pending.is_empty():
		if not await game.startup_checkpoint():return
		var resource=load(pending.pop_front())
		if resource==null:fail("动物暂时没有准备好，可继续学习或检查更新");return
		held_resources.append(resource)
	set_phase("wildlife")
	if not await game.startup_turn():return
	var wildlife=load("res://scripts/wildlife.gd").new()
	wildlife.process_mode=Node.PROCESS_MODE_DISABLED;wildlife.hide();game.world.add_child(wildlife)
	await wildlife.setup(game.world,true)
	if not await game.startup_turn():return
	# Construction can continue during this stage. Reconcile any new land
	# before enabling movement or exposing the prepared animals.
	while wildlife.land_count!=game.world.land.size():
		if not await game.startup_turn():return
		await wildlife.refresh_habitats(true)
	game.world.wildlife=wildlife;prepare_arrivals()
	wildlife._process(0.);wildlife.show();wildlife.process_mode=Node.PROCESS_MODE_INHERIT
	held_resources.clear();mark("wildlife_ready");set_phase("arrivals")
	# Only the visual children grow. Route anchors, collision clearances and
	# species-specific scale animation retain their original transforms.
	arrivals.sort_custom(func(a,b):return arrival_priority(a)>arrival_priority(b))
	for visual in arrivals:
		if game.closing:return
		if not is_instance_valid(visual):continue
		if not marks.has("animals_start"):mark("animals_start")
		begin_arrival(visual,Vector3.ONE,.68)
		await get_tree().create_timer(.14).timeout
	while not growing.is_empty() and not game.closing:await get_tree().process_frame
	if game.closing:return
	mark("animals_ready");set_phase("complete");set_process(false)

func begin_arrival(visual:Node3D,base:Vector3,seconds:float)->Dictionary:
	visual.scale=base*.025;visual.show()
	var arrival={"visual":visual,"base":base,"seconds":seconds,"elapsed":0.,"frame":Engine.get_process_frames()+2,"done":false}
	growing.append(arrival);return arrival

func advance_arrivals(dt:float):
	for i in range(growing.size()-1,-1,-1):
		var arrival=growing[i]
		if not is_instance_valid(arrival.visual):arrival.done=true;growing.remove_at(i);continue
		if Engine.get_process_frames()<arrival.frame:continue
		# Let the tiny first frame warm its material, then preserve the visible
		# growth even if the renderer or a later load has one long frame.
		arrival.elapsed=minf(arrival.seconds,arrival.elapsed+minf(dt,1./30.))
		var t=arrival.elapsed/arrival.seconds;var back=t-1.
		var size=1.+2.45*back*back*back+1.45*back*back
		arrival.visual.scale=arrival.base*lerpf(.025,1.,size)
		if t>=1.:arrival.visual.scale=arrival.base;arrival.done=true;growing.remove_at(i)

func layer_free():
	if is_instance_valid(sky):sky.get_parent().queue_free();sky=null

func shutdown():
	pending.clear()

func set_phase(value:String):
	mark("phase_"+value)
	phase=value;phase_started=Time.get_ticks_msec();phase_active_ms=0;last_tick=phase_started

func _process(dt):
	advance_arrivals(dt)
	if camera_running and not game.closing:
		# A single shader upload must not consume the whole visible movement.
		camera_elapsed=minf(CAMERA_SECONDS,camera_elapsed+minf(dt,1./30.))
		pull_back(camera_progress())
		if camera_elapsed>=CAMERA_SECONDS:camera_running=false;mark("camera_ready")
	var now=Time.get_ticks_msec()
	if game.closing or failed or game.scene_ready:last_tick=now;return
	if not game.hud.overlay.visible and not game.startup_input_busy():phase_active_ms+=mini(1000,now-last_tick)
	last_tick=now
	if phase_active_ms>30000:fail("星球暂时没有打开，可继续查词或检查更新")

func fail(message:String):
	if failed:return
	failed=true;pending.clear();mark("failed");game.hud.toast(message)
	# Keep the lightweight sky and the three usable toolbar entries. Never
	# replace the user's learning save with an empty or partially loaded world.

func cancel_camera():
	if not camera_running:return
	camera_running=false;mark("camera_interrupted");mark("camera_ready")

func camera_progress()->float:
	return .5-.5*cos(PI*clampf(camera_elapsed/CAMERA_SECONDS,0.,1.))

func pull_back(value:float):
	if game.closing:return
	game.camera.size=lerpf(7.,25.5,value)
	game.camera.position=Vector3(0,17,12).lerp(game.HOME_CAMERA,value)
	game.camera_focus=Vector3(0,10.4,0).lerp(Vector3(0,4.2,0),value)
	game.camera.look_at(game.camera_focus);game.world_zoom=game.camera.size
	if is_instance_valid(game.cosmos):
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
