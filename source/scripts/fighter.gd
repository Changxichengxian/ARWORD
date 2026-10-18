extends CharacterBody3D
class_name FrontierFighter

var main
var player=false
var kind=0
var model:Node3D
var hp=100.0
var max_hp=100.0
var ammo=6
var capacity=6
var reload_left=0.0
var cooldown=0.0
var aim=Vector3.FORWARD
var dash_left=0.0
var dash_cooldown=0.0
var invulnerable=0.0
var dash_direction=Vector3.FORWARD
var knock=Vector3.ZERO
var gait=0.0
var last_seen=Vector3.ZERO
var search_left=0.0
var think_left=0.0
var move_intent=Vector3.ZERO
var shot_windup=0.0
var recoil=0.0
var flash=0.0
var label:Label3D
var leg_l:Node3D
var leg_r:Node3D
var gun:Node3D
var body:Node3D
var home=Vector3.ZERO
var meshes:Array=[]
var flash_material:StandardMaterial3D
var hit_tween:Tween
var fall_tween:Tween
var observed_velocity=Vector3.ZERO
var aim_line:MeshInstance3D

func setup(owner_node,is_player:bool,type:int,p:Vector3):
	main=owner_node;player=is_player;kind=type
	collision_layer=1;collision_mask=3
	var shape=CollisionShape3D.new();var capsule=CapsuleShape3D.new()
	capsule.radius=.37;capsule.height=1.65;shape.shape=capsule;shape.position.y=.83;add_child(shape)
	model=load("res://assets/models/"+(["raider","sentinel","flanker"][kind] if not player else "ranger")+".glb").instantiate()
	add_child(model)
	meshes=model.find_children("*","MeshInstance3D",true,false)
	flash_material=StandardMaterial3D.new();flash_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_material.albedo_color=Color(1,.94,.70,.75);flash_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	leg_l=model.find_child("LegL",true,false);leg_r=model.find_child("LegR",true,false)
	gun=model.find_child("Gun",true,false);body=model.find_child("Body",true,false)
	position=p;home=p;last_seen=p
	max_hp=100 if player else [58,88,64][kind];hp=max_hp
	capacity=6 if player else 3;ammo=capacity
	cooldown=1.0+kind*.4
	label=Label3D.new();label.font=main.font;label.font_size=38;label.pixel_size=.008
	label.position.y=2.25;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test=false;label.outline_size=8;add_child(label)
	label.text="" if player else ["急进者","守点者","绕行者"][kind]
	label.modulate=Color("fdf3dc")
	var ring=MeshInstance3D.new();var torus=TorusMesh.new();torus.inner_radius=.41;torus.outer_radius=.48;torus.rings=16;torus.ring_segments=6
	ring.mesh=torus;ring.material_override=main.world.material(Color("5cf0db") if player else Color("ff9c73"));ring.position.y=.05;add_child(ring)
	aim_line=MeshInstance3D.new();var line=BoxMesh.new();line.size=Vector3(.055,.025,3.0);aim_line.mesh=line
	aim_line.material_override=main.world.material(Color("ff7944"));add_child(aim_line);aim_line.hide()

func tick(dt:float,move:Vector2=Vector2.ZERO,wants_fire=false):
	if hp<=0:return
	if flash>0:
		flash=maxf(0,flash-dt)
		if flash==0:
			for part in meshes:part.material_overlay=null
	cooldown=maxf(0,cooldown-dt);dash_cooldown=maxf(0,dash_cooldown-dt)
	invulnerable=maxf(0,invulnerable-dt);recoil=maxf(0,recoil-dt*6)
	if reload_left>0:
		reload_left=maxf(0,reload_left-dt)
		if reload_left==0:
			ammo=capacity
			if player:main.sfx("reload",.65)
	if not player: ai(dt)
	else: move_intent=Vector3(move.x,0,move.y)
	var speed=6.0 if player else [2.85,2.1,3.3][kind]
	if dash_left>0:
		dash_left=maxf(0,dash_left-dt);velocity=dash_direction*18
	else:
		var desired=move_intent*speed
		velocity.x=move_toward(velocity.x,desired.x,dt*48)
		velocity.z=move_toward(velocity.z,desired.z,dt*48)
	knock=knock.move_toward(Vector3.ZERO,dt*18)
	velocity+=knock;velocity.y=-4
	move_and_slide()
	if player and wants_fire:shoot()
	if aim.length_squared()>.1:
		var target_angle=atan2(-aim.x,-aim.z)
		model.rotation.y=lerp_angle(model.rotation.y,target_angle,minf(1,dt*22))
	gait+=dt*minf(velocity.length(),8)*2
	var stride=minf(Vector2(velocity.x,velocity.z).length()/6,1)
	if leg_l:leg_l.rotation.x=sin(gait)*.65*stride
	if leg_r:leg_r.rotation.x=-sin(gait)*.65*stride
	if body:body.position.y=.78+abs(sin(gait))*.055*stride
	if gun:gun.position.z=-.44+recoil*.13
	if not player:
		aim_line.visible=reload_left<=0 and cooldown<.18 and shot_windup>.16
		aim_line.position=aim*1.8+Vector3.UP*.055;aim_line.rotation.y=atan2(-aim.x,-aim.z)
		label.text=("换弹  %.1f"%reload_left) if reload_left>0 else (["急进","守点","绕行"][kind]+"  "+str(ceili(hp)))
		label.modulate=Color("ffde67") if reload_left>0 else Color("fff2df")

func ai(dt:float):
	if main.phase!="battle":move_intent=Vector3.ZERO;return
	var target=main.player
	var offset=target.position-position;offset.y=0
	var distance=offset.length()
	var sees=distance<17 and main.line_clear(position+Vector3.UP*.9,target.position+Vector3.UP*.9)
	if sees:
		last_seen=target.position;search_left=3.4
		observed_velocity=observed_velocity.lerp(Vector3(target.velocity.x,0,target.velocity.z),minf(1,dt*5))
	else:search_left=maxf(0,search_left-dt)
	think_left-=dt
	if think_left<=0:
		think_left=.20+randf()*.18
		var goal=last_seen
		if reload_left>0:
			goal=position-offset.normalized()*3
		elif sees and kind==2:
			goal=target.position+offset.normalized()*-6+Vector3(-offset.z,0,offset.x).normalized()*4.5
		elif sees and kind==1 and distance<8:goal=position
		elif sees and distance<4.8:goal=position-offset.normalized()*2.3
		if search_left<=0:goal=home
		move_intent=main.world.steer(position,goal)
	if sees:
		var skill=main.save_data.challenge
		var lead=observed_velocity*(distance/[11.0,13.0,15.0][skill]+.12)*[0.0,.72,1.0][skill]
		var predicted=(offset+lead.limit_length(4.0)).normalized()
		aim=aim.slerp(predicted,minf(1,dt*[2.6,4.2,5.2][skill])).normalized()
		if distance<11.5 and aim.dot(predicted)>.96 and reload_left<=0:
			shot_windup+=dt
			if shot_windup>.32:shoot()
		else:shot_windup=0
	else:shot_windup=0

func shoot():
	if cooldown>0 or reload_left>0 or hp<=0:return
	if ammo<=0:reload();return
	ammo-=1;recoil=1
	cooldown=.19 if player else [.72,.64,.58][main.save_data.challenge]
	main.fire(self)
	if ammo==0:reload()

func reload():
	if reload_left>0 or ammo==capacity:return
	reload_left=1.05 if player else [1.8,2.15,1.65][kind]
	if player:main.sfx("click",.4)

func dash(direction:Vector3) -> bool:
	if dash_cooldown>0 or hp<=0:return false
	dash_direction=direction.normalized() if direction.length_squared()>.04 else aim
	dash_left=.17;invulnerable=.25;dash_cooldown=1.55
	main.sfx("dash",.7);main.burst(position+Vector3.UP*.1,Color("9bddd2"),7,2)
	return true

func hurt(damage:float,direction:Vector3,source):
	if hp<=0:return
	if invulnerable>0:
		if player:main.perfect_dodge()
		return
	if not player and source==main.player and reload_left>0:
		damage*=1.6;main.counters+=1;main.float_text(position+Vector3.UP*2.5,"破绽！",Color("ffdd64"))
	elif not player and kind==1 and -direction.dot(aim)>.55:
		damage*=.6
	hp=maxf(0,hp-damage);knock+=direction*(2 if player else 4)
	flash=.075
	for part in meshes:part.material_overlay=flash_material
	if not player:main.impact_pause=maxf(main.impact_pause,.055 if reload_left>0 else .025)
	main.float_text(position+Vector3.UP*1.6,str(ceili(damage)),Color("fff0c6") if not player else Color("ff8d6e"))
	main.burst(position+Vector3.UP*.8,Color("efbf6a") if not player else Color("65ded4"),5,2)
	main.sfx("hit" if not player else "hurt",.6)
	if player:main.camera_shake=.18
	else:main.camera_shake=maxf(main.camera_shake,.055)
	if hit_tween and hit_tween.is_running():hit_tween.kill()
	hit_tween=create_tween();hit_tween.tween_property(model,"scale",Vector3(1.13,.88,1.13),.055);hit_tween.tween_property(model,"scale",Vector3.ONE,.12)
	if hp<=0:
		collision_layer=0
		main.fighter_down(self)
		fall_tween=create_tween();fall_tween.tween_property(model,"rotation:z",1.5,.2);fall_tween.parallel().tween_property(model,"scale",Vector3.ONE*.1,.4)
		if not player:fall_tween.tween_callback(queue_free)

func reset_transients():
	if hit_tween and hit_tween.is_running():hit_tween.kill()
	if fall_tween and fall_tween.is_running():fall_tween.kill()
	model.scale=Vector3.ONE;model.rotation.z=0;dash_left=0;invulnerable=0;dash_cooldown=0;knock=Vector3.ZERO;flash=0
	for part in meshes:part.material_overlay=null
