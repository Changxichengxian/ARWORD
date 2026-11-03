extends Node3D

# Local coordinates are tangent to the launch pad. Only the exposed sections of
# each limb exist in this scene. Their ends continue beneath the sea floor.
const LAYER=2
const MODEL="res://assets/models/rocket_kraken.glb"
const ARM_NAMES=["CrownCoil","ShelfGrip","BreachArch","SpurHook"]
const WATER_CONTACTS=[Vector3(-3,-1.3,-1.8),Vector3(4.6,-1.25,-.6),Vector3(-2.8,-1.3,3.0)]
const LOOSEN_START=[.42,.10,.0,.26]
# The touch paths follow the exposed middle of each sculpt, including the arch
# that remains offshore. Buried sections never intercept a tap on the water.
var touch_paths=preload("res://assets/kraken_paths.json").data
var world
var arms:Array[MeshInstance3D]=[]
var channels:Array=[]
var pile:Node3D
var coin_socket:Node3D
var release=0.0
var pulse=0.0
var wake_time=0.0
var wake_index=0
var animation_clock=0.0

static func isolate(node:Node3D):
	if node is GeometryInstance3D:node.layers=LAYER
	for mesh in node.find_children("*","GeometryInstance3D",true,false):mesh.layers=LAYER

func setup(owner_world):
	world=owner_world
	var visual=load(MODEL).instantiate()
	add_child(visual)
	isolate(visual)
	isolate(world.facilities.rocket)
	for arm_name in ARM_NAMES:
		var arm=visual.find_child(arm_name,true,false) as MeshInstance3D
		if arm==null:push_error("Missing arm: "+arm_name);continue
		var skin=ShaderMaterial.new()
		skin.shader=preload("res://assets/kraken_skin.gdshader")
		skin.set_shader_parameter("planet_center",arm.to_local(world.globe.global_position))
		arm.material_override=skin
		arms.append(arm)
		channels.append([arm.find_blend_shape_by_name("Release"),arm.find_blend_shape_by_name("Breath"),arm.find_blend_shape_by_name("Pulse")])
	coin_socket=Node3D.new()
	add_child(coin_socket)
	var chart_point=world.game.frontier.target("rocket")+Vector2(1.55,1.88)
	coin_socket.position=transform.affine_inverse()*world.surface(chart_point)
	var stone=world.pebble(coin_socket,Vector3(0,.09,0),Vector3(.72,.25,.55),"514956")
	isolate(stone)
	pile=world.model("gold_coin",coin_socket)
	pile.position.y=.20
	isolate(pile)
	# Moon rim behind the coils; a smaller amber practical picks out the ladder.
	var moon=SpotLight3D.new()
	moon.light_cull_mask=LAYER;moon.light_color=Color("92BCE8");moon.light_energy=4.8
	moon.spot_range=11;moon.spot_angle=55;moon.spot_attenuation=.65
	moon.shadow_enabled=true;moon.shadow_bias=.015;moon.shadow_normal_bias=.42
	add_child(moon);moon.position=Vector3(-3.1,5.1,-1.6)
	moon.basis=Basis.looking_at(Vector3(.8,.2,1.0)-moon.position,Vector3.UP)
	light_at(Vector3(1.8,1.7,2.9),Color("DDA576"),1.35,5.0)
	var lamp=world.pebble(coin_socket,Vector3(.29,.21,.02),Vector3(.12,.19,.12),"F3B272")
	var lit=lamp.material_override.duplicate() as StandardMaterial3D
	lit.emission_enabled=true;lit.emission=Color("F5A85F");lit.emission_energy_multiplier=1.0
	lamp.material_override=lit;isolate(lamp)
	release=paid_fraction()
	sync_state()
	apply_pose()

func light_at(at:Vector3,color:Color,energy:float,distance:float):
	var light=OmniLight3D.new()
	light.light_cull_mask=LAYER;light.light_color=color;light.light_energy=energy
	light.omni_range=distance;light.omni_attenuation=1.0;light.shadow_enabled=false
	add_child(light);light.position=at

func paid_fraction()->float:
	var frontier=world.game.frontier
	return 1.0 if frontier.rocket_open() else float(frontier.data.voyage.paid)/IslandFrontier.TRADE_PRICE

func sync_state():
	pile.visible=world.game.frontier.data.voyage.paid>0
	pile.scale=Vector3.ONE*lerpf(.57,1.22,paid_fraction())

func advance(dt:float):
	release=move_toward(release,paid_fraction(),dt*.36)
	pulse=maxf(0,pulse-dt)
	animation_clock+=dt
	if animation_clock<.034:return
	var elapsed=animation_clock
	animation_clock=0.0
	var camera=world.game.camera
	if is_instance_valid(camera) and global_basis.y.dot((camera.global_position-global_position).normalized())<-.1:return
	apply_pose()
	wake_time-=elapsed
	if wake_time<=0.0 and release<.98:
		var point=WATER_CONTACTS[wake_index%WATER_CONTACTS.size()]
		world.water.ripple((transform*point).normalized(),.46)
		wake_index+=1;wake_time=4.7+float(wake_index%3)*.66

func apply_pose():
	for i in range(arms.size()):
		var loosened=smoothstep(LOOSEN_START[i],1.0,release)
		var breath=(.5+.5*sin(world.time*.72+float(i)*1.38))*(1.0-.65*loosened)
		var t=(1.4-pulse)-i*.08
		var recoil=sin(clampf(t/.72,0,1)*PI)*(1.0-loosened) if pulse>0 else 0.0
		var values=[loosened,breath,recoil]
		for j in range(3):
			if channels[i][j]>=0:arms[i].set_blend_shape_value(channels[i][j],values[j])

func receive(amount:int):
	pulse=1.4
	var origin=transform*(coin_socket.position+Vector3(0,.36,0))
	var local_end=Vector3(2.4,.60,.10).lerp(WATER_CONTACTS[1],release*.55)
	world.send_material(origin,transform*local_end,"gold_coin",mini(amount,6),.52)
	world.water.ripple((transform*WATER_CONTACTS[1]).normalized(),1.6)
	sync_state()

func hit(screen:Vector2)->bool:
	var camera=world.game.camera
	if global_basis.y.dot((camera.global_position-global_position).normalized())<.18:return false
	if screen_hit(camera,coin_socket.global_position,screen,.42):return true
	for i in ARM_NAMES.size():
		var loosened=smoothstep(LOOSEN_START[i],1.0,release)
		for sample in touch_paths[ARM_NAMES[i]]:
			var local=Vector3(sample[0],sample[1],sample[2]).lerp(Vector3(sample[4],sample[5],sample[6]),loosened)
			var radial:Vector3=transform*local
			if radial.length()+sample[3]<world.water.BASE_RADIUS-.12:continue
			if screen_hit(camera,to_global(local),screen,sample[3]):return true
	return false

func screen_hit(camera:Camera3D,point:Vector3,screen:Vector2,radius:float)->bool:
	if camera.is_position_behind(point):return false
	var center=camera.unproject_position(point)
	var pixels=camera.unproject_position(point+camera.global_basis.x*radius).distance_to(center)
	return center.distance_to(screen)<maxf(9,pixels)
