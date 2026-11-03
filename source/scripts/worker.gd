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

func travel_speed()->float:
	return ((CARRY_SPEED if phase==1 else RUN_SPEED) if work_left>0 else WALK_SPEED)*gait_ratio()

func gait_ratio()->float:
	return world.avatar.gait_ratio if is_instance_valid(world.avatar) else 1.0

func run_amount(speed:float,loaded=false)->float:
	return clampf((speed/(SPEED_RATIO*gait_ratio())-1.25)/.50,0,1) if not loaded else 0.0

func stride_length(speed:float,loaded=false)->float:
	return lerpf(1.22,1.65,run_amount(speed,loaded))*SIZE_RATIO*gait_ratio()
func grant(mode:String,target:Vector2,entry:Dictionary,resource_kind:int):
	var was_resting=work_left<=0
	work_left=minf(36.0,work_left+(12.0 if mode=="word" else 9.0))
	var request={"target":target,"kind":resource_kind,"origin":entry.p if mode=="word" and not entry.is_empty() else target,"harvest":mode=="word" and not entry.is_empty()}
	if not was_resting and (transport_suspended or destination.distance_squared_to(target)<.0001):
		# Fast answers extend the current stroke/trip. The latest source is used after delivery.
		pending_work=request
		return
	pending_work.clear();configure_work(request)
	if was_resting:
		waking=.5
		if world.move_tween and world.move_tween.is_valid():world.move_tween.kill()
	else:world.walk_to(world.work_stance(0),.7)
func configure_work(request:Dictionary):
	destination=request.target;kind=request.kind;origin=request.origin;harvesting_cycle=request.harvest
	phase=0 if harvesting_cycle else 2;phase_time=0;hit_clock=0;stroke_time=0;last_impact=-1
	world.work_point=origin if harvesting_cycle else destination;world.current_tool=kind if harvesting_cycle else 2

func suspend_for_transport(suspended:bool):
	transport_suspended=suspended
	if suspended:world.set_tool(-1);carry.hide()

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
		world.work_point=destination;world.walk_to(world.work_stance(1),.85)
	elif phase==0:
		world.work_point=origin;world.walk_to(world.work_stance(2),.85)
func update(dt:float):
	if transport_suspended:
		# The boat owns travel; preserve the work budget and current production phase.
		world.set_tool(-1);carry.hide()
		var blend=1-exp(-dt*10.0)
		for limb in world.limbs.values():limb.rotation=limb.rotation.lerp(Vector3.ZERO,blend)
		world.actor.rotation=world.actor.rotation.lerp(Vector3.ZERO,blend);world.actor.position.y=lerpf(world.actor.position.y,0.0,blend);world.actor.scale=world.actor.scale.lerp(Vector3.ONE*ACTOR_SCALE,blend)
		if is_instance_valid(head_pivot):head_pivot.rotation=head_pivot.rotation.lerp(Vector3.ZERO,blend)
		update_skin();return
	var working=work_left>0
	var walking=world.move_tween and world.move_tween.is_running()
	# The reward is time spent working, so travel and getting up never consume it.
	if working and not walking and waking<=0:
		work_left=maxf(0,work_left-dt)
		if work_left<=0:settle();working=false
	if waking>0:
		waking=maxf(0,waking-dt)
		if waking<=0:world.walk_to(world.work_stance(0),.7)
	walking=world.move_tween and world.move_tween.is_running()
	if working and waking<=0:
		if not walking:phase_time+=dt
		if phase_time>[4.5,1.0,4.0][phase]:next_phase()
	elif not walking:
		rest_time+=dt
		if rest_time>[6.0,12.0,4.5,7.0][rest_variant]:rest_time=0;rest_variant=(rest_variant+1)%4
	carry.visible=working and phase==1 and waking<=0
	cargo[0].visible=kind==0;cargo[1].visible=kind==1
	world.set_tool((kind if phase==0 else 2) if working and phase!=1 and waking<=0 else -1)
	var pose={}
	for name in world.limbs:pose[name]=Vector3.ZERO
	var rot=Vector3.ZERO;var lift=0.0;var wrist=0.0;var contact_height=GROUND_GAP;var elasticity=0.0
	if walking:
		var moving=locomotion_pose(world.travelled,world.motion_speed,carry.visible)
		pose.merge(moving.pose,true);rot=moving.rotation;lift=moving.lift;contact_height=moving.ground
		# A restrained soft landing follows actual footsteps, never a looping idle wobble.
		var stride=stride_length(world.motion_speed,carry.visible)
		elasticity=-.018*pow(abs(sin(world.travelled*TAU/stride)),12)
	elif working and waking<=0:
		stroke_time+=dt
		if phase!=1:
			var action=2 if phase==2 else kind
			var cycle=[1.65,1.9,1.35][action];var beat=fmod(stroke_time,cycle)/cycle
			elasticity=impact_elasticity(beat)
			var strike=strike_pose(beat,action);pose.merge(strike.pose,true);rot=strike.rotation;lift=strike.lift;wrist=strike.wrist
			var impact=int(floor(stroke_time/cycle))
			if beat>=.64 and impact!=last_impact:
				last_impact=impact
				if phase==2:
					var p=world.builder.position+(world.builder.basis.y*.55-world.builder.basis.z*.62)*SIZE_RATIO
					for i in range(2):
						var chip=world.pebble(world.globe,p,Vector3.ONE*.07*SIZE_RATIO,"E9C98B")
						world.effects.append({"node":chip,"a":p,"b":p+world.builder.basis.x*(i-.5)*.3*SIZE_RATIO,"t":0.0,"duration":.35})
	elif waking<=0:
		match rest_variant:
			0: # Sitting on the grass.
				rot.y=PI;lift=seated_lift;pose.LegL.x=1.50;pose.LegR.x=1.48;pose.KneeL.x=-.12;pose.KneeR.x=-.10;pose.ArmL=Vector3(.12,0,.12);pose.ArmR=Vector3(.12,0,-.12);pose.ElbowL.x=.08;pose.ElbowR.x=.08;pose.Body.x=.05
			1: # Lying back with arms resting beside the body; no tools or effects.
				if is_instance_valid(world.avatar):
					# A short-legged, large-haired avatar dozes seated instead of exposing its underside.
					lift=seated_lift;pose.LegL.x=1.15;pose.LegR.x=1.10;pose.KneeL.x=-.35;pose.KneeR.x=-.30;pose.ArmL=Vector3(.18,0,.18);pose.ArmR=Vector3(.18,0,-.18);pose.Body.x=.08
				else:
					rot.x=PI/2;lift=.18*SIZE_RATIO;pose.ArmL.z=-.32;pose.ArmR.z=.32;pose.ElbowL.x=-.25;pose.ElbowR.x=-.25;pose.LegL.z=-.12;pose.LegR.z=.12
			2: # A slow stretch.
				rot.y=PI;pose.ArmL.z=-2.6;pose.ArmR.z=2.6;pose.ElbowL.x=.3;pose.ElbowR.x=.3;pose.Body.z=sin(rest_time*1.4)*.10;pose.Body.x=-.07
			3: # Sitting and gently swinging one foot.
				rot.y=PI;lift=seated_lift;pose.LegL.x=1.50;pose.LegR.x=1.48;pose.KneeL.x=sin(world.time*1.8)*.10;pose.KneeR.x=-.10;pose.ArmL=Vector3(.12,0,.12);pose.ArmR=Vector3(.12,0,-.12);pose.ElbowL.x=.08;pose.ElbowR.x=.08;pose.Body.x=.05
	if carry.visible:
		pose.ArmL=Vector3(.95,0,.34);pose.ArmR=Vector3(.95,0,-.34);pose.ElbowL.x=.40;pose.ElbowR.x=.40;pose.Body.x=.08
	var grounded_rest=not working and not walking and waking<=0 and rest_variant in [0,1,3]
	if not grounded_rest or rest_variant!=rest_ground_variant or world.builder.position.distance_squared_to(rest_ground_anchor)>.0001 or world.land.size()!=rest_ground_land:
		rest_ground_ready=false;rest_ground_offset=0.0;rest_ground_variant=rest_variant;rest_ground_anchor=world.builder.position;rest_ground_land=world.land.size()
	var blend=1-exp(-dt*(13.0 if working or walking else 6.0))
	for name in world.limbs:world.limbs[name].rotation=world.limbs[name].rotation.lerp(pose[name],blend)
	world.actor.rotation=world.actor.rotation.lerp(rot,blend)
	var stretch=1.0+elasticity;var width=sqrt(1.0/stretch)
	world.actor.scale=world.actor.scale.lerp(Vector3(width,stretch,width)*ACTOR_SCALE,1-exp(-dt*22))
	world.actor.position.y=lerpf(world.actor.position.y,lift+rest_ground_offset+sin(world.time*1.5)*.005*SIZE_RATIO,blend)
	for tool in world.tools.values():tool.rotation.x=lerpf(tool.rotation.x,wrist,blend)
	if is_instance_valid(head_pivot):
		# A delayed, small counter-turn lets the head settle after the torso. No idle oscillation.
		var follow=Vector3(-pose.Body.x*.25,-pose.Body.y*.30,-pose.Body.z*.25)
		head_pivot.rotation=head_pivot.rotation.lerp(follow,1-exp(-dt*7.0))
	if walking or working:plant_feet(contact_height)
	update_skin()
	if grounded_rest and not rest_ground_ready and rest_time>=.9 and world.actor.rotation.distance_squared_to(rot)<.0001:
		settle_rest_support()

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

func settle_rest_support():
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
		rest_ground_offset=clampf(.022-gap,-.18*SIZE_RATIO,.25*SIZE_RATIO)
		world.actor.position.y+=rest_ground_offset
		update_skin()
	rest_ground_ready=true;rest_ground_samples+=1

func update_skin():
	if not is_instance_valid(skeleton):return
	for binding in skin_bindings:
		var driver=binding.driver
		var pose=Transform3D(skeleton.global_basis.inverse()*driver.global_basis*binding.correction,skeleton.to_local(driver.global_position))
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
	var run=run_amount(speed,loaded)
	var angle=distance*TAU/stride_length(speed,loaded);var amplitude=lerpf(.44,.68,run)
	var pose={}
	for i in range(2):
		var side="L" if i==0 else "R";var phase_angle=angle+i*PI
		var thigh=sin(phase_angle)*amplitude
		pose["Leg"+side]=Vector3(thigh,0,0)
		# The knee bends backward as the heel leaves the ground, then extends to land.
		pose["Knee"+side]=Vector3(-pow(maxf(0,cos(phase_angle)),2)*lerpf(.65,1.18,run),0,0)
		pose["Arm"+side]=Vector3(.12-thigh*.72+run*.17,0,.04 if i==0 else -.04)
		pose["Elbow"+side]=Vector3(lerpf(.24,.85,run),0,0)
	pose.Body=Vector3(lerpf(.045,.16,run),sin(angle)*.065,0)
	var contact=abs(sin(angle));var lift=.012+contact*.018+run*pow(contact,2)*.075
	return {"pose":pose,"rotation":Vector3(0,0,sin(angle)*.025),"lift":lift*SIZE_RATIO,"ground":GROUND_GAP+run*.075*SIZE_RATIO*(1-contact)}

func strike_pose(cycle:float,action:int)->Dictionary:
	# Slow preparation, a short committed downstroke, then recoil and recovery.
	var ready={"arm":.72,"elbow":.35,"body":.06,"twist":-.05,"crouch":.025,"wrist":-.45}
	var raised={"arm":2.05 if action==0 else 2.40 if action==1 else 1.65,"elbow":.30,"body":-.10,"twist":-.36 if action==0 else -.10,"crouch":.055,"wrist":.05}
	var hit={"arm":.82 if action!=2 else .72,"elbow":.22,"body":.30 if action==0 else .43 if action==1 else .22,"twist":.30 if action==0 else .12,"crouch":.11 if action==1 else .075,"wrist":-1.80 if action==0 else -2.0 if action==1 else -1.6}
	var a:Dictionary;var b:Dictionary;var t:float
	if cycle<.48:
		a=ready;b=raised;t=smoothstep(0.0,.48,cycle)
	elif cycle<.64:
		a=raised;b=hit;t=pow((cycle-.48)/.16,1.7)
	elif cycle<.74:
		a=hit;b=ready;t=smoothstep(.64,.74,cycle)*.28
	else:
		a=hit;b=ready;t=.28+smoothstep(.74,1.0,cycle)*.72
	var frame={}
	for key in ready:frame[key]=lerpf(a[key],b[key],t)
	var pose={
		"ArmR":Vector3(frame.arm,0,-.16),"ElbowR":Vector3(frame.elbow,0,-.06),
		"ArmL":Vector3(frame.arm*.78,0,.48),"ElbowL":Vector3(.50,0,.08),
		"Body":Vector3(frame.body,frame.twist,frame.twist*.10),
		"LegL":Vector3(.16+frame.crouch,0,-.035),"LegR":Vector3(-.11+frame.crouch,0,.035),
		"KneeL":Vector3(-.18-frame.crouch*1.1,0,0),"KneeR":Vector3(-.12-frame.crouch,0,0)
	}
	return {"pose":pose,"rotation":Vector3(0,-frame.twist*.18,frame.twist*.05),"lift":-frame.crouch*SIZE_RATIO,"wrist":frame.wrist}
