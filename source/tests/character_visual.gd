extends SceneTree

# Internal visual QA only. The runtime skeleton, cargo and support calculations
# stay intact; the test hides scenery and substitutes a neutral ground material.
const Motion=preload("res://scripts/character_motion.gd")
var game
var world
var worker
var directory=""
var character="deepseek"
var movie=false
var quick_tools=false
var manifest=[]

func _initialize():call_deferred("run")

func run():
	var args=OS.get_cmdline_user_args()
	if not "--qa" in args:
		push_error("QA_REQUIRED");quit(2);return
	for arg in args:
		if arg.begins_with("--visual-out="):directory=arg.trim_prefix("--visual-out=")
		if arg.begins_with("--character="):character=arg.trim_prefix("--character=")
		if arg=="--record-motion":movie=true
		if arg=="--quick-tools":quick_tools=true
	if directory.is_empty() or DisplayServer.get_name()=="headless":
		push_error("VISUAL_RENDERER_REQUIRED");quit(2);return
	DirAccess.make_dir_recursive_absolute(directory)
	game=load("res://main.tscn").instantiate();root.add_child(game)
	await create_timer(.8).timeout
	game.ambience.shutdown();game.speech.stop();game.speech.stream=null
	if not game.apply_fixed_character(character,false):
		push_error("CHARACTER_UNAVAILABLE "+character);await finish(3);return
	world=game.world;worker=world.worker
	game.process_mode=Node.PROCESS_MODE_DISABLED
	for tween in get_processed_tweens():tween.kill()
	game.hud.hide();game.cosmos.hide();game.cosmos.canvas.hide()
	game.cosmos.viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	for child in world.get_children():
		if child is Node3D and child!=world.globe:child.hide()
	for child in world.globe.get_children():
		if child!=world.builder and child is Node3D:child.hide()
	world.globe.quaternion=Quaternion.IDENTITY;world.place(world.builder,Vector2.ZERO)
	worker.work_left=0;worker.waking=0;worker.visit_target=Vector2.INF
	world.motion_speed=0;world.transporting=false
	root.size=Vector2i(720,900);root.content_scale_size=Vector2i(720,900)
	for child in world.get_children():
		if child is WorldEnvironment:
			var env=child.environment
			env.background_mode=Environment.BG_COLOR;env.background_color=Color("172435")
			env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
			env.ambient_light_color=Color("C7D5E6");env.ambient_light_energy=.48
	var sun=DirectionalLight3D.new();world.add_child(sun)
	sun.rotation_degrees=Vector3(-42,-38,0);sun.light_color=Color("FFF3E4")
	sun.light_energy=1.1;sun.shadow_enabled=true;sun.directional_shadow_max_distance=12
	sun.shadow_bias=.003;sun.shadow_normal_bias=.025;sun.shadow_blur=1.1
	var fill=DirectionalLight3D.new();world.add_child(fill)
	fill.rotation_degrees=Vector3(-20,135,0);fill.light_energy=.3;fill.light_color=Color("BCD5FF")
	neutral_ground()
	var specifications=get_specifications()
	for spec in specifications:
		reset_pose()
		var resting=spec[0] in ["sit-look","cheek-rub","stretch","doze"]
		for i in range(300 if resting else 120):
			# Let rest time cross the runtime support-cache threshold naturally.
			# Jumping directly to a settled time would cache the initial upright pose.
			var pose_time=minf(spec[1],float(i+1)/60.0) if resting else spec[1]
			sample(spec[0],pose_time,1.0/60.0)
			if i%30==29:await process_frame
		set_camera(spec[0],false)
		await capture(spec[0])
		if spec[0] in ["carry","putdown","sit-look","axe-raised","pick-raised","hammer-raised"] or str(spec[0]).begins_with("candidate") :
			set_camera(spec[0],true);await capture(spec[0]+"-side")
		if spec[0] in ["carry","axe-raised"] or str(spec[0]).begins_with("candidate"):
			set_camera(spec[0],true,true);await capture(spec[0]+"-other-side")
	if movie:
		await record_motion()
		await record_wake()
	var out=FileAccess.open(directory.path_join("manifest.json"),FileAccess.WRITE)
	out.store_string(JSON.stringify({"character":character,"renderer":RenderingServer.get_video_adapter_name(),"images":manifest,"qa":game.qa,"support":"Runtime ground_faces retained; neutral ground uses those same triangles.","pose":"Runtime worker.apply_frame / worker.update, including skeleton and expressions."},"\t"));out.close()
	print("CHARACTER_VISUAL_RESULT ",character," ",manifest.size()," images")
	await finish(0)

func neutral_ground():
	var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for faces in world.ground_faces.values():
		for face in faces:
			for point in face:surface.add_vertex(point)
	surface.generate_normals()
	var mesh=MeshInstance3D.new();mesh.mesh=surface.commit()
	var material=StandardMaterial3D.new();material.albedo_color=Color("566A79");material.roughness=.88
	material.cull_mode=BaseMaterial3D.CULL_DISABLED;mesh.material_override=material
	world.globe.add_child(mesh)

func reset_pose():
	worker.work_left=0;worker.phase=0;worker.phase_time=0;worker.waking=0
	worker.rest_ground_offset=0;worker.rest_ground_ready=false
	worker.rest_ground_variant=-1;worker.rest_time=0;worker.rest_variant=0
	worker.expression={"effort":0.0,"focus":0.0,"relax":0.0,"sleep":0.0,"look":Vector2.ZERO}
	world.actor.rotation=Vector3.ZERO;world.actor.position.y=0
	for limb in world.limbs.values():limb.rotation=Vector3.ZERO
	if is_instance_valid(world.avatar):world.avatar.rest_cached=false
	worker.carry.hide();worker.carry.position=Vector3.ZERO;world.set_tool(-1)

func sample(action:String,t:float,dt:float):
	world.time+=dt
	if action in ["sit-look","cheek-rub","stretch","doze"]:
		worker.work_left=0;worker.rest_variant={"sit-look":0,"doze":1,"stretch":2,"cheek-rub":3}[action]
		worker.rest_time=maxf(0,t-dt);worker.update(dt);return
	worker.work_left=12;worker.rest_time=0;worker.waking=0
	var walking=action in ["walk","run","carry"]
	world.motion_speed=({"walk":IslandWorker.WALK_SPEED,"run":IslandWorker.RUN_SPEED,"carry":IslandWorker.CARRY_SPEED}.get(action,0.0))*worker.gait_ratio()
	var frame:Dictionary
	var striking=action.begins_with("axe-") or action.begins_with("pick-") or action.begins_with("hammer-")
	var tool_action=0 if action.begins_with("axe-") else 1 if action.begins_with("pick-") else 2
	world.set_tool(tool_action if striking else -1)
	worker.carry.hide()
	if action in ["walk","run"]:
		frame=Motion.locomotion(t,1.0 if action=="run" else 0.0,1.0,IslandWorker.SIZE_RATIO)
	elif striking:
		frame=worker.strike_pose(t,tool_action);frame.elasticity=worker.impact_elasticity(t)
	else:
		frame=Motion.locomotion(t,0.0,1.0,IslandWorker.SIZE_RATIO,true) if walking else {"pose":{}}
		var holding=Motion.carrying(.35 if walking else t,walking,t,IslandWorker.SIZE_RATIO)
		frame.pose.merge(holding.pose,true)
		for key in holding:
			if key!="pose":frame[key]=holding[key]
		worker.cargo[0].show();worker.cargo[1].hide()
		worker.carry.visible=float(holding.load)>.08
		if not is_instance_valid(world.avatar):worker.carry.position=Vector3(0,-.24*(1.0-float(holding.load)),0)
	worker.gait_phase=t;worker.gait_amount=1.0 if walking else 0.0
	worker.apply_frame(frame,dt,walking,true,false)

func set_camera(action:String,side:bool,other_side:bool=false):
	var resting=action in ["sit-look","cheek-rub","stretch","doze"]
	var yaw=PI if resting and (action!="doze" or is_instance_valid(world.avatar)) else 0.0
	var basis=world.builder.global_basis*Basis(Vector3.UP,yaw)
	var target=world.builder.global_position+world.builder.global_basis.y*(.48 if resting and action!="stretch" else .64)
	game.camera.projection=Camera3D.PROJECTION_ORTHOGONAL;game.camera.keep_aspect=Camera3D.KEEP_HEIGHT
	game.camera.size=1.95 if action in ["stretch","axe-raised","pick-raised","hammer-raised"] else 1.75
	var side_x=-4.0 if other_side else 4.0
	game.camera.global_position=target+basis*Vector3(side_x,1.25,-.8) if side else target+basis*Vector3(2.2,1.15,-4.2)
	game.camera.look_at(target,world.builder.global_basis.y);game.camera.current=true

func capture(name:String):
	await process_frame;await RenderingServer.frame_post_draw
	var path=directory.path_join(name+".png")
	var result=root.get_texture().get_image().save_png(path)
	if result!=OK:push_error("IMAGE_WRITE_FAILED "+path)
	manifest.append({"name":name,"path":path,"actor_y":world.actor.position.y,"ground_gap":ground_gap(),"expression":worker.expression.duplicate(),"geometry":geometry_snapshot()})
	print("CHARACTER_IMAGE ",path)

func vector_json(value:Vector3)->Array:return [value.x,value.y,value.z]

func geometry_snapshot()->Dictionary:
	var result={"coordinates":"world global and builder local","builder_global":vector_json(world.builder.global_position),"limbs":{},"axe_meshes":[]}
	for name in ["ArmR","ElbowR","Body"]:
		result.limbs[name]={"global":vector_json(world.limbs[name].global_position),"builder_local":vector_json(world.builder.to_local(world.limbs[name].global_position))}
	if is_instance_valid(world.avatar):
		for side in ["left","right"]:
			var hand=world.avatar.hand_point(side)
			result[side+"_hand"]={"global":vector_json(hand),"builder_local":vector_json(world.builder.to_local(hand))}
		var head=world.avatar.skeleton.to_global(world.avatar.poses[world.avatar.humanoid.head].origin)
		result.head={"global":vector_json(head),"builder_local":vector_json(world.builder.to_local(head))}
	var tool=world.tools.Axe
	var cargo_center=worker.carry.to_global(Vector3(0,.34,-.42))
	result.carry={"visible":worker.carry.visible,"center_global":vector_json(cargo_center),"center_builder":vector_json(world.builder.to_local(cargo_center))}
	result.axe={"global":vector_json(tool.global_position),"builder_local":vector_json(world.builder.to_local(tool.global_position)),"global_basis":[vector_json(tool.global_basis.x),vector_json(tool.global_basis.y),vector_json(tool.global_basis.z)]}
	var meshes=tool.find_children("*","MeshInstance3D",true,false)
	if tool is MeshInstance3D:meshes.append(tool)
	for mesh in meshes:
		var minimum=Vector3.INF;var maximum=-Vector3.INF;var local_min=Vector3.INF;var local_max=-Vector3.INF
		for i in range(8):
			var p=mesh.to_global(mesh.get_aabb().get_endpoint(i));var local=world.builder.to_local(p)
			minimum=minimum.min(p);maximum=maximum.max(p);local_min=local_min.min(local);local_max=local_max.max(local)
		result.axe_meshes.append({"name":str(mesh.name),"global_min":vector_json(minimum),"global_max":vector_json(maximum),"builder_min":vector_json(local_min),"builder_max":vector_json(local_max)})
	return result

func ground_gap()->float:
	var lowest=INF
	if is_instance_valid(world.avatar):
		for probe in world.avatar.support_probes:
			var p=world.globe.to_local(world.avatar.probe_point(probe))
			lowest=minf(lowest,(p-world.ground_point(world.terrain.coordinates(p))).dot(world.builder.basis.y))
		return lowest
	var mesh=world.actor.find_child("ContinuousBody",true,false)
	var skeleton=worker.skeleton;skeleton.force_update_all_bone_transforms()
	var arrays=mesh.mesh.surface_get_arrays(0);var binds=[]
	for i in mesh.skin.get_bind_count():
		binds.append(skeleton.get_bone_global_pose(skeleton.find_bone(mesh.skin.get_bind_name(i)))*mesh.skin.get_bind_pose(i))
	for i in arrays[Mesh.ARRAY_VERTEX].size():
		var point=Vector3.ZERO
		for j in range(4):point+=(binds[arrays[Mesh.ARRAY_BONES][i*4+j]]*arrays[Mesh.ARRAY_VERTEX][i])*arrays[Mesh.ARRAY_WEIGHTS][i*4+j]
		var p=world.globe.to_local(skeleton.to_global(point))
		lowest=minf(lowest,(p-world.ground_point(world.terrain.coordinates(p))).dot(world.builder.basis.y))
	return lowest

func record_motion():
	var frames=directory.path_join("carry-sequence");DirAccess.make_dir_recursive_absolute(frames)
	reset_pose();set_camera("carry",false)
	for i in range(180):
		var t=float(i)/60.0
		var action="pickup" if t<.35 else "carry" if t<2.35 else "putdown"
		var phase=t if t<.35 else (t-.35)*4.0 if t<2.35 else .35+t-2.35
		sample(action,phase,1.0/60.0)
		await process_frame;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(frames.path_join("frame-%04d.png"%i))
	print("CHARACTER_SEQUENCE ",frames)

func record_wake():
	var frames=directory.path_join("wake-sequence");DirAccess.make_dir_recursive_absolute(frames)
	reset_pose()
	for i in range(120):sample("sit-look",minf(1.4,float(i+1)/60.0),1.0/60.0)
	set_camera("sit-look",true)
	for i in range(150):
		if i==45:worker.begin_wake()
		if i<45:sample("sit-look",1.4+float(i)/60.0,1.0/60.0)
		elif worker.waking>0:
			world.time+=1.0/60.0
			worker.waking=maxf(0,worker.waking-1.0/60.0)
			worker.apply_frame(worker.waking_frame(),1.0/60.0,false,false,false)
			if worker.wake_grounded and not is_instance_valid(world.avatar):worker.settle_rest_support(false)
		else:
			worker.work_left=12
			worker.apply_frame({"pose":{},"relax":.2},1.0/60.0,false,true,false)
		await process_frame;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(frames.path_join("frame-%04d.png"%i))
	print("CHARACTER_SEQUENCE ",frames)

func finish(code:int):
	game.closing=true;game.ambience.shutdown();game.speech.stop();game.speech.stream=null
	await create_timer(.10).timeout
	game.queue_free();await process_frame;await process_frame;quit(code)

func get_specifications()->Array:
	var specifications=[
		["walk",.80],["run",1.0],["pickup",.14],["carry",.80],["putdown",.73],
		["axe-raised",.48],["axe-impact",.64],["pick-raised",.48],["pick-impact",.64],
		["hammer-raised",.48],["hammer-impact",.64],["sit-look",1.4],
		["cheek-rub",3.05],["stretch",1.75],["doze",4.0]]
	if quick_tools:specifications=[["carry",.80],["axe-raised",.48]]
	if "--quick-carry" in OS.get_cmdline_user_args():specifications=[["pickup",.14],["carry",.80],["putdown",.73]]
	return specifications
