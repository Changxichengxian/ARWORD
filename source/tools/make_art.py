"""Original miniature world assets; run in Blender --background --python this.py."""
import bpy, math, random, sys
from pathlib import Path
from mathutils import Vector
R=Path(__file__).resolve().parents[1]
OUT=R/'assets/models';OUT.mkdir(parents=True,exist_ok=True)
SRC=R/'art-source';SRC.mkdir(exist_ok=True)
bpy.context.preferences.filepaths.save_version=0
random.seed(402)
ONLY=sys.argv[sys.argv.index('--only')+1] if '--only' in sys.argv else ''
def clean():
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
def mat(name,h):
    rgb=tuple(int(h[i:i+2],16)/255 for i in (0,2,4))
    rgb=tuple(c/12.92 if c<=.04045 else ((c+.055)/1.055)**2.4 for c in rgb)
    m=bpy.data.materials.new(name);m.use_nodes=True;m.diffuse_color=(*rgb,1)
    bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(*rgb,1);bs.inputs['Roughness'].default_value=.78
    return m
def empty(name,parent=None):
    o=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(o);o.parent=parent;return o
def finish(o,name,m,parent=None):
    o.name=name;o.data.materials.append(m);o.parent=parent;return o
def cube(name,p,s,m,parent=None,b=.035):
    bpy.ops.mesh.primitive_cube_add(size=1,location=p);o=bpy.context.object;o.scale=s;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if b:
        mod=o.modifiers.new('soft edge','BEVEL');mod.width=b;mod.segments=1;bpy.ops.object.modifier_apply(modifier=mod.name)
        mod=o.modifiers.new('weighted faces','WEIGHTED_NORMAL');bpy.ops.object.modifier_apply(modifier=mod.name)
    return finish(o,name,m,parent)
def ico(name,p,s,m,parent=None,sub=1):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=sub,radius=1,location=p);o=bpy.context.object;o.scale=s;return finish(o,name,m,parent)
def cyl(name,p,r,h,m,parent=None,n=10,r2=None):
    bpy.ops.mesh.primitive_cone_add(vertices=n,radius1=r,radius2=r if r2 is None else r2,depth=h,location=p);return finish(bpy.context.object,name,m,parent)
def beam(name,a,b,w,m,parent=None):
    a,b=Vector(a),Vector(b);o=cube(name,(a+b)/2,(w,w,(b-a).length),m,parent,.012);o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();return o
def mesh(name,verts,faces,m,parent=None):
    d=bpy.data.meshes.new(name);d.from_pydata(verts,[],faces);d.update();o=bpy.data.objects.new(name,d);bpy.context.collection.objects.link(o);return finish(o,name,m,parent)
def export(name):
    if ONLY and name!=ONLY:return
    bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',export_yup=True,export_apply=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(SRC/(name+'.blend')))
wood=mat('Toasted cedar','915636');cut=mat('Honey end grain','E7BA76');cream=mat('Warm plaster','FFF1CE');navy=mat('Ink','213F50');roof=mat('Apricot clay','E88350');rooflight=mat('Clay highlight','F2AB65');teal=mat('Blue green glass','6EC5BC');stone=mat('Blue slate','8199AD');lightstone=mat('Silver stone','B6CDCE');leaf=mat('Fresh foliage','76B84C');leafdark=mat('Deep foliage','438C5C');leaflight=mat('Leaf tips','B5D966');gold=mat('Golden brass','F7CC67');snow=mat('Cloud','F8F2DD');pink=mat('Flower coral','F4A495')
clean();root=empty('LittleTide')
o=ico('Ocean',(0,0,0),(4.6,4.6,4.6),mat('Sea','40A9BD'),root,3)
for h in ['48B5C2','369CAF','65C5C6'] :o.data.materials.append(mat('Sea facet '+h,h))
for face in o.data.polygons:face.material_index=random.choices([0,1,2,3],[6,2,2,1])[0]
def island(rad,extra,m,name):
    verts=[(0,0,rad)];segments=64;rings=10
    for ring in range(1,rings+1):
        for i in range(segments):
            a=i*math.tau/segments;phi=(1.00+.13*math.sin(3*a)+.07*math.cos(5*a)+extra)*ring/rings
            verts.append((rad*math.sin(phi)*math.cos(a),rad*math.sin(phi)*math.sin(a),rad*math.cos(phi)))
    faces=[]
    for i in range(segments):faces.append((0,1+i,1+(i+1)%segments))
    for ring in range(rings-1):
        for i in range(segments):
            a=1+ring*segments+i;b=1+ring*segments+(i+1)%segments;c=a+segments;d=b+segments
            faces.extend([(a,c,b),(b,c,d)])
    o=mesh(name,verts,faces,m,root)
    for face in o.data.polygons:
        if face.normal.z<0: pass
    return o
island(4.74,.06,mat('Sand','EFD8A3'),'Sand coast')
land=island(4.81,0,mat('Grass','93C568'),'Living land')
land.data.materials.append(mat('Grass sun','A5CE77'));land.data.materials.append(mat('Grass shade','87BA63'))
for f in land.data.polygons:f.material_index=random.choices([0,1,2],[8,1,1])[0]
export('planet')

clean();root=empty('Oak');cyl('Trunk',(0,0,.62),.14,1.24,wood,root,7,.1)
beam('Fork',(-.35,0,.95),(.25,0,1.42),.13,wood,root)
for p,s,m in [((0,0,1.55),(.70,.64,.60),leaf),((-.40,0,1.30),(.55,.52,.49),leafdark),((.35,.12,1.70),(.52,.49,.45),leaflight)]:ico('Crown',p,s,m,root,2)
export('oak')
clean();root=empty('Ore')
for p,s,m in [((0,0,.34),(.65,.53,.48),stone),((.37,.19,.23),(.42,.4,.32),lightstone),((-.27,-.1,.60),(.21,.23,.30),teal)]:ico('Boulder',p,s,m,root,1)
export('ore')
clean();root=empty('Timber');o=cyl('Log',(0,0,0),.12,.56,wood,root,8);o.rotation_euler[1]=math.pi/2
for x in [-.284,.284]:o=cyl('Cut face',(x,0,0),.108,.01,cut,root,8);o.rotation_euler[1]=math.pi/2
export('timber')
clean();root=empty('Builder')
# A deliberately simple, readable silhouette. Each limb has a real animation pivot.
person=mat('Apricot character','F5A33B');face=mat('Warm yellow head','FFDB7A')
body=empty('Body',root);ico('Torso',(0,0,.78),(.26,.18,.36),person,body,2)
ico('Head',(0,0,1.32),(.235,.22,.245),face,body,2)
for side,x in [('L',-.145),('R',.145)]:
    leg=empty('Leg'+side,root);leg.location=(x,0,.50)
    cyl('Leg shape',(0,0,-.17),.10,.34,person,leg,10)
    ico('Foot',(0,.055,-.37),(.115,.175,.11),person,leg,2)
for side,x in [('L',-.31),('R',.31)]:
    arm=empty('Arm'+side,root);arm.location=(x,0,.99)
    cyl('Arm shape',(0,0,-.18),.095,.36,person,arm,10)
    ico('Hand',(0,0,-.38),(.11,.11,.12),person,arm,2)
    if side=='R':
        tool=empty('Tool',arm);beam('Handle',(0,0,-.42),(0,.34,-.42),.055,wood,tool)
        cube('Tool head',(0,.35,-.42),(.25,.12,.13),lightstone,tool,.035)
export('builder')

def building_start(name):
    clean();r=empty(name);return r,[empty('Stage'+str(i),r) for i in range(4)]
def gable(name,w,d,z,h,m,par):
    return mesh(name,[(-w/2,-d/2,z),(w/2,-d/2,z),(0,-d/2,z+h),(-w/2,d/2,z),(w/2,d/2,z),(0,d/2,z+h)],[(0,2,1),(3,4,5),(0,1,4,3),(0,3,5,2),(1,2,5,4)],m,par)
r,s=building_start('Cottage')
cube('Stone footing',(0,0,.12),(1.65,1.45,.24),lightstone,s[0],.08)
for x in [-.65,.65]:
    for y in [-.55,.55]:cube('Frame',(x,y,.73),(.12,.12,1.26),wood,s[1])
cube('Walls',(0,0,.68),(1.36,1.12,1.0),cream,s[1],.05)
cube('Door',(0,.575,.53),(.37,.035,.76),teal,s[2],.08)
for x in [-.43,.43]:
    cube('Window',(x,.58,.88),(.26,.05,.31),navy,s[2],.035);cube('Sill',(x,.64,.69),(.34,.15,.07),wood,s[2])
gable('Roof',1.8,1.65,1.18,.62,roof,s[3])
for y in [-.68,-.34,0,.34,.68]:
    beam('Roof batten',(-.89,y,1.20),(0,y,1.84),.055,rooflight,s[3]);beam('Roof batten',(0,y,1.84),(.89,y,1.20),.055,rooflight,s[3])
cube('Chimney',(.50,-.3,1.68),(.25,.25,.61),lightstone,s[3]);cube('Chimney cap',(.50,-.3,2.0),(.32,.32,.08),cream,s[3])
for x in [-.48,.48]:
    cube('Planter',(x,.76,.27),(.35,.20,.18),wood,s[3]);ico('Flowers',(x,.76,.40),(.22,.16,.18),pink,s[3],1)
export('cottage')
r,s=building_start('Windmill');cyl('Foot',(0,0,.13),.8,.26,lightstone,s[0],10)
cyl('Tower',(0,0,.85),.58,1.45,cream,s[1],10,.42)
for z in [.38,1.0,1.45]:cyl('Timber belt',(0,0,z),.61-(z-.38)*.12,.075,wood,s[2],10)
cube('Door',(0,.56,.48),(.35,.06,.58),teal,s[2],.08);cyl('Roof',(0,0,1.78),.69,.7,roof,s[3],10,.025)
rotor=empty('Rotor',s[3]);rotor.location=(0,.70,1.37)
for a in range(4):
    angle=a*math.pi/2;end=(math.sin(angle)*1.06,0,math.cos(angle)*1.06)
    beam('Spoke',(0,0,0),end,.07,wood,rotor)
    blade=cube('Canvas',(math.sin(angle)*.7+.11*math.cos(angle),0,math.cos(angle)*.7-.11*math.sin(angle)),(.25,.055,.65),cream,rotor,.015);blade.rotation_euler[1]=angle
o=cyl('Hub',(0,.02,0),.14,.12,gold,rotor,10);o.rotation_euler[0]=math.pi/2
export('windmill')
r,s=building_start('Garden');cube('Base',(0,0,.1),(1.8,1.6,.2),lightstone,s[0],.08)
for x in [-.58,0,.58]:
    cube('Bed',(x,0,.23),(.42,1.25,.20),wood,s[1],.04)
    for y in [-.4,0,.4]:ico('Plant',(x,y,.42),(.17,.18,.22),leaf,s[2],1);ico('Fruit',(x+.07,y,.54),(.09,.09,.10),roof,s[3],1)
for x in [-.88,.88]:
    for y in [-.75,.75]:beam('Post',(x,y,.1),(x,y,1.2),.06,cream,s[2])
for y in [-.76,0,.76]:
    beam('Arch',(-.90,y,1.15),(0,y,1.64),.07,cream,s[3]);beam('Arch',(0,y,1.64),(.90,y,1.15),.07,cream,s[3])
beam('Ridge',(0,-.82,1.64),(0,.82,1.64),.09,teal,s[3])
export('garden')

# Small additions make each completed chapter visible without inflating building levels.
clean();root=empty('Deck')
for i in range(7):cube('Plank',((i-3)*.18,0,.12),(.16,1.3,.16),cut,root,.018)
for x in [-.65,.65]:
    for y in [-.52,.52]:cyl('Post',(x,y,.30),.065,.60,wood,root,8)
    beam('Rail',(x,-.55,.55),(x,.55,.55),.06,cream,root)
export('deck')
clean();root=empty('Bench')
for x in [-.43,.43]:cube('Leg',(x,0,.2),(.11,.5,.4),wood,root,.02)
cube('Seat',(0,0,.43),(1.15,.56,.12),cut,root,.035)
cube('Back',(0,-.23,.72),(1.15,.10,.46),teal,root,.04)
export('bench')
clean();root=empty('Camp')
for x in [-.65,.65]:beam('Pole',(x,0,0),(x,0,1.6),.065,wood,root)
mesh('Canopy',[(-.75,-.6,1.24),(.75,-.6,1.24),(-.75,0,1.66),(.75,0,1.66),(-.75,.6,1.24),(.75,.6,1.24)],[(0,1,3,2),(2,3,5,4)],cream,root)
cube('Rug',(0,0,.035),(1.25,.95,.07),teal,root,.025)
for x in [-.35,.35]:ico('Cushion',(x,.12,.13),(.22,.25,.13),roof,root,2)
export('camp')
clean();root=empty('Cistern')
cyl('Tank',(0,0,.48),.53,.96,wood,root,12)
for z in [.16,.74]:cyl('Band',(0,0,z),.55,.08,lightstone,root,12)
cyl('Water',(0,0,.97),.47,.025,teal,root,12)
beam('Outlet',(.42,0,.36),(.72,0,.36),.12,lightstone,root)
export('cistern')
clean();root=empty('Channel')
cube('Trough',(0,0,.10),(.42,1.7,.20),wood,root,.025)
cube('Water',(0,0,.22),(.30,1.65,.03),teal,root,.01)
for x in [-.24,.24]:cube('Wall',(x,0,.24),(.10,1.7,.32),cut,root,.02)
export('channel')
clean();root=empty('Workbench')
for x in [-.42,.42]:
    for y in [-.22,.22]:cube('Leg',(x,y,.36),(.12,.12,.72),wood,root,.018)
cube('Top',(0,0,.77),(1.13,.72,.15),cut,root,.04)
cyl('Pot',(-.30,0,.94),.15,.22,teal,root,10)
beam('Tool',(.05,-.15,.87),(.35,.15,.87),.07,navy,root)
export('workbench')
clean();root=empty('Orchard')
for x,y in [(-.42,-.1),(.40,.25)]:
    cyl('Trunk',(x,y,.55),.09,1.1,wood,root,7)
    ico('Crown',(x,y,1.2),(.48,.47,.54),leafdark,root,2)
    for a in range(5):ico('Fruit',(x+math.sin(a*2)*.35,y+math.cos(a*2)*.35,1.2),(.10,.10,.10),roof,root,2)
export('orchard')
clean();root=empty('Fence')
for x in [-.8,-.4,0,.4,.8]:cube('Picket',(x,0,.37),(.12,.11,.74),cream,root,.045)
for z in [.22,.55]:cube('Rail',(0,-.07,z),(1.8,.10,.09),wood,root,.02)
export('fence')
clean();root=empty('Hive')
for z,radius in [(.22,.37),(.48,.40),(.72,.36),(.91,.25)]:cyl('Hive ring',(0,0,z),radius,.26,gold,root,12,radius*.92)
ico('Entrance',(0,.38,.38),(.10,.025,.075),navy,root,2)
cube('Stand',(0,0,.07),(.9,.8,.14),wood,root,.04)
export('hive')
clean();root=empty('Cloud')
for p,s in [((-.5,0,0),(.55,.33,.28)),((0,0,.12),(.70,.43,.4)),((.6,0,0),(.48,.32,.26))]:ico('Puff',p,s,snow,root,2)
export('cloud')
clean();root=empty('Boat');ico('Hull',(0,0,.13),(.43,.78,.25),roof,root,1);cube('Deck',(0,0,.30),(.55,1.10,.10),cream,root,.05)
beam('Mast',(0,0,.3),(0,0,1.45),.055,wood,root);mesh('Sail',[(.02,0,.58),(.02,0,1.4),(.02,.67,.58)],[(0,1,2),(2,1,0)],cream,root)
export('boat')
clean();root=empty('Flower')
beam('Stem',(0,0,0),(0,0,.35),.04,leafdark,root);ico('Bloom',(0,0,.38),(.15,.15,.11),pink,root,1);ico('Center',(0,0,.46),(.07,.07,.04),gold,root,1)
export('flower')
print('PLANET_ART_COMPLETE')
