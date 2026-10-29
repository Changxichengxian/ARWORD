extends Button
class_name IslandIcon

var kind="star"
var lit=false
var ink=Color("284852")
var caption=""

func _ready():
	focus_mode=Control.FOCUS_NONE
	resized.connect(queue_redraw)
	pressed.connect(queue_redraw)

func _draw():
	var c=size*.5
	if not caption.is_empty():c.x=size.x*.29
	var r=13.0;var col=ink
	if disabled:col.a=.4
	match kind:
		"star":
			var corners=[];var curve=PackedVector2Array()
			for i in range(10):
				var a=-PI/2+i*PI/5;corners.append(c+Vector2(cos(a),sin(a))*r*(1 if i%2==0 else .48))
			for i in range(10):
				var v=corners[i];var a=v.lerp(corners[(i+9)%10],.16);var b=v.lerp(corners[(i+1)%10],.16)
				for j in range(5):
					var t=j/4.0;curve.append(a.lerp(v,t).lerp(v.lerp(b,t),t))
			if lit:draw_colored_polygon(curve,col)
			curve.append(curve[0]);draw_polyline(curve,col,2.4,true)
		"headphones":
			draw_arc(c+Vector2(0,2),12,PI,TAU,24,col,2.8,true)
			for side in [-1,1]:draw_style_box(pad(col),Rect2(c+Vector2(side*11-3,-1),Vector2(6,12)))
		"book":
			draw_polyline(PackedVector2Array([c+Vector2(-13,-10),c+Vector2(-4,-11),c,c+Vector2(4,-11),c+Vector2(13,-10),c+Vector2(13,11),c+Vector2(4,10),c+Vector2(0,13),c+Vector2(-4,10),c+Vector2(-13,11),c+Vector2(-13,-10)]),col,2,true)
			draw_line(c+Vector2(0,-8),c+Vector2(0,12),col,2,true)
		"gear":
			draw_arc(c,8,0,TAU,24,col,2.5,true);draw_circle(c,3,col)
			for i in range(8):var v=Vector2.from_angle(i*TAU/8);draw_line(c+v*10,c+v*14,col,3,true)
		"compass":
			draw_arc(c,13,0,TAU,30,col,2,true);draw_colored_polygon(PackedVector2Array([c+Vector2(4,-9),c+Vector2(1,2),c+Vector2(-4,9),c+Vector2(-1,-2)]),col)
		"planet":
			draw_arc(c,12,0,TAU,30,col,2,true);draw_arc(c,6,0,TAU,20,col,1.5,true);draw_line(c+Vector2(-11,0),c+Vector2(11,0),col,1.7,true)
		"home":
			draw_polyline(PackedVector2Array([c+Vector2(-13,-1),c+Vector2(0,-12),c+Vector2(13,-1)]),col,3,true)
			draw_rect(Rect2(c+Vector2(-9,0),Vector2(18,12)),col,false,2);draw_rect(Rect2(c+Vector2(-3,4),Vector2(6,8)),col)
		"mill":
			draw_circle(c,3,col)
			for i in range(4):var v=Vector2.from_angle(i*PI/2+.3);draw_line(c+v*4,c+v*14,col,4,true)
			draw_polyline(PackedVector2Array([c+Vector2(-5,7),c+Vector2(-7,15),c+Vector2(7,15),c+Vector2(5,7)]),col,2,true)
		"leaf":
			var pts=PackedVector2Array([c+Vector2(-9,9),c+Vector2(-10,0),c+Vector2(-5,-9),c+Vector2(11,-13),c+Vector2(10,4),c+Vector2(2,10),c+Vector2(-9,9)])
			draw_polyline(pts,col,2.5,true);draw_line(c+Vector2(-13,14),c+Vector2(6,-7),col,2.3,true)
		"play":draw_colored_polygon(PackedVector2Array([c+Vector2(-5,-10),c+Vector2(11,0),c+Vector2(-5,10)]),col)
		"skip":
			for x in [-8,3]:draw_polyline(PackedVector2Array([c+Vector2(x-4,-9),c+Vector2(x+5,0),c+Vector2(x-4,9)]),col,2.8,true)
		"close":draw_line(c-Vector2(7,7),c+Vector2(7,7),col,2.5,true);draw_line(c+Vector2(-7,7),c+Vector2(7,-7),col,2.5,true)
	if not caption.is_empty():draw_string(get_theme_default_font(),Vector2(size.x*.48,size.y*.5+6),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,17,col)

func pad(color:Color)->StyleBoxFlat:
	var s=StyleBoxFlat.new();s.bg_color=color;s.set_corner_radius_all(2);return s
