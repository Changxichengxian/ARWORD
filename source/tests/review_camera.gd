extends SceneTree

var game
var failed=0
var checks=0
var output="../work/camera-review-update/visual"
func _initialize():
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	DirAccess.make_dir_recursive_absolute(output);call_deferred("run")
func check(ok:bool,label:String):
	checks+=1
	if not ok:failed+=1
	print("PASS " if ok else "FAIL ",label)
func settle():
	for i in 3:await process_frame
func snap(name:String):
	if DisplayServer.get_name()=="headless":return
	await settle();await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(name+".png"))
func set_word(id:String,kind:String):
	game.task_serial+=1;game.review_feedback="";game.review_pointer=-1
	game.hud.close();game.exploring=false;game.locked=false;game.help_visible=false;game.helped=false
	game.mode="word";game.word_selected=[];game.learning.data.pending_help.clear();game.learning.data.help_pending=""
	game.learning.data.words[id]={"seen":0,"correct":0,"strength":0,"last":0,"due":0,"helped":0,"review_round":0,"review_at":0}
	game.current=game.word_review.prepare(game.word_senses.prepare(game.learning.by_id[id]),kind,game.learning.active_bank)
	game.order=range(game.current.options.size());game.order.shuffle()
	game.hud.show_task();game.hud.set_card_open(true,false)
func touch(point:Vector2,down:bool,cancel=false):
	var event=InputEventScreenTouch.new();event.index=8;event.position=point;event.pressed=down;event.canceled=cancel
	root.push_input(event,true);await settle()
func run():
	game=load("res://main.tscn").instantiate();game.set_script(load("res://tests/word_details_game.gd"));root.add_child(game)
	await create_timer(.3).timeout
	game.word_review.setup(game.learning.by_id)
	var learning=game.learning
	learning.data.review_style="mixed";learning.introduce("tradition")
	var modes=[]
	for seen in 3:
		learning.data.words.tradition.seen=seen;modes.append(learning.review_kind("tradition"))
	check(modes.has("audio") and modes.has("text") and modes.has("reverse"),"one reviewed word rotates through all three tasks")
	check(not learning.data.spelling,"spelling is opt-in")
	game.show_practice_modes();game.toggle_spelling();game.hud.close()
	var scheduled=[]
	for i in 4:
		learning.data.words.tradition.seen=i
		scheduled.append(learning.review_kind("tradition"))
	var prefs=IslandLearning.new();prefs.accept_save(JSON.parse_string(JSON.stringify(learning.data)))
	check(scheduled.count("spelling")==1 and prefs.data.spelling,"spelling is mixed in and the preference survives reload")
	set_word("right","spelling")
	check(game.hud.spelling_field!=null and game.hud.answers.is_empty() and game.current.options.is_empty(),"spelling a multi-sense word offers a text field without answer choices")
	var work_before=learning.data.actions
	game.hud.spelling_field.text_submitted.emit("  ")
	check(not game.locked,"blank spelling cannot submit")
	game.hud.spelling_field.text_submitted.emit("rite")
	check(game.review_feedback=="retry" and game.hud.word_label.text=="right" and learning.data.actions==work_before,"incorrect spelling reveals the target and grants no work")
	game.continue_word_feedback();game.hud.spelling_field.text_submitted.emit(" RIGHT ")
	check(game.review_feedback=="next" and learning.data.words.right.helped==1 and learning.data.words.right.correct==0,"correcting spelling stays assisted")
	game.continue_word_feedback();set_word("tradition","spelling")
	game.hud.spelling_field.text_submitted.emit("Tradition")
	game.submit_spelling("tradition")
	check(learning.data.words.tradition.correct==1 and learning.data.actions==work_before+2,"independent spelling works once through Enter and accepts case")
	game.continue_word_feedback();game.toggle_spelling();game.hud.close()
	var restored=IslandLearning.new();restored.accept_save(JSON.parse_string(JSON.stringify(learning.data)))
	check(restored.review_kind("tradition")==learning.review_kind("tradition"),"task rotation and learning records survive saving")
	for kind in ["audio","text","reverse"]:
		game.spoken.clear();learning.data.speech=true;set_word("tradition",kind);await settle()
		check(game.current.options.size()==4 and game.current.option_words.size()==4,"four paired choices for "+kind)
		check(game.spoken.is_empty() if kind=="reverse" else not game.spoken.is_empty(),"audio does not give away reverse task: "+kind)
		await snap("question-"+kind)
		game.answer(game.current.correct)
		if kind=="reverse":check(game.spoken==[game.current.audio],"correct reverse answer pronounces the target once")
		var seen=learning.data.words.tradition.seen;var actions=learning.data.actions
		game.answer(game.current.correct)
		check(learning.data.words.tradition.seen==seen and learning.data.actions==actions,"duplicate submission cannot count twice: "+kind)
		var labels=true
		for i in game.hud.answers.size():
			var index=game.order[i];var text=game.hud.answers[i].text
			labels=labels and text==str(game.current.option_meanings[index])+"\n"+str(game.current.option_words[index]) and not game.current.option_words[index].is_empty()
		check(labels,"each meaning reveals its corresponding English word: "+kind)
		await create_timer(1.4).timeout
		check(game.current.id=="tradition" and game.review_feedback=="next","answer waits instead of advancing on a timer: "+kind)
		await snap("answer-"+kind)
		await touch(Vector2(275,230),false)
		check(game.review_feedback=="next","old release cannot continue the feedback")
		await touch(Vector2(275,230),true);await touch(Vector2(275,230),false,true)
		check(game.review_feedback=="next","cancelled touch cannot continue the feedback")
		await touch(Vector2(275,230),true);await touch(Vector2(275,230),false)
		check(game.review_feedback.is_empty() and learning.data.words.tradition.seen==seen,"one fresh touch continues without another reward")
	game.spoken.clear();set_word("tradition","reverse");await settle()
	game.answer((int(game.current.correct)+1)%4);game.answer(game.current.correct)
	check(game.spoken==[game.current.audio],"incorrect reverse answer pronounces only the target, once")
	game.continue_word_feedback();await settle()
	check(game.spoken.size()==1,"retry leaves the reverse prompt silent")
	set_word("tradition","audio");await settle()
	var actions=learning.data.actions;var units=game.frontier.finished_units()
	game.answer((int(game.current.correct)+1)%4)
	check(game.review_feedback=="retry" and learning.data.actions==actions and game.frontier.finished_units()==units and learning.data.words.tradition.correct==0,"incorrect choice reveals pairs without claiming success or work")
	game.continue_word_feedback();game.answer(game.current.correct)
	check(learning.data.words.tradition.correct==0 and learning.data.words.tradition.helped==1,"a revealed answer stays assisted after retry")
	for id in game.word_senses.entries:
		set_word(id,"audio");await settle()
		for index in game.current.correct_indices:game.toggle_word_answer(index)
		game.submit_word_answers()
		check(game.review_feedback=="next" and game.current.option_words.size()==6 and not game.current.option_words.has(""),"reviewed multi-sense choices also reveal all six words: "+id)
	game.continue_word_feedback();game.locked=false;game.review_feedback=""
	set_word("tradition","audio");game.answer(game.current.correct);game.explore()
	check(game.review_feedback.is_empty() and not game.locked,"closing a result releases it so another site can be chosen")
	game.explore(true,false);game.set_user_zoom(3.2)
	var zoom=game.camera.size;var tilt=game.inspection_tilt
	var angle=rad_to_deg(asin((game.camera.position-Vector3.UP*IslandTerrain.RADIUS).normalized().y))
	check(absf(angle-25.)<.01,"closest manual view is ten degrees flatter")
	game.select_site("cottage");await create_timer(.5).timeout
	check(is_equal_approx(game.camera.size,zoom) and is_equal_approx(game.inspection_tilt,tilt),"selecting a site keeps the manual zoom and pitch")
	await snap("close-site")
	game.explore();await create_timer(.5).timeout
	check(is_equal_approx(game.camera.size,zoom),"closing the card also keeps the manual zoom")
	var opening=load("res://scripts/startup.gd").new();opening.game=game
	opening.pull_back(0.)
	var highest=game.camera.unproject_position(game.camera.global_basis.y*15.)
	check(highest.y>root.size.y,"entire planet starts below the frame instead of popping in")
	for step in [0.,.2,.4,.6,.8,1.]:
		opening.pull_back(step);await snap("opening-%02d"%roundi(step*100))
	opening.free()
	print("REVIEW_CAMERA_RESULT ",checks," checks / ",failed," failed")
	game.closing=true;game.ambience.shutdown();game.speech.stop();game.queue_free();await settle()
	quit.call_deferred(0 if failed==0 else 1)
