extends Node3D

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
var coat:Skeleton3D
var chest_bone:int
var head_bone:int
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

# The container stays at the globe origin; each resident chooses its own coast.
var homes:Array=[]
var seal_mover:Dictionary={}
var navigation
var random=RandomNumberGenerator.new()
var ground_support_cache={}

func _ready():
	crab=CRAB.instantiate();add_child(crab);crab.scale=Vector3.ONE*.69
	seal=SEAL.instantiate();add_child(seal);seal.scale=Vector3.ONE*.77
	seal.position=Vector3(.14,0,.23);seal.rotation.y=PI*.5
	head=seal.find_child("Head",true,false);chest=seal.find_child("Chest",true,false);body=seal.find_child("Body",true,false)
	flipper=seal.find_child("FlipperL",true,false);other_flipper=seal.find_child("FlipperR",true,false)
	hind_left=seal.find_child("HindL",true,false);hind_right=seal.find_child("HindR",true,false)
	claw=crab.find_child("ClawL",true,false);other_claw=crab.find_child("ClawR",true,false)
	pincer_left=crab.find_child("PincerL",true,false);pincer_right=crab.find_child("PincerR",true,false)
	coat=seal.find_children("*","Skeleton3D",true,false)[0]
	chest_bone=coat.find_bone("CoatChest");head_bone=coat.find_bone("CoatHead")
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

	seal_mover=make_mover(seal,3,.77)

func make_crab_entry(model:Node3D,index:int,size:float)->Dictionary:
	var articulated=[]
	for side in ["L","R"]:
		for i in range(4):
			var joint=model.find_child("Leg"+side+str(i),true,false)
			var knee=joint.find_child("Knee*",true,false);var toe=joint.find_child("Toe*",true,false)
			articulated.append({"node":joint,"knee":knee,"toe":toe,"upper":knee.position,"lower":toe.position,"rest":joint.position+knee.position+toe.position,"phase":float(i%2)*.5+(.5 if side=="R" else 0.)})
	return {"model":model,"index":index,"size":size,"legs":articulated,"left":model.find_child("ClawL",true,false),"right":model.find_child("ClawR",true,false),"finger_left":model.find_child("PincerL",true,false),"finger_right":model.find_child("PincerR",true,false),"gait":0.,"last":Vector3.ZERO,"state":"rest","surface":"rock","route_valid":false,"panic":0.,"reaction":0.}

func make_mover(model:Node3D,index:int,size:float)->Dictionary:
	var contacts=[]
	for part in model.find_children("*","MeshInstance3D",true,false):
		for surface in part.mesh.get_surface_count():
			var points=part.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			for i in range(0,points.size(),maxi(1,points.size()/32)):
				contacts.append({"node":part,"point":points[i]})
	return {"model":model,"index":index,"size":size,"contacts":contacts,"route":[],"ups":[],"surfaces":[],"segment":0,"distance":0.,"phase":"forage","wait":6.+index*2.,"home":{},"point":Vector3.ZERO,"up":Vector3.UP,"heading":Vector3.FORWARD,"moving":false,"surface":"seabed","gait":0.,"reaction":0.,"panic":0.,"last":Vector3.ZERO}

func choose_coast(life):
	habitat=life;position=Vector3.ZERO;basis=Basis.IDENTITY
	if navigation==null:
		navigation=preload("res://scripts/shore_routes.gd").new(life);random.randomize()
	navigation.land_count=-1;homes.clear();ground_support_cache.clear()
	var world=life.world
	var steps=[Vector2i(1,0),Vector2i(0,1),Vector2i(-1,1),Vector2i(-1,0),Vector2i(0,-1),Vector2i(1,-1)]
	for cell in world.land:
		if world.terrain.kind(cell)=="rocket":continue
		var center=IslandFrontier.point(cell)
		for step in steps:
			if world.land.has(cell+step):continue
			var out=(IslandFrontier.point(cell+step)-center).normalized()
			for shift in [0.,-.30,.30]:
				var edge_center=center+Vector2(-out.y,out.x)*shift
				var dry=edge_center+out*.82
				if not world.clear_ground(dry,.34,false):continue
				var ground:Vector3=world.ground_point(dry)
				if ground.length()>12.65:continue
				var safe=true
				for group in world.resources:
					for resource in group:
						if resource.p.distance_to(dry)<.56:safe=false
				for prop in life.land_life.low_props:
					if minf(prop.center.distance_to(dry),prop.center.distance_to(dry-out*.35))<prop.radius+.06:safe=false
				if not safe:continue
				var edge=edge_center+out*(IslandFrontier.HEX*.866-.04)
				if not world.clear_segment(dry,edge_center+out*.88,.12,false):continue
				var sea=life.sea_direction(edge_center+out*3.1)
				if not navigation.clear_arc(sea,sea):continue
				var top:Vector3=world.ground_point(edge)
				var lip=life.sea_direction(edge_center+out*(IslandFrontier.HEX*.866+.40))
				var outward=(lip-top.normalized()).slide(top.normalized()).normalized()
				var floor=seabed_point(lip)
				var shore=[ground+ground.normalized()*.035,top+top.normalized()*.04,lip*(top.length()+.04),floor,seabed_point(sea)]
				var ups=[ground.normalized(),top.normalized(),(lip+outward).normalized(),floor.normalized(),sea]
				# Check the wet approach against rocks and the cave, too.
				for i in range(13):
					var n=lip.slerp(sea,float(i)/12.)
					if not life.clear_of_cave(n,.72) or not life.clear_of_seabed_props(n,.55,IslandWater.MAX_DEPTH):safe=false;break
				var side=Vector2(-out.y,out.x)
				var seal_room=world.clear_segment(dry-side*.55,dry+side*.55,.21,false)
				for prop in life.land_life.low_props:
					var nearest=Geometry2D.get_closest_point_to_segment(prop.center,dry-side*.55,dry+side*.55)
					if nearest.distance_to(prop.center)<prop.radius:seal_room=false;break
				if safe:homes.append({"seal_room":seal_room,"cell":cell,"chart":world.terrain.chart_at(center),"dry":dry,"sea":sea,"shore":shore,"ups":ups})
	show()
	var residents=crabs+[seal_mover]
	for entry in residents:
		if not entry.has("route"):
			var mover=make_mover(entry.model,entry.index,entry.size)
			for key in mover:entry[key]=mover[key]
		if entry.point==Vector3.ZERO and not homes.is_empty():
			entry.home=homes[(entry.index*maxi(1,homes.size()/residents.size()))%homes.size()]
			var n:Vector3=entry.home.sea
			for attempt in range(24):
				var candidate=life.offset_direction(n,Vector2.from_angle(attempt*2.4)*(.8+.4*(attempt/8)))
				if not navigation.clear_arc(candidate,candidate):continue
				var separated=true
				for other in residents:
					if other!=entry and other.get("point",Vector3.ZERO)!=Vector3.ZERO and other.point.distance_to(seabed_point(candidate))<resident_radius(other)+resident_radius(entry):separated=false
				if separated:n=candidate;break
			entry.point=seabed_point(n);entry.up=n
		elif entry.point!=Vector3.ZERO:
			# Replan unfinished water travel after land changes; retain position.
			entry.route=[];entry.phase="forage";entry.wait=.5
			recover_coast(entry)
		entry.model.visible=entry.point!=Vector3.ZERO
		if entry.model.visible:place_mover(entry,0.)
	normal=seal_mover.point.normalized() if seal_mover.point!=Vector3.ZERO else Vector3.UP

func seabed_point(n:Vector3)->Vector3:
	return n.normalized()*(habitat.world.water.floor_radius(n.normalized())+.045)

func recover_coast(entry:Dictionary):
	var world=habitat.world;var n:Vector3=entry.point.normalized()
	if navigation.clear_arc(n,n):return
	var coordinate=world.terrain.coordinates(n)
	if world.on_land(coordinate):
		entry.point=world.ground_point(coordinate)+n*.045;entry.up=n
		entry.phase="seek_shore";entry.surface="land";entry.wait=.8
		var nearby=homes.duplicate()
		nearby.sort_custom(func(a,b):return a.dry.distance_squared_to(coordinate)<b.dry.distance_squared_to(coordinate))
		for home in nearby:
			if world.terrain.chart_at(coordinate)!=home.chart:continue
			if shore_occupied(home,entry) or (entry.index==3 and not home.seal_room):continue
			var walk=world.walking_route(coordinate,home.dry)
			if walk.is_empty():continue
			var points=[entry.point];var ups=[n];var surfaces=[]
			for point in walk:
				var ground:Vector3=world.ground_point(point);points.append(ground+ground.normalized()*.045);ups.append(ground.normalized());surfaces.append("land")
			for i in range(home.shore.size()):points.append(home.shore[i]);ups.append(home.ups[i]);surfaces.append("shore" if i<4 else "seabed")
			entry.home=home;set_route(entry,points,ups,surfaces);entry.phase="depart";return
	else:
		for attempt in range(48):
			var end=habitat.offset_direction(n,Vector2.from_angle(attempt*2.399)*(.8+.4*(attempt/12)))
			if not navigation.clear_arc(end,end):continue
			var points=[entry.point];var ups=[n];var surfaces=[];var safe=true
			for i in range(1,17):
				var probe=n.slerp(end,float(i)/16.)
				if world.on_land(world.terrain.coordinates(probe)):safe=false;break
				points.append(seabed_point(probe));ups.append(probe);surfaces.append("seabed")
			if safe:set_route(entry,points,ups,surfaces);entry.phase="depart";return

func shore_occupied(home:Dictionary,entry:Dictionary)->bool:
	for other in crabs+[seal_mover]:
		if other.index==entry.index or other.home.is_empty() or other.phase not in ["travel","rest","depart"]:continue
		var clearance=resident_radius(entry)+resident_radius(other)+.12
		# Two different beaches can share the same way around a headland.
		# Reserve the approach as well as the dry resting point.
		if home.shore[0].distance_to(other.home.shore[0])>9.:continue
		for i in range(home.shore.size()-1):
			for j in range(other.home.shore.size()-1):
				var near=Geometry3D.get_closest_points_between_segments(home.shore[i],home.shore[i+1],other.home.shore[j],other.home.shore[j+1])
				if near[0].distance_to(near[1])<clearance:return true
	return false

func set_route(entry:Dictionary,points:Array,ups:Array,surfaces:Array):
	entry.route=points;entry.ups=ups;entry.surfaces=surfaces;entry.segment=0;entry.distance=0.

func leave_shore(entry:Dictionary):
	set_route(entry,entry.home.shore.duplicate(),entry.home.ups.duplicate(),["shore","shore","shore","seabed"])
	entry.phase="depart"

func visit_shore(entry:Dictionary)->bool:
	if homes.is_empty():return false
	if homes.size()<4:
		for other in crabs+[seal_mover]:
			if other!=entry and other.phase in ["forage","roam"] and other.get("queue_time",0.)>entry.get("queue_time",0.)+.01:return false
	navigation.rebuild()
	var start=entry.point.normalized();var choices=homes.duplicate()
	var other_chart=entry.home.get("chart",-1)
	# Give newly opened islands a turn, while allowing every usable shore.
	var seed=random.randi()
	choices.sort_custom(func(a,b):
		var av=(0. if a.chart!=other_chart else 2.)+float(posmod(hash(a.dry)^seed,1000))/1000.
		var bv=(0. if b.chart!=other_chart else 2.)+float(posmod(hash(b.dry)^seed,1000))/1000.
		return av<bv)
	for home in choices:
		if shore_occupied(home,entry) or (entry.index==3 and not home.seal_room):continue
		var route=navigation.sea_path(start,home.sea)
		if route.is_empty():continue
		var points=[entry.point];var ups=[entry.up];var surfaces=[]
		for i in range(1,route.size()):
			var count=maxi(1,ceili(route[i-1].angle_to(route[i])*IslandWater.BASE_RADIUS/.20))
			for step in range(1,count+1):
				var n:Vector3=route[i-1].slerp(route[i],float(step)/count).normalized()
				points.append(seabed_point(n));ups.append(n);surfaces.append("seabed")
		for i in range(home.shore.size()-2,-1,-1):
			points.append(home.shore[i]);ups.append(home.ups[i]);surfaces.append("shore" if i<3 else "seabed")
		entry.home=home;set_route(entry,points,ups,surfaces);entry.phase="travel";entry.queue_time=0.
		return true
	return false

# Conservative horizontal envelopes include the tip of the tail and the claws.
func resident_radius(entry:Dictionary)->float:
	return entry.size*(1.09 if entry.index==3 else .62)

func blocked_by(entry:Dictionary,next_point:Vector3)->Dictionary:
	for other in crabs+[seal_mover]:
		if entry.index==other.index or other.get("point",Vector3.ZERO)==Vector3.ZERO:continue
		var distance=next_point.distance_to(other.point)
		if distance<resident_radius(entry)+resident_radius(other) and distance<entry.point.distance_to(other.point):
			return other
	return {}

func detour(entry:Dictionary,other:Dictionary):
	var n:Vector3=entry.point.normalized()
	var away:Vector3=(entry.point-other.point).slide(n).normalized()
	for turn in [1.,-1.,0.]:
		var direction=(away+n.cross(away)*turn).normalized()
		var end=(entry.point+direction*.85).normalized()
		if not navigation.clear_arc(n,end):continue
		var target=seabed_point(end)
		if not blocked_by(entry,target).is_empty():continue
		set_route(entry,[entry.point,target],[n,end],["seabed"])
		entry.phase="roam";entry.blocked_time=0.;return

func advance_mover(entry:Dictionary,dt:float):
	entry.moving=false
	if entry.point==Vector3.ZERO:return
	if entry.phase=="rest" and entry.index==3:
		entry.heading=entry.up.cross(entry.home.shore[1]-entry.home.shore[0]).normalized()
	if entry.phase in ["forage","roam"]:entry.queue_time=entry.get("queue_time",0.)+dt
	if entry.route.is_empty():
		entry.wait-=dt
		if entry.wait<=0.:
			if entry.phase=="seek_shore":recover_coast(entry)
			elif entry.phase=="rest":leave_shore(entry)
			elif not visit_shore(entry):
				entry.wait=5.
				var n:Vector3=entry.point.normalized()
				var end=habitat.offset_direction(n,Vector2.from_angle(random.randf()*TAU)*.6)
				if navigation.clear_arc(n,end):
					set_route(entry,[entry.point,seabed_point(end)],[n,end],["seabed"]);entry.phase="roam"
	else:
		var speed=.33 if entry.index==3 else .16
		if entry.surface=="shore":speed*=.65
		entry.distance+=dt*speed*(1.+entry.panic*.55)
		while entry.segment<entry.route.size()-1:
			var a:Vector3=entry.route[entry.segment];var b:Vector3=entry.route[entry.segment+1]
			var length=a.distance_to(b)
			if entry.distance<length and length>.0001:
				var amount=entry.distance/length
				var next_point=a.lerp(b,amount)
				var blocker=blocked_by(entry,next_point)
				if not blocker.is_empty():
					entry.distance=maxf(0.,entry.distance-dt*speed*(1.+entry.panic*.55))
					entry.blocked_time=entry.get("blocked_time",0.)+dt
					if entry.blocked_time>.45 and entry.surfaces[entry.segment]=="seabed":detour(entry,blocker)
					break
				entry.blocked_time=0.
				entry.point=next_point;entry.up=entry.ups[entry.segment].slerp(entry.ups[entry.segment+1],amount).normalized()
				entry.surface=entry.surfaces[entry.segment]
				if entry.surface=="seabed":
					entry.point=seabed_point(entry.point.normalized());entry.up=seabed_up(entry.point.normalized())
				entry.heading=(b-a).normalized();entry.moving=true;break
			entry.distance-=length;entry.segment+=1;entry.point=b
		if entry.segment>=entry.route.size()-1:
			entry.up=entry.ups[-1];entry.route=[]
			entry.phase="forage" if entry.phase in ["depart","roam"] else "rest"
			entry.surface="seabed" if entry.phase=="forage" else "land"
			entry.wait=random.randf_range(8.,18.)
	place_mover(entry,dt)

func place_mover(entry:Dictionary,dt:float):
	if entry.surface=="seabed":entry.up=seabed_up(entry.point.normalized())
	elif entry.surface=="land":entry.up=land_up(entry.point)
	var point:Vector3=entry.point;var up:Vector3=entry.up
	var forward:Vector3=entry.heading.slide(up).normalized()
	if forward.length_squared()<.1:forward=habitat.tangent_axes(up)[0]
	var frame=habitat.frame_at(up,forward)
	# Crabs travel sideways; seals face their route.
	if entry.index!=3:frame=frame.rotated(up,PI*.5)
	var previous:Vector3=entry.last
	if previous!=Vector3.ZERO:entry.gait+=previous.distance_to(point)/(.18*entry.size)
	entry.last=point
	entry.model.position=point+point.normalized()*entry.get("support_lift",0.)
	var rotation=frame.get_rotation_quaternion()
	entry.model.quaternion=entry.model.quaternion.slerp(rotation,1.-exp(-dt*7.)) if dt>0 else rotation
	entry.model.scale=Vector3.ONE*entry.size

func seabed_up(n:Vector3)->Vector3:
	var a=seabed_point(habitat.offset_direction(n,Vector2(.12,0)))-seabed_point(habitat.offset_direction(n,Vector2(-.12,0)))
	var b=seabed_point(habitat.offset_direction(n,Vector2(0,.12)))-seabed_point(habitat.offset_direction(n,Vector2(0,-.12)))
	var up=a.cross(b).normalized()
	return up if up.dot(n)>0 else -up

func land_up(point:Vector3)->Vector3:
	var world=habitat.world;var p=world.terrain.coordinates(point)
	var a=world.ground_point(p+Vector2(.12,0))-world.ground_point(p-Vector2(.12,0))
	var b=world.ground_point(p+Vector2(0,.12))-world.ground_point(p-Vector2(0,.12))
	var up=a.cross(b).normalized()
	return up if up.dot(point)>0 else -up

func animate(t:float,dt:float):
	if not visible:return
	attention=maxf(0,attention-dt);attention_blend=lerpf(attention_blend,smoothstep(0.,.8,attention),1.-exp(-dt*8.))
	if habitat:
		advance_mover(seal_mover,dt)
		for entry in crabs:
			entry.reaction=maxf(0.,entry.reaction-dt);entry.panic=lerpf(entry.panic,smoothstep(0.,.65,entry.reaction),1.-exp(-dt*9.))
			advance_mover(entry,dt)
			normal=seal_mover.point.normalized()
	animate_seal(t)
	for entry in crabs:animate_crab(entry,t,dt)
	if habitat:
		for entry in crabs+[seal_mover]:support_surface(entry,dt)

func support_surface(entry:Dictionary,dt:float):
	if entry.point==Vector3.ZERO:return
	entry.support_wait=entry.get("support_wait",0.)-dt
	if entry.support_wait>0. and entry.get("support_surface","")==entry.surface:return
	entry.support_wait=.05;entry.support_surface=entry.surface
	var lift=-INF
	# Fit the actual posed fins, belly and feet to curved basin floors. The
	# movement path itself remains continuous; only ground support is lifted.
	var old:float=entry.get("support_lift",0.)
	var near_shore=entry.surface=="shore" and absf(entry.point.length()-entry.home.shore[1].length())<.33
	if entry.surface in ["seabed","land"] or near_shore:
		for contact in entry.contacts:
			var p=to_local(contact.node.to_global(contact.point))-entry.point.normalized()*old
			var height=habitat.world.water.floor_radius(p.normalized())
			if entry.surface=="land" or near_shore:
				var coordinate=habitat.world.terrain.coordinates(p)
				if habitat.world.on_land(coordinate):
					var key=Vector2i(roundi(coordinate.x*40.),roundi(coordinate.y*40.))
					if not ground_support_cache.has(key):ground_support_cache[key]=habitat.world.ground_point(coordinate).length()
					height=ground_support_cache[key]
			lift=maxf(lift,height+.012-p.length())
	lift=maxf(-.07,lift) if is_finite(lift) else 0.
	lift=maxf(lift,lerpf(old,lift,1.-exp(-maxf(dt,.05)*7.)))
	entry.support_lift=lift
	entry.model.position=entry.point+entry.point.normalized()*lift

func rotate_coat_joint(index:int,joint:Node3D):
	var parent=coat.get_bone_parent(index)
	var axes=coat.get_bone_global_rest(parent).basis.orthonormalized()
	var rest=coat.get_bone_rest(index).basis.orthonormalized()
	coat.set_bone_pose_rotation(index,(axes.inverse()*joint.basis*axes*rest).get_rotation_quaternion())

func animate_seal(t:float):
	var swimming=habitat and seal_mover.surface=="seabed"
	var moving=habitat and seal_mover.moving
	var phase=fposmod(t,20.)
	var stretch=smoothstep(2.,3.5,phase)*(1.-smoothstep(5.,7.,phase)) if not moving else 0.
	var roll=.22*smoothstep(9.,11.,phase)*(1.-smoothstep(14.,16.,phase)) if not swimming and not moving else 0.
	seal_state="swim" if swimming and moving else "forage" if swimming else "scoot" if moving else "stretch" if stretch>.1 else "sunbathe" if roll>.05 else "look"
	var stroke=sin(t*(4. if swimming else 6.)) if moving else 0.
	body.scale=Vector3(1.+.018*stroke,1.+.012*sin(t*1.8),1.-.025*stroke)
	body.rotation.z=roll
	chest.rotation.x=.12*stretch+.055*attention_blend+.045*stroke
	head.rotation.x=.04*sin(t*.9)-.23*attention_blend+.10*stretch
	head.rotation.y=.22*sin(t*.48)+.20*attention_blend
	rotate_coat_joint(chest_bone,chest);rotate_coat_joint(head_bone,head)
	flipper.rotation=Vector3(.08*stroke,.13*stroke,-.10-.22*stretch-.18*stroke)
	other_flipper.rotation=Vector3(-.08*stroke,-.13*stroke,.10+.22*stretch+.18*stroke)
	hind_left.rotation=Vector3(0.,.30*stroke,-.09-.10*stroke)
	hind_right.rotation=Vector3(0.,.30*stroke,.09+.10*stroke)
	if not habitat:
		seal.position=Vector3(.14,.04,.23);seal.rotation.y=PI*.5

func animate_crab(entry:Dictionary,t:float,dt:float):
	var model:Node3D=entry.model
	if not habitat:model.position=Vector3(-.60+entry.index*.60,.006,-.38)
	var moving=entry.get("moving",false)
	entry.state="retreat" if entry.panic>.2 else "seabed_walk" if moving and entry.surface=="seabed" else "climb" if moving else "forage" if entry.surface=="seabed" else "feed"
	var feed=0. if moving else 1.
	for leg in entry.legs:
		var cycle=fposmod(entry.gait+leg.phase,1.)
		var sweep=(.065-.13*cycle/.65 if cycle<.65 else -.065+.13*smoothstep(.65,1.,cycle)) if moving else 0.
		var lift=.045*sin((cycle-.65)/.35*PI) if moving and cycle>.65 else 0.
		var foot:Vector3=leg.rest;foot.x+=sweep;foot.y=.018+lift
		place_leg(leg,foot)
	entry.left.rotation=Vector3(.15*feed,0.,-.14-.28*entry.panic-.19*feed*(.5+.5*sin(t*5.)))
	entry.right.rotation=Vector3(.12*feed,0.,.08+.24*feed*(.5+.5*sin(t*5.+1.2))+.18*entry.panic)
	entry.finger_left.rotation.z=.22+.28*feed*(.5+.5*sin(t*8.))
	entry.finger_right.rotation.z=-.18-.32*feed*(.5+.5*sin(t*8.+1.4))
	if entry.index==0:crab_state=entry.state

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
		if not target.node.is_visible_in_tree():continue
		var point:Vector3=target.node.global_position
		if camera.is_position_behind(point) or camera.unproject_position(point).distance_to(screen_pos)>24.:continue
		var n=(habitat.global_basis*target.node.position.normalized()).normalized() if habitat else global_basis.y
		if n.dot((camera.global_position-point).normalized())<.10:continue
		if target.entry.is_empty():notice("seal")
		else:target.entry.reaction=2.2
		return true
	return false
