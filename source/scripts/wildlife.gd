extends Node3D
class_name IslandWildlife

# Marine paths use spherical directions and the same physical sea-floor map as water.
var world
var animals:Array=[]
var clock=0.0
var land_count=-1
var coast:Array=[]
var offshore:Array=[]
var outer_sea:Array=[]
var meadows:Array=[]
var water_effects:Array=[]
var scenery:Node3D
var grass:Array=[]
var cave:Dictionary={}
var broad_homes:Array=[]
var seabed_obstacles:Array=[]
var bird_scene=preload("res://assets/models/wild_bird.glb")
var butterfly_scene=preload("res://assets/models/wild_butterfly.glb")
var whale_scene=preload("res://assets/models/wild_whale.glb")
var fish_scenes={"gold":preload("res://assets/models/wild_fish.glb"),"silver":preload("res://assets/models/wild_silver_fish.glb"),"reef":preload("res://assets/models/wild_reef_fish.glb"),"ray":preload("res://assets/models/wild_ray.glb"),"turtle":preload("res://assets/models/wild_turtle.glb")}
var coral_scene=preload("res://assets/models/sea_coral.glb")
var grass_scene=preload("res://assets/models/sea_grass.glb")
var relic_scene=preload("res://assets/models/sea_relic.glb")
var cave_scene=preload("res://assets/models/sea_cave.glb")
var water_math=preload("res://scripts/water.gd")
var spray_material:StandardMaterial3D
const SPECIES=["gold","silver","reef","ray","turtle"]
const SCALES={"gold":.53,"silver":.48,"reef":.52,"ray":.70,"turtle":.66}
const BODY_HEIGHT={"gold":.17,"silver":.14,"reef":.29,"ray":.15,"turtle":.22}
const BODY_RADIUS={"gold":.36,"silver":.44,"reef":.37,"ray":1.32,"turtle":.65}
const WHALE_RATE=.085
const WHALE_HALF_LENGTH=2.31

func setup(owner_world):
	world=owner_world
	if get_parent()!=world.globe:reparent(world.globe,false)
	position=Vector3.ZERO;basis=Basis.IDENTITY
	spray_material=StandardMaterial3D.new();spray_material.albedo_color=Color("D1F3F0");spray_material.roughness=.18
	refresh_habitats()

func sea_direction(p:Vector2)->Vector3:return world.surface(p).normalized()
func available_depth(p:Vector2)->float:return depth_at(sea_direction(p))
func depth_at(normal:Vector3)->float:
	var water=world.get("water")
	return float(water.depth_at(normal)) if water and water.has_method("depth_at") else 0.0
func tangent_axes(n:Vector3)->Array:
	var side=n.cross(Vector3.UP).normalized()
	if side.length_squared()<.1:side=Vector3.RIGHT.slide(n).normalized()
	return [side,side.cross(n).normalized()]
func offset_direction(n:Vector3,offset:Vector2)->Vector3:
	var axes=tangent_axes(n);var length=offset.length()
	if length<.00001:return n
	var tangent=(axes[0]*offset.x+axes[1]*offset.y)/length
	return (n*cos(length/water_math.BASE_RADIUS)+tangent*sin(length/water_math.BASE_RADIUS)).normalized()
func body_depth_normal(n:Vector3,radius:float)->float:
	var depth=depth_at(n)
	for i in range(8):depth=minf(depth,depth_at(offset_direction(n,Vector2(cos(i*TAU/8),sin(i*TAU/8))*radius)))
	return depth
func body_depth(p:Vector2,radius:float)->float:return body_depth_normal(sea_direction(p),radius)
func water_at(p:Vector2,margin=0.0)->bool:return outside_land(sea_direction(p),margin)
func outside_land(n:Vector3,margin:float)->bool:
	for cell in world.land:
		if n.distance_to(sea_direction(IslandFrontier.point(cell)))*water_math.BASE_RADIUS<IslandFrontier.HEX*1.10+margin:return false
	return true
func deep_sea(normal:Vector3,margin:float,minimum_depth:float)->bool:
	return outside_land(normal,margin) and body_depth_normal(normal,margin)>=minimum_depth
func safe_sea(p:Vector2,margin:float,minimum_depth:float)->bool:return deep_sea(sea_direction(p),margin,minimum_depth)
func clear_of_cave(n:Vector3,margin:float)->bool:
	return cave.is_empty() or n.distance_to(cave.normal)*water_math.BASE_RADIUS>3.2+margin
func fish_depth(species_name:String)->float:
	return 1.08 if species_name=="ray" else .48 if species_name=="turtle" else .68 if species_name=="silver" else .46
func clear_of_seabed_props(n:Vector3,extent:float,bottom_depth:float)->bool:
	for obstacle in seabed_obstacles:
		if n.distance_to(obstacle.normal)*water_math.BASE_RADIUS<extent+obstacle.radius and bottom_depth>obstacle.depth:return false
	return true

func refresh_habitats():
	var water=world.get("water")
	if water and water.has_method("rebuild") and water.get("land_count")!=world.land.size():water.rebuild()
	land_count=world.land.size();coast.clear();offshore.clear();outer_sea.clear();meadows.clear()
	var steps=[Vector2i(1,0),Vector2i(0,1),Vector2i(-1,1),Vector2i(-1,0),Vector2i(0,-1),Vector2i(1,-1)]
	for cell in world.land:
		var center=IslandFrontier.point(cell);var region=world.terrain.kind(cell)
		if region in ["grove","shore","meadow","wetland","hill"]:meadows.append(center+Vector2(.55,.42))
		for step in steps:
			if world.land.has(cell+step):continue
			var direction=(IslandFrontier.point(cell+step)-center).normalized()
			var normal=sea_direction(center+direction*IslandFrontier.HEX*2.15)
			if deep_sea(normal,.35,.68):coast.append(normal)
			normal=sea_direction(center+direction*IslandFrontier.HEX*3.25)
			if deep_sea(normal,.7,1.05):offshore.append(normal)
			normal=sea_direction(center+direction*IslandFrontier.HEX*4.6)
			if deep_sea(normal,1.2,1.55):outer_sea.append(normal)
	if meadows.is_empty():meadows.append(IslandFrontier.point(world.land.keys()[0]) if not world.land.is_empty() else Vector2.ZERO)
	if coast.is_empty():coast.assign(offshore)
	rebuild_seabed_life()
	var desired={"bird":mini(4,1+land_count/8),"fish":22 if land_count>=18 else 18,"butterfly":mini(6,1+land_count/6),"whale":2 if land_count>=18 else 1}
	for kind in desired:
		var count=0
		for animal in animals:
			if animal.kind==kind:count+=1
		while count<int(desired[kind]):spawn(kind,count);count+=1
	broad_homes.clear()
	for animal in animals:
		if animal.kind=="fish":configure_fish(animal)
		elif animal.kind=="whale":configure_whale(animal)

func species(index:int)->String:
	if index<4:return "gold"
	if index<10:return "silver"
	if index<14:return "reef"
	if index<16:return "ray"
	if index<18:return "turtle"
	return "silver" if index<20 else "reef"
func spawn(kind:String,index:int):
	var anchor=Node3D.new();add_child(anchor)
	var type=species(index) if kind=="fish" else kind
	var scene=fish_scenes[type] if kind=="fish" else bird_scene if kind=="bird" else whale_scene if kind=="whale" else butterfly_scene
	var model=scene.instantiate();anchor.add_child(model)
	var scale_factor=float(SCALES[type]) if kind=="fish" else .68 if kind=="bird" else (1.62 if index==0 else .82) if kind=="whale" else .66
	model.scale=Vector3.ONE*scale_factor
	for mesh in model.find_children("*","MeshInstance3D",true,false):mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	animals.append({"kind":kind,"species":type,"index":index,"anchor":anchor,"model":model,"scale":scale_factor,"home":meadows[(index*5)%meadows.size()],"normal":Vector3.UP,"radius":.7,"phase":float(index)*.63,"action_offset":0.0,"startle":0.0,"left":model.find_child("FlipperL" if kind=="whale" or type in ["ray","turtle"] else "WingL",true,false),"right":model.find_child("FlipperR" if kind=="whale" or type in ["ray","turtle"] else "WingR",true,false),"tail":model.find_child("Tail",true,false),"fluke":model.find_child("Fluke",true,false),"blowhole":model.find_child("Blowhole",true,false),"last":Vector3.ZERO,"state":"swim","breath_cycle":-1,"route_valid":true,"depth":.3})

func configure_fish(animal:Dictionary):
	var broad=animal.species in ["ray","turtle"];var pool=outer_sea if animal.species=="ray" and not outer_sea.is_empty() else offshore if broad or animal.species=="silver" else coast
	if pool.is_empty():pool=coast if not coast.is_empty() else offshore
	animal.route_valid=false
	if pool.is_empty():return
	var extent=float(BODY_RADIUS[animal.species]);var min_depth=maxf(1.45 if animal.species=="ray" else .95 if broad else .62,float(BODY_HEIGHT[animal.species])*2+.35)
	for attempt in range(pool.size()):
		var normal:Vector3=pool[(int(animal.index/3)*5+attempt)%pool.size()]
		var crowded=false
		if broad:
			for other in broad_homes:
				if normal.distance_to(other)*water_math.BASE_RADIUS<3.0:crowded=true;break
		if crowded:continue
		for radius in [1.35,.85,.45,.18]:
			var safe=true
			for i in range(24):
				var n=offset_direction(normal,Vector2(sin(i*TAU/24),cos(i*TAU/24)*.65)*radius)
				if not deep_sea(n,extent,min_depth) or not clear_of_cave(n,extent) or not clear_of_seabed_props(n,extent,fish_depth(animal.species)+float(BODY_HEIGHT[animal.species])+.08):safe=false;break
			if safe:
				animal.normal=normal;animal.radius=radius;animal.route_valid=true
				if broad:broad_homes.append(normal)
				return

func water_point(p:Vector2,depth=.28)->Vector3:return water_point_normal(sea_direction(p),depth)
func water_point_normal(normal:Vector3,depth:float)->Vector3:
	return normal*(water_math.surface_radius(normal,world.time)-depth)
func whale_direction(animal:Dictionary,t:float)->Vector3:
	return offset_direction(animal.route_center,Vector2(sin(t*WHALE_RATE),cos(t*WHALE_RATE)*.68)*animal.radius)
func sea_candidates()->Array:
	var candidates=[Vector3(0,.30,1).normalized(),Vector3(-.75,.20,.65).normalized(),Vector3(.78,.16,.65).normalized()]
	for i in range(96):
		var y=1.0-(i+.5)/48.0;var a=i*2.39996323;var r=sqrt(maxf(0,1-y*y));candidates.append(Vector3(cos(a)*r,y,sin(a)*r))
	return candidates
func configure_whale(animal:Dictionary):
	animal.route_valid=false
	var candidates=sea_candidates()
	if animal.index==1:candidates=candidates.slice(2)+candidates.slice(0,2)
	# The complete long blue-whale hull, flippers and animated flukes need a
	# larger footprint than the old short-bodied stylised whale.
	var margin=WHALE_HALF_LENGTH*float(animal.scale)+.32;var minimum=2.85 if animal.index==0 else 1.8
	for home in candidates:
		animal.route_center=home
		for radius in [3.6,2.4,1.4,.7]:
			animal.radius=radius;var safe=true
			for i in range(32):
				var normal=whale_direction(animal,i*TAU/32/WHALE_RATE)
				if not deep_sea(normal,margin,minimum) or not clear_of_cave(normal,margin):safe=false;break
			if safe:animal.route_valid=true;return

func frame_at(point:Vector3,forward:Vector3)->Basis:
	var up=point.normalized();var tangent=forward-up*forward.dot(up)
	if tangent.length_squared()<.00000001:tangent=(Vector3.FORWARD if absf(up.z)<.85 else Vector3.RIGHT).slide(up)
	var right=tangent.cross(up).normalized()
	return Basis(right,up,right.cross(up).normalized()).orthonormalized()
func whale_position(animal:Dictionary,t:float)->Vector3:
	var normal=whale_direction(animal,t);var adult=animal.index==0
	animal.anchor.visible=animal.route_valid
	var swim_depth=1.60 if adult else .89;var breath_depth=.56 if adult else .27
	var action_time=t+animal.action_offset
	var cycle=int(action_time/62.0);var phase=fmod(action_time,62.0);var depth=swim_depth+sin(t*.36)*.09;var pitch=sin(t*.8)*.025;var state="swim"
	if phase>=12 and phase<17:depth=lerpf(swim_depth,breath_depth,smoothstep(0,1,(phase-12)/5));state="rise"
	elif phase>=17 and phase<23:
		depth=breath_depth;state="breathe"
		if animal.breath_cycle!=cycle:
			animal.breath_cycle=cycle
			if animal.last!=Vector3.ZERO:water_burst(animal.blowhole.global_position,animal.anchor.position.normalized(),false,1.5 if adult else 1.0)
	elif phase>=23 and phase<29:depth=lerpf(breath_depth,swim_depth,smoothstep(0,1,(phase-23)/6));pitch=-.12*sin((phase-23)*PI/6);state="dive"
	elif cycle%2==0 and phase>=43 and phase<47:
		var u=(phase-43)/4;depth=swim_depth-sin(u*PI)*(2.55 if adult else 1.40);pitch=.52*sin(u*TAU);state="breach"
	if animal.state=="breach" and state!="breach":
		water_burst(to_global(water_point_normal(normal,0)),normal,true,1.7 if adult else 1.0)
		world.water.ripple(normal,2.3 if adult else 1.2)
	animal.state=state;animal.depth=depth
	animal.model.rotation.x=pitch;animal.model.rotation.z=sin(t*.45)*.025
	# Cetacean propulsion is a slow vertical wave, not a fish's lateral flick.
	animal.tail.rotation.x=sin(t*.92)*.15;animal.fluke.rotation.x=sin(t*.92-.65)*.13
	animal.left.rotation.z=-.065+sin(t*.45)*.065;animal.right.rotation.z=.065-sin(t*.45)*.065
	return water_point_normal(normal,depth)

func rebuild_seabed_life():
	if scenery:scenery.queue_free()
	scenery=Node3D.new();scenery.name="UnderwaterDiscoveries";add_child(scenery);grass.clear();cave.clear();seabed_obstacles.clear()
	var chosen=[]
	for i in range(offshore.size()):
		var n:Vector3=offshore[(i*7)%offshore.size()]
		if not deep_sea(n,.65,1.45):continue
		var crowded=false
		for previous in chosen:
			if n.distance_to(previous)*water_math.BASE_RADIUS<2.5:crowded=true;break
		if crowded:continue
		chosen.append(n)
		var plant=coral_scene if chosen.size()%3 else relic_scene
		place_bed_model(plant,n,.74 if plant==coral_scene else .86,i*.7)
		seabed_obstacles.append({"normal":n,"radius":.82,"depth":depth_at(n)-.72})
		for j in range(2):
			var direction=offset_direction(n,Vector2(.65 if j==0 else -.65,.28))
			if deep_sea(direction,.3,.95):grass.append({"node":place_bed_model(grass_scene,direction,.75,i*.7+j),"phase":i+j*2.0})
		if chosen.size()>=mini(9,3+land_count/7):break
	for n in sea_candidates():
		if not deep_sea(n,3.2,2.85):continue
		var base=Node3D.new();scenery.add_child(base);base.position=n*(world.water.floor_radius(n)+.08)
		# The ordinary globe recentering rotation also brings the entrance toward
		# the camera; a development visit must not show only the cave's back wall.
		var entrance=Quaternion(n,Vector3.UP).inverse()*Vector3.BACK
		base.basis=frame_at(base.position,entrance);base.rotate_object_local(Vector3.UP,.15)
		var shell=cave_scene.instantiate();base.add_child(shell);shell.scale=Vector3.ONE*.86
		cave={"root":base,"shell":shell,"normal":n}
		break
func place_bed_model(scene:PackedScene,n:Vector3,size:float,yaw:float)->Node3D:
	var anchor=Node3D.new();scenery.add_child(anchor);anchor.position=n*(world.water.floor_radius(n)+.035)
	anchor.basis=frame_at(anchor.position,tangent_axes(n)[1]);anchor.rotate_object_local(Vector3.UP,yaw)
	var model=scene.instantiate();anchor.add_child(model);model.scale=Vector3.ONE*size
	return model
func update_seagrass():
	for plant in grass:plant.node.rotation.z=sin(clock*.85+plant.phase)*.065
func preview_event(event:String)->Vector3:
	if event=="cave" and not cave.is_empty():return cave.normal
	for animal in animals:
		if animal.kind=="whale" and animal.index==0:
			animal.action_offset=(44.4 if event=="whale_breach" else 16.5)-fmod(animal.phase,124.0)
			animal.breath_cycle=-1
			return whale_direction(animal,animal.phase)
	return Vector3.UP

func _process(dt):
	if not is_instance_valid(world):return
	clock+=dt
	if land_count!=world.land.size():refresh_habitats()
	for animal in animals:
		animal.startle=maxf(0,animal.startle-dt);animal.phase+=dt*(1.8 if animal.startle>0 and animal.kind!="whale" else 1.0)
		var t=animal.phase;var pos:Vector3
		if animal.kind=="fish":
			var broad=animal.species in ["ray","turtle"];var rate=.25 if broad else .48
			var n=offset_direction(animal.normal,Vector2(sin(t*rate),cos(t*rate)*.65)*animal.radius)
			var bed=body_depth_normal(n,float(BODY_RADIUS[animal.species]));var height=float(BODY_HEIGHT[animal.species])
			var depth=fish_depth(animal.species)+sin(t*.75)*.045
			depth=clampf(depth,height+.13,maxf(height+.13,bed-height-.13));animal.depth=depth
			animal.anchor.visible=animal.route_valid and bed>height*2+.27;pos=water_point_normal(n,depth)
			if animal.tail:animal.tail.rotation.y=sin(t*(1.8 if broad else 7.5))*(.13 if broad else .34)
			if broad:
				var flap=sin(t*(1.65 if animal.species=="ray" else 2.0))*.22
				animal.left.rotation.z=-flap;animal.right.rotation.z=flap
				if animal.species=="turtle":animal.left.rotation.y=sin(t*2.0)*.30;animal.right.rotation.y=-sin(t*2.0)*.30
			animal.model.rotation.z=sin(t*.65)*.045
		elif animal.kind=="whale":pos=whale_position(animal,t)
		else:
			var p:Vector2=animal.home
			if animal.kind=="bird":
				p+=Vector2(cos(t*.30)*1.6,sin(t*.30)*1.0);pos=world.surface(p);pos+=pos.normalized()*(2.9+sin(t*.55)*.25+animal.startle*.35)
				var flap=sin(t*7.5)*.58*(.22 if fmod(t,8.0)>4.2 else 1.0);animal.left.rotation.z=-flap;animal.right.rotation.z=flap
			else:
				p+=Vector2(sin(t*.8)*.29,sin(t*1.3)*.23);pos=world.surface(p);pos+=pos.normalized()*(.40+.09*sin(t*2)+animal.startle*.22)
				var flap=.35+abs(sin(t*15))*.95;animal.left.rotation.z=-flap;animal.right.rotation.z=flap
		var forward=pos-animal.last
		if animal.last==Vector3.ZERO:forward=tangent_axes(pos.normalized())[0]
		animal.anchor.position=pos
		if forward.length_squared()>.00000001:animal.anchor.basis=Basis(animal.anchor.basis.get_rotation_quaternion().slerp(frame_at(pos,forward).get_rotation_quaternion(),1-exp(-dt*7)).normalized())
		animal.last=pos
	update_water_effects(dt);update_seagrass()

func water_burst(global_point:Vector3,normal:Vector3,splash:bool,size=1.0):
	var start=to_local(global_point);var tangent=tangent_axes(normal)[0];var other=normal.cross(tangent).normalized()
	for i in range(22 if splash else 12):
		var drop=MeshInstance3D.new();var mesh=SphereMesh.new();mesh.radius=(.035 if splash else .026)*size;mesh.height=mesh.radius*2;mesh.radial_segments=5;mesh.rings=2;drop.mesh=mesh;drop.material_override=spray_material;drop.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(drop);drop.position=start
		var angle=i*2.399;var side=tangent*cos(angle)+other*sin(angle)
		water_effects.append({"node":drop,"start":start,"normal":normal,"velocity":(normal*(.8+float(i%4)*.25 if splash else 1.7+float(i%3)*.22)+side*(1.0 if splash else .24))*size,"age":0.0,"life":1.1 if splash else 1.4})
func update_water_effects(dt:float):
	for i in range(water_effects.size()-1,-1,-1):
		var effect=water_effects[i];effect.age+=dt;var age=effect.age
		effect.node.position=effect.start+effect.velocity*age-effect.normal*1.8*age*age;effect.node.scale=Vector3.ONE*(1-age/effect.life)
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
	if nearest.kind=="whale":nearest.action_offset=12.0-fmod(nearest.phase,124.0);nearest.breath_cycle=-1
	elif nearest.kind=="fish":
		for animal in animals:
			if animal.kind=="fish" and animal.species==nearest.species:animal.startle=2.4
	else:nearest.startle=2.4
	return true
