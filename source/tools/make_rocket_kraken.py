"""Build the sections of a submerged animal that hold the launch island.

Coordinates in the tables are (east, forward, elevation, radius) in game metres,
relative to the rocket tile. The actor has no authored head or body. Morphs are
generated from the same sweep and attachment coordinates as the resting mesh.
Run inside Blender 4.4 with --background --python.
"""
from pathlib import Path
from math import sin, cos, tau, pi, exp
import bpy
from mathutils import Vector, Quaternion

ROOT = Path(__file__).resolve().parents[1]
SIDES = 16
STEPS = 4
# Each arm has a different gesture. Both ends of the breach plunge through the surface.
ARMS = {
    "CrownCoil": [
        (-4.05,-2.5,-4.20,.98),(-3.35,-2.15,-2.38,.85),
        (-2.82,-1.78,-.78,.71),(-2.41,-1.55,.25,.61),(-1.81,-1.28,.96,.52),
        (-1.13,-.85,1.05,.46),(-.89,-.28,.96,.43),(-.86,.36,1.00,.40),
        (-.43,.83,1.12,.36),(.18,.84,1.31,.31),(.67,.48,1.51,.26),
        (.73,-.10,1.70,.21),(.42,-.51,1.91,.16),(-.05,-.60,2.10,.12),
        (-.41,-.43,2.25,.08),(-.54,-.17,2.32,.042),(-.52,.02,2.31,.012)
    ],
    "ShelfGrip": [
        (6.05,.12,-5.0,1.14),(5.55,-.36,-3.08,1.0),(4.84,-.68,-1.45,.84),
        (4.38,-.73,-.19,.73),(3.94,-.64,.59,.64),(3.34,-.46,.82,.56),
        (2.85,-.16,.65,.47),(2.55,.18,.39,.39),(2.41,.56,.19,.29),
        (2.51,.92,.095,.20),(2.78,1.10,-.03,.125),(3.0,1.10,-.20,.062),
        (3.06,.99,-.35,.016)
    ],
    "BreachArch": [
        (-3.72,3.10,-4.76,1.12),(-3.76,2.94,-3.02,1.02),(-3.25,2.67,-1.39,.94),
        (-2.70,2.33,-.30,.85),(-2.15,2.17,.15,.78),(-1.38,2.14,.28,.71),
        (-.65,2.37,.11,.62),(.05,2.81,-.27,.56),(.55,3.50,-.95,.52),
        (1.10,3.95,-1.72,.48),(1.64,4.23,-3.46,.44)
    ],
    "SpurHook": [
        (.44,-4.57,-4.42,.65),(.58,-3.86,-2.85,.55),(.85,-3.35,-1.63,.46),
        (1.17,-2.94,-.60,.39),(1.58,-2.62,.02,.32),(1.99,-2.47,.20,.27),
        (2.35,-2.50,.11,.20),(2.54,-2.73,-.12,.14),
        (2.48,-2.98,-.36,.080),(2.29,-3.05,-.48,.018)
    ],
}
# Rolling the sucker fields about their local tangent shows selected sections of
# the underside. The remaining surface is uninterrupted muscle rather than dots.
ROLL = {"CrownCoil":.42,"ShelfGrip":-.52,"BreachArch":-.34,"SpurHook":.55}

def smooth(a,b,v):
    f=min(1,max(0,(v-a)/(b-a)))
    return f*f*(3-2*f)

def local(x,forward,height):
    return Vector((x,-forward,height))

def linear(rgb):
    def c(value):
        x=int(value,16)/255
        return x/12.92 if x<=.04045 else ((x+.055)/1.055)**2.4
    return Vector([c(rgb[i:i+2]) for i in (0,2,4)])

DORSAL=linear("244B57")
FLANK=linear("464159")
BELLY=linear("795663")
RIDGE=linear("388481")
CUP=linear("AB8C99")
CUP_WALL=linear("856577")
CUP_HOLE=linear("584455")

def sample(knots,t):
    x=max(0,min(t,1))*(len(knots)-1)
    index=min(int(x),len(knots)-2)
    a,b,c,d=[Vector(knots[max(0,min(len(knots)-1,i))]) for i in (index-1,index,index+1,index+2)]
    u=x-index
    return .5*(2*b+(c-a)*u+(2*a-5*b+4*c-d)*(u*u)+(-a+3*b-3*c+d)*(u*u*u))

def center(name,t,pose):
    x,z,h,r=sample(ARMS[name],t)
    # Bury the unseen cut ends below the deepest possible seabed (radius 7.62).
    foot=1-smooth(.0,.23,t)
    h-=5.4*foot
    x-=.95*foot if name=="ShelfGrip" else 0
    if name=="BreachArch":
        x+=.55*foot
        z-=.6*foot
        h-=5.1*smooth(.79,1,t)
    edge=smooth(.06,.5,t)
    if pose=="Release":
        if name=="CrownCoil":
            # Slide the curl away from the hull in its own radial direction.
            outward=Vector((x,z)).normalized()
            clearance=2.5*smooth(.28,.70,t)
            x+=outward.x*clearance-.53*edge
            z+=outward.y*clearance-.54*edge
            h-=edge*(3.20+1.45*smooth(.30,.8,t))+2.25*smooth(.0,.22,t)
        elif name=="ShelfGrip":
            x+=1.7*edge;z-=.77*edge;h-=2.8*edge+2.4*smooth(.0,.27,t)
        elif name=="BreachArch":
            x-=.95;z+=.80;h-=.86+.40*t
        else:
            z-=.6*edge;h-=2.0*edge
    elif pose=="Breath":
        w=sin(t*pi)*(.035 if name=="CrownCoil" else .090)
        x+=w*sin(pi*t*2);h+=w;z+=.025*sin(t*tau)
    elif pose=="Pulse":
        w=sin(t*pi)*(.055 if name=="CrownCoil" else .13)
        h+=w*sin(1.55*pi*t);x+=w*cos(1.6*pi*t)
        r*=1+.06*exp(-((t-.48)/.18)**2)
    return local(x,z,h),r

def frame(name,t,pose):
    c,r=center(name,t,pose)
    tangent=(center(name,min(1,t+.0005),pose)[0]-center(name,max(0,t-.0005),pose)[0]).normalized()
    # A parallel-transported reference frame is supplied by the caller.
    return c,r,tangent

class Brush:
    def __init__(self):self.verts=[];self.faces=[];self.colors=[];self.soft=[]
    def point(self,v,col):
        self.verts.append(tuple(v));self.colors.append(tuple(col)+(1.0,));return len(self.verts)-1
    def face(self,seq,soft):
        self.faces.append(tuple(seq));self.soft.append(soft)
    def join(self,one,two,soft=True):
        for i,a in enumerate(one):self.face([a,one[(i+1)%len(one)],two[(i+1)%len(two)],two[i]],soft)

def skin(c,r,side,cross,a,u):
    relief=(1+.046*cos(3*a+u*4.6)+.028*sin(5*a-u*3))*(1+.025*sin(u*tau*2.4))
    return c+relief*r*(side*cos(a)*.87+cross*sin(a))

def geometry(name,pose):
    count=(len(ARMS[name])-1)*STEPS+1
    brush=Brush();frames=[];rings=[]
    prev_tangent=None;normal=None
    for j in range(count):
        u=j/(count-1);c,r,tangent=frame(name,u,pose)
        if normal is None:
            ref=Vector((-.20,-1,-.28))
            normal=(ref-tangent*tangent.dot(ref)).normalized()
        else:normal=prev_tangent.rotation_difference(tangent)@normal
        prev_tangent=tangent
        side=Quaternion(tangent,ROLL[name]+.75*sin(u*pi*1.65))@normal
        cross=tangent.cross(side).normalized()
        frames.append((c,r,tangent,side,cross))
        ring=[]
        for i in range(SIDES):
            a=tau*i/SIDES
            v=skin(c,r,side,cross,a,u)
            # The warm belly has a broken blue-green seam on either shoulder.
            belly=smooth(.23,.89,cos(a))
            blue=smooth(-.08,.48,-cos(a))
            color=FLANK.lerp(DORSAL,blue).lerp(BELLY,belly)
            stripe=exp(-((cos(a)-.05)/.18)**2)*(.35+.32*(.5+.5*sin(22*u+sin(a)*4)))
            color=color.lerp(RIDGE,stripe)
            color*=.89+.10*(.5+.5*cos(a*4+u*10))
            ring.append(brush.point(v,color))
        if rings:brush.join(rings[-1],ring)
        rings.append(ring)
    brush.face(reversed(rings[0]),False);brush.face(rings[-1],False)
    # Broken, narrow longitudinal folds along the flank. Each raised crest
    # follows the turning skin; hips/no rigid spikes are added to the outline.
    for sign in [-1,1]:
        for start,end,phase in [(.20,.49,.24),(.53,.78,1.03),(.83,.94,2.15)]:
            sections=[q for q in range(count) if start<=q/(count-1)<=end]
            previous=[]
            for n,j in enumerate(sections):
                u=j/(count-1);c,r,tangent,side,cross=frames[j]
                amp=max(.02,sin(pi*n/max(1,len(sections)-1)))
                a=sign*(1.65+.17*sin(10*u+phase))
                rim=[]
                for da,raise_by,col in [(-.08,-.015,DORSAL),(0,.048,RIDGE),(.08,-.015,DORSAL)]:
                    angle=a+amp*da
                    outward=(side*cos(angle)+cross*sin(angle)).normalized()
                    p=skin(c,r,side,cross,angle,u)+outward*raise_by*r*amp
                    rim.append(brush.point(p,col.lerp(DORSAL,.30)))
                if previous:
                    for k in range(2):brush.face([previous[k],previous[k+1],rim[k+1],rim[k]],True)
                previous=rim
    # Cupped rims are actual geometry, with a recessed inner cup and scalloped
    # seating. A stagger and size falloff give the underside an organic cadence.
    spacing=3 if name!='BreachArch' else 4
    for j in range(5,count-3,spacing):
        for row in [-1,1]:
            k=j+(1 if row<0 else 0)
            c,r,tangent,side,cross=frames[k]
            u=k/(count-1)
            if u<.18 or r<.075:continue
            a=row*(.46+.07*sin(u*17))
            outward=(side*cos(a)+cross*sin(a)).normalized()
            across=tangent.cross(outward).normalized()
            base=skin(c,r,side,cross,a,u)-outward*r*.025
            radius=r*(.245+.035*sin(j+row))
            layers=[]
            for sz,lift,color in [(.74,-.12,BELLY),(.92,.16,CUP_WALL),(1.0,.37,CUP_WALL),(.88,.56,CUP),(.65,.56,CUP),(.52,.39,CUP_WALL),(.38,.23,CUP_HOLE)]:
                ring=[]
                for i in range(10):
                    b=i*tau/10
                    p=base+outward*(lift*radius)+radius*sz*(across*cos(b)*.96+tangent*sin(b)*1.13)
                    ring.append(brush.point(p,color))
                if layers:brush.join(layers[-1],ring,True)
                layers.append(ring)
            brush.face(layers[-1],False)
    return brush

def create_arm(name,material):
    arm=geometry(name,"Grip")
    data=bpy.data.meshes.new(name+"Surface")
    data.from_pydata(arm.verts,[],arm.faces);data.update()
    color=data.color_attributes.new(name="TideSkin",type="FLOAT_COLOR",domain="POINT")
    for i,v in enumerate(arm.colors):color.data[i].color=v
    for p,soft in zip(data.polygons,arm.soft):p.use_smooth=soft
    # Recalculate winding for the cup rings and the curved closed tubes.
    import bmesh
    bm=bmesh.new();bm.from_mesh(data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(data);bm.free()
    o=bpy.data.objects.new(name,data);bpy.context.collection.objects.link(o)
    o.data.materials.append(material);o.shape_key_add(name="Basis")
    for pose in ["Release","Breath","Pulse"]:
        shape=geometry(name,pose)
        assert len(shape.verts)==len(arm.verts)
        key=o.shape_key_add(name=pose)
        key.data.foreach_set("co",[n for v in shape.verts for n in v])
    return o

def build():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.filepaths.save_version=0
    m=bpy.data.materials.new("Brine / glancing light");m.use_nodes=True;m.diffuse_color=(.10,.13,.18,1)
    bs=m.node_tree.nodes.get("Principled BSDF");bs.inputs["Roughness"].default_value=.43
    bs.inputs["Metallic"].default_value=.09
    vertex=m.node_tree.nodes.new("ShaderNodeVertexColor");vertex.layer_name="TideSkin"
    m.node_tree.links.new(vertex.outputs["Color"],bs.inputs["Base Color"])
    for name in ARMS:create_arm(name,m)
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/"art-source/rocket_kraken.blend"))
    bpy.ops.export_scene.gltf(filepath=str(ROOT/"assets/models/rocket_kraken.glb"),export_format="GLB",export_yup=True,export_animations=False,export_morph=True,export_morph_normal=True,export_vertex_color="MATERIAL")

if __name__=="__main__":build()
