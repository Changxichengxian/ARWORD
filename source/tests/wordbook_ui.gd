extends SceneTree
var game
var passed=0
var failed=0
var output=""
func _initialize():call_deferred("run")
func check(ok:bool,label:String):
	if ok:passed+=1;print("PASS ",label)
	else:failed+=1;push_error("FAIL "+label)
func settle():
	for i in range(4):await process_frame
func snap(label:String):
	if output.is_empty() or DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(label+".png"))
func modal_fits()->bool:
	var good=true
	for control in game.hud.overlay.find_children("*","Control",true,false):
		if control is Button or control is Label:
			var rect=control.get_global_rect()
			if rect.position.x<0 or rect.position.y<0 or rect.end.x>game.hud.size.x+1 or rect.end.y>game.hud.size.y+1:good=false
	return good
func card_fits()->bool:
	var rect=game.hud.card.get_global_rect()
	return rect.position.y>=300 and rect.end.y<=game.hud.size.y-10 and rect.end.x<=game.hud.size.x+1
func run():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--visual-out="):output=arg.trim_prefix("--visual-out=")
	if not output.is_empty():DirAccess.make_dir_recursive_absolute(output)
	game=load("res://main.tscn").instantiate();root.add_child(game)
	await create_timer(.5).timeout
	game.settings();await settle();check(modal_fits(),"settings remain inside portrait screen with wordbook and development entries");await snap("settings")
	game.show_wordbooks();await settle();check(modal_fits(),"all six books and their counts fit without scrolling");await snap("wordbooks")
	game.choose_wordbook("cet6");check(game.learning.data.book_id=="cet6" and not game.hud.overlay.visible,"choosing a book updates and closes the native panel")
	game.select_site(game.frontier.data.active);await create_timer(.4).timeout
	var entries=game.learning.wordbooks.entries.values();var candidates=[]
	entries.sort_custom(func(a,b):return game.font.get_string_size(a.word,HORIZONTAL_ALIGNMENT_LEFT,-1,34).x>game.font.get_string_size(b.word,HORIZONTAL_ALIGNMENT_LEFT,-1,34).x)
	for q in entries.slice(0,8):candidates.append(q)
	entries.sort_custom(func(a,b):return JSON.stringify(a.options).length()>JSON.stringify(b.options).length())
	for q in entries.slice(0,8):candidates.append(q)
	var fit=true;var text_fit=true
	for q in candidates:
		game.current=q;game.mode="word";game.order=[0,1,2,3];game.help_visible=false;game.hud.show_task();await settle()
		if not card_fits():fit=false;print("CARD_OVERFLOW ",q.word," ",game.hud.card.get_global_rect())
		for answer in game.hud.answers:
			if answer.get_minimum_size().x>answer.size.x+1:text_fit=false
		game.hud.show_help();await settle()
		if not card_fits():fit=false;print("HELP_OVERFLOW ",q.word," ",game.hud.card.get_global_rect())
	check(fit and text_fit,"longest book words and largest option sets fit in study and hint cards")
	game.current=game.learning.by_id["temporary"];game.hud.show_task();await settle();await snap("study")
	game.show_developer();await settle();check(modal_fits(),"fast completion controls fit in their own short panel");await snap("developer")
	var words=JSON.stringify(game.learning.data.words);var practice=JSON.stringify(game.learning.data.practice)
	game.learning.data.dev_skip=false;var before=game.frontier.finished_units();game.fast_forward(true)
	check(game.frontier.finished_units()==before,"disabled developer privilege blocks full completion")
	game.learning.data.dev_skip=true;game.fast_forward(true);await create_timer(1.0).timeout
	check(game.world.land.size()==57 and game.frontier.finished_units()==game.frontier.content_units() and game.exploring,"full completion visibly expands all land and returns to world view")
	check(JSON.stringify(game.learning.data.words)==words and JSON.stringify(game.learning.data.practice)==practice,"native completion control preserves actual study records")
	await snap("completed-world")
	game.space_settings();await settle();check(modal_fits(),"sky controls and randomize button fit the screen");await snap("sky-settings")
	var settings=game.learning.data.space_settings.duplicate();var seed=game.cosmos.sky_seed;game.cosmos.randomize_sky()
	check(seed!=game.cosmos.sky_seed and settings==game.learning.data.space_settings,"new sky varies the scene without resetting saved slider choices")
	print("WORDBOOK_UI_RESULT ",passed," passed / ",failed," failed")
	game.closing=true;game.ambience.shutdown();game.speech.stop();game.speech.stream=null;await create_timer(.1).timeout
	game.queue_free();await process_frame;await process_frame;quit(0 if failed==0 else 1)
