extends SceneTree

# Geometry regression against an explicitly supplied pre-optimization snapshot.
# The reference is loaded locally; no duplicate production implementation is kept here.
var failures=0
var checks=0
var terrain:IslandTerrain
var reference

class SampleWater extends RefCounted:
	var calls=0
	func depth_at(n:Vector3)->float:
		calls+=1
		return 2.0+sin(n.x*3.7)*.6+cos(n.y*2.1)*.4+n.z*.3

class SampleWorld extends RefCounted:
	var water

func check(ok:bool,label:String):
	checks+=1
	if not ok:failures+=1;push_error(label)

func _initialize():
	if not "--qa" in OS.get_cmdline_user_args():quit(2);return
	var reference_path=""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--baseline-terrain="):reference_path=argument.trim_prefix("--baseline-terrain=")
	if reference_path.is_empty() or not FileAccess.file_exists(reference_path):
		push_error("Supply --baseline-terrain=<path to the original terrain.gd>");quit(2);return
	var reference_script=GDScript.new()
	reference_script.source_code=FileAccess.get_file_as_string(reference_path).replace("class_name IslandTerrain", "")
	if reference_script.reload()!=OK:quit(2);return
	reference=reference_script.new()
	terrain=IslandTerrain.new()
	var samples=PackedVector2Array()
	var rng=RandomNumberGenerator.new();rng.seed=69143
	for cell in terrain.cells:
		var center=IslandFrontier.point(cell)
		samples.append(center)
		for i in range(6):
			var corner=Vector2.from_angle((i*60+30)*PI/180)*IslandTerrain.H
			# Both sides of sector/hex boundaries, including exact ties.
			for scale_factor in [.59999,.6,.60001,.99999,1.0,1.00001,1.08]:
				samples.append(center+corner*scale_factor)
		for i in range(12):samples.append(center+Vector2(rng.randf_range(-2,2),rng.randf_range(-2,2)))
	for i in range(200):samples.append(Vector2(rng.randf_range(-70,70),rng.randf_range(-50,50)))
	var max_point_error=0.0;var max_basis_error=0.0
	for p in samples:
		check(terrain.cell_at(p)==reference.cell_at(p),"nearest cell/tie changed at "+str(p))
		check(terrain.chart_at(p)==reference.chart_at(p),"chart selection changed at "+str(p))
		var expected=reference.point(p)
		max_point_error=maxf(max_point_error,terrain.point(p).distance_to(expected))
		check(absf(terrain.height_at(p)-reference.height_at(p))<.00001,"terrain height changed at "+str(p))
		var chart=reference.chart_at(p);var basis=reference.chart_basis(chart)
		var expected_basis=basis*Basis(Quaternion(Vector3.UP,(basis.inverse()*expected).normalized()))
		var actual_basis=terrain.surface_basis(p)
		for column in range(3):max_basis_error=maxf(max_basis_error,actual_basis[column].distance_to(expected_basis[column]))
		check(terrain.coordinates(expected).distance_to(reference.coordinates(expected))<.00002,"inverse chart changed at "+str(p))
	check(max_point_error<.00002,"surface positions changed")
	check(max_basis_error<.00002,"surface orientation changed")
	var rebuilt=IslandTerrain.new()
	for p in samples:check(rebuilt.point(p).is_equal_approx(terrain.point(p)),"fresh terrain disagrees with existing geometry")
	check(terrain.cell_centers.size()==terrain.cells.size() and terrain.chart_bases.size()==5,"fixed lookup table sizes")
	test_footprint_samples()
	print(JSON.stringify({"test":"terrain_performance","checks":checks,"failures":failures,"points":samples.size(),"max_point_error":max_point_error,"max_basis_error":max_basis_error}))
	quit(1 if failures else 0)

func test_footprint_samples():
	var life=IslandWildlife.new();var sample_world=SampleWorld.new();sample_world.water=SampleWater.new();life.world=sample_world
	for n in [Vector3.UP,Vector3.DOWN,Vector3.RIGHT,Vector3(1,2,3).normalized(),Vector3(.01,.9999,.002).normalized()]:
		for radius in [0.0,.000001,.26,.36,.44,.65,1.32,2.63,3.24]:
			var expected=sample_world.water.depth_at(n)
			for i in range(8):expected=minf(expected,sample_world.water.depth_at(life.offset_direction(n,Vector2(cos(i*TAU/8),sin(i*TAU/8))*radius)))
			sample_world.water.calls=0
			check(absf(life.body_depth_normal(n,radius)-expected)<.000001,"animal seabed clearance changed")
			check(sample_world.water.calls==9,"animal footprint must still query all nine samples")
	life.tidepool.free();life.free()
