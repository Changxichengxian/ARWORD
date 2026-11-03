extends Control
class_name IslandHUD

const INK=Color("284852")
const CREAM=Color("FFF5DF")
const GREEN=Color("287C69")
var game
var card:PanelContainer
var card_open=false
var card_height=365.0
var card_shift=0.0
var card_tween:Tween
var body:VBoxContainer
var overlay:ColorRect
var sites:HBoxContainer
var site_buttons:Array=[]
var world_progress={}
var toast_label:Label
var toast_timer=0.0
var answers:Array=[]
var word_label:Button
var screen=""
var word_tween:Tween
var clock_label:Label
var clock_second=-1

func skin(color:Color,radius=18)->StyleBoxFlat:
	var s=StyleBoxFlat.new();s.bg_color=color;s.set_corner_radius_all(radius)
	s.content_margin_left=16;s.content_margin_right=16;s.content_margin_top=10;s.content_margin_bottom=10
	s.shadow_color=Color(0.02,.07,.10,.16);s.shadow_size=4;s.shadow_offset=Vector2(0,3);return s
func style_button(b:Button,primary=false):
	b.add_theme_stylebox_override("normal",skin(Color("E5EFE4") if not primary else Color("F3C671"),14))
	b.add_theme_stylebox_override("pressed",skin(Color("BFD9CE") if not primary else Color("DBAC56"),14))
	b.add_theme_stylebox_override("hover",skin(Color("EFF7EE") if not primary else Color("FFDA8E"),14))
	b.add_theme_stylebox_override("disabled",skin(Color("E9E5D7"),14))
	b.add_theme_color_override("font_color",INK);b.add_theme_color_override("font_hover_color",INK);b.add_theme_color_override("font_pressed_color",INK);b.add_theme_color_override("font_disabled_color",Color("8E9B8D"))
	b.add_theme_font_size_override("font_size",19);b.focus_mode=Control.FOCUS_NONE
func button(parent:Node,value:String,action:Callable,primary=false,height=48)->Button:
	var b=Button.new();b.text=value;b.custom_minimum_size=Vector2(0,height);b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	style_button(b,primary);parent.add_child(b);b.pressed.connect(action);return b
func ghost(parent:Node,value:String,action:Callable,height=40)->Button:
	var b=button(parent,value,action,false,height)
	for state in ["normal","hover","pressed","disabled"]:b.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	b.add_theme_font_size_override("font_size",16);b.add_theme_color_override("font_color",GREEN);return b
func icon(parent:Node,kind:String,action:Callable,hint:String)->IslandIcon:
	var b=IslandIcon.new();b.kind=kind;b.tooltip_text=hint;b.custom_minimum_size=Vector2(44,44);style_button(b);parent.add_child(b);b.pressed.connect(action);return b
func text(parent:Node,value:String,font_size=21,color=INK)->Label:
	var l=Label.new();l.text=value;l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;l.add_theme_font_size_override("font_size",font_size);l.add_theme_color_override("font_color",color);parent.add_child(l);return l
func row(parent:Node)->HBoxContainer:
	var r=HBoxContainer.new();r.add_theme_constant_override("separation",9);parent.add_child(r);return r
func spacer(parent:Node,height:int):var c=Control.new();c.custom_minimum_size.y=height;parent.add_child(c)
func divider(parent:Node):
	var line=HSeparator.new();var s=StyleBoxLine.new();s.color=Color("D6DFC9");s.thickness=1;line.add_theme_stylebox_override("separator",s);parent.add_child(line)

func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);mouse_filter=Control.MOUSE_FILTER_IGNORE
	var theme_new=Theme.new();theme_new.default_font=game.font;theme_new.default_font_size=20;theme=theme_new
	for id in game.world.markers:add_world_progress(id)
	var header=MarginContainer.new();add_child(header);header.anchor_right=1;header.offset_left=22;header.offset_right=-22;header.offset_top=24
	var top=row(header);var air=Control.new();air.size_flags_horizontal=Control.SIZE_EXPAND_FILL;top.add_child(air)
	for pair in [["headphones",game.toggle_listen,"听词"],["book",game.journal,"阅读"],["compass",game.recenter,"回到工地"],["gear",game.settings,"设置"]]:icon(top,pair[0],pair[1],pair[2])
	if not game.learning.wordbooks.books.is_empty():
		var books=icon(top,"books",game.show_wordbooks,"词书");top.move_child(books,1)
	toast_label=text(self,"",16,CREAM);toast_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;toast_label.anchor_left=.08;toast_label.anchor_right=.92;toast_label.offset_top=84;toast_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	clock_label=text(self,"",52,Color(.88,.94,1,.84));clock_label.autowrap_mode=TextServer.AUTOWRAP_OFF;clock_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;clock_label.anchor_left=.5;clock_label.anchor_right=.5;clock_label.anchor_top=.135;clock_label.anchor_bottom=.135;clock_label.offset_left=-150;clock_label.offset_right=150;clock_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	clock_label.add_theme_color_override("font_shadow_color",Color(.01,.025,.05,.75));clock_label.add_theme_constant_override("shadow_offset_x",1);clock_label.add_theme_constant_override("shadow_offset_y",2);clock_label.add_theme_constant_override("shadow_outline_size",3)
	sites=HBoxContainer.new();add_child(sites);sites.anchor_top=1;sites.anchor_bottom=1;sites.anchor_right=1;sites.offset_left=22;sites.offset_right=-22;sites.add_theme_constant_override("separation",9)
	sites.hide()
	card=PanelContainer.new();add_child(card);card.anchor_top=1;card.anchor_bottom=1;card.anchor_right=1;card.offset_left=16;card.offset_right=-16;card.offset_bottom=-20
	card.add_theme_stylebox_override("panel",skin(CREAM,26));body=VBoxContainer.new();body.add_theme_constant_override("separation",6);card.add_child(body)
	card.grow_vertical=Control.GROW_DIRECTION_BEGIN
	overlay=ColorRect.new();overlay.color=Color(.02,.08,.12,.66);overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);overlay.mouse_filter=Control.MOUSE_FILTER_STOP;add_child(overlay);overlay.hide()
	sync_goal()
func clear_body():
	for child in body.get_children():child.hide();child.queue_free()
	answers.clear();word_label=null
func layout_card(height:float):
	card_height=height
	position_card(card_shift)
	sites.offset_top=-height-80;sites.offset_bottom=-height-30
func position_card(shift:float):
	card_shift=shift;card.offset_top=-card_height-20+shift;card.offset_bottom=-20+shift
func set_card_open(open:bool,animate=true):
	if card_tween and card_tween.is_valid():card_tween.kill()
	card_open=open
	if not animate:
		card.visible=open;position_card(0);card.modulate.a=1 if open else 0;return
	if open and not card.visible:position_card(48);card.modulate.a=0;card.show()
	card_tween=create_tween();card_tween.set_parallel(true)
	card_tween.tween_method(position_card,card_shift,0.0 if open else 48.0,.32 if open else .28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT if open else Tween.EASE_IN_OUT)
	card_tween.tween_property(card,"modulate:a",1.0 if open else 0.0,.26)
	if not open:card_tween.chain().tween_callback(func():if not card_open:card.hide())
func sync_goal():
	for id in world_progress:
		var item=world_progress[id];var p=game.frontier.progress(id);var selected=id==game.frontier.data.active
		var ready=game.frontier.available(id);var done=game.frontier.done(id)
		item.title.text=game.frontier.facility_title(id) if done else game.frontier.title(id).trim_suffix(" · 自由照料")
		if not ready:
			var chapter=game.frontier.chapter(id)
			if chapter.has("gate"):p=Vector2(game.frontier.gate_count(chapter.gate),chapter.threshold)
		item.count.text="✓" if done else str(int(p.x))+"/"+str(int(p.y))
		item.bar.value=p.x/maxf(1,p.y)
		item.bar.get_theme_stylebox("fill").bg_color=Color("EBC673") if selected else Color("97C6B2") if ready else Color("7E999F")
		item.panel.modulate=Color.WHITE if selected else Color(1,1,1,.86)
		var quota=game.frontier.study_quota(id);var part=float(game.frontier.data.effort.get(id,0))
		item.small.visible=selected and ready and not done and quota>1
		item.small.text="这一步  "+str(roundi(part*quota))+" / "+str(quota)
		item.stepbar.visible=item.small.visible;item.stepbar.value=part
	update_world_progress()
func add_world_progress(id:String):
	var panel=PanelContainer.new();panel.name="WorldProgress_"+id;panel.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(panel)
	var background=skin(Color(.08,.20,.26,.88),9);background.content_margin_left=8;background.content_margin_right=8;background.content_margin_top=5;background.content_margin_bottom=5;background.shadow_size=2;panel.add_theme_stylebox_override("panel",background)
	var box=VBoxContainer.new();box.add_theme_constant_override("separation",3);panel.add_child(box)
	var line=row(box);line.add_theme_constant_override("separation",6)
	var title_label=text(line,"",13,CREAM);title_label.autowrap_mode=TextServer.AUTOWRAP_OFF
	var count_label=text(line,"",12,Color("EBC673"));count_label.autowrap_mode=TextServer.AUTOWRAP_OFF
	var progress=ProgressBar.new();progress.show_percentage=false;progress.custom_minimum_size.y=4;progress.max_value=1
	for pair in [["background",Color("42616A")],["fill",Color("EBC673")]]:
		var style=StyleBoxFlat.new();style.bg_color=pair[1];style.set_corner_radius_all(2);progress.add_theme_stylebox_override(pair[0],style)
	box.add_child(progress)
	var small=text(box,"",11,Color("BBDCD6"));small.autowrap_mode=TextServer.AUTOWRAP_OFF
	var stepbar=progress.duplicate();box.add_child(stepbar);stepbar.custom_minimum_size.y=3;stepbar.get_theme_stylebox("fill").bg_color=Color("EBC673")
	for child in panel.find_children("*","Control",true,false):child.mouse_filter=Control.MOUSE_FILTER_IGNORE
	world_progress[id]={"panel":panel,"title":title_label,"count":count_label,"bar":progress,"small":small,"stepbar":stepbar}
func update_world_progress():
	if not is_instance_valid(card) or not is_instance_valid(overlay):return
	for id in world_progress:
		var panel=world_progress[id].panel;var active=id==game.frontier.data.active
		panel.visible=not overlay.visible and game.frontier.previewable(id) and (active or not game.frontier.done(id))
		if not panel.visible:continue
		var marker=game.world.markers[id];var normal=game.world.globe.global_basis*marker.position.normalized()
		if normal.dot((game.camera.global_position-marker.global_position).normalized())<.20:panel.hide();continue
		var point=game.world.progress_anchor(id)
		if game.camera.is_position_behind(point):panel.hide();continue
		panel.reset_size();panel.position=game.camera.unproject_position(point)-Vector2(panel.size.x*.5,panel.size.y+8)
		var bottom=card.position.y-8 if card.visible else size.y-8
		# Never pin a label to the screen edge: it belongs to the object below it.
		if panel.position.x<5 or panel.position.x+panel.size.x>size.x-5 or panel.position.y<86 or panel.position.y+panel.size.y>bottom:panel.hide()

func task_heading(label:String):
	var r=row(body);text(r,label,15,GREEN).size_flags_horizontal=Control.SIZE_EXPAND_FILL
	if game.frontier.data.active=="mountain" and game.frontier.done("mountain"):icon(r,"telescope",game.open_observatory,"观测星云")
	if game.frontier.data.active in ["goldmine","smelter"]:
		ghost(r,"矿 "+str(game.frontier.data.voyage.ore)+" · 金 "+str(game.frontier.data.voyage.coins),game.show_rocket,30)
	if game.learning.data.dev_skip:icon(r,"skip",game.skip_learning,"跳过学习")
	return r
func show_task():
	clear_body();screen=game.mode
	if game.exploring and not (card_tween and card_tween.is_running()):card.hide()
	match game.mode:
		"word":show_word()
		"read":show_read()
		"listen":show_listen()
		"sentence":show_sentence()
func show_word():
	layout_card(365);var q=game.current;var r=task_heading(("听音 · " if game.learning.data.listen else "回忆 · ")+str(game.world.production_route.get("name","采集")))
	var star=icon(r,"star",game.bookmark,"收藏");star.lit=game.learning.data.bookmarks.has(q.id)
	word_label=ghost(body,"点一下，再听一遍" if game.learning.data.listen else q.word,game.speak_word,62);word_label.add_theme_font_size_override("font_size",28 if game.learning.data.listen else 34)
	if not game.learning.data.listen:
		var width=game.font.get_string_size(q.word,HORIZONTAL_ALIGNMENT_LEFT,-1,34).x
		word_label.add_theme_font_size_override("font_size",clampi(int(34*minf(1.0,(size.x-80)/maxf(1,width))),19,34))
	text(body,q.pos,14,Color("789087")).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var grid=GridContainer.new();grid.columns=2;grid.add_theme_constant_override("h_separation",10);grid.add_theme_constant_override("v_separation",9);body.add_child(grid)
	for i in range(4):
		var answer=game.order[i];var b=button(grid,q.options[answer],game.answer.bind(answer),false,57);b.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;b.custom_minimum_size.x=1;answers.append(b)
		if str(q.options[answer]).length()>18:b.add_theme_font_size_override("font_size",15)
	spacer(body,5);divider(body);ghost(body,"想不起来？看提示",game.reveal,35)
	if not game.exploring and (game.learning.data.listen or game.learning.data.speech):game.call_deferred("speak_word")
func show_help():
	clear_body();screen="help";layout_card(365);var q=game.current
	var r=row(body);word_label=ghost(r,q.word,game.speak_word,48);word_label.add_theme_font_size_override("font_size",30)
	if game.frontier.data.active in ["goldmine","smelter"]:
		ghost(r,"矿 "+str(game.frontier.data.voyage.ore)+" · 金 "+str(game.frontier.data.voyage.coins),game.show_rocket,30)
	if game.learning.data.dev_skip:icon(r,"skip",game.skip_learning,"跳过学习")
	text(body,q.zh,23,GREEN)
	if not str(q.get("example","")).is_empty():reading(body,q.example,72,20);text(body,q.translation,17,Color("70857B"))
	spacer(body,5);button(body,"遮住释义，再想一次",game.retry,true,47)
func show_read():
	layout_card(430);var m=game.mission;var r=task_heading(m.title)
	icon(r,"play",game.speak_task,"听这段");ghost(r,"展开" if game.short_reading else "短一点",game.toggle_short)
	if game.context_assisted:text(body,m.zh,18,GREEN).custom_minimum_size.y=135
	else:reading(body,m.short if game.short_reading else m.text,135,20)
	text(body,m.question,18)
	show_choices(m.options)
	divider(body);ghost(body,"读不懂？看译文",game.reveal,32)
func show_listen():
	layout_card(400);task_heading(game.mission.title+" · 听伙伴说")
	var r=row(body);var play=icon(r,"headphones",game.speak_task,"重播");play.custom_minimum_size=Vector2(74,68)
	ghost(r,"再听一遍",game.speak_task,64);ghost(r,"慢一点",game.speak_task.bind(true),64)
	if game.context_assisted:reading(body,game.mission.cue,68,19)
	else:text(body,"这次该怎么做？",23).custom_minimum_size.y=40
	show_choices(game.mission.cue_options)
	divider(body);ghost(body,"没听清？看看原文",game.reveal,32)
func show_choices(options:Array):
	for answer in game.order:
		var b=button(body,options[answer],game.answer.bind(answer),false,44);b.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;answers.append(b)
		for state in ["normal","hover","pressed","disabled"]:
			var style=b.get_theme_stylebox(state).duplicate();style.content_margin_top=6;style.content_margin_bottom=6;b.add_theme_stylebox_override(state,style)
func show_sentence():
	layout_card(375 if game.sentence_words.size()<=8 else 425);task_heading("把安排告诉伙伴")
	text(body,game.mission.sentence_zh,18)
	var phrase=text(body," ".join(game.sentence_chosen) if not game.sentence_chosen.is_empty() else "…",21,GREEN);phrase.custom_minimum_size.y=61
	var flow=HFlowContainer.new();flow.add_theme_constant_override("h_separation",7);flow.add_theme_constant_override("v_separation",7);flow.custom_minimum_size.y=97 if game.sentence_words.size()<=8 else 147;body.add_child(flow)
	for i in game.sentence_order:
		var b=button(flow,game.sentence_words[i],game.select_word.bind(i),false,42);b.size_flags_horizontal=0;b.disabled=game.sentence_used.has(i);b.add_theme_font_size_override("font_size",18)
	text(body,game.sentence_hint if not game.sentence_hint.is_empty() else " ",16,GREEN).custom_minimum_size.y=42
	divider(body);var r=row(body);ghost(r,"重新组织",game.sentence_reset,32);ghost(r,"提示",game.sentence_help,32)
func feedback(answer:int):
	for i in range(answers.size()):
		answers[i].disabled=true
		if game.order[i]==answer:
			var style=answers[i].get_theme_stylebox("disabled").duplicate();style.bg_color=Color("B6DDAC");answers[i].add_theme_stylebox_override("disabled",style)
func pulse_word():
	if not is_instance_valid(word_label):return
	if word_tween and word_tween.is_valid():word_tween.kill()
	word_label.pivot_offset=word_label.size*.5;word_label.scale=Vector2.ONE
	word_tween=create_tween();word_tween.tween_property(word_label,"scale",Vector2.ONE*1.035,.10);word_tween.tween_property(word_label,"scale",Vector2.ONE,.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
func modal(title:String,bottom=false,dim=true)->VBoxContainer:
	for child in overlay.get_children():child.hide();child.queue_free()
	overlay.color.a=.66 if dim else 0.0;overlay.show()
	var center=MarginContainer.new() if bottom else CenterContainer.new();center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);overlay.add_child(center)
	if bottom:center.offset_left=18;center.offset_right=-18;center.offset_bottom=-20
	var panel=PanelContainer.new();panel.custom_minimum_size.x=maxf(280,size.x-36);panel.add_theme_stylebox_override("panel",skin(CREAM,24));center.add_child(panel)
	if bottom:panel.size_flags_vertical=Control.SIZE_SHRINK_END
	var box=VBoxContainer.new();box.add_theme_constant_override("separation",12);panel.add_child(box)
	if not title.is_empty():text(box,title,26)
	return box
func parameter(parent:Node,label:String,key:String,limits:Vector2):
	var block=VBoxContainer.new();block.add_theme_constant_override("separation",0);parent.add_child(block)
	var line=row(block);var caption=text(line,label,17);caption.size_flags_horizontal=Control.SIZE_EXPAND_FILL;caption.autowrap_mode=TextServer.AUTOWRAP_OFF
	var number=text(line,"%.2f" % game.learning.data.space_settings[key],15,GREEN);number.autowrap_mode=TextServer.AUTOWRAP_OFF;number.custom_minimum_size.x=58;number.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	var slider=HSlider.new();slider.name="Space_"+key;slider.min_value=limits.x;slider.max_value=limits.y;slider.step=.05;slider.value=game.learning.data.space_settings[key];slider.custom_minimum_size.y=42;slider.focus_mode=Control.FOCUS_NONE;block.add_child(slider)
	var rail=StyleBoxFlat.new();rail.bg_color=Color("C5D8CD");rail.set_corner_radius_all(3);rail.content_margin_top=3;rail.content_margin_bottom=3;slider.add_theme_stylebox_override("slider",rail)
	var fill=rail.duplicate();fill.bg_color=GREEN;slider.add_theme_stylebox_override("grabber_area",fill);slider.add_theme_stylebox_override("grabber_area_highlight",fill)
	var knob_image=Image.create(24,24,false,Image.FORMAT_RGBA8)
	for y in range(24):
		for x in range(24):
			var distance=Vector2(x-11.5,y-11.5).length();var color=Color("F3C671") if distance<8.5 else GREEN;color.a=clampf(11.5-distance,0,1);knob_image.set_pixel(x,y,color)
	var knob=ImageTexture.create_from_image(knob_image);slider.add_theme_icon_override("grabber",knob);slider.add_theme_icon_override("grabber_highlight",knob)
	slider.value_changed.connect(func(value):number.text="%.2f" % value;game.set_space_parameter(key,value))
	slider.drag_ended.connect(func(_changed):game.save_progress())
func close():
	if screen=="space_settings":game.save_progress()
	overlay.hide();screen="help" if game.help_visible else game.mode
func reading(parent:Node,value:String,height=235,font_size=21):
	var rich=RichTextLabel.new();rich.bbcode_enabled=true;rich.custom_minimum_size.y=height;rich.scroll_active=true;rich.meta_underlined=false
	rich.add_theme_color_override("default_color",INK);rich.add_theme_font_size_override("normal_font_size",font_size)
	var regex=RegEx.new();regex.compile("[A-Za-z]+(?:'[A-Za-z]+)?");var result="";var last=0
	for m in regex.search_all(value):
		result+=value.substr(last,m.get_start()-last)+"[url="+m.get_string().to_lower()+"]"+m.get_string()+"[/url]";last=m.get_end()
	rich.text=result+value.substr(last);parent.add_child(rich);rich.meta_clicked.connect(func(word):game.lookup(str(word)))
func toast(value:String):toast_label.text=value;toast_timer=2.8
func _process(dt):
	toast_timer=maxf(0,toast_timer-dt);toast_label.modulate.a=minf(1,toast_timer)
	update_world_progress()
	clock_label.visible=game.exploring and not overlay.visible
	clock_label.modulate.a=1.0-card.modulate.a if card.visible else 1.0
	var second=int(Time.get_unix_time_from_system())
	if clock_label.visible and second!=clock_second:
		clock_second=second;var now=Time.get_datetime_dict_from_system();clock_label.text="%02d:%02d" % [now.hour,now.minute]
