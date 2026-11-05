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
	world.worker.plant_feet(frame.get("ground",IslandWorker.GROUND_GAP))
	world.worker.update_skin()
func skin_bottom(world,actual_ground=false)->float:
	var mesh=world.actor.find_child("ContinuousBody",true,false)
	var skeleton=world.worker.skeleton;skeleton.force_update_all_bone_transforms()
	var arrays=mesh.mesh.surface_get_arrays(0);var lowest=INF;var bind=[]
	for i in mesh.skin.get_bind_count():
		var bone=skeleton.find_bone(mesh.skin.get_bind_name(i))
		bind.append(skeleton.get_bone_global_pose(bone)*mesh.skin.get_bind_pose(i))
	for i in arrays[Mesh.ARRAY_VERTEX].size():
		var point=Vector3.ZERO
		for j in range(4):
			point+=(bind[arrays[Mesh.ARRAY_BONES][i*4+j]]*arrays[Mesh.ARRAY_VERTEX][i])*arrays[Mesh.ARRAY_WEIGHTS][i*4+j]
		if actual_ground:
			var p=world.globe.to_local(skeleton.to_global(point));lowest=minf(lowest,p.length()-world.ground_point(world.terrain.coordinates(p)).length())
		else:lowest=minf(lowest,world.builder.to_local(skeleton.to_global(point)).y)
	return lowest
func run():
	var game=load("res://main.tscn").instantiate();root.add_child(game)
	await create_timer(.8).timeout
	var world=game.world;var worker=world.worker
	world.set_process(false)
	if world.move_tween and world.move_tween.is_valid():world.move_tween.kill()
	apply_pose(world,{"pose":{},"rotation":Vector3.ZERO,"lift":0.0})
	check(abs(world.actor.to_local(world.limbs.ArmR.global_position).y-1.24)<.001,"the new waist pivot preserves the authored shoulder rest position")
	var grip=world.tools.Axe.get_parent()
	var rest=world.actor.to_local(grip.global_position)
	apply_pose(world,worker.strike_pose(.48,0));var raised=world.actor.to_local(grip.global_position)
	apply_pose(world,worker.strike_pose(.64,0));var impact=world.actor.to_local(grip.global_position)
	check(raised.y>rest.y+.4 and raised.z<rest.z,"the axe actually rises in front of the body during preparation")
	check(impact.z<-.25 and raised.y>impact.y+.25,"the downstroke lands forward instead of throwing the hand behind the character")
	var waist=world.actor.to_local(world.limbs.Body.global_position)
	var upper=world.actor.to_local(world.limbs.Body.to_global(Vector3.UP))
	check(upper.z<waist.z-.18 and world.limbs.KneeL.rotation.x<-.2,"a committed strike leans the torso toward the work in front and bends the knees")
	check(abs(worker.feet_height()-IslandWorker.GROUND_GAP)<.002,"the supporting foot stays planted during a committed strike")
	var actual_bottom=skin_bottom(world);print("ACTUAL_SKIN_BOTTOM ",actual_bottom)
	check(actual_bottom>-.03 and actual_bottom<.09,"the visible skinned foot agrees with its ground contact probe")
	var skin=world.actor.find_child("ContinuousBody",true,false);var material=skin.get_active_material(0)
	var physical_height=skin.get_aabb().size.y*IslandWorker.ACTOR_SCALE
	print("ACTUAL_CHARACTER_HEIGHT ",physical_height)
	check(physical_height>1.03 and physical_height<1.12,"the whole white character is about two thirds of the previous tree-sized height")
	check(absf(world.tools.Axe.global_basis.get_scale().x/world.actor.global_basis.get_scale().x-1.0)<.001 and worker.carry.get_parent()==world.limbs.Body,"tools and carried material inherit the same body scale")
	check(material.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED and material.roughness>.35 and material.roughness<.5 and material.vertex_color_use_as_albedo,"the soft highlights and subtle vertex colors stay fully opaque")
	var head_width=0.0
	for vertex in skin.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		if vertex.y>1.30:head_width=maxf(head_width,absf(vertex.x)*2)
	print("ACTUAL_HEAD_WIDTH ",head_width)
	check(head_width<.44 and head_width>.40,"the small head keeps a clear silhouette above the longer limbs")
	var support_ok=true;var smallest=1.0;var biggest=1.0
	worker.work_left=8;worker.phase=2;worker.waking=0;worker.stroke_time=1.35*.60;worker.phase_time=0
	for frame in range(32):
		worker.update(.016);smallest=minf(smallest,world.actor.scale.y/IslandWorker.ACTOR_SCALE);biggest=maxf(biggest,world.actor.scale.y/IslandWorker.ACTOR_SCALE)
		support_ok=support_ok and abs(worker.feet_height()-IslandWorker.GROUND_GAP)<.003
	check(smallest>.94 and smallest<.985 and biggest>1.005 and support_ok,"one impact compresses and rebounds gently while the support foot stays grounded")
	check(worker.head_pivot!=null and worker.head_pivot.rotation.length()>.01 and worker.head_pivot.rotation.length()<.15,"the head follows the working torso with a restrained independent reaction")
	world.actor.scale=Vector3.ONE*IslandWorker.ACTOR_SCALE
	var slow=worker.locomotion_pose(.25,IslandWorker.WALK_SPEED);var fast=worker.locomotion_pose(.25,IslandWorker.RUN_SPEED)
	check(fast.pose.ElbowR.x>slow.pose.ElbowR.x+.4 and (Basis.from_euler(fast.pose.Body)*Vector3.UP).z<(Basis.from_euler(slow.pose.Body)*Vector3.UP).z-.08,"running has bent elbows and a stronger lean toward the facing direction")
	var travelled=worker.locomotion_pose(.25,IslandWorker.WALK_SPEED);var later=worker.locomotion_pose(.25,IslandWorker.WALK_SPEED)
	check(travelled.pose==later.pose,"feet use distance travelled rather than wall-clock time")
	var sample=worker.locomotion_pose(.15,IslandWorker.WALK_SPEED)
	check(sample.pose.LegL.x*sample.pose.LegR.x<0 and (sample.pose.ArmL.x-.12)*(sample.pose.LegL.x)<0,"opposite legs and opposite arms share a coordinated stride")
	worker.work_left=10;worker.waking=0;worker.kind=1;worker.phase=1;worker.update(.016)
	check(worker.carry.visible and worker.cargo[1].visible and not worker.cargo[0].visible,"stone work carries stone instead of wooden logs")
	check(worker.travel_speed()==IslandWorker.CARRY_SPEED and worker.stride_length(IslandWorker.CARRY_SPEED,true)<.9,"smaller loaded steps and slower transport share the movement scale")
	worker.destination=Vector2(2,1);worker.origin=Vector2.ZERO;worker.phase=1;worker.phase_time=.31;worker.stroke_time=.48;worker.work_left=8
	worker.grant("word",Vector2(2,1),{"p":Vector2(3,4)},1)
	check(worker.work_left==20 and worker.phase==1 and worker.phase_time==.31 and worker.stroke_time==.48,"a fast answer extends work without restarting the current carry or stroke")
	worker.phase=2;worker.next_phase()
	check(worker.origin==Vector2(3,4) and worker.phase==0 and worker.pending_work.is_empty(),"the newest source takes effect after the current construction cycle")
	if world.move_tween and world.move_tween.is_valid():world.move_tween.kill()
	var transport_budget=worker.work_left;var transport_phase=worker.phase;var transport_clock=worker.stroke_time
	worker.suspend_for_transport(true);worker.update(2.0)
	check(worker.work_left==transport_budget and worker.phase==transport_phase and worker.stroke_time==transport_clock and not worker.carry.visible and not world.tools.Axe.visible,"boat transport pauses both work seconds and working motion")
	var boat_destination=worker.destination;worker.grant("word",Vector2(8,9),{"p":Vector2(7,8)},0)
	check(worker.destination==boat_destination and worker.phase==transport_phase and worker.pending_work.target==Vector2(8,9),"changing the work site during a boat trip queues it without working at the old landing")
	worker.suspend_for_transport(false)
	var walking_budget=worker.work_left
	world.walk_to(world.safe_point(world.terrain.coordinates(world.builder.position)+Vector2(.6,0)));worker.update(.1)
	check(worker.work_left==walking_budget,"ordinary travel preserves the earned working seconds")
	if world.move_tween and world.move_tween.is_valid():world.move_tween.kill()
	worker.waking=.5;worker.update(.1)
	check(worker.work_left==walking_budget,"getting up preserves the earned working seconds")
	worker.waking=0
	var before=JSON.stringify(game.learning.data);worker.work_left=.01;worker.update(.05)
	check(worker.work_left==0 and not worker.carry.visible and JSON.stringify(game.learning.data)==before,"finishing the animation returns to rest without granting progress")
	if world.move_tween and world.move_tween.is_valid():world.move_tween.kill()
	worker.rest_variant=0;worker.rest_time=0;worker.update(1.0)
	var sitting_bottom=skin_bottom(world,true)
	worker.rest_variant=1;worker.rest_time=0;worker.update(1.0)
	var lying_bottom=skin_bottom(world,true)
	check(sitting_bottom>=-.01 and sitting_bottom<.05 and lying_bottom>=-.01 and lying_bottom<.05,"the actual seated and lying skin touches the ground without sinking")
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
	var fill=DirectionalLight3D.new();fill.light_energy=.55;world.add_child(fill);fill.rotation_degrees=Vector3(-35,145,0)
	worker.carry.hide();world.set_tool(-1)
	for entry in [["walk",worker.locomotion_pose(.16,IslandWorker.WALK_SPEED)],["run",worker.locomotion_pose(.22,IslandWorker.RUN_SPEED)],["axe-raised",worker.strike_pose(.48,0)],["axe-impact",worker.strike_pose(.64,0)],["pick-impact",worker.strike_pose(.64,1)]]:
		world.set_tool(0 if str(entry[0]).begins_with("axe") else 1 if str(entry[0]).begins_with("pick") else -1);apply_pose(world,entry[1])
		await create_timer(.15).timeout;await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(directory.path_join(str(entry[0])+".png"))
	worker.work_left=0;worker.waking=0;worker.rest_variant=0;worker.rest_time=0;worker.update(1.0)
	print("SITTING_SKIN_BOTTOM ",skin_bottom(world)," LIFT ",world.actor.position.y)
	await create_timer(.15).timeout;await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(directory.path_join("sitting.png"))
	worker.rest_variant=1;worker.rest_time=0;worker.update(1.0)
	print("LYING_SKIN_BOTTOM ",skin_bottom(world)," LIFT ",world.actor.position.y)
	await create_timer(.15).timeout;await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(directory.path_join("lying.png"))
	worker.work_left=8;worker.phase=2;worker.phase_time=0;worker.waking=0;worker.stroke_time=1.35*.60
	apply_pose(world,worker.strike_pose(.60,2))
	for frame in range(30):
		worker.update(.016)
		await RenderingServer.frame_post_draw
		if frame in [6,16,28]:root.get_texture().get_image().save_png(directory.path_join("elastic-"+str(frame)+".png"))
