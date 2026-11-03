extends SceneTree
var game
var passed=0
var failed=0
var output="../work/qa11/observatory-ui"
func _initialize():
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	DirAccess.make_dir_recursive_absolute(output);call_deferred("run")
func check(ok:bool,label:String):
	if ok:passed+=1;print("PASS ",label)
	else:failed+=1;push_error("FAIL "+label)
func settle():
	for i in range(3):await process_frame
func snapshot(name:String):
	await settle();await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(name+".png"))
func mouse_button(position:Vector2,pressed:bool,button=MOUSE_BUTTON_LEFT):
	var event=InputEventMouseButton.new();event.position=position;event.global_position=position;event.button_index=button;event.pressed=pressed;event.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed and button==MOUSE_BUTTON_LEFT else 0
	Input.parse_input_event(event);await settle()
func mouse_motion(position:Vector2,relative:Vector2,held=false):
	var event=InputEventMouseMotion.new();event.position=position;event.global_position=position;event.relative=relative;event.button_mask=MOUSE_BUTTON_MASK_LEFT if held else 0
	Input.parse_input_event(event);await settle()
func click(button):
	var p=button.get_global_rect().get_center();await mouse_motion(p,Vector2.ZERO);await mouse_button(p,true);await mouse_button(p,false)
func touch(index:int,position:Vector2,pressed:bool):
	var event=InputEventScreenTouch.new();event.index=index;event.position=position;event.pressed=pressed
	Input.parse_input_event(event);await settle()
func touch_drag(index:int,position:Vector2,relative:Vector2):
	var event=InputEventScreenDrag.new();event.index=index;event.position=position;event.relative=relative
	Input.parse_input_event(event);await settle()
func run():
	game=load("res://main.tscn").instantiate();root.add_child(game)
	DisplayServer.window_set_size(Vector2i(540,960));DisplayServer.window_set_position(Vector2i(DisplayServer.screen_get_usable_rect().end.x-100,60))
	await create_timer(.6).timeout
	game.open_observatory();check(not game.cosmos.observatory_active,"unfinished mountain keeps the observatory locked")
	game.frontier.finish_for_development(true);game.world.sync_buildings(false);game.select_site("mountain")
	await create_timer(.6).timeout
	var entrance
	for button in game.hud.card.find_children("*","BaseButton",true,false):
		if button.tooltip_text=="观测星云":entrance=button
	check(entrance!=null and entrance.is_visible_in_tree(),"completed mountain exposes its telescope button on the learning card")
	await snapshot("mountain-card")
	if entrance==null:game.closing=true;game.ambience.shutdown();quit(1);return
	var history=JSON.stringify(game.learning.data)
	await click(entrance);await create_timer(.8).timeout
	check(game.cosmos.observatory_active and game.cosmos.canvas.layer==4,"native card button enters the observatory")
	check(not game.hud.visible,"covered island controls cannot intercept observatory gestures")
	var buttons=game.observatory_layer.find_children("*","BaseButton",true,false)
	var fitting=buttons.size()==4
	for i in range(buttons.size()):
		var rect=buttons[i].get_global_rect()
		fitting=fitting and rect.position.x>=0 and rect.position.y>=0 and rect.end.x<=540 and rect.end.y<=100
		for j in range(i):fitting=fitting and not rect.intersects(buttons[j].get_global_rect())
	check(fitting,"return and three target buttons fit without overlap at 540 by 960")
	for index in range(3):
		await click(buttons[index+1]);await create_timer(.8).timeout
		check(game.cosmos.observation_index==index,"native target button selects volume "+str(index))
		await snapshot("target-"+str(index))
	var initial=game.cosmos.observation_yaw
	await mouse_button(Vector2(260,550),true);await mouse_motion(Vector2(290,560),Vector2(30,10),true)
	check(absf(game.cosmos.observation_yaw-initial)>.02,"mouse dragging rotates the actual observation camera")
	var button_point=buttons[2].get_global_rect().get_center()
	await mouse_motion(button_point,Vector2(0,-30),true);await mouse_button(button_point,false)
	var stopped=game.cosmos.observation_yaw;await mouse_motion(Vector2(300,600),Vector2(45,25))
	check(not game.observatory_drag and is_equal_approx(game.cosmos.observation_yaw,stopped),"releasing a drag on a target button ends capture without accidental switching")
	var old_zoom=game.cosmos.observation_zoom;await mouse_button(Vector2(250,550),true,MOUSE_BUTTON_WHEEL_UP)
	check(game.cosmos.observation_zoom<old_zoom,"desktop wheel zoom remains available")
	game.select_observation(0)
	await touch(0,Vector2(190,550),true);await touch(1,Vector2(350,550),true)
	var pinch_zoom=game.cosmos.observation_zoom;var pinch_yaw=game.cosmos.observation_yaw
	await touch_drag(1,Vector2(390,550),Vector2(40,0))
	check(game.cosmos.observation_zoom<pinch_zoom and is_equal_approx(game.cosmos.observation_yaw,pinch_yaw),"two native touches pinch to zoom without also rotating")
	await touch(1,button_point,false);var single_yaw=game.cosmos.observation_yaw
	await touch_drag(0,Vector2(215,550),Vector2(25,0))
	check(game.observatory_touch_points.size()==1 and absf(game.cosmos.observation_yaw-single_yaw)>.02,"lifting one finger over the toolbar resumes one-finger rotation")
	await touch(0,button_point,false);stopped=game.cosmos.observation_yaw
	await touch_drag(0,Vector2(260,600),Vector2(45,50))
	check(game.observatory_touch_points.is_empty() and game.observatory_touch==-1 and is_equal_approx(game.cosmos.observation_yaw,stopped),"final touch release over UI clears every observation gesture")
	var target=buttons[3].get_global_rect().get_center();await touch(0,target,true);await touch(0,target,false)
	check(game.cosmos.observation_index==2 and game.observatory_touch_points.is_empty(),"a fresh touchscreen tap still activates the target button")
	await touch(0,Vector2(230,540),true);game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(game.observatory_touch_points.is_empty() and not game.observatory_drag,"losing application focus cancels the observation gesture")
	await click(buttons[0]);await settle()
	check(not game.cosmos.observatory_active and game.cosmos.canvas.layer==-10 and game.hud.visible,"return button restores the island and its original controls")
	check(game.observatory_touch_points.is_empty() and not game.observatory_drag and JSON.stringify(game.learning.data)==history,"entering, observing and returning never changes saved learning progress")
	await snapshot("returned-to-planet")
	print("OBSERVATORY_UI_RESULT ",passed," passed / ",failed," failed")
	game.closing=true;game.ambience.shutdown();game.speech.stop();game.speech.stream=null;game.queue_free();await process_frame;await process_frame
	quit(0 if failed==0 else 1)
