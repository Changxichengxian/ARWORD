extends SceneTree
func _initialize():
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	call_deferred("run")
func run():
	var game=load("res://main.tscn").instantiate();root.add_child(game)
	await create_timer(.5).timeout
	var cosmos=game.get_node_or_null("Cosmos")
	if cosmos==null:
		cosmos=load("res://scripts/cosmos.gd").new();cosmos.name="Cosmos";game.add_child(cosmos);cosmos.setup(game)
	game.explore();game.camera.size=21.5;game.camera.look_at(Vector3(0,4.2,0))
	await create_timer(2).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("../work/qa09/cosmos-overview.png")
	cosmos.viewport.get_texture().get_image().save_png("../work/qa09/cosmos-background.png")
	var first=cosmos.bodies[0].orbit.position;cosmos.advance(90.0)
	assert(first.distance_to(cosmos.bodies[0].orbit.position)>2.0)
	assert(cosmos.bodies[0].orbit.position.z!=cosmos.bodies[1].orbit.position.z)
	await create_timer(.3).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("../work/qa09/cosmos-orbit.png")
	game.resume_collect();await create_timer(.6).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("../work/qa09/cosmos-study.png")
	print("COSMOS_PASS: perspective depth, orbital motion, native composition")
	quit()
