extends Control
class_name IslandHUD

const INK=Color("284852")
const CREAM=Color("FFF5DF")
const GREEN=Color("287C69")
var game
var card:PanelContainer
var body:VBoxContainer
var overlay:ColorRect
var sites:HBoxContainer
var site_buttons:Array=[]
var goal:Label
var bar:ProgressBar
var toast_label:Label
var toast_timer=0.0
var answers:Array=[]
var word_label:Button
var progress_label:Label
var screen=""
var stars:Array=[]
var word_tween:Tween

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
	var rng=RandomNumberGenerator.new();rng.seed=704
	for i in range(55):stars.append(Vector3(rng.randf(),rng.randf(),rng.randf_range(.7,1.7)))
	var header=MarginContainer.new();add_child(header);header.anchor_right=1;header.offset_left=22;header.offset_right=-22;header.offset_top=30
	var top=row(header);var titles=VBoxContainer.new();titles.size_flags_horizontal=Control.SIZE_EXPAND_FILL;top.add_child(titles)
	text(titles,"美术预览 · 不保存" if game.art_preview else "词屿 / LITTLE TIDE",11,Color("A6C6C6"));text(titles,"青芽星",28,CREAM)
	for pair in [["headphones",game.toggle_listen,"听词"],["book",game.journal,"工作手记"],["compass",game.recenter,"回到工地"],["gear",game.settings,"设置"]]:icon(top,pair[0],pair[1],pair[2])
	var goal_panel=PanelContainer.new();add_child(goal_panel);goal_panel.anchor_right=1;goal_panel.offset_left=22;goal_panel.offset_right=-22;goal_panel.offset_top=101
	goal_panel.add_theme_stylebox_override("panel",skin(Color(.08,.20,.26,.83),16))
	var box=VBoxContainer.new();box.add_theme_constant_override("separation",7);goal_panel.add_child(box)
	var gr=row(box);goal=text(gr,"",18,CREAM);goal.size_flags_horizontal=Control.SIZE_EXPAND_FILL;progress_label=text(gr,"",16,Color("F2CB7B"));progress_label.custom_minimum_size.x=66;progress_label.autowrap_mode=TextServer.AUTOWRAP_OFF;progress_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	bar=ProgressBar.new();bar.show_percentage=false;bar.custom_minimum_size.y=5;bar.max_value=1
	var track=skin(Color("2C5260"),3);var fill=skin(Color("EBC673"),3)
	for s in [track,fill]:s.content_margin_left=0;s.content_margin_right=0;s.content_margin_top=0;s.content_margin_bottom=0;s.shadow_size=0
	bar.add_theme_stylebox_override("background",track);bar.add_theme_stylebox_override("fill",fill);box.add_child(bar)
	toast_label=text(self,"",18,CREAM);toast_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;toast_label.anchor_left=.08;toast_label.anchor_right=.92;toast_label.offset_top=170;toast_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var view=icon(self,"planet",game.explore,"看看星球");view.anchor_left=1;view.anchor_right=1;view.offset_left=-66;view.offset_right=-22;view.offset_top=178;view.offset_bottom=222
	sites=HBoxContainer.new();add_child(sites);sites.anchor_top=1;sites.anchor_bottom=1;sites.anchor_right=1;sites.offset_left=22;sites.offset_right=-22;sites.add_theme_constant_override("separation",9)
	sites.hide()
	card=PanelContainer.new();add_child(card);card.anchor_top=1;card.anchor_bottom=1;card.anchor_right=1;card.offset_left=16;card.offset_right=-16;card.offset_bottom=-20
	card.add_theme_stylebox_override("panel",skin(CREAM,26));body=VBoxContainer.new();body.add_theme_constant_override("separation",6);card.add_child(body)
	overlay=ColorRect.new();overlay.color=Color(.02,.08,.12,.66);overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);overlay.mouse_filter=Control.MOUSE_FILTER_STOP;add_child(overlay);overlay.hide()
	sync_goal()
func _draw():
	for p in stars:
		if p.y*size.y*.8<190:draw_circle(Vector2(p.x*size.x,p.y*size.y*.8),p.z,Color(.65,.83,.87,.18))
func clear_body():
	for child in body.get_children():child.hide();child.queue_free()
	answers.clear();word_label=null
func layout_card(height:float):
	card.offset_top=-height-20;card.offset_bottom=-20
	sites.offset_top=-height-80;sites.offset_bottom=-height-30
func sync_goal():
	var id=str(game.frontier.data.active);var p=game.frontier.progress(id)
	goal.text=game.frontier.title(id)
	progress_label.text="✓" if game.frontier.done(id) else str(int(p.x))+" / "+str(int(p.y));bar.value=p.x/p.y

func task_heading(label:String):
	var r=row(body);text(r,label,15,GREEN).size_flags_horizontal=Control.SIZE_EXPAND_FILL
	return r
func show_task():
	clear_body();screen=game.mode;card.visible=not game.exploring
	match game.mode:
		"word":show_word()
		"read":show_read()
		"listen":show_listen()
		"sentence":show_sentence()
func show_word():
	layout_card(365);var q=game.current;var r=task_heading("听音 · 采集" if game.learning.data.listen else "回忆 · 采集")
	var star=icon(r,"star",game.bookmark,"收藏");star.lit=game.learning.data.bookmarks.has(q.id)
	word_label=ghost(body,"点一下，再听一遍" if game.learning.data.listen else q.word,game.speak_word,62);word_label.add_theme_font_size_override("font_size",28 if game.learning.data.listen else 34)
	text(body,q.pos,14,Color("789087")).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var grid=GridContainer.new();grid.columns=2;grid.add_theme_constant_override("h_separation",10);grid.add_theme_constant_override("v_separation",9);body.add_child(grid)
	for i in range(4):
		var answer=game.order[i];var b=button(grid,q.options[answer],game.answer.bind(answer),false,57);b.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;b.custom_minimum_size.x=1;answers.append(b)
	spacer(body,5);divider(body);ghost(body,"想不起来？看提示",game.reveal,35)
	if game.learning.data.listen or game.learning.data.speech:game.call_deferred("speak_word")
func show_help():
	clear_body();screen="help";layout_card(365);var q=game.current
	word_label=ghost(body,q.word,game.speak_word,48);word_label.add_theme_font_size_override("font_size",30)
	text(body,q.zh,23,GREEN);reading(body,q.example,72,20);text(body,q.translation,17,Color("70857B"))
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
func modal(title:String)->VBoxContainer:
	for child in overlay.get_children():child.hide();child.queue_free()
	overlay.show()
	if is_instance_valid(game.restore_button):game.restore_button.hide()
	var center=CenterContainer.new();center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);overlay.add_child(center)
	var panel=PanelContainer.new();panel.custom_minimum_size.x=maxf(280,size.x-36);panel.add_theme_stylebox_override("panel",skin(CREAM,24));center.add_child(panel)
	var box=VBoxContainer.new();box.add_theme_constant_override("separation",12);panel.add_child(box)
	if not title.is_empty():text(box,title,26)
	return box
func close():
	overlay.hide();screen="help" if game.help_visible else game.mode
	if is_instance_valid(game.restore_button):game.restore_button.visible=game.exploring
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
