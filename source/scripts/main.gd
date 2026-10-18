extends Node3D

const SAVE="user://frontier3d.json"
var font=preload("res://assets/fonts/FrontierSC.ttf")
var world:FrontierWorld
var player:FrontierFighter
var enemies:Array=[]
var bullets:Array=[]
var effects:Array=[]
var camera:Camera3D
var hud:FrontierHUD
var phase="camp"
var save_data={"version":1,"wood":0,"bridge":false,"wins":0,"band":3,"words":{},"checks":[],"sound":true,"read_words":0,"listen_count":0,"challenge":1,"next_lesson":0}
var lessons:Array=[]
var words:Array=[]
var dictionary:Dictionary={}
var lesson_index=0
var extended=false
var translated=false
var helped=false
var listened=false
var brief_open=false
var counters=0
var dodges=0
var hits=0
var shots=0
var camera_shake=0.0
var mouse_aim=Vector3.FORWARD
var mouse_fire=false
var keys_move=Vector2.ZERO
var elapsed=0.0
var speech:AudioStreamPlayer
var sound_pool:Array=[]
var sound_index=0
var sound_bank={}
var dodge_notice=0.0
var quiz={}
var quiz_bank:Array=[]
var battle_ended=false
var build_view=false
var qa_mode=false
var aim_dot:MeshInstance3D
var impact_pause=0.0
var approach=0
var last_back_msec=-1000

func _ready():
	randomize()
	font.fallbacks=[preload("res://assets/fonts/FrontierLatin.ttf")]
	get_tree().quit_on_go_back=false
	qa_mode="--qa" in OS.get_cmdline_user_args()
	read_save()
	lessons=JSON.parse_string(FileAccess.get_file_as_string("res://assets/lessons.json"))
	lesson_index=clampi(save_data.next_lesson,0,lessons.size()-1);extended=save_data.band>=5
	words=JSON.parse_string(FileAccess.get_file_as_string("res://assets/vocabulary.json"))
	dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/dictionary.json"))
	world=FrontierWorld.new();add_child(world);world.create(self,save_data.bridge)
	player=FrontierFighter.new();add_child(player);player.setup(self,true,0,Vector3(-.5,0,9))
	camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=15.5;camera.far=120;camera.near=.1;add_child(camera)
	camera.position=player.position+Vector3(0,18,16);camera.look_at(player.position);camera.current=true
	var layer=CanvasLayer.new();add_child(layer);hud=FrontierHUD.new();hud.game=self;layer.add_child(hud)
	speech=AudioStreamPlayer.new();add_child(speech)
	for i in range(10):var p=AudioStreamPlayer.new();add_child(p);sound_pool.append(p)
	for name in ["shoot","enemy","hit","hurt","dash","reload","click","boom","win","build"]:sound_bank[name]=load("res://assets/audio/"+name+".wav")
	var torus=TorusMesh.new();torus.inner_radius=.16;torus.outer_radius=.23;torus.rings=16;torus.ring_segments=6
	aim_dot=MeshInstance3D.new();aim_dot.mesh=torus;aim_dot.material_override=world.material(Color("ffe7a0"));add_child(aim_dot)
	hud.toast("左侧移动 · 右侧瞄准射击 · 闪避穿过弹幕")
	set_process_input(true)

func read_save():
	if qa_mode:return
	var data=null
	for path in [SAVE,SAVE+".bak"]:
		if not FileAccess.file_exists(path):continue
		var candidate=JSON.parse_string(FileAccess.get_file_as_string(path))
		if candidate is Dictionary and candidate.get("version",0)==1:data=candidate;break
	if data==null:return
	for key in save_data:
		if data.has(key) and typeof(data[key])==typeof(save_data[key]):save_data[key]=data[key]
	# JSON numbers are floats, including previously serialized integers.
	for key in ["wood","wins","band","read_words","listen_count","challenge","next_lesson"]:
		if data.get(key) is float or data.get(key) is int:save_data[key]=clampi(int(data[key]),0,1000000)
	save_data.band=clampi(save_data.band,0,7)
	save_data.challenge=clampi(save_data.challenge,0,2)
	save_data.next_lesson=clampi(save_data.next_lesson,0,5)

func save_progress():
	if qa_mode:return
	var f=FileAccess.open(SAVE+".tmp",FileAccess.WRITE)
	if f==null:return
	f.store_string(JSON.stringify(save_data));f.flush();f.close()
	if FileAccess.file_exists(SAVE):
		if FileAccess.file_exists(SAVE+".bak"):DirAccess.remove_absolute(SAVE+".bak")
		DirAccess.rename_absolute(SAVE,SAVE+".bak")
	DirAccess.rename_absolute(SAVE+".tmp",SAVE)

func _notification(what):
	if what==NOTIFICATION_WM_GO_BACK_REQUEST and is_instance_valid(hud):
		handle_back()
	if what==NOTIFICATION_APPLICATION_PAUSED:
		if is_instance_valid(hud):hud.clear_input();mouse_fire=false
		if is_instance_valid(speech):speech.stop()
		save_progress()
		if phase=="battle" and is_instance_valid(hud) and not hud.overlay.visible:call_deferred("pause_menu")

func handle_back():
	var now=Time.get_ticks_msec()
	if now-last_back_msec<150:return
	last_back_msec=now
	if hud.screen=="word" and brief_open:render_brief()
	elif phase=="result":return_camp()
	elif hud.overlay.visible:brief_open=false;speech.stop();hud.close()
	else:pause_menu()

func _input(event):
	if not is_instance_valid(hud):return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ESCAPE,KEY_BACK]:
		handle_back();get_viewport().set_input_as_handled();return
	hud.touch(event)
	if hud.overlay.visible:return
	if event is InputEventMouse and (event.device==-1 or OS.has_feature("android")):return
	if event is InputEventMouseMotion:
		var origin=camera.project_ray_origin(event.position);var normal=camera.project_ray_normal(event.position)
		var point=Plane(Vector3.UP,.9).intersects_ray(origin,normal)
		if point!=null:mouse_aim=(point-player.position).normalized();mouse_aim.y=0
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		mouse_fire=event.pressed
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_SPACE:do_dash()
		elif event.keycode==KEY_R:player.reload()
		elif event.keycode==KEY_ESCAPE:pause_menu()

func _physics_process(dt):
	if not is_instance_valid(player) or not is_instance_valid(hud):return
	dodge_notice=maxf(0,dodge_notice-dt)
	if hud.overlay.visible:
		mouse_fire=false
		camera_update(dt)
		return
	if impact_pause>0:
		impact_pause=maxf(0,impact_pause-dt);camera_update(dt);update_effects(dt);return
	var move=hud.move
	keys_move=Vector2(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W))).limit_length(1)
	if keys_move.length()>.05:move=keys_move
	if hud.aim.length()>.18:player.aim=Vector3(hud.aim.x,0,hud.aim.y).normalized()
	elif hud.fire:
		var nearest=nearest_enemy()
		if nearest:player.aim=(nearest.position-player.position).normalized();player.aim.y=0
	elif mouse_fire:player.aim=mouse_aim
	elif move.length()>.2:player.aim=Vector3(move.x,0,move.y).normalized()
	if phase in ["camp","battle"]:player.tick(dt,move,hud.fire or mouse_fire)
	if phase=="battle":
		elapsed+=dt
		for enemy in enemies:
			if is_instance_valid(enemy):enemy.tick(dt)
	update_bullets(dt)
	update_effects(dt)
	camera_update(dt)
	aim_dot.visible=phase in ["camp","battle"]
	aim_dot.position=player.position+player.aim*3+Vector3.UP*.06

func camera_update(dt):
	var target=Vector3(8.6,0,1) if build_view else player.position
	if phase=="battle" and not build_view:target+=player.aim*1.5
	var ideal=target+Vector3(0,18,16)
	camera.position=camera.position.lerp(ideal,minf(1,dt*7))
	camera.look_at(camera.position-Vector3(0,18,16))
	camera_shake=maxf(0,camera_shake-dt)
	if camera_shake>0:camera.h_offset=randf_range(-1,1)*camera_shake;camera.v_offset=randf_range(-1,1)*camera_shake*.6
	else:camera.h_offset=0;camera.v_offset=0

func nearest_enemy():
	var best=null;var distance=1000.0
	for e in enemies:
		if not is_instance_valid(e) or e.hp<=0:continue
		var d=player.position.distance_squared_to(e.position)
		if d<distance and line_clear(player.position+Vector3.UP,e.position+Vector3.UP):best=e;distance=d
	return best

func line_clear(a:Vector3,b:Vector3) -> bool:
	var query=PhysicsRayQueryParameters3D.create(a,b,2)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func fire(fighter:FrontierFighter):
	var direction=fighter.aim
	if not fighter.player:direction=direction.rotated(Vector3.UP,randf_range(-.10,.10))
	var start=fighter.position+Vector3.UP*.95+direction*.25
	var mesh=MeshInstance3D.new();var shape=BoxMesh.new();shape.size=Vector3(.11,.11,.55 if fighter.player else .38)
	mesh.mesh=shape;mesh.material_override=world.material(Color("ffed8c") if fighter.player else Color("fc8863"));add_child(mesh);mesh.position=start
	mesh.look_at(start+direction)
	bullets.append({"node":mesh,"velocity":direction*(25 if fighter.player else [11,13,15][save_data.challenge]),"source":fighter,"ttl":2.6,"damage":19 if fighter.player else [6,8,10][save_data.challenge],"exclude":[fighter.get_rid()]})
	if fighter.player:shots+=1;sfx("shoot",.30);camera_shake=maxf(camera_shake,.025)
	else:sfx("enemy",.18)
	burst(start,Color("ffdf72"),3,1.5)

func update_bullets(dt):
	for i in range(bullets.size()-1,-1,-1):
		var b=bullets[i];var n=b.node
		if not is_instance_valid(n):bullets.remove_at(i);continue
		var to=n.position+b.velocity*dt
		var query=PhysicsRayQueryParameters3D.create(n.position,to,3,b.exclude)
		var hit=get_world_3d().direct_space_state.intersect_ray(query)
		b.ttl-=dt
		if not hit.is_empty():
			var collider=hit.collider
			if collider is FrontierFighter:
				if is_instance_valid(b.source) and collider.player!=b.source.player:
					collider.hurt(b.damage,b.velocity.normalized(),b.source)
					if b.source==player:hits+=1
			elif collider.has_meta("breakable"):world.damage_prop(collider,b.damage)
			burst(hit.position,Color("ffe0a1"),3,1)
			b.ttl=0
		if b.ttl<=0:n.queue_free();bullets.remove_at(i)
		else:n.position=to

func do_dash():
	if hud.overlay.visible or not phase in ["battle","camp"]:return
	var move=hud.move if hud.move.length()>.1 else keys_move
	player.dash(Vector3(move.x,0,move.y) if move.length()>.1 else player.aim)

func perfect_dodge():
	if dodge_notice>0:return
	dodge_notice=.8;dodges+=1
	player.ammo=mini(player.capacity,player.ammo+1)
	float_text(player.position+Vector3.UP*2,"擦身闪避 +1 发",Color("9fffe6"));sfx("click",.7)

func explode(p:Vector3):
	sfx("boom",.8);camera_shake=.35;burst(p,Color("ffae4c"),26,8)
	for f in [player]+enemies:
		if is_instance_valid(f) and f.hp>0 and f.position.distance_to(p)<4.1:
			f.hurt(45,(f.position-p).normalized(),player)
	for prop in world.breakables:
		if is_instance_valid(prop) and float(prop.get_meta("hp",0))>0 and prop.position.distance_to(p)<3.2:
			world.damage_prop(prop,50)

func burst(p:Vector3,color:Color,count:int,speed:float):
	for i in range(count):
		if effects.size()>200:break
		var n=MeshInstance3D.new();var mesh=BoxMesh.new();mesh.size=Vector3.ONE*randf_range(.07,.18);n.mesh=mesh;n.material_override=world.material(color)
		add_child(n);n.position=p
		effects.append({"node":n,"v":Vector3(randf_range(-1,1),randf_range(.4,1.5),randf_range(-1,1))*speed,"life":randf_range(.2,.55),"text":false})

func float_text(p:Vector3,value:String,color:Color):
	var n=Label3D.new();n.font=font;n.text=value;n.font_size=40;n.pixel_size=.012;n.billboard=BaseMaterial3D.BILLBOARD_ENABLED;n.modulate=color;n.outline_size=8;n.no_depth_test=true
	add_child(n);n.position=p;effects.append({"node":n,"v":Vector3.UP*1.7,"life":.75,"text":true})

func update_effects(dt):
	for i in range(effects.size()-1,-1,-1):
		var e=effects[i];e.life-=dt
		if not is_instance_valid(e.node):effects.remove_at(i);continue
		if e.life<=0:e.node.queue_free();effects.remove_at(i);continue
		e.node.position+=e.v*dt
		if not e.text:e.v.y-=dt*16;e.node.rotate_x(dt*4);e.node.rotate_z(dt*3)
		else:e.node.modulate.a=minf(1,e.life*3)

func sfx(name:String,volume=.5):
	if not save_data.sound or not sound_bank.has(name):return
	var p=sound_pool[sound_index%sound_pool.size()];sound_index+=1;p.stream=sound_bank[name];p.volume_db=linear_to_db(volume);p.pitch_scale=randf_range(.96,1.04);p.play()

func living_enemies() -> int:
	var n=0
	for e in enemies:
		if is_instance_valid(e) and e.hp>0:n+=1
	return n

func fighter_down(f):
	if battle_ended:return
	if f==player:
		battle_ended=true;call_deferred("finish_battle",false)
	elif living_enemies()==0:
		battle_ended=true;call_deferred("finish_battle",true)
	else:
		player.hp=minf(100,player.hp+9)
		float_text(player.position+Vector3.UP*2,"+9",Color("a4f9b1"))

func clear_battle():
	for e in enemies:
		if is_instance_valid(e):e.queue_free()
	enemies.clear()
	for b in bullets:
		if is_instance_valid(b.node):b.node.queue_free()
	bullets.clear()

func start_battle():
	clear_battle();world.reset_cover();phase="battle";battle_ended=false
	player.hp=100;player.ammo=6;player.reload_left=0;player.cooldown=0;player.dash_cooldown=0;player.collision_layer=1;player.model.scale=Vector3.ONE;player.model.rotation.z=0
	player.position=Vector3(8.6,0,4.8) if save_data.bridge and approach==1 else Vector3(-.4,0,5.5)
	player.velocity=Vector3.ZERO;player.aim=Vector3.FORWARD
	player.reset_transients()
	counters=0;dodges=0;hits=0;shots=0;elapsed=0
	var positions=[Vector3(-.3,0,-3.7),Vector3(-5.3,0,-8.6),Vector3(5.8,0,-8.8)]
	for i in range(3):
		var e=FrontierFighter.new();add_child(e);e.setup(self,false,(i+lesson_index)%3,positions[i]);enemies.append(e)
	brief_open=false;build_view=false;speech.stop();hud.close();hud.toast("三发之后，抓住换弹空档")
	save_data.read_words+=str(current_text()).split(" ").size()
	save_progress()

func finish_battle(won:bool):
	phase="result";hud.clear_input();mouse_fire=false
	var reward=10 if won else 3
	save_data.wood+=reward
	if won:save_data.wins+=1;sfx("win",.65)
	if won:save_data.next_lesson=(lesson_index+1)%lessons.size()
	save_progress()
	var c=hud.card("据点拿下！" if won else "撤回整备，再找机会")
	hud.text(c,"木料 +%d   ·   换弹反击 %d 次   ·   闪避 %d 次"%[reward,counters,dodges],23)
	hud.text(c,"%d 秒   ·   命中 %d / %d"%[int(elapsed),hits,shots],19,Color("587273"))
	hud.button(c,"复盘这份情报",review_lesson,true)
	var r=hud.row(c);hud.button(r,"回营建设",return_camp);hud.button(r,"再来一局",next_brief)

func return_camp():
	clear_battle();phase="camp";battle_ended=false;build_view=false;brief_open=false
	lesson_index=save_data.next_lesson
	player.hp=100;player.ammo=6;player.reload_left=0;player.collision_layer=1;player.model.scale=Vector3.ONE;player.model.rotation.z=0
	player.position=Vector3(-.5,0,9);player.velocity=Vector3.ZERO
	player.reset_transients()
	hud.close();save_progress()

func next_brief():
	return_camp();show_brief()

func current_text() -> String:
	return lessons[lesson_index].long if extended else lessons[lesson_index].short

func show_brief():
	if phase=="battle":return
	brief_open=true;translated=false;helped=false;listened=false;build_view=false
	render_brief()

func render_brief():
	var lesson=lessons[lesson_index]
	var c=hud.card("情报 %d / %d  ·  %s"%[lesson_index+1,lessons.size(),lesson.title])
	hud.screen="brief"
	var tabs=hud.row(c)
	hud.button(tabs,"短篇" if not extended else "换短一点",func():extended=false;render_brief(),not extended)
	hud.button(tabs,"展开阅读",func():extended=true;render_brief(),extended)
	hud.button(tabs,"听情报",func():play_brief(1.0))
	hud.button(tabs,"慢速",func():play_brief(.8))
	if translated:hud.text(c,lesson.zh,21);helped=true
	else:hud.english(c,current_text(),230)
	if save_data.bridge:
		var routes=hud.row(c)
		hud.button(routes,"Central bridge",func():approach=0;render_brief(),approach==0)
		hud.button(routes,"East crossing",func():approach=1;render_brief(),approach==1)
	var r=hud.row(c)
	hud.button(r,"英文" if translated else "译文",func():translated=not translated;render_brief())
	hud.button(r,"出发交锋",start_battle,true)
	hud.button(r,"回营地",func():brief_open=false;speech.stop();hud.close())

func play_brief(speed:float):
	speech.stop();speech.stream=load("res://assets/audio/brief%d_%d.mp3"%[lesson_index,1 if extended else 0]);speech.pitch_scale=1.0
	# Godot AudioEffectPitchShift compensates slowed playback pitch.
	speech.pitch_scale=speed
	var bus=AudioServer.get_bus_index("Speech")
	if bus<0:
		AudioServer.add_bus();bus=AudioServer.bus_count-1;AudioServer.set_bus_name(bus,"Speech");AudioServer.add_bus_effect(bus,AudioEffectPitchShift.new())
	AudioServer.get_bus_effect(bus,0).pitch_scale=1.0/speed
	speech.bus="Speech";speech.play();listened=true;save_data.listen_count+=1;save_progress()

func review_lesson():
	var lesson=lessons[lesson_index];var c=hud.card("情报复盘")
	hud.text(c,lesson.question,26)
	for i in range(lesson.options.size()):hud.button(c,lesson.options[i],func():answer_lesson(i))
	hud.button(c,"回营地",return_camp)

func answer_lesson(index:int):
	var lesson=lessons[lesson_index];var right=index==int(lesson.correct)
	save_data.checks.append({"lesson":lesson_index,"right":right,"helped":helped,"listened":listened,"time":Time.get_unix_time_from_system()})
	if save_data.checks.size()>100:save_data.checks.pop_front()
	save_progress()
	var c=hud.card("理解到位" if right else "再看这个关系")
	hud.text(c,lesson.explain,24)
	hud.button(c,"把计划组织成一句话",sentence_lesson,true)
	hud.button(c,"回营地",return_camp)

func sentence_lesson():
	quiz={"sentence":lessons[lesson_index].sentence.split(" "),"picked":[],"order":[],"sentence_mode":true}
	for i in range(quiz.sentence.size()):quiz.order.append(i)
	quiz.order.shuffle();render_sentence()

func render_sentence():
	var c=hud.card("给同伴发计划")
	hud.text(c,lessons[lesson_index].sentence_zh,23)
	var selected=""
	for i in quiz.picked:selected+=quiz.sentence[i]+" "
	hud.text(c,selected if not selected.is_empty() else "点词块，组成你的计划。",26)
	var r=hud.row(c);var count=0
	for i in quiz.order:
		if i in quiz.picked:continue
		if count>0 and count%4==0:r=hud.row(c)
		hud.button(r,quiz.sentence[i],func():quiz.picked.append(i);render_sentence());count+=1
	var actions=hud.row(c)
	hud.button(actions,"撤回一个",func():if quiz.picked.size()>0:quiz.picked.pop_back();render_sentence())
	hud.button(actions,"发送",func():
		if sentence_matches():
			var box=hud.card("计划收到")
			hud.text(box,lessons[lesson_index].sentence,26)
			hud.button(box,"回营地",return_camp,true)
		else:hud.toast("再看一下顺序，已选词块可以撤回。")
	,true)
	hud.button(c,"回营地",return_camp)

func sentence_matches() -> bool:
	if quiz.picked.size()!=quiz.sentence.size():return false
	for i in range(quiz.picked.size()):
		if quiz.sentence[quiz.picked[i]]!=quiz.sentence[i]:return false
	return true

func word_card(word:String):
	helped=true
	var entry=dictionary.get(word,{"meaning":"暂未收录这个词形","phonetic":""})
	var c=hud.card(word)
	hud.screen="word"
	hud.text(c,str(entry.get("phonetic","")),22,Color("577b80"));hud.text(c,str(entry.meaning).left(260),23)
	var r=hud.row(c)
	hud.button(r,"已收藏" if save_data.words.has(word) else "收藏",func():save_data.words[word]=Time.get_unix_time_from_system();save_progress();word_card(word))
	if ResourceLoader.exists("res://assets/audio/x_"+word+".mp3"):
		hud.button(r,"发音",func():speech.stop();speech.bus="Master";speech.pitch_scale=1;speech.stream=load("res://assets/audio/x_"+word+".mp3");speech.play())
	hud.button(c,"继续阅读" if brief_open else "返回",render_brief if brief_open else learning_menu,true)

func learning_menu():
	var c=hud.card("英语手册")
	hud.text(c,"阅读接触 %d 词   ·   收藏 %d 个词"%[save_data.read_words,save_data.words.size()],21)
	var r=hud.row(c)
	hud.button(r,"测词义起点 · 24 题",func():begin_quiz(24),true)
	hud.button(r,"词语补给 · 5 题",func():begin_quiz(5))
	var index=0
	for word in save_data.words:
		if index>=6:break
		hud.button(c,word,func():word_card(word));index+=1
	if save_data.words.size()>6:hud.text(c,"显示最近收藏中的六个词",17)
	hud.button(c,"返回游戏",hud.close)

func begin_quiz(count:int):
	quiz={"n":0,"count":count,"right":0,"theta":float(save_data.band),"seen":[],"guessed":false}
	next_word()

func next_word():
	var band=clampi(roundi(quiz.theta),0,7);quiz_bank=[]
	for w in words:
		if int(w.band)==band and not w.id in quiz.seen:quiz_bank.append(w)
	if quiz_bank.is_empty():quiz_bank=words.duplicate()
	var q=quiz_bank.pick_random();quiz.q=q;quiz.seen.append(q.id);quiz.guessed=false
	var c=hud.card("词义起点  %d / %d"%[quiz.n+1,quiz.count])
	hud.text(c,q.word,40)
	hud.text(c,q.get("pos","常用词义"),18,Color("557478"))
	var indexes=[0,1,2,3];indexes.shuffle()
	for i in indexes:hud.button(c,q.options[i],func():word_answer(i==int(q.correct)))
	var r=hud.row(c)
	var guess=CheckBox.new();guess.text="这次是猜的";guess.add_theme_color_override("font_color",FrontierHUD.INK);r.add_child(guess);guess.toggled.connect(func(on):quiz.guessed=on)
	hud.button(r,"不认识",func():word_answer(false))
	hud.button(c,"暂时返回",learning_menu)

func word_answer(right:bool):
	var pass_answer=right and not quiz.guessed
	var probability=.25+.75/(1+exp((int(quiz.q.band)-quiz.theta)*1.25))
	quiz.theta=clampf(quiz.theta+(1.8 if quiz.n<6 else 1.0)*((1.0 if pass_answer else 0.0)-probability),-1,9)
	if pass_answer:quiz.right+=1
	quiz.n+=1
	if quiz.n<quiz.count:next_word();return
	if quiz.count>=24:
		save_data.band=clampi(roundi(quiz.theta),0,7);extended=save_data.band>=5
	save_progress()
	var c=hud.card("从这里继续")
	hud.text(c,"独立认出 %d / %d"%[quiz.right,quiz.count],28)
	hud.text(c,("已触及当前词库上限" if quiz.theta>7 else "后续选词从第 %d 档开始"%[save_data.band+1]) if quiz.count>=24 else "补给完成。可以回去交锋了。",23)
	hud.text(c,"这是词义抽样，不代表精确总词汇量。",18,Color("557478"))
	hud.button(c,"返回游戏",hud.close,true)

func build_menu():
	if phase!="camp":return
	build_view=true
	var c=hud.card("东侧栈桥")
	hud.text(c,"修通后，下一场可从侧翼进入据点。",25)
	if save_data.bridge:
		hud.text(c,"已建成，可以亲自走过去。",22)
		hud.button(c,"去桥边看看",func():build_view=false;player.position=Vector3(8.6,0,4.8);hud.close(),true)
	else:
		hud.text(c,"木料 %d / 8"%save_data.wood,24)
		hud.button(c,"开始修建",construct_bridge,true)
	hud.button(c,"返回",func():build_view=false;hud.close())

func construct_bridge():
	if save_data.bridge:return
	if save_data.wood<8:hud.toast("赢下一场交锋，就有足够木料。");return
	save_data.wood-=8;save_data.bridge=true;save_progress()
	approach=1
	hud.close();build_view=true;player.position=Vector3(8.6,0,5)
	world.construct();sfx("build",.8);hud.toast("侧路打通！亲自走过桥试试。")
	get_tree().create_timer(2.3).timeout.connect(func():build_view=false)

func pause_menu():
	if not is_instance_valid(hud):return
	speech.stop();var c=hud.card("歇一会儿")
	hud.button(c,"继续",hud.close,true)
	hud.button(c,"音效：开" if save_data.sound else "音效：关",func():save_data.sound=not save_data.sound;save_progress();pause_menu())
	if phase!="battle":hud.button(c,"交锋强度："+["练手","标准","挑战"][save_data.challenge],func():save_data.challenge=(save_data.challenge+1)%3;save_progress();pause_menu())
	hud.text(c,"左侧移动 · 拖右侧瞄准射击 · 点右侧可辅助瞄准\n闪避时短暂无伤，穿过弹幕补回一发。\n电脑：WASD 移动，鼠标瞄准/射击，空格闪避，R 换弹。",20)
	if phase=="battle":hud.button(c,"撤回营地",return_camp)
	hud.button(c,"关于这个样段",func():var box=hud.card("词境前线 3D · 0.3");hud.text(box,"真实三维场景 · 本地对手\n三种对手、六组情报、可修复侧桥。\n原始模型用 Blender 制作；引擎 Godot（MIT）。字体 Noto Sans SC（OFL）；词义 ECDICT（MIT）；语音 Kokoro 合成。",20);hud.button(box,"返回",pause_menu))

func resume_after_menu():
	keys_move=Vector2.ZERO;mouse_fire=false
