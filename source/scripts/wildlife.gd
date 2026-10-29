extends Node3D
class_name IslandWildlife

# Decorative populations share real water and sea-floor heights, without changing learning.
var world
var animals:Array=[]
var clock=0.0
var land_count=-1
var coast:Array=[]
var offshore:Array=[]
var meadows:Array=[]
var water_effects:Array=[]
var bird_scene=preload("res://assets/models/wild_bird.glb")
var fish_scene=preload("res://assets/models/wild_fish.glb")
var butterfly_scene=preload("res://assets/models/wild_butterfly.glb")
var whale_scene=preload("res://assets/models/wild_whale.glb")
var water_math=preload("res://scripts/water.gd")
var spray_material:StandardMaterial3D

func setup(owner_world):
	world=owner_world
	if get_parent()!=world.globe:reparent(world.globe,false)
	position=Vector3.ZERO;basis=Basis.IDENTITY
	spray_material=StandardMaterial3D.new();spray_material.albedo_color=Color("D1F3F0");spray_material.roughness=.18
	refresh_habitats()

func sea_direction(p:Vector2)->Vector3:
	return Vector3(p.x,sqrt(maxf(.1,144-p.length_squared())),p.y).normalized()
func available_depth(p:Vector2)->float:
	var water=world.get("water")
	return float(water.depth_at(sea_direction(p))) if water and water.has_method("depth_at") else 0.0
func body_depth(p:Vector2,radius:float)->float:
	var depth=available_depth(p)
	for i in range(8):depth=minf(depth,available_depth(p+Vector2(cos(i*TAU/8),sin(i*TAU/8))*radius))
	return depth
func water_at(p:Vector2,margin=0.0)->bool:
	if p.length()>11.65:return false
	for cell in world.land:
		var q=(p-IslandFrontier.point(cell)).abs();var h=IslandFrontier.HEX*1.13+margin
		if q.x<sqrt(3.0)*h*.5 and q.y<h and q.x/sqrt(3.0)+q.y<h:return false
	return true
func safe_sea(p:Vector2,margin:float,minimum_depth:float)->bool:
	if not water_at(p,margin) or available_depth(p)<minimum_depth:return false
	for i in range(8):
		var edge=p+Vector2(cos(i*TAU/8),sin(i*TAU/8))*margin
		if not water_at(edge) or available_depth(edge)<minimum_depth:return false
	return true

func refresh_habitats():
	# World setup creates the ocean before land. Refresh its real sea floor now,
	# before choosing the very first fish/whale route or a route after expansion.
	var water=world.get("water")
	if water and water.has_method("rebuild") and water.get("land_count")!=world.land.size():water.rebuild()
	land_count=world.land.size();coast.clear();offshore.clear();meadows.clear()
	var steps=[Vector2i(1,0),Vector2i(0,1),Vector2i(-1,1),Vector2i(-1,0),Vector2i(0,-1),Vector2i(1,-1)]
	for cell in world.land:
		var center=IslandFrontier.point(cell);var region=world.terrain.kind(cell)
		if region in ["grove","shore","meadow","wetland","hill"]:meadows.append(center+Vector2(.55,.42))
		for step in steps:
			if world.land.has(cell+step):continue
			var direction=(IslandFrontier.point(cell+step)-center).normalized()
			var p=center+direction*IslandFrontier.HEX*1.92
			if water_at(p) and available_depth(p)>.45:coast.append(p)
			p=center+direction*IslandFrontier.HEX*2.85
			if water_at(p) and available_depth(p)>.75:offshore.append(p)
	if meadows.is_empty():meadows.append(Vector2.ZERO)
	if coast.is_empty():coast.assign(offshore)
	var desired={"bird":mini(4,1+land_count/8),"fish":mini(32,12+(land_count/6)*4),"butterfly":mini(6,1+land_count/6),"whale":2 if land_count>=18 else 1}
	for kind in desired:
		var count=0
		for animal in animals:
			if animal.kind==kind:count+=1
		while count<int(desired[kind]):spawn(kind,count);count+=1
	for animal in animals:
		if animal.kind=="fish":
			if not water_at(animal.home) or available_depth(animal.home)<.45:animal.home=habitat("fish",animal.index)
			animal.radius=swim_radius(animal.home)
		elif animal.kind=="whale":configure_whale(animal)

func swim_radius(home:Vector2)->float:
	for radius in [.95,.72,.48,.28,.12]:
		var safe=true
		for i in range(32):
			var a=i*TAU/32
			if not safe_sea(home+Vector2(sin(a)*radius,cos(a)*radius*.66),.14,.40):safe=false;break
		if safe:return radius
	return 0.0

func habitat(kind:String,index:int)->Vector2:
	if kind=="fish":
		var group=index/4;var pool=offshore if group%2==1 and not offshore.is_empty() else coast
		if not pool.is_empty():return pool[(group*3+1)%pool.size()]
	return meadows[(index*5)%meadows.size()]

func spawn(kind:String,index:int):
	var anchor=Node3D.new();add_child(anchor)
	var scene=bird_scene if kind=="bird" else fish_scene if kind=="fish" else whale_scene if kind=="whale" else butterfly_scene
	var model=scene.instantiate();anchor.add_child(model)
	var scale_factor=.68 if kind=="bird" else (.48+float(index%3)*.035) if kind=="fish" else (.65 if index==0 else .49) if kind=="whale" else .66
	model.scale=Vector3.ONE*scale_factor
	for mesh in model.find_children("*","MeshInstance3D",true,false):mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	animals.append({"kind":kind,"index":index,"anchor":anchor,"model":model,"home":habitat(kind,index),"radius":.7,"phase":float(index/4)*1.87 if kind=="fish" else index*5.5,"startle":0.0,"left":model.find_child("FlipperL" if kind=="whale" else "WingL",true,false),"right":model.find_child("FlipperR" if kind=="whale" else "WingR",true,false),"tail":model.find_child("Tail",true,false),"fluke":model.find_child("Fluke",true,false),"blowhole":model.find_child("Blowhole",true,false),"last":Vector3.ZERO,"state":"swim","breath_cycle":-1,"route_valid":true,"depth":.3})

func water_point(p:Vector2,depth=.28)->Vector3:
	return water_point_normal(sea_direction(p),depth)
func water_point_normal(normal:Vector3,depth:float)->Vector3:
	var time=float(world.get("time")) if world.get("time")!=null else clock
	return normal*(water_math.surface_radius(normal,time)-depth)

func deep_sea(normal:Vector3,margin:float,minimum_depth:float)->bool:
	var water=world.get("water")
	if not water or water.depth_at(normal)<minimum_depth:return false
	for cell in world.land:
		var center=world.surface(IslandFrontier.point(cell)).normalized()
		if normal.distance_to(center)*12<IslandFrontier.HEX+margin:return false
	var side=normal.cross(Vector3.UP).normalized()
	if side.length_squared()<.1:side=Vector3.RIGHT
	var forward=side.cross(normal).normalized()
	for i in range(8):
		var around=(normal+(side*cos(i*TAU/8)+forward*sin(i*TAU/8))*margin/12.0).normalized()
		if water.depth_at(around)<minimum_depth:return false
	return true
func whale_direction(animal:Dictionary,t:float)->Vector3:
	return (animal.route_center+(animal.route_side*sin(t*.16)+animal.route_forward*cos(t*.16)*.6)*animal.radius/12.0).normalized()
func configure_whale(animal:Dictionary):
	# Wide sea lanes leave room for the complete hull and tail, including while surfacing.
	# Spherical routes also use the broad ocean beyond the northern land-cap.
	var candidates=[Vector3(0,.30,1),Vector3(-.75,.20,.65),Vector3(.78,.16,.65),Vector3(0,-.16,1),Vector3(-.5,-.35,.8),Vector3(.5,-.35,.8),Vector3(0,-.7,.7),Vector3.DOWN]
	if animal.index==1:candidates=candidates.slice(2)+candidates.slice(0,2)
	animal.route_valid=false
	for home in candidates:
		animal.route_center=home.normalized();animal.route_side=animal.route_center.cross(Vector3.UP).normalized()
		if animal.route_side.length_squared()<.1:animal.route_side=Vector3.RIGHT
		animal.route_forward=animal.route_side.cross(animal.route_center).normalized()
		for radius in [1.70,1.25,.85]:
			animal.radius=radius
			var safe=true
			for i in range(32):
				var normal=whale_direction(animal,i*TAU/32/.16)
				if not deep_sea(normal,1.70 if animal.index==0 else 1.30,1.25):safe=false;break
			if safe:
				animal.route_valid=true;return

func frame_at(point:Vector3,forward:Vector3)->Basis:
	var up=point.normalized();var tangent=forward-up*forward.dot(up)
	if tangent.length_squared()<.00000001:
		tangent=(Vector3.FORWARD if absf(up.z)<.85 else Vector3.RIGHT).slide(up)
	var right=tangent.cross(up).normalized()
	# Reconstruct the third axis: normalizing a tiny projected delta alone can retain
	# enough radial rounding error to make Basis.slerp reject a nearly stopped fish.
	return Basis(right,up,right.cross(up).normalized()).orthonormalized()

func whale_position(animal:Dictionary,t:float)->Vector3:
	var normal=whale_direction(animal,t)
	animal.anchor.visible=animal.route_valid and deep_sea(normal,1.60 if animal.index==0 else 1.20,1.15)
	var cycle=int(t/44.0);var phase=fmod(t,44.0);var depth=.65+sin(t*.5)*.045;var pitch=sin(t*1.1)*.035;var state="swim"
	if phase>=8 and phase<11:depth=lerpf(.65,.18,smoothstep(0,1,(phase-8)/3));state="rise"
	elif phase>=11 and phase<15:
		depth=.18;state="breathe"
		if animal.breath_cycle!=cycle:
			animal.breath_cycle=cycle
			if animal.last!=Vector3.ZERO:water_burst(animal.blowhole.global_position,animal.anchor.position.normalized(),false)
	elif phase>=15 and phase<18:depth=lerpf(.18,.65,smoothstep(0,1,(phase-15)/3));pitch=.16*sin((phase-15)*PI/3);state="dive"
	elif cycle%2==0 and phase>=26 and phase<29:
		var u=(phase-26)/3;depth=.65-sin(u*PI)*1.35;pitch=-.75*sin(u*TAU);state="breach"
	if animal.state=="breach" and state!="breach":
		water_burst(to_global(water_point_normal(normal,0)),normal,true)
		var water=world.get("water")
		if water and water.has_method("ripple"):water.ripple(normal,1.2)
	animal.state=state;animal.depth=depth
	animal.model.rotation.x=pitch;animal.model.rotation.z=sin(t*.65)*.035
	animal.tail.rotation.x=sin(t*2.0)*.20;animal.fluke.rotation.x=sin(t*2.0-.55)*.18
	animal.left.rotation.z=-.13+sin(t*1.3)*.10;animal.right.rotation.z=.13-sin(t*1.3)*.10
	return water_point_normal(normal,depth)

func _process(dt):
	if not is_instance_valid(world):return
	clock+=dt
	if land_count!=world.land.size():refresh_habitats()
	for animal in animals:
		animal.startle=maxf(0,animal.startle-dt)
		animal.phase+=dt*(1.8 if animal.startle>0 and animal.kind!="whale" else 1.0)
		var t=animal.phase;var p:Vector2=animal.home;var pos:Vector3
		if animal.kind=="fish":
			var slot=animal.index%4;var a=t*.65-slot*.72
			p+=Vector2(sin(a)*animal.radius,cos(a)*animal.radius*.66)*(1.0-float(slot%2)*.14)
			var depth=(.34 if (animal.index/4)%2==0 else .58)+float(slot)*.026+sin(t*1.3)*.045
			var bed=body_depth(p,.30)
			depth=minf(depth,maxf(.20,bed-.19));animal.depth=depth
			animal.anchor.visible=not coast.is_empty() and water_at(p) and bed>.39
			pos=water_point(p,depth)
			if animal.tail:animal.tail.rotation.y=sin(t*8)*.36
			animal.model.rotation.y=sin(t*8-.4)*.045;animal.model.rotation.z=sin(t*.65)*.08
		elif animal.kind=="whale":pos=whale_position(animal,t)
		elif animal.kind=="bird":
			p+=Vector2(cos(t*.30)*1.6,sin(t*.30)*1.0)
			pos=world.surface(p);pos+=pos.normalized()*(2.9+sin(t*.55)*.25+animal.startle*.35)
			var flap=sin(t*7.5)*.58*(.22 if fmod(t,8.0)>4.2 else 1.0)
			animal.left.rotation.z=-flap;animal.right.rotation.z=flap
		else:
			p+=Vector2(sin(t*.8)*.29,sin(t*1.3)*.23)
			pos=world.surface(p);pos+=pos.normalized()*(.40+.09*sin(t*2)+animal.startle*.22)
			var flap=.35+abs(sin(t*15))*.95
			animal.left.rotation.z=-flap;animal.right.rotation.z=flap
		var forward=pos-animal.last
		if animal.last==Vector3.ZERO:forward=Vector3(1,0,0)
		animal.anchor.position=pos
		if forward.length_squared()>.00000001:
			var from_rotation=animal.anchor.basis.get_rotation_quaternion()
			var to_rotation=frame_at(pos,forward).get_rotation_quaternion()
			animal.anchor.basis=Basis(from_rotation.slerp(to_rotation,1-exp(-dt*7)).normalized())
		animal.last=pos
	update_water_effects(dt)

func water_burst(global_point:Vector3,normal:Vector3,splash:bool):
	var start=to_local(global_point);var tangent=normal.cross(Vector3.RIGHT).normalized()
	if tangent.length_squared()<.1:tangent=normal.cross(Vector3.FORWARD).normalized()
	var other=normal.cross(tangent).normalized()
	for i in range(16 if splash else 10):
		var drop=MeshInstance3D.new();var mesh=SphereMesh.new();mesh.radius=.035 if splash else .026;mesh.height=mesh.radius*2;mesh.radial_segments=5;mesh.rings=2;drop.mesh=mesh;drop.material_override=spray_material;drop.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(drop);drop.position=start
		var angle=i*2.399;var side=tangent*cos(angle)+other*sin(angle)
		water_effects.append({"node":drop,"start":start,"normal":normal,"velocity":normal*(.8+float(i%4)*.25 if splash else 1.7+float(i%3)*.22)+side*(1.0 if splash else .24),"age":0.0,"life":.85 if splash else 1.25})

func update_water_effects(dt:float):
	for i in range(water_effects.size()-1,-1,-1):
		var effect=water_effects[i];effect.age+=dt;var age=effect.age
		effect.node.position=effect.start+effect.velocity*age-effect.normal*1.8*age*age
		effect.node.scale=Vector3.ONE*(1-age/effect.life)
		if age>=effect.life:effect.node.queue_free();water_effects.remove_at(i)

func handle_tap(screen_pos:Vector2)->bool:
	if not is_instance_valid(world.game.camera):return false
	var camera=world.game.camera;var nearest={};var distance=30.0
	for animal in animals:
		if not animal.anchor.visible:continue
		var p=animal.anchor.global_position;var normal=world.globe.global_basis*animal.anchor.position.normalized()
		if normal.dot((camera.global_position-p).normalized())<.10 or camera.is_position_behind(p):continue
		var d=camera.unproject_position(p).distance_to(screen_pos)
		if d<distance:nearest=animal;distance=d
	if nearest.is_empty():return false
	if nearest.kind=="whale":
		# A visible whale can be watched surfacing without waiting a whole ambient cycle.
		nearest.phase=floor(nearest.phase/88.0)*88.0+25.8
	elif nearest.kind=="fish":
		var group=nearest.index/4
		for animal in animals:
			if animal.kind=="fish" and animal.index/4==group:animal.startle=2.4
	else:nearest.startle=2.4
	return true
