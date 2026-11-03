"""Original working settlements and distinct island silhouettes. Blender 4.4+."""
import bpy, math, random, sys
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
ONLY=sys.argv[sys.argv.index('--only')+1].split(',') if '--only' in sys.argv else []
bpy.context.preferences.filepaths.save_version=0
def clean():
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
def mat(name,color,rough=.73,metal=0):
    rgb=[int(color[i:i+2],16)/255 for i in (0,2,4)]
    rgb=[c/12.92 if c<=.04045 else ((c+.055)/1.055)**2.4 for c in rgb]
    m=bpy.data.materials.new(name);m.use_nodes=True;m.diffuse_color=(*rgb,1)
    bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(*rgb,1);bs.inputs['Roughness'].default_value=rough;bs.inputs['Metallic'].default_value=metal
    m.use_backface_culling=False
    return m
def node(name,parent=None,p=(0,0,0)):
    o=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(o);o.parent=parent;o.location=p;return o
def finish(o,name,m,parent):o.name=name;o.data.materials.append(m);o.parent=parent;return o
def box(name,p,s,m,parent,bevel=.025):
    bpy.ops.mesh.primitive_cube_add(size=1,location=p);o=bpy.context.object;o.scale=s;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        b=o.modifiers.new('cut corners','BEVEL');b.width=bevel;b.segments=1;bpy.ops.object.modifier_apply(modifier=b.name)
    return finish(o,name,m,parent)
def ico(name,p,s,m,parent,sub=1):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=sub,radius=1,location=p);o=bpy.context.object;o.scale=s;return finish(o,name,m,parent)
def cyl(name,p,r,h,m,parent,n=10,r2=None):
    bpy.ops.mesh.primitive_cone_add(vertices=n,radius1=r,radius2=r if r2 is None else r2,depth=h,location=p);return finish(bpy.context.object,name,m,parent)
def beam(name,a,b,w,m,parent):
    a,b=Vector(a),Vector(b);o=box(name,(a+b)/2,(w,w,(b-a).length),m,parent,.012);o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();return o
def mesh(name,v,f,m,parent):
    unique=[];seen=set()
    for face in f:
        key=tuple(sorted(face))
        if key not in seen:unique.append(face);seen.add(key)
    d=bpy.data.meshes.new(name);d.from_pydata(v,[],unique);d.update();o=bpy.data.objects.new(name,d);bpy.context.collection.objects.link(o);return finish(o,name,m,parent)
def export(name):
    if ONLY and name not in ONLY:return
    # One vertex-painted mesh per articulated branch, rather than a draw per plank.
    parents=[o for o in bpy.context.scene.objects if o.type=='EMPTY']
    for parent in parents:
        parts=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.parent==parent]
        if not parts:continue
        bpy.ops.object.select_all(action='DESELECT')
        for o in parts:o.select_set(True)
        bpy.context.view_layer.objects.active=parts[0];bpy.ops.object.join();o=bpy.context.object
        colors=o.data.color_attributes.new(name='Tint',type='FLOAT_COLOR',domain='CORNER')
        for poly in o.data.polygons:
            for loop in poly.loop_indices:colors.data[loop].color=o.data.materials[poly.material_index].diffuse_color
        m=mat(name+' paint','FFFFFF');v=m.node_tree.nodes.new('ShaderNodeVertexColor');v.layer_name='Tint';m.node_tree.links.new(v.outputs['Color'],m.node_tree.nodes['Principled BSDF'].inputs['Base Color'])
        o.data.materials.clear();o.data.materials.append(m)
        for poly in o.data.polygons:poly.material_index=0
    bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets/models'/f'{name}.glb'),export_format='GLB',export_yup=True,export_apply=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art-source'/f'{name}.blend'))
wood=mat('honey cedar','A87348');light=mat('fresh cut','E4BE83');cream=mat('canvas ivory','F6E8C9');blue=mat('sea enamel','5CABB7');navy=mat('ink metal','304D62');stone=mat('granite','98ACAA');gold=mat('brass','D7A65B');leaf=mat('deep fronds','428F76');mint=mat('sunlit leaves','87C99C');orange=mat('fruit','EDAA55');violet=mat('mineral','A6A4D3');ember=mat('warm coals','EAB07A');black=mat('basalt','596777')

clean();r=node('Shipyard')
for x in [-.92,.92]:
    for y in [-.75,.1,.85]:cyl('pile',(x,y,.24),.085,.68,wood,r,8)
    for i in range(12):box('dock board',(x,-.92+i*.17,.59),(.42,.145,.09),light if i%3 else wood,r,.01)
for y in [-.70,-.28,.18,.62]:
    for sign in [-1,1]:beam('boat rib',(0,y,.58),(sign*.55,y,.95-abs(y)*.12),.065,wood,r)
beam('keel',(0,-.9,.56),(0,.92,.56),.10,navy,r)
for sign in [-1,1]:beam('hull rail',(sign*.51,-.73,.88),(sign*.51,.7,.88),.09,light,r)
beam('crane',(-.92,-.62,.6),(-.92,-.62,1.92),.12,navy,r);beam('crane arm',(-.92,-.62,1.88),(.05,-.62,1.88),.1,navy,r)
beam('rope',(-.02,-.62,1.84),(-.02,-.62,.98),.028,wood,r)
for y in [.3,.55]:cyl('rope reel',(-.95,y,.78),.15,.22,gold,r,12)
box('sail parcel',(.92,.73,.81),(.38,.38,.22),cream,r)
export('shipyard')

clean();r=node('Stonecutter')
box('bed',(0,0,.21),(1.45,.9,.42),stone,r,.06)
for x in [-.54,.54]:beam('rail',(x,-.55,.5),(x,.55,.5),.065,navy,r)
box('cut block',(0,0,.64),(.7,.62,.42),cream,r,.055)
wheel=node('CutterWheel',r,(0,0,.95));o=cyl('saw',(0,0,0),.42,.04,navy,wheel,20);o.rotation_euler[0]=math.pi/2
for i in range(12):
    a=i*math.tau/12;o=box('tooth',(.42*math.cos(a),0,.42*math.sin(a)),(.1,.07,.07),gold,wheel,.005);o.rotation_euler[1]=-a
export('stonecutter')

clean();r=node('Weavery')
for x in [-.62,.62]:beam('upright',(x,0,.05),(x,0,1.5),.10,wood,r)
for z in [.3,1.42]:beam('crossbar',(-.67,0,z),(.67,0,z),.10,light,r)
for i in range(11):beam('warp',(-.5+i*.1,0,.34),(-.5+i*.1,0,1.36),.016,cream,r)
mesh('half woven sail',[(-.5,-.02,.34),(.5,-.02,.34),(.5,-.02,.95),(-.5,-.02,1.08)],[(0,1,2,3),(3,2,1,0)],cream,r)
for x in [-.62,.62]:beam('foot',(x,-.42,.06),(x,.42,.06),.10,navy,r)
for i in range(3):
    o=cyl('cloth roll',(.63+i*.12,.4,.34),.09,.52,cream,r,10);o.rotation_euler[1]=math.pi/2
export('weavery')

clean();r=node('Forge')
box('hearth',(-.35,.2,.3),(.85,.75,.60),black,r,.08)
box('dark opening',(-.35,-.19,.24),(.49,.025,.30),navy,r)
for i in range(4):ico('coal',(-.51+i*.11,-.23,.18),(.075,.06,.065),ember,r)
cyl('hood',(-.35,.2,.87),.50,.62,stone,r,6,.23);cyl('chimney',(-.35,.2,1.45),.20,.58,cream,r,6)
cyl('stump',(.45,-.2,.26),.32,.5,wood,r,8)
box('anvil',(.45,-.2,.63),(.65,.3,.21),navy,r);mesh('horn',[(.77,-.35,.55),(.77,-.05,.55),(1,-.2,.65),(.77,-.35,.73),(.77,-.05,.73)],[(0,1,2),(3,2,4),(0,2,3),(1,4,2)],navy,r)
export('forge')

clean();r=node('Lensworks')
cyl('round workbench',(0,0,.55),.57,.15,wood,r,12)
for a in [0,2.094,4.188]:beam('leg',(.45*math.cos(a),.45*math.sin(a),.05),(.36*math.cos(a),.36*math.sin(a),.55),.10,navy,r)
o=cyl('large lens',(0,0,.85),.39,.09,blue,r,20);o.rotation_euler[0]=.48
for i in range(3):
    a=i*math.tau/3;beam('lens clamp',(.5*math.cos(a),.5*math.sin(a),.62),(.32*math.cos(a),.32*math.sin(a),.99),.055,gold,r)
for i in range(3):cyl('polishing disks',(.34,-.40,.66+i*.045),.15,.035,violet,r,14)
export('lensworks')

clean();r=node('Windpump')
for x in [-.32,.32]:beam('tower',(x,0,.03),(x*.5,0,1.6),.08,wood,r)
rot=node('PumpRotor',r,(0,-.08,1.62))
for i in range(6):
    a=i*math.tau/6;beam('spoke',(0,0,0),(.55*math.cos(a),0,.55*math.sin(a)),.035,navy,rot)
    o=box('vane',(.43*math.cos(a),0,.43*math.sin(a)),(.32,.045,.18),cream,rot,.012);o.rotation_euler[1]=-a
cyl('tank',(.50,.05,.32),.34,.64,blue,r,12);cyl('rim',(.50,.05,.65),.37,.05,cream,r,12)
beam('pipe',(.12,.1,.84),(.5,.1,.84),.06,gold,r);beam('pipe end',(.5,.1,.84),(.5,.1,.62),.06,gold,r)
export('windpump')

clean();r=node('OrchardPress')
box('table',(0,0,.45),(1.05,.65,.13),light,r)
for x in [-.4,.4]:beam('leg',(x,0,.02),(x,0,.45),.1,wood,r)
cyl('press barrel',(0,0,.78),.25,.55,wood,r,12)
beam('press screw',(0,0,.95),(0,0,1.35),.06,navy,r);beam('handle',(-.35,0,1.3),(.35,0,1.3),.07,light,r)
box('basket',(.63,.1,.22),(.4,.4,.44),wood,r)
for i in range(6):ico('fruit',(.52+(i%2)*.16,-.01+(i//2)*.1,.48),(.10,.10,.09),orange,r)
export('orchard_press')

clean();r=node('Glassworks')
cyl('kiln',(0,.15,.5),.53,1.0,cream,r,10,.38)
box('fire door',(0,-.38,.33),(.38,.05,.39),navy,r)
box('bench',(.73,-.05,.43),(.65,.75,.13),wood,r)
for i in range(3):ico('glass lump',(.55+i*.15,-.08,.60),(.11,.18,.16),[blue,mint,violet][i],r)
cyl('chimney',(0,.15,1.16),.17,.38,stone,r,8)
export('glassworks')

clean();r=node('Basaltworks')
box('workbed',(0,0,.17),(1.4,.95,.34),black,r,.06)
for x in [-.45,0,.45]:
    o=cyl('stone pipe',(x,0,.48),.19,.76,stone,r,10);o.rotation_euler[0]=math.pi/2
    o=cyl('pipe shadow',(x,-.385,.48),.12,.012,navy,r,10);o.rotation_euler[0]=math.pi/2
for x in [-.68,.68]:beam('gantry',(x,.2,.16),(x,.2,1.25),.08,wood,r)
beam('arch',(-.68,.2,1.25),(.68,.2,1.25),.09,wood,r)
export('basaltworks')

clean();r=node('Tidalworks')
for x in [-.68,.68]:box('stone support',(x,0,.38),(.3,.65,.76),stone,r)
rot=node('TideWheel',r,(0,0,.67));o=cyl('wheel hub',(0,0,0),.13,1.2,navy,rot,10);o.rotation_euler[1]=math.pi/2
for i in range(10):
    a=i*math.tau/10;beam('wheel spoke',(0,0,0),(0,.58*math.cos(a),.58*math.sin(a)),.055,wood,rot)
    o=box('paddle',(0,.58*math.cos(a),.58*math.sin(a)),(1,.21,.075),light,rot,.01);o.rotation_euler[0]=a
box('water channel',(0,.95,.14),(1.2,.65,.27),cream,r);box('water',(0,.95,.285),(1.03,.54,.02),blue,r,.005)
export('tidalworks')

clean();r=node('Palm')
for i in range(4):beam('curved trunk',(.04*i,0,i*.36),(.04*(i+1),0,(i+1)*.36),.13-i*.012,wood,r)
for i in range(7):
    a=i*math.tau/7;dx,dy=math.cos(a),math.sin(a)
    mesh('frond',[(.16,0,1.48),(.16+dx*.45-dy*.20,dy*.45+dx*.20,1.61),(.16+dx*1.04,dy*1.04,1.25),(.16+dx*.45+dy*.20,dy*.45-dx*.20,1.61)],[(0,1,2),(0,2,3),(2,1,0),(3,2,0)],leaf if i%2 else mint,r)
for i in range(3):ico('coconut',(.16+math.cos(i*2.1)*.14,math.sin(i*2.1)*.14,1.35),(.13,.13,.13),orange,r)
export('palm')

clean();r=node('BasaltColumns')
for i,(x,y,h) in enumerate([(-.5,0,.7),(-.18,.12,1.4),(.16,.02,1.0),(.45,.18,1.8),(.65,-.15,.65)]):
    cyl('column',(x,y,h/2),.23,h,black if i%2 else stone,r,6)
export('basalt_columns')

clean();r=node('RockArch')
for sign in [-1,1]:
    ico('pillar',(sign*.68,0,.55),(.34,.40,.62),stone,r)
    ico('shoulder',(sign*.47,0,1.08),(.40,.34,.33),cream,r)
ico('keystone',(0,0,1.25),(.43,.30,.24),stone,r)
export('rock_arch')

# Small, recognizable products shown travelling through actual work sites.
for name in ['fruit_crate','water_jar','reed_bundle','sailcloth','iron_ore','metal_brace','lens','hardwood','sea_glass','basalt_ore','stone_pipe']:
    clean();r=node(name.title())
    if name=='fruit_crate':
        box('crate',(0,0,.13),(.40,.32,.26),wood,r)
        for i in range(4):ico('fruit',((i%2-.5)*.17,(i//2-.5)*.13,.30),(.10,.10,.10),orange,r)
    elif name=='water_jar':
        cyl('jar',(0,0,.23),.19,.46,blue,r,10,.13);cyl('lip',(0,0,.48),.15,.04,cream,r,10)
    elif name=='reed_bundle':
        for i in range(5):beam('reed',((i-2)*.06,0,0),((i-2)*.06,.03,.57),.045,light,r)
        box('tie',(0,0,.24),(.33,.10,.06),blue,r)
    elif name=='sailcloth':
        for i in range(3):box('fold',(0,0,.05+i*.07),(.48,.34,.065),cream,r,.016)
        box('strap',(0,0,.16),(.07,.35,.20),blue,r,.01)
    elif name=='metal_brace':
        box('bracket',(0,0,.04),(.48,.27,.08),navy,r);box('angle',(-.20,0,.16),(.08,.27,.31),navy,r)
        for y in [-.07,.07]:cyl('rivet',(.09,y,.09),.024,.03,gold,r,8)
    elif name=='lens':cyl('polished lens',(0,0,.045),.24,.09,blue,r,18)
    elif name=='hardwood':
        for i in range(2):box('board',(0,(i-.5)*.15,.06),(.6,.13,.12),wood,r,.015)
    elif name=='stone_pipe':
        o=cyl('pipe',(0,0,.16),.16,.50,stone,r,10);o.rotation_euler[0]=math.pi/2
        o=cyl('opening',(0,-.255,.16),.10,.008,navy,r,10);o.rotation_euler[0]=math.pi/2
    else:ico('mineral',(0,0,.2),(.28,.23,.24),{'iron_ore':orange,'sea_glass':mint,'basalt_ore':black}[name],r)
    export(name)
