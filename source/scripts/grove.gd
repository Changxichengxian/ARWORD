extends Node3D
class_name IslandGrove

var game
var globe:Node3D
var builder:Node3D
var actor:Node3D
var buildings:Array=[]
var resources:Array=[]
var clouds:Array=[]
var effects:Array=[]
var rotor:Node3D
var boat:Node3D
var cursor:MeshInstance3D
var time=0.0
var desired_yaw=0.0
var move_tween:Tween
var active_kind=0
var active_resource=0
var swing=0.0
const RADIUS=4.84
const SITES=[Vector2(-1.85,-.45),Vector2(.9,-1.5),Vector2(2.0,.9)]
const PLOTS=[Vector2(-1.9,2.0),Vector2(.0,2.55)]
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
			var a=Node3D.new();globe.add_child(a);var p=PLOTS[kind]+Vector2((i%3-1)*.62,(i/3)*.63-.3);place(a,p,i*.7)
			var prop=model("oak" if kind==0 else "ore",a);prop.scale=Vector3.ONE*(.57 if kind==0 else .68);row.append({"anchor":a,"visual":prop,"p":p,"base":prop.scale})
		resources.append(row)
	builder=Node3D.new();globe.add_child(builder);place(builder,PLOTS[0]+Vector2(-.5,.7));actor=model("builder",builder);actor.scale=Vector3.ONE*.80
	for i in range(5):
		var c=model("cloud",self);c.scale=Vector3.ONE*(.7+i*.1);clouds.append(c)
	boat=model("boat",globe);boat.scale=Vector3.ONE*.55
	cursor=MeshInstance3D.new();var cm=TorusMesh.new();cm.inner_radius=.38;cm.outer_radius=.42;cm.rings=24;cm.ring_segments=4;cursor.mesh=cm;cursor.material_override=mat("FFE4A1");globe.add_child(cursor)
	sync_buildings();prepare_resource()

func sync_buildings():
	for i in range(3):
		var count=int(game.learning.data.build[i]);var fraction=float(count)/IslandLearning.NEEDS[i]
		for stage in buildings[i].find_children("Stage*","Node3D",true,false):
			var level=int(str(stage.name).trim_prefix("Stage"));stage.visible=(count>0 and fraction>=float(level)/3.0)
		buildings[i].get_child(buildings[i].get_child_count()-1).visible=count==0
	if game.learning.data.flags.get("cottage_west",false):place(buildings[0],Vector2(-2.25,-.5),PI-.25)
	if game.learning.data.flags.get("mill_hill",false):place(buildings[1],Vector2(.65,-2.1),PI+.25)

func prepare_resource():
	var a=int(game.learning.data.actions)
	active_kind=0 if game.learning.data.active==0 else (a/6)%2
	active_resource=a%6
	for i in range(6):
		var saved_entry=resources[active_kind][i];saved_entry.visual.visible=i>=active_resource;saved_entry.visual.scale=saved_entry.base;saved_entry.visual.rotation=Vector3.ZERO
	var entry=resources[active_kind][active_resource];entry.visual.visible=true;entry.visual.scale=entry.base
	place(cursor,entry.p);cursor.position+=cursor.basis.y*.025
	if move_tween and move_tween.is_valid():move_tween.kill()
	var target=entry.p+Vector2(.18,.9)
	move_tween=create_tween();move_tween.tween_method(func(p):place(builder,p,PI),Vector2(builder.position.x,builder.position.z),target,.32).set_trans(Tween.TRANS_SINE)

func harvest(result:Dictionary):
	var entry=resources[active_kind][active_resource];var prop=entry.visual;swing=.6
	var t=create_tween();t.set_parallel(true);t.tween_property(prop,"rotation:z",-.65 if active_kind==0 else .3,.18);t.tween_property(prop,"scale",Vector3.ONE*.02,.28).set_delay(.12)
	var start=entry.anchor.position+entry.anchor.basis.y*.6;var target=buildings[result.project].position+buildings[result.project].basis.y*.8
	for i in range(5):
		var chip=model("timber" if active_kind==0 else "ore",globe);chip.scale=Vector3.ONE*(.9 if active_kind==0 else .18)
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
	time+=dt;globe.rotation.y=lerp_angle(globe.rotation.y,desired_yaw,1-exp(-dt*7));swing=maxf(0,swing-dt)
	actor.rotation.z=sin(swing*23)*swing*.4
	actor.position.y=abs(sin(time*8))*.025 if move_tween and move_tween.is_running() else sin(time*1.8)*.014
	if is_instance_valid(rotor) and int(game.learning.data.build[1])>=IslandLearning.NEEDS[1]:rotor.rotate_z(dt*.7)
	for i in range(clouds.size()):
		var a=time*.025+i*TAU/clouds.size();clouds[i].position=Vector3(cos(a)*6.6,1.0+sin(a*2+i)*.6,sin(a)*5.2);clouds[i].rotation.y=-a
	var ba=time*.06;boat.position=Vector3(sin(ba)*4.25,2.05,cos(ba)*4.25);boat.basis=Basis(Quaternion(Vector3.UP,boat.position.normalized()));boat.rotate_object_local(Vector3.UP,ba);boat.scale=Vector3.ONE*.55;boat.visible=int(game.learning.data.build[0])>=IslandLearning.NEEDS[0]
	cursor.scale=Vector3.ONE*(1.0+sin(time*3)*.04)
	for i in range(effects.size()-1,-1,-1):
		var e=effects[i];e.t+=dt
		if e.t<0:e.node.visible=false;continue
		e.node.visible=true;var u=minf(1,e.t/e.duration);e.node.position=e.a.lerp(e.b,u)+Vector3.UP*sin(u*PI)*1.15;e.node.rotate_y(dt*5)
		if u>=1:e.node.queue_free();effects.remove_at(i)
	if game.learning.data.flags.get("water",false) and game.learning.completed() and int(time*8)!=int((time-dt)*8):
		var a=buildings[1].position;var b=buildings[2].position;var drop=pebble(globe,a,Vector3.ONE*.10,"A4EDF0")
		effects.append({"node":drop,"a":a,"b":b,"t":0.0,"duration":1.0,"seed":0})
