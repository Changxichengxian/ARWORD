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
var exploring=false
var restore_button:Button
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

func _ready():
	font.fallbacks=[preload("res://assets/fonts/FrontierLatin.ttf")]
	art_preview="--art-preview" in OS.get_cmdline_user_args()
	qa="--qa" in OS.get_cmdline_user_args() or art_preview;get_tree().quit_on_go_back=false
	if OS.has_feature("windows") and DisplayServer.get_name()!="headless":
		var area=DisplayServer.screen_get_usable_rect()
		var height=mini(1100,area.size.y-100);var width=roundi(height*9.0/16)
		DisplayServer.window_set_size(Vector2i(width,height))
		DisplayServer.window_set_position(area.position+Vector2i((area.size.x-width)/2,(area.size.y-height)/2))
		get_window().title="词屿 · 美术预览（不保存）" if art_preview else "词屿 · 电脑试玩"
	learning=IslandLearning.new();read_save();frontier=IslandFrontier.new(learning)
	if art_preview:
		for c in IslandFrontier.CHAPTERS:frontier.data.progress[c.id]=c.need
		learning.data.build=[8,12,16];learning.data.development=[36,24,24];frontier.data.active="cottage"
	frontier_notes=JSON.parse_string(FileAccess.get_file_as_string("res://assets/frontier_missions.json"))
	notes=JSON.parse_string(FileAccess.get_file_as_string("res://assets/missions.json"));dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/dictionary.json"))
	world=IslandGrove.new();add_child(world);world.setup(self)
	camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.keep_aspect=Camera3D.KEEP_WIDTH;camera.size=world_zoom;camera.near=.1;camera.far=150;add_child(camera);camera.position=Vector3(0,24,21);camera.look_at(Vector3(0,10.0,0));camera.current=true
	speech=AudioStreamPlayer.new();add_child(speech)
	for i in range(6):var p=AudioStreamPlayer.new();add_child(p);effects.append(p)
	for kind in ["chop","stone","land","build","tap","soft"]:
		var path="res://assets/audio/"+kind+".wav"
		if ResourceLoader.exists(path):sound_bank[kind]=load(path)
	var layer=CanvasLayer.new();add_child(layer);hud=IslandHUD.new();hud.game=self;layer.add_child(hud)
	restore_button=hud.button(hud,"继续照料",resume_collect,true,54);restore_button.anchor_left=.26;restore_button.anchor_right=.74;restore_button.anchor_top=1;restore_button.anchor_bottom=1;restore_button.offset_top=-86;restore_button.offset_bottom=-30;restore_button.hide()
	next_task()
	if art_preview:
		explore();camera.size=21.5;camera.look_at(Vector3(0,4.2,0));world.desired_rotation=Quaternion(Vector3.UP,Vector3(0,.85,.53).normalized());hud.toast("美术预览 · 不保存进度")
	elif learning.data.actions==0:hud.toast("点建筑或进度条选工地")

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
	if mode=="listen":call_deferred("speak_task")
func next_word():next_task()
func select_site(site):
	var id=IslandFrontier.BUILD_IDS[site] if site is int else str(site)
	if not frontier.available(id):hud.toast(frontier.unlock_hint(id));return
	if locked or id==frontier.data.active or not frontier.choose(id):return
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
	var result=frontier.advance()
	complete_action(result)
func complete_action(result:Dictionary):
	learning.data.context_help.erase(context_key());save_progress();world.harvest(result);play_fx("chop" if world.active_kind==0 else "stone");hud.sync_goal()
	if result.complete:hud.toast("这一段做好了 · 点下一处工地")
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
	if current.is_empty():return
	play_speech(current.audio);hud.pulse_word()
func word_audio(word:String)->String:return str(learning.by_id[word].audio) if learning.by_id.has(word) else "audio/lookup_"+word+".mp3"
func speak_task(slow=false):
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
		complete_action(frontier.advance())
	else:hud.show_task()
func sentence_help():
	if locked:return
	mark_context_help();sentence_hint=mission.sentence;hud.show_task()
func sentence_reset():
	if locked:return
	sentence_used=[];sentence_chosen=[];sentence_hint="";hud.show_task()

func explore():
	if locked:return
	exploring=true;hud.card.hide();hud.sites.hide();restore_button.show();speech.stop();hud.toast("点建筑选工地 · 双指缩放")
	camera.look_at(Vector3.ZERO);camera.size=27.0
func resume_collect():
	exploring=false;restore_button.hide();hud.card.show();hud.sites.hide();camera.look_at(Vector3(0,10.0,0));camera.size=world_zoom
	world.recenter()
func recenter():world.recenter()
func world_area(p:Vector2)->bool:
	return p.y>126 and p.y<(hud.card.position.y-8 if not exploring else hud.size.y-100)
func _unhandled_input(event):
	if not is_instance_valid(hud) or hud.overlay.visible:return
	if event is InputEventScreenTouch:
		if event.pressed and world_area(event.position):
			touch_points[event.index]=event.position
			if touch_points.size()==1:drag_id=event.index;drag_start=event.position;drag_distance=0
			elif touch_points.size()==2:pinch_distance=touch_points.values()[0].distance_to(touch_points.values()[1]);drag_distance=100
		elif not event.pressed:
			if event.index==drag_id and drag_distance<12 and world_area(event.position):
				var id=world.site_at(event.position)
				if not id.is_empty():select_site(id)
			touch_points.erase(event.index)
			if touch_points.is_empty():drag_id=-1
			else:drag_id=int(touch_points.keys()[0]);drag_distance=100
	if event is InputEventScreenDrag and touch_points.has(event.index):
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
						var id=world.site_at(event.position)
						if not id.is_empty():select_site(id)
					mouse_drag=false
			elif event.pressed and world_area(event.position) and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
				camera.size=clampf(camera.size*(.9 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1.1),8,29)
				if not exploring:world_zoom=camera.size
		if event is InputEventMouseMotion and mouse_drag:drag_distance+=event.relative.length();world.drag(event.relative)

func _input(event):
	# Releases over a card/modal still end a world gesture; UI may consume them later.
	if event is InputEventScreenTouch and not event.pressed and is_instance_valid(hud) and (hud.overlay.visible or not world_area(event.position)):
		touch_points.erase(event.index)
		if touch_points.is_empty():drag_id=-1
		else:drag_id=int(touch_points.keys()[0]);drag_distance=100
	if event is InputEventMouseButton and not event.pressed and is_instance_valid(hud) and not world_area(event.position):mouse_drag=false
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ESCAPE,KEY_BACK]:back();get_viewport().set_input_as_handled()
func _notification(what):
	if what==NOTIFICATION_WM_GO_BACK_REQUEST and is_instance_valid(hud):back()
	if what==NOTIFICATION_APPLICATION_PAUSED and learning!=null:
		save_progress();drag_id=-1;touch_points.clear();mouse_drag=false
		if is_instance_valid(speech):speech.stop()
func back():
	var now=Time.get_ticks_msec()
	if now-last_back<150:return
	last_back=now;speech.stop()
	if hud.screen=="lookup" and lookup_return.is_valid():lookup_return.call()
	elif hud.overlay.visible:hud.close()
	elif exploring:resume_collect()
	else:settings()

func settings():
	if locked:return
	speech.stop();var box=hud.modal("歇一会儿");hud.screen="settings"
	hud.text(box,"独立辨认过 "+str(learning.independent_count())+" 个词",20)
	hud.text(box,"短文 "+str(learning.data.practice.read)+"  ·  听力 "+str(learning.data.practice.listen)+"  ·  组句 "+str(learning.data.practice.sentence),16)
	hud.button(box,"词汇起点 · "+["基础","适中","进阶","挑战"][learning.data.band],func():learning.data.band=(learning.data.band+1)%4;learning.data.success_run=0;learning.data.miss_run=0;save_progress();settings())
	hud.button(box,"音效 · "+("开" if learning.data.sound else "关"),func():learning.data.sound=not learning.data.sound;save_progress();settings())
	hud.button(box,"自动读词 · "+("开" if learning.data.speech else "关"),func():learning.data.speech=not learning.data.speech;save_progress();settings())
	hud.button(box,"收藏的词",func():bookmarks(0))
	hud.ghost(box,"继续照料",func():hud.close())
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
	hud.ghost(box,"继续照料",func():hud.close())
func lookup(word:String,play=true):
	if hud.screen!="lookup":lookup_return=journal if hud.screen=="journal" else (func():hud.close()) if hud.screen not in ["bookmarks"] else lookup_return
	var d=dictionary.get(word,{})
	if mode=="word" and word==str(current.get("id","")):helped=true;learning.mark_help(word);save_progress()
	var box=hud.modal("");hud.screen="lookup";var r=hud.row(box)
	var title=hud.ghost(r,word,func():play_speech(word_audio(word)));title.add_theme_font_size_override("font_size",30)
	var star=hud.icon(r,"star",bookmark.bind(word),"收藏");star.lit=learning.data.bookmarks.has(word)
	var rich=RichTextLabel.new();rich.text=str(d.get("translation","可在短文译文中查看这个词。"));rich.custom_minimum_size.y=clampf(ceil(rich.text.length()/22.0)*29,60,180);rich.add_theme_color_override("default_color",IslandHUD.INK);box.add_child(rich)
	hud.ghost(box,"返回",func():if lookup_return.is_valid():lookup_return.call())
	if play:play_speech(word_audio(word))
