extends SceneTree
func _initialize():call_deferred("run")
func run():
	var game=load("res://main.tscn").instantiate();root.add_child(game)
	await create_timer(.1).timeout
	var cosmos=game.get_node_or_null("Cosmos")
	if cosmos==null:
		cosmos=load("res://scripts/cosmos.gd").new();cosmos.name="Cosmos";game.add_child(cosmos);cosmos.setup(game)
	var before=cosmos.bodies[0].orbit.position;cosmos.advance(90)
	assert(before.distance_to(cosmos.bodies[0].orbit.position)>2)
	assert(cosmos.space_camera.projection==Camera3D.PROJECTION_PERSPECTIVE)
	assert(cosmos.bodies[0].orbit.position.z!=cosmos.bodies[1].orbit.position.z)
	if not "--quit-direct" in OS.get_cmdline_user_args():
		game.closing=true;game.ambience.shutdown();game.speech.stop();game.speech.stream=null;await create_timer(.10).timeout
		game.queue_free();await process_frame;await process_frame
	print("COSMOS_LOGIC_PASS")
	quit()
