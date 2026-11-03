"""Original low-poly blue whale, replacing wild_whale only. Blender 4.4.

Shape references (not copied textures or meshes):
https://www.nps.gov/places/blue-whale.htm
https://www.fisheries.noaa.gov/species/blue-whale
Broad flat U rostrum, rear small dorsal, slim pectorals, horizontal notched flukes.
Blender +Y is forward, +Z up; glTF converts this to Godot -Z / +Y.
"""
import bpy, math, sys
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
bpy.context.preferences.filepaths.save_version=0
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
def mat(name,color,rough=.48):
    c=[int(color[i:i+2],16)/255 for i in (0,2,4)]
    c=[v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in c]
    m=bpy.data.materials.new(name);m.use_nodes=True;m.diffuse_color=(*c,1)
    p=m.node_tree.nodes['Principled BSDF'];p.inputs['Base Color'].default_value=(*c,1);p.inputs['Roughness'].default_value=rough
    return m
blue=mat('Blue whale slate blue','577C90');lighter=mat('Subtle blue mottling','64899B');darkblue=mat('Deep blue mottling','4C7188');belly=mat('Pale blue grey ventral pleats','A7BDC1');sideblue=mat('Blue grey flank','7194A5');ink=mat('Small eyes and mouth line','243D49');groove=mat('Ventral groove shadow','799AAB')
palette=[blue,lighter,darkblue,belly,sideblue,groove]
def node(name,parent=None,p=(0,0,0)):
    o=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(o);o.parent=parent;o.location=p;return o
def mesh(name,v,f,m,parent):
    d=bpy.data.meshes.new(name);d.from_pydata(v,[],f);d.update();o=bpy.data.objects.new(name,d);bpy.context.collection.objects.link(o);o.parent=parent;o.data.materials.append(m);return o
def ico(name,p,s,m,parent,sub=2):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=sub,radius=1)
    o=bpy.context.object;o.name=name;o.parent=parent;o.location=p;o.scale=s;o.data.materials.append(m);return o
def loft(name,profile,parent,segments=20):
    # Each row is longitudinal position, horizontal half-width, half-height, centre height.
    v=[];angles=[2*math.pi*k/segments for k in range(segments)]
    pleats=[4.03,4.25,4.48,4.71,4.94,5.17,5.39] if parent.name=='Body' else []
    for a in pleats:angles.extend([a-.010,a+.010])
    angles=sorted(angles);segments=len(angles)
    for y,w,h,z in profile:
        for a in angles:v.append((w*math.cos(a),y,z+h*math.sin(a)))
    f=[]
    for j in range(len(profile)-1):
        for k in range(segments):f.append((j*segments+k,j*segments+(k+1)%segments,(j+1)*segments+(k+1)%segments,(j+1)*segments+k))
    f.extend([tuple(reversed(range(segments))),tuple((len(profile)-1)*segments+k for k in range(segments))])
    o=mesh(name,v,f,blue,parent)
    for m in palette[1:]:o.data.materials.append(m)
    for poly in o.data.polygons:
        if len(poly.vertices)!=4:continue
        k=poly.index%segments;j=poly.index//segments;a=(angles[k]+(angles[k+1] if k+1<segments else 2*math.pi))/2
        if math.sin(a)<-.37:poly.material_index=3
        elif math.sin(a)<.25:poly.material_index=4
        else:poly.material_index=1 if (j*5+k*7)%13 in [0,1] else 2 if (j*7+k*3)%17==0 else 0
        if 3<=j<=9 and any(abs(a-p)<.009 for p in pleats):poly.material_index=5
    return o
def paddle(name,outline,thickness,m,parent):
    n=len(outline);v=[(x,y,z+thickness/2) for x,y,z in outline]+[(x,y,z-thickness/2) for x,y,z in outline]
    f=[tuple(range(n)),tuple(reversed(range(n,n*2)))]
    for k in range(n):f.append((k,(k+1)%n,(k+1)%n+n,k+n))
    return mesh(name,v,f,m,parent)
root=node('Whale');body=node('Body',root)
# One uninterrupted body from flat rounded rostrum through the trunk to the tail root.
profile=[(2.05,.13,.037,.005),(2.015,.22,.061,.009),(1.94,.275,.089,.012),(1.79,.306,.116,.019),(1.55,.325,.142,.031),(1.30,.348,.182,.043),(1.07,.362,.225,.049),(.80,.377,.279,.035),(.47,.383,.322,.012),(.12,.362,.332,-.006),(-.25,.313,.307,-.012),(-.60,.259,.260,-.019),(-.92,.209,.206,-.027),(-1.19,.164,.154,-.035),(-1.44,.126,.109,-.038)]
loft('Continuous streamlined body and flat U head',profile,body)
# Low central rostral ridge and paired blowholes; no spherical forehead.
ridge=[(-.018,1.88,.102),(.018,1.88,.102),(.027,1.10,.283),(-.027,1.10,.283),(0,1.46,.197)]
mesh('Single low rostral ridge',ridge,[(0,1,4),(1,2,4),(2,3,4),(3,0,4)],blue,body)
for s in [-1,1]:
    ico('Tiny side eye',(s*.357,1.10,.014),(.014,.025,.020),ink,body)
    ico('Paired blowhole',(s*.034,1.03,.280),(.016,.053,.008),ink,body)
node('Blowhole',root,(0,1.035,.294))
# Restrained mouth seam follows the flattened broad head instead of a smiling muzzle.
for s in [-1,1]:
    p=[(s*.14,2.048,-.001),(s*.232,2.005,-.004),(s*.286,1.91,-.011),(s*.316,1.72,-.021),(s*.337,1.47,-.031),(s*.351,1.23,-.044),(s*.355,1.08,-.055)]
    verts=[]
    for x,y,z in p:verts.extend([(x,y,z-.006),(x,y,z+.006)])
    mesh('Long fine mouth seam',verts,[(i*2,i*2+1,i*2+3,i*2+2) for i in range(len(p)-1)],ink,body)
# Throat pleats are thin colour regions in the connected hull itself, not
# separate ribbons that can read as floating cables under directional light.
# The small dorsal fin is behind the middle, around three quarters of total length.
mesh('Small far aft dorsal fin',[(0,-1.04,.166),(.025,-1.23,.112),(0,-1.31,.101),(0,-1.19,.236),(-.025,-1.23,.112)],[(0,1,3),(1,2,3),(2,4,3),(4,0,3),(0,4,2,1)],blue,body)
flippers=[]
for side,s in [('L',-1),('R',1)]:
    fin=node('Flipper'+side,root,(s*.315,.72,-.12));flippers.append(fin)
    outline=[(0,.105,0),(s*.14,.035,-.017),(s*.39,-.22,-.048),(s*.61,-.53,-.082),(s*.66,-.65,-.089),(s*.57,-.63,-.082),(s*.30,-.34,-.047),(s*.075,-.16,-.012),(0,-.12,0)]
    paddle('Long pointed pectoral flipper',outline,.022,sideblue,fin)
tail=node('Tail',root,(0,-1.32,-.037))
loft('Tapering flexible tail stock',[(.04,.146,.128,0),(-.14,.121,.101,0),(-.34,.097,.077,-.004),(-.52,.071,.049,-.003),(-.66,.063,.035,0)],tail,16)
fluke=node('Fluke',tail,(0,-.61,0))
# Two thin swept triangles meet at a visibly notched trailing edge.
outline=[(0,.09,.006),(-.18,.13,.012),(-.40,.095,.015),(-.69,-.04,.004),(-.77,-.17,-.005),(-.45,-.30,-.011),(-.15,-.35,-.008),(0,-.245,.004),(.15,-.35,-.008),(.45,-.30,-.011),(.77,-.17,-.005),(.69,-.04,.004),(.40,.095,.015),(.18,.13,.012)]
paddle('Broad horizontal notched flukes',outline,.026,blue,fluke)
def merge(parent):
    parts=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.parent==parent]
    bpy.ops.object.select_all(action='DESELECT')
    for o in parts:o.select_set(True)
    bpy.context.view_layer.objects.active=parts[0]
    if len(parts)>1:bpy.ops.object.join()
    o=bpy.context.object;t=o.data.color_attributes.new(name='Tint',type='FLOAT_COLOR',domain='CORNER')
    for p in o.data.polygons:
        for i in p.loop_indices:t.data[i].color=o.data.materials[p.material_index].diffuse_color
    m=mat(parent.name+' blue whale colors','FFFFFF');v=m.node_tree.nodes.new('ShaderNodeVertexColor');v.layer_name='Tint';m.node_tree.links.new(v.outputs['Color'],m.node_tree.nodes['Principled BSDF'].inputs['Base Color'])
    o.data.materials.clear();o.data.materials.append(m)
    for p in o.data.polygons:p.material_index=0
for p in [body,tail,fluke,*flippers]:merge(p)
for o in bpy.context.scene.objects:
    if o.type=='MESH':o.data.validate();o.data.update()
bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets/models/wild_whale.glb'),export_format='GLB',export_yup=True,export_apply=True)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art-source/wild_whale.blend'))
print('BLUE_WHALE_READY: wild_whale only; continuous hull, articulated tail and pectorals')
if '--renders' in sys.argv:
    output=Path(sys.argv[sys.argv.index('--renders')+1])
    if not output.is_absolute():output=ROOT.parent/output
    output.mkdir(parents=True,exist_ok=True)
    scene=bpy.context.scene;scene.render.engine='BLENDER_EEVEE_NEXT';scene.render.resolution_x=1400;scene.render.resolution_y=900;scene.render.resolution_percentage=100
    scene.world.color=(.2,.2,.2);scene.view_settings.view_transform='AgX'
    for pos,power,size in [((3,4,7),1100,5),((-4,1,3),700,4),((1,-5,4),850,3)]:
        bpy.ops.object.light_add(type='AREA',location=pos);l=bpy.context.object;l.data.energy=power;l.data.shape='DISK';l.data.size=size;l.rotation_euler=(-l.location).to_track_quat('-Z','Y').to_euler()
    bpy.ops.object.camera_add();cam=bpy.context.object;scene.camera=cam;cam.data.type='ORTHO';cam.data.ortho_scale=5.4
    for name,pos,up in [('blue-whale-side',(6,0,.5),'Z'),('blue-whale-top',(0,0,8),'Y'),('blue-whale-three-quarter',(5,5,4),'Z')]:
        cam.location=pos;cam.rotation_euler=(-cam.location).to_track_quat('-Z','Y').to_euler()
        if name=='blue-whale-top':cam.rotation_euler=(0,0,math.pi/2)
        scene.render.filepath=str(output/(name+'.png'));bpy.ops.render.render(write_still=True)
