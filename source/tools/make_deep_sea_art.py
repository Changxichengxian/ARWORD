"""Original articulated sea life and hollow underwater scenery. Blender source retained."""
import bpy,math,sys
from pathlib import Path
from mathutils import Vector
from mathutils.geometry import delaunay_2d_cdt
ROOT=Path(__file__).resolve().parents[1]
ONLY=sys.argv[sys.argv.index('--only')+1].split(',') if '--only' in sys.argv else []
bpy.context.preferences.filepaths.save_version=0
def clean():
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
def mat(name,color,rough=.72):
    rgb=[int(color[i:i+2],16)/255 for i in (0,2,4)]
    rgb=[v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in rgb]
    m=bpy.data.materials.new(name);m.use_nodes=True;m.diffuse_color=(*rgb,1)
    m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(*rgb,1)
    m.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=rough
    return m
def node(name,parent=None,p=(0,0,0)):
    o=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(o);o.parent=parent;o.location=p;return o
def ico(name,p,s,m,parent,sub=2):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=sub,radius=1)
    o=bpy.context.object;o.name=name;o.parent=parent;o.location=p;o.scale=s;o.data.materials.append(m);return o
def mesh(name,v,f,m,parent):
    d=bpy.data.meshes.new(name);d.from_pydata(v,[],f);d.update();o=bpy.data.objects.new(name,d);bpy.context.collection.objects.link(o);o.parent=parent;o.data.materials.append(m);return o
def rod(name,a,b,r,m,parent,vertices=6):
    a,b=Vector(a),Vector(b);bpy.ops.mesh.primitive_cone_add(vertices=vertices,radius1=r,radius2=r*.74,depth=(b-a).length)
    o=bpy.context.object;o.name=name;o.parent=parent;o.location=(a+b)/2;o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();o.data.materials.append(m);return o
def merge(parent):
    parts=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.parent==parent]
    if not parts:return
    bpy.ops.object.select_all(action='DESELECT')
    for o in parts:o.select_set(True)
    bpy.context.view_layer.objects.active=parts[0]
    if len(parts)>1:bpy.ops.object.join()
    o=bpy.context.object;t=o.data.color_attributes.new(name='Tint',type='FLOAT_COLOR',domain='CORNER')
    for p in o.data.polygons:
        for i in p.loop_indices:t.data[i].color=o.data.materials[p.material_index].diffuse_color
    m=mat(parent.name+' colors','FFFFFF');v=m.node_tree.nodes.new('ShaderNodeVertexColor');v.layer_name='Tint';m.node_tree.links.new(v.outputs['Color'],m.node_tree.nodes['Principled BSDF'].inputs['Base Color'])
    o.data.materials.clear();o.data.materials.append(m)
    for p in o.data.polygons:p.material_index=0
def export(name,parts):
    if ONLY and name not in ONLY:return
    for p in parts:merge(p)
    for o in bpy.context.scene.objects:
        if o.type=='MESH':o.data.validate();o.data.update()
    bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets/models'/f'{name}.glb'),export_format='GLB',export_yup=True,export_apply=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art-source'/f'{name}.blend'))
def fin(parent,name,vertices,m):
    return mesh(name,vertices,[tuple(range(len(vertices))),tuple(reversed(range(len(vertices))))],m,parent)

def blade(parent,name,stations,upper,lower,sign=1):
    """Closed foil with an elliptical cross section; first station buries the joint.

    Each station is (x, y, z, half_chord, half_thickness). Unlike scaled spheres,
    the outer sections can taper and sweep back without leaving the shoulder.
    """
    vertices=[];faces=[];sides=10
    for x,y,z,width,thickness in stations:
        for j in range(sides):
            a=2*math.pi*j/sides
            vertices.append((sign*x,y+math.cos(a)*width,z+math.sin(a)*thickness))
    faces.append(tuple(reversed(range(sides))))
    for i in range(len(stations)-1):
        for j in range(sides):
            k=(j+1)%sides
            faces.append((i*sides+j,i*sides+k,(i+1)*sides+k,(i+1)*sides+j))
    faces.append(tuple((len(stations)-1)*sides+j for j in range(sides)))
    if sign<0:faces=[tuple(reversed(f)) for f in faces]
    o=mesh(name,vertices,faces,upper,parent);o.data.materials.append(lower)
    for p in o.data.polygons:
        if p.normal.z<-.01:p.material_index=1
    return o

def fish_body(parent,name,stations,top,side,bottom):
    """One continuous fusiform skin instead of intersecting back/belly balls."""
    vertices=[];faces=[];sides=12
    for y,width,height,z in stations:
        for j in range(sides):
            a=2*math.pi*j/sides
            vertices.append((math.cos(a)*width,y,z+math.sin(a)*height))
    faces.append(tuple(range(sides)))
    for i in range(len(stations)-1):
        for j in range(sides):
            k=(j+1)%sides
            faces.append((i*sides+j,(i+1)*sides+j,(i+1)*sides+k,i*sides+k))
    faces.append(tuple(reversed([(len(stations)-1)*sides+j for j in range(sides)])))
    o=mesh(name,vertices,faces,side,parent);o.data.materials.append(top);o.data.materials.append(bottom)
    for p in o.data.polygons:
        z=p.center.z
        if z>.055:p.material_index=1
        elif z<-.04:p.material_index=2
    return o
silver=mat('silver blue','9ACFD3');deep=mat('deep teal','356983');cream=mat('ivory','E8E4BD');ink=mat('eyes','142F42');gold=mat('soft gold','EDC96C');turq=mat('reef teal','3AAFA9');green=mat('shell green','577D57');lightgreen=mat('shell plates','8EA66D')

clean();root=node('SilverFish');body=node('Body',root)
fish_body(body,'continuous silver body',[(-.42,.026,.04,0),(-.26,.075,.085,.005),(-.06,.13,.145,0),(.17,.119,.13,0),(.34,.078,.08,-.005),(.44,.018,.029,-.008)],deep,silver,cream)
for s in [-1,1]:ico('eye',(s*.092,.27,.035),(.016,.022,.018),ink,body,2)
fin(body,'dorsal',[(0,.12,.09),(0,-.03,.29),(0,-.17,.10)],deep)
fins=[]
for side,s in [('L',-1),('R',1)]:
    p=node('Fin'+side,root,(s*.095,.10,-.02));fins.append(p)
    blade(p,'tapered pectoral',[(0,0,0,.07,.012),(.12,-.10,-.035,.06,.009),(.19,-.19,-.04,.004,.003)],silver,cream,s)
tail=node('Tail',root,(0,-.39,0))
fin(tail,'forked tail',[(0,.02,0),(0,-.27,.24),(0,-.17,.03),(0,-.27,-.21),(0,-.04,-.02)],deep)
export('wild_silver_fish',[body,tail,*fins])

clean();root=node('ReefFish');body=node('Body',root)
reef=fish_body(body,'continuous reef body',[(-.25,.018,.06,0),(-.17,.065,.23,0),(-.11,.082,.29,0),(-.075,.091,.315,0),(-.03,.095,.33,0),(.055,.094,.31,0),(.085,.092,.296,0),(.14,.086,.27,0),(.25,.062,.17,.005),(.33,.018,.035,0)],turq,turq,cream)
# Color bands belong to the continuous skin, with no raised geometry.
reef.data.materials.append(deep)
for p in reef.data.polygons:
    if -.111<p.center.y<-.074 or .054<p.center.y<.086:p.material_index=3
for s in [-1,1]:ico('eye',(s*.055,.255,.080),(.016,.023,.022),ink,body,2)
fin(body,'high dorsal',[(0,.17,.20),(0,-.10,.53),(0,-.24,.20)],gold)
fin(body,'lower fin',[(0,.10,-.20),(0,-.14,-.41),(0,-.23,-.12)],gold)
tail=node('Tail',root,(0,-.24,0));fin(tail,'rounded tail',[(0,0,.05),(0,-.22,.17),(0,-.26,0),(0,-.22,-.16),(0,0,-.05)],gold)
fins=[]
for side,s in [('L',-1),('R',1)]:
    p=node('Fin'+side,root,(s*.075,.15,-.025));fins.append(p)
    blade(p,'reef paddle',[(0,0,0,.055,.009),(.10,-.065,-.02,.08,.006),(.15,-.13,-.03,.005,.002)],gold,cream,s)
export('wild_reef_fish',[body,tail,*fins])

clean();root=node('Ray');body=node('Body',root)
fish_body(body,'ray central disc',[(-.48,.09,.04,-.015),(-.28,.23,.10,0),(.02,.31,.13,0),(.30,.24,.11,.005),(.49,.12,.055,0),(.54,.025,.022,-.005)],deep,deep,cream)
for s in [-1,1]:
    ico('eye hood',(s*.14,.29,.10),(.052,.068,.04),deep,body,2)
    ico('small eye',(s*.159,.32,.12),(.018,.023,.013),ink,body,2)
    ico('spiracle',(s*.15,.19,.127),(.022,.037,.009),ink,body,1)
wings=[]
for side,s in [('L',-1),('R',1)]:
    wing=node('Flipper'+side,root,(s*.18,-.025,0));wings.append(wing)
    blade(wing,'supple inner disc',[(-.08,0,0,.38,.058),(.10,-.045,0,.40,.045),(.25,-.11,-.005,.32,.03),(.42,-.18,-.012,.22,.015)],deep,cream,s)
    tip=node('FlipperTip'+side,wing,(s*.36,-.15,-.008));wings.append(tip)
    blade(tip,'swept outer disc',[(-.035,0,0,.255,.022),(.12,-.07,-.012,.17,.015),(.30,-.17,-.025,.07,.008),(.40,-.24,-.025,.006,.002)],deep,cream,s)
tail=node('Tail',root,(0,-.44,0));rod('long tail',(0,0,0),(0,-.98,-.035),.046,deep,tail);rod('tail end',(0,-.8,-.03),(.08,-1.38,.01),.022,deep,tail)
export('wild_ray',[body,tail,*wings])

clean();root=node('Turtle');body=node('Body',root)
shellrim=mat('shell rim olive','687A4E');shellshade=mat('shell seams','3C583F');skin=mat('flipper ochre olive','A5AF78');shellwarm=mat('warm scute','7F9254')
ico('plastron',(0,-.035,-.065),(.335,.455,.098),cream,body,2)
# The complete dome is one constrained triangulation: scutes and seams share
# vertices, so their surface cannot intersect or float above the carapace.
def dome_z(x,y):
    return .005+.275*math.sqrt(max(0.0,1-(x/.375)**2-((y+.035)/.49)**2))
def clip(poly,nx,ny,d):
    result=[]
    for a,b in zip(poly,poly[1:]+poly[:1]):
        da=nx*a[0]+ny*a[1]-d;db=nx*b[0]+ny*b[1]-d
        if da<=0:result.append(a)
        if (da<0)!=(db<0):
            t=da/(da-db);result.append((a[0]+(b[0]-a[0])*t,a[1]+(b[1]-a[1])*t))
    return result
count=48
ellipse=[(.375*.93*math.cos(i*2*math.pi/count),-.035+.49*.93*math.sin(i*2*math.pi/count)) for i in range(count)]
# Five vertebral scutes and offset costal pairs form staggered five/six-sided
# plates. A peripheral row follows the curved rim instead of a square grid.
seeds=[(0,-.355),(.008,-.195),(-.008,-.025),(.006,.145),(0,.315)]
seeds += [(s*(.205+.018*math.cos(i*1.3)),y+(.008 if s<0 else -.008))
          for s in [-1,1] for i,y in enumerate([-.28,-.115,.065,.245])]
seeds += [(.375*.89*math.cos((i+.24)*2*math.pi/18),
           -.035+.49*.89*math.sin((i+.24)*2*math.pi/18)) for i in range(18)]
polygons=[]
for x,y in seeds:
    poly=ellipse[:]
    for ox,oy in seeds:
        if (x,y)!=(ox,oy):poly=clip(poly,ox-x,oy-y,(ox*ox+oy*oy-x*x-y*y)/2)
    # A narrow inset forms the dark seam, without any separate overlay.
    original=poly[:]
    for a,b in zip(original,original[1:]+original[:1]):
        nx=b[1]-a[1];ny=a[0]-b[0];length=math.hypot(nx,ny)
        poly=clip(poly,nx,ny,nx*a[0]+ny*a[1]-.0035*length)
    polygons.append(poly)
verts2=[Vector((0,-.035))];edges=[]
for radius in [.18,.36,.54,.72,.86,.95,1.0]:
    for i in range(count):
        a=i*2*math.pi/count;verts2.append(Vector((.375*radius*math.cos(a),-.035+.49*radius*math.sin(a))))
for poly in polygons:
    start=len(verts2);verts2.extend(Vector(p) for p in poly)
    edges.extend((start+i,start+(i+1)%len(poly)) for i in range(len(poly)))
triangulated=delaunay_2d_cdt(verts2,edges,[],0,1e-6,False)
shell=mesh('continuous scuted carapace',[(v.x,v.y,dome_z(v.x,v.y)) for v in triangulated[0]],triangulated[2],shellshade,body)
for m in [shellwarm,lightgreen,green,shellrim]:shell.data.materials.append(m)
def inside(x,y,poly):
    return all((b[0]-a[0])*(y-a[1])-(b[1]-a[1])*(x-a[0])>=-1e-7 for a,b in zip(poly,poly[1:]+poly[:1]))
for face in shell.data.polygons:
    x,y=face.center.x,face.center.y
    if (x/.375)**2+((y+.035)/.49)**2>.91**2:face.material_index=4
    else:
        for i,poly in enumerate(polygons):
            if inside(x,y,poly):face.material_index=([1,2,1,2,1][i] if i<5 else [3,1,3,1][(i-5)%4] if i<13 else [4,3,4][i%3]);break
count=24
for i in range(count):
    a=i*2*math.pi/count;b=(i+1)*2*math.pi/count
    rod('carapace edge',(.37*math.cos(a),-.035+.485*math.sin(a),.008),(.37*math.cos(b),-.035+.485*math.sin(b),.008),.025,shellrim,body)
head=node('Head',root,(0,.34,-.025))
ico('short neck',(0,.035,0),(.10,.15,.075),skin,head,2)
ico('sea turtle head',(0,.19,.012),(.117,.16,.091),skin,head,2)
ico('blunt beak',(0,.30,-.007),(.073,.067,.056),lightgreen,head,2)
ico('lower beak',(0,.295,-.043),(.065,.061,.018),cream,head,1)
for s in [-1,1]:
    ico('eye socket',(s*.102,.21,.043),(.021,.032,.025),shellshade,head,2)
    ico('eye',(s*.116,.22,.046),(.012,.021,.017),ink,head,2)
    ico('eye glint',(s*.125,.228,.051),(.004,.006,.005),cream,head,1)
limbs=[]
for side,s in [('L',-1),('R',1)]:
    f=node('Flipper'+side,root,(s*.26,.22,-.06));limbs.append(f)
    blade(f,'swept front flipper',[(-.08,.01,0,.085,.046),(.06,-.025,-.008,.12,.035),(.22,-.085,-.015,.125,.025),(.40,-.20,-.026,.09,.018),(.58,-.39,-.03,.007,.004)],skin,cream,s)
    back=node('Hind'+side,root,(s*.235,-.34,-.06));limbs.append(back)
    blade(back,'short steering paddle',[(-.06,.035,0,.065,.035),(.07,-.06,-.008,.105,.023),(.19,-.15,-.01,.075,.014),(.24,-.24,-.005,.008,.004)],lightgreen,cream,s)
tail=node('Tail',root,(0,-.43,-.06));rod('small tail',(0,0,0),(0,-.16,-.007),.03,skin,tail)
export('wild_turtle',[body,head,tail,*limbs])

coral=mat('coral salmon','DC967D');violet=mat('coral lavender','9C9CBC');stone=mat('reef stone','627F7C');weed=mat('sea grass','629C82');weedlight=mat('sea grass light','8FBA91')
clean();root=node('CoralCluster');body=node('Body',root)
ico('rock',(0,0,.12),(.55,.36,.20),stone,body,1)
for i in range(5):
    a=i*2.399;x=math.cos(a)*.28;y=math.sin(a)*.20;h=.45+(i%3)*.13
    rod('coral stem',(x,y,.10),(x*.9,y*.9,h),.065,coral if i%2 else violet,body)
    for s in [-1,1]:
        tip=(x+s*.20,y+.08,h+.16);rod('branch',(x,y,h*.68),tip,.043,coral if i%2 else violet,body)
        ico('rounded tip',tip,(.052,.052,.06),coral if i%2 else violet,body,1)
export('sea_coral',[body])

clean();root=node('SeaGrass');body=node('Body',root)
ico('small anchor stone',(0,0,.04),(.22,.18,.075),stone,body,1)
for i in range(9):
    a=i*2.399;x=math.cos(a)*.15;y=math.sin(a)*.15;h=.45+(i%4)*.12;dx=math.cos(a+.7)*.17;dy=math.sin(a+.7)*.14
    fin(body,'ribbon blade',[(x-.035,y,0),(x+.035,y,0),(x+dx+.025,y+dy,h*.65),(x+dx*.6,y+dy*.7,h),(x+dx-.025,y+dy,h*.6)],weed if i%2 else weedlight)
export('sea_grass',[body])

bone=mat('old mineral ivory','BCBDA3');moss=mat('weathered stone','5F7877')
clean();root=node('SeaRelic');body=node('Body',root)
for i in range(6):
    y=(i-2.5)*.26;ico('vertebra',(0,y,.09),(.13,.13,.10),bone,body,1)
    if i in [0,5]:continue
    for s in [-1,1]:
        prev=(0,y,.08)
        for j in range(1,5):
            a=j*math.pi/7;p=(s*math.sin(a)*.52,y+.04*math.sin(a),.08+(1-math.cos(a))*.44)
            rod('fossil rib',prev,p,.035,bone,body);prev=p
for i in range(4):ico('broken reef',(.72*math.cos(i*1.9),.64*math.sin(i*1.9),.12),(.22,.30,.21),moss,body,1)
export('sea_relic',[body])

cave_outer=mat('cave rock','455B69');cave_edge=mat('cave rim','6A7B7A');cave_inner=mat('cave inner stone','273D4D');cave_back=mat('cave deep wall','162B3A')
clean();root=node('DeepCave');body=node('Body',root)
n=14;vertices=[]
for layer in range(4):
    y=[.10,-.55,-1.65,-3.10][layer]
    for i in range(n):
        a=2*math.pi*i/n;rx=1.45+(layer%2)*.10;rz=1.04-(layer*.04)
        vertices.append((math.cos(a)*rx,y,.94+math.sin(a)*rz))
faces=[]
for layer in range(3):
    for i in range(n):j=(i+1)%n;faces.append(((layer+1)*n+i,(layer+1)*n+j,layer*n+j,layer*n+i))
mesh('recessed tunnel',vertices,faces,cave_inner,body)
mesh('solid rear wall',vertices[-n:],[(tuple(reversed(range(n))))],cave_back,body)
for i in range(11):
    a=i*math.pi/10;position=(math.cos(a)*1.65,.06,.28+math.sin(a)*1.8)
    o=ico('irregular mouth rock',position,(.44,.50,.39+.08*(i%3)),cave_edge,body,1);o.rotation_euler=(i*.17,i*.31,i*.39)
for j in range(3):
    for i in range(7):
        a=i*math.pi/6;position=(math.cos(a)*(1.62-j*.03),-.6-j*.82,.25+math.sin(a)*1.76)
        ico('rock shell',position,(.52,.63,.47),cave_outer,body,1)
mesh('cave floor',[(-1.6,.3,-.02),(1.6,.3,-.02),(1.6,-3.4,-.02),(-1.6,-3.4,-.02)],[(0,1,2,3)],cave_inner,body)
export('sea_cave',[body])

watcher=mat('ancient indigo','364C66');pale=mat('ancient muted teal','6A8B91');eye=mat('quiet amber eyes','C6CC9E')
eye.node_tree.nodes['Principled BSDF'].inputs['Emission Color'].default_value=eye.diffuse_color
eye.node_tree.nodes['Principled BSDF'].inputs['Emission Strength'].default_value=.32
clean();root=node('AbyssWatcher');body=node('Body',root)
ico('massive hidden head',(0,0,0),(.96,1.0,.63),watcher,body)
ico('broad muzzle',(0,.72,-.12),(.72,.60,.38),pale,body)
ico('lower jaw',(0,.51,-.34),(.66,.70,.17),watcher,body)
eyes=node('Eyes',root)
for s in [-1,1]:
    ico('recessed eye',(s*.64,.86,.34),(.14,.14,.10),ink,body)
    ico('dim eye',(s*.66,.96,.36),(.065,.065,.045),eye,eyes)
    ico('heavy brow',(s*.61,.70,.47),(.27,.29,.095),watcher,body,1)
    fin(body,'cheek crest',[(s*.70,.31,.06),(s*1.15,-.15,.20),(s*.89,-.48,-.12)],pale)
for i in range(4):ico('soft ridge',(0,-.51+i*.28,.52),(.16,.24,.13),pale,body,1)
export('sea_watcher',[body])
print('DEEP_SEA_READY: four articulated species, coral, sea grass, fossil relic, hollow cave, watcher')
