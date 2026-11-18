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
var card_scroll:ScrollContainer
var overlay:ColorRect
var sites:HBoxContainer
var site_buttons:Array=[]
var world_progress={}
var toast_label:Label
var toast_timer=0.0
var answers:Array=[]
var word_label:Button
var word_submit:Button
var word_selection_count:Label
var word_meaning:Label
var word_inventory:Button
var word_footer:HBoxContainer
var word_grid:GridContainer
var word_help:Button
var screen=""
var word_tween:Tween
var clock_label:Label
var clock_second=-1
var search_button:Button
var books_button:Button
var settings_button:Button

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
func word_button(parent:Node,value:String,word:String,height=62)->Button:
	var b=preload("res://scripts/word_button.gd").new();b.text=value;b.custom_minimum_size=Vector2(0,height);b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	style_button(b);parent.add_child(b)
	for state in ["normal","hover","pressed","disabled"]:b.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	b.add_theme_color_override("font_color",GREEN);b.tooltip_text="轻点发音，长按查看释义和例句"
	b.short_pressed.connect(game.speak_word);b.held.connect(game.lookup.bind(word))
	return b
func icon(parent:Node,kind:String,action:Callable,hint:String)->IslandIcon:
	var b=IslandIcon.new();b.kind=kind;b.tooltip_text=hint;b.custom_minimum_size=Vector2(44,44);style_button(b);parent.add_child(b);b.pressed.connect(action);return b
func text(parent:Node,value:String,font_size=21,color=INK)->Label:
	var l=Label.new();l.text=value;l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;l.add_theme_font_size_override("font_size",font_size);l.add_theme_color_override("font_color",color);parent.add_child(l);return l
func row(parent:Node)->HBoxContainer:
	var r=HBoxContainer.new();r.add_theme_constant_override("separation",9);parent.add_child(r);return r
func spacer(parent:Node,height:int):var c=Control.new();c.custom_minimum_size.y=height;parent.add_child(c)
func divider(parent:Node):
	var line=HSeparator.new();var s=StyleBoxLine.new();s.color=Color("D6DFC9");s.thickness=1;line.add_theme_stylebox_override("separator",s);parent.add_child(line)

func scroll_body(scroll:ScrollContainer,separation:int)->VBoxContainer:
	# A scroll viewport clips drawing outside its bounds, including button shadows.
	var inset=MarginContainer.new()
	inset.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	for side in ["left","right"]:inset.add_theme_constant_override("margin_"+side,5)
	inset.add_theme_constant_override("margin_top",2)
	inset.add_theme_constant_override("margin_bottom",8)
	scroll.add_child(inset)
	var box=VBoxContainer.new()
	box.add_theme_constant_override("separation",separation)
	inset.add_child(box)
	return box

func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);mouse_filter=Control.MOUSE_FILTER_IGNORE
	var theme_new=Theme.new();theme_new.default_font=game.font;theme_new.default_font_size=20;theme=theme_new
	safe_frame=Control.new();safe_frame.name="SafeContent";safe_frame.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(safe_frame);safe_frame.clip_contents=true
	refresh_safe_area();get_viewport().size_changed.connect(refresh_safe_area)
	header=MarginContainer.new();safe_frame.add_child(header);header.anchor_right=1;header.offset_left=22;header.offset_right=-22;header.offset_top=24
	var top=row(header);top.add_theme_constant_override("separation",8)
	search_button=icon(top,"search",game.show_word_search,"搜索英文或中文")
	search_button.name="QuickSearch";search_button.caption="搜英文 / 中文";search_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;search_button.custom_minimum_size=Vector2(156,48)
	books_button=icon(top,"books",game.show_wordbooks,"词书");settings_button=icon(top,"gear",game.settings,"设置")
	for button in [search_button,books_button,settings_button]:
		button.custom_minimum_size.y=48
		button.add_theme_stylebox_override("normal",skin(Color("E2F3ED") if button==search_button else Color("FFF0D7"),24))
		button.add_theme_stylebox_override("hover",skin(Color("F0FFF7"),24))
		button.add_theme_stylebox_override("pressed",skin(Color("BEDDD6"),24))

	toast_label=text(safe_frame,"",16,CREAM);toast_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;toast_label.anchor_left=.08;toast_label.anchor_right=.92;toast_label.offset_top=84;toast_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	clock_label=text(safe_frame,"",52,Color(.88,.94,1,.84));clock_label.autowrap_mode=TextServer.AUTOWRAP_OFF;clock_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;clock_label.anchor_left=.5;clock_label.anchor_right=.5;clock_label.anchor_top=.19;clock_label.anchor_bottom=.19;clock_label.offset_left=-150;clock_label.offset_right=150;clock_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	clock_label.add_theme_color_override("font_shadow_color",Color(.01,.025,.05,.75));clock_label.add_theme_constant_override("shadow_offset_x",1);clock_label.add_theme_constant_override("shadow_offset_y",2);clock_label.add_theme_constant_override("shadow_outline_size",3)
	sites=HBoxContainer.new();safe_frame.add_child(sites);sites.anchor_top=1;sites.anchor_bottom=1;sites.anchor_right=1;sites.offset_left=22;sites.offset_right=-22;sites.add_theme_constant_override("separation",9)
	sites.hide()
	card=PanelContainer.new();safe_frame.add_child(card);card.anchor_top=1;card.anchor_bottom=1;card.anchor_right=1;card.offset_left=16;card.offset_right=-16;card.offset_bottom=-20
	card.add_theme_stylebox_override("panel",skin(CREAM,26));card_scroll=ScrollContainer.new();card_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;card.add_child(card_scroll)
	body=scroll_body(card_scroll,6)
	card.grow_vertical=Control.GROW_DIRECTION_BEGIN
	card.minimum_size_changed.connect(func():position_card(card_shift),CONNECT_DEFERRED)
	body.minimum_size_changed.connect(func():position_card(card_shift),CONNECT_DEFERRED)
	overlay=ColorRect.new();overlay.color=Color(.02,.08,.12,.66);overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);overlay.mouse_filter=Control.MOUSE_FILTER_STOP;add_child(overlay);overlay.hide()
	sync_goal()
func attach_world():
	for id in game.world.markers:
		if not world_progress.has(id):add_world_progress(id)
	sync_goal()

func set_world_ready(ready:bool):
	books_button.disabled=false;settings_button.disabled=false
	clock_label.visible=ready and game.exploring and not overlay.visible

func clear_body():
	card_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO
	body.add_theme_constant_override("separation",6)
	var panel=card.get_theme_stylebox("panel");panel.content_margin_left=16;panel.content_margin_right=16
	card_scroll.scroll_vertical=0
	for child in body.get_children():child.hide();child.queue_free()
	word_grid=null;word_footer=null;word_meaning=null;word_inventory=null;answers.clear();word_label=null;word_submit=null;word_selection_count=null;word_help=null
func layout_card(height:float):
	card_height=height
	position_card(card_shift)
func position_card(shift:float):
	card_shift=shift
	var height=minf(card_height,maxf(1,safe_rect.size.y-98))
	if card_scroll.vertical_scroll_mode==ScrollContainer.SCROLL_MODE_DISABLED:
		height=maxf(height,body.get_parent().get_combined_minimum_size().y+card.get_theme_stylebox("panel").get_minimum_size().y)
	card.offset_bottom=-20+shift
	card.offset_top=-20+shift-height
	sites.offset_top=card.offset_top-60;sites.offset_bottom=card.offset_top-10
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
signal safe_rect_changed(rect:Rect2)
const SafeArea=preload("res://scripts/safe_area.gd")
var safe_frame:Control
var safe_rect=Rect2()
var layout_timer=0.
var active_panel:PanelContainer
var active_center:Container
var active_scroll:ScrollContainer
var active_box:VBoxContainer
var header:MarginContainer
func refresh_safe_area():
	apply_safe_rect(SafeArea.current(get_viewport()))

func apply_safe_rect(rect:Rect2):
	if not rect.has_area() or (rect.is_equal_approx(safe_rect) and safe_frame.size.is_equal_approx(rect.size)):return
	safe_rect=rect;safe_frame.position=rect.position;safe_frame.size=rect.size
	if is_instance_valid(card):
		fit_word_controls()
		position_card(card_shift)
	if is_instance_valid(active_panel):fit_modal()
	safe_rect_changed.emit(rect)

func fit_modal():
	if not is_instance_valid(active_center) or active_center.is_queued_for_deletion():return
	var rect=safe_rect.grow_individual(-18,-12,-18,-20)
	if OS.has_feature("android") and screen=="search" and DisplayServer.virtual_keyboard_get_height()>0:
		var pixel_height=maxf(1,DisplayServer.window_get_size().y)
		rect.size.y=maxf(160,rect.size.y-DisplayServer.virtual_keyboard_get_height()*get_viewport_rect().size.y/pixel_height)
	active_panel.custom_minimum_size.x=rect.size.x
	active_scroll.custom_minimum_size.y=clampf(active_box.get_parent().get_combined_minimum_size().y,1,maxf(1,rect.size.y-24))
	active_center.position=rect.position;active_center.size=rect.size

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
		item.panel.reset_size()
	update_world_progress()
func add_world_progress(id:String):
	var panel=PanelContainer.new();panel.name="WorldProgress_"+id;panel.mouse_filter=Control.MOUSE_FILTER_IGNORE;safe_frame.add_child(panel)
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
	# Text, theme and child visibility change layout; moving the globe does not.
	panel.minimum_size_changed.connect(panel.reset_size,CONNECT_DEFERRED)
func update_world_progress():
	if not is_instance_valid(card) or not is_instance_valid(overlay):return
	if not game.scene_ready or not is_instance_valid(game.camera) or not is_instance_valid(game.world):
		for item in world_progress.values():item.panel.hide()
		return
	var camera=game.camera
	var camera_position=camera.global_position
	var globe_basis=game.world.globe.global_basis
	var bottom=card.position.y-8 if card.visible else safe_rect.size.y-8
	for id in world_progress:
		var panel=world_progress[id].panel;var active=id==game.frontier.data.active
		var display=not overlay.visible and game.frontier.previewable(id) and (active or not game.frontier.done(id))
		if display:
			var marker=game.world.markers[id];var normal=globe_basis*marker.position.normalized()
			display=normal.dot((camera_position-marker.global_position).normalized())>=.20
		if display:
			var point=game.world.progress_anchor(id)
			display=not camera.is_position_behind(point)
			if display:
				var position=camera.unproject_position(point)-safe_rect.position-Vector2(panel.size.x*.5,panel.size.y+8)
				# Never pin a label to the screen edge: it belongs to the object below it.
				display=position.x>=5 and position.x+panel.size.x<=safe_rect.size.x-5 and position.y>=86 and position.y+panel.size.y<=bottom
				if display:panel.position=position
		# Apply the final result once. Occluded labels must not show/hide every frame.
		panel.visible=display

func task_heading(label:String):
	var r=row(body);text(r,label,15,GREEN).size_flags_horizontal=Control.SIZE_EXPAND_FILL
	if game.frontier.data.active in ["goldmine","smelter"]:
		word_inventory=ghost(r,"矿 "+str(game.frontier.data.voyage.ore)+" · 金 "+str(game.frontier.data.voyage.coins),game.show_rocket,30)
		word_inventory.size_flags_horizontal=Control.SIZE_SHRINK_END
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
	card_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	var q=game.current
	if q.is_empty():
		layout_card(205)
		task_heading("单词")
		text(body,"本书的单词已学会",22).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		button(body,"换词书",game.select_book_panel,true)
		return
	var intro=game.introducing()
	var multi=game.word_senses.is_multi(q)
	layout_card(1)
	var kind=str(q.get("review_kind","text"))
	var listen=kind=="audio" and not intro
	var reverse=kind=="reverse" and not intro
	var state=game.learning.data.words.get(q.id,{})
	var title="新词" if intro else ("复习 "+str(int(state.get("review_round",0))+1)+"/3" if state.has("review_at") else "到期复习")
	if state.has("spot_hits"):title="回忆"
	var r=task_heading(title+(" · "+{"audio":"听音选意","text":"看词选意","reverse":"看意选词"}[kind] if not intro else ""))
	var star=icon(r,"star",game.bookmark,"收藏");star.lit=game.learning.data.bookmarks.has(q.id)
	if reverse:
		word_meaning=text(body,q.zh,25,GREEN);word_meaning.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	else:
		word_label=word_button(body,"点一下，再听一遍" if listen else q.word,q.id);word_label.add_theme_font_size_override("font_size",28 if listen else 34)
	if is_instance_valid(word_label):
		word_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		word_label.custom_minimum_size.y=44
	if not multi or not intro:
		text(body,q.pos,14,Color("789087")).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	if intro:
		text(body,"\n".join(q.sense_labels) if multi else q.options[int(q.correct)],21 if multi else 23).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		var actions=row(body)
		button(actions,"记好了",game.introduce_word.bind(q.id),true)
		button(actions,"学会",game.introduce_word.bind(q.id,true))
		fit_word_controls()
		if not game.exploring and game.word_should_autoplay():game.call_deferred("speak_word")
		return
	word_grid=GridContainer.new();word_grid.columns=2
	word_grid.add_theme_constant_override("h_separation",8);word_grid.add_theme_constant_override("v_separation",6)
	body.add_child(word_grid)
	for answer in game.order:
		var b=button(word_grid,q.options[answer],game.toggle_word_answer.bind(answer) if multi else game.answer.bind(answer),false,44)
		b.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;b.custom_minimum_size.x=1;answers.append(b)
	word_footer=row(body)
	word_help=ghost(word_footer,"看提示",game.reveal,40)
	if multi:
		word_selection_count=text(word_footer,"",15,GREEN)
		word_selection_count.autowrap_mode=TextServer.AUTOWRAP_OFF
		word_submit=button(word_footer,"确认",game.submit_word_answers,true,44);word_submit.name="WordSubmit"
		update_word_selection()
	fit_word_controls()
	if not game.exploring and game.word_should_autoplay() and game.review_feedback.is_empty():game.call_deferred("speak_word")

func show_word_feedback(selected:int,correct:bool):
	if not game.current.has("option_words"):
		if game.word_review.entries.is_empty():game.word_review.setup(game.learning.by_id)
		game.current=game.word_review.prepare(game.current,str(game.current.get("review_kind","text")),game.learning.active_bank)
	clear_body();show_word()
	var q=game.current
	if is_instance_valid(word_label):word_label.text=q.word
	if is_instance_valid(word_meaning):word_meaning.text=q.word
	word_footer.hide()
	var expected:Array=q.get("correct_indices",[int(q.correct)])
	for i in answers.size():
		var index=game.order[i];var b=answers[i]
		b.text=str(q.option_meanings[index])+"\n"+str(q.option_words[index])
		b.disabled=true
		b.add_theme_color_override("font_disabled_color",INK)
		var style=b.get_theme_stylebox("disabled").duplicate()
		if expected.has(index):style.bg_color=Color("B6DDAC")
		elif index==selected or game.word_selected.has(index):style.bg_color=Color("F3C4B9")
		b.add_theme_stylebox_override("disabled",style)
	text(body,"轻点任意处，继续" if correct else "看看对应的单词 · 轻点任意处再试一次",16,GREEN).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	fit_word_controls()

func fit_word_controls():
	if not is_instance_valid(card_scroll) or card_scroll.vertical_scroll_mode!=ScrollContainer.SCROLL_MODE_DISABLED:return
	var compact=safe_rect.size.x<410 or safe_rect.size.y<600
	var panel=card.get_theme_stylebox("panel")
	panel.content_margin_left=10 if compact else 16;panel.content_margin_right=panel.content_margin_left
	body.add_theme_constant_override("separation",3 if compact else 6)
	if is_instance_valid(word_inventory):
		var stock="矿 %d · 金 %d" % [game.frontier.data.voyage.ore,game.frontier.data.voyage.coins]
		word_inventory.text="库存" if compact else stock;word_inventory.tooltip_text=stock
	if is_instance_valid(word_meaning):word_meaning.add_theme_font_size_override("font_size",19 if compact else 25)
	var width=safe_rect.size.x+card.offset_right-card.offset_left-card.get_theme_stylebox("panel").get_minimum_size().x-10.
	if is_instance_valid(word_label):
		var available=width
		if word_label.get_parent() is HBoxContainer:
			for control in word_label.get_parent().get_children():
				if control!=word_label:available-=control.get_combined_minimum_size().x+9
		var measured=game.font.get_string_size(word_label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,32).x
		word_label.add_theme_font_size_override("font_size",clampi(floori(32*available/maxf(measured,1)),17,32))
	if not is_instance_valid(word_grid):return
	var column=floorf((width-word_grid.get_theme_constant("h_separation"))/2.)
	for b in answers:
		var font_size=15 if compact else 16 if b.disabled or column<160 or b.text.length()>16 else 19
		b.add_theme_font_size_override("font_size",font_size)
		for state in ["normal","pressed","hover","disabled"]:
			var box=b.get_theme_stylebox(state)
			box.content_margin_left=8 if compact else 14;box.content_margin_right=box.content_margin_left
			box.content_margin_top=4 if compact else 8;box.content_margin_bottom=box.content_margin_top
		var style=b.get_theme_stylebox("disabled" if b.disabled else "normal")
		var interior=maxf(1,column-style.get_minimum_size().x)
		var lines=game.font.get_multiline_string_size(b.text,HORIZONTAL_ALIGNMENT_CENTER,interior,font_size)
		b.custom_minimum_size.y=maxf(44,ceilf(lines.y)+style.get_minimum_size().y+2)
func show_help():
	clear_body();screen="help";card_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;layout_card(1);var q=game.current
	var r=row(body);word_label=word_button(r,q.word,q.id,48);word_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;word_label.add_theme_font_size_override("font_size",30)
	if game.frontier.data.active in ["goldmine","smelter"]:
		word_inventory=ghost(r,"矿 "+str(game.frontier.data.voyage.ore)+" · 金 "+str(game.frontier.data.voyage.coins),game.show_rocket,30)
		word_inventory.size_flags_horizontal=Control.SIZE_SHRINK_END
	if game.learning.data.dev_skip:icon(r,"skip",game.skip_learning,"跳过学习")
	text(body,"\n".join(q.sense_labels) if game.word_senses.is_multi(q) else q.zh,21,GREEN)
	if not str(q.get("example","")).is_empty():reading(body,q.example,0,19);text(body,q.translation,17,Color("70857B"))
	button(body,"遮住释义，再想一次",game.retry,true,47);fit_word_controls()
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
	if is_instance_valid(word_submit):word_submit.disabled=true
	for i in range(answers.size()):
		answers[i].disabled=true
		if game.order[i]==answer or (game.mode=="word" and game.current.get("correct_indices",[]).has(game.order[i])):
			var style=answers[i].get_theme_stylebox("disabled").duplicate();style.bg_color=Color("B6DDAC");answers[i].add_theme_stylebox_override("disabled",style)
func update_word_selection():
	if not is_instance_valid(word_submit) or not is_instance_valid(word_selection_count):return
	var count=game.current.correct_indices.size()
	word_selection_count.text="选 %d 项 · %d/%d" % [count,game.word_selected.size(),count]
	word_submit.disabled=game.word_selected.size()!=count or game.locked
	for i in range(answers.size()):
		var selected=game.word_selected.has(game.order[i]);var b=answers[i]
		b.text=("✓ " if selected else "")+str(game.current.options[game.order[i]])
		b.add_theme_stylebox_override("normal",skin(Color("BFD9CE") if selected else Color("E5EFE4"),14))
	fit_word_controls()
func pulse_word():
	if not is_instance_valid(word_label):return
	if word_tween and word_tween.is_valid():word_tween.kill()
	word_label.pivot_offset=word_label.size*.5;word_label.scale=Vector2.ONE
	word_tween=create_tween();word_tween.tween_property(word_label,"scale",Vector2.ONE*(1.+minf(.035,8./maxf(1,word_label.size.x))),.10);word_tween.tween_property(word_label,"scale",Vector2.ONE,.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
func modal(title:String,bottom=false,dim=true)->VBoxContainer:
	for child in overlay.get_children():child.hide();child.queue_free()
	overlay.color.a=.66 if dim else 0.0;overlay.show()
	var center=MarginContainer.new() if bottom else CenterContainer.new()
	overlay.add_child(center);active_center=center
	var panel=PanelContainer.new();panel.add_theme_stylebox_override("panel",skin(CREAM,24));center.add_child(panel)
	if bottom:panel.size_flags_vertical=Control.SIZE_SHRINK_END
	active_panel=panel
	active_scroll=ScrollContainer.new();active_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;panel.add_child(active_scroll)
	var box=scroll_body(active_scroll,12)
	active_box=box;box.minimum_size_changed.connect(fit_modal,CONNECT_DEFERRED)
	fit_modal()
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
	var rich=RichTextLabel.new();rich.bbcode_enabled=true;rich.custom_minimum_size.y=height;rich.fit_content=height==0;rich.scroll_active=height>0;rich.meta_underlined=false
	rich.add_theme_color_override("default_color",INK);rich.add_theme_font_size_override("normal_font_size",font_size)
	var regex=RegEx.new();regex.compile("[A-Za-z]+(?:'[A-Za-z]+)?");var result="";var last=0
	for m in regex.search_all(value):
		result+=value.substr(last,m.get_start()-last)+"[url="+m.get_string().to_lower()+"]"+m.get_string()+"[/url]";last=m.get_end()
	rich.text=result+value.substr(last);parent.add_child(rich);rich.meta_clicked.connect(func(word):game.lookup(str(word)))
func toast(value:String):toast_label.text=value;toast_timer=2.8
func _process(dt):
	if OS.has_feature("android"):
		layout_timer-=dt
		if layout_timer<=0.:
			layout_timer=.35;refresh_safe_area()
			if screen=="search" and overlay.visible:fit_modal()
	toast_timer=maxf(0,toast_timer-dt);toast_label.modulate.a=minf(1,toast_timer)
	update_world_progress()
	clock_label.visible=game.scene_ready and game.exploring and not overlay.visible
	clock_label.modulate.a=1.0-card.modulate.a if card.visible else 1.0
	var second=int(Time.get_unix_time_from_system())
	if clock_label.visible and second!=clock_second:
		clock_second=second;var now=Time.get_datetime_dict_from_system();clock_label.text="%02d:%02d" % [now.hour,now.minute]
