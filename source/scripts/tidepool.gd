extends Node3D

const LEDGE=preload("res://assets/models/tidal_ledge.glb")
const CRAB=preload("res://assets/models/wild_crab.glb")
const SEAL=preload("res://assets/models/wild_seal.glb")
var crab:Node3D
var seal:Node3D
var head:Node3D
var flipper:Node3D
var claw:Node3D
var attention=0.
var scuttle=0.
var normal=Vector3.ZERO

func _ready():
	add_child(LEDGE.instantiate())
	crab=CRAB.instantiate();add_child(crab);crab.scale=Vector3.ONE*.69
	seal=SEAL.instantiate();add_child(seal);seal.scale=Vector3.ONE*.77
	seal.position=Vector3(.28,0,.055);seal.rotation.y=-1.02
	head=seal.find_child("Head",true,false);flipper=seal.find_child("FlipperL",true,false)
	claw=crab.find_child("ClawL",true,false)

func choose_coast(life):
	# Keep an inhabited shelf in place when a distant island grows.
	if normal!=Vector3.ZERO and life.outside_land(normal,1.40):return
	hide();normal=Vector3.ZERO
	for n in life.coast+life.offshore:
		if n.dot(Vector3.DOWN)>.45 or not life.outside_land(n,1.40) or not life.clear_of_cave(n,1.40):continue
		normal=n;position=n*(IslandWater.BASE_RADIUS+.155)
		basis=life.frame_at(position,life.tangent_axes(n)[1]);show();return

func animate(t:float,dt:float):
	if not visible:return
	attention=maxf(0,attention-dt);scuttle=maxf(0,scuttle-dt)
	var intent=smoothstep(0.,.9,attention)
	head.rotation.x=-.10+.10*sin(t*.46)-.27*intent
	head.rotation.y=.31*sin(t*.31)+.27*intent
	flipper.rotation.z=-.09+.08*sin(t*.8)+.18*intent
	seal.scale.y=.77*(1.+.018*sin(t*1.8))
	# The crab travels sideways and pauses at each end to display its large claw.
	var travel=clampf(1.45*sin(t*.44),-1.,1.)
	var step_weight=1.-smoothstep(.80,1.,absf(travel))
	crab.position=Vector3(-.72+.14*travel,.014*absf(sin(t*9.))*step_weight,-.16+.12*smoothstep(0.,.75,scuttle))
	crab.rotation.z=.035*sin(t*9.)*step_weight
	claw.rotation.z=-.16-(1.-step_weight)*(.36+.22*sin(t*4.))-.33*smoothstep(0.,.7,scuttle)

func notice(kind:String):
	if kind=="seal":attention=2.4
	else:scuttle=1.5
