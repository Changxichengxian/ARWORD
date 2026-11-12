extends SceneTree
# Exercise real imported vertex envelopes through the production animation,
# then test complete aquatic bodies against the physical sea floor and surface.
var failed=0
var passed=0
class GameStub extends Node3D:
	var camera:Camera3D
	var frontier=IslandFrontier.new(IslandLearning.new())
class WorldStub extends Node3D:
	var game
	var globe:Node3D
	var water:IslandWater
	var time=0.
	var terrain=IslandTerrain.new()
	var land={Vector2i(0,0):true,Vector2i(1,0):true,Vector2i(0,1):true}
	func surface(p:Vector2)->Vector3:return terrain.point(p)
func _initialize():
	if not "--qa" in OS.get_cmdline_user_args():quit(2);return
	call_deferred("run")
func check(ok:bool,label:String):
	if ok:passed+=1;print("PASS ",label)
	else:failed+=1;push_error("FAIL "+label)
func vertices(model:Node3D)->Array:
	var result=[]
	for part in model.find_children("*","MeshInstance3D",true,false):
		var points={}
		for surface in part.mesh.get_surface_count():
			for v in part.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:points[v]=true
		result.append({"part":part,"vertices":points.keys()})
	return result
func run():
	var game=GameStub.new();root.add_child(game)
	game.camera=Camera3D.new();game.add_child(game.camera);game.camera.position=Vector3(0,24,24);game.camera.look_at(Vector3.ZERO)
	var world=WorldStub.new();game.add_child(world);world.game=game;world.globe=Node3D.new();world.add_child(world.globe)
	for cell in IslandFrontier.ROCKET_CELLS:world.land[cell]=true
	var ocean=load("res://assets/models/ocean.glb").instantiate();world.globe.add_child(ocean)
	world.water=IslandWater.new();world.globe.add_child(world.water);world.water.setup(world,ocean)
	var life=IslandWildlife.new();world.add_child(life);life.setup(world);life.set_process(false)
	var sampled=[];var types={}
	for animal in life.animals:
		if animal.kind=="fish" and not types.has(animal.species):
			types[animal.species]=true;sampled.append({"animal":animal,"geometry":vertices(animal.model)})
	check(types.size()==13 and types.has("octopus") and types.has("hammerhead") and types.has("sunfish"),"octopus, hammerhead and sunfish join the existing aquatic animals")
	var bird={};var turtle={}
	for animal in life.animals:
		if animal.kind=="bird":bird=animal
		if animal.species=="turtle":turtle=animal
	check(bird.tip_left!=null and bird.tip_right!=null,"gull has articulated hand wings")
	check(turtle.hind_left!=null and turtle.hind_right!=null and turtle.head!=null,"turtle has separate steering paddles and head")
	var bird_states={};var turtle_states={};var hind_min=INF;var hind_max=-INF;var tip_min=INF;var tip_max=-INF
	var maximum={};var minimum={};var hull_safe=true;var wet=true;var on_ocean=true;var finite=true
	var dolphins_surface=false;var dolphins_dive=false;var squid_states={};var moving_fins={}
	for expanded in [false,true]:
		if expanded:
			for chapter in IslandFrontier.CHAPTERS:
				for cell in chapter.cells:world.land[cell]=true
			world.water.rebuild();life.refresh_habitats()
		var valid=0;var trench=0;var main_shore=0;var quadrants={}
		for animal in life.animals:
			if animal.kind!="fish" or not animal.route_valid:continue
			valid+=1
			var n:Vector3=animal.normal
			if n.dot(life.trench_normal)>IslandWildlife.TRENCH_EDGE:trench+=1
			if n.y>(.45 if expanded else .68):
				main_shore+=1
				quadrants[int(fposmod(atan2(n.z,n.x),TAU)/(PI*.5))]=true
		print("FISH_HABITATS expanded=",expanded," valid=",valid," main=",main_shore," trench=",trench," quadrants=",quadrants.keys())
		check(valid==(38 if expanded else 34),"all fish have safe routes")
		check(main_shore>=8 and quadrants.size()>=3 and trench<=2,"main shore has several populated directions and the trench has at most two residents")
		for step in 60:
			world.time+=.53;life._process(.53)
			bird_states[bird.state]=true;turtle_states[turtle.state]=true
			if turtle.hind_left:
				hind_min=minf(hind_min,turtle.hind_left.rotation.z);hind_max=maxf(hind_max,turtle.hind_left.rotation.z)
			if bird.tip_left:
				tip_min=minf(tip_min,bird.tip_left.rotation.z);tip_max=maxf(tip_max,bird.tip_left.rotation.z)
			for entry in sampled:
				var a=entry.animal
				if not a.anchor.visible:continue
				if a.species=="dolphin":dolphins_surface=dolphins_surface or a.state=="surface";dolphins_dive=dolphins_dive or a.state=="swim"
				if a.species=="squid":squid_states[a.state]=true
				if a.species in ["seahorse","puffer"] and a.fin_left and absf(a.fin_left.rotation.z)>.12:moving_fins[a.species]=true
				for part in entry.geometry:
					var transform=life.global_transform.affine_inverse()*part.part.global_transform
					for v in part.vertices:
						var point:Vector3=transform*v;var n=point.normalized()
						var floor_gap=point.length()-world.water.floor_radius(n)
						var surface_gap=IslandWater.surface_radius(n,world.time)-point.length()
						minimum[a.species]=minf(minimum.get(a.species,INF),floor_gap)
						maximum[a.species]=minf(maximum.get(a.species,INF),surface_gap)
						hull_safe=hull_safe and floor_gap>=-.015
						wet=wet and surface_gap>=(-.45 if a.species=="dolphin" and a.state=="surface" else -.015)
						on_ocean=on_ocean and life.outside_land(n,0.);finite=finite and point.is_finite()
	check(bird_states.has("flap") and bird_states.has("glide") and tip_max-tip_min>.2,"gull alternates flapping and gliding with flexible hand wings")
	check(turtle_states.has("paddle") and turtle_states.has("glide") and hind_max-hind_min>.06,"turtle alternates strokes and gliding while rear paddles steer")
	check(finite and hull_safe and on_ocean,"all sampled aquatic mesh vertices clear land and seabed before and after expansion")
	check(wet,"all sampled aquatic mesh vertices stay below the moving water surface")
	check(dolphins_surface and dolphins_dive,"dolphins alternate surface breathing and submerged swimming")
	check(squid_states.has("pulse") and squid_states.has("glide") and moving_fins.size()==2,"squid pulses and glides; seahorse and puffer actively paddle")
	print("MIN_SEABED_CLEARANCE ",minimum);print("MIN_SURFACE_CLEARANCE ",maximum)
	game.queue_free();await process_frame;await process_frame
	print("WILDLIFE_MOTION_RESULT ",passed," passed / ",failed," failed");quit(int(failed>0))
