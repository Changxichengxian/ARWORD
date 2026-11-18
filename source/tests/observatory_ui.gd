extends SceneTree
var game
var passed=0
var failed=0
var output="../work/observatory-update/visual"
func _initialize():
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	DirAccess.make_dir_recursive_absolute(output);call_deferred("run")
func check(ok:bool,label:String):
	if ok:passed+=1;print("PASS ",label)
	else:failed+=1;push_error("FAIL "+label)
func settle():
	for i in range(3):await process_frame
func snapshot(name:String):
	if DisplayServer.get_name()=="headless":return
	await settle();await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(name+".png"))
func mouse_button(position:Vector2,pressed:bool,button=MOUSE_BUTTON_LEFT):
	var event=InputEventMouseButton.new();event.position=position;event.global_position=position;event.button_index=button;event.pressed=pressed;event.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed and button==MOUSE_BUTTON_LEFT else 0
	Input.parse_input_event(event);await settle()
func mouse_motion(position:Vector2,relative:Vector2,held=false):
	var event=InputEventMouseMotion.new();event.position=position;event.global_position=position;event.relative=relative;event.button_mask=MOUSE_BUTTON_MASK_LEFT if held else 0
	Input.parse_input_event(event);await settle()
func click_at(p:Vector2):
	await mouse_motion(p,Vector2.ZERO);await mouse_button(p,true);await mouse_button(p,false)
func touch(index:int,position:Vector2,pressed:bool):
	var event=InputEventScreenTouch.new();event.index=index;event.position=position;event.pressed=pressed
	Input.parse_input_event(event);await settle()
func touch_drag(index:int,position:Vector2,relative:Vector2):
	var event=InputEventScreenDrag.new();event.index=index;event.position=position;event.relative=relative
	Input.parse_input_event(event);await settle()
func sky_point(point:Vector3)->Vector2:
	return game.cosmos.space_camera.unproject_position(point)*root.get_visible_rect().size/Vector2(game.cosmos.viewport.size)
func run():
	game=load("res://main.tscn").instantiate();root.add_child(game)
	DisplayServer.window_set_size(Vector2i(540,960))
	await create_timer(.6).timeout
	var cosmos=game.cosmos;cosmos.set_process(false);cosmos.set_sky_seed(103);cosmos.advance(0)
	game.open_observatory(true);game.open_observatory(false,0,1)
	check(not cosmos.observatory_active and not cosmos.enter_observatory(0),"all observation routes require the completed observatory")
	await click_at(sky_point(cosmos.CENTER))
	check(not cosmos.observatory_active,"clicking the black hole before construction leaves the world visible")
	game.frontier.data.progress.mountain=game.frontier.chapter("mountain").need
	game.frontier.choose("mountain");game.next_task()
	var entrance=false
	for button in game.hud.card.find_children("*","BaseButton",true,false):
		if button.tooltip_text=="观测星云":entrance=true
	check(not entrance,"completed observatory has no separate telescope button")
	game.set_practice_mix(true)
	check(game.learning.context_modes().size()==3,"comprehensive choice enables reading, listening and sentences")
	await snapshot("practice-modes")
	game.set_practice_mix(false)
	check(game.learning.context_modes().is_empty(),"word-only choice disables all optional exercises")
	game.hud.close();game.explore(true,false)
	var history=JSON.stringify(game.learning.data)
	var opening=load("res://scripts/startup.gd").new();opening.game=game
	opening.pull_back(0.);cosmos.set_opening_view(0.)
	var close_fov=cosmos.star_material.get_shader_parameter("field_of_view")
	await snapshot("opening-close")
	opening.pull_back(1.);cosmos.set_opening_view(1.)
	var far_fov=cosmos.star_material.get_shader_parameter("field_of_view")
	check(close_fov<far_fov and opening.CAMERA_SECONDS>=1.5,"opening pullback gives the star field visible parallax at a gentler pace")
	opening.free();await snapshot("daily-sky")
	var overview=cosmos.space_camera.transform
	await click_at(sky_point(cosmos.CENTER));cosmos.advance(1.)
	check(cosmos.observatory_active and cosmos.primary_close,"native black-hole tap opens its close view after construction")
	check(not game.hud.visible,"covered island controls cannot intercept observation gestures")
	var buttons=game.observatory_layer.find_children("*","BaseButton",true,false)
	check(buttons.size()==1 and buttons[0].tooltip_text=="返回星球","observation shows only the return control")
	await snapshot("black-hole")
	var initial=cosmos.observation_yaw
	await mouse_button(Vector2(260,550),true);await mouse_motion(Vector2(290,560),Vector2(30,10),true)
	check(absf(cosmos.observation_yaw-initial)>.02,"mouse dragging rotates the observation camera")
	var button_point=buttons[0].get_global_rect().get_center()
	await mouse_motion(button_point,Vector2(0,-30),true);await mouse_button(button_point,false)
	var stopped=cosmos.observation_yaw;await mouse_motion(Vector2(300,600),Vector2(45,25))
	check(cosmos.observatory_active and not game.observatory_drag and is_equal_approx(cosmos.observation_yaw,stopped),"release over return ends a drag without exiting")
	var old_zoom=cosmos.observation_zoom;await mouse_button(Vector2(250,550),true,MOUSE_BUTTON_WHEEL_UP)
	check(cosmos.observation_zoom<old_zoom,"desktop wheel zoom remains available")
	await touch(0,Vector2(190,550),true);await touch(1,Vector2(350,550),true)
	var pinch_zoom=cosmos.observation_zoom
	await touch_drag(1,Vector2(390,550),Vector2(40,0))
	check(cosmos.observation_zoom<pinch_zoom,"two-finger pinch zooms the close view")
	await touch(1,button_point,false);var single_yaw=cosmos.observation_yaw
	await touch_drag(0,Vector2(215,550),Vector2(25,0))
	check(game.observatory_touch_points.size()==1 and absf(cosmos.observation_yaw-single_yaw)>.02,"one remaining finger keeps rotating")
	await touch(0,button_point,false)
	await click_at(button_point)
	check(not cosmos.observatory_active and cosmos.space_camera.transform==overview and game.hud.visible,"return restores the original sky and planet controls")
	await click_at(cosmos.screen_position(1));cosmos.advance(1.)
	check(cosmos.observatory_active and cosmos.observation_body==1,"native tap on an orbiting planet opens that planet")
	game.close_observatory();await settle()
	for index in range(cosmos.bodies.size()):
		game.open_observatory(false,0,index);cosmos.advance(1.)
		var body=cosmos.bodies[index]
		check(cosmos.observation_body==index and cosmos.space_camera.position.distance_to(body.orbit.position)<12,"close view frames planet "+str(index))
		await snapshot("planet-"+str(index));game.close_observatory();await settle()
	for index in range(cosmos.cloud_regions.size()):
		await click_at(sky_point(cosmos.cloud_regions[index].node.position));cosmos.advance(1.)
		check(cosmos.observatory_active and not cosmos.primary_close and cosmos.observation_body==-1 and cosmos.observation_index==index,"native sky tap selects nebula "+str(index))
		await snapshot("nebula-"+str(index));game.close_observatory();await settle()
	cosmos.set_black_hole(false)
	await click_at(sky_point(cosmos.CENTER));cosmos.advance(1.)
	check(cosmos.observatory_active and cosmos.primary_close and not cosmos.space_environment.glow_enabled,"sun preference also supports direct observation")
	await snapshot("sun");game.close_observatory()
	check(JSON.stringify(game.learning.data)==history,"observing and returning never changes learning or construction records")
	print("OBSERVATORY_UI_RESULT ",passed," passed / ",failed," failed")
	game.closing=true;game.ambience.shutdown();game.speech.stop();game.speech.stream=null;game.queue_free();await process_frame;await process_frame
	quit(0 if failed==0 else 1)
