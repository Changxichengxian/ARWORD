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
	for i in range(5):await process_frame
func snap(label:String):
	if output.is_empty() or DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(label+".png"))
func set_word(word:String,intro=false):
	game.hud.close();game.exploring=false;game.locked=false;game.help_visible=false;game.helped=false;game.mode="word";game.word_selected=[]
	game.learning.data.listen=false;game.learning.data.speech=false
	game.current=game.word_senses.prepare(game.learning.by_id[word]);game.order=range(game.current.options.size());game.order.shuffle()
	if intro:game.learning.data.words.erase(word)
	else:game.learning.introduce(word)
	game.hud.show_task();game.hud.set_card_open(true,false)
func mouse(at:Vector2,pressed:bool):
	var motion=InputEventMouseMotion.new();motion.position=at;motion.global_position=at;root.push_input(motion,true)
	var event=InputEventMouseButton.new();event.position=at;event.global_position=at;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;root.push_input(event,true)
func run():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--visual-out="):output=arg.trim_prefix("--visual-out=")
	game=load("res://main.tscn").instantiate();game.set_script(load("res://tests/word_details_game.gd"));root.add_child(game)
	await create_timer(.5).timeout
	var details=game.word_details
	check(details.entry(" Tradition ").common.begins_with("传统"),"normalized lookup uses reviewed main meaning")
	check(details.entry("fine").definition.contains("罚"),"short learning answer does not erase other senses")
	check(details.search(" BANK ")[0]=="bank" and details.search("").is_empty() and details.search("zzzzzzzz").is_empty(),"search handles exact words, case, whitespace and no matches")
	check(details.search("a").size()<=24 and details.search("trad").has("tradition"),"search bounds results and supports prefixes")
	check(details.sentences("tradition").size()==3,"tradition has three bilingual teaching examples")
	for word in ["industry","kid","stock"]:check(details.entry(word).common==game.learning.wordbooks.entries[word].zh,"lookup and learning share corrected meaning: "+word)
	var before=JSON.stringify(game.learning.data.words);var units=game.frontier.finished_units()
	game.spoken.clear();game.word_search_query="Tradition";game.show_word_search();await settle()
	await snap("search")
	var field=game.hud.active_box.find_child("WordSearch",true,false)
	field.text_submitted.emit(field.text);await settle()
	check(game.hud.screen=="lookup" and game.spoken==[game.word_audio("tradition")],"submitting a search opens shared detail and reads exactly once")
	check(before==JSON.stringify(game.learning.data.words) and units==game.frontier.finished_units(),"searching another word changes no mastery or work progress")
	await snap("tradition")
	game.bookmark("tradition");await settle();check(game.spoken.size()==1,"bookmarking inside detail does not autoplay again")
	game.lookup_return.call();await settle()
	check(game.hud.screen=="search" and game.word_search_query=="Tradition","detail returns to the previous query")
	set_word("tradition");await settle();game.spoken.clear()
	var button=game.hud.word_label;var at=button.get_global_rect().get_center()
	mouse(at,true);await create_timer(.12).timeout;mouse(at,false);await settle()
	check(game.spoken.size()==1 and not game.hud.overlay.visible,"short press speaks once without opening detail")
	game.spoken.clear();mouse(at,true);await create_timer(.65).timeout;mouse(at,false);await settle()
	check(game.hud.screen=="lookup" and game.spoken.size()==1,"holding opens detail and release does not replay")
	check(game.helped and game.learning.data.pending_help.has("tradition") and units==game.frontier.finished_units(),"long press counts as help without rewarding work")
	game.lookup_return.call();await settle();game.spoken.clear()
	button=game.hud.word_label;at=button.get_global_rect().get_center();mouse(at,true)
	var drag=InputEventMouseMotion.new();drag.position=at+Vector2(25,0);drag.global_position=drag.position;drag.relative=Vector2(25,0);drag.button_mask=MOUSE_BUTTON_MASK_LEFT;root.push_input(drag,true)
	await create_timer(.65).timeout;mouse(at+Vector2(25,0),false);await settle()
	check(not game.hud.overlay.visible and game.spoken.is_empty(),"drag cancels both hold and short-press playback")
	for word in game.word_senses.entries:
		set_word(word,true);await settle()
		check(game.current.options.size()==6 and game.current.correct_indices.size() in [2,3],"only reviewed senses produce six choices: "+word)
		var text="";for label in game.hud.body.find_children("*","Label",true,false):text+=label.text
		check(text.contains(game.current.options[1]),"introduction teaches more than the first sense: "+word)
		set_word(word);await settle()
		check(game.hud.word_submit.disabled,"multi-select starts with disabled submit: "+word)
		var first=game.current.correct_indices[0];game.toggle_word_answer(first);game.toggle_word_answer(first)
		check(game.word_selected.is_empty(),"choice can be deselected: "+word)
		for index in game.current.correct_indices:game.toggle_word_answer(index)
		game.toggle_word_answer(5)
		check(game.word_selected.size()==game.current.correct_indices.size() and not game.hud.word_submit.disabled,"selection limit and submit readiness: "+word)
		check(not game.word_senses.matches(game.current,[first,first]),"duplicate choices cannot pass: "+word)
		if word=="light":await snap("six-select-three")
	set_word("bank");await settle();game.toggle_word_answer(0);game.toggle_word_answer(5)
	var record=JSON.stringify(game.learning.data.words["bank"]);units=game.frontier.finished_units();game.submit_word_answers();await settle()
	check(game.help_visible and game.helped and game.frontier.finished_units()==units,"wrong multi-select shows help without granting progress")
	check(JSON.stringify(game.learning.data.words["bank"])==record,"wrong multi-select does not invent successful recall")
	game.retry();await settle();check(game.word_selected.is_empty(),"retry clears all checked choices")
	for index in game.current.correct_indices:game.toggle_word_answer(index)
	game.submit_word_answers();var action_count=game.learning.data.actions;game.submit_word_answers()
	check(game.locked and game.learning.data.words.bank.helped>0 and game.learning.data.actions==action_count,"assisted multi-select is recorded once and double submit is blocked")
	await create_timer(1.5).timeout
	set_word("light");await settle();var previous_correct=int(game.learning.data.words.light.get("correct",0));units=game.frontier.finished_units()
	for index in game.current.correct_indices:game.toggle_word_answer(index)
	game.submit_word_answers();check(game.learning.data.words.light.correct==previous_correct+1 and not game.helped,"independent multi-select records one correct recall")
	await create_timer(1.5).timeout
	set_word("tradition");await settle();check(not game.word_senses.is_multi(game.current) and game.current.options.size()==4,"synonymous translations do not become multiple answers")
	game.word_search_query="bank";game.show_word_search();game.lookup("bank");await settle()
	game.hud.apply_safe_rect(Rect2(0,24,360,616));await settle()
	check(game.hud.active_panel.get_global_rect().position.x>=0 and game.hud.active_panel.get_global_rect().end.x<=360.5,"long definition fits narrow phone width")
	check(game.hud.active_scroll.get_global_rect().end.y<=640,"detail scroll stays above the bottom safe area")
	await snap("narrow-bank")
	print("WORD_DETAILS_RESULT ",passed," passed / ",failed," failed")
	game.closing=true;game.ambience.shutdown();game.speech.stop();game.speech.stream=null;game.queue_free();await settle()
	# The dummy audio mixer drains on wall time, independently of --fixed-fps.
	var drain_until=Time.get_ticks_msec()+250
	while Time.get_ticks_msec()<drain_until:await process_frame
	quit.call_deferred(0 if failed==0 else 1)
