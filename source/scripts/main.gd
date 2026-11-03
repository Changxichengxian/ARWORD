extends Node3D

const SAVE="user://island4.json"
var font=preload("res://assets/fonts/FrontierSC.ttf")
var learning:IslandLearning
var frontier:IslandFrontier
var frontier_notes:Array=[]
var touch_points={}
var pinch_distance=0.0
var mouse_drag=false
var world_zoom=10.0
var world:IslandGrove
var hud:IslandHUD
var camera:Camera3D
var camera_focus=Vector3(0,10.0,0)
var camera_tween:Tween
var current:Dictionary={}
var mission:Dictionary={}
var notes:Array=[]
var dictionary={}
var mode="word"
var order:Array=[]
var locked=false
var helped=false
var help_visible=false
var context_assisted=false
var short_reading=true
var exploring=true
var cosmos
var ambience
var speech:AudioStreamPlayer
var effects:Array=[]
var sound_bank={}
var sound_index=0
var sentence_words:Array=[]
var sentence_used:Array=[]
var sentence_chosen:Array=[]
var sentence_order:Array=[]
var sentence_hint=""
var qa=false
var art_preview=false
var drag_id=-1
var drag_start=Vector2.ZERO
var drag_distance=0.0
var last_back=-1000
var lookup_return:Callable
var closing=false
var observatory_layer:CanvasLayer
var observatory_drag=false
var observatory_touch=-1
var observatory_touch_points={}
var observatory_pinch_distance=0.0
var observatory_hud_visible=true
var avatar_store
var avatar_info={}
var avatar_saved_local=false
var avatar_busy=false
var avatar_dialog:FileDialog
var avatar_picker

func _ready():
	font.fallbacks=[preload("res://assets/fonts/FrontierLatin.ttf")]
	art_preview="--art-preview" in OS.get_cmdline_user_args()
	qa="--qa" in OS.get_cmdline_user_args() or art_preview;get_tree().quit_on_go_back=false;get_tree().auto_accept_quit=false
	if OS.has_feature("windows") and DisplayServer.get_name()!="headless":
		var area=DisplayServer.screen_get_usable_rect()
		var height=mini(1100,area.size.y-100);var width=roundi(height*9.0/16)
		DisplayServer.window_set_size(Vector2i(width,height))
		DisplayServer.window_set_position(area.position+Vector2i((area.size.x-width)/2,(area.size.y-height)/2))
		get_window().title="词屿"
	learning=IslandLearning.new();read_save();frontier=IslandFrontier.new(learning)
	if art_preview:
		for c in IslandFrontier.CHAPTERS:frontier.data.progress[c.id]=c.need
		learning.data.build=[8,12,16];learning.data.development=[36,24,24];frontier.data.active="cottage"
	frontier_notes=JSON.parse_string(FileAccess.get_file_as_string("res://assets/frontier_missions.json"))
	notes=JSON.parse_string(FileAccess.get_file_as_string("res://assets/missions.json"));dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/dictionary.json"))
	world=IslandGrove.new();add_child(world);world.setup(self)
	camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.keep_aspect=Camera3D.KEEP_WIDTH;camera.size=world_zoom;camera.near=.1;camera.far=150;add_child(camera);camera.position=Vector3(0,24,21);camera.look_at(Vector3(0,10.0,0));camera.current=true
	cosmos=load("res://scripts/cosmos.gd").new();cosmos.name="Cosmos";add_child(cosmos);cosmos.setup(self)
	world.wildlife=load("res://scripts/wildlife.gd").new();world.add_child(world.wildlife);world.wildlife.setup(world)
	speech=AudioStreamPlayer.new();add_child(speech)
	ambience=load("res://scripts/ambience.gd").new();add_child(ambience);ambience.setup(self)
	for i in range(6):var p=AudioStreamPlayer.new();add_child(p);effects.append(p)
	for kind in ["chop","stone","land","build","tap","soft"]:
		var path="res://assets/audio/"+kind+".wav"
		if ResourceLoader.exists(path):sound_bank[kind]=load(path)
	var layer=CanvasLayer.new();add_child(layer);hud=IslandHUD.new();hud.game=self;layer.add_child(hud)
	next_task()
	explore(true,false)
	if art_preview:world.desired_rotation=Quaternion(Vector3.UP,Vector3(0,.85,.53).normalized())
	call_deferred("initialize_avatar")

func read_save():
	if qa:return
	for path in [SAVE,SAVE+".bak"]:
		if FileAccess.file_exists(path):
			var candidate=JSON.parse_string(FileAccess.get_file_as_string(path))
			if learning.accept_save(candidate):return
func save_progress():
	if qa:return
	var f=FileAccess.open(SAVE+".tmp",FileAccess.WRITE)
	if f==null:return
	f.store_string(JSON.stringify(learning.data));f.flush();f.close()
	if FileAccess.file_exists(SAVE):
		if FileAccess.file_exists(SAVE+".bak"):DirAccess.remove_absolute(SAVE+".bak")
		DirAccess.rename_absolute(SAVE,SAVE+".bak")
	DirAccess.rename_absolute(SAVE+".tmp",SAVE)

func context_key()->String:return str(mission.id)+"_"+mode
func next_task():
	if closing:return
	mode=frontier.mode();locked=false;help_visible=false;sentence_hint=""
	var active=str(frontier.data.active)
	if active in IslandFrontier.BUILD_IDS:
		mission=notes[frontier.site(active)*4+(int(frontier.data.turns.get(active,0))/6)%4]
	else:mission=frontier_notes[int(frontier.chapter(active).note)]
	context_assisted=learning.data.context_help.get(context_key(),false)
	short_reading=learning.data.band<2
	if mode=="word":
		current=learning.next_word(Time.get_unix_time_from_system(),mission.focus);helped=learning.data.help_pending==current.id;order=[0,1,2,3]
	else:
		current={};order=[0,1,2]
		if mode=="sentence":
			sentence_words=Array(str(mission.sentence).trim_suffix(".").split(" "));sentence_used=[];sentence_chosen=[];sentence_order=range(sentence_words.size());sentence_order.shuffle()
	order.shuffle();world.prepare_resource();hud.show_task();hud.sync_goal()
	if mode=="listen" and not exploring:call_deferred("speak_task")
func next_word():next_task()
func select_site(site):
	var id=IslandFrontier.BUILD_IDS[site] if site is int else str(site)
	if not frontier.available(id):hud.toast(frontier.unlock_hint(id));return
	if locked:
		if exploring and id==frontier.data.active:resume_collect()
		return
	if id==frontier.data.active:
		if exploring:resume_collect()
		return
	if not frontier.choose(id):return
	speech.stop();save_progress();hud.close();world.sync_buildings();next_task()
	if exploring:resume_collect()

func answer(index:int):
	if locked or help_visible or hud.overlay.visible or exploring:return
	var correct=int(current.correct) if mode=="word" else int(mission.correct if mode=="read" else mission.cue_correct)
	if index!=correct:
		if mode=="word":reveal()
		else:mark_context_help();hud.show_task()
		return
	locked=true;speech.stop();hud.feedback(index)
	if mode=="word":learning.record(current.id,helped,Time.get_unix_time_from_system(),false,world.active_kind)
	else:learning.finish_context(mode,mission.id,context_assisted,false)
	var result=frontier.study_advance()
	complete_action(result)
func skip_learning():
	if locked or exploring or hud.overlay.visible or not learning.data.dev_skip:return
	locked=true;speech.stop();learning.data.dev_steps+=1
	if mode=="word":learning.data.harvested[world.active_kind]+=1
	elif mode in ["read","listen"]:learning.data.dev_context[mode]+=1
	complete_action(frontier.advance(),false)
func complete_action(result:Dictionary,learned=true):
	if learned:learning.data.context_help.erase(context_key())
	frontier.record_delivery(world.production_route)
	save_progress();world.harvest(result);play_fx("chop" if world.active_kind==0 else "stone");hud.sync_goal()
	if result.complete:
		var id=str(frontier.data.active)
		hud.toast("船已备好 · 可以去远方的群岛" if id=="shipyard" else "点望远镜，看看远处的星云" if id=="mountain" else frontier.facility_title(id)+"做好了")
	var duration=1.35 if result.complete else 1.15
	get_tree().create_timer(duration).timeout.connect(func():
		if is_inside_tree():next_task()
	)
func mark_context_help():
	context_assisted=true;learning.data.context_help[context_key()]=true;save_progress()
func reveal():
	if locked:return
	if mode!="word":mark_context_help();hud.show_task();return
	helped=true;help_visible=true;learning.mark_help(current.id);save_progress();play_fx("soft");hud.show_help()
func retry():
	if locked:return
	help_visible=false;order.shuffle();hud.show_task()
func toggle_short():
	if locked:return
	short_reading=not short_reading;speech.stop();hud.show_task()
func toggle_listen():
	if locked:return
	if mode=="word":
		learning.data.listen=not learning.data.listen;save_progress();hud.show_help() if help_visible else hud.show_task()
	else:speak_task()
func bookmark(word=""):
	if locked:return
	var id=word if not word.is_empty() else str(current.get("id",""))
	if id.is_empty():return
	if learning.data.bookmarks.has(id):learning.data.bookmarks.erase(id)
	else:learning.data.bookmarks[id]=true
	save_progress()
	if hud.screen=="lookup":lookup(id,false)
	elif mode=="word":hud.show_help() if help_visible else hud.show_task()

func speak_word():
	if closing or current.is_empty() or exploring or hud.overlay.visible or not hud.card.visible:return
	play_speech(current.audio);hud.pulse_word()
func word_audio(word:String)->String:return str(learning.by_id[word].audio) if learning.by_id.has(word) else "audio/lookup_"+word+".mp3"
func speak_task(slow=false):
	if closing or exploring or hud.overlay.visible:return
	var suffix="cue" if mode in ["listen","sentence"] else ("short" if short_reading else "full")
	play_speech("audio/"+mission.id+"_"+suffix+".mp3",slow)
func play_speech(path:String,slow=false):
	if not ResourceLoader.exists("res://assets/"+path):return
	speech.stop();var speed=.85 if slow else 1.0;speech.pitch_scale=speed
	var bus=AudioServer.get_bus_index("Speech")
	if bus<0:
		AudioServer.add_bus();bus=AudioServer.bus_count-1;AudioServer.set_bus_name(bus,"Speech");AudioServer.add_bus_effect(bus,AudioEffectPitchShift.new())
	AudioServer.get_bus_effect(bus,0).pitch_scale=1.0/speed
	speech.bus="Speech";speech.stream=load("res://assets/"+path);speech.play()
func play_fx(kind:String):
	if not learning.data.sound or not sound_bank.has(kind):return
	var p=effects[sound_index%effects.size()];sound_index+=1;p.stream=sound_bank[kind];p.volume_db=-5;p.pitch_scale=1.0;p.play()

func select_word(index:int):
	if locked or exploring or hud.overlay.visible or sentence_used.has(index):return
	var expected=sentence_words[sentence_chosen.size()]
	if sentence_words[index]!=expected:
		mark_context_help();sentence_hint="下一处："+expected;hud.show_task();return
	sentence_hint="";sentence_used.append(index);sentence_chosen.append(sentence_words[index]);play_fx("tap")
	if sentence_chosen.size()==sentence_words.size():
		locked=true;hud.show_task()
		if int(learning.data.active)==2:learning.data.flags.water=true
		learning.finish_context("sentence",mission.id,context_assisted,false)
		complete_action(frontier.study_advance())
	else:hud.show_task()
func sentence_help():
	if locked:return
	mark_context_help();sentence_hint=mission.sentence;hud.show_task()
func sentence_reset():
	if locked:return
	sentence_used=[];sentence_chosen=[];sentence_hint="";hud.show_task()

func frame_view(focus:Vector3,zoom:float,animate=true):
	if camera_tween and camera_tween.is_valid():camera_tween.kill()
	if not animate:camera_focus=focus;camera.look_at(focus);camera.size=zoom;return
	var from_focus=camera_focus;var from_zoom=camera.size
	camera_tween=create_tween();camera_tween.tween_method(func(t):
		camera_focus=from_focus.lerp(focus,t);camera.look_at(camera_focus);camera.size=lerpf(from_zoom,zoom,t),0.0,1.0,.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
func stop_view_transition():
	if camera_tween and camera_tween.is_valid():camera_tween.kill()
func explore(wide=false,animate=true):
	if exploring and not wide and not hud.card_open:return
	exploring=true;hud.set_card_open(false,animate);hud.sites.hide();speech.stop()
	frame_view(Vector3(0,4.2,0) if wide else Vector3(0,8.8,0),25.5 if wide else minf(29,world_zoom*1.12),animate)
func resume_collect():
	exploring=false;hud.set_card_open(true);hud.sites.hide();frame_view(Vector3(0,10.0,0),world_zoom)
	world.recenter()
	if mode=="listen":speak_task()
	elif mode=="word" and (learning.data.listen or learning.data.speech):speak_word()
func recenter():world.recenter()
func world_area(p:Vector2)->bool:
	return p.y>86 and p.y<hud.size.y-4 and (not hud.card.visible or not hud.card.get_global_rect().has_point(p))
func tap_world(p:Vector2):
	var id=world.site_at(p)
	if not exploring:
		explore()
		return
	if not id.is_empty():select_site(id);return
	if world.wildlife and world.wildlife.handle_tap(p):return
	if cosmos:cosmos.handle_tap(p)
func _unhandled_input(event):
	if cosmos and cosmos.observatory_active:
		observatory_input(event);return
	if not is_instance_valid(hud) or hud.overlay.visible:return
	if event is InputEventScreenTouch:
		if event.pressed and world_area(event.position):
			touch_points[event.index]=event.position
			if touch_points.size()==1:drag_id=event.index;drag_start=event.position;drag_distance=0
			elif touch_points.size()==2:pinch_distance=touch_points.values()[0].distance_to(touch_points.values()[1]);drag_distance=100
		elif not event.pressed:
			if event.index==drag_id and drag_distance<12 and world_area(event.position):
				tap_world(event.position)
			touch_points.erase(event.index)
			if touch_points.is_empty():drag_id=-1
			else:drag_id=int(touch_points.keys()[0]);drag_distance=100
	if event is InputEventScreenDrag and touch_points.has(event.index):
		stop_view_transition()
		touch_points[event.index]=event.position
		if touch_points.size()==2:
			var distance=touch_points.values()[0].distance_to(touch_points.values()[1])
			if pinch_distance>1:camera.size=clampf(camera.size*pinch_distance/maxf(1,distance),8,29)
			if not exploring:world_zoom=camera.size
			pinch_distance=distance
		elif event.index==drag_id:drag_distance+=event.relative.length();world.drag(event.relative)
	if not OS.has_feature("android"):
		if event is InputEventMouseButton:
			if event.button_index==MOUSE_BUTTON_LEFT:
				if event.pressed and world_area(event.position):mouse_drag=true;drag_distance=0
				elif not event.pressed:
					if mouse_drag and drag_distance<12:
						tap_world(event.position)
					mouse_drag=false
			elif event.pressed and world_area(event.position) and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
				stop_view_transition()
				camera.size=clampf(camera.size*(.9 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1.1),8,29)
				if not exploring:world_zoom=camera.size
		if event is InputEventMouseMotion and mouse_drag:stop_view_transition();drag_distance+=event.relative.length();world.drag(event.relative)

func _input(event):
	# A captured sky gesture must finish even when its release lands on a toolbar button.
	if cosmos and cosmos.observatory_active and observatory_capture_input(event):
		get_viewport().set_input_as_handled();return
	# Releases over a card/modal still end a world gesture; UI may consume them later.
	if event is InputEventScreenTouch and not event.pressed and is_instance_valid(hud) and (hud.overlay.visible or not world_area(event.position)):
		touch_points.erase(event.index)
		if touch_points.is_empty():drag_id=-1
		else:drag_id=int(touch_points.keys()[0]);drag_distance=100
	if event is InputEventMouseButton and not event.pressed and is_instance_valid(hud) and (hud.overlay.visible or not world_area(event.position)):mouse_drag=false
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ESCAPE,KEY_BACK]:back();get_viewport().set_input_as_handled()
func _notification(what):
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED]:reset_observatory_input()
	if what==NOTIFICATION_WM_CLOSE_REQUEST:request_exit()
	if what==NOTIFICATION_WM_GO_BACK_REQUEST and is_instance_valid(hud):back()
	if what==NOTIFICATION_APPLICATION_PAUSED and learning!=null:
		save_progress();drag_id=-1;touch_points.clear();mouse_drag=false
		if is_instance_valid(speech):speech.stop()
		if ambience and is_instance_valid(ambience.player):ambience.player.stream_paused=true
	if what==NOTIFICATION_APPLICATION_RESUMED and ambience and is_instance_valid(ambience.player):ambience.player.stream_paused=false
func request_exit():
	if closing:return
	closing=true;save_progress()
	if ambience:ambience.shutdown()
	if is_instance_valid(speech):speech.stop();speech.stream=null
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit()
func back():
	var now=Time.get_ticks_msec()
	if now-last_back<150:return
	last_back=now;speech.stop()
	if cosmos and cosmos.observatory_active:close_observatory();return
	if hud.screen=="lookup" and lookup_return.is_valid():lookup_return.call()
	elif hud.overlay.visible:hud.close()
	elif not exploring:explore()
	else:settings()

func settings():
	if locked:return
	speech.stop();var box=hud.modal("歇一会儿");hud.screen="settings"
	hud.text(box,"独立辨认过 "+str(learning.independent_count())+" 个词",20)
	hud.text(box,"短文 "+str(learning.data.practice.read)+"  ·  听力 "+str(learning.data.practice.listen)+"  ·  组句 "+str(learning.data.practice.sentence),16)
	if not learning.wordbooks.books.is_empty():hud.button(box,"词书 · "+str(learning.current_book().get("title","选择")),show_wordbooks)
	hud.button(box,"词汇起点 · "+["基础","适中","进阶","挑战"][learning.data.band],func():learning.data.band=(learning.data.band+1)%4;learning.data.success_run=0;learning.data.miss_run=0;save_progress();settings())
	hud.button(box,"音效 · "+("开" if learning.data.sound else "关"),func():learning.data.sound=not learning.data.sound;save_progress();settings())
	hud.button(box,"轻音乐 · "+("开" if learning.data.music else "关"),func():learning.data.music=not learning.data.music;save_progress();settings())
	hud.button(box,"星空与星云",space_settings)
	hud.button(box,"人物",show_avatar_settings)
	hud.button(box,"自动读词 · "+("开" if learning.data.speech else "关"),func():learning.data.speech=not learning.data.speech;save_progress();settings())
	hud.button(box,"收藏的词",func():bookmarks(0))
	hud.button(box,"开发特权 · "+("开" if learning.data.dev_skip else "关"),show_developer)
	hud.ghost(box,"关闭",func():hud.close())
func initialize_avatar():
	var directory="user://avatars"
	if qa:
		var scope=str(Time.get_ticks_usec())
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--qa-avatar-scope="):
				var requested=argument.trim_prefix("--qa-avatar-scope=").validate_filename()
				if not requested.is_empty() and requested not in [".",".."]:scope=requested
		directory="user://qa-avatars/".path_join(scope)
	avatar_store=load("res://scripts/avatar_store.gd").new(directory)
	if OS.has_feature("android") and Engine.has_singleton("LocalAvatarPicker"):
		avatar_picker=Engine.get_singleton("LocalAvatarPicker")
		avatar_picker.connect("avatar_picked",avatar_file_selected)
		avatar_picker.connect("avatar_pick_failed",avatar_picker_failed)
		avatar_picker.connect("avatar_pick_cancelled",avatar_picker_cancelled)
	restore_avatar()
	if qa:
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--qa-avatar-import="):
				var result=import_local_avatar(argument.trim_prefix("--qa-avatar-import="))
				print("QA_AVATAR_IMPORT ",JSON.stringify(result))
func restore_avatar()->Dictionary:
	var config=avatar_store.recover();avatar_info={}
	avatar_saved_local=config.get("selected","")=="local"
	if config.get("selected","")!="local":return config
	var result=world.call("load_local_avatar",avatar_store.current_path())
	if result.get("ok",false):avatar_info=config
	elif is_instance_valid(hud):hud.toast(str(result.get("error","人物暂时无法载入，已使用白色人物")))
	return result
func show_avatar_settings():
	if locked:return
	# Keep glyphs for the locally tested model credit: 大肥鱼 · MZEM · 木子恶魔.
	speech.stop();var box=hud.modal("人物");hud.screen="avatar"
	hud.text(box,str(avatar_info.get("title","白色人物")),24)
	var author=str(avatar_info.get("author",""))
	if not author.is_empty():hud.text(box,"作者 · "+author,16,IslandHUD.GREEN)
	hud.button(box,"选择 VRM 模型",pick_avatar,true,50).disabled=avatar_busy
	hud.ghost(box,"恢复白色人物",clear_avatar,44).disabled=avatar_busy or not avatar_saved_local
	hud.ghost(box,"返回",settings,44)
func pick_avatar():
	if avatar_busy or avatar_store==null:return
	if OS.has_feature("android"):
		if avatar_picker==null:hud.toast("人物导入暂不可用");return
		avatar_busy=true;show_avatar_settings();avatar_picker.call("pick_avatar");return
	if not DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE):hud.toast("此设备暂不支持文件选择");return
	avatar_busy=true;show_avatar_settings()
	if not is_instance_valid(avatar_dialog):
		avatar_dialog=FileDialog.new();avatar_dialog.access=FileDialog.ACCESS_FILESYSTEM;avatar_dialog.file_mode=FileDialog.FILE_MODE_OPEN_FILE
		avatar_dialog.use_native_dialog=true;avatar_dialog.filters=PackedStringArray(["*.vrm;VRM 模型"])
		avatar_dialog.title="选择人物模型";add_child(avatar_dialog)
		avatar_dialog.file_selected.connect(avatar_file_selected);avatar_dialog.canceled.connect(avatar_picker_cancelled)
	avatar_dialog.popup_centered_ratio(.8)
func avatar_picker_cancelled():
	avatar_busy=false
	if hud.screen=="avatar" and hud.overlay.visible:show_avatar_settings()
func avatar_picker_failed(message:String):
	avatar_busy=false
	if hud.screen=="avatar" and hud.overlay.visible:show_avatar_settings()
	hud.toast(avatar_store.clean_label(message,100))
func avatar_file_selected(path:String):
	avatar_busy=false
	var result=import_local_avatar(path)
	if hud.screen=="avatar" and hud.overlay.visible:show_avatar_settings()
	hud.toast("人物已换好" if result.get("ok",false) else str(result.get("error","人物未能导入")))
func import_local_avatar(path:String)->Dictionary:
	if avatar_store==null or avatar_busy:return {"ok":false,"error":"人物导入正在准备"}
	avatar_busy=true
	var prepared=avatar_store.prepare(path)
	if not prepared.ok:avatar_busy=false;return prepared
	var checked=world.call("prepare_local_avatar",prepared.path)
	if not checked.get("ok",false):avatar_store.cancel();avatar_busy=false;return checked
	var installed=avatar_store.install()
	if not installed.ok:checked.candidate.free();avatar_store.cancel();avatar_busy=false;return installed
	var committed=avatar_store.confirm(checked)
	if not committed.ok:
		checked.candidate.free();avatar_store.rollback()
		avatar_busy=false;return committed
	# The candidate is fully decoded once; activation only swaps the already prepared scene.
	world.call("activate_local_avatar",checked.candidate)
	avatar_info=committed.info;avatar_saved_local=true;avatar_busy=false
	return {"ok":true,"title":avatar_info.title,"author":avatar_info.author}
func clear_avatar():
	if avatar_busy or avatar_store==null:return
	if not avatar_store.clear():hud.toast("人物设置暂时无法保存");return
	world.call("clear_local_avatar");avatar_info={};avatar_saved_local=false;show_avatar_settings()
func space_settings():
	if not exploring:explore()
	speech.stop();var box=hud.modal("星空与星云",true,false);hud.screen="space_settings"
	box.add_theme_constant_override("separation",7)
	for item in [["星云浓度","nebula"],["色彩强度","color"],["星云范围","band"],["星星密度","stars"],["漂移速度","drift"]]:hud.parameter(box,item[0],item[1],IslandLearning.SPACE_LIMITS[item[1]])
	var line=hud.row(box);hud.ghost(line,"恢复默认",reset_space_settings,42);hud.ghost(line,"换片星空",cosmos.randomize_sky,42);hud.button(line,"完成",hud.close,true,42)
func show_wordbooks():
	if locked:return
	speech.stop();var box=hud.modal("选一本词书");hud.screen="wordbooks"
	box.add_theme_constant_override("separation",8)
	for book in learning.wordbooks.books:
		var selected=book.id==learning.data.book_id;var count=book.words.size();var known=learning.book_independent(book.id)
		var label=("✓  " if selected else "")+str(book.title)+"  ·  "+str(count)+" 词"
		var excluded=int(book.get("excluded_count",0));var lower=learning.wordbooks.find(str(book.get("excluded_book","")))
		label+="\n已辨认 "+str(known)+" 词" if excluded==0 else "\n略去"+str(lower.get("title","基础"))+" "+str(excluded)+" 词 · 已辨认 "+str(known)
		var button=hud.button(box,label,choose_wordbook.bind(str(book.id)),selected,66);button.add_theme_font_size_override("font_size",17)
	var rate=frontier.study_quota();hud.text(box,"当前每小步约 "+str(rate)+" 次练习",16,IslandHUD.GREEN)
	hud.ghost(box,"关闭",hud.close)
func choose_wordbook(id:String):
	if locked or not learning.select_book(id):return
	frontier.refresh_plan();save_progress();speech.stop();hud.close();next_task();hud.sync_goal()
func set_space_parameter(key:String,value:float):
	if not IslandLearning.SPACE_LIMITS.has(key):return
	var limits=IslandLearning.SPACE_LIMITS[key];learning.data.space_settings[key]=clampf(value,limits.x,limits.y)
	cosmos.apply_settings(learning.data.space_settings)
func reset_space_settings():
	learning.data.space_settings=IslandLearning.SPACE_DEFAULTS.duplicate();cosmos.apply_settings(learning.data.space_settings);save_progress();space_settings()
func toggle_developer():
	learning.data.dev_skip=not learning.data.dev_skip;save_progress()
	if help_visible:hud.show_help()
	else:hud.show_task()
	settings()
func show_developer():
	if locked:return
	speech.stop();var box=hud.modal("开发特权");hud.screen="developer"
	hud.button(box,"跳过学习 · "+("开" if learning.data.dev_skip else "关"),func():
		learning.data.dev_skip=not learning.data.dev_skip;save_progress()
		if help_visible:hud.show_help()
		else:hud.show_task()
		show_developer())
	hud.button(box,"完成当前工地",fast_forward.bind(false),true,54).disabled=not learning.data.dev_skip
	hud.button(box,"全部建设完成",fast_forward.bind(true),true,54).disabled=not learning.data.dev_skip
	hud.button(box,"巡游与海底",show_explore_tools,false,48).disabled=not learning.data.dev_skip
	hud.text(box,"只推进建设，保留真实学习记录。",16,IslandHUD.GREEN)
	hud.ghost(box,"关闭",hud.close)
func fast_forward(everything=false):
	if locked or not learning.data.dev_skip:return
	frontier.finish_for_development(everything);save_progress();hud.close()
	world.sync_buildings(true);next_task();explore(everything)
	hud.toast("建设已完成" if everything else "这处工地已完成")

func show_explore_tools():
	if not learning.data.dev_skip:return
	var box=hud.modal("去看看");hud.screen="developer_tour"
	for pair in [["shipyard","船坞"],["sunreach","椰风群岛"],["basalt","黑沙群岛"],["mountain","高山望远镜"]]:
		var id=str(pair[0]);var available=frontier.done(id)
		hud.button(box,str(pair[1])+("" if available else " · 尚未建好"),tour_site.bind(id),false,46).disabled=not available
	var row=hud.row(box);hud.button(row,"蓝鲸",preview_nature.bind("whale"),false,46);hud.button(row,"深海洞窟",preview_nature.bind("cave"),false,46)
	hud.ghost(box,"返回",show_developer)
func tour_site(id:String):
	if not learning.data.dev_skip or not frontier.done(id):return
	hud.close();frontier.choose(id);save_progress();next_task();explore(false)
	world.recenter();frame_view(Vector3(0,9.3,0),13.5)
func preview_nature(kind:String):
	if not learning.data.dev_skip:return
	hud.close();explore(false);var normal=world.wildlife.preview_event(kind)
	world.desired_rotation=Quaternion(normal,Vector3.UP)
	frame_view(Vector3(0,9.2,0),16.0 if kind=="whale" else 12.0)
func open_observatory():
	if not frontier.done("mountain") or cosmos.observatory_active:return
	speech.stop();hud.close();explore(false);mouse_drag=false;touch_points.clear()
	world.work_point=frontier.target("mountain");world.walk_to(world.work_stance(0))
	if not cosmos.enter_observatory(0):return
	reset_observatory_input();observatory_hud_visible=hud.visible;hud.hide()
	observatory_layer=CanvasLayer.new();observatory_layer.layer=5;add_child(observatory_layer)
	var root=Control.new();root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.mouse_filter=Control.MOUSE_FILTER_IGNORE;observatory_layer.add_child(root)
	var margin=MarginContainer.new();root.add_child(margin);margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE);margin.add_theme_constant_override("margin_left",16);margin.add_theme_constant_override("margin_right",16);margin.add_theme_constant_override("margin_top",20)
	var bar=HBoxContainer.new();margin.add_child(bar);bar.add_theme_constant_override("separation",8)
	var back_button=hud.icon(bar,"close",close_observatory,"返回星球");back_button.custom_minimum_size=Vector2(44,44)
	var options=cosmos.observation_targets()
	for i in range(options.size()):
		var button=hud.button(bar,str(options[i].title),select_observation.bind(i),false,44)
		button.add_theme_font_override("font",font);button.add_theme_font_size_override("font_size",14)
func select_observation(index:int):
	reset_observatory_input();cosmos.select_observation_target(index)
func close_observatory():
	cosmos.leave_observatory();reset_observatory_input()
	if is_instance_valid(observatory_layer):observatory_layer.queue_free()
	observatory_layer=null;hud.visible=observatory_hud_visible
	mouse_drag=false;touch_points.clear();drag_id=-1
func reset_observatory_input():
	observatory_drag=false;observatory_touch=-1;observatory_touch_points.clear();observatory_pinch_distance=0.0
func observatory_over_controls(position:Vector2)->bool:
	if not is_instance_valid(observatory_layer):return false
	for button in observatory_layer.find_children("*","BaseButton",true,false):
		if button.is_visible_in_tree() and button.get_global_rect().has_point(position):return true
	return false
func observatory_capture_input(event)->bool:
	if event is InputEventMouse and event.device==InputEvent.DEVICE_ID_EMULATION:return false
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed and observatory_drag:
		observatory_drag=false;return true
	if event is InputEventMouseMotion and observatory_drag:
		cosmos.rotate_observation(event.relative);return true
	if event is InputEventScreenTouch and (not event.pressed or event.canceled) and observatory_touch_points.has(event.index):
		observatory_touch_points.erase(event.index);observatory_pinch_distance=0.0
		observatory_touch=-1 if observatory_touch_points.is_empty() else int(observatory_touch_points.keys()[0])
		if observatory_touch_points.size()>=2:observatory_pinch_distance=observatory_touch_points.values()[0].distance_to(observatory_touch_points.values()[1])
		return true
	if event is InputEventScreenDrag and observatory_touch_points.has(event.index):
		observatory_touch_points[event.index]=event.position
		if observatory_touch_points.size()>=2:
			var distance=observatory_touch_points.values()[0].distance_to(observatory_touch_points.values()[1])
			if observatory_pinch_distance>1:cosmos.zoom_observation(observatory_pinch_distance/maxf(1,distance))
			observatory_pinch_distance=distance
		else:cosmos.rotate_observation(event.relative)
		return true
	return false
func observatory_input(event):
	if observatory_capture_input(event):return
	if event is InputEventMouse and (event.device==InputEvent.DEVICE_ID_EMULATION or not observatory_touch_points.is_empty()):return
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_LEFT:observatory_drag=event.pressed
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:cosmos.zoom_observation(.9 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1.1)
	elif event is InputEventScreenTouch:
		if event.pressed and not event.canceled and not observatory_over_controls(event.position):
			observatory_touch_points[event.index]=event.position;observatory_touch=int(observatory_touch_points.keys()[0])
			if observatory_touch_points.size()>=2:observatory_pinch_distance=observatory_touch_points.values()[0].distance_to(observatory_touch_points.values()[1])
func bookmarks(page:int):
	var ids=learning.data.bookmarks.keys();var box=hud.modal("收藏的词");hud.screen="bookmarks"
	if ids.is_empty():hud.text(box,"点空心星星，把一个词留在这里。",19)
	for i in range(page*4,mini(ids.size(),page*4+4)):
		var id=ids[i];hud.button(box,id,func():lookup_return=bookmarks.bind(page);lookup(id))
	var r=hud.row(box)
	if page>0:hud.ghost(r,"上一页",bookmarks.bind(page-1))
	if ids.size()>(page+1)*4:hud.ghost(r,"下一页",bookmarks.bind(page+1))
	hud.ghost(box,"返回",settings)
func journal():
	if locked:return
	var box=hud.modal(mission.title);hud.screen="journal"
	var r=hud.row(box);hud.icon(r,"play",func():play_speech("audio/"+mission.id+"_full.mp3"),"听这段")
	hud.ghost(r,"译文",func():var b=hud.modal(mission.title);hud.text(b,mission.zh,21);hud.ghost(b,"返回手记",journal);hud.screen="translation")
	hud.reading(box,mission.text,255)
	hud.ghost(box,"关闭",func():hud.close())
func lookup(word:String,play=true):
	if hud.screen!="lookup":lookup_return=journal if hud.screen=="journal" else (func():hud.close()) if hud.screen not in ["bookmarks"] else lookup_return
	var d=dictionary.get(word,{})
	if d.is_empty() and learning.by_id.has(word):
		var q=learning.by_id[word];d={"translation":q.get("definition",q.zh)}
	if mode=="word" and word==str(current.get("id","")):helped=true;learning.mark_help(word);save_progress()
	var box=hud.modal("");hud.screen="lookup";var r=hud.row(box)
	var title=hud.ghost(r,word,func():play_speech(word_audio(word)));title.add_theme_font_size_override("font_size",30)
	var star=hud.icon(r,"star",bookmark.bind(word),"收藏");star.lit=learning.data.bookmarks.has(word)
	var rich=RichTextLabel.new();rich.text=str(d.get("translation","可在短文译文中查看这个词。"));rich.custom_minimum_size.y=clampf(ceil(rich.text.length()/22.0)*29,60,180);rich.add_theme_color_override("default_color",IslandHUD.INK);box.add_child(rich)
	hud.ghost(box,"返回",func():if lookup_return.is_valid():lookup_return.call())
	if play:play_speech(word_audio(word))
