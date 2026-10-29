extends SceneTree
var passed=0
var failed=0
func check(value:bool,label:String):
	if value:passed+=1;print("PASS ",label)
	else:failed+=1;push_error("FAIL "+label)
func _initialize():call_deferred("run")
func apply_pose(world,frame:Dictionary):
	for name in world.limbs:world.limbs[name].rotation=frame.pose.get(name,Vector3.ZERO)
	world.actor.rotation=frame.rotation;world.actor.position.y=frame.lift
	for tool in world.tools.values():tool.rotation.x=frame.get("wrist",0.0)
	world.worker.plant_feet(frame.get("ground",.015))
func run():
	var game=load("res://main.tscn").instantiate();root.add_child(game)
	await create_timer(.8).timeout
	var world=game.world;var worker=world.worker
	world.set_process(false)
	if world.move_tween and world.move_tween.is_valid():world.move_tween.kill()
	apply_pose(world,{"pose":{},"rotation":Vector3.ZERO,"lift":0.0})
	check(abs(world.actor.to_local(world.limbs.ArmR.global_position).y-1.12)<.001,"moving the torso pivot preserves the shoulder rest position")
	var grip=world.tools.Axe.get_parent()
	var rest=world.actor.to_local(grip.global_position)
	apply_pose(world,worker.strike_pose(.48,0));var raised=world.actor.to_local(grip.global_position)
	apply_pose(world,worker.strike_pose(.64,0));var impact=world.actor.to_local(grip.global_position)
	check(raised.y>rest.y+.4 and raised.z<rest.z,"the axe actually rises in front of the body during preparation")
	check(impact.z<-.25 and raised.y>impact.y+.25,"the downstroke lands forward instead of throwing the hand behind the character")
	check(world.limbs.Body.rotation.x>.2 and world.limbs.KneeL.rotation.x<-.2,"a committed strike engages the torso and knees")
	check(abs(worker.feet_height()-.015)<.002,"the supporting foot stays planted during a committed strike")
	var slow=worker.locomotion_pose(.25,1.05);var fast=worker.locomotion_pose(.25,1.8)
	check(fast.pose.ElbowR.x>slow.pose.ElbowR.x+.4 and fast.pose.Body.x>slow.pose.Body.x,"running has bent elbows and a distinct forward body lean")
	var travelled=worker.locomotion_pose(.25,1.05);var later=worker.locomotion_pose(.25,1.05)
	check(travelled.pose==later.pose,"feet use distance travelled rather than wall-clock time")
	var sample=worker.locomotion_pose(.15,1.05)
	check(sample.pose.LegL.x*sample.pose.LegR.x<0 and (sample.pose.ArmL.x-.12)*(sample.pose.LegL.x)<0,"opposite legs and opposite arms share a coordinated stride")
	worker.work_left=10;worker.waking=0;worker.kind=1;worker.phase=1;worker.update(.016)
	check(worker.carry.visible and worker.cargo[1].visible and not worker.cargo[0].visible,"stone work carries stone instead of wooden logs")
	var before=JSON.stringify(game.learning.data);worker.work_left=.01;worker.update(.05)
	check(worker.work_left==0 and not worker.carry.visible and JSON.stringify(game.learning.data)==before,"finishing the animation returns to rest without granting progress")
	print("WORKER_MOTION_RESULT ",passed," passed / ",failed," failed")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--visual-out="):await visual(game,arg.trim_prefix("--visual-out="))
	game.closing=true;game.ambience.shutdown();game.speech.stop();game.speech.stream=null;await create_timer(.10).timeout
	game.queue_free();await process_frame;await process_frame
	quit(0 if failed==0 else 1)

func visual(game,directory:String):
	DirAccess.make_dir_recursive_absolute(directory)
	var world=game.world;var worker=world.worker
	if world.move_tween and world.move_tween.is_valid():world.move_tween.kill()
	game.hud.hide()
	for child in world.globe.get_children():
		if child!=world.builder and child is Node3D:child.hide()
	world.globe.quaternion=Quaternion.IDENTITY;world.place(world.builder,Vector2.ZERO)
	var ground=MeshInstance3D.new();var shape=CylinderMesh.new();shape.top_radius=1.8;shape.bottom_radius=1.9;shape.height=.12;shape.radial_segments=6;ground.mesh=shape;ground.material_override=world.mat("82B569");world.builder.add_child(ground);ground.position.y=-.08
	game.camera.size=2.65;game.camera.position=world.builder.global_position+Vector3(2.6,2.9,-4.3);game.camera.look_at(world.builder.global_position+Vector3(0,.75,0))
	worker.carry.hide();world.set_tool(-1)
	for entry in [["walk",worker.locomotion_pose(.16,1.1)],["run",worker.locomotion_pose(.22,1.8)],["axe-raised",worker.strike_pose(.48,0)],["axe-impact",worker.strike_pose(.64,0)],["pick-impact",worker.strike_pose(.64,1)]]:
		world.set_tool(0 if str(entry[0]).begins_with("axe") else 1 if str(entry[0]).begins_with("pick") else -1);apply_pose(world,entry[1])
		await create_timer(.15).timeout;await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(directory.path_join(str(entry[0])+".png"))
	worker.work_left=0;worker.waking=0;worker.rest_variant=0;worker.rest_time=0;worker.update(1.0)
	await create_timer(.15).timeout;await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(directory.path_join("sitting.png"))
	worker.rest_variant=1;worker.rest_time=0;worker.update(1.0)
	await create_timer(.15).timeout;await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(directory.path_join("lying.png"))
