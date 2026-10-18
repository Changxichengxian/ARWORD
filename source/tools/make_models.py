"""Original low-poly 3D assets. Run with Blender 4.4+ --background --python."""
import bpy, math, random
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/models';OUT.mkdir(parents=True,exist_ok=True)
random.seed(33)
def clean():
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
def mat(name,color,metal=0):
    color=tuple(c/12.92 if c<=.04045 else ((c+.055)/1.055)**2.4 for c in color)
    m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Roughness'].default_value=.76;p.inputs['Metallic'].default_value=metal
    return m
def empty(name,loc=(0,0,0),parent=None):
    o=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(o);o.location=loc;o.parent=parent;return o
def finish(o,name,material,parent=None):
    o.name=name;o.data.materials.append(material)
    if parent:o.parent=parent
    return o
def cube(name,loc,size,m,parent=None,bevel=.035):
    bpy.ops.mesh.primitive_cube_add(size=1,location=loc);o=bpy.context.object;o.scale=size
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        b=o.modifiers.new('edge','BEVEL');b.width=bevel;b.segments=1
        bpy.ops.object.modifier_apply(modifier=b.name)
        n=o.modifiers.new('weighted','WEIGHTED_NORMAL');bpy.ops.object.modifier_apply(modifier=n.name)
    return finish(o,name,m,parent)
def cyl(name,loc,radius,depth,m,parent=None,vertices=8,r2=None):
    bpy.ops.mesh.primitive_cone_add(vertices=vertices,radius1=radius,radius2=radius if r2 is None else r2,depth=depth,location=loc)
    return finish(bpy.context.object,name,m,parent)
def ico(name,loc,size,m,parent=None,sub=1):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=sub,radius=1,location=loc);o=bpy.context.object;o.scale=size;return finish(o,name,m,parent)
def beam(name,a,b,width,m,parent=None):
    a,b=Vector(a),Vector(b);o=cube(name,(a+b)/2,(width,width,(b-a).length),m,parent,.025);o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();return o
def mesh(name,verts,faces,m,parent=None):
    data=bpy.data.meshes.new(name);data.from_pydata(verts,[],faces);data.update();o=bpy.data.objects.new(name,data);bpy.context.collection.objects.link(o);o.data.materials.append(m);o.parent=parent;return o
def export(name):
    bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',export_yup=True,export_apply=True,export_materials='EXPORT')
    # Editable modeling source for each asset; no external textures.
    source=ROOT/'art-source';source.mkdir(exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(source/(name+'.blend')))

wood=mat('Honey timber',(.50,.25,.105));woodlight=mat('Cut wood',(.78,.49,.20));dark=mat('Deep navy',(.035,.09,.13));cream=mat('Warm ivory',(.90,.84,.64));steel=mat('Blue steel',(.19,.32,.37),.3);glass=mat('Visor',(.025,.16,.20),.2);shine=mat('Visor light',(.25,.9,.94));gold=mat('Brass',(.98,.66,.16),.25)
for name,color,kind in [('ranger',(.10,.55,.58),0),('raider',(.86,.25,.13),1),('sentinel',(.62,.43,.19),2),('flanker',(.48,.27,.64),3)]:
    clean();root=empty('Actor');coat=mat(name+' coat',color)
    body=empty('Body',(0,0,.78),root)
    cube('Torso',(0,0,.21),(.72,.43,.63),coat,body,.10)
    cube('Chest plate',(0,.25,.27),(.47,.12,.34),cream,body,.05)
    cube('Belt',(0,0,-.03),(.76,.49,.12),dark,body)
    cube('Buckle',(0,.28,-.03),(.17,.06,.12),gold,body)
    cube('Pack',(0,-.32,.19),(.50,.20,.45),wood,body,.06)
    head=empty('Head',(0,0,.65),body)
    ico('Helmet',(0,0,.04),(.48,.43,.43),coat,head,2)
    cube('Face',(0,.36,.015),(.62,.14,.30),glass,head,.09)
    cube('Reflection',(-.12,.444,.08),(.25,.014,.04),shine,head,.005)
    cube('Chin',(0,.31,-.17),(.42,.16,.10),cream,head)
    for sign in [-1,1]:
        cyl('Ear',(sign*.43,0,.02),.14,.12,steel,head).rotation_euler[1]=math.pi/2
        leg=empty('LegL' if sign<0 else 'LegR',(sign*.22,0,.69),root)
        cube('Trousers',(0,0,-.20),(.27,.30,.43),dark,leg,.04)
        cube('Boot',(0,.09,-.51),(.32,.48,.24),wood,leg,.055)
        cube('Knee',(0,.17,-.19),(.24,.10,.18),coat,leg)
        arm=empty('ArmL' if sign<0 else 'ArmR',(sign*.46,0,.38),body)
        cube('Sleeve',(0,.10,-.05),(.28,.36,.37),coat,arm,.065)
        cube('Glove',(0,.28,-.15),(.25,.26,.23),wood,arm,.04)
    gun=empty('Gun',(.42,.44,.20),body)
    cube('Receiver',(0,.16,0),(.28,.46,.24),steel,gun)
    tube=cyl('Barrel',(0,.55,.03),.095,.42,dark,gun,8);tube.rotation_euler[0]=math.pi/2
    ring=cyl('Muzzle',(0,.78,.03),.12,.075,gold,gun,8);ring.rotation_euler[0]=math.pi/2
    cube('Stock',(0,-.10,-.015),(.21,.25,.18),wood,gun)
    cube('Sight',(0,.20,.16),(.08,.14,.07),gold,gun,.015)
    if kind==1:
        for x in [-.15,0,.15]:ico('crest',(x,0,.48),(.12,.19,.20),gold,head)
    if kind==2:
        cube('ShoulderArmor',(-.5,0,.44),(.30,.47,.22),cream,body,.07)
        cube('Antenna',(0,-.22,.57),(.05,.05,.36),steel,head,.005)
    if kind==3:
        beam('Scarf',(0,-.27,.53),(.35,-.68,.40),.18,gold,body)
    export(name)

clean();root=empty('Crate')
cube('box',(0,0,.55),(1.05,1.05,1.1),wood,root,.055)
for z in [.12,.96]:
    for y in [-.54,.54]:cube('rim',(0,y,z),(1.16,.12,.14),woodlight,root)
for x in [-.47,.47]:
    for y in [-.55,.55]:cube('upright',(x,y,.55),(.13,.12,.96),woodlight,root)
for y in [-.58,.58]:beam('brace',(-.42,y,.16),(.42,y,.94),.12,woodlight,root)
export('crate')
clean();root=empty('Barrel');red=mat('Explosive coral',(.87,.26,.13))
cyl('body',(0,0,.6),.43,1.13,red,root,10)
for z in [.18,.98]:cyl('band',(0,0,z),.46,.09,steel,root,10)
cyl('top',(0,0,1.19),.40,.045,dark,root,10)
cube('hazard',(0,.435,.62),(.29,.02,.30),gold,root)
export('barrel')
clean();root=empty('Pine');greens=[mat('Pine'+str(i),c) for i,c in enumerate([(.16,.39,.23),(.24,.52,.27),(.36,.64,.31)])]
cyl('trunk',(0,0,.58),.17,1.1,wood,root)
for i in range(3):cyl('crown',(0,0,1.2+i*.60),1.04-i*.22,1.40,greens[i],root,7,.04)
export('pine')
clean();root=empty('Rock');stone=mat('Warm limestone',(.62,.64,.52))
ico('rock',(0,0,.4),(.90,.70,.65),stone,root,1)
ico('chip',(.60,.30,.20),(.36,.37,.30),cream,root,1)
export('rock')
clean();root=empty('Workshop');roof=mat('Teal roof',(.08,.39,.43))
cube('stonebase',(0,0,.15),(3.4,2.8,.3),stone,root,.07)
cube('walls',(0,0,1.25),(2.9,2.3,2.1),cream,root,.03)
verts=[(-1.75,-1.5,2.15),(1.75,-1.5,2.15),(0,-1.5,3.25),(-1.75,1.5,2.15),(1.75,1.5,2.15),(0,1.5,3.25)]
mesh('roof',verts,[(0,1,2),(3,5,4),(0,2,5,3),(2,1,4,5),(0,3,4,1)],roof,root)
for x in [-1.4,1.4]:
    for y in [-1.18,1.18]:cube('timber',(x,y,1.2),(.16,.16,2.2),wood,root)
cube('door',(0,1.17,.86),(.83,.1,1.5),wood,root)
for x in [-.92,.92]:cube('window',(x,1.18,1.48),(.52,.10,.57),dark,root)
for x in [-.92,.92]:
    cube('cross',(x,1.25,1.48),(.06,.03,.57),gold,root,.005)
    cube('cross',(x,1.25,1.48),(.52,.03,.06),gold,root,.005)
cyl('chimney',(-.94,-.5,2.83),.25,1.1,wood,root,4)
export('workshop')
clean();root=empty('Bridge')
for i in range(10):
    cube('Plank%02d'%i,(0,(i-4.5)*.36,.05),(2.8,.33,.14),woodlight if i%3 else wood,root,.025)
for x in [-1.3,1.3]:
    cube('support',(x,0,-.12),(.16,3.8,.22),wood,root)
    for y in [-1.6,0,1.6]:cube('post',(x,y,.5),(.15,.15,1.0),wood,root)
    cube('rail',(x,0,.9),(.12,3.8,.12),woodlight,root)
export('bridge')
print('MODEL_BUILD_OK',len(list(OUT.glob('*.glb'))),flush=True)
