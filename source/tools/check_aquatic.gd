extends SceneTree
class WorldStub extends Node3D:
	var game
	var globe:Node3D
	var water:IslandWater
	var time=0.0
	var land={Vector2i(0,0):true,Vector2i(1,0):true,Vector2i(0,1):true}
	var terrain=IslandTerrain.new()
	func surface(p:Vector2)->Vector3:return terrain.point(p)
class GameStub extends Node3D:
	var camera:Camera3D
var passed=0
var failed=0
func check(condition:bool,label:String):
	if condition:passed+=1;print("PASS ",label)
	else:failed+=1;push_error("FAIL "+label)
func _initialize():call_deferred("run")
func run():
	var game=GameStub.new();root.add_child(game)
	game.camera=Camera3D.new();game.add_child(game.camera);game.camera.position=Vector3(0,25,25);game.camera.look_at(Vector3.ZERO)
	var world=WorldStub.new();game.add_child(world);world.game=game;world.globe=Node3D.new();world.add_child(world.globe)
	var ocean=load("res://assets/models/ocean.glb").instantiate();world.globe.add_child(ocean)
	var smallest=INF;var largest=0.0
	for mesh in ocean.find_children("*","MeshInstance3D",true,false):
		for surface in range(mesh.mesh.get_surface_count()):
			for vertex in mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				var radius=world.globe.to_local(mesh.to_global(vertex)).length();smallest=minf(smallest,radius);largest=maxf(largest,radius)
	print("IMPORTED_OCEAN_RADII ",smallest," .. ",largest)
	check(abs(largest-11.62)<.002 and abs(smallest-11.62)<.002,"actual ocean GLB vertices have an eleven-point-six-two radius before shader displacement")
	# Production creates water before the first land cells. Wildlife must refresh
	# that initial all-ocean map before selecting its first safe sea lanes.
	var initial_land=world.land.duplicate();world.land.clear()
	world.water=IslandWater.new();world.globe.add_child(world.water);world.water.setup(world,ocean)
	world.land=initial_land
	var life=IslandWildlife.new();world.add_child(life);life.setup(world);life.set_process(false)
	check(world.water.land_count==world.land.size() and world.water.depth_at(Vector3.UP)<.35 and world.water.depth_at(Vector3.DOWN)>2.5,"first wildlife setup refreshes the actual shallow and deep seabed before route selection")
	var stable_frames=true
	for i in range(20):
		var n=Vector3(sin(i),.9,cos(i)*.7).normalized();var basis=life.frame_at(n*11.4,n*.2+Vector3(.0000001,.000002,.0000003))
		if absf(basis.x.dot(basis.y))>.00001 or absf(basis.y.dot(basis.z))>.00001 or absf(basis.determinant()-1)>.00001:stable_frames=false
	check(stable_frames,"near-radial motion still produces stable orthogonal swimming frames")
	var fish_submerged=true;var fish_above_floor=true;var whale_above_floor=true;var surfaced=false;var breached=false;var sprayed=false;var swimming_whale=false
	for step in range(450):
		world.time+=.1;life._process(.1)
		for animal in life.animals:
			if not animal.anchor.visible:continue
			if animal.kind=="fish":
				var normal=animal.anchor.position.normalized();var surface=IslandWater.surface_radius(normal,world.time)
				if animal.anchor.position.length()+.17>surface:fish_submerged=false
				if animal.anchor.position.length()-.14<world.water.floor_radius(normal):fish_above_floor=false
			elif animal.kind=="whale":
				if animal.state=="swim":swimming_whale=true
				if animal.state=="breathe":surfaced=true
				if animal.state=="breach":breached=true
				if animal.anchor.position.length()-.40<world.water.floor_radius(animal.anchor.position.normalized()):whale_above_floor=false
		if not life.water_effects.is_empty():sprayed=true
	check(fish_submerged,"fish bodies stay below the same moving surface used by the water shader")
	check(fish_above_floor,"fish remain above the real seabed")
	check(swimming_whale and whale_above_floor,"a whale patrols a genuinely deep lane above the seabed")
	check(surfaced and breached and sprayed,"the whale surfaces, sprays, breaches and splashes during its natural cycle")
	check(world.water.strengths.length()>0,"landing creates a ripple in the actual water shader")
	for chapter in IslandFrontier.CHAPTERS:
		for cell in chapter.cells:world.land[cell]=true
	world.water.rebuild();life.refresh_habitats();life._process(.1)
	var whale_count=0;var valid_routes=0
	for animal in life.animals:
		if animal.kind=="whale":
			whale_count+=1
			if animal.route_valid:valid_routes+=1
	check(whale_count==2 and valid_routes==2,"both adult and calf retain safe sea lanes after full island expansion")
	game.queue_free();await process_frame;await process_frame
	print("AQUATIC_RESULT ",passed," passed / ",failed," failed")
	quit(0 if failed==0 else 1)
