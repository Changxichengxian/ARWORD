extends SceneTree
var game
var failures=0
func _initialize():call_deferred("run")
func check(ok:bool,label:String):
	if ok:print("PASS ",label)
	else:failures+=1;push_error("FAIL "+label)
func run():
	game=load("res://main.tscn").instantiate();root.add_child(game)
	var deadline=Time.get_ticks_msec()+30000
	while not game.scene_ready and Time.get_ticks_msec()<deadline:await process_frame
	check(game.scene_ready and game.startup.camera_running,"world accepts touch before the opening camera finishes")
	if not game.scene_ready:quit(1);return
	var point=Vector2(root.size.x*.55,root.size.y*.65)
	var press=InputEventScreenTouch.new();press.index=0;press.position=point;press.pressed=true;root.push_input(press,true)
	var before=game.world.globe.quaternion;var zoom=game.camera.size
	for i in 24:
		var drag=InputEventScreenDrag.new();drag.index=0;drag.position=point+Vector2(4,-1);drag.relative=Vector2(4,-1);point=drag.position;root.push_input(drag,true)
		await process_frame
	check(game.startup.marks.has("camera_interrupted") and not game.startup.camera_running,"touch drag takes over the opening camera immediately")
	check(is_equal_approx(zoom,game.camera.size),"taking over keeps the current zoom without a snap")
	check(before.angle_to(game.world.globe.quaternion)>.10,"planet follows the gesture during the opening")
	check(not game.startup.marks.has("person_start") and not game.startup.marks.has("phase_wildlife"),"character and animal preparation wait for the held gesture")
	var release=InputEventScreenTouch.new();release.index=0;release.position=point;release.pressed=false;root.push_input(release,true)
	while not game.startup.marks.has("animals_ready") and Time.get_ticks_msec()<deadline:await process_frame
	check(game.startup.marks.has("animals_ready"),"remaining startup resumes after release")
	print("STARTUP_INTERACTION_RESULT ",failures," failed")
	await game.request_exit()
	if failures:quit(1)
