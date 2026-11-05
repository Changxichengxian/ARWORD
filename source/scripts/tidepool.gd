extends Node3D

const LEDGE=preload("res://assets/models/tidal_ledge.glb")
const CRAB=preload("res://assets/models/wild_crab.glb")
const SEAL=preload("res://assets/models/wild_seal.glb")
var crab:Node3D
var seal:Node3D
var head:Node3D
var chest:Node3D
var body:Node3D
var flipper:Node3D
var other_flipper:Node3D
var hind_left:Node3D
var hind_right:Node3D
var claw:Node3D
var other_claw:Node3D
var pincer_left:Node3D
var pincer_right:Node3D
var legs:Array=[]
var belly_points:PackedVector3Array=[]
var attention=0.
var scuttle=0.
var attention_blend=0.
var panic=0.
var crab_gait=0.
var crab_previous=Vector3.ZERO
var crabs:Array=[]
var habitat
var crab_state="walk"
var seal_state="look"
var normal=Vector3.ZERO

func _ready():
	add_child(LEDGE.instantiate())
	crab=CRAB.instantiate();add_child(crab);crab.scale=Vector3.ONE*.69
	seal=SEAL.instantiate();add_child(seal);seal.scale=Vector3.ONE*.77
	seal.position=Vector3(.14,0,.23);seal.rotation.y=PI*.5
	head=seal.find_child("Head",true,false);chest=seal.find_child("Chest",true,false);body=seal.find_child("Body",true,false)
	flipper=seal.find_child("FlipperL",true,false);other_flipper=seal.find_child("FlipperR",true,false)
	hind_left=seal.find_child("HindL",true,false);hind_right=seal.find_child("HindR",true,false)
	claw=crab.find_child("ClawL",true,false);other_claw=crab.find_child("ClawR",true,false)
	pincer_left=crab.find_child("PincerL",true,false);pincer_right=crab.find_child("PincerR",true,false)
	# Only the torso contact points determine belly support; flippers remain
	# hinged at the shoulder and rise on the lower side during a body roll.
	var unique={}
	for part in body.get_children():
		if not part is MeshInstance3D:continue
		for surface in part.mesh.get_surface_count():
			for v in part.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				var point=body.to_local(part.to_global(v))
				if point.y<.18:unique[point]=true
	for point in unique:belly_points.append(point)
	for side in ["L","R"]:
		for index in range(4):
			var leg=crab.find_child("Leg"+side+str(index),true,false)
			if not leg:continue
			var knee=leg.find_child("Knee*",true,false);var toe=leg.find_child("Toe*",true,false)
			if not knee or not toe:continue
			legs.append({"node":leg,"knee":knee,"toe":toe,"upper":knee.position,"lower":toe.position,"rest":leg.position+knee.position+toe.position,"phase":float(index%2)*.5+(.5 if side=="R" else 0.)})

	crabs.append(make_crab_entry(crab,0,.69))
	for i in range(1,3):
		var extra=CRAB.instantiate();add_child(extra);extra.scale=Vector3.ONE*(.50 if i==1 else .53)
		crabs.append(make_crab_entry(extra,i,.50 if i==1 else .53))

func make_crab_entry(model:Node3D,index:int,size:float)->Dictionary:
	var articulated=[]
	for side in ["L","R"]:
		for i in range(4):
			var joint=model.find_child("Leg"+side+str(i),true,false)
			var knee=joint.find_child("Knee*",true,false);var toe=joint.find_child("Toe*",true,false)
			articulated.append({"node":joint,"knee":knee,"toe":toe,"upper":knee.position,"lower":toe.position,"rest":joint.position+knee.position+toe.position,"phase":float(i%2)*.5+(.5 if side=="R" else 0.)})
	return {"model":model,"index":index,"size":size,"legs":articulated,"left":model.find_child("ClawL",true,false),"right":model.find_child("ClawR",true,false),"finger_left":model.find_child("PincerL",true,false),"finger_right":model.find_child("PincerR",true,false),"gait":0.,"last":Vector3.ZERO,"state":"rest","surface":"rock","route_valid":false,"panic":0.,"reaction":0.}

const RIM=[Vector2(-1.37,.22),Vector2(-1.1,.61),Vector2(-.42,.76),Vector2(.38,.70),Vector2(1.04,.49),Vector2(1.31,.14),Vector2(1.24,-.34),Vector2(.79,-.61),Vector2(.12,-.75),Vector2(-.75,-.68),Vector2(-1.23,-.40)]
func rim_radius(direction:Vector2)->float:
	var radius=INF
	for i in RIM.size():
		var a:Vector2=RIM[i];var edge:Vector2=RIM[(i+1)%RIM.size()]-a
		var denominator=direction.cross(edge)
		if absf(denominator)<.00001:continue
		var distance=a.cross(edge)/denominator;var amount=a.cross(direction)/denominator
		if distance>0. and amount>=0. and amount<=1.:radius=minf(radius,distance)
	return radius

func floor_point(point:Vector3)->Vector3:
	# Solve height while keeping this shelf's horizontal coordinates. A plain
	# radial projection would pull a descending crab through the tapered rock.
	var p=point
	var up=basis.y.normalized()
	for i in 5:
		var globe_point:Vector3=transform*p;var n=globe_point.normalized()
		var gap=globe_point.length()-habitat.world.water.floor_radius(n)-.025
		if absf(gap)<.0001:break
		p.y-=gap/maxf(.3,up.dot(n))
	return p

func floor_up(point:Vector3)->Vector3:
	var dx=floor_point(point+Vector3(.12,0,0))-floor_point(point-Vector3(.12,0,0))
	var dz=floor_point(point+Vector3(0,0,.12))-floor_point(point-Vector3(0,0,.12))
	return dz.cross(dx).normalized()

func configure_crabs():
	for entry in crabs:
		entry.route_valid=false
		for offset in [0.,.10,-.10,.20,-.20]:
			var angle=[-2.60,-1.57,-.55][entry.index]+offset
			var direction=Vector3(cos(angle),0.,sin(angle));var radius=rim_radius(Vector2(direction.x,direction.z))
			var okay=true
			for step in 9:
				var p=direction*(radius*1.07+.4+step*.055)
				var globe_point:Vector3=habitat.to_local(to_global(p));var n=globe_point.normalized()
				if not habitat.outside_land(n,.34) or habitat.depth_at(n)<.65 or not habitat.clear_of_cave(n,.4):okay=false;break
				for obstacle in habitat.seabed_obstacles:
					if obstacle.normal.distance_to(normal)<.001:continue
					if n.distance_to(obstacle.normal)*IslandWater.BASE_RADIUS<obstacle.radius+.38:okay=false;break
			if okay:
				entry.direction=direction;entry.radius=radius;entry.route_valid=true
				var bottom=floor_point(direction*(radius*1.03+.45))
				for i in 3:
					var wall_scale=lerpf(1.07,.78,clampf((-bottom.y-.25)/5.25,0.,1.))
					bottom=floor_point(direction*(radius*wall_scale+.45))
				entry.bottom=bottom;entry.bed_up=floor_up(bottom);entry.outer_up=floor_up(bottom+direction*.36);break
		# Each crab remains visible on its own patch if surrounding water is
		# temporarily blocked after expansion. No unsafe seabed route is used.
		if not entry.route_valid:
			entry.direction=Vector3(cos([-2.6,-1.57,-.55][entry.index]),0.,sin([-2.6,-1.57,-.55][entry.index]));entry.radius=rim_radius(Vector2(entry.direction.x,entry.direction.z))

func choose_coast(life):
	habitat=life
	if normal!=Vector3.ZERO and life.outside_land(normal,1.40):configure_crabs();return
	hide();normal=Vector3.ZERO
	for n in life.coast+life.offshore:
		if n.dot(Vector3.DOWN)>.45 or not life.outside_land(n,1.40) or not life.clear_of_cave(n,1.40):continue
		normal=n;position=n*(IslandWater.BASE_RADIUS+.155)
		basis=life.frame_at(position,life.tangent_axes(n)[1]);show();configure_crabs();return

func envelope(t:float,start:float,rise:float,hold:float,end:float)->float:
	return smoothstep(start,rise,t)*(1.-smoothstep(hold,end,t))

func animate(t:float,dt:float):
	if not visible:return
	attention=maxf(0,attention-dt);scuttle=maxf(0,scuttle-dt)
	attention_blend=lerpf(attention_blend,smoothstep(0.,.8,attention),1.-exp(-dt*8.))
	panic=lerpf(panic,smoothstep(0.,.8,scuttle),1.-exp(-dt*9.))
	animate_seal(t)
	for entry in crabs:animate_crab(entry,t,dt)

func animate_seal(t:float):
	var phase=fposmod(t,28.)
	# Two short belly-driven pushes, a stretch and a sunning roll, then a
	# return to the original spot. The crab owns the separate seaward lane.
	var outbound=smoothstep(4.,5.3,phase)*.10+smoothstep(6.,7.3,phase)*.10
	var inbound=smoothstep(21.,22.3,phase)*.10+smoothstep(23.,24.3,phase)*.10
	var push=envelope(phase,4.,4.5,4.8,5.5)+envelope(phase,6.,6.5,6.8,7.5)+envelope(phase,21.,21.5,21.8,22.5)+envelope(phase,23.,23.5,23.8,24.5)
	var stretch=envelope(phase,8.,9.2,10.2,12.)
	var roll=envelope(phase,12.,13.8,16.,18.5)
	var settle=envelope(phase,18.5,19.3,20.,21.)
	seal_state="scoot" if push>.08 else "stretch" if stretch>.08 else "sunbathe" if roll>.08 else "settle" if settle>.08 else "look"
	var side_roll=.48*roll
	seal.rotation=Vector3(0.,PI*.5,side_roll)
	body.scale=Vector3(1.+.025*push,1.+.014*sin(t*1.8),1.-.045*push)
	chest.rotation.x=.03+.19*stretch+.09*push+.055*attention_blend
	head.rotation.x=-.05+.12*stretch-.08*push+.06*sin(t*.9)-.25*attention_blend
	head.rotation.y=.27*sin(t*.48)+.24*attention_blend
	head.rotation.z=-.13*roll
	flipper.rotation=Vector3(.08*push,.12*stretch,-.04-.23*push-.18*stretch-side_roll*1.35)
	other_flipper.rotation=Vector3(.08*push,-.12*stretch,.04+.23*push+.18*stretch+.20*roll*sin(t*2.3))
	hind_left.rotation=Vector3(.10*push+.07*stretch,.12*stretch,-.10*push-.16*roll)
	hind_right.rotation=Vector3(.10*push+.07*stretch,-.12*stretch,.10*push+.16*roll)
	seal.position.x=.14-outbound+inbound;seal.position.z=.23
	var bottom=INF
	for point in belly_points:bottom=minf(bottom,(seal.basis*(body.transform*point)).y)
	seal.position.y=-bottom+.002

func crab_route(entry:Dictionary,phase:float)->Dictionary:
	var out:Vector3=entry.direction;var radius:float=entry.radius
	var top=out*(radius*.58);top.y=.006
	var edge=out*(radius*.94);edge.y=.006
	if not entry.route_valid:return {"point":top,"up":Vector3.UP,"axis":out,"state":"feed","surface":"rock"}
	var bottom:Vector3=entry.bottom
	var p=top;var up=Vector3.UP;var axis=out;var state="walk";var surface="rock"
	if phase<3.:p=top.lerp(edge,smoothstep(0.,3.,phase))
	elif phase<5.5 or (phase>=13. and phase<15.5):
		var descending=phase<5.5
		var u=smoothstep(3.,5.5,phase) if descending else 1.-smoothstep(13.,15.5,phase)
		var y=lerpf(.006,bottom.y,u)
		var wall_scale=lerpf(.94,1.07,clampf(-y/.25,0.,1.)) if y>-.25 else lerpf(1.07,.78,clampf((-y-.25)/5.25,0.,1.))
		var foot_clearance=.12*sin(u*PI)+.45*smoothstep(.68,1.,u)
		p=out*(radius*wall_scale+foot_clearance);p.y=y+.075*envelope(u,0.,.015,.065,.20)
		var wall_turn=smoothstep(0.,.22,u)*(1.-smoothstep(.7,1.,u))
		up=Vector3.UP.lerp(out,wall_turn).normalized()
		axis=out.lerp(Vector3.DOWN,wall_turn).normalized()
		if u>.7:up=up.lerp(entry.bed_up,smoothstep(.7,1.,u)).normalized()
		p+=up*.04*sin(u*PI)
		state="descend" if descending else "climb";surface="wall"
	elif phase<13.:
		var distance=.36*smoothstep(5.5,8.,phase)*(1.-smoothstep(10.,13.,phase))
		p=floor_point(bottom+out*distance);up=entry.bed_up.lerp(entry.outer_up,distance/.36).normalized();axis=out
		state="forage" if phase>=8. and phase<10. else "seabed_walk";surface="seabed"
	elif phase<18.:p=edge.lerp(top,smoothstep(15.5,18.,phase))
	else:state="feed" if phase<21. else "display"
	return {"point":p,"up":up,"axis":axis,"state":state,"surface":surface}

func animate_crab(entry:Dictionary,t:float,dt:float):
	var model:Node3D=entry.model;var size:float=entry.size
	entry.reaction=maxf(0.,entry.reaction-dt)
	entry.panic=lerpf(entry.panic,smoothstep(0.,.65,entry.reaction),1.-exp(-dt*9.))
	entry.motion_time=entry.get("motion_time",t-dt)+dt*(1.+entry.panic*.65)
	var phase=fposmod(entry.motion_time+float(entry.index)*8.-.65*entry.panic,24.)
	var route=crab_route(entry,phase) if habitat else {"point":Vector3(-.60+entry.index*.60,.006,-.38),"up":Vector3.UP,"axis":Vector3.RIGHT,"state":"display" if fposmod(t,6.)>3. else "feed","surface":"rock"}
	var point:Vector3=route.point
	var up:Vector3=route.up;var axis:Vector3=route.axis.slide(up).normalized()
	var frame=Basis(axis,up,axis.cross(up).normalized()).orthonormalized()
	# A startled crab shortens its body, tucks the feeding claw and takes
	# rapid small steps on the same checked surface instead of jumping away.
	var movement=point-entry.last;var speed=movement.length()/maxf(dt,.001) if entry.last!=Vector3.ZERO else 0.
	if entry.last!=Vector3.ZERO:entry.gait+=movement.length()/(size*.20)
	entry.last=point;entry.state="retreat" if entry.panic>.2 else route.state;entry.surface=route.surface
	model.position=point;model.basis=frame.scaled(Vector3.ONE*size)
	var forward=1. if movement.dot(axis)>=0. else -1.
	var moving=minf(1.,speed*4.)
	entry.feed=lerpf(entry.get("feed",0.),1. if entry.state in ["feed","forage"] else 0.,1.-exp(-dt*7.))
	entry.display=lerpf(entry.get("display",0.),1. if entry.state=="display" else 0.,1.-exp(-dt*7.))
	var near_wall=entry.surface!="rock" and Vector2(point.x,point.z).length()<float(entry.get("radius",1.))*1.07+.65
	entry.wall=lerpf(entry.get("wall",0.),1. if entry.surface=="wall" or near_wall else 0.,1.-exp(-dt*10.))
	var feed:float=entry.feed;var display:float=entry.display
	for leg in entry.legs:
		var cycle=fposmod(entry.gait+leg.phase,1.)
		var sweep=.065-.13*cycle/.65 if cycle<.65 else -.065+.13*smoothstep(.65,1.,cycle)
		var lift=0. if cycle<.65 else .045*sin((cycle-.65)/.35*PI)*moving
		var foot:Vector3=leg.rest;foot.x+=sweep*forward;foot.y=.018+lift
		var contact=model.transform*foot
		if entry.surface=="wall" or entry.surface=="seabed":
			contact=rock_contact(contact)
			var bed=floor_point(contact)
			contact.y=maxf(contact.y,bed.y+.012)
		place_leg(leg,model.transform.affine_inverse()*contact)
	entry.left.rotation=Vector3(.15*feed,0.,-.14-.72*display-.28*entry.panic-.19*feed*(.5+.5*sin(t*5.)))
	entry.right.rotation=Vector3(.12*feed,0.,.08+.24*feed*(.5+.5*sin(t*5.+1.2))+.18*entry.panic)
	entry.left.rotation.z=lerpf(entry.left.rotation.z,-.88,entry.wall);entry.right.rotation.z=lerpf(entry.right.rotation.z,.64,entry.wall)
	entry.finger_left.rotation.z=.22+.30*display+.28*feed*(.5+.5*sin(t*8.))
	entry.finger_right.rotation.z=-.18-.32*feed*(.5+.5*sin(t*8.+1.4))
	if entry.index==0:crab_state=entry.state

func rock_contact(point:Vector3)->Vector3:
	if point.y>=.014 or point.y< -5.5:return point
	var horizontal=Vector2(point.x,point.z)
	var width=lerpf(.94,1.07,clampf(-point.y/.25,0.,1.)) if point.y>-.25 else lerpf(1.07,.78,clampf((-point.y-.25)/5.25,0.,1.))
	var radius=rim_radius(horizontal.normalized())*width+.055
	var penetration=radius-horizontal.length()
	if penetration<=0.:return point
	if point.y>-.25 and -point.y<penetration:point.y=.014
	else:
		horizontal=horizontal.normalized()*radius;point.x=horizontal.x;point.z=horizontal.y
	return point

func place_leg(leg:Dictionary,target:Vector3):
	var hip:Vector3=leg.node.position;var delta=target-hip
	var first:Vector3=leg.upper;var second:Vector3=leg.lower
	var a=first.length();var b=second.length();var distance=clampf(delta.length(),absf(a-b)+.001,a+b-.001)
	var axis=delta.normalized();var bend=Vector3.UP.slide(axis).normalized()
	var along=(a*a+distance*distance-b*b)/(2.*distance)
	var knee=axis*along+bend*sqrt(maxf(0.,a*a-along*along))
	leg.node.quaternion=Quaternion(first.normalized(),knee.normalized())
	var lower=leg.node.basis.inverse()*(axis*distance-knee)
	leg.knee.quaternion=Quaternion(second.normalized(),lower.normalized())

func notice(kind:String):
	if kind=="seal":attention=3.2
	else:
		scuttle=2.2
		if not crabs.is_empty():crabs[0].reaction=2.2

func handle_tap(screen_pos:Vector2,camera:Camera3D)->bool:
	if not visible:return false
	var targets=[{"node":seal,"entry":{}}]
	for entry in crabs:targets.append({"node":entry.model,"entry":entry})
	for target in targets:
		var point:Vector3=target.node.global_position
		if camera.is_position_behind(point) or camera.unproject_position(point).distance_to(screen_pos)>24.:continue
		var n=(habitat.global_basis*habitat.to_local(point).normalized()).normalized() if habitat else global_basis.y
		if n.dot((camera.global_position-point).normalized())<.10:continue
		# The solid shelf blocks clicks on crabs hidden behind its column.
		var ray_start=to_local(camera.global_position);var ray_end=to_local(point)
		var blocked=false
		for i in range(1,24):
			var probe=ray_start.lerp(ray_end,float(i)/24.)
			if probe.y>=-.02 or probe.y< -5.5:continue
			var horizontal=Vector2(probe.x,probe.z)
			var radius=rim_radius(horizontal.normalized())
			var width=lerpf(.94,1.07,clampf(-probe.y/.25,0.,1.)) if probe.y>-.25 else lerpf(1.07,.78,clampf((-probe.y-.25)/5.25,0.,1.))
			if horizontal.length()<radius*width:blocked=true;break
		if blocked:continue
		if target.entry.is_empty():notice("seal")
		else:target.entry.reaction=2.2
		return true
	return false
