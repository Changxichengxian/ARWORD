extends Node3D

const SAVE="user://island4.json"
var font=preload("res://assets/fonts/FrontierSC.ttf")
var learning:IslandLearning
var frontier:IslandFrontier
var touch_points={}
const MIN_PAIR_SPAN=18.0
var pair_span=0.0
var pair_zoom=1.0
var pair_frame=Basis.IDENTITY
var pair_rotation=Quaternion.IDENTITY
var mouse_drag=false
var world_zoom=10.0
var world:IslandGrove
var hud:IslandHUD
var camera:Camera3D
var camera_focus=Vector3(0,10.0,0)
var camera_tween:Tween
var inspection_tilt=0.0
const HOME_CAMERA=Vector3(0,24,21)
const CLOSE_PITCH=35.0
var current:Dictionary={}
var mission:Dictionary={}
var dictionary={}
var mode="word"
var order:Array=[]
var locked=false
var helped=false
var help_visible=false
var context_assisted=false
var context_between_words=false
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
var observatory_hud_visible=true
var curriculum=preload("res://scripts/curriculum.gd").new()
var journal_entry:Dictionary={}
var journal_short=true
var fixed_character="deepseek"
var study_voice=preload("res://scripts/study_voice.gd").new()
var cast_store
var trench_camera:Camera3D
const FixedCast=preload("res://scripts/fixed_cast.gd")

func _ready():
	font.fallbacks=[preload("res://assets/fonts/FrontierLatin.ttf")]
	art_preview="--art-preview" in OS.get_cmdline_user_args()
	qa="--qa" in OS.get_cmdline_user_args() or art_preview;get_tree().quit_on_go_back=false;get_tree().auto_accept_quit=false
	if OS.has_feature("windows") and DisplayServer.get_name()!="headless":
		var area=DisplayServer.screen_get_usable_rect()
		var height=mini(1100,area.size.y-100);var width=roundi(height*9.0/16)
		DisplayServer.window_set_size(Vector2i(width,height))
		DisplayServer.window_set_position(area.position+Vector2i((area.size.x-width)/2,(area.size.y-height)/2))
		get_window().title="ARWORD"
	learning=IslandLearning.new();read_save();frontier=IslandFrontier.new(learning)
	if art_preview:
		for c in IslandFrontier.CHAPTERS:frontier.data.progress[c.id]=c.need
		learning.data.build=[8,12,16];learning.data.development=[36,24,24];frontier.data.active="cottage"
	dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/dictionary.json"))
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
	hud.overlay.visibility_changed.connect(func():if hud.overlay.visible:reset_world_input())
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
	context_between_words=false
	if mode=="word":
		current=learning.next_word(Time.get_unix_time_from_system())
		context_between_words=current.is_empty()
		if context_between_words:mode=["read","listen","sentence"][int(learning.data.word_turn)%3]
	mission=curriculum.preview(learning) if mode=="word" else curriculum.next(learning,mode)
	context_assisted=learning.data.context_help.get(context_key(),false)
	short_reading=curriculum.short_first(learning,mission)
	if mode=="word":
		helped=learning.data.help_pending==current.id;order=[0,1,2,3]
	else:
		current={};order=[0,1,2]
		if mode=="sentence":
			sentence_words=Array(str(mission.sentence).trim_suffix(".").split(" "));sentence_used=[];sentence_chosen=[];sentence_order=range(sentence_words.size());sentence_order.shuffle()
	order.shuffle();world.prepare_resource();hud.show_task();hud.sync_goal()
	if mode=="listen" and not exploring:call_deferred("speak_task")
func next_word():next_task()
func select_site(site):
	var id=IslandFrontier.BUILD_IDS[site] if site is int else str(site)
	if id=="rocket":
		if frontier.done("shipyard"):world.worker.visit(frontier.target(id))
		show_rocket();return
	if not frontier.available(id):hud.toast(frontier.unlock_hint(id));return
	if locked:
		if exploring and id==frontier.data.active:resume_collect()
		return
	if id==frontier.data.active:
		world.worker.visit(frontier.target(id))
		if exploring:resume_collect()
		return
	if not frontier.choose(id):return
	speech.stop();save_progress();hud.close();world.sync_buildings();next_task()
	world.worker.visit(frontier.target(id))
	if exploring:resume_collect()

func introducing()->bool:
	return mode=="word" and not current.is_empty() and learning.needs_intro(current.id)

func introduce_word(id:String,already_known=false):
	if not introducing() or current.id!=id or locked or exploring or hud.overlay.visible:return
	learning.introduce(id,already_known);speech.stop();save_progress();next_task()

func answer(index:int):
	if locked or help_visible or hud.overlay.visible or exploring or introducing():return
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
	if mode=="word" and learning.data.words[current.id].get("mastered",false):
		hud.toast(current.word+" · 已学会")
func skip_learning():
	if locked or exploring or hud.overlay.visible or not learning.data.dev_skip:return
	locked=true;speech.stop();learning.data.dev_steps+=1
	if mode=="word":learning.data.harvested[world.active_kind]+=1
	elif mode in ["read","listen"]:learning.data.dev_context[mode]+=1
	complete_action(frontier.advance(),false)
func complete_action(result:Dictionary,learned=true):
	if context_between_words and learned:learning.data.word_turn+=1
	if mode!="word":curriculum.release(learning,mode,mission.id)
	if learned:learning.data.context_help.erase(context_key())
	frontier.record_delivery(world.production_route)
	var rocket_unlocked=frontier.try_unlock_rocket()
	world.sync_voyage()
	save_progress();world.harvest(result);play_fx("chop" if world.active_kind==0 else "stone");hud.sync_goal()
	if rocket_unlocked:
		hud.toast("词书首轮完成 · 火箭舱门已开启")
	elif result.complete:
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
	var recording=study_voice.recording(path) if learning.data.feiyu_voice else null
	if recording==null:
		if not ResourceLoader.exists("res://assets/"+path):return
		recording=load("res://assets/"+path)
	speech.stop();var speed=.85 if slow else 1.0;speech.pitch_scale=speed
	var bus=AudioServer.get_bus_index("Speech")
	if bus<0:
		AudioServer.add_bus();bus=AudioServer.bus_count-1;AudioServer.set_bus_name(bus,"Speech");AudioServer.add_bus_effect(bus,AudioEffectPitchShift.new())
	AudioServer.get_bus_effect(bus,0).pitch_scale=1.0/speed
	speech.bus="Speech";speech.stream=recording;speech.play()
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

func zoom_tilt(zoom:float)->float:
	return 1.-smoothstep(3.2,12.,zoom) if exploring else 0.

func apply_framing(focus:Vector3,zoom:float,tilt:float):
	camera_focus=focus;camera.size=zoom;inspection_tilt=tilt
	var pivot=focus.lerp(Vector3.UP*IslandGrove.RADIUS,tilt)
	var pitch=deg_to_rad(CLOSE_PITCH)
	var close_position=Vector3.UP*IslandGrove.RADIUS+Vector3(0,sin(pitch),cos(pitch))*25.
	camera.position=HOME_CAMERA.lerp(close_position,tilt)
	camera.look_at(pivot)

func set_user_zoom(zoom:float):
	var size_new=clampf(zoom,3.2,29.)
	apply_framing(camera_focus,size_new,zoom_tilt(size_new))
	if not exploring:world_zoom=size_new

func frame_view(focus:Vector3,zoom:float,animate=true):
	if camera_tween and camera_tween.is_valid():camera_tween.kill()
	var tilt=zoom_tilt(zoom)
	if not animate:apply_framing(focus,zoom,tilt);return
	var from_focus=camera_focus;var from_zoom=camera.size;var from_tilt=inspection_tilt
	camera_tween=create_tween();camera_tween.tween_method(func(t):
		apply_framing(from_focus.lerp(focus,t),lerpf(from_zoom,zoom,t),lerpf(from_tilt,tilt,t)),0.0,1.0,.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
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
	return hud.safe_rect.has_point(p) and p.y>hud.safe_rect.position.y+86 and p.y<hud.safe_rect.end.y-4 and (not hud.card.visible or not hud.card.get_global_rect().has_point(p))
func tap_world(p:Vector2):
	var id=world.site_at(p)
	if not exploring:
		explore()
		return
	if not id.is_empty():select_site(id);return
	if world.wildlife and world.wildlife.handle_tap(p):return
	if cosmos:cosmos.handle_tap(p)
func reset_world_input():
	touch_points.clear()
	pair_span=0.0
	mouse_drag=false
	drag_id=-1

func finger_line(points:Dictionary)->Vector2:
	var fingers=points.values()
	return fingers[1]-fingers[0]

func surface_grip(line:Vector2)->Basis:
	var fingers=touch_points.values()
	var midpoint:Vector2=(fingers[0]+fingers[1])*.5
	return grip_at(midpoint,line)

func grip_at(midpoint:Vector2,line:Vector2)->Basis:
	var to_view=camera.global_basis.z.normalized()
	var ray_offset=camera.project_ray_origin(midpoint)-world.globe.global_position
	var radial=ray_offset-to_view*ray_offset.dot(to_view)
	var radius=IslandGrove.RADIUS
	var rr=radial.length_squared()/(radius*radius)
	# Continue the virtual surface beyond the visible limb. This keeps a pair
	# partly over the sky well conditioned, even when the globe is very close.
	var depth=radius*(sqrt(1.0-rr) if rr<=.90 else maxf(.001,sqrt(.10)*exp(-5.*(rr-.90))))
	var normal=(radial+to_view*depth).normalized()
	var screen_direction=camera.global_basis.x*line.x-camera.global_basis.y*line.y
	# Tangent whose projection points along the displayed line between fingers.
	var tangent=(screen_direction-to_view*(screen_direction.dot(normal)/normal.dot(to_view))).normalized()
	return Basis(tangent,normal.cross(tangent),normal)

func begin_world_pair():
	stop_view_transition()
	drag_distance=100
	var line=finger_line(touch_points)
	pair_span=line.length()
	if pair_span<MIN_PAIR_SPAN:
		pair_span=0.0
		return
	pair_zoom=camera.size
	pair_rotation=world.desired_rotation
	pair_frame=surface_grip(line)

func captured_world_touch(event)->bool:
	if not (event is InputEventScreenTouch or event is InputEventScreenDrag):return false
	if not touch_points.has(event.index):return false
	if event is InputEventScreenTouch:
		if event.pressed and not event.canceled:return false
		var tap=not event.canceled and touch_points.size()==1 and event.index==drag_id and drag_distance<12 and world_area(event.position)
		touch_points.erase(event.index)
		pair_span=0.0
		drag_id=-1 if touch_points.is_empty() else int(touch_points.keys()[0])
		drag_distance=100
		if tap:tap_world(event.position)
		return true
	var delta:Vector2=event.position-touch_points[event.index]
	touch_points[event.index]=event.position
	stop_view_transition()
	if touch_points.size()==1:
		drag_distance+=delta.length()
		world.drag(delta)
		return true
	var line=finger_line(touch_points)
	if line.length()<MIN_PAIR_SPAN:
		pair_span=0.0
	elif pair_span==0.0:
		begin_world_pair()
	else:
		set_user_zoom(pair_zoom*pair_span/line.length())
		var turn=surface_grip(line)*pair_frame.transposed()
		world.desired_rotation=(turn.get_rotation_quaternion()*pair_rotation).normalized()
	return true

func _unhandled_input(event):
	if cosmos and cosmos.observatory_active:
		observatory_input(event);return
	if not is_instance_valid(hud) or hud.overlay.visible:return
	if captured_world_touch(event):return
	if event is InputEventScreenTouch:
		if event.pressed and not event.canceled and world_area(event.position) and touch_points.size()<2:
			touch_points[event.index]=event.position
			if touch_points.size()==1:drag_id=event.index;drag_start=event.position;drag_distance=0
			else:begin_world_pair()
	if event is InputEventMouse and event.device==InputEvent.DEVICE_ID_EMULATION:return
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
				var before=grip_at(event.position,Vector2.RIGHT)
				set_user_zoom(camera.size*(.9 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1.1))
				if exploring:
					var turn=grip_at(event.position,Vector2.RIGHT)*before.transposed()
					world.desired_rotation=(turn.get_rotation_quaternion()*world.desired_rotation).normalized()
		if event is InputEventMouseMotion and mouse_drag:stop_view_transition();drag_distance+=event.relative.length();world.drag(event.relative)

func _input(event):
	# A captured sky gesture must finish even when its release lands on a toolbar button.
	if cosmos and cosmos.observatory_active and observatory_capture_input(event):
		get_viewport().set_input_as_handled();return
	# Continue an established grab across a card or toolbar, including release.
	if is_instance_valid(hud) and not hud.overlay.visible and captured_world_touch(event):
		get_viewport().set_input_as_handled();return
	if event is InputEventMouseButton and not event.pressed and is_instance_valid(hud) and (hud.overlay.visible or not world_area(event.position)):mouse_drag=false
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ESCAPE,KEY_BACK]:back();get_viewport().set_input_as_handled()
func _notification(what):
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED]:
		reset_observatory_input()
		reset_world_input()
	if what==NOTIFICATION_WM_CLOSE_REQUEST:request_exit()
	if what==NOTIFICATION_WM_GO_BACK_REQUEST and is_instance_valid(hud):back()
	if what==NOTIFICATION_APPLICATION_PAUSED and learning!=null:
		save_progress()
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
	if is_instance_valid(trench_camera):leave_trench();return
	if cosmos and cosmos.observatory_active:close_observatory();return
	if hud.screen=="lookup" and lookup_return.is_valid():lookup_return.call()
	elif hud.screen=="translation" and not journal_entry.is_empty():show_journal_page(journal_entry)
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
	if study_voice.archive!=null:
		hud.button(box,"英语朗读 · "+("大肥鱼（可爱）" if learning.data.feiyu_voice else "原声"),toggle_study_voice)
	var music_row=hud.row(box)
	hud.button(music_row,"轻音乐 · "+("开" if learning.data.music else "关"),func():learning.data.music=not learning.data.music;save_progress();settings())
	hud.ghost(music_row,"下一首",ambience.next_track).disabled=not learning.data.music
	hud.button(box,"星空与星云",space_settings)
	hud.button(box,"人物",show_avatar_settings)
	hud.button(box,"自动读词 · "+("开" if learning.data.speech else "关"),func():learning.data.speech=not learning.data.speech;save_progress();settings())
	hud.button(box,"收藏的词",func():bookmarks(0))
	hud.button(box,"开发特权 · "+("开" if learning.data.dev_skip else "关"),show_developer)
	var settings_footer=hud.row(box)
	if Engine.has_singleton("PlanetUpdates"):
		hud.ghost(settings_footer,"检查更新",func():preload("res://scripts/updater.gd").open(self))
	hud.ghost(settings_footer,"关闭",func():hud.close())
func toggle_study_voice():
	learning.data.feiyu_voice=not learning.data.feiyu_voice
	save_progress()
	settings()
	play_speech("audio/work00_cue.mp3")

func initialize_avatar():
	var directory="user://characters"
	var legacy="user://avatars/current.vrm"
	if qa:
		var scope=str(Time.get_ticks_usec())
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--qa-avatar-scope="):
				var label=arg.trim_prefix("--qa-avatar-scope=").validate_filename()
				if label not in ["", ".", ".."]:scope=label
		directory="user://qa-characters/".path_join(scope)
		legacy=""
	cast_store=FixedCast.new(directory)
	if qa and not "--qa-with-cast" in OS.get_cmdline_user_args():
		fixed_character="default"
		return
	study_voice.prepare(directory)
	cast_store.prepare(FixedCast.BUILTIN,legacy)
	fixed_character="default"
	if cast_store.preferred()=="deepseek":apply_fixed_character("deepseek",false)

func apply_fixed_character(id:String,persist:bool)->bool:
	if cast_store==null or id not in ["deepseek","default"]:return false
	var candidate:Node3D=null
	if id=="deepseek":
		if cast_store.model_path.is_empty():return false
		var result=world.prepare_local_avatar(cast_store.model_path)
		if not result.get("ok",false):return false
		candidate=result.candidate
	if persist and not cast_store.remember(id):
		if candidate:candidate.free()
		return false
	if candidate:world.activate_local_avatar(candidate)
	else:world.clear_local_avatar()
	fixed_character=id
	return true

func select_fixed_character(id:String):
	if fixed_character!=id and not apply_fixed_character(id,true):hud.toast("人物暂时无法切换")
	show_avatar_settings()

func show_avatar_settings():
	if not exploring:explore()
	speech.stop()
	var box=hud.modal("人物")
	hud.screen="avatar"
	if cast_store!=null and not cast_store.model_path.is_empty():
		hud.button(box,("✓  " if fixed_character=="deepseek" else "")+"大肥鱼",select_fixed_character.bind("deepseek"),fixed_character=="deepseek",56)
		hud.text(box,"DeepSeek 娘 · 木子恶魔",16,IslandHUD.GREEN)
	hud.button(box,("✓  " if fixed_character=="default" else "")+"默认人物",select_fixed_character.bind("default"),fixed_character=="default",56)
	hud.ghost(box,"返回",settings)

func space_settings():
	if not exploring:explore()
	speech.stop();var box=hud.modal("星空与星云",true,false);hud.screen="space_settings"
	box.add_theme_constant_override("separation",4)
	for item in [["星云浓度","nebula"],["色彩强度","color"],["星云范围","band"],["星星密度","stars"],["漂移速度","drift"]]:hud.parameter(box,item[0],item[1],IslandLearning.SPACE_LIMITS[item[1]])
	hud.ghost(box,"中心天体 · "+("黑洞" if learning.data.black_hole else "太阳"),toggle_central_body,40)
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
		var mastered=0
		for id in book.words:
			if learning.data.words.get(id,{}).get("mastered",false):mastered+=1
		if mastered>0:label+=" · 已学会 "+str(mastered)
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
func toggle_central_body():
	learning.data.black_hole=not learning.data.black_hole
	cosmos.set_black_hole(learning.data.black_hole);save_progress();space_settings()

func reset_space_settings():
	learning.data.black_hole=IslandLearning.DEFAULT_BLACK_HOLE;cosmos.set_black_hole(learning.data.black_hole)
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
	var rewind=hud.row(box)
	hud.ghost(rewind,"重做当前工地",confirm_rewind.bind(false),44).disabled=not learning.data.dev_skip
	hud.ghost(rewind,"星球回到开局",confirm_rewind.bind(true),44).disabled=not learning.data.dev_skip
	hud.button(box,"巡游与海底",show_explore_tools,false,48).disabled=not learning.data.dev_skip
	hud.text(box,"只推进建设，保留真实学习记录。",16,IslandHUD.GREEN)
	hud.ghost(box,"关闭",hud.close)
func confirm_rewind(all_sites:bool):
	if locked or not learning.data.dev_skip:return
	var box=hud.modal("星球回到开局" if all_sites else "重做当前工地")
	hud.text(box,"重置土地、建筑、材料和航程。学习记录和收藏保留。" if all_sites else "重置这处工地的建设进度。其他工地和学习记录保留。",18)
	var line=hud.row(box);hud.ghost(line,"取消",show_developer);hud.button(line,"确认退回",rewind_building.bind(all_sites),true)

func rewind_building(all_sites:bool):
	if locked or not learning.data.dev_skip:return
	frontier.rewind_building(all_sites);save_progress()
	stop_view_transition();reset_world_input();speech.stop();hud.close()
	var old=world
	world=IslandGrove.new();remove_child(old);old.queue_free()
	add_child(world);world.setup(self)
	for node in world.get_children():
		if node is WorldEnvironment:
			node.environment.background_mode=Environment.BG_CANVAS;node.environment.background_canvas_max_layer=-10
	world.wildlife=load("res://scripts/wildlife.gd").new();world.add_child(world.wildlife);world.wildlife.setup(world)
	if fixed_character=="deepseek":apply_fixed_character("deepseek",false)
	world_zoom=10;next_task();explore(true,false);hud.sync_goal()

func fast_forward(everything=false):
	if locked or not learning.data.dev_skip:return
	frontier.finish_for_development(everything);save_progress();hud.close()
	world.sync_buildings(true);next_task();explore(everything)
	hud.toast("建设已完成" if everything else "这处工地已完成")

func show_explore_tools():
	if not learning.data.dev_skip:return
	var box=hud.modal("去看看");hud.screen="developer_tour"
	for pair in [["goldmine","远岛矿洞"],["smelter","主岛铸币坊"],["rocket","背面火箭"],["shipyard","船坞"],["mountain","高山望远镜"]]:
		var id=str(pair[0]);var available=frontier.done(id) or id=="rocket"
		hud.button(box,str(pair[1])+("" if available else " · 尚未建好"),tour_site.bind(id),false,46).disabled=not available
	var row=hud.row(box);hud.button(row,"蓝鲸",preview_nature.bind("whale"),false,46);hud.button(row,"深海洞窟",preview_nature.bind("cave"),false,46)
	var coast=hud.row(box);hud.button(coast,"虎鲸",preview_nature.bind("orca"),false,46);hud.button(coast,"潮间岩台",preview_nature.bind("tidepool"),false,46).disabled=not world.wildlife.tidepool.visible
	hud.ghost(box,"返回",show_developer)

func show_rocket():
	if locked:return
	if frontier.try_unlock_rocket():
		save_progress()
		world.sync_voyage()
	explore()
	world.desired_rotation=Quaternion(world.surface(frontier.target("rocket")).normalized(),Vector3.UP)
	frame_view(Vector3(0,10.4,0),10.5)
	var open=frontier.rocket_open()
	var box=hud.modal("远航火箭" if open else "海怪的泊位",true,false)
	hud.screen="rocket"
	hud.ghost(box,"观察海沟",enter_trench,40)
	var wallet=frontier.data.voyage
	var total_price=IslandFrontier.TRADE_PRICE
	if open:
		var book=learning.wordbooks.find(str(wallet.earned_book))
		var caption="开发巡游 · 舱门已开" if book.is_empty() else str(book.title)+" · 首轮完成"
		hud.text(box,caption,18,IslandHUD.GREEN)
		if book.is_empty():
			hud.ghost(box,"继续我的词书航程",resume_voyage)
		hud.button(box,"点火试车",fire_rocket_engine,true,46)
		hud.ghost(box,"收起",hud.close)
		return
	var book=learning.current_book()
	hud.text(box,"泊位交易  "+str(wallet.paid)+" / "+str(total_price)+" 枚",22)
	hud.text(box,str(book.title)+"首轮  "+str(learning.book_independent())+" / "+str(book.words.size())+" 词",16,IslandHUD.GREEN)
	if wallet.paid>=total_price:
		hud.text(box,"海怪已让路。独立认完一本词书，就能开启舱门。",17)
	else:
		var amount=frontier.offer_amount()
		var pay=hud.button(box,"交付 "+str(amount)+" 枚金币" if amount>0 else "金币  "+str(wallet.coins),pay_trader,true,46)
		pay.disabled=amount==0 or not frontier.done("smelter")
		var row=hud.row(box)
		if frontier.available("goldmine"):hud.button(row,"去矿洞",go_voyage_site.bind("goldmine"),false,44)
		if frontier.available("smelter"):hud.button(row,"去铸币坊",go_voyage_site.bind("smelter"),false,44)
		if not frontier.done("shipyard"):hud.text(box,"建成船坞后，可以前往远岛采金。",16,IslandHUD.GREEN)
	hud.ghost(box,"收起",hud.close)

func enter_trench():
	if is_instance_valid(trench_camera):return
	hud.header.hide()
	var box=hud.modal("",true,false);hud.screen="trench"
	hud.ghost(box,"浮上海面",leave_trench,46)
	trench_camera=Camera3D.new();world.trader.add_child(trench_camera)
	trench_camera.near=.06;trench_camera.far=40;trench_camera.keep_aspect=Camera3D.KEEP_WIDTH;trench_camera.fov=80
	var env=Environment.new()
	env.background_mode=Environment.BG_COLOR;env.background_color=Color("113346")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("A2D3D6");env.ambient_light_energy=.76
	env.fog_enabled=true;env.fog_density=.105;env.fog_light_color=Color("22495B");env.fog_light_energy=.62
	trench_camera.environment=env;trench_camera.current=true
	var lamp=OmniLight3D.new();lamp.light_color=Color("97D4DB");lamp.light_energy=2.3;lamp.omni_range=8.;trench_camera.add_child(lamp)
	var observer=trench_camera
	var descend=func(t):
		observer.position=Vector3(-5.25,-2.38,-2.0).lerp(Vector3(-5.30,-2.81,-1.65),t)
		observer.look_at(world.trader.to_global(Vector3(-2.,-2.48-t*.42,3.4)),world.trader.global_basis.y)
	descend.call(0.);trench_camera.create_tween().tween_method(descend,0.,1.,3.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func leave_trench():
	if not is_instance_valid(trench_camera):return
	camera.current=true;trench_camera.queue_free();trench_camera=null
	hud.header.show()
	show_rocket()

func fire_rocket_engine():
	if not frontier.rocket_open() or hud.screen!="rocket":return
	hud.close()
	world.test_rocket_engine()
	play_fx("build")

func resume_voyage():
	frontier.data.voyage.dev_open=false
	save_progress()
	world.sync_voyage()
	hud.sync_goal()
	show_rocket()

func go_voyage_site(id:String):
	hud.close()
	select_site(id)

func pay_trader():
	if hud.screen!="rocket" or not hud.overlay.visible:return
	var amount=frontier.offer_gold()
	if amount<=0:return
	hud.close()
	var unlocked=frontier.try_unlock_rocket()
	save_progress()
	world.receive_coins(amount)
	hud.sync_goal()
	play_fx("build")
	if unlocked:hud.toast("火箭舱门已开启")
	elif frontier.data.voyage.paid>=IslandFrontier.TRADE_PRICE:hud.toast("海怪让开了泊位")
func tour_site(id:String):
	if not learning.data.dev_skip or (not frontier.done(id) and id!="rocket"):return
	if id=="rocket":
		if frontier.done("shipyard"):world.worker.visit(frontier.target(id))
		show_rocket();return
	hud.close();frontier.choose(id);save_progress();next_task();explore(false)
	world.worker.visit(frontier.target(id));world.recenter();frame_view(Vector3(0,9.3,0),13.5)
func preview_nature(kind:String):
	if not learning.data.dev_skip:return
	hud.close();explore(false);var normal=world.wildlife.preview_event(kind)
	world.desired_rotation=Quaternion(normal,Vector3.UP)
	var zoom={"whale":16.0,"orca":8.2,"tidepool":3.6,"cave":12.0}
	frame_view(Vector3(0,11.5,0) if kind=="tidepool" else Vector3(0,9.6,0),zoom[kind])
func open_observatory(primary=false):
	if cosmos.observatory_active:return
	if primary and not learning.data.black_hole:return
	if not primary and not frontier.done("mountain"):return
	speech.stop();hud.close();explore(false);reset_world_input()
	if not primary:
		world.work_point=frontier.target("mountain");world.walk_to(world.work_stance(0))
	if not cosmos.enter_observatory(0):return
	cosmos.primary_close=primary;cosmos.update_observation_quality()
	reset_observatory_input();observatory_hud_visible=hud.visible;hud.hide()
	observatory_layer=CanvasLayer.new();observatory_layer.layer=5;add_child(observatory_layer)
	var root=Control.new();root.mouse_filter=Control.MOUSE_FILTER_IGNORE;observatory_layer.add_child(root)
	root.position=hud.safe_rect.position;root.size=hud.safe_rect.size
	hud.safe_rect_changed.connect(layout_observation_ui)
	var margin=MarginContainer.new();root.add_child(margin);margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE);margin.add_theme_constant_override("margin_left",16);margin.add_theme_constant_override("margin_right",16);margin.add_theme_constant_override("margin_top",20)
	var bar=HBoxContainer.new();margin.add_child(bar);bar.add_theme_constant_override("separation",8)
	var back_button=hud.icon(bar,"close",close_observatory,"返回星球");back_button.custom_minimum_size=Vector2(44,44)
	margin.add_theme_constant_override("margin_top",roundi(hud.header.offset_top))
	if primary:return
	var options=cosmos.observation_targets()
	for i in range(options.size()):
		var button=hud.button(bar,str(options[i].title),select_observation.bind(i),false,44)
		button.add_theme_font_override("font",font);button.add_theme_font_size_override("font_size",14)
func layout_observation_ui(rect:Rect2):
	if is_instance_valid(observatory_layer) and observatory_layer.get_child_count()>0:
		var controls=observatory_layer.get_child(0)
		controls.position=rect.position;controls.size=rect.size

func select_observation(index:int):
	reset_observatory_input();cosmos.select_observation_target(index)
func close_observatory():
	if hud.safe_rect_changed.is_connected(layout_observation_ui):hud.safe_rect_changed.disconnect(layout_observation_ui)
	cosmos.leave_observatory();reset_observatory_input()
	if is_instance_valid(observatory_layer):observatory_layer.queue_free()
	observatory_layer=null;hud.visible=observatory_hud_visible
	reset_world_input()
func reset_observatory_input():
	observatory_drag=false;observatory_touch=-1;observatory_touch_points.clear()
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
		observatory_touch_points.erase(event.index)
		observatory_touch=-1 if observatory_touch_points.is_empty() else int(observatory_touch_points.keys()[0])
		return true
	if event is InputEventScreenDrag and observatory_touch_points.has(event.index):
		var previous=finger_line(observatory_touch_points) if observatory_touch_points.size()==2 else Vector2.ZERO
		observatory_touch_points[event.index]=event.position
		if observatory_touch_points.size()==2:
			var line=finger_line(observatory_touch_points)
			if minf(line.length(),previous.length())>=MIN_PAIR_SPAN:
				cosmos.zoom_observation(previous.length()/line.length())
				cosmos.observation_roll=wrapf(cosmos.observation_roll+previous.angle_to(line),-PI,PI)
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
		if event.pressed and not event.canceled and not observatory_over_controls(event.position) and observatory_touch_points.size()<2:
			observatory_touch_points[event.index]=event.position;observatory_touch=int(observatory_touch_points.keys()[0])
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
	journal_short=short_reading
	show_journal_page(mission)
func show_journal_page(entry:Dictionary):
	journal_entry=entry
	speech.stop()
	var box=hud.modal(entry.title);hud.screen="journal"
	var r=hud.row(box)
	var suffix="_short.mp3" if journal_short else "_full.mp3"
	hud.icon(r,"play",func():play_speech("audio/"+entry.id+suffix),"听这段")
	hud.ghost(r,"展开" if journal_short else "短一点",func():journal_short=not journal_short;show_journal_page(entry))
	hud.ghost(r,"译文",show_journal_translation)
	var index=curriculum.pool.find(entry)
	hud.ghost(r,"上一篇",show_journal_page.bind(curriculum.pool[posmod(index-1,curriculum.pool.size())]))
	hud.ghost(r,"下一篇",show_journal_page.bind(curriculum.pool[(index+1)%curriculum.pool.size()]))
	hud.reading(box,entry.short if journal_short else entry.text,255)
	hud.ghost(box,"关闭",func():hud.close())
func show_journal_translation():
	if journal_entry.id==mission.id and mode in ["read","listen","sentence"]:mark_context_help()
	var box=hud.modal(journal_entry.title);hud.screen="translation"
	hud.text(box,journal_entry.zh,21)
	hud.ghost(box,"返回阅读",show_journal_page.bind(journal_entry))
func lookup(word:String,play=true):
	if hud.screen!="lookup":lookup_return=show_journal_page.bind(journal_entry) if hud.screen=="journal" else (func():hud.close()) if hud.screen not in ["bookmarks"] else lookup_return
	var d=dictionary.get(word,{})
	if d.is_empty() and learning.by_id.has(word):
		var q=learning.by_id[word];d={"translation":q.get("definition",q.zh)}
	if mode=="word" and word==str(current.get("id","")):helped=true;learning.mark_help(word);save_progress()
	var box=hud.modal("");hud.screen="lookup";var r=hud.row(box)
	var title=hud.ghost(r,word,func():play_speech(word_audio(word)));title.add_theme_font_size_override("font_size",30)
	var star=hud.icon(r,"star",bookmark.bind(word),"收藏");star.lit=learning.data.bookmarks.has(word)
	if learning.data.words.get(word,{}).get("mastered",false):hud.text(box,"已学会",16,IslandHUD.GREEN)
	var rich=RichTextLabel.new();rich.text=str(d.get("translation","可在短文译文中查看这个词。"));rich.custom_minimum_size.y=clampf(ceil(rich.text.length()/22.0)*29,60,180);rich.add_theme_color_override("default_color",IslandHUD.INK);box.add_child(rich)
	hud.ghost(box,"返回",func():if lookup_return.is_valid():lookup_return.call())
	if play:play_speech(word_audio(word))
