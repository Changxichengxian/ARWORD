extends Node3D
class_name IslandGrove

var game
var globe:Node3D
var builder:Node3D
var actor:Node3D
var buildings:Array=[]
var additions:Array=[]
var limbs={}
var resources:Array=[]
var clouds:Array=[]
var effects:Array=[]
var rotor:Node3D
var boat:Node3D
var cursor:MeshInstance3D
var time=0.0
var desired_rotation=Quaternion.IDENTITY
var move_tween:Tween
var active_kind=0
var active_resource=0
var resource_batches=[-1,-1]
var swing=0.0
const RADIUS=4.84
const SITES=[Vector2(-1.85,-.45),Vector2(.9,-1.5),Vector2(2.0,.9)]
const PLOTS=[Vector2(-1.9,2.0),Vector2(.0,2.55)]
const ADDITIONS=[["deck","bench","camp"],["cistern","channel","workbench"],["orchard","fence","hive"]]
const ADD_SITES=[[Vector2(-1.4,3.65),Vector2(-1.0,.7),Vector2(-.6,-.9)],[Vector2(1.7,-2.0),Vector2(1.6,-.8),Vector2(2.65,-1.4)],[Vector2(3.1,1.0),Vector2(2.4,2.0),Vector2(1.4,2.3)]]
var mats={}

func mat(hex:String)->StandardMaterial3D:
	if mats.has(hex):return mats[hex]
	var m=StandardMaterial3D.new();m.albedo_color=Color(hex);m.roughness=.85;mats[hex]=m;return m
func model(name:String,parent:Node3D)->Node3D:
	var n=load("res://assets/models/"+name+".glb").instantiate();parent.add_child(n);return n
func surface(p:Vector2)->Vector3:return Vector3(p.x,sqrt(maxf(.1,RADIUS*RADIUS-p.length_squared())),p.y)
func place(node:Node3D,p:Vector2,angle=0.0):
	var v=surface(p);node.position=v;node.basis=Basis(Quaternion(Vector3.UP,v.normalized()));node.rotate_object_local(Vector3.UP,angle)
func pebble(parent:Node3D,p:Vector3,s:Vector3,color:String)->MeshInstance3D:
	var n=MeshInstance3D.new();var mesh=SphereMesh.new();mesh.radius=.5;mesh.height=1;mesh.radial_segments=6;mesh.rings=3;n.mesh=mesh;n.material_override=mat(color);parent.add_child(n);n.position=p;n.scale=s;return n

func pop(node:Node3D,delay=0.0,base=Vector3.ONE):
	if node.has_meta("pop"):
		var old=node.get_meta("pop")
		if old is Tween and old.is_valid():old.kill()
	node.scale=base*.08
	var tw=create_tween();node.set_meta("pop",tw)
	tw.tween_property(node,"scale",base,.42).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func drag(delta:Vector2):
	var axes=game.camera.global_basis
	desired_rotation=(Quaternion(axes.y,-delta.x*.006)*Quaternion(axes.x,-delta.y*.006)*desired_rotation).normalized()
func recenter():desired_rotation=Quaternion.IDENTITY
func site_at(screen_pos:Vector2)->int:
	var nearest=-1;var distance=55.0
	for i in range(buildings.size()):
		var p=buildings[i].global_position;var normal=globe.global_basis*buildings[i].position.normalized()
		if normal.dot((game.camera.global_position-p).normalized())<.15:continue
		var d=game.camera.unproject_position(p).distance_to(screen_pos)
		if d<distance:distance=d;nearest=i
	return nearest

func setup(owner_node):
	game=owner_node
	var e=Environment.new();e.background_mode=Environment.BG_COLOR;e.background_color=Color("152C43")
	e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;e.ambient_light_color=Color("C4E5EC");e.ambient_light_energy=.48;e.tonemap_mode=Environment.TONE_MAPPER_ACES
	var env=WorldEnvironment.new();env.environment=e;add_child(env)
	var sun=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-55,-38,0);sun.light_color=Color("FFF0D3");sun.light_energy=1.25;sun.shadow_enabled=true;sun.directional_shadow_max_distance=40;sun.shadow_bias=.035;add_child(sun)
	globe=Node3D.new();add_child(globe);model("planet",globe)
	for i in range(3):
		var anchor=Node3D.new();globe.add_child(anchor);place(anchor,SITES[i],PI-.15+i*.3)
		var b=model(["cottage","windmill","garden"][i],anchor);b.scale=Vector3.ONE*.87;buildings.append(anchor)
		if i==1:rotor=b.find_child("Rotor",true,false)
		var ring=MeshInstance3D.new();var tm=TorusMesh.new();tm.inner_radius=.9;tm.outer_radius=.96;tm.rings=24;tm.ring_segments=4;ring.mesh=tm;ring.material_override=mat("F4DAA1");anchor.add_child(ring);ring.position.y=.03
		var extra=[]
		for j in range(3):
			var point=Node3D.new();globe.add_child(point);place(point,ADD_SITES[i][j],PI+.2*j)
			var added=model(ADDITIONS[i][j],point);added.scale=Vector3.ONE*.7;added.visible=false;extra.append(added)
		additions.append(extra)
	var decor=[Vector2(-3.25,-.8),Vector2(-2.75,-2.0),Vector2(-1.3,-2.8),Vector2(.15,-3.0),Vector2(2.35,-2.0),Vector2(3.2,-.4)]
	for i in range(decor.size()):
		var a=Node3D.new();globe.add_child(a);place(a,decor[i],i*.9);var n=model("oak",a);n.scale=Vector3.ONE*(.65+.07*(i%3))
	for i in range(26):
		var a=float(i)/25;var p=Vector2(-2.1+4.1*a,.1+sin(a*PI)*.55)
		var stone=pebble(globe,surface(p),Vector3(.23,.08,.22),"EED8AB");stone.basis=Basis(Quaternion(Vector3.UP,stone.position.normalized()));stone.scale=Vector3(.25,.08,.20)
	for i in range(12):
		var a=Node3D.new();globe.add_child(a);place(a,Vector2(-3+fmod(i*1.13,6),-.2+sin(i*2.0)*1.1),i);var f=model("flower",a);f.scale=Vector3.ONE*.7
	for kind in range(2):
		var row=[]
		for i in range(6):
			# Clear the near row first so it cannot hide the worker harvesting the far row.
			var a=Node3D.new();globe.add_child(a);var p=PLOTS[kind]+Vector2((i%3-1)*.62,(1-i/3)*.63-.3);place(a,p,i*.7)
			var prop=model("oak" if kind==0 else "ore",a);prop.scale=Vector3.ONE*(.57 if kind==0 else .68);row.append({"anchor":a,"visual":prop,"p":p,"base":prop.scale})
		resources.append(row)
	builder=Node3D.new();globe.add_child(builder);place(builder,PLOTS[0]+Vector2(-.5,.7));actor=model("builder",builder);actor.scale=Vector3.ONE
	for part in ["ArmL","ArmR","LegL","LegR","Body"]:limbs[part]=actor.find_child(part,true,false)
	for i in range(5):
		var c=model("cloud",globe);c.scale=Vector3.ONE*(.7+i*.1);clouds.append(c)
	boat=model("boat",globe);boat.scale=Vector3.ONE*.55
	cursor=MeshInstance3D.new();var cm=TorusMesh.new();cm.inner_radius=.38;cm.outer_radius=.42;cm.rings=24;cm.ring_segments=4;cursor.mesh=cm;cursor.material_override=mat("FFE4A1");globe.add_child(cursor)
	sync_buildings(false);prepare_resource(false)

func sync_buildings(animate=true):
	for i in range(3):
		var count=int(game.learning.data.build[i]);var fraction=float(count)/IslandLearning.NEEDS[i]
		for stage in buildings[i].find_children("Stage*","Node3D",true,false):
			var level=int(str(stage.name).trim_prefix("Stage"));var show_stage=(count>0 and fraction>=float(level)/3.0);var was_visible=stage.visible;stage.visible=show_stage
			if show_stage and not was_visible and animate:pop(stage,float(level)*.07)
		buildings[i].get_child(buildings[i].get_child_count()-1).visible=count==0
		for j in range(3):
			var extra=additions[i][j];var show_extra=int(game.learning.data.development[i])>=(j+1)*12
			var was_visible=extra.visible;extra.visible=show_extra
			if show_extra and not was_visible and animate:pop(extra,0.0,Vector3.ONE*.7)
	if game.learning.data.flags.get("cottage_west",false):place(buildings[0],Vector2(-2.25,-.5),PI-.25)
	if game.learning.data.flags.get("mill_hill",false):place(buildings[1],Vector2(.65,-2.1),PI+.25)

func prepare_resource(animate=true):
	active_kind=0 if game.learning.data.active!=1 else 1
	active_resource=int(game.learning.data.harvested[active_kind])%6
	var batch=int(game.learning.data.harvested[active_kind])/6;var new_batch=resource_batches[active_kind]!=batch
	for i in range(6):
		var saved_entry=resources[active_kind][i];var was_visible=saved_entry.visual.visible;saved_entry.visual.visible=i>=active_resource;saved_entry.visual.rotation=Vector3.ZERO
		if saved_entry.visual.visible and animate and (new_batch or not was_visible):pop(saved_entry.visual,i*.04,saved_entry.base)
		elif not saved_entry.visual.has_meta("pop"):saved_entry.visual.scale=saved_entry.base
	resource_batches[active_kind]=batch
	var entry=resources[active_kind][active_resource];entry.visual.visible=true
	var work_point=entry.p if game.mode=="word" else SITES[int(game.learning.data.active)]
	place(cursor,work_point);cursor.position+=cursor.basis.y*.025
	if move_tween and move_tween.is_valid():move_tween.kill()
	var target=work_point+Vector2(.6,.7)
	var origin=Vector2(builder.position.x,builder.position.z);var heading=atan2(-(target-origin).x,-(target-origin).y)
	move_tween=create_tween();move_tween.tween_method(func(p):place(builder,p,heading),origin,target,clampf(origin.distance_to(target)*.20,.25,.80)).set_trans(Tween.TRANS_SINE)
	var facing=atan2(-(work_point-target).x,-(work_point-target).y)
	move_tween.tween_callback(func():place(builder,target,facing))

func harvest(result:Dictionary):
	var entry=resources[active_kind][active_resource];var prop=entry.visual;swing=.6
	if game.mode=="word":
		if prop.has_meta("pop") and prop.get_meta("pop").is_valid():prop.get_meta("pop").kill()
		var t=create_tween();t.set_parallel(true);t.tween_property(prop,"rotation:z",-.65 if active_kind==0 else .3,.18);t.tween_property(prop,"scale",Vector3.ONE*.02,.28).set_delay(.12)
	var start=entry.anchor.position+entry.anchor.basis.y*.6;var target=buildings[result.project].position+buildings[result.project].basis.y*.8
	if game.mode in ["read","sentence"]:start=builder.position+builder.basis.y*.6
	for i in range(5):
		var chip
		if game.mode in ["word","listen"]:
			chip=model("timber" if active_kind==0 else "ore",globe);chip.scale=Vector3.ONE*(.9 if active_kind==0 else .18)
		else:chip=pebble(globe,start,Vector3.ONE*.12,"F3D788" if game.mode=="read" else "9BD894")
		effects.append({"node":chip,"a":start,"b":target,"t":-i*.045,"duration":.52,"seed":i})
	var save_project=result.project
	get_tree().create_timer(.48).timeout.connect(func():
		if not is_inside_tree():return
		sync_buildings();var b=buildings[save_project];var tw=create_tween();tw.tween_property(b,"scale",Vector3.ONE*1.055,.09);tw.tween_property(b,"scale",Vector3.ONE,.16)
		game.play_fx("build" if result.complete else "land")
	)
	for i in range(6):
		var chip=pebble(globe,start,Vector3.ONE*.12,"EBD09A" if active_kind==0 else "B5D9D6")
		effects.append({"node":chip,"a":start,"b":start+Vector3(sin(i*1.7)*.6,-.25,cos(i*1.7)*.6),"t":0.0,"duration":.4,"seed":i})

func _process(dt):
	if not is_instance_valid(globe):return
	time+=dt;globe.quaternion=globe.quaternion.slerp(desired_rotation,1-exp(-dt*10));swing=maxf(0,swing-dt)
	var walking=move_tween and move_tween.is_running();var step=sin(time*17)*.55 if walking else 0.0
	for side in ["L","R"]:
		var sign_side=1.0 if side=="L" else -1.0
		if is_instance_valid(limbs.get("Leg"+side)):limbs["Leg"+side].rotation.x=step*sign_side
		if is_instance_valid(limbs.get("Arm"+side)):limbs["Arm"+side].rotation.x=-step*sign_side*.7
	if swing>0 and is_instance_valid(limbs.get("ArmR")):limbs.ArmR.rotation.x=-.4+sin((.6-swing)*15)*1.1
	actor.rotation.x=sin((.6-swing)*15)*swing*.15 if swing>0 else 0.0
	actor.position.y=abs(sin(time*17))*.04 if walking else sin(time*1.8)*.012
	if is_instance_valid(rotor) and int(game.learning.data.build[1])>=IslandLearning.NEEDS[1]:rotor.rotate_z(dt*.7)
	for i in range(clouds.size()):
		var a=time*.012+i*TAU/clouds.size();var p=Vector3(cos(a),.18+sin(a*2+i)*.10,sin(a)).normalized()*6.0
		clouds[i].position=p;clouds[i].basis=Basis(Quaternion(Vector3.UP,p.normalized()));clouds[i].scale=Vector3.ONE*(.55+i*.06)
	var ba=time*.055;boat.position=Vector3(sin(ba)*4.55,1.15,cos(ba)*4.55)
	var normal=boat.position.normalized();var forward=Vector3(cos(ba),0,-sin(ba)).normalized();boat.basis=Basis(forward.cross(normal).normalized(),normal,-forward);boat.scale=Vector3.ONE*.55;boat.visible=int(game.learning.data.build[0])>=IslandLearning.NEEDS[0]
	cursor.scale=Vector3.ONE*(1.0+sin(time*3)*.04)
	for i in range(effects.size()-1,-1,-1):
		var e=effects[i];e.t+=dt
		if e.t<0:e.node.visible=false;continue
		e.node.visible=true;var u=minf(1,e.t/e.duration);e.node.position=e.a.lerp(e.b,u)+Vector3.UP*sin(u*PI)*1.15;e.node.rotate_y(dt*5)
		if u>=1:e.node.queue_free();effects.remove_at(i)
	if game.learning.data.flags.get("water",false) and game.learning.completed() and int(game.learning.data.build[1])>=IslandLearning.NEEDS[1] and int(time*8)!=int((time-dt)*8):
		var a=buildings[1].position;var b=buildings[2].position;var drop=pebble(globe,a,Vector3.ONE*.10,"A4EDF0")
		effects.append({"node":drop,"a":a,"b":b,"t":0.0,"duration":1.0,"seed":0})
