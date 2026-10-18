extends Control
class_name IslandHUD

const INK=Color("284852")
const CREAM=Color("FFF5DF")
const GREEN=Color("287C69")
var game
var card:PanelContainer
var body:VBoxContainer
var overlay:ColorRect
var goal:Label
var bar:ProgressBar
var toast_label:Label
var toast_timer=0.0
var answers:Array=[]
var word_label:Label
var progress_label:Label
var tag:Label
var screen=""
var top:HBoxContainer
var stars:Array=[]

func skin(color:Color,radius=20)->StyleBoxFlat:
	var s=StyleBoxFlat.new();s.bg_color=color;s.set_corner_radius_all(radius)
	s.content_margin_left=18;s.content_margin_right=18;s.content_margin_top=13;s.content_margin_bottom=13
	s.shadow_color=Color(0.02,.07,.10,.22);s.shadow_size=7;s.shadow_offset=Vector2(0,4);return s
func style_button(b:Button,primary=false):
	b.add_theme_stylebox_override("normal",skin(Color("E8F0E5") if not primary else Color("F3C671"),14))
	b.add_theme_stylebox_override("pressed",skin(Color("BFD9CE") if not primary else Color("DBAC56"),14))
	b.add_theme_stylebox_override("hover",skin(Color("EFF7EE") if not primary else Color("FFDA8E"),14))
	b.add_theme_stylebox_override("disabled",skin(Color("E6E4D6"),14))
	b.add_theme_color_override("font_color",INK);b.add_theme_color_override("font_hover_color",INK);b.add_theme_color_override("font_pressed_color",INK);b.add_theme_color_override("font_disabled_color",Color("657B72"))
	b.add_theme_font_size_override("font_size",20);b.focus_mode=Control.FOCUS_NONE
func button(parent:Node,value:String,action:Callable,primary=false,height=50)->Button:
	var b=Button.new();b.text=value;b.custom_minimum_size=Vector2(0,height);b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	style_button(b,primary);parent.add_child(b);b.pressed.connect(action);return b
func text(parent:Node,value:String,font_size=21,color=INK)->Label:
	var l=Label.new();l.text=value;l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;l.add_theme_font_size_override("font_size",font_size);l.add_theme_color_override("font_color",color);parent.add_child(l);return l
func row(parent:Node)->HBoxContainer:
	var r=HBoxContainer.new();r.add_theme_constant_override("separation",9);parent.add_child(r);return r
func spacer(parent:Node,height:int):
	var c=Control.new();c.custom_minimum_size.y=height;parent.add_child(c)

func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);mouse_filter=Control.MOUSE_FILTER_IGNORE
	var theme_new=Theme.new();theme_new.default_font=game.font;theme_new.default_font_size=21;theme=theme_new
	var rng=RandomNumberGenerator.new();rng.seed=704
	for i in range(55):stars.append(Vector3(rng.randf(),rng.randf(),rng.randf_range(.7,1.7)))
	var header=MarginContainer.new();add_child(header);header.anchor_right=1;header.offset_left=22;header.offset_right=-22;header.offset_top=34
	top=row(header);var titles=VBoxContainer.new();titles.size_flags_horizontal=Control.SIZE_EXPAND_FILL;top.add_child(titles)
	text(titles,"词屿  /  LITTLE TIDE",12,Color("A6C6C6"));text(titles,"青芽星",29,CREAM)
	for pair in [["听",game.toggle_listen],["信",game.letters_menu],["···",game.settings]]:
		var icon_button=button(top,pair[0],pair[1],false,44);icon_button.custom_minimum_size.x=46;icon_button.size_flags_horizontal=0
	var goal_panel=PanelContainer.new();add_child(goal_panel);goal_panel.anchor_right=1;goal_panel.offset_left=22;goal_panel.offset_right=-22;goal_panel.offset_top=111
	goal_panel.add_theme_stylebox_override("panel",skin(Color(.08,.20,.26,.83),16))
	var box=VBoxContainer.new();box.add_theme_constant_override("separation",7);goal_panel.add_child(box)
	var gr=row(box);goal=text(gr,"",19,CREAM);goal.size_flags_horizontal=Control.SIZE_EXPAND_FILL;progress_label=text(gr,"",17,Color("F2CB7B"))
	progress_label.custom_minimum_size.x=63;progress_label.autowrap_mode=TextServer.AUTOWRAP_OFF;progress_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	bar=ProgressBar.new();bar.show_percentage=false;bar.custom_minimum_size.y=5;bar.max_value=1
	var track=skin(Color("2C5260"),3);var fill=skin(Color("EBC673"),3)
	for s in [track,fill]:s.content_margin_left=0;s.content_margin_right=0;s.content_margin_top=0;s.content_margin_bottom=0;s.shadow_size=0
	bar.add_theme_stylebox_override("background",track);bar.add_theme_stylebox_override("fill",fill);box.add_child(bar)
	toast_label=text(self,"",20,CREAM);toast_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;toast_label.anchor_left=.07;toast_label.anchor_right=.93;toast_label.offset_top=190;toast_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	card=PanelContainer.new();add_child(card);card.anchor_top=1;card.anchor_bottom=1;card.anchor_right=1;card.offset_left=16;card.offset_right=-16;card.offset_top=-435;card.offset_bottom=-20
	card.add_theme_stylebox_override("panel",skin(CREAM,26));body=VBoxContainer.new();body.add_theme_constant_override("separation",7);card.add_child(body)
	overlay=ColorRect.new();overlay.color=Color(.02,.08,.12,.66);overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);overlay.mouse_filter=Control.MOUSE_FILTER_STOP;add_child(overlay);overlay.hide()
	sync_goal()

func _draw():
	for p in stars:draw_circle(Vector2(p.x*size.x,p.y*size.y*.8),p.z,Color(.65,.83,.87,.25))

func clear_body():
	for child in body.get_children():child.hide();child.queue_free()
	answers.clear()

func sync_goal():
	var a=int(game.learning.data.active);var value=int(game.learning.data.build[a]);var done=game.learning.completed()
	goal.text="小岛已安顿 · 自由照料" if done else ["木屋 · 收拢第一批木材","风车 · 让叶片转起来","花园 · 种下一片生机"][a]
	progress_label.text="3 / 3" if done else str(value)+" / "+str(IslandLearning.NEEDS[a])
	bar.value=float(value)/IslandLearning.NEEDS[a]

func show_word():
	clear_body();screen="word";card.show()
	var q=game.current;var r=row(body)
	tag=text(r,("听音采集" if game.learning.data.listen else "林间回忆")+"  ·  "+str(int(game.learning.data.actions)%6+1)+" / 6",15,GREEN);tag.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var listen_button=button(r,"音",game.speak_word,false,38);listen_button.custom_minimum_size.x=47;listen_button.size_flags_horizontal=0
	var save_button=button(r,"藏" if not game.learning.data.bookmarks.has(q.id) else "已藏",game.bookmark,false,38);save_button.custom_minimum_size.x=57;save_button.size_flags_horizontal=0
	word_label=text(body,"听一听这个词" if game.learning.data.listen else str(q.word),34);word_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var subtitle=str(q.pos) if game.learning.data.listen else (str(q.phonetic)+"   ·   "+str(q.pos))
	var phon=text(body,subtitle,15,Color("6A827E"));phon.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var grid=GridContainer.new();grid.columns=2;grid.add_theme_constant_override("h_separation",10);grid.add_theme_constant_override("v_separation",10);body.add_child(grid)
	for i in range(4):
		var answer=game.order[i];var b=button(grid,str(q.options[answer]),game.answer.bind(answer),false,57);b.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;b.custom_minimum_size.x=1;answers.append(b)
	var foot=row(body);var helper=button(foot,"想不起来 · 看一眼",game.reveal,false,42);helper.add_theme_font_size_override("font_size",16)
	button(foot,"看看星球",game.explore,false,42).add_theme_font_size_override("font_size",16)
	if game.learning.data.listen or game.learning.data.speech:game.call_deferred("speak_word")

func show_help():
	clear_body();screen="help";var q=game.current
	var r=row(body);text(r,q.word,32).size_flags_horizontal=Control.SIZE_EXPAND_FILL;button(r,"听发音",game.speak_word,false,42)
	text(body,q.pos+" · "+q.zh,23,GREEN)
	text(body,q.example,20)
	text(body,q.translation,17,Color("74837A"))
	spacer(body,5);button(body,"遮住释义，再想一次",game.retry,true,48)
	text(body,"这次有提示，稍后再遇见它。",14,Color("7E8C7D"))

func feedback(answer:int):
	for i in range(answers.size()):
		answers[i].disabled=true
		if game.order[i]==answer:answers[i].add_theme_stylebox_override("disabled",skin(Color("B6DDAC"),14))

func modal(title:String)->VBoxContainer:
	for child in overlay.get_children():child.hide();child.queue_free()
	overlay.show()
	var center=CenterContainer.new();center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);overlay.add_child(center)
	var panel=PanelContainer.new();panel.custom_minimum_size.x=maxf(280,size.x-36);panel.add_theme_stylebox_override("panel",skin(CREAM,24));center.add_child(panel)
	var box=VBoxContainer.new();box.add_theme_constant_override("separation",12);panel.add_child(box);text(box,title,27);return box

func close():overlay.hide();screen="help" if game.help_visible else "word"

func reading(parent:Node,value:String,height=235):
	var rich=RichTextLabel.new();rich.bbcode_enabled=true;rich.custom_minimum_size.y=height;rich.scroll_active=true;rich.meta_underlined=false
	rich.add_theme_color_override("default_color",INK);rich.add_theme_font_size_override("normal_font_size",22)
	var regex=RegEx.new();regex.compile("[A-Za-z]+(?:'[A-Za-z]+)?");var result="";var last=0
	for m in regex.search_all(value):
		result+=value.substr(last,m.get_start()-last)+"[url="+m.get_string().to_lower()+"]"+m.get_string()+"[/url]";last=m.get_end()
	rich.text=result+value.substr(last);parent.add_child(rich);rich.meta_clicked.connect(func(word):game.lookup(str(word)))

func toast(value:String):toast_label.text=value;toast_timer=3.0
func _process(dt):
	toast_timer=maxf(0,toast_timer-dt);toast_label.modulate.a=minf(1,toast_timer)
	queue_redraw()
