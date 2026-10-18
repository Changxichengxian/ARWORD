extends Node3D

const SAVE="user://island4.json"
var font=preload("res://assets/fonts/FrontierSC.ttf")
var learning:IslandLearning
var world:IslandGrove
var hud:IslandHUD
var camera:Camera3D
var current:Dictionary={}
var order:Array=[0,1,2,3]
var locked=false
var helped=false
var help_visible=false
var exploring=false
var restore_button:Button
var speech:AudioStreamPlayer
var effects:Array=[]
var sound_bank={}
var sound_index=0
var letters:Array=[]
var dictionary={}
var letter_index=-1
var letter_translated=false
var sentence_words:Array=[]
var sentence_used:Array=[]
var sentence_chosen:Array=[]
var sentence_order:Array=[]
var sentence_hint=""
var qa=false
var drag_id=-1
var last_back=-1000

func _ready():
	font.fallbacks=[preload("res://assets/fonts/FrontierLatin.ttf")]
	qa="--qa" in OS.get_cmdline_user_args();get_tree().quit_on_go_back=false
	learning=IslandLearning.new();read_save();learning.next_project()
	letters=JSON.parse_string(FileAccess.get_file_as_string("res://assets/lessons.json"));dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/dictionary.json"))
	world=IslandGrove.new();add_child(world);world.setup(self)
	camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.keep_aspect=Camera3D.KEEP_WIDTH;camera.size=11.8;camera.near=.1;camera.far=100;add_child(camera);camera.position=Vector3(9,12,17);camera.look_at(Vector3(0,-3.1,0));camera.current=true
	var layer=CanvasLayer.new();add_child(layer);hud=IslandHUD.new();hud.game=self;layer.add_child(hud)
	restore_button=hud.button(hud,"回到采集",resume_collect,true,55);restore_button.anchor_left=.22;restore_button.anchor_right=.78;restore_button.anchor_top=1;restore_button.anchor_bottom=1;restore_button.offset_top=-92;restore_button.offset_bottom=-35;restore_button.hide()
	speech=AudioStreamPlayer.new();add_child(speech)
	for i in range(6):var p=AudioStreamPlayer.new();add_child(p);effects.append(p)
	for kind in ["chop","stone","land","build","tap","soft"]:
		var path="res://assets/audio/"+kind+".wav"
		if ResourceLoader.exists(path):sound_bank[kind]=load(path)
	next_word()
	if learning.data.actions==0:hud.toast("想起一个词，亲手开出一小片。")

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

func next_word():
	current=learning.next_word(Time.get_unix_time_from_system());helped=learning.data.help_pending==current.id;help_visible=false;locked=false
	order=[0,1,2,3];order.shuffle();world.prepare_resource();hud.show_word();hud.sync_goal()

func answer(index:int):
	if locked or help_visible or hud.overlay.visible or exploring:return
	if index!=int(current.correct):reveal();return
	locked=true;speech.stop();hud.feedback(index)
	var result=learning.record(current.id,helped,Time.get_unix_time_from_system());save_progress()
	world.harvest(result);play_fx("chop" if world.active_kind==0 else "stone");hud.sync_goal()
	if result.complete:hud.toast(["木屋完工，船靠岸了。","风车转起来了。","小岛安顿好了。去看看它吧。"][result.project])
	elif learning.data.actions%6==0:hud.toast("这一小片，整理好了。")
	var duration=1.25 if result.complete else .67
	get_tree().create_timer(duration).timeout.connect(func():
		if not is_inside_tree():return
		learning.next_project();save_progress();next_word()
	)

func reveal():
	if locked:return
	helped=true;help_visible=true;learning.mark_help(current.id);save_progress();play_fx("soft");hud.show_help()
func retry():
	if locked:return
	help_visible=false;order.shuffle();hud.show_word()
func toggle_listen():
	if locked:return
	learning.data.listen=not learning.data.listen;save_progress()
	if help_visible:hud.show_help()
	else:hud.show_word()
func bookmark():
	var id=current.id
	if learning.data.bookmarks.has(id):learning.data.bookmarks.erase(id)
	else:learning.data.bookmarks[id]=true
	save_progress();hud.show_word()

func speak_word():play_speech(str(current.audio))
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

func explore():
	if locked:return
	exploring=true;hud.card.hide();restore_button.show();speech.stop();hud.toast("拖动星球，看看你建好的地方。")
	camera.look_at(Vector3.ZERO);camera.size=11.5
func resume_collect():
	exploring=false;restore_button.hide();hud.card.show();camera.look_at(Vector3(0,-3.1,0));camera.size=11.8
func _unhandled_input(event):
	if not is_instance_valid(hud) or hud.overlay.visible:return
	var limit=hud.size.y-445 if not exploring else hud.size.y-110
	if event is InputEventScreenTouch:
		if event.pressed and event.position.y>210 and event.position.y<limit:drag_id=event.index
		elif event.index==drag_id:drag_id=-1
	if event is InputEventScreenDrag and event.index==drag_id:world.desired_yaw+=event.relative.x*.008
	if event is InputEventMouseMotion and event.button_mask==MOUSE_BUTTON_MASK_LEFT and not OS.has_feature("android") and event.position.y>210 and event.position.y<limit:world.desired_yaw+=event.relative.x*.008
func _input(event):
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ESCAPE,KEY_BACK]:back();get_viewport().set_input_as_handled()
func _notification(what):
	if what==NOTIFICATION_WM_GO_BACK_REQUEST and is_instance_valid(hud):back()
	if what==NOTIFICATION_APPLICATION_PAUSED and learning!=null:
		save_progress();drag_id=-1
		if is_instance_valid(speech):speech.stop()
func back():
	var now=Time.get_ticks_msec()
	if now-last_back<150:return
	last_back=now;speech.stop()
	if hud.screen=="lookup" and letter_index>=0:show_letter(letter_index)
	elif hud.overlay.visible:hud.close();letter_index=-1
	elif exploring:resume_collect()
	else:settings()

func settings():
	if locked:return
	letter_index=-1;speech.stop();var box=hud.modal("歇一会儿");hud.screen="settings"
	hud.text(box,"已独立想起 "+str(learning.independent_count())+" / 96 个",20)
	hud.button(box,"词汇起点 · "+["基础","适中","进阶","挑战"][learning.data.band],func():learning.data.band=(learning.data.band+1)%4;learning.data.success_run=0;learning.data.miss_run=0;save_progress();settings())
	hud.button(box,"音效 · "+("开" if learning.data.sound else "关"),func():learning.data.sound=not learning.data.sound;save_progress();settings())
	hud.button(box,"自动读词 · "+("开" if learning.data.speech else "关"),func():learning.data.speech=not learning.data.speech;save_progress();settings())
	hud.button(box,"我的收藏",func():bookmarks(0))
	hud.text(box,"难度会随回忆情况微调，不代表总词汇量。",15,Color("70847C"))
	hud.button(box,"继续采集",func():hud.close(),true)

func bookmarks(page:int):
	var ids=learning.data.bookmarks.keys();var box=hud.modal("收藏的小词");hud.screen="bookmarks"
	if ids.is_empty():hud.text(box,"遇到想留住的词，点一下“藏”。",20)
	for i in range(page*5,mini(ids.size(),page*5+5)):
		var q=learning.by_id.get(ids[i],{})
		if not q.is_empty():hud.button(box,q.word+" · "+q.zh,func():play_speech(q.audio),false,48)
	var r=hud.row(box)
	if page>0:hud.button(r,"上一页",func():bookmarks(page-1))
	if ids.size()>(page+1)*5:hud.button(r,"下一页",func():bookmarks(page+1))
	hud.button(box,"返回",settings,true)

func letters_menu():
	if locked:return
	speech.stop();letter_index=-1;var box=hud.modal("岛上的来信");hud.screen="letters"
	for i in range(letters.size()):
		var learned=learning.data.flags.get(letters[i].flag,false)
		hud.button(box,("✓  " if learned else "")+letters[i].title,show_letter.bind(i),false,58)
	hud.text(box,"读懂安排，选择建筑的位置与水路。",16,Color("70847C"))
	hud.button(box,"回到采集",func():hud.close(),true)

func show_letter(index:int):
	letter_index=index;var l=letters[index];var box=hud.modal(l.title);hud.screen="letter"
	var r=hud.row(box)
	hud.button(r,"听来信",func():play_speech("audio/letter"+str(index)+".mp3"),false,43)
	hud.button(r,"慢一点",func():play_speech("audio/letter"+str(index)+".mp3",true),false,43)
	hud.button(r,"译文",func():letter_translated=not letter_translated;show_letter(index),false,43)
	if letter_translated:hud.text(box,l.zh,21)
	else:hud.reading(box,l.text,230)
	for i in range(l.options.size()):hud.button(box,l.options[i],letter_answer.bind(i),false,48)
	hud.button(box,"返回",letters_menu)

func letter_answer(index:int):
	var l=letters[letter_index]
	if index!=int(l.correct):
		var box=hud.modal("再想一下");hud.text(box,l.zh,21);hud.button(box,"回到来信",show_letter.bind(letter_index),true);hud.screen="letter_help";return
	speech.stop();sentence_words=Array(str(l.sentence).trim_suffix(".").split(" "));sentence_used=[];sentence_chosen=[];sentence_hint="";sentence_order=range(sentence_words.size());sentence_order.shuffle();show_sentence()

func show_sentence():
	var l=letters[letter_index];var box=hud.modal("把安排告诉伙伴");hud.screen="sentence"
	hud.text(box,l.sentence_zh,21)
	var line=" ".join(sentence_chosen)
	var phrase=hud.text(box,line if not line.is_empty() else "…",23,Color("287C69"));phrase.custom_minimum_size.y=96
	var flow=HFlowContainer.new();flow.add_theme_constant_override("h_separation",6);flow.add_theme_constant_override("v_separation",7);box.add_child(flow)
	for i in sentence_order:
		var b=hud.button(flow,sentence_words[i],select_word.bind(i),false,43);b.size_flags_horizontal=0;b.disabled=sentence_used.has(i)
	var hint_label=hud.text(box,sentence_hint if not sentence_hint.is_empty() else " ",18,Color("56776B"));hint_label.custom_minimum_size.y=52
	var r=hud.row(box)
	hud.button(r,"重排",func():sentence_used=[];sentence_chosen=[];show_sentence())
	hud.button(r,"看提示",func():sentence_hint=l.sentence;show_sentence())
	hud.button(box,"返回来信",show_letter.bind(letter_index))

func select_word(index:int):
	if sentence_used.has(index):return
	var expected=sentence_words[sentence_chosen.size()]
	if sentence_words[index]!=expected:sentence_hint="下一处是："+expected;show_sentence();return
	sentence_hint=""
	sentence_used.append(index);sentence_chosen.append(sentence_words[index])
	if sentence_chosen.size()==sentence_words.size():
		var l=letters[letter_index];learning.data.flags[l.flag]=true;save_progress();world.sync_buildings();hud.close();hud.toast(l.effect);play_fx("build");letter_index=-1
	else:show_sentence()

func lookup(word:String):
	var d=dictionary.get(word,{})
	var box=hud.modal(word);hud.screen="lookup"
	if not str(d.get("phonetic","")).is_empty():hud.text(box,str(d.phonetic),19,Color("6B8B86"))
	hud.text(box,str(d.get("translation","本地未收录这个词形，可查看整封信的译文。")),21)
	if learning.by_id.has(word):hud.button(box,"听发音",func():play_speech(learning.by_id[word].audio))
	hud.button(box,"继续阅读",show_letter.bind(letter_index),true)
