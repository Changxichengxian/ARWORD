extends RefCounted
class_name IslandWorker

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

func _init(owner_world):
	world=owner_world
	# The model faces -Z. Positive shoulder X lifts the hand forward.
	# Put the upper body and shoulders on one waist pivot so a strike uses the torso.
	var torso=world.limbs.Body
	for part in torso.get_children():
		if part is Node3D:part.position.y-=.66
	torso.position.y=.66
	for side in ["L","R"]:world.limbs["Arm"+side].reparent(torso,true)
	feet=world.actor.find_children("Foot*","MeshInstance3D",true,false)
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
	var current=world.terrain.coordinates(world.builder.position)
	for cell in world.land:
		if cell in IslandFrontier.BUILD_CELLS or cell in [Vector2i(0,1),Vector2i(0,-1),Vector2i(3,0)]:continue
		var p=IslandFrontier.point(cell)+Vector2(0,-.27);var d=p.distance_squared_to(current)
		if d<score:score=d;best=p
	return best
func settle():
	world.set_tool(-1);carry.hide();rest_time=0;rest_variant=0
	var spot=rest_spot();world.work_point=spot+Vector2(0,-1);world.walk_to(spot,.75)
func grant(mode:String,target:Vector2,entry:Dictionary,resource_kind:int):
	var was_resting=work_left<=0
	work_left=minf(36.0,work_left+(12.0 if mode=="word" else 9.0))
	destination=target;kind=resource_kind;origin=entry.p if mode=="word" and not entry.is_empty() else target
	phase=0 if mode=="word" else 2;phase_time=0;hit_clock=0;stroke_time=0;last_impact=-1
	world.work_point=origin;world.current_tool=kind if mode=="word" else 2
	if was_resting:
		waking=.5
		if world.move_tween and world.move_tween.is_valid():world.move_tween.kill()
	else:world.walk_to(world.work_stance(0),.7)
func next_phase():
	phase=(phase+1)%3;phase_time=0;hit_clock=0;stroke_time=0;last_impact=-1
	if phase==1:
		world.work_point=destination;world.walk_to(world.work_stance(1),.85)
	elif phase==0:
		world.work_point=origin;world.walk_to(world.work_stance(2),.85)
func update(dt:float):
	var working=work_left>0
	if working:
		work_left=maxf(0,work_left-dt)
		if work_left<=0:settle();working=false
	if waking>0:
		waking=maxf(0,waking-dt)
		if waking<=0:world.walk_to(world.work_stance(0),.7)
	var walking=world.move_tween and world.move_tween.is_running()
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
	var rot=Vector3.ZERO;var lift=0.0;var wrist=0.0;var contact_height=.015
	if walking:
		var moving=locomotion_pose(world.travelled,world.motion_speed,carry.visible)
		pose.merge(moving.pose,true);rot=moving.rotation;lift=moving.lift;contact_height=moving.ground
	elif working and waking<=0:
		stroke_time+=dt
		if phase!=1:
			var action=2 if phase==2 else kind
			var cycle=[1.65,1.9,1.35][action];var beat=fmod(stroke_time,cycle)/cycle
			var strike=strike_pose(beat,action);pose.merge(strike.pose,true);rot=strike.rotation;lift=strike.lift;wrist=strike.wrist
			var impact=int(floor(stroke_time/cycle))
			if beat>=.64 and impact!=last_impact:
				last_impact=impact
				if phase==2:
					var p=world.builder.position+world.builder.basis.y*.55-world.builder.basis.z*.62
					for i in range(2):
						var chip=world.pebble(world.globe,p,Vector3.ONE*.07,"E9C98B")
						world.effects.append({"node":chip,"a":p,"b":p+world.builder.basis.x*(i-.5)*.3,"t":0.0,"duration":.35})
	elif waking<=0:
		match rest_variant:
			0: # Sitting on the grass.
				rot.y=PI;lift=-.39;pose.LegL.x=1.50;pose.LegR.x=1.48;pose.KneeL.x=-.12;pose.KneeR.x=-.10;pose.ArmL=Vector3(.12,0,.12);pose.ArmR=Vector3(.12,0,-.12);pose.ElbowL.x=.08;pose.ElbowR.x=.08;pose.Body.x=.05
			1: # Lying back, hands behind the head; no tool or construction effects.
				rot.x=PI/2;lift=.24;pose.ArmL.z=-1.9;pose.ArmR.z=1.9;pose.ElbowL.x=1.0;pose.ElbowR.x=1.0;pose.LegL.z=-.12;pose.LegR.z=.12
			2: # A slow stretch.
				rot.y=PI;pose.ArmL.z=-2.6;pose.ArmR.z=2.6;pose.ElbowL.x=.3;pose.ElbowR.x=.3;pose.Body.z=sin(rest_time*1.4)*.10;pose.Body.x=-.07
			3: # Sitting and gently swinging one foot.
				rot.y=PI;lift=-.39;pose.LegL.x=1.50;pose.LegR.x=1.48;pose.KneeL.x=sin(world.time*1.8)*.10;pose.KneeR.x=-.10;pose.ArmL=Vector3(.12,0,.12);pose.ArmR=Vector3(.12,0,-.12);pose.ElbowL.x=.08;pose.ElbowR.x=.08;pose.Body.x=.05
	if carry.visible:
		pose.ArmL=Vector3(.95,0,.34);pose.ArmR=Vector3(.95,0,-.34);pose.ElbowL.x=.40;pose.ElbowR.x=.40;pose.Body.x=.08
	var blend=1-exp(-dt*(13.0 if working or walking else 6.0))
	for name in world.limbs:world.limbs[name].rotation=world.limbs[name].rotation.lerp(pose[name],blend)
	world.actor.rotation=world.actor.rotation.lerp(rot,blend)
	world.actor.position.y=lerpf(world.actor.position.y,lift+sin(world.time*1.5)*.005,blend)
	for tool in world.tools.values():tool.rotation.x=lerpf(tool.rotation.x,wrist,blend)
	if walking or working:plant_feet(contact_height)

func feet_height()->float:
	var height=INF
	for mesh in feet:
		var box=mesh.get_aabb()
		for i in range(8):height=minf(height,world.builder.to_local(mesh.to_global(box.get_endpoint(i))).y)
	return height
func plant_feet(height=.015):
	var lowest=feet_height()
	if is_finite(lowest):world.actor.position.y+=height-lowest

func locomotion_pose(distance:float,speed:float,loaded=false)->Dictionary:
	var run=clampf((speed-1.25)/.50,0,1) if not loaded else 0.0
	var angle=distance*TAU/lerpf(1.22,1.65,run);var amplitude=lerpf(.44,.68,run)
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
	return {"pose":pose,"rotation":Vector3(0,0,sin(angle)*.025),"lift":lift,"ground":.015+run*.075*(1-contact)}

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
	return {"pose":pose,"rotation":Vector3(0,-frame.twist*.18,frame.twist*.05),"lift":-frame.crouch,"wrist":frame.wrist}
