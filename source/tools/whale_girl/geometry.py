"""Geometry vocabulary shared by the authored whale-girl components.

Coordinates are Blender rest space, with +X to the character's left and -Y
forward. Keeping the mesh vertices in rig space also keeps shape keys and
skin weights independent of Blender operator state.
"""
import math
from pathlib import Path
import bpy
from mathutils import Vector, Euler

MATERIALS = {}
PARTS = []
SECTION = ''
# Horizontal sections trace the illustration from the chin to the occiput.
# The lower face projects in front of the neck rather than tapering around it.
PROFILE = [
    (.947,.013,-.167,.016),(.955,.087,-.155,.066),(.968,.151,-.129,.113),
    (.986,.190,-.095,.165),(1.015,.232,-.058,.221),(1.050,.266,-.032,.253),
    (1.100,.301,-.008,.276),(1.157,.326,.004,.282),(1.227,.339,.013,.295),
    (1.322,.341,.024,.306),(1.412,.317,.032,.286),(1.495,.275,.030,.248),
    (1.561,.207,.022,.192),(1.607,.122,.020,.116),(1.630,.015,.019,.018)]

def linear(v):
    v=max(0.,min(1.,v))
    return v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4

def material(name, color, metal=0., rough=.64):
    if name not in MATERIALS:
        s=color.strip('#')
        if len(s)==3:s=''.join(c*2 for c in s)
        rgb=tuple(linear(int(s[i:i+2],16)/255) for i in (0,2,4))
        m=bpy.data.materials.new(name);m.diffuse_color=(*rgb,1);m.use_nodes=True
        bs=m.node_tree.nodes.get('Principled BSDF')
        bs.inputs['Base Color'].default_value=(*rgb,1)
        bs.inputs['Metallic'].default_value=metal;bs.inputs['Roughness'].default_value=rough
        MATERIALS[name]=m
    return name

def palette():
    for name,col in dict(skin='FFDBCD',ink='202040',cream='FFEFDC',navy='26345F',
                         gold='EDBD71',blush='F3A09D',hair='414D99',aqua='83D5F0',white='FFFCF3').items():
        material(name,col)

def head_profile(z):
    z=max(PROFILE[0][0],min(PROFILE[-1][0],z))
    for i,(a,b) in enumerate(zip(PROFILE,PROFILE[1:])):
        if z<=b[0]:
            before=PROFILE[max(0,i-1)]
            after=PROFILE[min(len(PROFILE)-1,i+2)]
            dz=b[0]-a[0]
            t=(z-a[0])/dz
            values=[]
            for k in (1,2,3):
                m0=(b[k]-before[k])/(b[0]-before[0])
                m1=(after[k]-a[k])/(after[0]-a[0])
                values.append(a[k]+(b[k]-a[k])*t*t*(3-2*t)+dz*t*(1-t)*((1-t)*m0-t*m1))
            return values

def face_y(x,z):
    w,y,d=head_profile(z)
    # Gentle muzzle and nasal relief is visible in profile. Their roots taper
    # into the cheek at both sides instead of leaving a separate "bead" nose.
    nasal=.023*math.exp(-(x/.032)**2-((z-1.072)/.036)**2)
    lips=.009*math.exp(-(x/.061)**2-((z-1.024)/.028)**2)
    chin=.014*math.exp(-(x/.075)**2-((z-.978)/.027)**2)
    return y-d*math.sqrt(max(0.,1.-(x/w)**2))-nasal-lips-chin

def texture_paint(obj,pixels,map_name):
    mat=MATERIALS.get(map_name)
    if not mat:
        material(map_name,"ffffff",rough=.81)
        mat=MATERIALS[map_name]
        path=Path(__file__).resolve().parents[2]/"art-source"/"whale-girl-paint"/(map_name+".png")
        im=bpy.data.images.load(str(path),check_existing=True)
        im.pack()
        tex=mat.node_tree.nodes.new("ShaderNodeTexImage")
        tex.image=im
        tex.extension="EXTEND"
        bs=mat.node_tree.nodes.get("Principled BSDF")
        mat.node_tree.links.new(tex.outputs["Color"],bs.inputs["Base Color"])
        mat.node_tree.links.new(tex.outputs["Color"],bs.inputs["Emission Color"])
        bs.inputs["Emission Strength"].default_value=.21
        bs.inputs["Specular IOR Level"].default_value=.14
    obj.data.materials[0]=mat
    uv=obj.data.uv_layers.new(name="Illustration")
    width,height=450,656
    for loop in obj.data.loops:
        u,v=pixels[loop.vertex_index]
        uv.data[loop.index].uv=((u+.5)/width,1-(v+.5)/height)

def painted(name,bone,verts,faces,pixels):
    obj=mesh(name,bone,"white",verts,faces)
    texture_paint(obj,pixels,"front-hair" if SECTION in ("fringe","mantle") else "costume-and-face")
    return obj

def backpainted(name,bone,verts,faces,pixels):
    obj=mesh(name,bone,"white",verts,faces)
    texture_paint(obj,pixels,"back-hair")
    return obj

def mesh(name,bone,mat,verts,faces,smooth=True):
    verts=[tuple(v) for v in verts];faces=[tuple(f) for f in faces]
    if not verts or len(verts)>50000 or len(faces)>65000:raise ValueError(name)
    data=bpy.data.meshes.new(name);data.from_pydata(verts,[],faces);data.validate();data.update()
    obj=bpy.data.objects.new(name,data);bpy.context.collection.objects.link(obj)
    data.materials.append(MATERIALS[mat])
    if smooth:data.polygons.foreach_set('use_smooth',[True]*len(data.polygons))
    if isinstance(bone,str):
        obj.vertex_groups.new(name=bone).add(list(range(len(verts))),1,'REPLACE')
    else:
        groups={}
        for i,v in enumerate(verts):
            weights=bone(*v)
            for k,weight in weights.items():
                if weight<=0:continue
                if k not in groups:groups[k]=obj.vertex_groups.new(name=k)
                groups[k].add([i],weight,'REPLACE')
    PARTS.append((obj,SECTION))
    return obj

def rings_mesh(name,bone,mat,rows):
    n=len(rows[0]);faces=[tuple(reversed(range(n)))]
    for j in range(len(rows)-1):
        for i in range(n):
            a=j*n+i;b=j*n+(i+1)%n
            faces.append((a,b,b+n,a+n))
    faces.append(tuple(range((len(rows)-1)*n,len(rows)*n)))
    return mesh(name,bone,mat,[v for row in rows for v in row],faces)

def loft(name,bone,mat,rings,n=40):
    rows=[[(x+rx*math.sin(i*math.tau/n),y-ry*math.cos(i*math.tau/n),z) for i in range(n)] for z,x,y,rx,ry in rings]
    if rings[-1][0]<rings[0][0]:rows.reverse()
    return rings_mesh(name,bone,mat,rows)

def oval(name,bone,mat,center,radii,rot=(0,0,0)):
    rot=Euler(rot).to_matrix();p=Vector(center);x,y,z=radii
    n,levels=(14,9) if max(radii)<.045 else (24,15)
    rows=[]
    for j in range(levels):
        lat=-math.pi*.5+math.pi*(.0005+.999*j/(levels-1))
        rows.append([p+rot@Vector((x*math.cos(lat)*math.cos(i*math.tau/n),
                                   y*math.cos(lat)*math.sin(i*math.tau/n),z*math.sin(lat))) for i in range(n)])
    return rings_mesh(name,bone,mat,rows)

def strand(name,bone,mat,keys,axis=(1,0,0),n=12):
    keys=[tuple(k) for k in keys];samples=[]
    steps=1 if len(keys)>40 else 4
    for j,(p1,p2) in enumerate(zip(keys,keys[1:])):
        p0=keys[max(0,j-1)];p3=keys[min(len(keys)-1,j+2)]
        for step in range(steps):
            t=step/steps
            samples.append(tuple(.5*((2*b)+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t**3) for a,b,c,d in zip(p0,p1,p2,p3)))
    samples.append(keys[-1])
    rows=[];previous=None
    for i,k in enumerate(samples):
        p=Vector(k[:3]);tangent=(Vector(samples[min(i+1,len(samples)-1)][:3])-Vector(samples[max(0,i-1)][:3])).normalized()
        if tangent.length<.001:tangent=Vector((0,0,1))
        axisv=Vector(axis);u=axisv-tangent*tangent.dot(axisv)
        if u.length<.05:u=tangent.orthogonal()
        u.normalize()
        if previous is not None and previous.dot(u)<0:u=-u
        previous=u;v=tangent.cross(u)
        rows.append([p+u*(max(.00008,k[3])*math.cos(j*math.tau/n))+v*(max(.00008,k[4])*math.sin(j*math.tau/n)) for j in range(n)])
    return rings_mesh(name,bone,mat,rows)

def tube(name,bone,mat,points,radii,n=8):
    if isinstance(radii,(int,float)):radii=[radii]*len(points)
    keys=[(*p,r,r) for p,r in zip(points,radii)]
    return strand(name,bone,mat,keys,n=n)

def shape(obj,name,transform):
    if not obj.data.shape_keys:obj.shape_key_add(name='Basis')
    key=obj.shape_key_add(name=name)
    for i,v in enumerate(obj.data.vertices):key.data[i].co=transform(*v.co)
    return key

def tint(obj,fn):
    mat_name='Pigment '+obj.data.materials[0].name
    m=bpy.data.materials.get(mat_name)
    if not m:
        m=obj.data.materials[0].copy();m.name=mat_name
        col=m.node_tree.nodes.new('ShaderNodeVertexColor');col.layer_name='Paint'
        m.node_tree.links.new(col.outputs['Color'],m.node_tree.nodes.get('Principled BSDF').inputs['Base Color'])
    obj.data.materials[0]=m
    if obj.name.startswith("Face - chin"):
        # Broad, warm fill preserves the drawn facial planes as the head turns.
        face_material=m.copy()
        face_material.name="Painted complexion"
        tree=face_material.node_tree
        bs=tree.nodes.get("Principled BSDF")
        bs.inputs["Specular IOR Level"].default_value=.07
        bs.inputs["Roughness"].default_value=.94
        bs.inputs["Emission Color"].default_value=(.92,.74,.68,1)
        bs.inputs["Emission Strength"].default_value=.17
        obj.data.materials[0]=face_material
    attr=obj.data.color_attributes.new(name='Paint',type='FLOAT_COLOR',domain='POINT')
    for i,v in enumerate(obj.data.vertices):attr.data[i].color=(*[linear(c) for c in fn(*v.co)[:3]],1.)
