extends SceneTree
var passed=0
var failed=0
func check(value:bool,label:String):
	if value:passed+=1;print("PASS ",label)
	else:failed+=1;push_error("FAIL "+label)
func _initialize():
	if not "--qa" in OS.get_cmdline_user_args():push_error("QA_REQUIRED: rest_terrain");quit(2);return
	call_deferred("run")
func run():
	var memory=IslandLearning.new();var frontier=IslandFrontier.new(memory)
	frontier.data.progress.meadow=6
	var unlocked_land=frontier.cells().duplicate()
	check(frontier.previewable("wetland") and not frontier.available("wetland"),"new terrain appears as a preview before enough work has accumulated")
	memory.data.harvested[0]=7;check(not frontier.available("wetland"),"seven wood collections cannot unlock an eight-collection bay")
	memory.data.harvested[0]=8;check(frontier.available("wetland") and frontier.cells()==unlocked_land,"unlock permits expansion without granting unearned land")
	frontier.data.progress.quarry=6;memory.data.harvested[1]=10
	check(frontier.available("plateau"),"stone work opens the plateau")
	for dependency in frontier.chapter("mountain").requires:
		frontier.data.progress[dependency]=frontier.chapter(dependency).need
	memory.data.practice.read=6;memory.data.practice.listen=5
	check(not frontier.available("mountain"),"mountain requires the full reading and listening milestone")
	memory.data.practice.listen=6;check(frontier.available("mountain"),"reading plus listening opens mountain exploration")
	var restored=IslandLearning.new();restored.accept_save(JSON.parse_string(JSON.stringify(memory.data)));var reloaded=IslandFrontier.new(restored)
	check(reloaded.available("mountain") and reloaded.available("wetland"),"cumulative terrain access survives a save reload")
	var terrain=IslandTerrain.new();var plateau=IslandFrontier.point(Vector2i(4,-2));var peak=IslandFrontier.point(Vector2i(2,-3))
	check(terrain.height_at(peak)>terrain.height_at(plateau) and terrain.height_at(plateau)>1.7,"mountain and plateau have different real elevations")
	check(abs(terrain.height_at(plateau)-terrain.height_at(plateau+Vector2(.2,.1)))<.001,"plateau has a usable flat summit")
	check(terrain.coordinates(terrain.point(peak)).distance_to(peak)<.001,"walking coordinates remain correct on elevated terrain")
	var game=load("res://main.tscn").instantiate();root.add_child(game)
	await create_timer(1.5).timeout
	var worker=game.world.worker;var before=JSON.stringify(game.learning.data)
	if game.world.move_tween and game.world.move_tween.is_valid():game.world.move_tween.kill()
	worker.work_left=0;worker.rest_variant=1;worker.rest_time=1
	await create_timer(.8).timeout
	check(abs(game.world.actor.rotation.x-PI/2)<.05 and not worker.carry.visible,"idle character can lie down without tools or cargo")
	check(JSON.stringify(game.learning.data)==before,"resting animations do not change learning or world progress")
	worker.grant("word",Vector2.ZERO,game.world.selected_entry,0)
	check(worker.work_left>=11.9,"one successful word grants a substantial work period")
	game.next_task();check(worker.work_left>=11.8,"moving to the next exercise does not cancel earned work")
	await create_timer(.8).timeout
	check(worker.work_left>10 and game.world.tools.Axe.visible,"character wakes and resumes work")
	for i in range(8):worker.grant("word",Vector2.ZERO,game.world.selected_entry,0)
	check(worker.work_left==36,"rapid answers extend work without creating an endless queue")
	# The budget is only spent while working at the site.
	if game.world.move_tween and game.world.move_tween.is_valid():game.world.move_tween.kill()
	worker.waking=0;worker.work_left=.01;worker.update(.1)
	check(worker.work_left==0 and not game.world.tools.Axe.visible,"earned work ends and tools are put away")
	check(JSON.stringify(game.learning.data)==before,"visual work budget never grants extra unearned learning or land")
	print("REST_TERRAIN_RESULT ",passed," passed / ",failed," failed")
	game.closing=true;game.ambience.shutdown();game.speech.stop();game.speech.stream=null;await create_timer(.10).timeout
	game.queue_free();await process_frame;await process_frame
	quit(0 if failed==0 else 1)
