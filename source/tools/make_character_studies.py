"""Original opaque character proportion studies; does not replace the shipped builder.

Blender --background --python source/tools/make_character_studies.py
Outputs editable studies to work/qa10/character-study.
Design references: Valve's Character Art Guide (silhouette/direction/value hierarchy),
and Animation Mentor's Squash and Stretch (brief deformation, conserved volume).
"""
import bpy,math
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'work/qa10/character-study';OUT.mkdir(parents=True,exist_ok=True)
bpy.context.preferences.filepaths.save_version=0
def linear(c):return c/12.92 if c<=.04045 else ((c+.055)/1.055)**2.4
def material(name,color,rough=.27):
    m=bpy.data.materials.new(name);m.use_nodes=True
    rgb=[linear(int(color[i:i+2],16)/255) for i in (0,2,4)]
    shader=m.node_tree.nodes.get('Principled BSDF');shader.inputs['Base Color'].default_value=(*rgb,1);shader.inputs['Roughness'].default_value=rough;shader.inputs['Specular IOR Level'].default_value=.52;shader.inputs['Coat Weight'].default_value=.28;shader.inputs['Coat Roughness'].default_value=.22
    return m
def empty(name,parent=None,p=(0,0,0)):
    o=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(o);o.parent=parent;o.location=p;return o
def sphere(name,p,scale,mat,parent=None):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24,ring_count=16,radius=1,location=p)
    o=bpy.context.object;o.name=name;o.scale=scale;o.data.materials.append(mat);o.parent=parent
    for f in o.data.polygons:f.use_smooth=True
    return o
def tube(name,a,b,r1,r2,mat,parent=None):
    a,b=Vector(a),Vector(b);length=(b-a).length
    vertices=[];faces=[];rings=12;segments=16
    for j in range(rings+1):
        t=j/rings;angle=t*math.pi
        z=math.cos(angle)*((length/2)+max(r1,r2))
        if j<rings/2:radius=r1*math.sin(min(math.pi/2,angle*2));z=length/2+r1*math.cos(min(math.pi/2,angle*2))
        elif j>rings/2:radius=r2*math.sin(min(math.pi/2,(math.pi-angle)*2));z=-length/2-r2*math.cos(min(math.pi/2,(math.pi-angle)*2))
        else:radius=(r1+r2)/2;z=0
        for i in range(segments):
            ar=i/segments*math.tau;vertices.append((radius*math.cos(ar),radius*math.sin(ar),z))
    for j in range(rings):
        for i in range(segments):
            k=j*segments+i;next=j*segments+(i+1)%segments;faces.append((k,next,next+segments,k+segments))
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(vertices,[],faces);mesh.update();o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o)
    o.location=(a+b)/2;o.rotation_euler=(a-b).to_track_quat('Z','Y').to_euler();o.data.materials.append(mat);o.parent=parent;return o
def torso(name,rings,mat):
    vertices=[];faces=[];n=24
    for z,rx,ry in rings:
        for i in range(n):
            a=i/n*math.tau;vertices.append((math.cos(a)*rx,math.sin(a)*ry,z))
    for j in range(len(rings)-1):
        for i in range(n):
            k=j*n+i;next=j*n+(i+1)%n;faces.append((k,next,next+n,k+n))
    faces.extend([tuple(reversed(range(n))),tuple((len(rings)-1)*n+i for i in range(n))])
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(vertices,[],faces);mesh.update();o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o);o.data.materials.append(mat);return o
def smooth(a,b,x):
    t=max(0,min(1,(x-a)/(b-a)));return t*t*(3-2*t)
def tool_mesh(name,vertices,faces,mat,parent):
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(vertices,[],faces);mesh.update();o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o);o.data.materials.append(mat);o.parent=parent;return o
STUDIES=[
 dict(id='a',name='Light worker',hip=.75,shoulder=1.24,head=1.56,hs=(.213,.193,.222),chest=.225,waist=.175,hips=.190,armx=.285,elbowx=.365,arm=.078,leg=.095,eyes=False),
 dict(id='b',name='Soft worker',hip=.69,shoulder=1.16,head=1.48,hs=(.231,.209,.218),chest=.254,waist=.214,hips=.211,armx=.310,elbowx=.390,arm=.086,leg=.109,eyes=False),
 dict(id='c',name='Scout worker',hip=.80,shoulder=1.30,head=1.63,hs=(.213,.191,.230),chest=.223,waist=.170,hips=.187,armx=.285,elbowx=.367,arm=.078,leg=.093,eyes=False),
 dict(id='d',name='Soft light worker',hip=.75,shoulder=1.24,head=1.56,hs=(.213,.193,.222),chest=.216,waist=.181,hips=.185,armx=.278,elbowx=.360,arm=.076,leg=.093,eyes=False),
]
for cfg in STUDIES:
    if globals().get('INSTALL_D',False) and cfg['id']!='d':continue
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    root=empty('Builder');paint=material('Opaque honey soft glaze','FFCC43');wood=material('Cedar tools','88512F',.65);metal=material('Brushed blue steel','A8CBCC',.33)
    soft=cfg['id']=='d'
    if soft:
        shader=paint.node_tree.nodes.get('Principled BSDF');shader.inputs['Roughness'].default_value=.43;shader.inputs['Coat Weight'].default_value=.09;shader.inputs['Coat Roughness'].default_value=.36
        paint.name='Opaque pearl soft glaze';shader.inputs['Base Color'].default_value=(*(linear(c/255) for c in (243,246,245)),1)
    hip=cfg['hip'];shoulder=cfg['shoulder'];knee=hip*.52;elbow=shoulder-.26;hand=elbow-.22
    parts=[torso('Torso silhouette',[(hip-.15,.09,.105),(hip-.055,cfg['hips'],.145),(hip+.12,cfg['waist'],.135),(shoulder-.12,cfg['chest'],.154),(shoulder+.015,cfg['chest']*.93,.145),(shoulder+.105,.080,.080)],paint)]
    if soft:
        bpy.data.objects.remove(parts.pop(),do_unlink=True)
        parts=[torso('Torso silhouette',[(hip-.115,.147,.101),(hip-.045,cfg['hips'],.121),(hip+.10,cfg['waist'],.135),(shoulder-.16,cfg['chest'],.151),(shoulder-.035,.180,.131),(shoulder+.060,.101,.089),(shoulder+.105,.076,.076)],paint)]
    parts.append(tube('Neck',(0,0,shoulder+.04),(0,0,cfg['head']-cfg['hs'][2]+.09),.076,.073,paint))
    parts.append(sphere('Head',(0,0,cfg['head']),cfg['hs'],paint))
    body_driver=empty('Body',root,(0,0,hip+.02))
    bindings={'Body':((0,0,hip+.02),(0,0,cfg['head']+.15),'Root')}
    neck_height=shoulder+.105
    if soft:
        empty('HeadPivot',body_driver,(0,0,neck_height-hip-.02))
        bindings['Head']=((0,0,neck_height),(0,0,cfg['head']+.15),'Body')
    probes=[]
    for side,sign in [('L',-1),('R',1)]:
        x=sign*.123;leg=empty('Leg'+side,root,(x,0,hip));kn=empty('Knee'+side,leg,(0,0,knee-hip))
        parts.append(tube('Thigh',(x,0,hip-(.10 if soft else .035)),(x,0,knee),cfg['leg']*1.02,cfg['leg']*.93,paint))
        parts.append(tube('Shin',(x,0,knee),(x,.025,.12),cfg['leg']*.93,cfg['leg']*.83,paint))
        foot_y=.035 if soft else .065;foot_z=.076 if soft else .085;foot_depth=.106 if soft else .139
        foot=sphere('Foot',(x,foot_y,foot_z),(cfg['leg']*.91,foot_depth,.075 if soft else .079),paint);parts.append(foot)
        probe=sphere('FootProbe'+side,(0,foot_y,foot_z-knee),(cfg['leg']*.91,foot_depth,.075 if soft else .079),paint,kn);probe.display_type='WIRE';probes.append(probe)
        bindings['Leg'+side]=((x,0,hip),(x,0,knee),'Root');bindings['Knee'+side]=((x,0,knee),(x,.025,.08),'Leg'+side)
        ax=sign*cfg['armx'];ex=sign*cfg['elbowx'];arm=empty('Arm'+side,root,(ax,0,shoulder));el=empty('Elbow'+side,arm,(ex-ax,0,elbow-shoulder))
        parts.append(tube('UpperArm',(ax,0,shoulder-(.075 if soft else .01)),(ex,0,elbow),cfg['arm']*(1.01 if soft else 1.10),cfg['arm'],paint))
        parts.append(tube('Forearm',(ex,0,elbow),(ex,.13,hand-(.025 if soft else 0)),cfg['arm'],cfg['arm']*(1.01 if soft else .92),paint))
        if not soft:parts.append(sphere('Hand',(ex,.13,hand-.01),(cfg['arm']*1.10,cfg['arm']*1.13,cfg['arm']*1.15),paint))
        # A tapered shoulder bridge is part of the torso, never a round socket cap.
        parts.append(tube('Shoulder bridge',(sign*cfg['chest']*.70,0,shoulder+.005),(ax,0,shoulder-(.075 if soft else .025)),cfg['arm']*(1.02 if soft else 1.15),cfg['arm']*(1.01 if soft else 1.10),paint))
        bindings['Arm'+side]=((ax,0,shoulder),(ex,0,elbow),'Body');bindings['Elbow'+side]=((ex,0,elbow),(ex,.13,hand-.01),'Arm'+side)
        if side=='R':
            grip=empty('Grip',el,(0,.13,hand-.01-elbow))
            for tool_name in ['Axe','Pickaxe','Mallet']:
                tool=empty(tool_name,grip);tube('Handle',(0,-.17,0),(0,.43,0),.029,.029,wood,tool)
                if tool_name=='Mallet':
                    bpy.ops.mesh.primitive_cube_add(size=1,location=(0,.42,0));o=bpy.context.object;o.name='Mallet head';o.scale=(.17,.17,.32);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);bevel=o.modifiers.new('Rounded wooden corners','BEVEL');bevel.width=.04;bevel.segments=2;bpy.ops.object.modifier_apply(modifier=bevel.name);o.data.materials.append(wood);o.parent=tool
                elif tool_name=='Axe':
                    tool_mesh('Broad axe',[(0,.28,-.06),(0,.51,-.10),(0,.55,.22),(0,.33,.29),(.06,.28,-.06),(.06,.51,-.10),(.06,.55,.22),(.06,.33,.29)],[(0,1,2,3),(7,6,5,4),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0)],metal,tool)
                else:
                    for tip in [-1,1]:
                        tube('Pick crown',(0,.40,0),(0,.46,tip*.18),.045,.045,metal,tool)
                        tool_mesh('Tapered tip',[(-.05,.42,tip*.15),(.05,.42,tip*.15),(.05,.50,tip*.15),(-.05,.50,tip*.15),(0,.35,tip*.39)],[(0,1,4),(1,2,4),(2,3,4),(3,0,4),(0,3,2,1)],metal,tool)
    bpy.ops.object.select_all(action='DESELECT')
    for o in parts:o.select_set(True)
    bpy.context.view_layer.objects.active=parts[0];bpy.ops.object.join();skin=bpy.context.object;skin.name='ContinuousBody'
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    modifier=skin.modifiers.new('Welded clean silhouette','REMESH');modifier.mode='VOXEL';modifier.voxel_size=.012;modifier.use_smooth_shade=True;bpy.ops.object.modifier_apply(modifier=modifier.name)
    modifier=skin.modifiers.new('Soft transitions','SMOOTH');modifier.factor=.48;modifier.iterations=4;bpy.ops.object.modifier_apply(modifier=modifier.name)
    modifier=skin.modifiers.new('Game budget','DECIMATE');modifier.ratio=.48;bpy.ops.object.modifier_apply(modifier=modifier.name)
    skin.data.validate(clean_customdata=True);skin.data.update()
    for face in skin.data.polygons:face.use_smooth=True
    skin.data.materials.clear();skin.data.materials.append(paint)
    if soft:
        colors=skin.data.color_attributes.new(name='Body value',type='FLOAT_COLOR',domain='POINT')
        base=tuple(paint.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value)
        for vertex in skin.data.vertices:
            amount=.88+.12*smooth(.05,cfg['head'],vertex.co.z);colors.data[vertex.index].color=(*(channel*amount for channel in base[:3]),1)
        color_node=paint.node_tree.nodes.new('ShaderNodeVertexColor');color_node.layer_name='Body value'
        paint.node_tree.links.new(color_node.outputs['Color'],paint.node_tree.nodes.get('Principled BSDF').inputs['Base Color'])
    armature=bpy.data.armatures.new('Soft worker skin');rig=bpy.data.objects.new('BuilderSkinRig',armature);bpy.context.collection.objects.link(rig)
    bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);bpy.context.view_layer.objects.active=rig;bpy.ops.object.mode_set(mode='EDIT')
    bone=armature.edit_bones.new('SkinRoot');bone.head=(0,0,.02);bone.tail=(0,0,hip+.02)
    for name,(head,tail,parent) in bindings.items():
        bone=armature.edit_bones.new('Skin'+name);bone.head=head;bone.tail=tail;bone.parent=armature.edit_bones['Skin'+parent]
    bpy.ops.object.mode_set(mode='OBJECT');skin.select_set(True);bpy.context.view_layer.objects.active=rig;bpy.ops.object.parent_set(type='ARMATURE_NAME');rig.parent=root
    for vertex in skin.data.vertices:
        x,y,z=vertex.co;side='L' if x<0 else 'R';weights={'SkinBody':1.0}
        arm_boundary=cfg['chest']+.010
        if z<shoulder+.09 and abs(x)>arm_boundary:
            arm=smooth(arm_boundary,cfg['armx']+.025,abs(x)) if z>shoulder-.08 else 1.0;forearm=1-smooth(elbow-.075,elbow+.085,z)
            weights={'SkinBody':1-arm,'SkinArm'+side:arm*(1-forearm),'SkinElbow'+side:arm*forearm}
        elif z<hip+.05:
            leg=1-smooth(hip-.12,hip+.05,z);shin=1-smooth(knee-.065,knee+.095,z);weights={'SkinBody':1-leg,'SkinLeg'+side:leg*(1-shin),'SkinKnee'+side:leg*shin}
        if soft and z>neck_height-.035:
            head_weight=smooth(neck_height-.035,neck_height+.045,z);weights={'SkinBody':1-head_weight,'SkinHead':head_weight}
        for name,weight in weights.items():
            if weight>.0001:skin.vertex_groups[name].add([vertex.index],weight,'REPLACE')
    if cfg['eyes']:
        ink=material('Quiet dark eyes','173E4A',.32)
        for x in [-.067,.067]:sphere('Eye',(x,cfg['hs'][1]*.955,cfg['head']+.016),(.022,.012,.030),ink,body_driver).location.z-=hip+.02
    path=OUT/cfg['id'];path.mkdir(exist_ok=True)
    model_path=ROOT/'source/assets/models/builder.glb' if globals().get('INSTALL_D',False) else path/'builder.glb'
    blend_path=ROOT/'source/art-source/builder.blend' if globals().get('INSTALL_D',False) else path/'builder.blend'
    bpy.ops.export_scene.gltf(filepath=str(model_path),export_format='GLB',export_yup=True,export_apply=False)
    bpy.ops.wm.save_as_mainfile(filepath=str(blend_path))
    print('STUDY',cfg['id'],cfg['name'],len(skin.data.vertices),'vertices')
