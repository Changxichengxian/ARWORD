extends Node3D
class_name IslandCosmos

# A second, genuinely perspective 3D view. Its distances are deliberately compressed.
# The close island keeps its orthographic study camera; the solar system has its own depth.
const CENTER=Vector3(-5.5,14,-50)
const DEFAULT_SETTINGS={"nebula":1.45,"color":1.3,"band":1.15,"stars":1.1,"drift":1.0}
const SETTING_LIMITS={"nebula":Vector2(0,2.5),"color":Vector2(0,2),"band":Vector2(.4,2),"stars":Vector2(.3,2),"drift":Vector2(0,2)}
var game
var viewport:SubViewport
var space_camera:Camera3D
var space:Node3D
var canvas:CanvasLayer
var display:TextureRect
var star_material:ShaderMaterial
var bodies:Array=[]
var sun:Node3D
var solar_surface:MeshInstance3D
var clock=0.0
var nebula_clock=0.0
var settings=DEFAULT_SETTINGS.duplicate()
var focus_index=-1
var focus_time=0.0
var base_fov=44.0
var shooting_star:MeshInstance3D
var meteor_clock=0.0

func setup(owner_game):
	game=owner_game
	viewport=SubViewport.new();viewport.name="SolarSystemView";viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;viewport.msaa_3d=Viewport.MSAA_2X;add_child(viewport)
	space=Node3D.new();viewport.add_child(space)
	var env=WorldEnvironment.new();var atmosphere=Environment.new();env.environment=atmosphere;space.add_child(env)
	atmosphere.background_mode=Environment.BG_CANVAS;atmosphere.background_canvas_max_layer=-20;atmosphere.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;atmosphere.ambient_light_color=Color("718FA9");atmosphere.ambient_light_energy=.28
	star_material=ShaderMaterial.new();star_material.shader=preload("res://assets/cosmos_sky.gdshader")
	apply_settings(game.learning.data.get("space_settings",{}))
	var sky_canvas=CanvasLayer.new();sky_canvas.layer=-20;viewport.add_child(sky_canvas)
	var sky_field=ColorRect.new();sky_field.mouse_filter=Control.MOUSE_FILTER_IGNORE;sky_field.material=star_material;sky_canvas.add_child(sky_field);sky_field.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	space_camera=Camera3D.new();space_camera.fov=base_fov;space_camera.near=.1;space_camera.far=180;space_camera.current=true;space.add_child(space_camera)
	var light=DirectionalLight3D.new();space.add_child(light);light.rotation_degrees=Vector3(-22,-35,-12);light.light_color=Color("FFE5B5");light.light_energy=1.25
	sun=Node3D.new();space.add_child(sun);sun.position=CENTER
	solar_surface=sphere(sun,1.48,Color("FFD783"),28,14);var solar_material=ShaderMaterial.new();solar_material.shader=preload("res://assets/cosmos_sun.gdshader");solar_surface.material_override=solar_material
	glow(sun,8.0,Color(1,.46,.12,.22));glow(sun,4.6,Color(1,.76,.30,.36))
	add_body("ring",14.0,.4,.0060,1.05,Color("8179A6"),Color("B1D1CD"),0)
	add_body("ice",20.0,-1.3,.0043,1.05,Color("487BA1"),Color("B3ECEB"),1)
	add_body("ember",26.0,-1.05,.0031,.72,Color("493D52"),Color("E8A47C"),2)
	add_body("garden",8.0,-2.25,.0081,.67,Color("297C79"),Color("87C9A0"),0)
	add_meteor()
	canvas=CanvasLayer.new();canvas.name="SolarBackground";canvas.layer=-10;add_child(canvas)
	display=TextureRect.new();display.texture=viewport.get_texture();display.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;display.stretch_mode=TextureRect.STRETCH_SCALE;display.mouse_filter=Control.MOUSE_FILTER_IGNORE;canvas.add_child(display);display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for child in game.world.get_children():
		if child is WorldEnvironment:
			child.environment.background_mode=Environment.BG_CANVAS;child.environment.background_canvas_max_layer=-10
	resize();get_viewport().size_changed.connect(resize)
	advance(0)
func apply_settings(values:Dictionary):
	# Speed changes keep the existing cloud phase, so moving a slider never jumps the sky.
	for key in DEFAULT_SETTINGS:
		var value=values.get(key,DEFAULT_SETTINGS[key]);var limits=SETTING_LIMITS[key]
		settings[key]=clampf(float(value),limits.x,limits.y) if (value is int or value is float) and is_finite(float(value)) else DEFAULT_SETTINGS[key]
	if not is_instance_valid(star_material):return
	for pair in [["nebula","nebula_strength"],["color","color_strength"],["band","band_width"],["stars","star_density"]]:
		star_material.set_shader_parameter(pair[1],settings[pair[0]])
func resize():
	if not is_instance_valid(viewport):return
	var view_size=get_viewport().get_visible_rect().size
	var factor=minf(1.0,720.0/maxf(1,view_size.x))
	viewport.size=Vector2i(maxi(270,int(view_size.x*factor)),maxi(480,int(view_size.y*factor)))
	star_material.set_shader_parameter("aspect",float(viewport.size.x)/float(viewport.size.y))
func sphere(parent:Node3D,radius:float,color:Color,segments=18,rings=10)->MeshInstance3D:
	var mesh=SphereMesh.new();mesh.radius=radius;mesh.height=radius*2;mesh.radial_segments=segments;mesh.rings=rings
	var visual=MeshInstance3D.new();visual.mesh=mesh;var material=StandardMaterial3D.new();material.albedo_color=color;material.roughness=.9;visual.material_override=material;parent.add_child(visual);return visual
func glow(parent:Node3D,width:float,color:Color):
	var mesh=QuadMesh.new();mesh.size=Vector2.ONE*width;var visual=MeshInstance3D.new();visual.mesh=mesh;parent.add_child(visual)
	var material=ShaderMaterial.new();material.shader=preload("res://assets/cosmos_glow.gdshader");material.set_shader_parameter("tint",color);visual.material_override=material;visual.position.z=.1
func add_body(id:String,radius:float,phase:float,speed:float,size:float,color:Color,accent:Color,kind:int):
	var orbit=Node3D.new();space.add_child(orbit);var axis=Node3D.new();orbit.add_child(axis);axis.rotation_degrees=Vector3(12,0,-18)
	var surface=sphere(axis,size,color);var material=ShaderMaterial.new();material.shader=preload("res://assets/cosmos_planet.gdshader");material.set_shader_parameter("base_color",color);material.set_shader_parameter("accent_color",accent);material.set_shader_parameter("kind",kind);surface.material_override=material
	if id=="ring":
		axis.rotation_degrees=Vector3(62,0,-24);rings(axis,size)
	if id=="ice":
		for i in range(6):
			var crystal=MeshInstance3D.new();var prism=CylinderMesh.new();prism.top_radius=0;prism.bottom_radius=.17;prism.height=.60;prism.radial_segments=5;crystal.mesh=prism;var m=StandardMaterial3D.new();m.albedo_color=Color("B8E7E9");m.roughness=.65;crystal.material_override=m;axis.add_child(crystal)
			var n=Vector3(cos(i*TAU/6)*.62,.78,sin(i*TAU/6)*.62).normalized();crystal.position=n*(size+.14);crystal.basis=Basis(Quaternion(Vector3.UP,n))
	if id=="garden":
		for i in range(5):
			var moon=sphere(axis,.13,Color("8DC69C"),8,4);moon.position=Vector3(cos(i*TAU/5),.35*sin(i),sin(i*TAU/5))*size*1.6
	bodies.append({"id":id,"orbit":orbit,"axis":axis,"radius":radius,"phase":phase,"speed":speed,"size":size})
func rings(parent:Node3D,size:float):
	var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for band in range(3):
		var inner=size*(1.35+band*.27);var outer=inner+size*.19
		for i in range(80):
			var a=i*TAU/80;var b=(i+1)*TAU/80
			st.set_color([Color("9FC9CA"),Color("C7BDA7"),Color("7789A9")][band])
			for v in [Vector3(cos(a)*inner,0,sin(a)*inner),Vector3(cos(b)*outer,0,sin(b)*outer),Vector3(cos(a)*outer,0,sin(a)*outer),Vector3(cos(a)*inner,0,sin(a)*inner),Vector3(cos(b)*inner,0,sin(b)*inner),Vector3(cos(b)*outer,0,sin(b)*outer)]:st.add_vertex(v)
	st.generate_normals();var visual=MeshInstance3D.new();visual.mesh=st.commit();var material=StandardMaterial3D.new();material.vertex_color_use_as_albedo=true;material.cull_mode=BaseMaterial3D.CULL_DISABLED;material.roughness=.9;visual.material_override=material;parent.add_child(visual)
func add_meteor():
	shooting_star=MeshInstance3D.new();var mesh=QuadMesh.new();mesh.size=Vector2(2.5,.035);shooting_star.mesh=mesh;var material=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.albedo_color=Color(.64,.83,1,.0);material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;shooting_star.material_override=material;space.add_child(shooting_star)
func advance(dt:float):
	clock+=dt;meteor_clock+=dt
	nebula_clock+=dt*settings.drift
	star_material.set_shader_parameter("drift",nebula_clock)
	star_material.set_shader_parameter("twinkle_time",clock)
	for body in bodies:
		var angle=body.phase+clock*body.speed;var dz=sin(angle)*body.radius
		var tilt={"ring":.09,"ice":.34,"ember":-.22,"garden":.29}[body.id]
		body.orbit.position=CENTER+Vector3(cos(angle)*body.radius,-dz*.28+cos(angle)*body.radius*tilt,dz)
		body.axis.rotate_y(dt*(.10 if body.id=="ring" else .16))
	solar_surface.rotate_y(dt*.012)
	var shooting=fposmod(meteor_clock+17.0,39.0);shooting_star.visible=shooting<1.8
	if shooting_star.visible:
		shooting_star.position=Vector3(14-shooting*13,18-shooting*7,-48);shooting_star.rotation.z=.49;shooting_star.material_override.albedo_color.a=sin(shooting/1.8*PI)*.48
	if focus_time>0:
		focus_time=maxf(0,focus_time-dt)
		# A small acknowledgement pulse preserves the complete planet and clock composition.
		var body=bodies[focus_index];body.axis.scale=Vector3.ONE*(1.0+sin((1.0-focus_time/1.5)*PI)*.12)
		if focus_time<=0:body.axis.scale=Vector3.ONE;focus_index=-1
func _process(dt):
	if is_instance_valid(viewport):advance(dt)
func screen_position(index:int)->Vector2:
	var position=space_camera.unproject_position(bodies[index].orbit.position)
	return position*get_viewport().get_visible_rect().size/Vector2(viewport.size)
func handle_tap(screen_pos:Vector2)->bool:
	# Only touches clearly above the close island are eligible, so distant planets cannot steal worksite taps.
	if screen_pos.y>get_viewport().get_visible_rect().size.y*.30:return false
	for i in range(bodies.size()):
		if screen_position(i).distance_to(screen_pos)<28:
			if focus_index>=0:bodies[focus_index].axis.scale=Vector3.ONE
			focus_index=i;focus_time=1.5;return true
	return false
