extends Node3D
class_name IslandGrove

const RADIUS=12.0
const ADDITIONS=[["deck","bench","camp"],["cistern","channel","workbench"],["orchard","fence","hive"]]
var game
var globe:Node3D
var builder:Node3D
var actor:Node3D
var buildings:Array=[]
var additions:Array=[]
var resources:Array=[[],[]]
var clouds:Array=[]
var effects:Array=[]
var limbs={}
var tools={}
var mats={}
var land={}
var markers={}
var facilities={}
var rotor:Node3D
var boat:Node3D
var cursor:Node3D
var desired_rotation=Quaternion.IDENTITY
var move_tween:Tween
var active_kind=0
var active_resource=0
var time=0.0
var swing=0.0
var work_point=Vector2.ZERO
var work_phase=0
var work_clock=0.0
var last_target=""
var current_tool=0
var ring_material:StandardMaterial3D
var selected_entry={}
var scenery:Node3D
var coast_count=-1
var terrain=IslandTerrain.new()
var worker:IslandWorker
var motion_speed=0.0
var travelled=0.0
var motion_previous=Vector3.ZERO
var travel_heading=0.0
var road_segments=0
var wildlife
var water

func mat(hex:String)->StandardMaterial3D:
	if mats.has(hex):return mats[hex]
	var m=StandardMaterial3D.new();m.albedo_color=Color(hex);m.roughness=.85;mats[hex]=m;return m
func model(name:String,parent:Node3D)->Node3D:
	var n=load("res://assets/models/"+name+".glb").instantiate();parent.add_child(n);return n
func surface(p:Vector2)->Vector3:return terrain.point(p)
func place(node:Node3D,p:Vector2,angle=0.0):
	var v=surface(p);node.position=v;node.basis=Basis(Quaternion(Vector3.UP,v.normalized()));node.rotate_object_local(Vector3.UP,angle)
func pebble(parent:Node3D,p:Vector3,s:Vector3,color:String)->MeshInstance3D:
	var n=MeshInstance3D.new();var mesh=SphereMesh.new();mesh.radius=.5;mesh.height=1;mesh.radial_segments=6;mesh.rings=3;n.mesh=mesh;n.material_override=mat(color);parent.add_child(n);n.position=p;n.scale=s;return n
func pop(node:Node3D,delay=0.0,base=Vector3.ONE):
	if node.has_meta("pop"):
		var old=node.get_meta("pop")
		if old is Tween and old.is_valid():old.kill()
	node.scale=base*.04
	var tw=create_tween();node.set_meta("pop",tw);tw.tween_property(node,"scale",base,.48).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
func drag(delta:Vector2):
	var axes=game.camera.global_basis
	# The grabbed surface follows the finger in both screen axes.
	desired_rotation=(Quaternion(axes.y,delta.x*.005)*Quaternion(axes.x,delta.y*.005)*desired_rotation).normalized()
func recenter():
	var p=surface(game.frontier.target(game.frontier.data.active)).normalized()
	desired_rotation=Quaternion(p,Vector3.UP)
func site_at(screen_pos:Vector2)->String:
	if is_instance_valid(game.hud):
		for id in game.hud.world_progress:
			var panel=game.hud.world_progress[id].panel
			if panel.visible and panel.get_global_rect().has_point(screen_pos):return id
	var nearest="";var distance=58.0
	for id in markers:
		# A finished place remains selectable for study, without an always-on upgrade sign.
		if not game.frontier.previewable(id):continue
		var p=markers[id].global_position;var normal=globe.global_basis*markers[id].position.normalized()
		if normal.dot((game.camera.global_position-p).normalized())<.20:continue
		var foot=game.camera.unproject_position(p);var center=game.camera.unproject_position(p+normal*.65)
		var d=minf(foot.distance_to(screen_pos),center.distance_to(screen_pos))
		if d<distance:distance=d;nearest=id
	return nearest
func progress_anchor(id:String)->Vector3:
	var anchor=markers[id]
	return anchor.global_position+anchor.global_basis.y*float(anchor.get_meta("label_height",.85))
func measure_progress_height(id:String,visual:Node3D):
	var height=.4
	for mesh in visual.find_children("*","MeshInstance3D",true,false):
		if not mesh.is_visible_in_tree():continue
		var box=mesh.get_aabb()
		for i in range(8):height=maxf(height,visual.to_local(mesh.to_global(box.get_endpoint(i))).y)
	markers[id].set_meta("label_height",height+.16)
func ring(parent:Node3D,radius:float,material:Material)->Node3D:
	var root=Node3D.new();parent.add_child(root)
	var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for segment in range(14):
		for j in range(4):
			var a=(segment+float(j)/5)*TAU/14;var b=(segment+float(j+1)/5)*TAU/14
			var p0=Vector3(cos(a)*(radius-.055),.065,sin(a)*(radius-.055));var p1=Vector3(cos(a)*(radius+.055),.065,sin(a)*(radius+.055))
			var p2=Vector3(cos(b)*(radius+.055),.065,sin(b)*(radius+.055));var p3=Vector3(cos(b)*(radius-.055),.065,sin(b)*(radius-.055))
			for v in [p0,p2,p1,p0,p3,p2]:st.add_vertex(v)
	st.generate_normals();var n=MeshInstance3D.new();n.mesh=st.commit();n.material_override=material;root.add_child(n);return root
func tile(cell:Vector2i,animate:bool):
	var anchor=Node3D.new();globe.add_child(anchor);place(anchor,IslandFrontier.point(cell));land[cell]=anchor
	if animate:pop(anchor,float(land.size()%3)*.07)
func terrain_geometry():
	var directions=[Vector2i(0,1),Vector2i(-1,1),Vector2i(-1,0),Vector2i(0,-1),Vector2i(1,-1),Vector2i(1,0)]
	for cell in land:
		var anchor=land[cell];var p=IslandFrontier.point(cell);var center=surface(p);var inv=anchor.basis.orthonormalized().inverse()
		for old in anchor.get_children():old.queue_free()
		var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var corners=[];var inside=[];var summit=[];var boundary=[]
		for i in range(6):boundary.append(not land.has(cell+directions[i]))
		for i in range(6):
			var angle=(i*60+30)*PI/180;var off=Vector2(cos(angle),sin(angle))*IslandFrontier.HEX
			var coast=boundary[i] or boundary[(i+5)%6]
			var point=surface(p+off);corners.append(point-point.normalized()*(.14 if coast else 0))
			inside.append(surface(p+off*.88));summit.append(surface(p+off*.60))
		var region=terrain.kind(cell);var green=Color(IslandTerrain.COLORS[region])
		for i in range(6):
			var j=(i+1)%6;var a=inside[i];var b=inside[j];var c=corners[i];var d=corners[j]
			st.set_color(green.lightened(.04 if i%3==0 else 0))
			for v in [center,summit[j],summit[i]]:st.add_vertex(inv*(v-center))
			st.set_color(green.darkened(.08 if region in ["quarry","mountain","plateau"] else .035))
			for v in [summit[i],summit[j],b,summit[i],b,a]:st.add_vertex(inv*(v-center))
			st.set_color(Color("D7C48B") if boundary[i] and region not in ["quarry","mountain","plateau","crystal"] else green.darkened(.07))
			for v in [a,b,d,a,d,c]:st.add_vertex(inv*(v-center))
			if boundary[i]:
				var low_a=c.normalized()*(RADIUS-.55);var low_b=d.normalized()*(RADIUS-.55)
				var mid_a=c.lerp(low_a,.35);var mid_b=d.lerp(low_b,.35)
				st.set_color(Color("A3AA98") if region in ["quarry","mountain","plateau","crystal"] else Color("B69B72"))
				for v in [c,d,mid_b,c,mid_b,mid_a]:st.add_vertex(inv*(v-center))
				st.set_color(Color("768B8D") if region in ["quarry","mountain","plateau","crystal"] else Color("A29174"))
				for v in [mid_a,mid_b,low_b,mid_a,low_b,low_a]:st.add_vertex(inv*(v-center))
		st.generate_normals();var n=MeshInstance3D.new();n.mesh=st.commit();var material=mat("FFFFFF").duplicate();material.vertex_color_use_as_albedo=true;material.vertex_color_is_srgb=true;material.cull_mode=BaseMaterial3D.CULL_DISABLED;n.material_override=material;anchor.add_child(n)
	if scenery:scenery.queue_free()
	scenery=Node3D.new();globe.add_child(scenery)
	# Short, authored approaches to a few useful places. Most land stays wild.
	road_segments=0
	trail([IslandFrontier.point(Vector2i(0,1))+Vector2(.25,-.25),Vector2(2.1,1.25),IslandFrontier.point(Vector2i(1,0))+Vector2(0,.72)])
	if game.frontier.done("sawmill"):
		var p=game.frontier.target("sawmill");trail([p+Vector2(.18,.82),p+Vector2(.7,1.05),p+Vector2(.95,1.5)])
	if game.frontier.done("kiln"):
		var p=game.frontier.target("kiln");trail([p+Vector2(0,.76),p+Vector2(-.65,1.02)])
	if game.frontier.available("garden"):
		var p=game.frontier.target("garden");trail([p+Vector2(0,-.78),p+Vector2(-.30,-1.2),p+Vector2(-.64,-1.55)])
	if game.frontier.available("windmill"):
		var p=game.frontier.target("windmill");trail([p+Vector2(-.12,-.86),p+Vector2(-.4,-1.27),p+Vector2(-.22,-1.66)])
	for cell in land:
		var p=IslandFrontier.point(cell)
		for i in range(6):
			if land.has(cell+directions[i]):continue
			var a=(i*60+30)*PI/180;var b=a+PI/3
			var off0=Vector2(cos(a),sin(a))*IslandFrontier.HEX;var off1=Vector2(cos(b),sin(b))*IslandFrontier.HEX
			var edge=(off0+off1)*.5
			# Quiet coves have pale submerged shelves, separate from the grassy edge.
			var shelf=pebble(scenery,surface(p+edge*1.12).normalized()*11.56,Vector3(.62,.035,.28),"60C5C7")
			shelf.basis=Basis(Quaternion(Vector3.UP,shelf.position.normalized()));shelf.rotate_object_local(Vector3.UP,-atan2(edge.y,edge.x)+PI/2);shelf.scale=Vector3(.72,.035,.28)
	coast_count=land.size()
func trail(points:Array):
	for i in range(points.size()-1):path_segment(points[i],points[i+1])
func path_segment(a:Vector2,b:Vector2):
	road_segments+=1
	var side=Vector2(-(b-a).y,(b-a).x).normalized()*.11;var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(6):
		var p=a.lerp(b,i/6.0);var q=a.lerp(b,(i+1)/6.0)
		for v in [p-side,q+side,p+side,p-side,q-side,q+side]:st.add_vertex(surface(v)*1.002)
	st.generate_normals();var n=MeshInstance3D.new();n.mesh=st.commit();n.material_override=mat("C9B983");scenery.add_child(n)
func marker(id:String):
	var anchor=Node3D.new();globe.add_child(anchor);place(anchor,game.frontier.target(id));markers[id]=anchor
	var icon=Node3D.new();anchor.add_child(icon);icon.name="Sign";icon.position.y=.42
	var h=pebble(icon,Vector3.ZERO,Vector3(.27,.13,.27),"FFF1D1");h.rotation_degrees=Vector3(0,45,0)
	if game.frontier.chapter(id).has("gate"):
		for i in range(3):
			var peak=MeshInstance3D.new();var cone=CylinderMesh.new();cone.top_radius=0;cone.bottom_radius=.27;cone.height=.5+i*.1;cone.radial_segments=6;peak.mesh=cone;peak.material_override=mat("A7CBC9");icon.add_child(peak);peak.position=Vector3((i-1)*.25,.15,0)
func add_resource(kind:int,p:Vector2,scale_factor:float,crystal=false):
	var a=Node3D.new();globe.add_child(a);place(a,p,p.x*.4)
	var prop=model("crystal" if crystal else "oak" if kind==0 else "ore",a);prop.scale=Vector3.ONE*scale_factor
	resources[kind].append({"anchor":a,"visual":prop,"p":p,"base":prop.scale,"cooldown":0.0,"crystal":crystal})
func decorate_cell(cell:Vector2i,animate:bool):
	var p=IslandFrontier.point(cell);var region=terrain.kind(cell);var is_grove=region=="grove";var is_quarry=region in ["quarry","plateau","mountain"];var is_crystal=region=="crystal"
	if cell==Vector2i(0,0) or is_grove:
		var offsets=[Vector2(-.58,-.32),Vector2(.40,-.52),Vector2(.68,.28)] if is_grove else [Vector2(-.53,-.48),Vector2(.38,-.42)]
		for k in range(offsets.size()):
			add_resource(0,p+offsets[k],[.79,.65,.51][k] if is_grove else [.77,.63][k])
			if animate:pop(resources[0][-1].visual,.3,resources[0][-1].base)
	elif is_quarry or is_crystal:
		add_resource(1,p+Vector2(-.35,-.35),.86,is_crystal);add_resource(1,p+Vector2(.45,.2),.65,is_crystal)
		if animate:
			for entry in [resources[1][-1],resources[1][-2]]:pop(entry.visual,.3,entry.base)
	var rng=RandomNumberGenerator.new();rng.seed=915+cell.x*101+cell.y*29
	for i in range(3):
		var a=Node3D.new();globe.add_child(a);var angle=i*TAU/3+rng.randf_range(-.3,.3)
		place(a,p+Vector2(cos(angle),sin(angle))*.94,angle)
		var shrub=model("coast_garden",a);var sc=rng.randf_range(.45,.8);shrub.scale=Vector3.ONE*sc
		if animate:pop(shrub,.25,Vector3.ONE*sc)
	if cell in [Vector2i(-2,1),Vector2i(1,2),Vector2i(0,-2),Vector2i(-1,2)]:
		var a=Node3D.new();globe.add_child(a);place(a,p+Vector2(-.62,-.55),.3);model("cypress",a).scale=Vector3.ONE*.87
	if cell in [Vector2i(1,0),Vector2i(0,1),Vector2i(1,3),Vector2i(-1,3),Vector2i(0,-1)]:
		var a=Node3D.new();globe.add_child(a);place(a,p+Vector2(.64,.47));model("lantern",a).scale=Vector3.ONE*.75
	if region in ["quarry","plateau","mountain"]:
		var a=Node3D.new();globe.add_child(a);place(a,p+Vector2(-.5,-.5),.3);var rocks=model("cliff_rocks",a);rocks.scale=Vector3.ONE*(1.0 if region=="mountain" else .48)
		if animate:pop(rocks,.3,rocks.scale)
	if region=="mountain":
		var a=Node3D.new();globe.add_child(a);place(a,p+Vector2(.65,-.5));model("cypress",a).scale=Vector3.ONE*.6
	if region=="wetland":
		for i in range(3):
			var a=Node3D.new();globe.add_child(a);place(a,p+Vector2(-.65+i*.55,-.48));model("reeds",a).scale=Vector3.ONE*.8
		var water=pebble(globe,surface(p+Vector2(-.6,.15)),Vector3(.65,.025,.50),"52B6BD");water.basis=Basis(Quaternion(Vector3.UP,water.position.normalized()));water.scale=Vector3(.65,.025,.50)
	if region=="shore":
		var a=Node3D.new();globe.add_child(a);place(a,p+Vector2(-.7,.4),.7);model("driftwood",a).scale=Vector3.ONE*.45
func setup(owner_node):
	game=owner_node
	var e=Environment.new();e.background_mode=Environment.BG_COLOR;e.background_color=Color("173D52");e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;e.ambient_light_color=Color("BBD9E4");e.ambient_light_energy=.37;e.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	var env=WorldEnvironment.new();env.environment=e;add_child(env)
	var sun=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-48,-35,0);sun.light_color=Color("FFF0DB");sun.light_energy=1.0;sun.shadow_enabled=true;sun.directional_shadow_max_distance=60;sun.shadow_bias=.025;add_child(sun)
	globe=Node3D.new();add_child(globe);var ocean=model("ocean",globe)
	water=load("res://scripts/water.gd").new();globe.add_child(water);water.setup(self,ocean)
	var pod_anchor=Node3D.new();globe.add_child(pod_anchor);place(pod_anchor,IslandFrontier.point(Vector2i(0,1)),PI);model("landing_pod",pod_anchor).scale=Vector3.ONE*.7
	var pier=Node3D.new();globe.add_child(pier);place(pier,IslandFrontier.point(Vector2i(0,1))+Vector2(.62,.95),-.5);model("pier",pier).scale=Vector3.ONE*.75
	for id in IslandFrontier.BUILD_IDS:marker(id)
	for c in IslandFrontier.CHAPTERS:marker(c.id)
	for i in range(3):
		var a=Node3D.new();globe.add_child(a);place(a,game.frontier.target(IslandFrontier.BUILD_IDS[i]),PI)
		var b=model(["cottage","windmill","garden"][i],a);b.scale=Vector3.ONE*.8;buildings.append(a)
		if i==1:rotor=b.find_child("Rotor",true,false)
		var extra=[]
		for j in range(3):
			var point=Node3D.new();globe.add_child(point);var offset=[Vector2(-1.1,.25),Vector2(.9,.65),Vector2(0,-1.15)][j];place(point,game.frontier.target(IslandFrontier.BUILD_IDS[i])+offset,PI+.4*j)
			var added=model(ADDITIONS[i][j],point);added.scale=Vector3.ONE*.64;added.visible=false;extra.append(added)
		additions.append(extra)
	for id in ["sawmill","kiln"]:
		var a=Node3D.new();globe.add_child(a);place(a,game.frontier.target(id),PI);var n=model(id,a);n.scale=Vector3.ONE*.8;facilities[id]=a
	ring_material=StandardMaterial3D.new();ring_material.albedo_color=Color.WHITE;ring_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;ring_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;ring_material.cull_mode=BaseMaterial3D.CULL_DISABLED
	cursor=Node3D.new();globe.add_child(cursor);ring(cursor,1.17,ring_material)
	builder=Node3D.new();globe.add_child(builder);place(builder,Vector2(.2,.9));actor=model("builder",builder);actor.scale=Vector3.ONE*.9
	for part in ["ArmL","ArmR","LegL","LegR","Body","KneeL","KneeR","ElbowL","ElbowR"]:limbs[part]=actor.find_child(part,true,false)
	for name in ["Axe","Pickaxe","Mallet"]:tools[name]=actor.find_child(name,true,false)
	for i in range(5):
		var c=model("cloud",globe);c.scale=Vector3.ONE*(1.1+i*.1);clouds.append(c)
	boat=model("boat",globe);boat.scale=Vector3.ONE*.7
	sync_buildings(false);worker=IslandWorker.new(self);worker.settle();prepare_resource(false);recenter();motion_previous=builder.position
func sync_buildings(animate=true):
	for cell in game.frontier.cells():
		if not land.has(cell):tile(cell,animate);decorate_cell(cell,animate)
	if coast_count!=land.size():terrain_geometry()
	for id in markers:
		var ready=game.frontier.available(id);var old_ready=markers[id].get_meta("available",ready)
		markers[id].set_meta("available",ready)
		markers[id].visible=game.frontier.previewable(id) and (not game.frontier.done(id) or id==game.frontier.data.active or id in IslandFrontier.BUILD_IDS)
		if animate and ready and not old_ready:
			pop(markers[id]);game.hud.toast(game.frontier.chapter(id).get("title","")+"可以接出来了")
		markers[id].get_node("Sign").visible=id not in IslandFrontier.BUILD_IDS and not game.frontier.done(id)
	for id in facilities:
		var was=facilities[id].visible;facilities[id].visible=game.frontier.done(id)
		if facilities[id].visible:measure_progress_height(id,facilities[id])
		if animate and not was and facilities[id].visible:pop(facilities[id])
	for i in range(3):
		buildings[i].visible=game.frontier.available(IslandFrontier.BUILD_IDS[i])
		var count=int(game.learning.data.build[i]);var fraction=float(count)/IslandLearning.NEEDS[i]
		for stage in buildings[i].find_children("Stage*","Node3D",true,false):
			var level=int(str(stage.name).trim_prefix("Stage"));var show_stage=level==0 or (count>0 and fraction>=float(level)/3);var was=stage.visible;stage.visible=show_stage
			if show_stage and not was and animate:pop(stage,float(level)*.06)
		for j in range(3):
			var extra=additions[i][j];var show_extra=int(game.learning.data.development[i])>=(j+1)*12;var was=extra.visible;extra.visible=show_extra
			if show_extra and not was and animate:pop(extra,0.0,Vector3.ONE*.64)
		measure_progress_height(IslandFrontier.BUILD_IDS[i],buildings[i])
	place(cursor,game.frontier.target(game.frontier.data.active))
	cursor.scale=Vector3.ONE*(1.35 if game.frontier.data.active in IslandFrontier.BUILD_IDS else 1.0)
	if animate:
		get_tree().create_timer(.75).timeout.connect(func():
			if not is_inside_tree():return
			for i in range(3):measure_progress_height(IslandFrontier.BUILD_IDS[i],buildings[i])
			for id in facilities:
				if facilities[id].visible:measure_progress_height(id,facilities[id])
		)
func nearest_land(p:Vector2)->Vector2:
	var result=Vector2.ZERO;var distance=INF
	for cell in land:
		var center=IslandFrontier.point(cell);var d=center.distance_to(p)
		if d<distance:distance=d;result=p if d<IslandFrontier.HEX*.76 else center+(p-center).normalized()*IslandFrontier.HEX*.65
	return result
func nearest_cell(p:Vector2)->Vector2i:
	var result=Vector2i.ZERO;var distance=INF
	for cell in land:
		var d=IslandFrontier.point(cell).distance_squared_to(p)
		if d<distance:result=cell;distance=d
	return result
func walking_route(origin:Vector2,target:Vector2)->Array:
	var first=nearest_cell(origin);var last=nearest_cell(target)
	var queue=[first];var previous={first:first};var directions=[Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1),Vector2i(1,-1),Vector2i(-1,1)]
	while not queue.is_empty():
		var cell=queue.pop_front()
		if cell==last:break
		for step in directions:
			var next=cell+step
			if land.has(next) and not previous.has(next):previous[next]=cell;queue.append(next)
	var route=[];var cell=last
	if not previous.has(last):return [nearest_land(origin)]
	while cell!=first:route.push_front(IslandFrontier.point(cell));cell=previous[cell]
	if not route.is_empty():route.push_front(IslandFrontier.point(first))
	route.append(target);return route
func walk_to(target:Vector2,duration_scale=1.0):
	target=nearest_land(target)
	if move_tween and move_tween.is_valid():move_tween.kill()
	var origin=terrain.coordinates(builder.position)
	var speed=1.1
	if worker and worker.work_left>0:speed=.95 if worker.phase==1 else 1.8
	move_tween=create_tween()
	for waypoint in walking_route(origin,target):
		if origin.distance_to(waypoint)<.025:continue
		var heading=atan2(-(waypoint-origin).x,-(waypoint-origin).y)
		move_tween.tween_method(func(p):
			travel_heading=lerp_angle(travel_heading,heading,1-exp(-get_process_delta_time()*9))
			place(builder,p,travel_heading),origin,waypoint,maxf(.15,origin.distance_to(waypoint)/speed))
		origin=waypoint
	var facing=work_point-target;var final_heading=atan2(-facing.x,-facing.y)
	move_tween.tween_method(func(_t):travel_heading=lerp_angle(travel_heading,final_heading,.2);place(builder,target,travel_heading),0.0,1.0,.2)
func prepare_resource(animate=true):
	active_kind=1 if game.frontier.site(game.frontier.data.active)==1 and not resources[1].is_empty() else 0
	var pool=resources[active_kind];var target=game.frontier.target(game.frontier.data.active)
	var candidates=[]
	for entry in pool:
		if entry.cooldown<=0:candidates.append(entry)
	if candidates.is_empty():candidates=pool
	candidates.sort_custom(func(a,b):return a.p.distance_to(target)<b.p.distance_to(target))
	if not candidates.is_empty():
		selected_entry=candidates[int(game.learning.data.harvested[active_kind])%mini(3,candidates.size())]
		active_resource=pool.find(selected_entry)
	place(cursor,target)
	if last_target!=game.frontier.data.active and animate:recenter()
	last_target=game.frontier.data.active
func set_tool(index:int):
	for i in range(3):tools[["Axe","Pickaxe","Mallet"][i]].visible=i==index
func work_stance(phase:int)->Vector2:
	var front=Vector2(0,1)
	if is_instance_valid(game.camera):
		var local_camera=globe.to_local(game.camera.global_position);var delta=local_camera-surface(work_point)
		front=Vector2(delta.x,delta.z).normalized()
	var side=Vector2(front.y,-front.x)
	return work_point+front*1.05+side*([-.24,.3,0.0,.4][phase%4])
func send_material(start:Vector3,target:Vector3,kind:String,count=4,duration=.7,delay=0.0):
	for i in range(count):
		var chip=model(kind,globe);chip.scale=Vector3.ONE*(.85 if kind in ["timber","plank","brick"] else .18)
		effects.append({"node":chip,"a":start,"b":target,"t":-delay-i*.055,"duration":duration})
func harvest(result:Dictionary):
	swing=.7
	worker.grant(game.mode,game.frontier.target(game.frontier.data.active),selected_entry,active_kind)
	var target=surface(game.frontier.target(game.frontier.data.active))+Vector3.UP*.3
	var start=builder.position+builder.basis.y*.8
	var material="timber" if active_kind==0 else "ore"
	if game.mode=="word" and not selected_entry.is_empty():
		var prop=selected_entry.visual
		if prop.has_meta("pop") and prop.get_meta("pop").is_valid():prop.get_meta("pop").kill()
		start=selected_entry.anchor.position+selected_entry.anchor.basis.y*.65;selected_entry.cooldown=9.0
		var t=create_tween();t.set_parallel(true);t.tween_property(prop,"rotation:z",-.65 if active_kind==0 else .25,.2).set_delay(1.4);t.tween_property(prop,"scale",Vector3.ONE*.03,.30).set_delay(1.54)
		if selected_entry.crystal:material="crystal"
	elif game.frontier.done("sawmill") and active_kind==0:material="plank"
	elif game.frontier.done("kiln") and active_kind==1:material="brick"
	var machine="sawmill" if active_kind==0 else "kiln"
	var processing=game.mode=="word" and material!="crystal" and game.frontier.done(machine) and game.frontier.data.active!=machine
	if processing:
		var midpoint=facilities[machine].position+facilities[machine].basis.y*.8
		send_material(start,midpoint,material,4,.45,1.5)
		get_tree().create_timer(2.0).timeout.connect(func():
			if is_inside_tree():send_material(midpoint,target,"plank" if machine=="sawmill" else "brick",4,.45)
		)
	else:send_material(start,target,material,6,.8,1.5 if game.mode=="word" else .2)
	for i in range(6):
		var chip=pebble(globe,start,Vector3.ONE*.1,"EBCB88" if active_kind==0 else "B9DFDB")
		effects.append({"node":chip,"a":start,"b":start+Vector3(sin(i*1.7)*.6,-.25,cos(i*1.7)*.6),"t":0.0,"duration":.4})
	get_tree().create_timer((2.6 if processing else 2.3) if game.mode=="word" else .8).timeout.connect(func():
		if not is_inside_tree():return
		sync_buildings();game.play_fx("build" if result.complete else "land")
	)
func _process(dt):
	if not is_instance_valid(globe):return
	time+=dt;work_clock+=dt;swing=maxf(0,swing-dt);globe.quaternion=globe.quaternion.slerp(desired_rotation,1-exp(-dt*10))
	var distance=builder.position.distance_to(motion_previous);motion_previous=builder.position
	if distance<1:travelled+=distance
	motion_speed=lerpf(motion_speed,distance/maxf(dt,.001) if distance<1 else 0.0,1-exp(-dt*14))
	if worker:worker.update(dt)
	if is_instance_valid(rotor) and game.learning.data.build[1]>=IslandLearning.NEEDS[1]:rotor.rotate_z(dt*.7)
	for id in facilities:
		if facilities[id].visible and id=="sawmill":facilities[id].find_child("SawWheel",true,false).rotate_z(dt*2.4)
	for i in range(clouds.size()):
		var a=time*.007+i*TAU/clouds.size();var p=Vector3(cos(a),.12+sin(a*2+i)*.16,sin(a)).normalized()*13.3
		clouds[i].position=p;clouds[i].basis=Basis(Quaternion(Vector3.UP,p.normalized()));clouds[i].scale=Vector3.ONE*(1.0+i*.08)
	var ba=time*.018;boat.position=Vector3(sin(ba)*10.4,5.2,cos(ba)*10.4)
	var normal=boat.position.normalized();var forward=Vector3(cos(ba),0,-sin(ba)).normalized();boat.basis=Basis(forward.cross(normal).normalized(),normal,-forward);boat.scale=Vector3.ONE*.7
	cursor.get_child(0).rotation.y=time*.35;ring_material.albedo_color=Color(1,1,.98,.72+.26*sin(time*2.6))
	for id in markers:
		markers[id].get_node("Sign").position.y=.38+sin(time*2+id.length())*.07
	for pool in resources:
		for entry in pool:
			if entry.cooldown>0:
				entry.cooldown-=dt
				if entry.cooldown<=0:entry.visual.rotation=Vector3.ZERO;pop(entry.visual,0.0,entry.base)
	for i in range(effects.size()-1,-1,-1):
		var e=effects[i];e.t+=dt
		if e.t<0:e.node.visible=false;continue
		e.node.visible=true;var u=minf(1,e.t/e.duration);e.node.position=e.a.lerp(e.b,u)+Vector3.UP*sin(u*PI)*1.05;e.node.rotate_y(dt*4)
		if u>=1:e.node.queue_free();effects.remove_at(i)
