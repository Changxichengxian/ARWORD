"""Original articulated sea life and hollow underwater scenery. Blender source retained."""
import bpy,math,sys
from pathlib import Path
from mathutils import Vector
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
silver=mat('silver blue','9ACFD3');deep=mat('deep teal','356983');cream=mat('ivory','E8E4BD');ink=mat('eyes','142F42');gold=mat('soft gold','EDC96C');turq=mat('reef teal','3AAFA9');green=mat('shell green','577D57');lightgreen=mat('shell plates','8EA66D')

clean();root=node('SilverFish');body=node('Body',root)
ico('slender body',(0,0,0),(.13,.48,.14),silver,body)
ico('dark back',(0,-.02,.06),(.105,.41,.105),deep,body)
for s in [-1,1]:ico('eye',(s*.104,.30,.035),(.019,.023,.021),ink,body,1)
fin(body,'dorsal',[(0,.12,.09),(0,-.03,.29),(0,-.17,.10)],deep)
for s in [-1,1]:fin(body,'pectoral',[(s*.10,.05,0),(s*.28,-.13,-.01),(s*.10,-.16,-.03)],cream)
tail=node('Tail',root,(0,-.39,0))
fin(tail,'forked tail',[(0,.02,0),(0,-.27,.24),(0,-.17,.03),(0,-.27,-.21),(0,-.04,-.02)],deep)
export('wild_silver_fish',[body,tail])

clean();root=node('ReefFish');body=node('Body',root)
ico('tall body',(0,0,0),(.095,.28,.34),turq,body)
ico('cream face',(0,.21,.02),(.078,.13,.20),cream,body)
for y,z in [(-.08,.03),(.055,.01)]:ico('dark narrow stripe',(0,y,z),(.097,.030,.295 if y<0 else .26),deep,body)
for s in [-1,1]:ico('eye',(s*.075,.265,.105),(.020,.025,.024),ink,body,1)
fin(body,'high dorsal',[(0,.17,.20),(0,-.10,.53),(0,-.24,.20)],gold)
fin(body,'lower fin',[(0,.10,-.20),(0,-.14,-.41),(0,-.23,-.12)],gold)
tail=node('Tail',root,(0,-.24,0));fin(tail,'rounded tail',[(0,0,.05),(0,-.22,.17),(0,-.26,0),(0,-.22,-.16),(0,0,-.05)],gold)
export('wild_reef_fish',[body,tail])

clean();root=node('Ray');body=node('Body',root)
ico('flat body',(0,.02,0),(.31,.56,.13),deep,body)
ico('pale belly',(0,.04,-.065),(.29,.46,.071),cream,body)
for s in [-1,1]:ico('raised eye',(s*.16,.31,.105),(.05,.07,.04),gold,body,1)
wings=[]
for side,s in [('L',-1),('R',1)]:
    wing=node('Flipper'+side,root,(s*.21,0,0));wings.append(wing)
    v=[(0,.40,.015),(s*.36,.17,.035),(s*.78,-.15,-.06),(s*.66,-.36,-.09),(s*.20,-.43,-.025),(0,-.36,-.015),(s*.28,-.08,.055)]
    mesh('diamond wing',v,[(0,1,6),(1,2,6),(2,3,6),(3,4,6),(4,5,6),(5,0,6),(5,4,3,2,1,0)],deep,wing)
tail=node('Tail',root,(0,-.44,0));rod('long tail',(0,0,0),(0,-.98,-.035),.046,deep,tail);rod('tail end',(0,-.8,-.03),(.08,-1.38,.01),.022,deep,tail)
export('wild_ray',[body,tail,*wings])

clean();root=node('Turtle');body=node('Body',root)
ico('belly',(0,0,-.055),(.36,.48,.14),cream,body)
ico('faceted shell',(0,-.04,.07),(.37,.47,.24),green,body)
for x,y in [(0,0),(0,.22),(0,-.25),(-.20,.06),(.20,.06),(-.18,-.20),(.18,-.20)]:ico('shell scute',(x,y,.195 if x else .267),(.11,.14,.025),lightgreen,body,1)
ico('head',(0,.51,.015),(.13,.19,.12),lightgreen,body)
for s in [-1,1]:ico('eye',(s*.102,.57,.058),(.023,.026,.024),ink,body,1)
limbs=[]
for side,s in [('L',-1),('R',1)]:
    f=node('Flipper'+side,root,(s*.27,.21,-.035));limbs.append(f)
    ico('long front flipper',(s*.23,-.12,-.025),(.14,.35,.048),lightgreen,f)
    back=node('Hind'+side,root,(s*.24,-.32,-.04));limbs.append(back)
    ico('back paddle',(s*.11,-.14,0),(.12,.22,.046),green,back)
tail=node('Tail',root,(0,-.43,-.035));rod('tail',(0,0,0),(0,-.21,0),.045,green,tail)
export('wild_turtle',[body,tail,*limbs])

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
