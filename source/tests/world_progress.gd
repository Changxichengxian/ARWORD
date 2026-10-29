extends SceneTree
var passed=0
var failed=0
func check(value:bool,label:String):
	if value:passed+=1;print("PASS ",label)
	else:failed+=1;push_error("FAIL "+label)
func _initialize():call_deferred("run")
func run():
	var game=load("res://main.tscn").instantiate();root.add_child(game)
	await create_timer(.5).timeout
	game.explore();game.camera.size=18;game.camera.look_at(Vector3(0,8,0))
	await create_timer(.3).timeout
	var world=game.world;var hud=game.hud;var label=hud.world_progress.grove.panel
	check(label.visible,"unfinished work has a visible label above its own location")
	var initial=label.position;world.drag(Vector2(65,0))
	await create_timer(.4).timeout
	check(label.position.distance_to(initial)>5,"work label follows the object during planet rotation")
	var expected=game.camera.unproject_position(world.progress_anchor("grove"))-Vector2(label.size.x*.5,label.size.y+8)
	check(label.position.distance_to(expected)<1,"progress remains anchored to the worksite instead of the screen header")
	check(world.site_at(label.get_global_rect().get_center())=="grove","tapping an anchored label selects the same worksite")
	game.select_site("cottage");await create_timer(.4).timeout
	var center=Vector2.ZERO;var vertices=world.cursor.get_child(0).get_child(0).mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for vertex in vertices:center+=world.terrain.coordinates(vertex)
	center/=vertices.size()
	check(center.distance_to(game.frontier.target("cottage"))<.001,"the actual selection ring vertices move around the selected building")
	var extra_rings=0
	for marker in world.markers.values():
		for child in marker.get_children():
			if child.name!="Sign":extra_rings+=1
	check(extra_rings==0,"unselected worksites do not retain white rings")
	var before=game.learning.data.actions
	game.frontier.data.progress.meadow=6;game.learning.data.harvested[0]=7;world.sync_buildings(false);hud.sync_goal()
	check(hud.world_progress.wetland.count.text=="7/8","locked terrain shows the actual cumulative unlock requirement")
	game.select_site("wetland")
	check(game.frontier.data.active=="cottage" and game.learning.data.actions==before,"previewing locked terrain cannot switch or advance construction")
	game.explore();world.desired_rotation=Quaternion(world.markers.cottage.position.normalized(),-Vector3.UP)
	await create_timer(.8).timeout
	check(not hud.world_progress.cottage.panel.visible,"far-side progress is hidden behind the planet")
	game.settings();check(not hud.world_progress.cottage.panel.visible,"floating labels never cover a modal")
	print("WORLD_PROGRESS_RESULT ",passed," passed / ",failed," failed")
	game.closing=true;game.ambience.shutdown();game.speech.stop();game.speech.stream=null;await create_timer(.10).timeout
	game.queue_free();await process_frame;await process_frame
	quit(0 if failed==0 else 1)
