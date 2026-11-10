extends Node3D

# Rabbits use the same visible ground and building footprints as the worker.
# They never write learning, construction, inventory or save data.
const RABBIT=preload("res://assets/models/wild_rabbit.glb")
const SIZE=.66
const CLEARANCE=.29
const GRASS=["grove","meadow","sunreach","hill"]
var life
var world
var rabbits:Array=[]
var homes:Array=[]
var low_props:Array=[]
var land_count=-1
var navigation_signature=""
var refresh_wait=0.0

func setup(owner_life,initialize=true):
	life=owner_life;world=life.world
	if initialize:refresh_habitat()

func ground(p:Vector2)->Vector3:
	return world.ground_point(p) if world.has_method("ground_point") else world.surface(p)

func grass_safe(p:Vector2,avoid_actor=true)->bool:
	# Keep rabbit-sized building clearance even when a larger character loads.
	if not world.has_method("clear_ground") or not world.clear_ground(p,CLEARANCE,false):return false
	if not world.terrain.kind(world.terrain.cell_at(p)) in GRASS:return false
	for prop in low_props:
		if p.distance_squared_to(prop.center)<prop.radius*prop.radius:return false
	var center=ground(p);var low=center.length();var high=low
	# Test the entire footprint; a centre on land alone is insufficient at a shore.
	for i in range(8):
		var sample=p+Vector2.from_angle(i*TAU/8)*CLEARANCE
		if not world.on_land(sample):return false
		var height=ground(sample).length();low=minf(low,height);high=maxf(high,height)
	if high-low>.145:return false
	if avoid_actor:
		var builder=world.get("builder")
		if is_instance_valid(builder) and center.distance_to(builder.position)<.85:return false
	return true

func safe_route(a:Vector2,b:Vector2,avoid_actor=true)->bool:
	if a.distance_to(b)>.81 or world.terrain.chart_at(a)!=world.terrain.chart_at(b):return false
	if not world.clear_segment(a,b,CLEARANCE,false):return false
	var count=maxi(2,ceili(a.distance_to(b)/.09));var previous=ground(a)
	var builder=world.get("builder");var actor_limit=.85
	if avoid_actor and is_instance_valid(builder):actor_limit=minf(.85,previous.distance_to(builder.position))
	for i in range(count+1):
		var p=a.lerp(b,float(i)/count)
		if not grass_safe(p,false):return false
		var point=ground(p)
		# If a walking character enters the rabbit's space, allow a route that
		# increases separation. Requiring the starting point to be clear traps it.
		if avoid_actor and is_instance_valid(builder):
			var separation=point.distance_to(builder.position)
			if separation<actor_limit-.005 or (i==count and separation<.85):return false
			actor_limit=minf(.85,separation)
		if i>0 and absf(point.length()-previous.length())>.045:return false
		previous=point
	return true

func refresh_habitat(progressive=false):
	land_count=world.land.size();homes.clear()
	if not world.has_method("clear_ground"):return
	navigation_signature=str(world.get("navigation_signature"))
	cache_low_props()
	for cell in world.land:
		if progressive and not await world.game.startup_checkpoint():return
		if not world.terrain.kind(cell) in GRASS:continue
		var center=IslandFrontier.point(cell)
		# A stationary character can occupy all twelve old sample points while
		# safe grass remains between them. Search more of the same real ground.
		for radius in [.24,.48,.82,1.08]:
			for i in range(24):
				var p=center+Vector2.from_angle(i*TAU/24+.35)*radius
				if grass_safe(p):
					if world.terrain.kind(cell)=="meadow":homes.push_front(p)
					else:homes.append(p)
	var desired=2 if land_count>=18 else 1
	while rabbits.size()>desired:
		rabbits.pop_back().anchor.queue_free()
	for rabbit in rabbits:
		if rabbit.anchor.visible and grass_safe(rabbit.point,false):continue
		if not rabbit.anchor.visible and grass_safe(rabbit.point):
			rabbit.anchor.show();rabbit.fade=0.;rabbit.state="sniff";rabbit.elapsed=0.;rabbit.duration=2.
			place_rabbit(rabbit,0.);continue
		rabbit.anchor.hide()
		var candidate=find_home(rabbit.index)
		if candidate.is_finite():
			rabbit.point=candidate;rabbit.home=candidate;rabbit.state="sniff";rabbit.elapsed=0.;rabbit.duration=2.;rabbit.fade=0.
			rabbit.anchor.show();place_rabbit(rabbit,0.)
	while rabbits.size()<desired:
		var p=find_home(rabbits.size())
		if not p.is_finite():break
		spawn(p,rabbits.size())

func cache_low_props():
	# Navigation reserves buildings; rabbits additionally clear tree trunks,
	# rocks and low garden scenery, including decor that is batched for drawing.
	low_props.clear()
	var resources=world.get("resources")
	if resources is Array:
		for group in resources:
			for entry in group:low_props.append({"center":entry.p,"radius":CLEARANCE+.31*entry.base.x})
	var groups=world.get("decoration_groups")
	if not groups is Dictionary or not world.has_method("stable_point"):return
	for group in groups.values():
		for part in group.parts:
			if not is_instance_valid(part) or not part.mesh:continue
			var bounds=Rect2();var any=false
			for surface in part.mesh.get_surface_count():
				var vertices:PackedVector3Array=part.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
				for index in range(0,vertices.size(),maxi(1,vertices.size()/400)):
					var point:Vector3=world.stable_point(part,vertices[index]);var p:Vector2=world.terrain.coordinates(point)
					if not world.terrain.kind(world.terrain.cell_at(p)) in GRASS:continue
					if point.length()-world.surface(p).length()>.57:continue
					if any:bounds=bounds.expand(p)
					else:bounds=Rect2(p,Vector2.ZERO);any=true
			if any:low_props.append({"center":bounds.get_center(),"radius":bounds.size.length()*.5+CLEARANCE})

func find_home(index:int)->Vector2:
	if homes.is_empty():return Vector2(INF,INF)
	var fallback=Vector2(INF,INF)
	for step in range(homes.size()):
		var p:Vector2=homes[(step+index*13)%homes.size()]
		var clear=true
		for other in rabbits:
			if other.index!=index and ground(p).distance_to(ground(other.home))<1.3:clear=false;break
		if clear:
			if not fallback.is_finite():fallback=p
			var routes=0
			for direction in range(8):
				if safe_route(p,p+Vector2.from_angle(direction*TAU/8)*.30):routes+=1
			if routes>=3:return p
	return fallback

func spawn(p:Vector2,index:int):
	var anchor=Node3D.new();add_child(anchor)
	var model=RABBIT.instantiate();anchor.add_child(model);model.scale=Vector3.ONE*SIZE
	var joints={}
	for name in ["Body","Head","EarL","EarR","ForeL","ForeR","ForePawL","ForePawR","HindL","HindR","HindPawL","HindPawR","Tail"]:
		joints[name]=model.find_child(name,true,false)
	var rabbit={"index":index,"anchor":anchor,"model":model,"joints":joints,"point":p,"home":p,"from":p,"to":p,"heading":world.terrain.surface_basis(p)*Vector3.FORWARD,"state":"sniff","elapsed":0.,"duration":2.6+index,"cycle":index,"hops_left":0,"fade":0.,"route_check":0.,"look":Vector3.ZERO}
	rabbits.append(rabbit);place_rabbit(rabbit,0.)

func choose_hop(rabbit:Dictionary)->bool:
	var p:Vector2=rabbit.point
	var away=Vector2.ZERO;var builder=world.get("builder")
	if is_instance_valid(builder):
		var actor=world.terrain.coordinates(builder.position)
		if p.distance_to(actor)<1.0:away=(p-actor).normalized()
	for attempt in range(16):
		var angle=float(rabbit.cycle)*2.399+attempt*.73+rabbit.index
		var delta=Vector2.from_angle(angle)*(.25+.12*(attempt%3))
		if away!=Vector2.ZERO and delta.normalized().dot(away)<.12:continue
		var target=p+delta
		if target.distance_to(rabbit.home)>1.35:continue
		var crowded=false
		for other in rabbits:
			if other!=rabbit and ground(target).distance_to(other.anchor.position)<.70:crowded=true;break
		if crowded or not safe_route(p,target):continue
		rabbit.from=p;rabbit.to=target;rabbit.state="hop";rabbit.elapsed=0.;rabbit.duration=.66;rabbit.route_check=0.
		rabbit.turn_from=rabbit.heading;rabbit.hop_heading=(ground(target)-ground(p)).normalized()
		return true
	return false

func begin_rest(rabbit:Dictionary):
	rabbit.cycle+=1;rabbit.elapsed=0.;rabbit.hops_left=0
	rabbit.state=["sniff","sit","groom","sit"][rabbit.cycle%4]
	rabbit.duration=3.2+float(rabbit.cycle%3)*1.1

func animate(t:float,dt:float):
	if not world or not world.has_method("clear_ground"):return
	refresh_wait-=dt
	if refresh_wait<=0.:
		var missing=rabbits.size()<(2 if world.land.size()>=18 else 1)
		for rabbit in rabbits:
			if not rabbit.anchor.visible:missing=true
		refresh_wait=.25 if missing else .7
		# The worker can temporarily occupy every suitable starting patch while
		# walking out of spawn. Retry even when the static navigation is unchanged.
		if missing or land_count!=world.land.size() or navigation_signature!=str(world.get("navigation_signature")):refresh_habitat()
	for rabbit in rabbits:
		if not rabbit.anchor.visible:continue
		rabbit.elapsed+=minf(dt,.1);rabbit.fade=minf(1.,rabbit.fade+dt*3.)
		var lift=0.;var phase=0.
		if rabbit.state=="hop":
			phase=clampf(rabbit.elapsed/rabbit.duration,0.,1.)
			rabbit.heading=rabbit.turn_from.slerp(rabbit.hop_heading,smoothstep(0.,.18,phase)).normalized()
			var flight=clampf((phase-.16)/.66,0.,1.)
			# Translation happens only between takeoff and landing, with a planted
			# crouch and landing beat instead of skating while the paws are down.
			rabbit.route_check-=dt
			if rabbit.route_check<=0. and flight<1.:
				rabbit.route_check=.12
				if not safe_route(rabbit.point,rabbit.to):
					rabbit.from=rabbit.point;rabbit.to=rabbit.point;rabbit.hops_left=0
			var next_point:Vector2=rabbit.from.lerp(rabbit.to,flight)
			if not grass_safe(next_point,false):
				# Exact-frame guard catches a narrow edge between route samples.
				rabbit.from=rabbit.point;rabbit.to=rabbit.point;rabbit.hops_left=0
			else:rabbit.point=next_point
			lift=sin(flight*PI)*.17
			if phase>=1.:
				rabbit.point=rabbit.to;rabbit.hops_left-=1
				if rabbit.get("pending_alert",false):
					rabbit.pending_alert=false;notice(rabbit)
				elif rabbit.hops_left<=0 or not choose_hop(rabbit):begin_rest(rabbit)
		elif rabbit.elapsed>=rabbit.duration:
			rabbit.hops_left=2+(rabbit.cycle%2)
			if not choose_hop(rabbit):begin_rest(rabbit)
		elif rabbit.state=="alert":
			if rabbit.look.length_squared()>.1:rabbit.heading=rabbit.heading.slerp(rabbit.look,1.-exp(-dt*8.)).normalized()
		else:
			var builder=world.get("builder")
			if is_instance_valid(builder) and ground(rabbit.point).distance_to(builder.position)<1.05:
				rabbit.hops_left=2
				if not choose_hop(rabbit):rabbit.state="alert";rabbit.duration=rabbit.elapsed+.55
		pose(rabbit,t+rabbit.index*2.3,phase)
		place_rabbit(rabbit,lift)

func pose(rabbit:Dictionary,t:float,phase:float):
	var j:Dictionary=rabbit.joints
	for part in j.values():part.rotation=Vector3.ZERO
	rabbit.model.scale=Vector3.ONE*SIZE*maxf(.001,smoothstep(0.,1.,rabbit.fade))
	j.Body.scale=Vector3(1.,1.+.013*sin(t*2.2),1.)
	j.EarL.rotation=Vector3(.05*sin(t*1.2),.05,-.10-.06*sin(t*.63))
	j.EarR.rotation=Vector3(.04*sin(t*1.4+.8),-.04,.10+.08*sin(t*.77))
	j.Tail.rotation.x=.10*sin(t*1.5)
	if rabbit.state=="hop":
		var flight=clampf((phase-.16)/.66,0.,1.);var tuck=sin(flight*PI)
		j.Body.rotation.x=.10*sin(flight*TAU)
		j.Head.rotation.x=-.07*sin(flight*PI)
		for side in ["L","R"]:
			j["Fore"+side].rotation.x=-.60*tuck+.18*sin(flight*TAU)
			j["ForePaw"+side].rotation.x=.34*tuck
			j["Hind"+side].rotation.x=.40*sin(flight*TAU)-.22*tuck
			j["HindPaw"+side].rotation.x=-.22*sin(flight*TAU)+.25*tuck
		j.EarL.rotation.x=.18*tuck;j.EarR.rotation.x=.22*tuck
		var crouch=sin(clampf(phase/.16,0.,1.)*PI)*.06 if phase<.16 else sin(clampf((phase-.82)/.18,0.,1.)*PI)*.035 if phase>.82 else 0.
		j.Body.scale.y=1.-crouch
	elif rabbit.state=="sniff":
		j.Head.rotation.x=.17+.07*sin(t*5.2);j.Head.rotation.y=.18*sin(t*.9)
		j.EarL.rotation.x=.12;j.EarR.rotation.x=.07
	elif rabbit.state=="groom":
		var weight=smoothstep(0.,.4,rabbit.elapsed)*(1.-smoothstep(rabbit.duration-.4,rabbit.duration,rabbit.elapsed))
		j.Head.rotation.x=(.15+.07*sin(t*7.))*weight
		j.ForeL.rotation.x=(2.0+.12*sin(t*7.))*weight
		j.ForeR.rotation.x=(2.0+.12*sin(t*7.+.35))*weight
		j.ForePawL.rotation.x=.25*weight;j.ForePawR.rotation.x=.25*weight
	elif rabbit.state=="sit":
		j.Head.rotation.y=.22*sin(t*.7);j.Head.rotation.x=-.08
		j.EarL.rotation.z=-.24+.13*sin(t*.5);j.EarR.rotation.z=.11
	elif rabbit.state=="alert":
		j.Head.rotation.x=-.13;j.EarL.rotation.z=-.015;j.EarR.rotation.z=.015

func place_rabbit(rabbit:Dictionary,lift:float):
	var p:Vector2=rabbit.point
	if rabbit.get("ground_at",Vector2(INF,INF))!=p:
		var foot=ground(p)
		var dx=ground(p+Vector2(.05,0))-ground(p-Vector2(.05,0))
		var dz=ground(p+Vector2(0,.05))-ground(p-Vector2(0,.05))
		var up=dz.cross(dx).normalized()
		if up.dot(foot)<0.:up=-up
		if up.length_squared()<.5:up=foot.normalized()
		rabbit.ground_at=p;rabbit.ground_foot=foot;rabbit.ground_up=up
	var foot:Vector3=rabbit.ground_foot;var up:Vector3=rabbit.ground_up
	var forward:Vector3=rabbit.heading.slide(up).normalized()
	if forward.length_squared()<.5:forward=world.terrain.surface_basis(p)*Vector3.FORWARD
	rabbit.anchor.basis=Basis(forward.cross(up).normalized(),up,-forward).orthonormalized()
	rabbit.anchor.position=foot+up*(.008+lift)

func notice(rabbit:Dictionary):
	if rabbit.state=="hop" and rabbit.elapsed<rabbit.duration:
		rabbit.pending_alert=true;return
	rabbit.state="alert";rabbit.elapsed=0.;rabbit.duration=.75;rabbit.hops_left=2

func handle_tap(screen_pos:Vector2)->bool:
	var camera=world.game.camera
	for rabbit in rabbits:
		if not rabbit.anchor.visible:continue
		var target=rabbit.anchor.to_global(Vector3(0,.29,0))
		if camera.is_position_behind(target):continue
		var normal=world.globe.global_basis*rabbit.anchor.position.normalized()
		if normal.dot((camera.global_position-target).normalized())<.12:continue
		if camera.unproject_position(target).distance_to(screen_pos)>38.:continue
		rabbit.look=(world.globe.to_local(camera.global_position)-rabbit.anchor.position).normalized()
		notice(rabbit)
		return true
	return false
