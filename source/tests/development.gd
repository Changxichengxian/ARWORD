extends SceneTree
var passed=0
var failed=0
func check(ok:bool,label:String):
	if ok:passed+=1;print("PASS ",label)
	else:failed+=1;push_error("FAIL "+label)
func _initialize():call_deferred("run")
func run():
	var game=load("res://main.tscn").instantiate();root.add_child(game)
	await create_timer(.5).timeout
	check(game.exploring and not game.hud.card.visible and game.hud.clock_label.visible,"opening the app leaves an unobstructed planet and clock")
	game.select_site(game.frontier.data.active)
	await create_timer(.45).timeout
	check(game.hud.card.visible and not game.exploring,"tapping the selected place opens learning without a return button")
	check(game.world_area(Vector2(4,game.hud.card.position.y+80)) and game.world_area(Vector2(200,game.hud.size.y-8)),"card side and bottom margins count as outside the learning panel")
	var before_words=JSON.stringify(game.learning.data.words);var before_practice=JSON.stringify(game.learning.data.practice)
	var before=game.learning.data.actions;var before_harvest=game.learning.data.harvested[0]
	game.skip_learning();game.skip_learning()
	check(game.learning.data.actions==before+1 and game.learning.data.dev_steps==1,"developer skip advances once even on a double click")
	check(game.learning.data.harvested[0]==before_harvest+1 and game.world.worker.work_left>10,"developer skip performs real harvesting and a work animation")
	check(JSON.stringify(game.learning.data.words)==before_words and JSON.stringify(game.learning.data.practice)==before_practice,"skip never invents learned words or completed reading")
	var near_zoom=game.camera.size
	game.tap_world(Vector2(40,350));check(game.exploring and not game.hud.card_open and game.hud.card.visible,"tapping outside begins a visible card transition while work continues")
	check(abs(game.camera.size-near_zoom)<.05,"dismissing a card never teleports the camera to a distant overview")
	await create_timer(.45).timeout
	check(not game.hud.card.visible and game.camera.size<=near_zoom*1.15,"the card finishes sliding out and the camera pulls back only slightly")
	await create_timer(1.5).timeout
	check(not game.hud.card.visible,"a pending next task cannot reopen a dismissed card")
	game.learning.data.practice_modes.read=true
	game.select_site(game.frontier.data.active);game.skip_learning()
	await create_timer(1.5).timeout
	check(game.mode=="read","developer privilege can reach contextual work without answering vocabulary")
	game.skip_learning();await create_timer(1.5).timeout
	check(game.learning.data.dev_context.read==1 and game.learning.data.practice.read==0,"skipped reading is tracked separately from study")
	var reloaded=IslandLearning.new();check(reloaded.accept_save(JSON.parse_string(JSON.stringify(game.learning.data))),"developer changes retain a valid normal save")
	var frontier=IslandFrontier.new(reloaded)
	check(frontier.data.progress.grove==3 and reloaded.data.dev_steps==3,"developer construction survives normal save serialization")
	reloaded.data.dev_context={"read":6,"listen":6};frontier.data.progress.plateau=10;frontier.data.progress.hill=6;frontier.data.progress.crystal=8
	check(frontier.available("mountain") and reloaded.data.practice.read==0,"developer progress opens terrain without faking learning statistics")
	game.learning.data.dev_skip=false;before=game.learning.data.actions;game.skip_learning()
	check(game.learning.data.actions==before,"disabled privilege cannot bypass an exercise")
	while game.introducing():game.introduce_word(game.current.id)
	game.reveal();game.settings();game.toggle_developer();game.hud.close()
	check(game.help_visible and game.hud.screen=="help" and game.hud.answers.is_empty(),"changing developer privilege preserves the active explanation and retry action")
	game.retry();check(not game.help_visible and game.hud.answers.size()==4,"a hinted word remains answerable after changing the developer switch")
	game.learning.data.speech=true;game.settings();game.toggle_developer();await process_frame;await process_frame
	check(not game.speech.playing,"deferred auto-pronunciation cannot play behind settings")
	game.mouse_drag=true
	var release=InputEventMouseButton.new();release.button_index=MOUSE_BUTTON_LEFT;release.pressed=false;release.position=Vector2(200,350);game._input(release)
	check(not game.mouse_drag,"releasing a drag over settings cannot leave the planet attached to the mouse")
	game.hud.close();game.learning.data.speech=false
	for c in IslandFrontier.CHAPTERS:game.frontier.data.progress[c.id]=c.need
	game.world.sync_buildings(false)
	check(game.world.road_segments<=22 and game.world.road_segments<game.world.land.size()/2,"short facility approaches remain sparse across all three islands")
	var forbidden=false
	for label in game.hud.find_children("*","Label",true,false):
		if label.text.contains("青芽星") or label.text.contains("美术预览"):forbidden=true
	for button in game.hud.find_children("*","Button",true,false):
		if button.text.contains("继续照料"):forbidden=true
	check(not forbidden,"removed names and return prompts are absent from the game interface")
	print("DEVELOPMENT_RESULT ",passed," passed / ",failed," failed")
	game.closing=true;game.ambience.shutdown();game.speech.stop();game.speech.stream=null;await create_timer(.10).timeout
	game.queue_free();await process_frame;await process_frame
	quit(0 if failed==0 else 1)
