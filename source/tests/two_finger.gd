extends SceneTree

var game
var failures=0
var checks=0

func _initialize():
	if not "--qa" in OS.get_cmdline_user_args():
		quit(2)
		return
	call_deferred("run")

func check(ok:bool,label:String):
	checks+=1
	if not ok:failures+=1
	print("PASS " if ok else "FAIL ",label)

func touch(id:int,pos:Vector2,pressed:bool,canceled=false):
	var e=InputEventScreenTouch.new()
	e.index=id;e.position=pos;e.pressed=pressed;e.canceled=canceled
	Input.parse_input_event(e)
	await process_frame
	await process_frame

func move(id:int,old:Vector2,pos:Vector2):
	var e=InputEventScreenDrag.new()
	e.index=id;e.position=pos;e.relative=pos-old
	Input.parse_input_event(e)
	await process_frame
	await process_frame

func run():
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	root.size=Vector2i(540,960)
	DisplayServer.window_set_size(Vector2i(540,960))
	await create_timer(.3).timeout
	game.explore(true,false)
	game.frame_view(Vector3.ZERO,24,false)
	var center=game.camera.unproject_position(game.world.globe.global_position)
	var before:Quaternion=game.world.desired_rotation
	var a=center-Vector2(64,0);var b=center+Vector2(64,0)
	await touch(3,a,true);await touch(7,b,true)
	print("PAIR_START center=",center," viewport=",root.get_visible_rect()," active=",game.touch_points," zoom=",game.camera.size)
	var a2=center-Vector2(0,80);var b2=center+Vector2(0,80)
	await move(3,a,a2);await move(7,b,b2)
	var spun:Vector3=game.world.desired_rotation*(before.inverse()*game.camera.global_basis.x)
	check(spun.dot(-game.camera.global_basis.y)>.998,"clockwise quarter turn follows both fingers on screen")
	check(absf(game.camera.size-19.2)<.05,"a single two-finger motion also zooms by its measured span")
	await move(7,b2,b);await move(3,a2,a)
	check(game.world.desired_rotation.angle_to(before)<.005 and absf(game.camera.size-24)<.05,"opposite turn returns exactly without accumulating drift")
	await touch(7,b,false)
	var q:Quaternion=game.world.desired_rotation
	await move(3,a,a+Vector2(12,0))
	check(q.angle_to(game.world.desired_rotation)>.03 and q.angle_to(game.world.desired_rotation)<.09,"one remaining finger continues at the ordinary drag speed")
	await touch(3,a+Vector2(12,0),false)
	check(game.touch_points.is_empty() and game.exploring and not game.hud.overlay.visible,"ending a twist does not tap a site or learning card")
	var off=center+Vector2(48,-25);a=off-Vector2(45,0);b=off+Vector2(45,0)
	await touch(9,a,true);await touch(2,b,true)
	var anchor=game.pair_frame.z;before=game.world.desired_rotation
	var next_center=off+Vector2(12,8)
	var v=Vector2(45,0).rotated(.65)*1.2
	await move(2,b,next_center+v);await move(9,a,next_center-v)
	var surface:Vector3=game.world.desired_rotation*(before.inverse()*anchor)*IslandGrove.RADIUS
	check(game.camera.unproject_position(game.world.globe.global_position+surface).distance_to(next_center)<1,"the off-centre patch of ground stays between the fingers during turn, spread and travel")
	await touch(9,next_center-v,false,true);await touch(2,next_center+v,false,true)
	check(game.touch_points.is_empty(),"cancelling both touches clears their baselines")
	await touch(0,a,true);await touch(1,b,true);game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(game.touch_points.is_empty() and game.drag_id==-1 and game.pair_span==0.0,"losing focus cancels a pending multi-touch gesture")
	game.frontier.finish_for_development(true);game.world.sync_buildings(false);game.open_observatory()
	a=Vector2(160,400);b=Vector2(280,400);off=(a+b)*.5
	await touch(4,a,true);await touch(8,b,true)
	await move(4,a,off-Vector2(0,72));await move(8,b,off+Vector2(0,72))
	check(absf(game.cosmos.observation_roll-PI/2)<.01 and game.cosmos.observation_zoom<1,"the observatory accepts a combined twist and pinch")
	await touch(4,off-Vector2(0,72),false);await touch(8,off+Vector2(0,72),false)
	game.close_observatory()
	print("TWO_FINGER_RESULT ",checks," checks / ",failures," failed")
	game.closing=true;game.ambience.shutdown();game.queue_free();await process_frame;await process_frame
	quit.call_deferred(0 if failures==0 else 1)
