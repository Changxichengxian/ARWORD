extends SceneTree
func _initialize():call_deferred("run")
func run():
	var before=FileAccess.get_file_as_bytes("user://island4.json") if FileAccess.file_exists("user://island4.json") else PackedByteArray()
	var game=load("res://main.tscn").instantiate();root.add_child(game)
	for i in range(4):await process_frame
	assert(game.art_preview and game.qa,"Art preview must isolate saves without requiring --qa")
	assert(game.world.land.size()==33,"Preview contains the expanded island")
	game.learning.data.actions+=10;game.save_progress()
	var after=FileAccess.get_file_as_bytes("user://island4.json") if FileAccess.file_exists("user://island4.json") else PackedByteArray()
	assert(before==after,"Preview cannot modify regular progress")
	game.world.drag(Vector2(160,120));game.resume_collect()
	var target=game.world.surface(game.frontier.target(game.frontier.data.active)).normalized()
	assert((game.world.desired_rotation*target).distance_to(Vector3.UP)<.001,"Returning to study recenters the worksite")
	print("DESKTOP_PREVIEW_PASS: isolated saves, complete map, return camera")
	game.closing=true;game.ambience.shutdown();game.speech.stop();game.speech.stream=null;await create_timer(.10).timeout
	game.queue_free();await process_frame;await process_frame
	quit()
