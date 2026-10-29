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

func _init(owner_world):
	world=owner_world
	carry=Node3D.new();world.actor.add_child(carry)
	for i in range(3):
		var log=world.model("timber",carry);log.position=Vector3(0,.85+i*.12,-.35);log.scale=Vector3.ONE*.7
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
	phase=0 if mode=="word" else 2;phase_time=0;hit_clock=0
	world.work_point=origin;world.current_tool=kind if mode=="word" else 2
	if was_resting:
		waking=.5
		if world.move_tween and world.move_tween.is_valid():world.move_tween.kill()
	else:world.walk_to(world.work_stance(0),.7)
func next_phase():
	phase=(phase+1)%3;phase_time=0;hit_clock=0
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
		if phase_time>[3.8,1.1,4.0][phase]:next_phase()
	elif not walking:
		rest_time+=dt
		if rest_time>[6.0,12.0,4.5,7.0][rest_variant]:rest_time=0;rest_variant=(rest_variant+1)%4
	carry.visible=working and phase==1 and waking<=0
	world.set_tool((kind if phase==0 else 2) if working and phase!=1 and waking<=0 else -1)
	var pose={}
	for name in world.limbs:pose[name]=Vector3.ZERO
	var rot=Vector3.ZERO;var lift=0.0
	if walking:
		var step=sin(world.time*12)*.46
		for side in ["L","R"]:
			var sign=1.0 if side=="L" else -1.0
			pose["Leg"+side].x=step*sign;pose["Knee"+side].x=maxf(0,-step*sign)*.55;pose["Arm"+side].x=-step*sign*.75
		lift=abs(sin(world.time*12))*.035
	elif working and waking<=0:
		var beat=sin(fmod(world.time*(1.5 if phase==2 else 1.15),1.0)*PI)
		pose.ArmR.x=-.35-beat*.95;pose.ElbowR.x=-.2-beat*.3;pose.ArmL.x=-.4-beat*.3;pose.ElbowL.x=-.35
		rot.x=beat*.10;rot.z=sin(world.time*2)*.025
		if phase==2:
			hit_clock+=dt
			if hit_clock>.85:
				hit_clock=0
				var p=world.builder.position+world.builder.basis.y*.55-world.builder.basis.z*.5
				for i in range(2):
					var chip=world.pebble(world.globe,p,Vector3.ONE*.07,"E9C98B")
					world.effects.append({"node":chip,"a":p,"b":p+world.builder.basis.x*(i-.5)*.3,"t":0.0,"duration":.35})
	elif waking<=0:
		match rest_variant:
			0: # Sitting on the grass.
				rot.y=PI;lift=-.40;pose.LegL.x=1.35;pose.LegR.x=1.30;pose.KneeL.x=.25;pose.KneeR.x=.20;pose.ArmL.x=-.5;pose.ArmR.x=-.5;pose.ElbowL.x=-.4;pose.ElbowR.x=-.4
			1: # Lying back, hands behind the head; no tool or construction effects.
				rot.x=PI/2;lift=.24;pose.ArmL.z=-1.9;pose.ArmR.z=1.9;pose.ElbowL.x=-1.4;pose.ElbowR.x=-1.4;pose.LegL.z=-.12;pose.LegR.z=.12
			2: # A slow stretch.
				rot.y=PI;pose.ArmL.z=-2.6;pose.ArmR.z=2.6;pose.ElbowL.x=-.3;pose.ElbowR.x=-.3;rot.z=sin(rest_time*1.4)*.06
			3: # Sitting and gently swinging one foot.
				rot.y=PI;lift=-.40;pose.LegL.x=1.35;pose.LegR.x=1.30;pose.KneeL.x=.25+sin(world.time*1.8)*.13;pose.KneeR.x=.20;pose.ArmL.x=-.45;pose.ArmR.x=-.45
	if carry.visible:
		pose.ArmL.x=-1.0;pose.ArmR.x=-1.0;pose.ElbowL.x=-.55;pose.ElbowR.x=-.55
	var blend=1-exp(-dt*7)
	for name in world.limbs:world.limbs[name].rotation=world.limbs[name].rotation.lerp(pose[name],blend)
	world.actor.rotation=world.actor.rotation.lerp(rot,blend)
	world.actor.position.y=lerpf(world.actor.position.y,lift+sin(world.time*1.5)*.005,blend)
