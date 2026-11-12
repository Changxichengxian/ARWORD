extends SceneTree

var game
var passed=0
var failed=0
var output=""
func _initialize():call_deferred("run")
func check(ok:bool,label:String):
	if ok:passed+=1;print("PASS ",label)
	else:failed+=1;push_error("FAIL "+label)
func snap(label:String):
	if output.is_empty() or DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(label+".png"))
func settle():
	for i in range(3):await process_frame
func tap(button:Button):
	await settle()
	var at=button.get_global_rect().get_center()
	for down in [true,false]:
		var event=InputEventMouseButton.new();event.position=at;event.global_position=at;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;root.push_input(event,true)
	await settle()
func exercise_loading_drag():
	var point=Vector2(root.size.x*.55,root.size.y*.65)
	var press=InputEventScreenTouch.new();press.index=0;press.position=point;press.pressed=true;root.push_input(press,true)
	await process_frame
	var phase=game.startup.phase;var pending=game.startup.pending.size();var before=game.world.globe.quaternion
	var max_frame=0;var previous=Time.get_ticks_msec()
	for i in 24:
		var drag=InputEventScreenDrag.new();drag.index=0;drag.position=point+Vector2(4,-1);drag.relative=Vector2(4,-1);point=drag.position;root.push_input(drag,true)
		await process_frame
		var now=Time.get_ticks_msec();max_frame=maxi(max_frame,now-previous);previous=now
	check(game.startup.phase==phase and game.startup.pending.size()==pending,"heavy animal preparation pauses while a finger drags the planet")
	check(before.angle_to(game.world.globe.quaternion)>.10,"planet keeps following a real touch drag during animal loading")
	print("STARTUP_DRAG_MAX_FRAME_MS ",max_frame)
	var release=InputEventScreenTouch.new();release.index=0;release.position=point;release.pressed=false;root.push_input(release,true)

func run():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--visual-out="):output=arg.trim_prefix("--visual-out=")
	game=load("res://main.tscn").instantiate();game.set_script(load("res://tests/word_details_game.gd"));root.add_child(game)
	check(game.startup!=null and game.world==null and not game.scene_ready,"search exists before the world is assembled")
	check(not game.hud.search_button.disabled and not game.hud.books_button.disabled and not game.hud.settings_button.disabled,"all three toolbar entries are available during startup")
	await snap("01-first-stars")
	game.word_search_query="传统";await tap(game.hud.search_button)
	check(game.hud.screen=="search","real toolbar click opens search before the world is ready")
	check(game.word_details.search("传统").has("tradition"),"Chinese search finds tradition")
	check(game.word_details.search("银行").has("bank") and game.word_details.search("足球").has("football"),"Chinese search covers reviewed senses and dictionary meanings")
	check(game.word_details.search("不存在的测试词义").is_empty() and game.word_details.search("水",6).size()<=6,"Chinese search respects empty matches and result limit")
	var before=JSON.stringify(game.learning.data.words);var units=game.frontier.finished_units()
	game.spoken.clear();game.lookup("tradition");await settle()
	check(game.hud.screen=="lookup" and game.spoken==[game.word_audio("tradition")],"startup search opens full detail and reads once")
	await snap("02-chinese-detail")
	game.bookmark("tradition");await settle()
	check(game.spoken.size()==1 and before==JSON.stringify(game.learning.data.words) and units==game.frontier.finished_units(),"early lookup preserves mastery and work; bookmark does not replay")
	var paused_marks=JSON.stringify(game.startup.marks)
	await create_timer(.4).timeout
	check(paused_marks==JSON.stringify(game.startup.marks) and not game.startup.marks.has("geometry_ready"),"opening details pauses heavy world assembly")
	game.lookup_return.call();await settle()
	check(game.word_search_query=="传统" and game.hud.screen=="search","return preserves Chinese query")
	await snap("03-chinese-results")
	game.hud.close();await settle()
	await tap(game.hud.settings_button);check(game.hud.screen=="settings","real settings click works during loading")
	game.hud.close();await tap(game.hud.books_button);check(game.hud.screen=="wordbooks","real wordbook click works during loading")
	game.journal();check(game.hud.screen=="journal","reading can open before the first task exists")
	game.show_wordbooks();game.toggle_listen_preference();game.toggle_listen_preference()
	game.hud.close();await settle()
	await snap("04-stars-bright")
	var deadline=Time.get_ticks_msec()+60000;var captured={};var min_zoom=100.;var max_zoom=0.;var first_visible=0
	var person_frames=0;var animal_frames=0
	while not game.startup.marks.has("animals_ready") and Time.get_ticks_msec()<deadline:
		await process_frame
		if game.startup.marks.has("world_reveal") and not captured.has("first_planet"):
			captured.first_planet=true
			check(not is_instance_valid(game.startup.sky) and game.world.visible and game.world.wildlife==null and game.world.avatar==null,"planet is visible before space, character and animal preparation finishes")
			await snap("04-first-planet")
		if game.startup.phase in ["wildlife_resources","wildlife"] and not captured.has("drag"):
			captured.drag=true;await exercise_loading_drag()
		for arrival in game.startup.growing:
			var ratio=arrival.visual.scale.x/arrival.base.x
			if ratio>.03 and ratio<.98:
				if arrival.visual==game.world.avatar:person_frames+=1
				else:animal_frames+=1
		if is_instance_valid(game.camera):min_zoom=minf(min_zoom,game.camera.size);max_zoom=maxf(max_zoom,game.camera.size)
		if game.startup.camera_running and game.camera.size>16 and not captured.has("pullback"):
			captured.pullback=true;await snap("05-pullback")
		if game.startup.marks.has("person_start") and not captured.has("person"):
			captured.person=true;await snap("06-person")
		var count=0
		for visual in game.startup.arrivals:
			if is_instance_valid(visual) and visual.visible:count+=1
		if count>0 and count<game.startup.arrivals.size() and not captured.has("animals"):
			first_visible=count;captured.animals=true;await snap("07-animal-pop")
	check(game.startup.marks.has("animals_ready"),"startup completes")
	if not game.startup.marks.has("animals_ready"):quit(1);return
	var marks=game.startup.marks
	check(marks.first_draw<=marks.world_reveal and marks.world_ready<=marks.person_start and marks.person_ready<=marks.animals_start,"order is stars, world, character, then animals")
	check(min_zoom<12 and max_zoom>=25.4,"camera pulls back from the close planet to the whole scene")
	check(marks.world_reveal<marks.space_ready and marks.world_reveal<marks.phase_wildlife_resources and marks.world_reveal<marks.person_start,"space, animal loading and character loading never delay the first visible planet")
	check(marks.camera_start==marks.world_reveal and marks.camera_ready>marks.space_ready,"camera starts at planet visibility and overlaps remaining scene preparation")
	check(captured.has("drag"),"real drag was exercised during deferred animal preparation")
	check(animal_frames>=12,"animal growth remains visible across multiple rendered frames")
	if "--qa-with-cast" in OS.get_cmdline_user_args():check(person_frames>=12 and marks.person_ready-marks.person_start>=750,"character growth lasts long enough to see")
	check(first_visible>0 and first_visible<game.startup.arrivals.size(),"animals appear one at a time")
	var scales_ok=true
	for visual in game.startup.arrivals:scales_ok=scales_ok and visual.visible and visual.scale.is_equal_approx(Vector3.ONE)
	check(scales_ok,"all visual arrival scales settle exactly to their original size")
	check(game.scene_ready and not game.hud.books_button.disabled and not game.hud.settings_button.disabled,"normal world controls become available")
	if "--qa-with-cast" in OS.get_cmdline_user_args():check(is_instance_valid(game.world.avatar) and game.world.avatar.enabled and not game.world.avatar_appearing,"character finishes its pop and resumes normal motion")
	var white=false
	for mesh in game.world.builder.find_children("*","MeshInstance3D",true,false):
		if mesh.is_visible_in_tree() and not (is_instance_valid(game.world.avatar) and game.world.avatar.is_ancestor_of(mesh)):white=true
	check(not white,"hidden builder body never becomes a visible substitute")
	await snap("08-ready")
	game.hud.apply_safe_rect(Rect2(0,24,360,616));await settle()
	check(game.hud.search_button.size.x>=156 and game.hud.settings_button.get_global_rect().end.x<=360,"prominent search fits a narrow phone safe area")
	await snap("09-narrow-header")
	print("STARTUP_MARKS ",JSON.stringify(marks));print("STARTUP_RESULT ",passed," passed / ",failed," failed")
	game.closing=true
	if game.ambience:game.ambience.shutdown()
	game.speech.stop();game.speech.stream=null
	for player in game.effects:player.stop();player.stream=null
	game.queue_free();await settle()
	var drain_until=Time.get_ticks_msec()+250
	while Time.get_ticks_msec()<drain_until:await process_frame
	quit.call_deferred(0 if failed==0 else 1)
