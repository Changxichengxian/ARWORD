extends Control

# Small canvas-only opening: no models, textures, 3D shaders or loading timer.
var elapsed=0.0
var reveal=0.0
var pullback=0.0
var stars:Array=[]

func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	var random=RandomNumberGenerator.new();random.seed=73129
	for i in range(105):
		stars.append([Vector2(random.randf(),random.randf()),random.randf_range(.55,1.35),random.randf_range(.10,.9),random.randf_range(0,TAU)])

func _process(dt):
	elapsed+=dt;queue_redraw()

func _draw():
	var opacity=1.0-reveal
	draw_rect(Rect2(Vector2.ZERO,size),Color(0,0,0,opacity))
	var bright=smoothstep(.06,1.0,elapsed)*opacity
	for i in stars.size():
		var star=stars[i];var position=(star[0]-Vector2(.5,.42))*(1.0+pullback*.24)+Vector2(.5,.42)
		var light=bright*star[2]*(.85+.15*sin(elapsed*.65+star[3]))
		var color=Color("DDEFFF") if i%5 else Color("FFE5B6")
		color.a=light
		var p:Vector2=position*size
		if i%23==0:
			draw_circle(p,star[1]*3.5,Color(color,.05*light))
			draw_line(p-Vector2(star[1]*2.6,0),p+Vector2(star[1]*2.6,0),Color(color,light*.65),.8,true)
			draw_line(p-Vector2(0,star[1]*2.6),p+Vector2(0,star[1]*2.6),Color(color,light*.65),.8,true)
		draw_circle(p,star[1],color)
