extends Node3D
class_name IslandWater

const BASE_RADIUS=11.62
const MAX_DEPTH=4.0
const COLS=128
const ROWS=64
const A=Vector3(.78,.18,.60)
const B=Vector3(-.32,.71,.63)
var world
var material:ShaderMaterial
var foam_material:ShaderMaterial
var floor_mesh:MeshInstance3D
var foam:MeshInstance3D
var map:PackedFloat32Array=[]
var bed_texture:ImageTexture
var land_count=-1
var ripple_points:Array[Vector4]=[Vector4(0,1,0,-1000),Vector4(0,1,0,-1000),Vector4(0,1,0,-1000),Vector4(0,1,0,-1000)]
var strengths=Vector4.ZERO
var next_ripple=0

static func surface_radius(normal:Vector3,time:float)->float:
	var p=normal.normalized()*BASE_RADIUS
	return BASE_RADIUS+.026*sin(p.dot(A)*1.45-time*.85)+.014*sin(p.dot(B)*2.4+time*.65)

func setup(owner_world,ocean:Node3D):
	world=owner_world
	material=ShaderMaterial.new();material.shader=preload("res://assets/water.gdshader");material.render_priority=1
	# The old imported sphere kept its 11.62 scale on the mesh node. Normalize it
	# once: both shader displacement and creature positions now use world units.
	ocean.transform=Transform3D.IDENTITY
	for mesh in ocean.find_children("*","MeshInstance3D",true,false):
		mesh.transform=Transform3D.IDENTITY;mesh.material_override=material;mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh.extra_cull_margin=BASE_RADIUS
	floor_mesh=MeshInstance3D.new();floor_mesh.name="Seabed";add_child(floor_mesh);floor_mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var bed_material=StandardMaterial3D.new();bed_material.vertex_color_use_as_albedo=true;bed_material.vertex_color_is_srgb=true;bed_material.roughness=.95;bed_material.cull_mode=BaseMaterial3D.CULL_DISABLED;floor_mesh.material_override=bed_material
	foam_material=ShaderMaterial.new();foam_material.shader=preload("res://assets/shore_foam.gdshader");foam_material.render_priority=2
	foam=MeshInstance3D.new();foam.name="ShoreRipples";foam.material_override=foam_material;foam.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(foam)
	rebuild()

static func direction_at(column:float,row:float)->Vector3:
	var theta=(column/COLS-.5)*TAU;var phi=row/ROWS*PI
	return Vector3(cos(theta)*sin(phi),cos(phi),sin(theta)*sin(phi))

func analytic_depth(normal:Vector3,centers:Array)->float:
	var nearest=2.0
	for center in centers:nearest=minf(nearest,1.0-normal.dot(center))
	var distance=maxf(0.0,sqrt(maxf(0,nearest*2))*BASE_RADIUS-IslandFrontier.HEX)
	var shelf=.12+.22*smoothstep(0.0,.65,distance)+.92*smoothstep(.65,2.4,distance)
	var basin=2.05*smoothstep(2.4,5.8,distance)
	var relief=(sin(normal.x*12+normal.z*7)*.10+sin(normal.y*11-normal.z*8)*.08)*smoothstep(2.0,4.0,distance)
	return clampf(shelf+basin+relief,.12,3.5)

func rebuild():
	land_count=world.land.size();var centers=[]
	for cell in world.land:centers.append(world.surface(IslandFrontier.point(cell)).normalized())
	map.resize((COLS+1)*(ROWS+1));var image=Image.create(COLS+1,ROWS+1,false,Image.FORMAT_R8)
	for row in range(ROWS+1):
		for col in range(COLS+1):
			var depth=analytic_depth(direction_at(col,row),centers)
			# Quantize once; geometry, animal queries and shader see the exact same samples.
			depth=roundf(depth/MAX_DEPTH*255)/255.0*MAX_DEPTH;map[row*(COLS+1)+col]=depth;image.set_pixel(col,row,Color(depth/MAX_DEPTH,0,0))
	bed_texture=ImageTexture.create_from_image(image);material.set_shader_parameter("bed_depth",bed_texture)
	var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in range(ROWS):
		for col in range(COLS):
			for offset in [Vector2i(0,0),Vector2i(1,1),Vector2i(1,0),Vector2i(0,0),Vector2i(0,1),Vector2i(1,1)]:
				var x=col+offset.x;var y=row+offset.y;var n=direction_at(x,y);var depth=map[y*(COLS+1)+x]
				var tint=Color("DAC592").lerp(Color("429F91"),smoothstep(.12,1.1,depth)).lerp(Color("315C73"),smoothstep(1.0,3.4,depth))
				st.set_color(tint);st.set_normal(n);st.add_vertex(n*(BASE_RADIUS-depth))
	st.index();floor_mesh.mesh=st.commit();rebuild_foam()

func depth_at(normal:Vector3)->float:
	if map.is_empty():return 0.0
	var n=normal.normalized();var u=fposmod(atan2(n.z,n.x)/TAU+.5,1.0)*COLS;var v=acos(clampf(n.y,-1,1))/PI*ROWS
	var x=mini(COLS-1,int(floor(u)));var y=mini(ROWS-1,int(floor(v)));var fx=u-x;var fy=v-y
	return lerpf(lerpf(map[y*(COLS+1)+x],map[y*(COLS+1)+x+1],fx),lerpf(map[(y+1)*(COLS+1)+x],map[(y+1)*(COLS+1)+x+1],fx),fy)

func floor_radius(normal:Vector3)->float:return BASE_RADIUS-depth_at(normal)

func shore_normal(p:Vector2)->Vector3:
	return Vector3(p.x,sqrt(maxf(.1,144.0-p.length_squared())),p.y).normalized()

func rebuild_foam():
	var directions=[Vector2i(0,1),Vector2i(-1,1),Vector2i(-1,0),Vector2i(0,-1),Vector2i(1,-1),Vector2i(1,0)]
	var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);var edge_index=0
	for cell in world.land:
		var center=IslandFrontier.point(cell)
		for i in range(6):
			if world.land.has(cell+directions[i]):continue
			var angle=(i*60+30)*PI/180;var start=Vector2(cos(angle),sin(angle))*IslandFrontier.HEX;var end=Vector2(cos(angle+PI/3),sin(angle+PI/3))*IslandFrontier.HEX
			var outward=(start+end).normalized()
			for segment in range(8):
				for corner in [Vector2(0,0),Vector2(1,1),Vector2(1,0),Vector2(0,0),Vector2(0,1),Vector2(1,1)]:
					var along=(segment+corner.x)/8.0;var point=center+start.lerp(end,along)+outward*(.035+corner.y*.30)
					st.set_uv(Vector2(edge_index*1.34+along*1.34,corner.y));st.add_vertex(shore_normal(point)*BASE_RADIUS)
			edge_index+=1
	foam.mesh=st.commit()

func ripple(normal:Vector3,strength=1.0):
	var n=normal.normalized();ripple_points[next_ripple]=Vector4(n.x,n.y,n.z,world.time);strengths[next_ripple]=clampf(strength,0,3)
	next_ripple=(next_ripple+1)%4
	material.set_shader_parameter("ripples",ripple_points);material.set_shader_parameter("ripple_strength",strengths)

func _process(_dt):
	if not is_instance_valid(world) or material==null:return
	if world.land.size()!=land_count:rebuild()
	material.set_shader_parameter("water_time",world.time);foam_material.set_shader_parameter("water_time",world.time)
