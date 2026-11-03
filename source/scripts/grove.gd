extends Node3D
class_name IslandGrove

const RADIUS=12.0
const ADDITIONS=[["deck","bench","camp"],["cistern","channel","workbench"],["orchard","fence","hive"]]
const FACILITY_MODELS={"quarry":"stonecutter","sawmill":"sawmill","kiln":"kiln","meadow":"orchard_press","hill":"windpump","wetland":"weavery","plateau":"forge","crystal":"lensworks","mountain":"telescope","shipyard":"shipyard","sunreach":"orchard_press","coral":"glassworks","basalt":"basaltworks","tideworks":"tidalworks"}
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
var obstacles:Array=[]
var fixed_obstacles:Array=[]
var navigation=AStar2D.new()
var nav_grid={}
var nav_components={}
var navigation_signature=""
var ground_faces={}
var walk_goal=Vector2.ZERO
var ring_clock=0.0
var production_route={}
var transporting=false
var ferry:Node3D
var ferry_tween:Tween
var sea_routes
var avatar:Node3D
var avatar_tool_homes={}
const AvatarScript=preload("res://scripts/avatar.gd")
const WALK_CLEARANCE=.24
const NAV_STEP=.24

func mat(hex:String)->StandardMaterial3D:
	if mats.has(hex):return mats[hex]
	var m=StandardMaterial3D.new();m.albedo_color=Color(hex);m.roughness=.85;mats[hex]=m;return m
func model(name:String,parent:Node3D)->Node3D:
	var n=load("res://assets/models/"+name+".glb").instantiate();parent.add_child(n);return n
func validate_local_avatar(path:String)->Dictionary:
	var result=prepare_local_avatar(path)
	if result.ok:result.candidate.free();result.erase("candidate")
	return result
func prepare_local_avatar(path:String)->Dictionary:
	var candidate=AvatarScript.new();actor.add_child(candidate);candidate.hide()
	var result=candidate.load_file(self,path)
	if not result.ok:candidate.free();return result
	result.candidate=candidate;return result
func load_local_avatar(path:String)->Dictionary:
	var result=prepare_local_avatar(path)
	if not result.ok:return result
	return activate_local_avatar(result.candidate)
func activate_local_avatar(candidate:Node3D)->Dictionary:
	if not is_instance_valid(candidate) or not candidate is IslandAvatar or candidate.world!=self or not candidate.info.get("ok",false):return {"ok":false,"error":"人物模型尚未准备好"}
	if is_instance_valid(avatar):avatar.free()
	avatar=candidate;avatar.enabled=true;avatar.show()
	actor.find_child("ContinuousBody",true,false).hide()
	worker.rest_ground_ready=false;navigation_signature="";rebuild_navigation()
	if move_tween and move_tween.is_valid():move_tween.kill()
	if not transporting:
		var p=terrain.coordinates(builder.position);place(builder,safe_point(p),travel_heading)
		if worker.work_left>0:walk_to(work_stance(worker.phase))
	worker.update_skin()
	return avatar.info.duplicate()
func clear_local_avatar():
	if is_instance_valid(avatar):avatar.free()
	avatar=null
	for name in tools:tools[name].position=avatar_tool_homes.get(name,Vector3.ZERO)
	worker.carry.position=Vector3.ZERO;actor.find_child("ContinuousBody",true,false).show()
	worker.rest_ground_ready=false;navigation_signature="";rebuild_navigation();worker.update_skin()
func surface(p:Vector2)->Vector3:return terrain.point(p)
func ground_point(p:Vector2)->Vector3:
	var normal=surface(p).normalized();var found=Vector3.ZERO
	for cell in ground_faces:
		if IslandFrontier.point(cell).distance_squared_to(p)>IslandFrontier.HEX*IslandFrontier.HEX*1.1:continue
		for face in ground_faces[cell]:
			var hit=Geometry3D.ray_intersects_triangle(normal*30,-normal,face[0],face[1],face[2])
			if hit is Vector3 and hit.length_squared()>found.length_squared():found=hit
	return found if found.length_squared()>1.0 else surface(p)
func place(node:Node3D,p:Vector2,angle=0.0):
	node.position=surface(p);node.basis=terrain.surface_basis(p);node.rotate_object_local(Vector3.UP,angle)
func pebble(parent:Node3D,p:Vector3,s:Vector3,color:String)->MeshInstance3D:
	var n=MeshInstance3D.new();var mesh=SphereMesh.new();mesh.radius=.5;mesh.height=1;mesh.radial_segments=6;mesh.rings=3;n.mesh=mesh;n.material_override=mat(color);parent.add_child(n);n.position=p;n.scale=s;return n
func pop(node:Node3D,delay=0.0,base=Vector3.ONE):
	node.set_meta("full_scale",base)
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
	var n=MeshInstance3D.new();n.material_override=material;root.add_child(n);n.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	update_selection_ring();return root
func update_selection_ring():
	if not is_instance_valid(cursor) or cursor.get_child_count()==0:return
	cursor.transform=Transform3D.IDENTITY
	var radius=1.17*(1.35 if game.frontier.data.active in IslandFrontier.BUILD_IDS else 1.0)
	var center=game.frontier.target(game.frontier.data.active)
	var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for segment in range(14):
		for j in range(4):
			var a=(segment+float(j)/5)*TAU/14+time*.35;var b=(segment+float(j+1)/5)*TAU/14+time*.35
			var p0=center+Vector2(cos(a),sin(a))*(radius-.055);var p1=center+Vector2(cos(a),sin(a))*(radius+.055)
			var p2=center+Vector2(cos(b),sin(b))*(radius+.055);var p3=center+Vector2(cos(b),sin(b))*(radius-.055)
			for p in [p0,p2,p1,p0,p3,p2]:
				var v=ground_point(p);st.add_vertex(v+v.normalized()*.085)
	st.generate_normals();cursor.get_child(0).get_child(0).mesh=st.commit()
func tile(cell:Vector2i,animate:bool):
	var anchor=Node3D.new();globe.add_child(anchor);place(anchor,IslandFrontier.point(cell));land[cell]=anchor
	if animate:pop(anchor,float(land.size()%3)*.07)
func terrain_geometry():
	ground_faces.clear()
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
		var region=terrain.kind(cell);var green=Color(IslandTerrain.COLORS[region]);var variant=terrain.variant(cell)
		green=green.lightened(.035*variant) if variant!=1 else green.darkened(.035)
		var faces=[]
		for i in range(6):
			var j=(i+1)%6;var a=inside[i];var b=inside[j];var c=corners[i];var d=corners[j]
			for face in [[center,summit[j],summit[i]],[summit[i],summit[j],b],[summit[i],b,a],[a,b,d],[a,d,c]]:faces.append(face)
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
		ground_faces[cell]=faces
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
	for id in ["shipyard","sunreach","coral","basalt","tideworks","mountain"]:
		if game.frontier.done(id):
			var p=game.frontier.target(id);trail([p+Vector2(.05,.9),p+Vector2(.4,1.05),p+Vector2(.6,.8)])
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
func add_resource(kind:int,p:Vector2,scale_factor:float,crystal=false,region="",visual_name="",material=""):
	var a=Node3D.new();globe.add_child(a);place(a,p,p.x*.4)
	if visual_name.is_empty():visual_name="crystal" if crystal else "oak" if kind==0 else "ore"
	var prop=model(visual_name,a);prop.scale=Vector3.ONE*scale_factor
	if region.is_empty():region=terrain.kind(terrain.cell_at(p))
	if material.is_empty():material="crystal" if crystal else "timber" if kind==0 else "ore"
	resources[kind].append({"anchor":a,"visual":prop,"p":p,"base":prop.scale,"cooldown":0.0,"crystal":crystal,"region":region,"material":material})
func decor_prop(name:String,p:Vector2,scale_factor=1.0,angle=0.0,solid=false)->Node3D:
	var anchor=Node3D.new();globe.add_child(anchor);place(anchor,p,angle)
	var visual=model(name,anchor);visual.scale=Vector3.ONE*scale_factor
	if solid:fixed_obstacles.append(anchor)
	return anchor
func decorate_cell(cell:Vector2i,animate:bool):
	var p=IslandFrontier.point(cell);var region=terrain.kind(cell);var v=terrain.variant(cell)
	var rng=RandomNumberGenerator.new();rng.seed=915+cell.x*101+cell.y*29
	var resource_begin=[resources[0].size(),resources[1].size()]
	# Each three-tile chapter is authored as a useful centerpiece, a natural landmark,
	# and a quieter connecting shore. The same decoration is never stamped three times.
	if cell==Vector2i.ZERO or region=="grove":
		var offsets=[Vector2(-.65,-.30),Vector2(.30,-.60),Vector2(.65,.25)] if v==0 else [Vector2(-.6,.15),Vector2(.5,-.35)] if v==1 else [Vector2(.0,-.55)]
		for i in range(offsets.size()):add_resource(0,p+offsets[i],.78-i*.10,false,"grove")
		if v==2:decor_prop("driftwood",p+Vector2(.3,.35),.65,.4)
	elif region=="quarry":
		if v==0:
			add_resource(1,p+Vector2(-.6,-.45),.7,false,region)
			decor_prop("cliff_rocks",p+Vector2(.55,.30),.47,.7)
		elif v==1:
			# A clear working apron for the stone cutter, with a single large seam behind.
			add_resource(1,p+Vector2(-.65,-.7),.78,false,region)
		else:
			for i in range(3):add_resource(1,p+Vector2(-.6+i*.5,-.28+sin(i)*.5),.35+i*.12,false,region)
	elif region=="plateau":
		if v==0:
			decor_prop("rock_arch",p+Vector2(-.25,-.25),.65,.5,true)
			add_resource(1,p+Vector2(.65,.40),1.75,false,region,"iron_ore","iron_ore")
		elif v==1:
			add_resource(1,p+Vector2(-.62,-.70),1.45,false,region,"iron_ore","iron_ore")
		else:
			decor_prop("basalt_columns",p+Vector2(.05,-.30),.55,.8,true)
			add_resource(1,p+Vector2(-.55,.42),1.9,false,region,"iron_ore","iron_ore")
	elif region=="mountain":
		if v==0:
			for pair in [[Vector2(-.55,-.3),.70],[Vector2(.46,.22),.48]]:decor_prop("cypress",p+pair[0],pair[1],rng.randf()*TAU)
		elif v==1:
			decor_prop("lantern",p+Vector2(.65,.65),.65)
		else:
			decor_prop("cliff_rocks",p+Vector2(-.15,-.10),1.05,.95,true)
			decor_prop("cypress",p+Vector2(.65,.50),.32)
	elif region=="crystal":
		if v==0:
			add_resource(1,p+Vector2(-.70,-.55),.63,true,region)
		elif v==1:
			decor_prop("rock_arch",p+Vector2(.0,-.25),.57,-.7,true)
			add_resource(1,p+Vector2(-.60,.33),1.05,true,region)
		else:
			for i in range(4):
				var angle=.3+i*.7;add_resource(1,p+Vector2(cos(angle),sin(angle))*.64,.28+i*.10,true,region)
	elif region=="wetland":
		var count=[3,1,5][v]
		for i in range(count):
			var angle=.5+i*TAU/maxi(1,count);var offset=Vector2(cos(angle),sin(angle))*(.76 if v==1 else .58)
			add_resource(0,p+offset,.55+rng.randf()*.25,false,region,"reeds","reed_bundle")
		if v==2:decor_prop("driftwood",p+Vector2(.1,.15),.58,.9)
	elif region=="meadow":
		if v==0:decor_prop("orchard",p+Vector2(-.10,-.15),.55,.2)
		elif v==2:decor_prop("coast_garden",p+Vector2(.55,-.5),1.0)
		add_resource(0,p+Vector2(-.6,-.6),1.0,false,region,"fruit_crate","fruit_crate")
	elif region=="hill":
		if v==0:decor_prop("cypress",p+Vector2(-.5,-.3),.75)
		elif v==1:decor_prop("coast_garden",p+Vector2(-.6,-.7),.7)
		add_resource(0,p+Vector2(-.6,.5),.7,false,region,"water_jar","water_jar")
	elif region=="shipyard":
		if v==0:
			for i in range(3):decor_prop("hardwood",p+Vector2(-.1+i*.25,-.25),1.2,.3)
		elif v==2:
			decor_prop("pier",p+Vector2(-.4,.3),.70,.5,true)
			decor_prop("sailcloth",p+Vector2(.50,-.3),1.8)
	elif region=="sunreach":
		var offsets=[Vector2(-.65,-.65)] if v==0 else [Vector2(-.42,-.2),Vector2(.60,.35)] if v==1 else [Vector2(.20,-.30)]
		for i in range(offsets.size()):add_resource(0,p+offsets[i],.70+i*.14,false,region,"palm","hardwood")
		if v==2:decor_prop("driftwood",p+Vector2(-.45,.45),.68,.7)
	elif region=="coral":
		if v==1:decor_prop("rock_arch",p+Vector2(.25,-.15),.58,.2,true)
		for i in range([1,2,4][v]):
			var a=.8+i*1.4;add_resource(1,p+Vector2(cos(a),sin(a))*.70,1.2+i*.18,false,region,"sea_glass","sea_glass")
	elif region=="basalt":
		if v==1:decor_prop("basalt_columns",p+Vector2(.08,.15),.9,.35,true)
		elif v==2:decor_prop("rock_arch",p+Vector2(-.15,-.4),.5,1.1,true)
		add_resource(1,p+Vector2(-.55,-.62),1.55+v*.16,false,region,"basalt_ore","basalt_ore")
	elif region=="tideworks":
		if v==1:
			for i in range(3):decor_prop("stone_pipe",p+Vector2(-.45+i*.42,-.2),1.4,.2)
		elif v==2:decor_prop("reeds",p+Vector2(-.5,-.5),.7)
		add_resource(0,p+Vector2(.6,.4),.8,false,region,"water_jar","water_jar")
	elif region=="shore":decor_prop("driftwood",p+Vector2(-.7,.4),.45,.7)
	var shrubs=0 if region in ["mountain","basalt","crystal"] else 1 if region in ["plateau","quarry","coral","shipyard"] else 2
	for i in range(shrubs):
		var a=rng.randf()*TAU;decor_prop("coast_garden",p+Vector2(cos(a),sin(a))*.98,rng.randf_range(.32,.58),a)
	if cell in [Vector2i(1,0),Vector2i(0,1),Vector2i(1,3),Vector2i(-1,3),Vector2i(0,-1)]:decor_prop("lantern",p+Vector2(.64,.47),.65)
	if animate:
		for kind in range(2):
			for i in range(resource_begin[kind],resources[kind].size()):pop(resources[kind][i].visual,.3,resources[kind][i].base)
func setup(owner_node):
	game=owner_node
	var e=Environment.new();e.background_mode=Environment.BG_COLOR;e.background_color=Color("173D52");e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;e.ambient_light_color=Color("BBD9E4");e.ambient_light_energy=.37;e.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	var env=WorldEnvironment.new();env.environment=e;add_child(env)
	var sun=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-48,-35,0);sun.light_color=Color("FFF0DB");sun.light_energy=1.0;sun.shadow_enabled=true;sun.directional_shadow_max_distance=60;sun.shadow_bias=.025;add_child(sun)
	globe=Node3D.new();add_child(globe);var ocean=model("ocean",globe)
	water=load("res://scripts/water.gd").new();globe.add_child(water);water.setup(self,ocean)
	var pod_anchor=Node3D.new();globe.add_child(pod_anchor);place(pod_anchor,IslandFrontier.point(Vector2i(0,1)),PI);model("landing_pod",pod_anchor).scale=Vector3.ONE*.7
	fixed_obstacles.append(pod_anchor)
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
	for id in FACILITY_MODELS:
		var a=Node3D.new();globe.add_child(a);place(a,game.frontier.target(id),PI)
		var n=model(FACILITY_MODELS[id],a);n.scale=Vector3.ONE*(.62 if id=="mountain" else .85 if id=="shipyard" else .72)
		facilities[id]=a
	ring_material=StandardMaterial3D.new();ring_material.albedo_color=Color.WHITE;ring_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;ring_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;ring_material.cull_mode=BaseMaterial3D.CULL_DISABLED
	cursor=Node3D.new();globe.add_child(cursor);ring(cursor,1.17,ring_material)
	builder=Node3D.new();globe.add_child(builder);place(builder,Vector2(.2,.9));actor=model("builder",builder);actor.scale=Vector3.ONE*IslandWorker.ACTOR_SCALE
	for part in ["ArmL","ArmR","LegL","LegR","Body","KneeL","KneeR","ElbowL","ElbowR"]:limbs[part]=actor.find_child(part,true,false)
	for name in ["Axe","Pickaxe","Mallet"]:tools[name]=actor.find_child(name,true,false);avatar_tool_homes[name]=tools[name].position
	for i in range(5):
		var c=model("cloud",globe);c.scale=Vector3.ONE*(1.1+i*.1);clouds.append(c)
	boat=model("boat",globe);boat.scale=Vector3.ONE*.7
	ferry=model("boat",globe);ferry.name="WorkingFerry";ferry.scale=Vector3.ONE*.8;ferry.hide()
	sea_routes=preload("res://scripts/sea_routes.gd").new(self)
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
	update_selection_ring();rebuild_navigation()
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
func stable_point(node:Node3D,point:Vector3)->Vector3:
	# Collision bounds use the final scale while a newly built model pops in.
	var current=node
	while current!=globe and current is Node3D:
		var basis=Basis.from_euler(Vector3.ZERO if current.name=="Rotor" else current.rotation).scaled(current.get_meta("full_scale",current.scale))
		point=basis*point+current.position;current=current.get_parent()
	return point
func add_obstacle(visual:Node3D,label:String,reserve_finished=false):
	if not visual.is_visible_in_tree():return
	var points=PackedVector2Array()
	for mesh in visual.find_children("*","MeshInstance3D",true,false):
		if not reserve_finished and not mesh.is_visible_in_tree():continue
		var box=mesh.get_aabb()
		for i in range(8):points.append(terrain.coordinates(stable_point(mesh,box.get_endpoint(i))))
	if points.size()>2:
		var bounds=Rect2(points[0],Vector2.ZERO)
		for point in points:bounds=bounds.expand(point)
		obstacles.append({"id":label,"polygon":Geometry2D.convex_hull(points),"bounds":bounds})
func on_land(p:Vector2)->bool:
	# Axial hex rounding stays constant-time across the three island charts.
	var r=p.y/(1.5*IslandFrontier.HEX);var q=p.x/(sqrt(3.0)*IslandFrontier.HEX)-r*.5;var s=-q-r
	var iq=roundi(q);var ir=roundi(r);var ids=roundi(s)
	var dq=absf(iq-q);var dr=absf(ir-r);var ds=absf(ids-s)
	if dq>dr and dq>ds:iq=-ir-ids
	elif dr>ds:ir=-iq-ids
	return land.has(Vector2i(iq,ir))
func clear_ground(p:Vector2,clearance=WALK_CLEARANCE)->bool:
	if is_instance_valid(avatar):clearance=maxf(clearance,avatar.clearance)
	if not on_land(p):return false
	for i in range(8):
		if not on_land(p+Vector2.from_angle(i*TAU/8)*minf(clearance,.20)):return false
	for obstacle in obstacles:
		if not obstacle.bounds.grow(clearance).has_point(p):continue
		var polygon:PackedVector2Array=obstacle.polygon
		if Geometry2D.is_point_in_polygon(p,polygon):return false
		for i in range(polygon.size()-1):
			if p.distance_to(Geometry2D.get_closest_point_to_segment(p,polygon[i],polygon[i+1]))<clearance:return false
	return true
func clear_segment(a:Vector2,b:Vector2,clearance=WALK_CLEARANCE)->bool:
	var count=maxi(1,ceili(a.distance_to(b)/.10))
	for i in range(count+1):
		if not clear_ground(a.lerp(b,float(i)/count),clearance):return false
	return true
func rebuild_navigation():
	obstacles.clear()
	for node in fixed_obstacles:add_obstacle(node,"landing")
	for i in range(buildings.size()):
		add_obstacle(buildings[i],IslandFrontier.BUILD_IDS[i],true)
		for j in range(additions[i].size()):add_obstacle(additions[i][j],ADDITIONS[i][j])
	for id in facilities:add_obstacle(facilities[id],id)
	var signature=str(land.size())+str(avatar.clearance if is_instance_valid(avatar) else WALK_CLEARANCE)
	for obstacle in obstacles:
		signature+=obstacle.id
		for point in obstacle.polygon:signature+=str(Vector2i(roundi(point.x*1000),roundi(point.y*1000)))
	if signature==navigation_signature:return
	navigation_signature=signature
	navigation.clear();nav_grid.clear();nav_components.clear()
	var candidates={}
	for cell in land:
		var center=IslandFrontier.point(cell);var lower=center-Vector2.ONE*IslandFrontier.HEX;var upper=center+Vector2.ONE*IslandFrontier.HEX
		for x in range(floori(lower.x/NAV_STEP),ceili(upper.x/NAV_STEP)+1):
			for y in range(floori(lower.y/NAV_STEP),ceili(upper.y/NAV_STEP)+1):candidates[Vector2i(x,y)]=true
	for key in candidates:
		var point=Vector2(key)*NAV_STEP
		if clear_ground(point):
			var id=nav_grid.size();nav_grid[key]=id;navigation.add_point(id,point)
	for key in nav_grid:
		for step in [Vector2i(1,0),Vector2i(0,1),Vector2i(1,1),Vector2i(1,-1)]:
			if nav_grid.has(key+step) and clear_segment(Vector2(key)*NAV_STEP,Vector2(key+step)*NAV_STEP):navigation.connect_points(nav_grid[key],nav_grid[key+step])
	for id in navigation.get_point_ids():
		if nav_components.has(id):continue
		var queue=[id];nav_components[id]=id
		while not queue.is_empty():
			var next=queue.pop_back()
			for neighbor in navigation.get_point_connections(next):
				if not nav_components.has(neighbor):nav_components[neighbor]=id;queue.append(neighbor)
	if worker and move_tween and move_tween.is_running():walk_to(walk_goal)
func safe_point(wanted:Vector2,clearance=WALK_CLEARANCE,from=Vector2(INF,INF))->Vector2:
	if navigation.get_point_count()==0:return wanted
	if not from.is_finite():from=terrain.coordinates(builder.position) if is_instance_valid(builder) else Vector2.ZERO
	var component=nav_components[navigation.get_closest_point(from)]
	if clear_ground(wanted,clearance) and nav_components[navigation.get_closest_point(wanted)]==component:return wanted
	var best=wanted;var score=INF
	for id in navigation.get_point_ids():
		var p=navigation.get_point_position(id);var distance=p.distance_squared_to(wanted)
		if distance<score and nav_components[id]==component and clear_ground(p,clearance):score=distance;best=p
	return best
func walking_route(origin:Vector2,target:Vector2)->Array:
	if navigation.get_point_count()==0:return []
	target=safe_point(target,WALK_CLEARANCE,origin)
	if clear_segment(origin,target):return [target]
	var first=navigation.get_closest_point(origin);var last=navigation.get_closest_point(target)
	var path=Array(navigation.get_point_path(first,last))
	if path.is_empty():return []
	path.append(target)
	var route=[];var from=origin;var index=0
	while index<path.size():
		var far=index
		for next in range(index,path.size()):
			if clear_segment(from,path[next]):far=next
			else:break
		route.append(path[far]);from=path[far];index=far+1
	return route
func walk_to(target:Vector2,duration_scale=1.0):
	if transporting:return
	var origin=terrain.coordinates(builder.position)
	target=nearest_land(target)
	if terrain.chart_at(origin)!=terrain.chart_at(target) and game.frontier.done("shipyard"):
		ferry_to(safe_point(target,WALK_CLEARANCE,target));return
	target=safe_point(target,WALK_CLEARANCE,origin)
	walk_goal=target
	if move_tween and move_tween.is_valid():move_tween.kill()
	var speed=worker.travel_speed() if worker else IslandWorker.WALK_SPEED
	move_tween=create_tween()
	var route=walking_route(origin,target)
	if route.is_empty():move_tween.kill();return
	for waypoint in route:
		if origin.distance_to(waypoint)<.025:continue
		var heading=atan2(-(waypoint-origin).x,-(waypoint-origin).y)
		move_tween.tween_method(func(p):
			travel_heading=lerp_angle(travel_heading,heading,1-exp(-get_process_delta_time()*9))
			place(builder,p,travel_heading),origin,waypoint,maxf(.15,origin.distance_to(waypoint)/speed))
		origin=waypoint
	var reached:Vector2=route[-1];var facing=work_point-reached;var final_heading=atan2(-facing.x,-facing.y)
	move_tween.tween_method(func(_t):travel_heading=lerp_angle(travel_heading,final_heading,.2);place(builder,reached,travel_heading),0.0,1.0,.2)
func ferry_to(target:Vector2):
	if transporting:return
	var path=sea_routes.route(terrain.coordinates(builder.position),target)
	if path.is_empty():return
	if move_tween and move_tween.is_valid():move_tween.kill()
	transporting=true;walk_goal=target;worker.suspend_for_transport(true);actor.hide()
	ferry_tween=create_tween();ferry_tween.tween_interval(.18)
	ferry_tween.tween_callback(func():ferry.show();actor.show())
	for i in range(path.size()-1):
		var a:Vector3=path[i];var b:Vector3=path[i+1]
		ferry_tween.tween_method(func(t):
			var normal=a.slerp(b,t).normalized();var ahead=a.slerp(b,minf(1,t+.02)).normalized()-normal
			if ahead.length_squared()<.00001:ahead=b-a
			ahead=(ahead-normal*ahead.dot(normal)).normalized()
			var basis=Basis(ahead.cross(normal).normalized(),normal,-ahead)
			ferry.position=normal*(water.surface_radius(normal,time)+.12);ferry.basis=basis.scaled(Vector3.ONE*.8)
			builder.position=ferry.position+normal*.33;builder.basis=basis
		,0.0,1.0,maxf(.18,a.angle_to(b)*2.8))
	ferry_tween.tween_callback(func():
		ferry.hide();place(builder,target,travel_heading);motion_previous=builder.position;motion_speed=0
		transporting=false;worker.suspend_for_transport(false)
	)
func prepare_resource(animate=true):
	production_route=game.frontier.work_route()
	active_kind=int(production_route.tool)
	var pool=resources[active_kind];var target=game.frontier.target(game.frontier.data.active)
	var candidates=[]
	for entry in pool:
		if entry.region==production_route.source and entry.cooldown<=0:candidates.append(entry)
	if candidates.is_empty():
		for entry in pool:
			if entry.region==production_route.source:candidates.append(entry)
	if candidates.is_empty():
		for entry in pool:
			if terrain.chart_at(entry.p)==terrain.chart_at(target):candidates.append(entry)
	if candidates.is_empty():candidates=pool
	candidates.sort_custom(func(a,b):return a.p.distance_to(target)<b.p.distance_to(target))
	if not candidates.is_empty():
		selected_entry=candidates[int(game.learning.data.harvested[active_kind])%mini(3,candidates.size())]
		active_resource=pool.find(selected_entry)
	else:selected_entry={}
	update_selection_ring()
	if last_target!=game.frontier.data.active and animate:recenter()
	last_target=game.frontier.data.active
func set_tool(index:int):
	for i in range(3):tools[["Axe","Pickaxe","Mallet"][i]].visible=i==index
func work_stance(phase:int)->Vector2:
	var front=Vector2(0,1)
	if is_instance_valid(game.camera):
		var local_camera=globe.to_local(game.camera.global_position);var delta=local_camera-surface(work_point)
		var chart_delta=terrain.chart_basis(terrain.chart_at(work_point)).inverse()*delta
		front=Vector2(chart_delta.x,chart_delta.z).normalized()
	var side=Vector2(front.y,-front.x)
	var distance=.76 if worker and worker.phase==0 else 1.15
	var wanted=work_point+front*distance+side*([-.18,.22,0.0,.27][phase%4])
	return safe_point(wanted,WALK_CLEARANCE,nearest_land(work_point))
func send_material(start:Vector3,target:Vector3,kind:String,count=4,duration=.7,delay=0.0):
	for i in range(count):
		var chip=model(kind,globe);chip.scale=Vector3.ONE*(.55 if kind not in ["ore","crystal"] else .15)
		effects.append({"node":chip,"a":start,"b":target,"t":-delay-i*.055,"duration":duration})
func harvest(result:Dictionary):
	swing=.7
	var route=production_route.duplicate(true)
	var destination=game.frontier.target(str(route.destination))
	worker.grant(game.mode,destination,selected_entry,active_kind)
	var target=surface(destination);target+=target.normalized()*.30
	var start=builder.position+builder.basis.y*.55
	var raw=str(route.raw);var product=str(route.product)
	if not selected_entry.is_empty():
		start=selected_entry.anchor.position+selected_entry.anchor.basis.y*.45
		if game.mode=="word":
			var prop=selected_entry.visual
			if prop.has_meta("pop") and prop.get_meta("pop").is_valid():prop.get_meta("pop").kill()
			selected_entry.cooldown=9.0
			var t=create_tween();t.set_parallel(true)
			t.tween_property(prop,"rotation:z",-.35 if active_kind==0 else .18,.2).set_delay(1.4)
			t.tween_property(prop,"scale",Vector3.ONE*.03,.30).set_delay(1.54)
	var departure=start;var cargo_kind=raw;var delay=1.5
	for processor in route.processors:
		if not facilities.has(processor) or not game.frontier.done(processor):continue
		var midpoint=facilities[processor].position+facilities[processor].basis.y*.65
		send_material(departure,midpoint,cargo_kind,3,.65,delay)
		departure=midpoint;cargo_kind=str(IslandFrontier.PRODUCTION[processor].product);delay+=.75
		pulse_facility(str(processor),delay)
	send_material(departure,target,cargo_kind,3,.75,delay)
	for i in range(4):
		var chip=pebble(globe,start,Vector3.ONE*.065,"EBCB88" if active_kind==0 else "B9DFDB")
		var side=builder.basis.x*sin(i*1.7)*.4+builder.basis.z*cos(i*1.7)*.4
		effects.append({"node":chip,"a":start,"b":start+side-builder.basis.y*.16,"t":-1.45,"duration":.4})
	get_tree().create_timer(delay+.8).timeout.connect(func():
		if not is_inside_tree():return
		sync_buildings();game.play_fx("build" if result.complete else "land")
	)
func pulse_facility(id:String,delay:float):
	get_tree().create_timer(delay).timeout.connect(func():
		if not is_inside_tree() or not facilities.has(id):return
		var base=facilities[id];var ring=pebble(globe,base.position+base.basis.y*.65,Vector3.ONE*.09,"F3D78C")
		effects.append({"node":ring,"a":ring.position,"b":ring.position+base.basis.y*.5,"t":0.0,"duration":.55})
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
		if not facilities[id].visible:continue
		var part_name={"sawmill":"SawWheel","quarry":"CutterWheel","hill":"PumpRotor","tideworks":"TideWheel"}.get(id,"")
		if not part_name.is_empty():
			var moving_part=facilities[id].find_child(part_name,true,false)
			if moving_part:
				if id=="tideworks":moving_part.rotate_x(dt*.45)
				else:moving_part.rotate_z(dt*(2.4 if id=="sawmill" else .8))
	for i in range(clouds.size()):
		var a=time*.007+i*TAU/clouds.size();var p=Vector3(cos(a),.12+sin(a*2+i)*.16,sin(a)).normalized()*13.3
		clouds[i].position=p;clouds[i].basis=Basis(Quaternion(Vector3.UP,p.normalized()));clouds[i].scale=Vector3.ONE*(1.0+i*.08)
	var ba=time*.018;boat.position=Vector3(sin(ba)*10.4,5.2,cos(ba)*10.4)
	var normal=boat.position.normalized();var forward=Vector3(cos(ba),0,-sin(ba)).normalized();boat.basis=Basis(forward.cross(normal).normalized(),normal,-forward);boat.scale=Vector3.ONE*.7
	ring_clock+=dt
	if ring_clock>.05:ring_clock=0;update_selection_ring()
	ring_material.albedo_color=Color(1,1,.98,.72+.26*sin(time*2.6))
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
		e.node.visible=true;var u=minf(1,e.t/e.duration)
		var flight_normal=e.a.normalized().slerp(e.b.normalized(),u).normalized()
		e.node.position=flight_normal*(lerpf(e.a.length(),e.b.length(),u)+sin(u*PI)*.65);e.node.rotate_y(dt*4)
		if u>=1:e.node.queue_free();effects.remove_at(i)
