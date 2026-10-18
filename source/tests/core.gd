extends SceneTree
var passed=0
var failed=0
func check(value:bool,label:String):
	if value:passed+=1;print("PASS ",label)
	else:failed+=1;push_error("FAIL "+label)
func _initialize():call_deferred("run")
func run():
	var game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	check(game.qa,"save isolation")
	check(ProjectSettings.get_setting("display/window/handheld/orientation")==1,"portrait app orientation")
	check(game.learning.bank.size()==96,"96 curated words")
	var valid=true
	for q in game.learning.bank:
		if q.options.size()!=4 or q.options[q.correct]!=q.zh or q.example.is_empty() or not ResourceLoader.exists("res://assets/"+q.audio):valid=false
	check(valid,"every word has four options, a correct answer, example and audio")
	var m=IslandLearning.new();m.rng.seed=1
	m.data.words["retain"]={"seen":1,"correct":0,"strength":0,"last":1,"due":2,"helped":1}
	check(m.next_word(1000).id=="retain","due review precedes unseen word")
	check(m.next_word(1000).id!="retain","immediate repeats are avoided")
	m.mark_help("repair")
	var restarted=IslandLearning.new();restarted.accept_save(JSON.parse_string(JSON.stringify(m.data)))
	check(restarted.next_word(1000).id=="repair","unfinished helped word resumes after app restart")
	m.data.help_pending=""
	var a=m.record("retain",false,1000)
	check(m.data.words.retain.strength==1 and m.data.words.retain.due>1000,"independent recall schedules a later review")
	m.record("retain",false,1001)
	check(m.data.words.retain.strength==1,"instant repetition does not inflate memory strength")
	m.mark_help("retain");m.record("retain",false,2000)
	check(m.data.words.retain.strength==0 and m.data.words.retain.due==2120,"help stays recorded and returns sooner")
	check(m.data.build[0]==3,"assisted learning still advances construction")
	m.data.band=1;m.data.success_run=0
	for i in range(4):m.record("adapt",false,3000+i*200)
	check(m.data.band==2,"sustained independent recall raises difficulty")
	m.data.miss_run=0
	m.record("repair",true,5000);m.record("repair",true,5200)
	check(m.data.band==1,"repeated help lowers difficulty")
	var n=IslandLearning.new()
	for i in range(36):n.record("retain",false,10000+i*200);n.next_project()
	check(n.data.build==[8,12,16] and n.completed(),"three finite projects complete at 36 actions")
	n.record("retain",true,20000)
	check(n.data.build==[8,12,16],"review never degrades completed buildings")
	var restored=IslandLearning.new()
	check(restored.accept_save(JSON.parse_string(JSON.stringify(n.data))) and restored.data.build==[8,12,16],"JSON round trip preserves buildings")
	check(not restored.accept_save({"version":4,"build":["bad",0,0]}),"malformed save is rejected")
	game.current=game.learning.by_id["retain"];game.order=[0,1,2,3];game.hud.show_word()
	var before=game.learning.data.actions;game.answer(0);game.answer(0)
	check(game.learning.data.actions==before+1,"double tap cannot collect twice")
	check(game.world.effects.size()>=5,"word recall immediately moves actual 3D material")
	check(not game.hud.overlay.visible,"harvest has no reward claim dialog")
	await create_timer(.9).timeout
	before=game.learning.data.actions;game.answer(1)
	check(game.help_visible and game.learning.data.actions==before,"wrong meaning shows teaching without false collection")
	game.retry();game.answer(game.current.correct)
	check(game.learning.data.actions==before+1,"recall after help performs the same collection action")
	check(game.learning.data.words[game.current.id].strength==0,"corrected answer is not counted as independent mastery")
	await create_timer(.9).timeout
	game.learning.data.build=[8,12,16];game.world.sync_buildings();await process_frame
	var final_parts=true
	for b in game.world.buildings:
		for stage in b.find_children("Stage*","Node3D",true,false):
			if not stage.visible:final_parts=false
	check(final_parts,"completed houses have all modeled stages visible")
	var start=game.world.buildings[0].position;game.learning.data.flags.cottage_west=true;game.world.sync_buildings()
	check(game.world.buildings[0].position.distance_to(start)>.2,"understood location changes the actual building position")
	game.show_letter(2);game.letter_answer(0)
	check(game.hud.screen=="sentence","reading choice leads to an actionable sentence")
	var tile_order=game.sentence_order.duplicate();game.select_word(0)
	check(game.sentence_order==tile_order,"sentence tiles keep their positions after choosing a word")
	while game.sentence_chosen.size()<game.sentence_words.size():
		var index=game.sentence_chosen.size();game.select_word(index)
	check(game.learning.data.flags.get("water",false),"organizing the sentence connects the water route")
	game.show_letter(0);game.lookup("the");game.back()
	check(game.hud.screen=="letter","Android back returns from lookup to the letter")
	game.hud.close();game.explore();check(not game.hud.card.visible and game.exploring,"world inspection hides the learning panel")
	game.resume_collect();check(game.hud.card.visible and not game.exploring,"returning restores continuous collection")
	await process_frame
	check(game.hud.card.get_global_rect().end.y<=game.hud.size.y,"portrait card stays inside the screen")
	root.size=Vector2i(540,960);await process_frame;await process_frame
	print("COMPACT_RECTS ",game.hud.size," ",game.hud.card.get_global_rect())
	check(game.hud.card.get_global_rect().position.y>300 and game.hud.card.get_global_rect().end.y<=game.hud.size.y,"compact portrait screen leaves room for world and controls")
	var all_fit=true
	game.help_visible=false;game.order=[0,1,2,3]
	for q in game.learning.bank:
		game.current=q;game.hud.show_word();await process_frame;await process_frame;await process_frame
		if game.hud.card.get_global_rect().end.x>game.hud.size.x or game.hud.card.get_global_rect().end.y>game.hud.size.y:
			all_fit=false;print("LAYOUT_OVERFLOW ",q.id," ",game.hud.card.get_global_rect())
	check(all_fit,"all 96 word cards fit a compact portrait screen")
	var all_help_fit=true
	for q in game.learning.bank:
		game.current=q;game.hud.show_help();await process_frame;await process_frame;await process_frame
		if game.hud.card.get_global_rect().end.y>game.hud.size.y:all_help_fit=false;print("HELP_OVERFLOW ",q.id)
	check(all_help_fit,"all 96 explanations fit a compact portrait screen")
	print("CORE_RESULT ",passed," passed / ",failed," failed")
	game.queue_free();await process_frame;quit(1 if failed else 0)
