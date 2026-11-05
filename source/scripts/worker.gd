extends RefCounted
class_name IslandWorker

# Keep one scale contract for visuals, footsteps, cargo, work reach and rest space.
const ACTOR_SCALE=.61
const SIZE_RATIO=ACTOR_SCALE/.9
const SPEED_RATIO=.75
const WALK_SPEED=1.1*SPEED_RATIO
const RUN_SPEED=1.8*SPEED_RATIO
const CARRY_SPEED=.95*SPEED_RATIO
const GROUND_GAP=.015*SIZE_RATIO
const REST_LENGTH=1.45*SIZE_RATIO
const REST_CLEARANCE=.38*SIZE_RATIO
const Motion=preload("res://scripts/character_motion.gd")
const PICKUP_TIME=.35
const CARRY_TIME=1.0

var world
var work_left=0.0
var phase=0
var phase_time=0.0
var rest_time=0.0
var rest_variant=0
var waking=0.0
var destination=Vector2.ZERO
var origin=Vector2.ZERO
var kind=0
var carry:Node3D
var hit_clock=0.0
var stroke_time=0.0
var last_impact=-1
var cargo:Array=[]
var feet:Array=[]
var skeleton:Skeleton3D
var skin_bindings:Array=[]
var head_pivot:Node3D
var seated_lift=-.39
var rest_support:Array=[]
var rest_support_binds:Array=[]
var rest_ground_offset=0.0
var rest_ground_ready=false
var rest_ground_variant=-1
var rest_ground_anchor=Vector3.INF
var rest_ground_land=0
var rest_ground_samples=0
var pending_work:Dictionary={}
var harvesting_cycle=true
var transport_suspended=false
var visit_target=Vector2.INF
var gait_phase=0.0
var gait_distance=0.0
var gait_amount=0.0
var carry_travel_started=false
var carry_walk_time=0.0
var wake_duration=.72
var wake_pose:Dictionary={}
var wake_rotation=Vector3.ZERO
var wake_lift=0.0
var wake_grounded=false
var expression={"effort":0.0,"focus":0.0,"relax":0.0,"sleep":0.0,"look":Vector2.ZERO}

func _init(owner_world):
	world=owner_world
	world.actor.scale=Vector3.ONE*ACTOR_SCALE
	# The model faces -Z. Positive shoulder X lifts the hand forward.
	# Put the upper body and shoulders on one waist pivot so a strike uses the torso.
	var torso=world.limbs.Body
	if absf(torso.position.y)<.01:
		for part in torso.get_children():
			if part is Node3D:part.position.y-=.66
		torso.position.y=.66
	for side in ["L","R"]:world.limbs["Arm"+side].reparent(torso,true)
	seated_lift=(-.39-(world.limbs.LegL.position.y-.62)*.9)*SIZE_RATIO
	head_pivot=world.actor.find_child("HeadPivot",true,false)
	feet=world.actor.find_children("Foot*","MeshInstance3D",true,false)
	for foot in feet:
		if str(foot.name).begins_with("FootProbe"):foot.hide()
	var skeletons=world.actor.find_children("*","Skeleton3D",true,false)
	if not skeletons.is_empty():
		skeleton=skeletons[0]
		for name in world.limbs:
			var bone=skeleton.find_bone("Skin"+name)
			if bone>=0:
				var driver=world.limbs[name]
				var correction=driver.global_basis.inverse()*skeleton.global_basis*skeleton.get_bone_global_rest(bone).basis
				skin_bindings.append({"bone":bone,"driver":driver,"correction":correction})
		if is_instance_valid(head_pivot):
			var head_bone=skeleton.find_bone("SkinHead")
			if head_bone>=0:
				var correction=head_pivot.global_basis.inverse()*skeleton.global_basis*skeleton.get_bone_global_rest(head_bone).basis
				skin_bindings.append({"bone":head_bone,"driver":head_pivot,"correction":correction})
		prepare_rest_support()
	carry=Node3D.new();torso.add_child(carry)
	for name in ["Wood","Stone"]:
		var group=Node3D.new();group.name=name;carry.add_child(group);cargo.append(group)
	for i in range(3):
		var log=world.model("timber",cargo[0]);log.position=Vector3(0,.24+i*.10,-.42);log.scale=Vector3.ONE*.65
	for i in range(2):
		var rock=world.model("ore",cargo[1]);rock.position=Vector3((i-.5)*.21,.18+i*.10,-.40);rock.scale=Vector3.ONE*.23
	carry.hide();world.set_tool(-1)
func rest_spot()->Vector2:
	var best=Vector2.ZERO;var score=INF
	var length=world.avatar.rest_length if is_instance_valid(world.avatar) else REST_LENGTH
	var current=world.terrain.coordinates(world.builder.position)
	var component=world.nav_components.get(world.navigation.get_closest_point(current),-1)
	for id in world.navigation.get_point_ids():
		var p=world.navigation.get_point_position(id);var d=p.distance_squared_to(current)
		if d<score and world.nav_components.get(id,-2)==component and world.clear_segment(p,p+Vector2(0,length),REST_CLEARANCE):score=d;best=p
	return best if is_finite(score) else world.safe_point(current,.45*SIZE_RATIO)
func settle():
	world.set_tool(-1);carry.hide();rest_time=0;rest_variant=0
	var spot=rest_spot();world.work_point=spot+Vector2(0,-SIZE_RATIO);world.walk_to(spot,.75)

func visit(target:Vector2):
	visit_target=target
	if transport_suspended:return
	var already_rising=waking>0
	var getting_up=work_left<=0 and not (world.move_tween and world.move_tween.is_running())
	pending_work.clear()
	configure_work({"target":target,"origin":target,"kind":kind,"harvest":false})
	if already_rising:pass
	elif getting_up:begin_wake()
	else:waking=0.0;world.walk_to(world.work_stance(2))
	rest_time=0

func begin_wake():
	wake_pose.clear()
	for name in world.limbs:wake_pose[name]=world.limbs[name].rotation
	wake_rotation=world.actor.rotation;wake_lift=world.actor.position.y
	wake_grounded=rest_variant in [0,1,3] and (wake_lift<-.08 or absf(wake_rotation.x)>.3)
	wake_duration=.92 if absf(wake_rotation.x)>.5 else .72 if wake_grounded else .30
	waking=wake_duration
	if world.move_tween and world.move_tween.is_valid():world.move_tween.kill()
	rest_ground_ready=false;rest_ground_offset=0.0

func waking_frame()->Dictionary:
	var progress=clampf(1.0-waking/wake_duration,0,1)
	var gather={"Body":Vector3(-.24,0,0),"LegL":Vector3(.88,0,-.025),"LegR":Vector3(.86,0,.025),"KneeL":Vector3(-.70,0,0),"KneeR":Vector3(-.66,0,0),"ArmL":Vector3(.45,0,.12),"ArmR":Vector3(.45,0,-.12),"ElbowL":Vector3(.38,0,0),"ElbowR":Vector3(.38,0,0)}
	var pose={};var first=smoothstep(0.0,.38,progress);var rise=smoothstep(.30,1.0,progress)
	for name in world.limbs:
		var start:Vector3=wake_pose.get(name,world.limbs[name].rotation)
		var collected:Vector3=gather.get(name,Vector3.ZERO) if wake_grounded else Vector3.ZERO
		pose[name]=start.lerp(collected,first).lerp(Vector3.ZERO,rise)
	var upright=Vector3(0,wake_rotation.y,0)
	var rotation=Quaternion.from_euler(wake_rotation).slerp(Quaternion.from_euler(upright),first).slerp(Quaternion.IDENTITY,rise).get_euler()
	return {"pose":pose,"rotation":rotation,"lift":lerpf(wake_lift,0.0,rise),"head":Vector3(-.12*(1-rise),0,0),"effort":.30*sin(progress*PI),"focus":.45,"look":Vector2(0,-.2*(1-rise))}

func travel_speed()->float:
	if visit_target.is_finite():return RUN_SPEED*gait_ratio()
	return ((CARRY_SPEED if phase==1 else RUN_SPEED) if work_left>0 else WALK_SPEED)*gait_ratio()

func gait_ratio()->float:
	return world.avatar.gait_ratio if is_instance_valid(world.avatar) else 1.0

func run_amount(speed:float,loaded=false)->float:
	return clampf((speed/(SPEED_RATIO*gait_ratio())-1.25)/.50,0,1) if not loaded else 0.0

func stride_length(speed:float,loaded=false)->float:
	return lerpf(1.22,1.65,run_amount(speed,loaded))*SIZE_RATIO*gait_ratio()*(.78 if loaded else 1.0)
func grant(mode:String,target:Vector2,entry:Dictionary,resource_kind:int):
	visit_target=Vector2.INF
	var was_resting=work_left<=0
	work_left=minf(36.0,work_left+(12.0 if mode=="word" else 9.0))
	var request={"target":target,"kind":resource_kind,"origin":entry.p if mode=="word" and not entry.is_empty() else target,"harvest":mode=="word" and not entry.is_empty()}
	if not was_resting and (transport_suspended or destination.distance_squared_to(target)<.0001):
		# Fast answers extend the current stroke/trip. The latest source is used after delivery.
		pending_work=request
		return
	pending_work.clear();configure_work(request)
	# A new target may arrive midway through getting up. Keep the captured
	# support transition and let its completion start the newest route once.
	if waking>0:return
	if was_resting:
		begin_wake()
	else:world.walk_to(world.work_stance(0),.7)
func configure_work(request:Dictionary):
	destination=request.target;kind=request.kind;origin=request.origin;harvesting_cycle=request.harvest
	phase=0 if harvesting_cycle else 2;phase_time=0;hit_clock=0;stroke_time=0;last_impact=-1
	carry_travel_started=false;carry_walk_time=0.0
	world.work_point=origin if harvesting_cycle else destination;world.current_tool=kind if harvesting_cycle else 2

func suspend_for_transport(suspended:bool):
	transport_suspended=suspended
	if suspended:world.set_tool(-1);carry.hide()
	elif visit_target.is_finite() and world.terrain.chart_at(visit_target)!=world.terrain.chart_at(world.terrain.coordinates(world.builder.position)):
		visit(visit_target)
	elif visit_target.is_finite():
		world.work_point=visit_target
		world.walk_to(world.work_stance(2))

func next_phase():
	if phase==2 and not pending_work.is_empty():
		var request=pending_work.duplicate();pending_work.clear();configure_work(request)
		world.walk_to(world.work_stance(2),.85)
		return
	if phase==2 and not harvesting_cycle:
		phase_time=0;hit_clock=0;stroke_time=0;last_impact=-1
		return
	phase=(phase+1)%3;phase_time=0;hit_clock=0;stroke_time=0;last_impact=-1
	if phase==1:
		world.work_point=destination;carry_travel_started=false;carry_walk_time=0.0
	elif phase==0:
		world.work_point=origin;world.walk_to(world.work_stance(2),.85)
func advance_gait(dt:float,walking:bool,loaded:bool):
	# Integrate only new travel. Changing speed must not reinterpret the whole route.
	var distance=world.travelled-gait_distance;gait_distance=world.travelled
	if distance>=0.0 and distance<2.0:
		gait_phase=fposmod(gait_phase+distance*TAU/stride_length(world.motion_speed,loaded),TAU)
	var amount=clampf(world.motion_speed/(WALK_SPEED*gait_ratio()),0,1) if walking else 0.0
	gait_amount=lerpf(gait_amount,amount,1-exp(-dt*14.0))

func moving_frame(loaded:bool)->Dictionary:
	return Motion.locomotion(gait_phase,run_amount(world.motion_speed,loaded),gait_amount,SIZE_RATIO,loaded)

func update_expression(frame:Dictionary,dt:float):
	for key in ["effort","focus","relax","sleep"]:
		var speed=4.0 if key=="sleep" else 9.0
		expression[key]=lerpf(expression[key],clampf(float(frame.get(key,0.0)),0,1),1-exp(-dt*speed))
	var gaze:Vector2=frame.get("look",Vector2.ZERO)
	expression.look=expression.look.lerp(gaze.clamp(Vector2(-1,-1),Vector2.ONE),1-exp(-dt*6.0))

func update(dt:float):
	if transport_suspended:
		# The boat owns travel; preserve the work budget and production phase.
		world.set_tool(-1);carry.hide();advance_gait(dt,world.ferry_walking,false)
		var frame=moving_frame(false) if world.ferry_walking else {"pose":{},"relax":.25}
		apply_frame(frame,dt,world.ferry_walking,false,false)
		return
	var working=work_left>0
	var walking=world.move_tween and world.move_tween.is_running()
	if visit_target.is_finite() and not walking and waking<=0:visit_target=Vector2.INF
	# Count stationary work only, including pickup and set-down within the same
	# original one-second carrying phase. Walking, waking and sailing are free.
	var work_dt=dt if working and not walking and waking<=0 else 0.0
	if phase==1:
		work_dt=minf(work_dt,maxf(0.0,(CARRY_TIME if carry_travel_started else PICKUP_TIME)-phase_time))
	if working and not walking and waking<=0:
		work_left=maxf(0,work_left-work_dt)
		if work_left<=0:settle();working=false
	if waking>0:
		waking=maxf(0,waking-dt)
		if waking<=0:world.walk_to(world.work_stance(0),.7)
	walking=world.move_tween and world.move_tween.is_running()
	if working and waking<=0:
		if not walking:
			phase_time+=work_dt
			if phase==1 and not carry_travel_started and phase_time>=PICKUP_TIME-.00001:
				phase_time=PICKUP_TIME;carry_travel_started=true
				world.walk_to(world.work_stance(1),.85)
			elif phase_time>=[4.5,CARRY_TIME,4.0][phase]:next_phase()
	elif not walking and waking<=0:
		rest_time+=dt
		if rest_time>[6.0,12.0,4.5,7.0][rest_variant]:rest_time=0;rest_variant=(rest_variant+1)%4
	walking=world.move_tween and world.move_tween.is_running()
	var loaded=working and phase==1 and waking<=0
	if loaded and walking and world.motion_speed>.05*gait_ratio():carry_walk_time+=dt
	advance_gait(dt,walking,loaded)
	cargo[0].visible=kind==0;cargo[1].visible=kind==1
	world.set_tool((kind if phase==0 else 2) if working and phase!=1 and waking<=0 else -1)
	var frame:Dictionary
	if waking>0:
		frame=waking_frame()
	elif walking:
		frame=moving_frame(loaded)
	elif working:
		if phase!=1:
			stroke_time+=dt
			var action=2 if phase==2 else kind
			var cycle=[1.65,1.9,1.35][action];var beat=fposmod(stroke_time,cycle)/cycle
			frame=strike_pose(beat,action);frame.elasticity=impact_elasticity(beat)
			var impact=int(floor(stroke_time/cycle))
			if beat>=.64 and impact!=last_impact:
				last_impact=impact
				if phase==2:
					var p=world.builder.position+(world.builder.basis.y*.55-world.builder.basis.z*.62)*SIZE_RATIO
					for i in range(2):
						var chip=world.pebble(world.globe,p,Vector3.ONE*.07*SIZE_RATIO,"E9C98B")
						world.effects.append({"node":chip,"a":p,"b":p+world.builder.basis.x*(i-.5)*.3*SIZE_RATIO,"t":0.0,"duration":.35})
		else:frame={"pose":{}}
	else:
		frame=Motion.rest(rest_variant,rest_time,is_instance_valid(world.avatar),seated_lift,SIZE_RATIO)
	if loaded:
		var holding=Motion.carrying(phase_time,walking,gait_phase,SIZE_RATIO,carry_walk_time)
		frame.pose.merge(holding.pose,true)
		for key in holding:
			if key!="pose":frame[key]=holding[key]
		carry.visible=float(holding.get("load",1.0))>.08
		# The fixed avatar attaches cargo to both hands; the fallback uses the
		# same small pickup arc in torso space instead of popping in at full height.
		if not is_instance_valid(world.avatar):carry.position=Vector3(0,-.24*(1.0-float(holding.get("load",1.0))),0)
	else:carry.hide()
	var grounded_rest=not working and not walking and waking<=0 and rest_variant in [0,1,3]
	if not grounded_rest or rest_variant!=rest_ground_variant or world.builder.position.distance_squared_to(rest_ground_anchor)>.0001 or world.land.size()!=rest_ground_land:
		rest_ground_ready=false;rest_ground_offset=0.0;rest_ground_variant=rest_variant;rest_ground_anchor=world.builder.position;rest_ground_land=world.land.size()
	apply_frame(frame,dt,walking,working,grounded_rest)
	if waking>0 and wake_grounded and not is_instance_valid(world.avatar):
		# Short transition only: use the already selected skin probes while the
		# support changes from hips/back to feet. Settled rest keeps its cache.
		settle_rest_support(false)
	if grounded_rest and not rest_ground_ready and rest_time>=.9 and world.actor.quaternion.angle_to(Quaternion.from_euler(frame.get("rotation",Vector3.ZERO)))<.01:
		settle_rest_support()

func apply_frame(frame:Dictionary,dt:float,walking:bool,working:bool,grounded_rest:bool):
	var pose:Dictionary=frame.get("pose",{})
	var wrist_target=float(frame.get("wrist",0.0))
	if is_instance_valid(world.avatar) and world.avatar.is_fish:
		# Keep the chest hold below the face, and lift tools beside the large head.
		# Copy the values so repeated authoring samples never accumulate changes.
		pose=pose.duplicate()
		if frame.has("load"):
			var held=clampf(float(frame.load),0,1)
			# Keep the forward reach while lowering. Applying the full low hold
			# correction to already lowered arms would put the bundle in the skirt.
			var hold_height=smoothstep(.65,1.05,float(pose.get("ArmR",Vector3.ZERO).x))
			held*=hold_height
			for side in ["L","R"]:
				var arm:Vector3=pose.get("Arm"+side,Vector3.ZERO);arm.x-=.50*held;pose["Arm"+side]=arm
				var elbow:Vector3=pose.get("Elbow"+side,Vector3.ZERO);elbow.x-=.28*held;pose["Elbow"+side]=elbow
		if frame.has("action_phase"):
			# A short front-side wind-up suits the large head. Reaching over it
			# would bury the tool in the hair, even with an exaggerated elbow spread.
			var ready=smoothstep(.10,.42,float(frame.action_phase))*(1.0-smoothstep(.48,.64,float(frame.action_phase)))
			var arm:Vector3=pose.get("ArmR",Vector3.ZERO);arm.x=lerpf(arm.x,1.0,ready);arm.z=lerpf(arm.z,.4,ready);pose.ArmR=arm
			var elbow:Vector3=pose.get("ElbowR",Vector3.ZERO);elbow.x=lerpf(elbow.x,.2,ready);pose.ElbowR=elbow
			wrist_target=lerpf(wrist_target,-.6,ready)
	var rotation:Vector3=frame.get("rotation",Vector3.ZERO)
	var body_rate=12.0 if working or walking or waking>0 else 6.0
	for name in world.limbs:
		# Hands catch a load promptly; the torso and head follow more softly.
		var rate=body_rate*(1.35 if str(name).begins_with("Arm") or str(name).begins_with("Elbow") else 1.15 if str(name).begins_with("Leg") or str(name).begins_with("Knee") else 1.0)
		world.limbs[name].rotation=world.limbs[name].rotation.lerp(pose.get(name,Vector3.ZERO),1-exp(-dt*rate))
	world.actor.quaternion=world.actor.quaternion.slerp(Quaternion.from_euler(rotation),1-exp(-dt*body_rate))
	var elasticity=float(frame.get("elasticity",0.0))
	if walking:elasticity-=.012*pow(abs(sin(gait_phase)),12)*gait_amount
	var stretch=1.0+elasticity;var width=sqrt(1.0/stretch)
	world.actor.scale=world.actor.scale.lerp(Vector3(width,stretch,width)*ACTOR_SCALE,1-exp(-dt*22))
	var breath=sin(world.time*1.5)*.003*SIZE_RATIO if grounded_rest else 0.0
	world.actor.position.y=lerpf(world.actor.position.y,float(frame.get("lift",0.0))+rest_ground_offset+breath,1-exp(-dt*body_rate))
	for tool in world.tools.values():tool.rotation.x=lerpf(tool.rotation.x,wrist_target,1-exp(-dt*16.0))
	if is_instance_valid(head_pivot):
		var body:Vector3=world.limbs.Body.rotation
		var follow=Vector3(-body.x*.22,-body.y*.30,-body.z*.25)+Vector3(frame.get("head",Vector3.ZERO))
		head_pivot.rotation=head_pivot.rotation.lerp(follow,1-exp(-dt*7.0))
	update_expression(frame,dt)
	if walking or (working and waking<=0):plant_feet(float(frame.get("ground",GROUND_GAP)))
	update_skin()

func prepare_rest_support():
	# One initialization scan picks a small fixed set of skin support probes.
	# During play only these probes are transformed, once after a pose/location change.
	var mesh=world.actor.find_child("ContinuousBody",true,false)
	if mesh==null or mesh.skin==null:return
	var arrays=mesh.mesh.surface_get_arrays(0);var chosen={}
	for i in arrays[Mesh.ARRAY_VERTEX].size():
		var p:Vector3=arrays[Mesh.ARRAY_VERTEX][i];var dominant=0;var highest=0.0
		for j in range(4):
			if arrays[Mesh.ARRAY_WEIGHTS][i*4+j]>highest:highest=arrays[Mesh.ARRAY_WEIGHTS][i*4+j];dominant=arrays[Mesh.ARRAY_BONES][i*4+j]
		for axis in range(8):
			var key=str(dominant)+"/"+str(axis);var angle=axis*TAU/8.0;var score=p.y*cos(angle)+p.z*sin(angle)
			if not chosen.has(key) or score<chosen[key].score:chosen[key]={"index":i,"score":score}
	for pick in chosen.values():
		var i=pick.index;var weights=[]
		for j in range(4):weights.append({"bind":arrays[Mesh.ARRAY_BONES][i*4+j],"weight":arrays[Mesh.ARRAY_WEIGHTS][i*4+j]})
		rest_support.append({"position":arrays[Mesh.ARRAY_VERTEX][i],"weights":weights})
	for i in mesh.skin.get_bind_count():rest_support_binds.append({"bone":skeleton.find_bone(mesh.skin.get_bind_name(i)),"pose":mesh.skin.get_bind_pose(i)})

func settle_rest_support(cache=true):
	if rest_support.is_empty():return
	skeleton.force_update_all_bone_transforms()
	var binds=[];var gap=INF
	for bind in rest_support_binds:binds.append(skeleton.get_bone_global_pose(bind.bone)*bind.pose)
	for probe in rest_support:
		var point=Vector3.ZERO
		for weight in probe.weights:point+=(binds[weight.bind]*probe.position)*weight.weight
		var p=world.globe.to_local(skeleton.to_global(point));var ground=world.ground_point(world.terrain.coordinates(p))
		gap=minf(gap,(p-ground).dot(world.builder.basis.y))
	if is_finite(gap):
		var correction=clampf(.022-gap,-.18*SIZE_RATIO,.25*SIZE_RATIO)
		if cache:rest_ground_offset=correction
		world.actor.position.y+=correction
		update_skin()
	if cache:rest_ground_ready=true;rest_ground_samples+=1

func update_skin():
	if not is_instance_valid(skeleton):return
	var skeleton_inverse=skeleton.global_transform.affine_inverse()
	for binding in skin_bindings:
		var driver=binding.driver
		var pose=Transform3D(skeleton_inverse.basis*driver.global_basis*binding.correction,skeleton_inverse*driver.global_position)
		skeleton.set_bone_global_pose_override(binding.bone,pose,1.0,true)
	if is_instance_valid(world.avatar):world.avatar.update_pose()

func impact_elasticity(beat:float)->float:
	# Compress once on impact and give a smaller rebound; the remaining stroke is still.
	if beat>=.64 and beat<.74:return -.045*sin((beat-.64)/.10*PI)
	if beat>=.74 and beat<.87:return .018*sin((beat-.74)/.13*PI)
	return 0.0

func feet_height()->float:
	var height=INF
	for mesh in feet:
		var box=mesh.get_aabb()
		for i in range(8):height=minf(height,world.builder.to_local(mesh.to_global(box.get_endpoint(i))).y)
	return height
func plant_feet(height=GROUND_GAP):
	var lowest=feet_height()
	if is_finite(lowest):world.actor.position.y+=height-lowest

func locomotion_pose(distance:float,speed:float,loaded=false)->Dictionary:
	# Pure sampling remains available to authoring checks; runtime uses gait_phase.
	var amount=clampf(speed/(WALK_SPEED*gait_ratio()),0,1)
	return Motion.locomotion(distance*TAU/stride_length(speed,loaded),run_amount(speed,loaded),amount,SIZE_RATIO,loaded)

func strike_pose(cycle:float,action:int)->Dictionary:
	return Motion.strike(cycle,action,SIZE_RATIO)
