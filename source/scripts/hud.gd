extends Control
class_name FrontierHUD

var game
var overlay:ColorRect
var panel_box:VBoxContainer
var health:Label
var status:Label
var objective:Label
var toast_label:Label
var camp_buttons:HBoxContainer
var left_id=-1
var right_id=-1
var move=Vector2.ZERO
var aim=Vector2.ZERO
var fire=false
var toast_time=0.0
var stick_left=Vector2.ZERO
var stick_right=Vector2.ZERO
var menu_button:Button
var dictionary_button:Button
var paused=false
var screen=""
const INK=Color("17313d")
const NAVY=Color("203c49")
const YELLOW=Color("ffd56a")

func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	var theme_new=Theme.new();theme_new.default_font=game.font;theme_new.default_font_size=22;theme=theme_new
	health=label_at(Vector2(26,19),24)
	status=label_at(Vector2(26,90),19)
	objective=label_at(Vector2(0,22),23);objective.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	objective.anchor_left=.35;objective.anchor_right=.65;objective.offset_left=0;objective.offset_right=0
	toast_label=label_at(Vector2(0,110),26);toast_label.anchor_left=.2;toast_label.anchor_right=.8;toast_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	menu_button=Button.new();menu_button.text="Ⅱ";add_child(menu_button);menu_button.anchor_left=1;menu_button.anchor_right=1
	menu_button.offset_left=-76;menu_button.offset_right=-22;menu_button.offset_top=20;menu_button.offset_bottom=68;style_button(menu_button,false)
	menu_button.pressed.connect(game.pause_menu)
	dictionary_button=Button.new();dictionary_button.text="Aa";add_child(dictionary_button);dictionary_button.anchor_left=1;dictionary_button.anchor_right=1
	dictionary_button.offset_left=-146;dictionary_button.offset_right=-88;dictionary_button.offset_top=20;dictionary_button.offset_bottom=68;style_button(dictionary_button,false)
	dictionary_button.pressed.connect(game.learning_menu)
	camp_buttons=HBoxContainer.new();add_child(camp_buttons);camp_buttons.anchor_left=.5;camp_buttons.anchor_right=.5;camp_buttons.anchor_top=1;camp_buttons.anchor_bottom=1
	camp_buttons.offset_left=-245;camp_buttons.offset_right=245;camp_buttons.offset_top=-98;camp_buttons.offset_bottom=-34;camp_buttons.add_theme_constant_override("separation",12)
	button(camp_buttons,"出发交锋",game.show_brief,true)
	button(camp_buttons,"修建侧桥",game.build_menu,false)
	overlay=ColorRect.new();overlay.color=Color(0.025,.08,.12,.67);overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter=Control.MOUSE_FILTER_STOP;add_child(overlay);overlay.hide()
	move_child(toast_label,-1);toast_label.mouse_filter=Control.MOUSE_FILTER_IGNORE

func label_at(p:Vector2,font_size:int) -> Label:
	var l=Label.new();add_child(l);l.position=p;l.add_theme_font_size_override("font_size",font_size);l.add_theme_color_override("font_color",Color("fff6de"))
	l.add_theme_color_override("font_shadow_color",Color(.04,.12,.15,.7));l.add_theme_constant_override("shadow_offset_y",2);return l

func skin(color:Color,border:Color,width=2) -> StyleBoxFlat:
	var s=StyleBoxFlat.new();s.bg_color=color;s.border_color=border;s.set_border_width_all(width);s.set_corner_radius_all(14)
	s.content_margin_left=17;s.content_margin_right=17;s.content_margin_top=10;s.content_margin_bottom=10
	s.shadow_color=Color(0,.04,.06,.18);s.shadow_size=4;s.shadow_offset=Vector2(0,3)
	return s

func style_button(b:Button,primary:bool):
	b.add_theme_stylebox_override("normal",skin(YELLOW if primary else Color("e5f1ee"),Color("c89433") if primary else Color("b1ceca")))
	b.add_theme_stylebox_override("pressed",skin(Color("f0b844") if primary else Color("b5d7d1"),Color("638c8d")))
	b.add_theme_stylebox_override("hover",skin(Color("ffe193") if primary else Color("f4fcf7"),Color("b1ceca")))
	b.add_theme_color_override("font_color",INK);b.add_theme_color_override("font_pressed_color",INK);b.add_theme_color_override("font_hover_color",INK)
	b.add_theme_font_size_override("font_size",22)
	b.focus_mode=Control.FOCUS_NONE

func button(parent:Node,text:String,action:Callable,primary=false) -> Button:
	var b=Button.new();b.text=text;b.custom_minimum_size=Vector2(0,52);b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	style_button(b,primary);parent.add_child(b);b.pressed.connect(action);return b

func text(parent:Node,value:String,font_size=23,color=INK) -> Label:
	var l=Label.new();l.text=value;l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;l.add_theme_font_size_override("font_size",font_size);l.add_theme_color_override("font_color",color);parent.add_child(l);return l

func row(parent:Node) -> HBoxContainer:
	var r=HBoxContainer.new();r.add_theme_constant_override("separation",10);parent.add_child(r);return r

func card(title:String) -> VBoxContainer:
	clear_input()
	screen=""
	# Keep the clicked control in the tree until input dispatch finishes.
	for c in overlay.get_children():c.hide();c.queue_free()
	overlay.show()
	var center=CenterContainer.new();center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);overlay.add_child(center)
	var panel=PanelContainer.new();panel.custom_minimum_size=Vector2(minf(840,size.x-56),0);panel.add_theme_stylebox_override("panel",skin(Color("f6f2df"),Color("d4dfcb"),3));center.add_child(panel)
	panel_box=VBoxContainer.new();panel_box.add_theme_constant_override("separation",12);panel.add_child(panel_box)
	text(panel_box,title,29)
	return panel_box

func close():
	overlay.hide();clear_input();game.resume_after_menu()

func english(parent:Node,value:String,height=205):
	var rich=RichTextLabel.new();rich.bbcode_enabled=true;rich.custom_minimum_size=Vector2(0,minf(height,size.y*.34));rich.scroll_active=true
	rich.meta_underlined=false
	rich.add_theme_color_override("default_color",INK);rich.add_theme_font_size_override("normal_font_size",24)
	var regex=RegEx.new();regex.compile("[A-Za-z]+(?:'[A-Za-z]+)?")
	var result="";var last=0
	for m in regex.search_all(value):
		result+=value.substr(last,m.get_start()-last)+"[url="+m.get_string().to_lower()+"]"+m.get_string()+"[/url]";last=m.get_end()
	result+=value.substr(last);rich.text=result
	rich.meta_clicked.connect(func(meta):game.word_card(str(meta)))
	parent.add_child(rich)

func toast(value:String):toast_label.text=value;toast_time=2.3

func clear_input():
	left_id=-1;right_id=-1;move=Vector2.ZERO;aim=Vector2.ZERO;fire=false

func _process(dt):
	stick_left=Vector2(126,size.y-130);stick_right=Vector2(size.x-145,size.y-130)
	if game.player and is_instance_valid(game.player):
		var p=game.player
		health.text="耐久  %d / 100"%ceili(p.hp)
		status.text="换弹 %.1f"%p.reload_left if p.reload_left>0 else "弹药  "+str(p.ammo)+" / 6"
	objective.text=("据点  %d / 3"%(3-game.living_enemies())) if game.phase=="battle" else "河谷前哨   ·   木料 "+str(game.save_data.get("wood",0))
	camp_buttons.visible=game.phase=="camp" and not overlay.visible
	toast_time=maxf(0,toast_time-dt);toast_label.modulate.a=minf(1,toast_time*2)
	queue_redraw()

func _draw():
	if not game or not is_instance_valid(game.player):return
	var hp=maxf(0,game.player.hp/100)
	draw_style_box(skin(Color("173943"),Color("557e7c")),Rect2(22,59,204,15))
	draw_rect(Rect2(26,63,196*hp,7),Color("8bdb8d") if hp>.3 else Color("ff946c"))
	if overlay.visible:return
	for center in [stick_left,stick_right]:
		draw_circle(center,67,Color(.04,.15,.19,.32));draw_arc(center,67,0,TAU,48,Color(.81,.94,.86,.55),2,true)
	draw_circle(stick_left+move*38,27,Color(.89,.96,.86,.68))
	draw_circle(stick_right+aim*36,29,Color(1,.78,.31,.85))
	draw_string(game.font,stick_left+Vector2(-23,6),"移动",HORIZONTAL_ALIGNMENT_LEFT,-1,19,INK)
	draw_string(game.font,stick_right+Vector2(-23,6),"射击",HORIZONTAL_ALIGNMENT_LEFT,-1,19,INK)
	var dash=Vector2(size.x-142,size.y-280)
	draw_circle(dash,41,Color(.08,.23,.28,.67))
	var ready=1-game.player.dash_cooldown/1.55
	draw_arc(dash,41,-PI/2,-PI/2+TAU*ready,40,YELLOW,3,true)
	draw_string(game.font,dash+Vector2(-22,7),"闪避",HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color("fff2cf"))
	var reload_center=Vector2(size.x-270,size.y-200)
	draw_circle(reload_center,33,Color(.08,.23,.28,.67));draw_arc(reload_center,33,0,TAU,36,Color("b4d9cd"),2,true)
	draw_string(game.font,reload_center+Vector2(-20,7),"换弹",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("fff2cf"))
	if game.phase=="battle":
		for enemy in game.enemies:
			if not is_instance_valid(enemy) or enemy.hp<=0:continue
			if game.camera.is_position_behind(enemy.position):continue
			var p=game.camera.unproject_position(enemy.position+Vector3.UP*1.97)
			draw_rect(Rect2(p-Vector2(29,0),Vector2(58,5)),Color(.10,.16,.17,.7))
			draw_rect(Rect2(p-Vector2(29,0),Vector2(58*enemy.hp/enemy.max_hp,5)),Color("ff9b66"))

func touch(event:InputEvent):
	if overlay.visible:return
	if event is InputEventScreenTouch:
		if event.pressed:
			if event.position.distance_to(Vector2(size.x-270,size.y-200))<39:
				game.player.reload();return
			if event.position.distance_to(Vector2(size.x-142,size.y-280))<48:
				game.do_dash();return
			if event.position.distance_to(stick_left)<100 and left_id<0:left_id=event.index
			elif event.position.distance_to(stick_right)<100 and right_id<0:right_id=event.index;fire=true
		else:
			if event.index==left_id:left_id=-1;move=Vector2.ZERO
			if event.index==right_id:right_id=-1;aim=Vector2.ZERO;fire=false
	if event is InputEventScreenDrag or (event is InputEventScreenTouch and event.pressed):
		if event.index==left_id:move=((event.position-stick_left)/58).limit_length(1)
		if event.index==right_id:aim=((event.position-stick_right)/58).limit_length(1)
