extends SceneTree
var game
var count=0
var failures=0
var output=""
func _initialize():
	if not "--qa" in OS.get_cmdline_user_args():quit(2);return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--captures="):output=arg.trim_prefix("--captures=")
	call_deferred("run")
func check(ok:bool,label:String):
	count+=1
	if not ok:failures+=1
	print("PASS " if ok else "FAIL ",label)
func snap(label:String):
	if output.is_empty() or DisplayServer.get_name()=="headless":return
	DirAccess.make_dir_recursive_absolute(output)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(label+".png"))
func learning_flow():
	game.resume_collect();await create_timer(.45).timeout
	var first=game.current.id;var m=game.learning
	check(game.introducing() and game.hud.answers.is_empty(),"new word begins with its meaning")
	var buttons=game.hud.body.find_children("*","Button",true,false)
	var known_button:Button
	for button in buttons:
		if button.text=="学会":known_button=button
	check(known_button!=null and not game.hud.card_scroll.get_v_scroll_bar().visible and game.hud.card.get_global_rect().encloses(known_button.get_global_rect()),"intro offers the known path and shows the full button without scrolling")
	await snap("introduction")
	game.introduce_word(first);var second=game.current.id
	game.introduce_word(first)
	check(second!=first and m.data.word_turn==1 and m.data.actions==0 and m.book_independent()==0,"showing a word or pressing the old button twice never builds or counts recall")
	game.introduce_word(second)
	check(game.current.id==first and game.hud.answers.size()==4,"first recall follows another word")
	var restored=IslandLearning.new();restored.accept_save(JSON.parse_string(JSON.stringify(m.data)))
	check(restored.data.word_turn==2 and restored.next_word(1000.).id==first,"pending round survives JSON reload")
	game.answer((int(game.current.correct)+1)%4);game.retry();game.answer(game.current.correct)
	check(m.data.words[first].helped==1 and m.data.words[first].correct==0 and m.data.words[first].review_round==0,"a miss remains scheduled for independent recall")
	await create_timer(1.5).timeout
	check(game.current.id==second,"another card separates the retry")
	var skips=m.data.dev_steps;var turn=m.data.word_turn
	game.skip_learning();check(m.data.word_turn==turn and m.data.dev_steps==skips+1,"developer skip earns no recall")
	var gaps=[]
	for i in 60:
		var q=restored.next_word(1000.)
		if restored.needs_intro(q.id):restored.introduce(q.id)
		else:
			restored.record(q.id,false,1000.,false)
			if q.id==first:gaps.append(restored.data.word_turn)
		if gaps.size()==3:break
	check(gaps.size()==3 and gaps[1]-gaps[0]>=3 and gaps[2]-gaps[1]>=6 and restored.data.words[first].due>=87400,"three recalls widen in spacing and lead into tomorrow's queue")
	var known=IslandLearning.new()
	known.active_bank=[known.by_id[first]]
	known.introduce(first,true)
	check(known.next_word(1000.).is_empty() and known.book_independent()==0,"self-report alone earns no mastery; a lone word waits too")
	known.data.word_turn=known.data.words[first].review_at
	check(known.next_word(1000.).id==first,"first surprise check actually scheduled")
	known.record(first,false,1000.,false)
	var reloaded=IslandLearning.new()
	reloaded.accept_save(JSON.parse_string(JSON.stringify(known.data)))
	reloaded.active_bank=known.active_bank
	check(reloaded.data.words[first].spot_hits==1 and reloaded.next_word(2000.).is_empty(),"one successful spot check survives reload and cannot immediately repeat")
	reloaded.mark_help(first);reloaded.record(first,false,2000.,false)
	check(reloaded.data.words[first].spot_hits==0 and reloaded.data.words[first].correct==1,"a hinted check resets the pair")
	for i in 2:
		reloaded.data.word_turn=int(reloaded.data.words[first].review_at)
		check(reloaded.next_word(3000.).id==first,"pending spot check returns")
		reloaded.record(first,false,3000.,false)
	check(reloaded.data.words[first].mastered and reloaded.next_word(1e12).is_empty(),"two independent checks retire the word even after tomorrow or when the book is complete")
	await create_timer(1.5).timeout
func harbor_check():
	game.frontier.finish_for_development(true);var w=game.world;w.sync_buildings(false)
	check(w.piers.size()==5 and not w.transporting,"five docks exist before the first voyage")
	var docks=w.piers.duplicate()
	var sailing_path=[]
	var good=w.piers.size()==5;var bends=0
	for a in w.piers:
		var top=w.piers[a].get_meta("walkway");var deck:Vector3=top[-1]
		good=good and absf((top[-2]-deck).dot(deck.normalized()))<.015 and w.clear_ground(w.piers[a].get_meta("landing"))
		for b in w.piers:
			if b<=a:continue
			var path=w.sea_routes.sea_path(w.sea_routes.port(a),w.sea_routes.port(b))
			good=good and path.size()>=2
			if path.size()>2:bends+=1;sailing_path=path
			for i in range(1,path.size()):good=good and w.sea_routes.clear_arc(path[i-1],path[i])
	check(good and bends>0,"level outer jetties and curved clear-water routes between every pair")
	if not sailing_path.is_empty():
		w.set_ferry_pose(sailing_path[0],sailing_path[1],false)
		w.ferry_tween=w.create_tween();w.ferry_tween.pause()
		w.append_sailing(sailing_path,false)
		var prior=w.ferry.position;var speeds=[]
		for frame in 1800:
			var running=w.ferry_tween.custom_step(1./60.)
			speeds.append(prior.distance_to(w.ferry.position)*60.);prior=w.ferry.position
			if not running:break
		var peak=speeds.max()
		check(speeds.size()>100 and speeds[0]<peak*.05 and speeds[30]>speeds[5] and speeds[-1]<peak*.05 and speeds[-30]>speeds[-5],"ship accelerates off the berth and slows into the next, on the actual sailing tween")
	w.sync_buildings(false)
	check(w.piers==docks,"refresh and site selection retain the same dock nodes")
	var p=game.frontier.target("wetland")
	var feet=true
	for i in 25:
		var xy=p+Vector2.from_angle(i*TAU/25.)*.85
		w.place(w.builder,xy)
		feet=feet and w.builder.position.distance_to(w.ground_point(xy))<.001
	check(feet,"shallow bay walking root follows the visible terrain mesh")
	game.explore(true,false);var landing=w.piers[0].get_meta("landing")
	w.set_ferry_pose(w.sea_routes.port(0),w.surface(landing).normalized(),false)
	w.desired_rotation=Quaternion(w.surface(landing).normalized(),Vector3.UP);w.globe.quaternion=w.desired_rotation
	game.set_user_zoom(3.2)
	var axis=game.camera.global_basis.z
	check(absf(rad_to_deg(asin(axis.dot(Vector3.UP)))-35.)<.02,"closed maximum zoom looks across the ground at 35 degrees")
	await snap("pier-close")
	game.resume_collect();await create_timer(.55).timeout
	check(game.camera.position==game.HOME_CAMERA and game.inspection_tilt==0.,"opening a word card restores the original camera")
func run():
	game=load("res://main.tscn").instantiate();root.add_child(game)
	await create_timer(.45).timeout
	await learning_flow();await harbor_check()
	game.open_observatory(true);await create_timer(1.1).timeout
	var sky=game.cosmos
	var mat=sky.black_hole.material_override
	check(mat.get_shader_parameter("close_view") and sky.space_environment.glow_enabled and mat.get_shader_parameter("orbital_gas") is Texture2D,"close view renders the layered gas and its glow")
	var distance=sky.space_camera.position.distance_to(sky.CENTER)
	check(absf(distance-18.8)<.9,"inspection opens close enough for the foreground stream to extend beyond the frame")
	var old=mat.get_shader_parameter("flow_time")
	await create_timer(.25).timeout
	check(sky.black_hole.mesh is SphereMesh and mat.get_shader_parameter("flow_time")>old+.12,"a stationary camera sees time advancing inside a 3D volume")
	var position=sky.space_camera.position;sky.rotate_observation(Vector2(118,-72))
	await create_timer(.8).timeout
	check(position.distance_to(sky.space_camera.position)>3.,"dragging orbits the black hole")
	if not output.is_empty():
		sky.observation_pitch=.0;sky.observation_yaw=.0;await create_timer(.8).timeout
		sky.set_process(false)
		for i in range(45):
			mat.set_shader_parameter("flow_time",i*.12)
			await process_frame;await snap("disk-%02d"%i)
	game.close_observatory()
	check(not mat.get_shader_parameter("close_view") and not sky.space_environment.glow_enabled,"leaving inspection restores the lighter daily sky")
	print("ORBIT_REVIEW_RESULT ",count," checks / ",failures," failed")
	game.closing=true;game.queue_free();await process_frame;quit(int(failures>0))
