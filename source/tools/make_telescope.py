"""Original low-poly hilltop telescope. Run with Blender --background --python."""
import bpy
import math
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)

def material(name, hex_color, roughness=.65, metallic=0):
    rgb = [int(hex_color[i:i+2],16)/255 for i in (0,2,4)]
    rgb = [c/12.92 if c <= .04045 else ((c+.055)/1.055)**2.4 for c in rgb]
    m=bpy.data.materials.new(name);m.use_nodes=True;m.diffuse_color=(*rgb,1)
    p=m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value=(*rgb,1)
    p.inputs['Roughness'].default_value=roughness;p.inputs['Metallic'].default_value=metallic
    return m

cream=material('Warm porcelain','EFE6CB')
navy=material('Midnight enamel','294C65')
navylight=material('Enamel facets','426D83')
brass=material('Brushed honey brass','D5A95A',.42,.35)
wood=material('Oiled cedar legs','A86D48')
stone=material('Blue grey plinth','91AEB1')
dark=material('Recessed lens shadow','103341')
glass=material('Turquoise lens','54C7D0',.22,.20)
highlight=material('Lens soft reflection','BAF1E9',.27,.05)

def finish(o,name,mat):
    o.name=name;o.data.materials.append(mat);return o

def cone(name,location,radius,depth,mat,r2=None,vertices=12):
    bpy.ops.mesh.primitive_cone_add(vertices=vertices,radius1=radius,radius2=radius if r2 is None else r2,depth=depth,location=location)
    return finish(bpy.context.object,name,mat)

def box(name,location,scale,mat,bevel=.025):
    bpy.ops.mesh.primitive_cube_add(size=1,location=location)
    o=bpy.context.object;o.scale=scale;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        mod=o.modifiers.new('Hand rounded edges','BEVEL');mod.width=bevel;mod.segments=1
        bpy.ops.object.modifier_apply(modifier=mod.name)
        mod=o.modifiers.new('Broad flat normals','WEIGHTED_NORMAL');bpy.ops.object.modifier_apply(modifier=mod.name)
    return finish(o,name,mat)

def rod(name,a,b,radius,mat,vertices=10,r2=None):
    a,b=Vector(a),Vector(b);o=cone(name,(a+b)/2,radius,(b-a).length,mat,r2,vertices)
    o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();return o

cone('Hexagonal mountain footing',(0,0,.09),1.02,.18,stone,vertices=6)
cone('Raised stone rim',(0,0,.20),.84,.07,cream,vertices=6)
cone('Central brass socket',(0,0,1.35),.20,.35,brass,vertices=12)
cone('Azimuth head',(0,0,1.56),.27,.16,navy,vertices=12)
for i in range(3):
    a=math.tau*i/3+math.pi/6
    foot=Vector((math.cos(a)*.77,math.sin(a)*.77,.29))
    hip=Vector((math.cos(a)*.12,math.sin(a)*.12,1.40))
    mid=foot.lerp(hip,.57)
    rod('Tapered cedar tripod leg',foot,hip,.075,wood,8,.10)
    rod('Brass foot',foot-Vector((0,0,.03)),foot.lerp(hip,.13),.092,brass,8)
    rod('Tripod spreader',(0,0,.70),mid,.032,navy,8)
    rod('Tripod bolt',mid-Vector((.06,0,0)),mid+Vector((.06,0,0)),.045,brass,8)

for x in [-.25,.25]:
    box('Fork upright',(x,0,1.78),(.095,.15,.42),navy)
rod('Altitude axle',(-.34,0,1.93),(.34,0,1.93),.10,brass)
rod('Large focusing wheel',(.32,0,1.93),(.42,0,1.93),.16,navy,12)
rod('Wheel gold hub',(.42,0,1.93),(.45,0,1.93),.07,brass,10)

axis=Vector((0,math.cos(math.radians(27)),math.sin(math.radians(27))))
up=Vector((0,-axis.z,axis.y));side=Vector((1,0,0));center=Vector((0,.02,1.99))
def ring(name,along,radius,depth,mat):
    return rod(name,center+axis*(along-depth/2),center+axis*(along+depth/2),radius,mat,16)
ring('Long cream optical tube',0,.245,1.23,cream)
ring('Rear enamel housing',-.58,.265,.18,navy)
ring('Front broad enamel dew shield',.58,.31,.31,navy)
ring('Dew shield outer rim',.755,.32,.07,brass)
ring('Dark recessed lens well',.790,.275,.012,dark)
ring('Faceted objective glass',.802,.228,.012,glass)
ring('Rear focus barrel',-.75,.12,.20,brass)
ring('Eye cup',-.89,.145,.10,navy)
ring('Eye cup dark interior',-.946,.099,.008,dark)
for at in [-.29,.27]:
    ring('Brass tube retaining band',at,.252,.045,brass)
    rod('Tube band mounting pin',center+axis*at-up*.20,center+axis*at-up*.35,.035,navy,8)

# An off-axis finder and two broad lens reflection facets keep the silhouette readable at phone size.
finder_center=center+up*.39+side*.11
rod('Finder support',center+up*.20+side*.11,finder_center,.05,brass,8)
rod('Small finder scope',finder_center-axis*.28,finder_center+axis*.25,.07,cream,10)
rod('Finder cap',finder_center+axis*.25,finder_center+axis*.29,.083,navy,10)
for offset,size in [(Vector((-.07,0,.07)),.048),(Vector((.045,0,.12)),.023)]:
    p=center+axis*.811+side*offset.x+up*offset.z
    rod('Soft lens glint',p,p+axis*.006,size,highlight,6)

# A tiny field notebook and a wooden stool make the facility inviting without text labels.
cone('Observer stool seat',(-.52,-.48,.65),.23,.12,wood,vertices=10)
for angle in [0,math.tau/3,math.tau*2/3]:
    rod('Stool leg',(-.52+math.cos(angle)*.13,-.48+math.sin(angle)*.13,.27),(-.52+math.cos(angle)*.10,-.48+math.sin(angle)*.10,.60),.035,navy,8)
book=box('Closed star notebook',(.48,-.34,.29),(.27,.19,.06),navylight,.015);book.rotation_euler.z=-.24
box('Notebook gold clasp',(.48,-.35,.326),(.035,.08,.012),brass,.003)

parts=[o for o in bpy.context.scene.objects if o.type=='MESH']
bpy.ops.object.select_all(action='DESELECT')
for o in parts:o.select_set(True)
bpy.context.view_layer.objects.active=parts[0]
bpy.ops.object.join()
model=bpy.context.object;model.name='HilltopTelescope'
bpy.context.scene.cursor.location=(0,0,0);bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
out=ROOT/'assets/models/telescope.glb';out.parent.mkdir(parents=True,exist_ok=True)
bpy.ops.export_scene.gltf(filepath=str(out),export_format='GLB',export_yup=True,export_apply=True,use_selection=True)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art-source/telescope.blend'))
print('TELESCOPE_ASSET',len(model.data.vertices),'vertices',len(model.data.polygons),'faces',tuple(model.dimensions))
