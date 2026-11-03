extends Node3D
class_name IslandCosmos

# A second, genuinely perspective 3D view. Its distances are deliberately compressed.
# The close island keeps its orthographic study camera; the solar system has its own depth.
const CENTER=Vector3(-5.5,14,-50)
const DEFAULT_SETTINGS={"nebula":1.45,"color":1.3,"band":1.15,"stars":1.1,"drift":1.0}
const SETTING_LIMITS={"nebula":Vector2(0,2.5),"color":Vector2(0,2),"band":Vector2(.4,2),"stars":Vector2(.3,2),"drift":Vector2(0,2)}
const OBSERVATIONS=[{"id":"cyan","title":"青蓝回廊","accent":"70CAD6"},{"id":"violet","title":"紫色双云","accent":"BA9BEB"},{"id":"gold","title":"金边暗柱","accent":"E9C38B"}]
var game
var viewport:SubViewport
var space_camera:Camera3D
var space:Node3D
var canvas:CanvasLayer
var display:TextureRect
var star_material:ShaderMaterial
var cloud_texture:NoiseTexture3D
var cloud_regions:Array=[]
var bodies:Array=[]
var sun:Node3D
var black_hole:MeshInstance3D
var solar_surface:MeshInstance3D
var clock=0.0
var nebula_clock=0.0
var sky_seed=0
var settings=DEFAULT_SETTINGS.duplicate()
var focus_index=-1
var focus_time=0.0
var base_fov=44.0
var shooting_star:MeshInstance3D
var meteor_clock=0.0
var observatory_active=false
var primary_close=false
var observation_index=0
var observation_yaw=0.0
var observation_pitch=0.0
var observation_roll=0.0
var observation_zoom=1.0
var observation_blend=0.0

func setup(owner_game):
	game=owner_game
	viewport=SubViewport.new();viewport.name="SolarSystemView";viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;viewport.msaa_3d=Viewport.MSAA_DISABLED if OS.has_feature("android") else Viewport.MSAA_4X;add_child(viewport)
	space=Node3D.new();viewport.add_child(space)
	var env=WorldEnvironment.new();var atmosphere=Environment.new();env.environment=atmosphere;space.add_child(env)
	atmosphere.background_mode=Environment.BG_CANVAS;atmosphere.background_canvas_max_layer=-20;atmosphere.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;atmosphere.ambient_light_color=Color("718FA9");atmosphere.ambient_light_energy=.28
	star_material=ShaderMaterial.new();star_material.shader=preload("res://assets/cosmos_sky.gdshader")
	make_cloud_regions()
	randomize_sky()
	apply_settings(game.learning.data.get("space_settings",{}))
	var sky_canvas=CanvasLayer.new();sky_canvas.layer=-20;viewport.add_child(sky_canvas)
	var sky_field=ColorRect.new();sky_field.mouse_filter=Control.MOUSE_FILTER_IGNORE;sky_field.material=star_material;sky_canvas.add_child(sky_field);sky_field.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	space_camera=Camera3D.new();space_camera.fov=base_fov;space_camera.near=.1;space_camera.far=280;space_camera.current=true;space.add_child(space_camera)
	var light=DirectionalLight3D.new();space.add_child(light);light.rotation_degrees=Vector3(-22,-35,-12);light.light_color=Color("FFE5B5");light.light_energy=1.25
	sun=Node3D.new();space.add_child(sun);sun.position=CENTER
	solar_surface=sphere(sun,1.48,Color("FFD783"),28,14);var solar_material=ShaderMaterial.new();solar_material.shader=preload("res://assets/cosmos_sun.gdshader");solar_surface.material_override=solar_material
	glow(sun,8.0,Color(1,.46,.12,.22));glow(sun,4.6,Color(1,.76,.30,.36))
	black_hole=MeshInstance3D.new();black_hole.name="AccretionDisk";space.add_child(black_hole)
	black_hole.position=CENTER;black_hole.mesh=QuadMesh.new();black_hole.mesh.size=Vector2(19.8,11.)
	black_hole.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var accretion=ShaderMaterial.new();accretion.shader=preload("res://assets/accretion_disk.gdshader");black_hole.material_override=accretion
	accretion.set_shader_parameter("disk_orbits",preload("res://assets/cosmos/disk_orbits.png"))
	accretion.set_shader_parameter("disk_light",preload("res://assets/cosmos/disk_light.png"))
	black_hole.look_at(Vector3.ZERO,Vector3.UP)
	set_black_hole(game.learning.data.get("black_hole",IslandLearning.DEFAULT_BLACK_HOLE))
	add_body("ring",14.0,.4,.0060,1.05,Color("71655F"),Color("D9BE96"),0)
	add_body("ice",20.0,-1.3,.0043,1.05,Color("224866"),Color("BDE9EC"),1)
	add_body("ember",26.0,-1.05,.0031,.72,Color("292334"),Color("EAAA64"),2)
	add_body("garden",8.0,-2.25,.0081,.67,Color("153D4E"),Color("76A78D"),3)
	add_meteor()
	canvas=CanvasLayer.new();canvas.name="SolarBackground";canvas.layer=-10;add_child(canvas)
	display=TextureRect.new();display.texture=viewport.get_texture();display.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR;display.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;display.stretch_mode=TextureRect.STRETCH_SCALE;display.mouse_filter=Control.MOUSE_FILTER_IGNORE;canvas.add_child(display);display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for child in game.world.get_children():
		if child is WorldEnvironment:
			child.environment.background_mode=Environment.BG_CANVAS;child.environment.background_canvas_max_layer=-10
	resize();get_viewport().size_changed.connect(resize)
	advance(0)
func set_black_hole(enabled:bool):
	sun.visible=not enabled;black_hole.visible=enabled

func set_sky_seed(value:int):
	sky_seed=posmod(value,1048576);nebula_clock=0.0
	if is_instance_valid(star_material):
		star_material.set_shader_parameter("sky_seed",float(sky_seed));star_material.set_shader_parameter("drift",0.0)
	arrange_cloud_regions()
func randomize_sky():
	var random=RandomNumberGenerator.new();random.randomize()
	var next_seed=random.randi_range(0,1048575)
	if next_seed==sky_seed:next_seed=(next_seed+1)%1048576
	set_sky_seed(next_seed)
func apply_settings(values:Dictionary):
	# Speed changes keep the existing cloud phase, so moving a slider never jumps the sky.
	for key in DEFAULT_SETTINGS:
		var value=values.get(key,DEFAULT_SETTINGS[key]);var limits=SETTING_LIMITS[key]
		settings[key]=clampf(float(value),limits.x,limits.y) if (value is int or value is float) and is_finite(float(value)) else DEFAULT_SETTINGS[key]
	if not is_instance_valid(star_material):return
	for pair in [["nebula","nebula_strength"],["color","color_strength"],["band","band_width"],["stars","star_density"]]:
		star_material.set_shader_parameter(pair[1],settings[pair[0]])
	for region in cloud_regions:
		region.material.set_shader_parameter("nebula_strength",settings.nebula)
		region.material.set_shader_parameter("color_strength",settings.color)
		var radius=region.radii*pow(settings.band/1.15,.55)
		region.material.set_shader_parameter("cloud_radii",radius)
		region.node.mesh.size=Vector2.ONE*maxf(radius.x,maxf(radius.y,radius.z))*2.5
func make_cloud_regions():
	var noise=FastNoiseLite.new();noise.seed=18775;noise.noise_type=FastNoiseLite.TYPE_SIMPLEX_SMOOTH;noise.frequency=.055;noise.fractal_octaves=3
	cloud_texture=NoiseTexture3D.new();cloud_texture.width=96;cloud_texture.height=96;cloud_texture.depth=96;cloud_texture.seamless=true;cloud_texture.noise=noise
	for i in range(3):
		var node=MeshInstance3D.new();node.name="NebulaVolume"+str(i);node.mesh=QuadMesh.new();node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;space.add_child(node)
		var material=ShaderMaterial.new();material.shader=preload("res://assets/cosmos_volume.gdshader");material.set_shader_parameter("cloud_noise",cloud_texture);material.set_shader_parameter("ray_steps",8 if OS.has_feature("android") else 12);material.set_shader_parameter("density_scale",[1.0,.95,.85][i]);material.set_shader_parameter("structure",i);node.material_override=material
		var cluster=MultiMeshInstance3D.new();cluster.name="NebulaStarCluster"+str(i);cluster.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;space.add_child(cluster)
		var points=MultiMesh.new();points.transform_format=MultiMesh.TRANSFORM_3D;points.use_colors=true;points.instance_count=24
		var star_mesh=SphereMesh.new();star_mesh.radius=1;star_mesh.height=2;star_mesh.radial_segments=8;star_mesh.rings=4
		var star_paint=StandardMaterial3D.new();star_paint.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;star_paint.vertex_color_use_as_albedo=true;star_mesh.material=star_paint;points.mesh=star_mesh;cluster.multimesh=points
		cloud_regions.append({"node":node,"material":material,"radii":Vector3.ONE,"center":Vector3.ZERO,"cluster":cluster})
		var lights=Node3D.new();space.add_child(lights);lights.hide()
		cloud_regions[-1].lights=lights
		for j in 3:
			var star=MeshInstance3D.new();star.mesh=QuadMesh.new();star.mesh.size=Vector2.ONE*[2.4,1.4,.68][j]
			star.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var flare=ShaderMaterial.new();flare.shader=preload("res://assets/observatory_flare.gdshader")
			flare.set_shader_parameter("tint",[Color("C6F4FF"),Color("FFCB92"),Color("DDB7FF")][j])
			star.material_override=flare;lights.add_child(star)
func arrange_cloud_regions():
	var random=RandomNumberGenerator.new();random.seed=sky_seed
	for i in range(cloud_regions.size()):
		var region=cloud_regions[i];var depth=[118.0,148.0,172.0][i]
		var center=Vector3([-15.0,22.0,-1.0][i]+random.randf_range(-5,5),[30.0,39.0,59.0][i]+random.randf_range(-4,4),-depth)
		var radius=Vector3(random.randf_range(7.2,9.1),random.randf_range(5.2,7.2),random.randf_range(5.9,7.8));var angle=random.randf_range(-.48,.48)
		var orientation=Basis(Vector3.FORWARD,angle)*Basis(Vector3.RIGHT,random.randf_range(-.18,.18))
		region.center=center;region.radii=radius;region.node.position=center;region.node.rotation.z=-angle
		region.material.set_shader_parameter("cloud_center",center);region.material.set_shader_parameter("cloud_inverse",orientation.inverse());region.material.set_shader_parameter("noise_phase",Vector3(random.randf_range(0,1),random.randf_range(0,1),random.randf_range(0,1)))
		region.material.set_shader_parameter("cold_color",[Color("369CB6"),Color("576EB9"),Color("417E9D")][i]);region.material.set_shader_parameter("middle_color",[Color("777DC9"),Color("A97ECA"),Color("6C8CBB")][i]);region.material.set_shader_parameter("warm_color",[Color("C6B687"),Color("D7B3A4"),Color("E3B474")][i])
		region.material.set_shader_parameter("drift",nebula_clock)
		region.cluster.position=center
		region.lights.position=center
		var homes=[[Vector3(.35,.02,.40),Vector3(-.27,-.3,.26),Vector3(.45,.27,.2)],[Vector3(-.28,.15,.42),Vector3(.30,-.2,.25),Vector3(.15,.06,.28)],[Vector3(.24,.38,.40),Vector3(-.34,.17,.34),Vector3(-.16,-.20,.3)]][i]
		for j in 3:region.lights.get_child(j).position=orientation*(homes[j]*radius)
		for index in range(24):
			var p=Vector3(random.randf_range(-.8,.8),random.randf_range(-.7,.7),random.randf_range(-.8,.8))
			var size=random.randf_range(.018,.032) if index>3 else random.randf_range(.045,.064)
			region.cluster.multimesh.set_instance_transform(index,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*size),orientation*(p*radius)))
			region.cluster.multimesh.set_instance_color(index,[Color("AECFE8"),Color("DAD3EE"),Color("F0D3A1")][index%3]*(.65 if index>3 else 1.0))
	apply_settings(settings.duplicate())
func observation_targets()->Array:return OBSERVATIONS.duplicate(true)
func observations()->Array:return observation_targets()
func enter_observatory(index:int=0)->bool:
	if not is_instance_valid(space_camera) or index<0 or index>=cloud_regions.size():return false
	observatory_active=true;canvas.layer=4
	return select_observation_target(index)
func leave_observatory():
	observatory_active=false;primary_close=false;observation_blend=0.0;canvas.layer=-10
	space_camera.position=Vector3.ZERO;space_camera.rotation=Vector3.ZERO;space_camera.fov=base_fov
	update_observation_quality();update_sky_camera()
func select_observation_target(index:int)->bool:
	if index<0 or index>=cloud_regions.size():return false
	observation_index=index;observation_yaw=0.0;observation_pitch=0.0;observation_zoom=1.0;observation_blend=0.0
	observation_roll=0.0
	update_observation_quality();return true
func rotate_observation(delta:Vector2):
	if not observatory_active:return
	delta=delta.rotated(-observation_roll)
	observation_yaw=clampf(observation_yaw-delta.x*.003,-.48,.48)
	observation_pitch=clampf(observation_pitch+delta.y*.0025,-.28,.28)
func zoom_observation(factor:float):
	if observatory_active and is_finite(factor):observation_zoom=clampf(observation_zoom*factor,.53,1.72)
func update_observation_quality():
	for body in bodies:body.orbit.visible=not primary_close
	for i in range(cloud_regions.size()):
		var detailed=observatory_active and not primary_close and i==observation_index
		cloud_regions[i].lights.visible=detailed and settings.stars>0
		cloud_regions[i].material.set_shader_parameter("ray_steps",(24 if OS.has_feature("android") else 36) if detailed else (8 if OS.has_feature("android") else 12))
		cloud_regions[i].material.set_shader_parameter("detail_view",1.0 if detailed else 0.0)
func update_sky_camera():
	if not is_instance_valid(space_camera):return
	star_material.set_shader_parameter("sky_basis",space_camera.global_basis)
	star_material.set_shader_parameter("field_of_view",deg_to_rad(space_camera.fov))
func advance_observation(dt:float):
	if observatory_active:
		observation_blend=minf(1,observation_blend+dt*1.35)
		var region=cloud_regions[observation_index];var distance=region.radii.x*3.35*observation_zoom
		var target=region.node.position
		if primary_close:target=CENTER;distance=41.*observation_zoom
		var toward_camera=(-target).normalized()
		if primary_close:
			# A fixed transfer table describes one viewing inclination. Pan
			# across that image instead of orbiting a flat emitting surface.
			target+=space_camera.global_basis.x*observation_yaw*3.0+space_camera.global_basis.y*observation_pitch*3.0
			toward_camera=(-CENTER).normalized()
			space_camera.position=space_camera.position.lerp(CENTER+toward_camera*distance,1-exp(-dt*5.5))
			space_camera.look_at(target,Vector3.UP);space_camera.rotate_object_local(Vector3.BACK,observation_roll)
			update_sky_camera();return
		var offset=toward_camera.rotated(Vector3.UP,observation_yaw).rotated(Vector3.RIGHT,observation_pitch)*distance
		space_camera.position=space_camera.position.lerp(target+offset,1-exp(-dt*5.5))
		space_camera.look_at(target);space_camera.fov=base_fov
		space_camera.rotate_object_local(Vector3.BACK,observation_roll)
	for region in cloud_regions:
		region.node.look_at(space_camera.global_position,Vector3.UP)
	update_sky_camera()
func resize():
	if not is_instance_valid(viewport):return
	var view_size=get_viewport().get_visible_rect().size
	# Canvas coordinates stay logical when the desktop window grows. Render the planets at its physical pixels.
	var physical_size=Vector2(DisplayServer.window_get_size()) if DisplayServer.get_name()!="headless" else view_size
	var ratio=maxf(physical_size.x/maxf(1,view_size.x),physical_size.y/maxf(1,view_size.y))
	var desired=view_size*ratio
	if OS.has_feature("android"):
		# Budget world pixels independently from the full-resolution learning UI.
		get_viewport().scaling_3d_scale=clampf(sqrt(1050000./maxf(1,physical_size.x*physical_size.y)),.35,.85)
	var max_pixels=1500000.0 if OS.has_feature("android") else 4200000.0
	var max_edge=1800.0 if OS.has_feature("android") else 2880.0
	var factor=minf(1.0,minf(max_edge/maxf(desired.x,desired.y),sqrt(max_pixels/maxf(1,desired.x*desired.y))))
	viewport.size=Vector2i(maxi(270,roundi(desired.x*factor)),maxi(480,roundi(desired.y*factor)))
	star_material.set_shader_parameter("aspect",float(viewport.size.x)/float(viewport.size.y))
func sphere(parent:Node3D,radius:float,color:Color,segments=32,rings=16)->MeshInstance3D:
	var mesh=SphereMesh.new();mesh.radius=radius;mesh.height=radius*2;mesh.radial_segments=segments;mesh.rings=rings
	var visual=MeshInstance3D.new();visual.mesh=mesh;var material=StandardMaterial3D.new();material.albedo_color=color;material.roughness=.9;visual.material_override=material;parent.add_child(visual);return visual
func glow(parent:Node3D,width:float,color:Color):
	var mesh=QuadMesh.new();mesh.size=Vector2.ONE*width;var visual=MeshInstance3D.new();visual.mesh=mesh;parent.add_child(visual)
	var material=ShaderMaterial.new();material.shader=preload("res://assets/cosmos_glow.gdshader");material.set_shader_parameter("tint",color);visual.material_override=material;visual.position.z=.1
func add_body(id:String,radius:float,phase:float,speed:float,size:float,color:Color,accent:Color,kind:int):
	var orbit=Node3D.new();space.add_child(orbit);var axis=Node3D.new();orbit.add_child(axis);axis.rotation_degrees=Vector3(12,0,-18)
	var surface=sphere(axis,size,color);var material=ShaderMaterial.new();material.shader=preload("res://assets/cosmos_planet.gdshader");material.set_shader_parameter("base_color",color);material.set_shader_parameter("accent_color",accent);material.set_shader_parameter("kind",kind);surface.material_override=material
	if id=="ring":
		axis.rotation_degrees=Vector3(19,0,-28);rings(axis,size)
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
	for i in 128:
		var a=i*TAU/128;var b=(i+1)*TAU/128
		for point in [Vector2(a,0),Vector2(b,1),Vector2(a,1),Vector2(a,0),Vector2(b,0),Vector2(b,1)]:
			var radius=size*lerpf(1.19,2.32,point.y)
			st.set_uv(Vector2(point.y,0));st.add_vertex(Vector3(cos(point.x)*radius,0,sin(point.x)*radius))
	var visual=MeshInstance3D.new();visual.mesh=st.commit()
	var dust=ShaderMaterial.new();dust.shader=preload("res://assets/ice_rings.gdshader")
	visual.material_override=dust;visual.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;parent.add_child(visual)
func add_meteor():
	shooting_star=MeshInstance3D.new();var mesh=QuadMesh.new();mesh.size=Vector2(2.5,.035);shooting_star.mesh=mesh;var material=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.albedo_color=Color(.64,.83,1,.0);material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;shooting_star.material_override=material;space.add_child(shooting_star)
func advance(dt:float):
	clock+=dt;meteor_clock+=dt
	nebula_clock+=dt*settings.drift
	star_material.set_shader_parameter("drift",nebula_clock)
	star_material.set_shader_parameter("twinkle_time",clock)
	for i in range(cloud_regions.size()):
		var region=cloud_regions[i];var offset=Vector3(sin(nebula_clock*.011+i)-sin(float(i)),sin(nebula_clock*.008+i*.7)-sin(i*.7),0)*.45
		region.node.position=region.center+offset;region.material.set_shader_parameter("cloud_center",region.node.position);region.material.set_shader_parameter("drift",nebula_clock)
		region.cluster.position=region.node.position
		region.lights.position=region.node.position
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
	advance_observation(dt)
var sky_frame_time=0.
func _process(dt):
	if not is_instance_valid(viewport):return
	if OS.has_feature("android") and not observatory_active:
		sky_frame_time+=dt
		if sky_frame_time<.05:return
		dt=sky_frame_time;sky_frame_time=0.
		viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
	elif viewport.render_target_update_mode!=SubViewport.UPDATE_ALWAYS:
		viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	advance(dt)
func screen_position(index:int)->Vector2:
	var position=space_camera.unproject_position(bodies[index].orbit.position)
	return position*get_viewport().get_visible_rect().size/Vector2(viewport.size)
func handle_tap(screen_pos:Vector2)->bool:
	if observatory_active:return false
	# Only touches clearly above the close island are eligible, so distant planets cannot steal worksite taps.
	if screen_pos.y>get_viewport().get_visible_rect().size.y*.30:return false
	if black_hole.visible:
		var factor=get_viewport().get_visible_rect().size/Vector2(viewport.size)
		var center=space_camera.unproject_position(CENTER)*factor
		var radius=(space_camera.unproject_position(CENTER+space_camera.global_basis.x*2.6)*factor).distance_to(center)
		if screen_pos.distance_to(center)<radius:game.open_observatory(true);return true
	for i in range(bodies.size()):
		if screen_position(i).distance_to(screen_pos)<28:
			if focus_index>=0:bodies[focus_index].axis.scale=Vector3.ONE
			focus_index=i;focus_time=1.5;return true
	return false
