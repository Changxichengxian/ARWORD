extends SceneTree
var passed=0
var failed=0
var game
func check(value:bool,label:String):
	if value:passed+=1;print("PASS ",label)
	else:failed+=1;push_error("FAIL "+label)
func _initialize():call_deferred("run")
func settle():
	for i in range(4):await process_frame
func fits()->bool:
	var rect=game.hud.card.get_global_rect()
	return rect.position.y>=300 and rect.end.y<=game.hud.size.y+1 and rect.end.x<=game.hud.size.x+1 and game.hud.sites.get_global_rect().end.y<=rect.position.y
func set_mode(mode:String,note=0):
	for c in IslandFrontier.CHAPTERS:game.frontier.data.progress[c.id]=c.need
	var id=IslandFrontier.BUILD_IDS[note/4] if note<12 else IslandFrontier.CHAPTERS[[0,2,4,3,5][note-12]].id
	game.frontier.choose(id)
	game.frontier.data.turns[id]=(note%4)*6+IslandLearning.MODES.find(mode) if note<12 else IslandLearning.MODES.find(mode)
	game.next_task()
func run():
	game=load("res://main.tscn").instantiate();root.add_child(game);await settle()
	check(game.qa,"save isolation")
	check(ProjectSettings.get_setting("display/window/handheld/orientation")==1,"portrait app orientation")
	check(game.learning.bank.size()==96 and game.notes.size()==12 and game.frontier_notes.size()==5,"96 curated words and 17 contextual work notes")
	var m=IslandLearning.new();m.rng.seed=1
	m.data.words["retain"]={"seen":1,"correct":0,"strength":0,"last":1,"due":2,"helped":1}
	check(m.next_word(1000).id=="retain","due review precedes unseen word")
	check(m.next_word(1000).id!="retain","immediate repeats are avoided")
	m.mark_help("repair");m.data.context_help.work00_read=true
	var restarted=IslandLearning.new();restarted.accept_save(JSON.parse_string(JSON.stringify(m.data)))
	check(restarted.next_word(1000).id=="repair" and restarted.data.context_help.work00_read,"unfinished word and context help survive restart")
	m.data.help_pending="";m.record("retain",false,1000)
	check(m.data.words.retain.strength==1 and m.data.words.retain.due==1120,"first independent recall returns after two minutes")
	m.record("retain",false,1001);check(m.data.words.retain.strength==1,"instant repetition does not inflate memory strength")
	m.record("retain",false,1300);check(m.data.words.retain.strength==2 and m.data.words.retain.due==1900,"second spaced recall returns after ten minutes")
	m.mark_help("retain");m.record("retain",false,2000)
	check(m.data.words.retain.strength==0 and m.data.words.retain.due==2120,"help stays recorded and returns sooner")
	var word_count=m.data.words.size();var harvest_before=m.data.harvested.duplicate();m.finish_context("read","work00",true)
	check(m.data.practice.read==1 and m.data.contexts.work00_read.assisted==1 and m.data.words.size()==word_count,"reading assistance is tracked without inventing word mastery")
	check(m.data.harvested==harvest_before,"reading and listening do not silently remove unharvested resources")
	m.data.band=1;m.data.success_run=0
	for i in range(4):m.record("adapt",false,3000+i*200)
	check(m.data.band==2,"sustained independent recall raises difficulty")
	m.data.miss_run=0;m.record("repair",true,5000);m.record("repair",true,5200)
	check(m.data.band==1,"repeated help lowers difficulty")
	var n=IslandLearning.new();n.select_site(2);n.advance()
	check(n.data.build==[0,0,1] and n.data.active==2,"player chooses work site and stays there")
	var actual=[]
	n=IslandLearning.new()
	for i in range(6):actual.append(n.mode());n.advance()
	check(actual==["word","word","read","word","listen","sentence"],"reading listening and sentence work occur in the main loop")
	n=IslandLearning.new()
	for site in range(3):
		n.select_site(site)
		for i in range(IslandLearning.NEEDS[site]+36):n.advance()
	check(n.data.actions==144 and n.data.build==[8,12,16] and n.data.development==[36,36,36] and n.all_done(),"144 actions finish three buildings and nine additions")
	n.advance();check(n.data.development==[36,36,36],"finished milestones never expand endlessly")
	var old={"version":4,"build":[8,12,16],"active":2,"actions":36,"band":2,"words":m.data.words,"flags":{"water":true},"bookmarks":{"retain":true}}
	var restored=IslandLearning.new()
	check(restored.accept_save(JSON.parse_string(JSON.stringify(old))) and restored.data.build==[8,12,16] and restored.data.development==[0,0,0] and restored.data.words.retain.strength==m.data.words.retain.strength and restored.data.bookmarks.retain,"0.4 save preserves buildings words and bookmarks with new optional progress")
	check(not restored.accept_save({"version":4,"build":["bad",0,0]}),"malformed save is rejected")
	var f=IslandFrontier.new(IslandLearning.new())
	check(f.cells().size()==3 and f.available("grove") and f.available("quarry") and not f.available("sawmill"),"small starting shore has two expansion choices and gated new capability")
	f.advance();check(f.cells().size()==3,"one recall shows progress without adding an entire biome")
	f.advance();check(f.cells().size()==4,"two work actions create a visible new land tile")
	f.learning.data.harvested=[100,100];f.learning.data.practice.read=100
	for c in IslandFrontier.CHAPTERS:
		check(f.available(c.id),"expansion dependencies can be reached: "+c.id)
		f.choose(c.id)
		for i in range(c.need):f.advance()
	check(f.cells().size()==33 and f.finished_count()==10,"ten bounded chapters grow three starting tiles into thirty-three")
	var fixed=f.cells().size();f.advance();check(f.cells().size()==fixed,"completed land never creates endless new requirements")
	var retained=IslandLearning.new();retained.accept_save(JSON.parse_string(JSON.stringify(f.learning.data)));var ff=IslandFrontier.new(retained)
	check(ff.cells().size()==33 and ff.data.active==f.data.active,"expanded land and selected worksite survive save reload")
	check(not game.hud.sites.visible and game.hud.site_buttons.is_empty(),"fixed three-building navigation is absent")
	var before=game.learning.data.actions;game.current=game.learning.by_id.retain;game.order=[0,1,2,3];game.hud.show_task();game.answer(game.current.correct);game.answer(game.current.correct)
	check(game.learning.data.actions==before+1,"double tap cannot collect twice")
	check(game.world.effects.size()>=5 and not game.hud.overlay.visible,"recall moves actual 3D material without reward dialog")
	await create_timer(1.45).timeout
	before=game.learning.data.actions;game.answer((int(game.current.correct)+1)%4)
	check(game.help_visible and game.learning.data.actions==before,"wrong meaning teaches without false collection")
	var id=game.current.id;game.retry();game.answer(game.current.correct)
	check(game.learning.data.actions==before+1 and game.learning.data.words[id].strength==0,"assisted recall builds without counting independent mastery")
	await create_timer(1.45).timeout
	check(game.mode=="read","two recalls lead directly into a reading task")
	var compact_land=game.world.land.size()==4
	for anchor in game.world.land.values():
		for mesh in anchor.get_children():
			if mesh is MeshInstance3D and mesh.get_aabb().size.length()>5:compact_land=false
	check(compact_land,"new land stays tile-sized after its spring appearance animation")
	before=game.learning.data.actions;game.answer(game.mission.correct);check(game.learning.data.actions==before+1 and game.learning.data.practice.read==1,"reading decision directly advances selected project")
	await create_timer(1.45).timeout
	set_mode("listen");game.answer((int(game.mission.cue_correct)+1)%3)
	check(game.context_assisted and not game.hud.overlay.visible,"listening error reveals original instruction in place")
	game.answer(game.mission.cue_correct);check(game.learning.data.practice.listen==1 and game.learning.data.contexts.work00_listen.assisted==1,"listening progress retains assistance")
	await create_timer(1.45).timeout
	set_mode("sentence",8);var tile_order=game.sentence_order.duplicate();game.select_word(0)
	check(game.sentence_order==tile_order,"sentence tiles retain their positions")
	while game.sentence_chosen.size()<game.sentence_words.size():game.select_word(game.sentence_chosen.size())
	var complete_phrase=false
	for label in game.hud.body.find_children("*","Label",true,false):
		if label.text==" ".join(game.sentence_words) and label.visible:complete_phrase=true
	check(complete_phrase,"the final chosen word is visible in the completed sentence")
	check(game.learning.data.flags.get("water",false) and game.learning.data.practice.sentence==1,"organizing garden instruction unlocks water route")
	await create_timer(1.45).timeout
	game.journal();game.lookup("the");game.back();check(game.hud.screen=="journal","native back restores reading after lookup")
	game.hud.close();game.explore();check(not game.hud.card.visible and not game.hud.sites.visible,"world view hides learning controls")
	game.settings();check(not game.restore_button.visible,"world return button cannot cover modal")
	game.hud.close();game.resume_collect();check(game.hud.card.visible and not game.exploring,"return restores continuous work")
	var world=game.world;world.recenter();world.drag(Vector2(80,0));var horizontal=world.desired_rotation;world.recenter();world.drag(Vector2(0,80));var vertical=world.desired_rotation
	check(not horizontal.is_equal_approx(Quaternion.IDENTITY) and not vertical.is_equal_approx(Quaternion.IDENTITY) and not horizontal.is_equal_approx(vertical),"horizontal and vertical drags rotate distinct camera axes")
	var normal=game.camera.global_position.normalized()*world.RADIUS
	world.desired_rotation=Quaternion.IDENTITY;world.drag(Vector2(15,0))
	check((world.desired_rotation*normal-normal).dot(game.camera.global_basis.x)>0,"right swipe moves the grabbed surface right")
	world.desired_rotation=Quaternion.IDENTITY;world.drag(Vector2(0,15))
	check((world.desired_rotation*normal-normal).dot(-game.camera.global_basis.y)>0,"down swipe moves the grabbed surface down")
	world.recenter()
	await create_timer(.3).timeout
	var radial=true
	for cloud in world.clouds:
		if cloud.get_parent()!=world.globe or cloud.basis.y.normalized().dot(cloud.position.normalized())<.999:radial=false
	check(radial,"cloud bases face planet center and inherit planet rotation")
	var tangent=Vector3(cos(world.time*.018),0,-sin(world.time*.018))
	check((-world.boat.basis.z.normalized()).dot(tangent)>.999,"boat points along its orbit")
	var limbs_ok=true
	for limb in ["ArmL","ArmR","LegL","LegR"]:
		if not is_instance_valid(world.limbs.get(limb)):limbs_ok=false
	check(limbs_ok,"simple hero has four independent animated limb pivots")
	world.swing=.6;await create_timer(.12).timeout
	check(abs(world.limbs.ArmR.rotation.x)>.05,"harvesting animates the hero arm")
	var test_node=Node3D.new();world.add_child(test_node);world.pop(test_node);await create_timer(.32).timeout
	check(test_node.scale.x>1.0,"appearance animation overshoots for springiness")
	await create_timer(.3).timeout;check(test_node.scale.is_equal_approx(Vector3.ONE),"appearance animation settles at intended scale");test_node.queue_free()
	game.learning.data.build=[8,12,16];game.learning.data.development=[12,24,36];world.sync_buildings(false)
	var visible_count=0
	for extras in world.additions:
		for extra in extras:if extra.visible:visible_count+=1
	check(visible_count==6,"each completed 12-action stage reveals one specific addition")
	check(is_instance_valid(world.limbs.ElbowR) and is_instance_valid(world.limbs.KneeL) and world.tools.size()==3,"hero has elbow and knee articulation and three real tools")
	var idle_actions=game.learning.data.actions;world.worker.work_left=0;world.worker.settle();await create_timer(.2).timeout
	check(game.learning.data.actions==idle_actions and not world.tools.Axe.visible and not world.tools.Mallet.visible,"resting worker puts tools away without earning construction progress")
	game.frontier.choose("cottage");world.sync_buildings(false);world.recenter();world.globe.quaternion=world.desired_rotation
	var projected=game.camera.unproject_position(world.markers.cottage.global_position)
	check(world.site_at(projected)=="cottage","touching a projected building selects its world worksite")
	game.frontier.data.progress.sawmill=8;game.frontier.data.progress.grove=6;game.frontier.data.progress.quarry=6
	world.sync_buildings(false)
	var saw_point=game.camera.unproject_position(world.markers.sawmill.global_position)
	check(world.site_at(saw_point)=="sawmill","finished facilities remain selectable without an upgrade ring")
	var connected=true
	for c in IslandFrontier.CHAPTERS:
		for cell in c.cells:
			if world.land.has(cell):
				var destination=IslandFrontier.point(cell);var path=world.walking_route(Vector2.ZERO,destination);var last=Vector2.ZERO
				if path.is_empty() or not path[-1].is_equal_approx(destination):connected=false
				for waypoint in path:
					if waypoint.distance_to(last)>sqrt(3.0)*IslandFrontier.HEX+.01:connected=false
					last=waypoint
	check(connected,"worker routes follow connected land")
	var original_zoom=game.camera.size
	for i in range(2):
		var press=InputEventScreenTouch.new();press.index=i;press.position=Vector2(200+i*100,270);press.pressed=true;game._unhandled_input(press)
	var pinch=InputEventScreenDrag.new();pinch.index=1;pinch.position=Vector2(350,270);pinch.relative=Vector2(50,0);game._unhandled_input(pinch)
	check(game.camera.size<original_zoom,"spreading two fingers zooms toward the island")
	for i in range(2):
		var release=InputEventScreenTouch.new();release.index=i;release.position=Vector2(200+i*100,950);release.pressed=false;game._input(release)
	check(game.touch_points.is_empty() and game.drag_id==-1,"releasing over a learning card cannot leave a stuck world gesture")
	game.camera.size=original_zoom
	root.size=Vector2i(540,960);await settle();game.help_visible=false;game.mode="word";game.order=[0,1,2,3]
	var all_fit=true;var help_fit=true
	for q in game.learning.bank:
		game.current=q;game.hud.show_task();await settle()
		if not fits():all_fit=false;print("WORD_OVERFLOW ",q.id," ",game.hud.card.get_global_rect())
		game.hud.show_help();await settle()
		if not fits():help_fit=false;print("HELP_OVERFLOW ",q.id," ",game.hud.card.get_global_rect())
	check(all_fit,"all 96 word cards fit compact portrait screen")
	check(help_fit,"all 96 explanations fit compact portrait screen")
	var context_fit=true
	for i in range(17):
		for mode in ["read","listen","sentence"]:
			set_mode(mode,i)
			for assisted in [false,true]:
				game.context_assisted=assisted;game.sentence_hint=game.mission.sentence if assisted else ""
				for short in [false,true]:
					game.short_reading=short;game.hud.show_task();await settle()
					if not fits():context_fit=false;print("CONTEXT_OVERFLOW ",i," ",mode," ",assisted," ",game.hud.card.get_global_rect())
	check(context_fit,"all short full and assisted context cards fit compact portrait screen")
	game.settings();await settle();var panel=game.hud.overlay.get_child(game.hud.overlay.get_child_count()-1).get_child(0)
	check(panel.get_global_rect().end.y<=game.hud.size.y and panel.get_global_rect().end.x<=game.hud.size.x,"settings fit compact portrait screen")
	game.lookup("photosynthesis");await settle();panel=game.hud.overlay.get_child(game.hud.overlay.get_child_count()-1).get_child(0)
	check(panel.get_global_rect().end.y<=game.hud.size.y and panel.get_global_rect().end.x<=game.hud.size.x,"dictionary modal fits compact portrait screen")
	print("CORE_RESULT ",passed," passed / ",failed," failed")
	game.queue_free();await process_frame;quit(1 if failed else 0)
