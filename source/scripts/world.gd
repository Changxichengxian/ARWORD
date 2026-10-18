extends Node3D
class_name FrontierWorld

var barriers: Array = []
var breakables: Array = []
var bridge_parts: Node3D
var bridge_block: StaticBody3D
var nav = AStarGrid2D.new()
var main
var materials = {}
var river_foam:Array=[]
var wind_time=0.0
const MODEL = "res://assets/models/"

func material(color: Color) -> StandardMaterial3D:
	var key = color.to_html()
	if materials.has(key): return materials[key]
	var m = StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = .87
	materials[key] = m
	return m

func box(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var n = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = size
	n.mesh = mesh
	n.material_override = material(color)
	parent.add_child(n)
	n.position = pos
	return n

func model(name: String, pos: Vector3, scale_value = 1.0, parent: Node3D = null) -> Node3D:
	var n = load(MODEL + name + ".glb").instantiate()
	if parent == null: parent = self
	parent.add_child(n)
	n.position = pos
	n.scale = Vector3.ONE * scale_value
	return n

func wall(pos: Vector3, size: Vector3, name_value = "wall") -> StaticBody3D:
	var b = StaticBody3D.new()
	b.name = name_value
	b.collision_layer = 2
	b.collision_mask = 1
	add_child(b)
	b.position = pos
	var c = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = size
	c.shape = shape
	b.add_child(c)
	barriers.append({"node":b,"rect":Rect2(Vector2(pos.x-size.x/2,pos.z-size.z/2),Vector2(size.x,size.z))})
	return b

func create(owner_node, built: bool):
	main = owner_node
	var env = WorldEnvironment.new()
	var e = Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("8ccbd2")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("b9d8df")
	e.ambient_light_energy = .38
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.environment = e
	add_child(env)
	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-53,-32,0)
	sun.light_color = Color("fff2cd")
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 55
	sun.shadow_bias = .035
	add_child(sun)
	box(self, Vector3(0,-.9,0), Vector3(29,1.7,33), Color("ad8c54"))
	ground()
	var floor_body = wall(Vector3(0,-.55,0),Vector3(29,1,33),"Ground")
	barriers.pop_back() # floor is walkable for top-down navigation
	box(self,Vector3(0,-1.2,0),Vector3(180,.1,180),Color("329eaf"))
	# River and two crossings. The right crossing becomes a permanent construction.
	box(self,Vector3(0,-.012,1),Vector3(28,.05,3.4),Color("42bed0"))
	wall(Vector3(-8,.4,1),Vector3(10,1,3.4),"RiverWest")
	wall(Vector3(4.4,.4,1),Vector3(4.6,1,3.4),"RiverMiddle")
	wall(Vector3(12.1,.4,1),Vector3(3.2,1,3.4),"RiverEast")
	bridge_block = wall(Vector3(8.65,.4,1),Vector3(3.9,1,3.4),"UnbuiltCrossing")
	model("bridge",Vector3(-.45,0,1),1.0)
	bridge_parts = model("bridge",Vector3(8.65,0,1),1.0)
	bridge_parts.visible = built
	bridge_block.collision_layer = 0 if built else 2
	for p in [Vector3(-13.6,.5,0),Vector3(13.6,.5,0)]:wall(p,Vector3(.8,2,32))
	for p in [Vector3(0,.5,-15.7),Vector3(0,.5,15.7)]:wall(p,Vector3(28,2,.8))
	model("workshop",Vector3(-7,0,11),1.0)
	wall(Vector3(-7,1,11),Vector3(3.3,2.4,2.8))
	# Physical camp dressing gives the workshop a readable front yard.
	model("crate",Vector3(-9.6,0,11.5),.8)
	model("crate",Vector3(-10,0,10.3),.65)
	for x in [-10,-9,-8,-7,-6,-5,-4]:
		box(self,Vector3(x,.45,13.4),Vector3(.12,.9,.12),Color("89612d"))
	box(self,Vector3(-7,.65,13.4),Vector3(6,.13,.12),Color("b88b4c"))
	box(self,Vector3(-4.1,1.6,9.5),Vector3(.11,3.2,.11),Color("8b6c43"))
	box(self,Vector3(-3.6,2.7,9.5),Vector3(1.0,.65,.06),Color("32afb3"))
	for x in [7.4,9.9]:
		for z in [-.9,2.8]:box(self,Vector3(x,.3,z),Vector3(.22,.6,.22),Color("997340"))
	for i in range(14):
		var foam=box(self,Vector3(-13+i*2,.021,.0+(i%3)*.8),Vector3(.55,.024,.035),Color("b3ece2"))
		river_foam.append(foam)
	# Paths and a raised-looking capture platform stay physically flat for readable combat.
	for i in range(13):box(self,Vector3(-.4,.008,13-i*2.1),Vector3(3.5,.025,2.2),Color("d7c28a"))
	box(self,Vector3(4.8,.012,5.5),Vector3(10.5,.03,2.3),Color("cbb981"))
	box(self,Vector3(8.6,.013,6.7),Vector3(2.8,.03,12.0),Color("cbb981"))
	box(self,Vector3(0,.025,-8),Vector3(6,.06,5),Color("b3ad87"))
	for x in [-3.1,3.1]:
		box(self,Vector3(x,.18,-8),Vector3(.17,.36,5.2),Color("e2d5a3"))
	# Destructible cover and explosive barrels.
	for p in [Vector3(-3,0,-4.7),Vector3(3.2,0,-6),Vector3(-7,0,-7.7),Vector3(6.2,0,-10)]:
		prop("crate",p,45)
	for p in [Vector3(-4.4,0,-5.5),Vector3(4.6,0,-7.4)]:prop("barrel",p,20)
	for p in [Vector3(-8.7,0,-3.4),Vector3(8,0,-5),Vector3(-2,0,-11.8)]:
		model("rock",p,1.3)
		wall(p+Vector3(0,.6,0),Vector3(1.7,1.2,1.4))
	var rng = RandomNumberGenerator.new()
	rng.seed = 3372
	for side in [-1,1]:
		for i in range(13):
			var p = Vector3(side*rng.randf_range(14.3,19.0),-.1,-19+i*3.1)
			model("pine",p,rng.randf_range(1.2,2.1))
	for i in range(12):model("pine",Vector3(-18+i*3.2,0,-19-rng.randf_range(0,3)),rng.randf_range(1.3,2.4))
	for i in range(22):
		var p = Vector3(rng.randf_range(-12.5,12.5),.03,rng.randf_range(-14,14))
		if abs(p.z-1)<2.0 or abs(p.x)<2:continue
		var tuft=MeshInstance3D.new();var mesh=CylinderMesh.new()
		mesh.top_radius=0;mesh.bottom_radius=.16;mesh.height=.4;mesh.radial_segments=5
		tuft.mesh=mesh;tuft.material_override=material(Color("66923b"));add_child(tuft);tuft.position=p+Vector3(0,.17,0)
	update_navigation()

func _process(dt):
	wind_time+=dt
	for i in range(river_foam.size()):
		var foam=river_foam[i]
		foam.position.x=-13+fmod(i*2+wind_time*.45,26)
		foam.scale.x=.8+sin(wind_time*1.3+i)*.25

func ground():
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng=RandomNumberGenerator.new();rng.seed=124
	for x in range(-14,14,2):
		for z in range(-16,16,2):
			var c=Color("83b556").lerp(Color("a9c871"),rng.randf()*.25)
			for point in [Vector3(x,0,z),Vector3(x+2,0,z),Vector3(x,0,z+2),Vector3(x+2,0,z),Vector3(x+2,0,z+2),Vector3(x,0,z+2)]:
				st.set_color(c);st.set_normal(Vector3.UP);st.add_vertex(point)
	var g=MeshInstance3D.new();g.mesh=st.commit()
	var m=StandardMaterial3D.new();m.vertex_color_use_as_albedo=true;m.roughness=1.0
	m.vertex_color_is_srgb=true
	g.material_override=m;add_child(g)

func prop(kind: String,p: Vector3,hp: float):
	var b=wall(p+Vector3(0,.6,0),Vector3(1.05,1.2,1.05),kind)
	var visual=model(kind,Vector3(0,-.6,0),1,b)
	b.set_meta("breakable",true);b.set_meta("hp",hp);b.set_meta("kind",kind)
	breakables.append(b)

func update_navigation():
	nav.region=Rect2i(-14,-16,29,33)
	nav.cell_size=Vector2.ONE
	nav.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	nav.update()
	nav.fill_solid_region(nav.region,false)
	barriers=barriers.filter(func(entry):return is_instance_valid(entry.node))
	for x in range(-14,15):
		for z in range(-16,17):
			var point=Vector2(x,z)
			for entry in barriers:
				if is_instance_valid(entry.node) and entry.node.collision_layer != 0 and entry.rect.grow(.34).has_point(point):
					nav.set_point_solid(Vector2i(x,z));break

func steer(from: Vector3,to: Vector3) -> Vector3:
	var start=Vector2i(clampi(roundi(from.x),-13,13),clampi(roundi(from.z),-15,15))
	var goal=Vector2i(clampi(roundi(to.x),-13,13),clampi(roundi(to.z),-15,15))
	if nav.is_point_solid(start):
		var escape=nearest_free(start,from,true)
		if escape==start:return Vector3.ZERO
		return (Vector3(escape.x,0,escape.y)-Vector3(from.x,0,from.z)).normalized()
	if nav.is_point_solid(goal):goal=nearest_free(goal,to,false)
	if nav.is_point_solid(goal):return Vector3.ZERO
	var path=nav.get_id_path(start,goal)
	if path.size()<2:return Vector3.ZERO
	var next=path[1]
	return (Vector3(next.x,0,next.y)-Vector3(from.x,0,from.z)).normalized()

func nearest_free(cell:Vector2i,origin:Vector3,require_sight:bool) -> Vector2i:
	var best=cell;var score=10000.0
	for x in range(cell.x-3,cell.x+4):
		for y in range(cell.y-3,cell.y+4):
			var candidate=Vector2i(x,y)
			if not nav.region.has_point(candidate) or nav.is_point_solid(candidate):continue
			var point=Vector3(x,origin.y,y)
			if require_sight and not main.line_clear(origin+Vector3.UP*.5,point+Vector3.UP*.5):continue
			var distance=origin.distance_squared_to(point)
			if distance<score:score=distance;best=candidate
	return best

func construct():
	bridge_parts.visible=true
	bridge_block.collision_layer=0
	update_navigation()
	var nodes=bridge_parts.find_children("*","MeshInstance3D",true,false)
	var i=0
	for n in nodes:
		var home=n.position
		n.position.y += 2.0
		var tween=create_tween()
		tween.tween_property(n,"position",home,.42).set_delay(i*.035).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		i+=1

func damage_prop(b: Node3D,amount: float):
	if not is_instance_valid(b) or not b.has_meta("hp"):return
	var hp=float(b.get_meta("hp"))-amount
	b.set_meta("hp",hp)
	if hp>0:return
	b.collision_layer=0
	var p=b.global_position
	if b.get_meta("kind")=="barrel":main.explode(p)
	else:main.burst(p,Color("c6924c"),12,3.5)
	b.queue_free()
	call_deferred("update_navigation")

func reset_cover():
	for b in breakables:
		if is_instance_valid(b):b.collision_layer=0;b.queue_free()
	breakables.clear()
	for p in [Vector3(-3,0,-4.7),Vector3(3.2,0,-6),Vector3(-7,0,-7.7),Vector3(6.2,0,-10)]:prop("crate",p,45)
	for p in [Vector3(-4.4,0,-5.5),Vector3(4.6,0,-7.4)]:prop("barrel",p,20)
	call_deferred("update_navigation")
