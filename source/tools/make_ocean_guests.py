"""Four original articulated ocean animals. Blender +Y forward, +Z up.

Run Blender in background with --python make_ocean_guests.py. Optional
-- --only wild_dolphin,wild_seahorse,wild_puffer,wild_squid limits exports.
Continuous lofted skins and solid fins retain named pivots in GLB and .blend.
"""
import math
import sys
from pathlib import Path

import bpy
import bmesh
from mathutils import Vector
from mathutils.geometry import delaunay_2d_cdt

sys.path.insert(0, str(Path(__file__).resolve().parent))
from wildlife_mesh import clean, material, node, ico, mesh, export

ink = material('marine eye deep ink', '172F3C')
ivory = material('warm marine ivory', 'F2E5C8')
blue = material('dolphin blue grey', '648D9F')
blue_back = material('dolphin slate back', '476C85')
blue_belly = material('dolphin pearl belly', 'C7D7D3')
amber = material('seahorse honey', 'D6A453')
amber_back = material('seahorse warm ochre', 'A67842')
amber_belly = material('seahorse golden cream', 'EBD39B')
amber_band = material('seahorse bony rings', 'C48C45')
fin_gold = material('delicate pale fins', 'E4D79E')
puff_gold = material('puffer mustard gold', 'C6A453')
puff_back = material('puffer olive back', '9B934A')
puff_belly = material('puffer ivory belly', 'F0DFA8')
puff_spot = material('puffer olive spots', '686C3F')
salmon = material('squid soft coral', 'CD8D7A')
salmon_back = material('squid terracotta', 'B66A64')
salmon_belly = material('squid pearl cream', 'E8C9AE')
salmon_fin = material('squid fin rose', 'CF9E92')


def loft(parent, name, sections, palette, sides=16):
    """Closed skin along Y; each section is (y, half_width, half_height, z)."""
    verts = []
    for y, width, height, z in sections:
        for j in range(sides):
            angle = 2 * math.pi * j / sides
            verts.append((math.cos(angle) * width, y, z + math.sin(angle) * height))
    faces = [tuple(range(sides))]
    for i in range(len(sections) - 1):
        for j in range(sides):
            k = (j + 1) % sides
            faces.append((i*sides+j, (i+1)*sides+j, (i+1)*sides+k, i*sides+k))
    faces.append(tuple(reversed([(len(sections)-1)*sides+j for j in range(sides)])))
    obj = mesh(name, verts, faces, palette[0], parent)
    for mat in palette[1:]:
        obj.data.materials.append(mat)
    for face in obj.data.polygons:
        if len(palette) >= 3:
            if face.normal.z > .38:
                face.material_index = 1
            elif face.normal.z < -.40:
                face.material_index = 2
    return obj


def tube(parent, name, stations, mat, sides=10, lower=None):
    """Closed curved tube with parallel local frames and no spherical joints.

    Stations contain (x,y,z,width,height). X stays the preferred side axis;
    all limb and seahorse curves progress mostly in their local YZ plane.
    """
    verts = []
    for i, (x, y, z, width, height) in enumerate(stations):
        a = Vector(stations[max(0, i-1)][:3])
        b = Vector(stations[min(len(stations)-1, i+1)][:3])
        forward = (b-a).normalized()
        side = Vector((1,0,0))
        side = (side-forward*side.dot(forward)).normalized()
        up = side.cross(forward).normalized()
        for j in range(sides):
            angle = j * math.tau / sides
            p = Vector((x,y,z)) + side*math.cos(angle)*width + up*math.sin(angle)*height
            verts.append(tuple(p))
    faces = [tuple(range(sides))]
    for i in range(len(stations)-1):
        for j in range(sides):
            k = (j+1)%sides
            faces.append((i*sides+j,(i+1)*sides+j,(i+1)*sides+k,i*sides+k))
    faces.append(tuple(reversed([(len(stations)-1)*sides+j for j in range(sides)])))
    obj = mesh(name, verts, faces, mat, parent)
    if lower:
        obj.data.materials.append(lower)
        for face in obj.data.polygons:
            if face.normal.z < -.35:face.material_index=1
    return obj


def plate(parent, name, outline, thickness, mat, lower=None, axis='Z'):
    """Small solid fin with an actual rim and crowned surfaces."""
    axis_vector = Vector((0,0,1) if axis=='Z' else (1,0,0))
    points = [Vector(p) for p in outline]
    centre = sum(points, Vector()) / len(points)
    n = len(points)
    verts = [tuple(p) for p in points]
    verts += [tuple(p-axis_vector*thickness*.35) for p in points]
    verts += [tuple(centre+axis_vector*thickness), tuple(centre-axis_vector*thickness)]
    faces=[]
    for i in range(n):
        j=(i+1)%n
        faces += [(2*n,i,j),(2*n+1,n+j,n+i),(i,n+i,n+j,j)]
    normal=(points[1]-points[0]).cross(points[2]-points[0])
    if normal.dot(axis_vector)<0:faces=[tuple(reversed(f)) for f in faces]
    obj=mesh(name,verts,faces,mat,parent)
    if lower:
        obj.data.materials.append(lower)
        for f in obj.data.polygons:
            if f.normal.dot(axis_vector)<-.1:f.material_index=1
    return obj


def cone(parent, name, a, b, radius, mat, sides=6):
    a,b=Vector(a),Vector(b)
    bpy.ops.mesh.primitive_cone_add(vertices=sides,radius1=radius,radius2=radius*.12,depth=(b-a).length)
    obj=bpy.context.object;obj.name=name;obj.parent=parent
    obj.location=(a+b)/2;obj.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler()
    obj.data.materials.append(mat)
    return obj


def spotted_puffer(parent):
    """Rounded spots are constrained regions of the same watertight skin.

    A modest parameter-space triangulation puts real curved spot boundaries
    in the mesh. It avoids both floating spot discs and colored quad checks.
    The parameter seam is underneath the pale belly, away from all spots.
    """
    sections=[(-.24,.045,.05,0),(-.205,.11,.12,0),(-.14,.164,.178,0),
        (-.045,.193,.202,0),(.065,.19,.198,0),(.16,.15,.158,-.005),
        (.23,.09,.105,-.013),(.27,.042,.055,-.024),(.28,.02,.03,-.024)]
    # y, angle around the body, longitudinal and angular radii.
    spots=[(-.16,.35,.022,.17),(-.065,.10,.027,.18),(.05,.23,.020,.14),
        (.11,.80,.019,.15),(-.07,1.10,.025,.18),(.025,1.75,.022,.16),
        (-.15,2.18,.020,.17),(-.045,2.78,.028,.19),(.08,3.04,.020,.14),
        (-.145,3.08,.019,.15),(-.185,1.39,.016,.14)]
    lower_angle=-math.pi/2;upper_angle=3*math.pi/2
    # Scale angle to the body's approximate radius so triangulation makes
    # compact physical triangles instead of thin six-radian slivers.
    angular_scale=.19
    verts2=[];edges=[]
    y_values=sorted(set([s[0] for s in sections]+[-.24+i*.52/20 for i in range(21)]))
    boundaries=[math.asin(-.25),math.pi-math.asin(-.25),math.asin(.72),math.pi-math.asin(.72)]
    angles=sorted(set([lower_angle+j*math.tau/40 for j in range(41)]+boundaries))
    for y in y_values:
        start=len(verts2)
        for angle in angles:verts2.append(Vector((y,angle*angular_scale)))
        edges.extend((start+j,start+j+1) for j in range(len(angles)-1))
    for angle in boundaries:
        j=angles.index(angle)
        edges.extend((i*len(angles)+j,(i+1)*len(angles)+j) for i in range(len(y_values)-1))
    for y,a,ry,ra in spots:
        start=len(verts2)
        for j in range(16):
            t=j*math.tau/16;verts2.append(Vector((y+ry*math.cos(t),(a+ra*math.sin(t))*angular_scale)))
        edges.extend((start+j,start+(j+1)%16) for j in range(16))
    planar=delaunay_2d_cdt(verts2,edges,[],0,1e-7,False)
    def profile(y):
        for a,b in zip(sections,sections[1:]):
            if y<=b[0]+1e-6:
                t=max(0,min(1,(y-a[0])/(b[0]-a[0])))
                return tuple(a[k]+(b[k]-a[k])*t for k in [1,2,3])
        return sections[-1][1:]
    vertices=[]
    for uv in planar[0]:
        width,height,z=profile(uv.x)
        angle=uv.y/angular_scale
        vertices.append((math.cos(angle)*width,uv.x,z+math.sin(angle)*height))
    # Parameter-space CCW winding maps to outward-facing skin.
    faces=[tuple(f) for f in planar[2]]
    for y,reverse in [(-.24,False),(.28,True)]:
        ring=sorted([i for i,v in enumerate(planar[0]) if abs(v.x-y)<1e-6],key=lambda i:planar[0][i].y)
        faces.append(tuple(reversed(ring)) if reverse else tuple(ring))
    obj=mesh('round puffer skin with inset spots',vertices,faces,puff_gold,parent)
    for mat in [puff_back,puff_belly,puff_spot]:obj.data.materials.append(mat)
    for face in obj.data.polygons:
        uv=sum((planar[0][i] for i in face.vertices),Vector((0,0)))/len(face.vertices)
        angle=uv.y/angular_scale
        if math.sin(angle)<-.25:face.material_index=2
        elif math.sin(angle)>.72:face.material_index=1
        if any(((uv.x-y)/ry)**2+((angle-a)/ra)**2<.999 for y,a,ry,ra in spots):
            face.material_index=3
    joined=bmesh.new();joined.from_mesh(obj.data)
    bmesh.ops.remove_doubles(joined,verts=list(joined.verts),dist=1e-6)
    bmesh.ops.recalc_face_normals(joined,faces=list(joined.faces))
    joined.to_mesh(obj.data);joined.free();obj.data.update()
    return obj


# Dolphin: melon and beak belong to the same tapered skin. Horizontal flukes
# and swept pectorals distinguish it from the fish already living in the sea.
clean(); root=node('Dolphin'); body=node('Body',root)
loft(body,'continuous dolphin skin',[
    (-.70,.065,.075,-.015),(-.52,.12,.125,-.005),(-.28,.20,.20,0),
    (0,.235,.235,.01),(.26,.22,.225,.02),(.48,.18,.20,.035),
    (.61,.135,.16,.025),(.69,.09,.085,-.035),(.83,.065,.055,-.05),
    (1.00,.03,.035,-.05),(1.035,.008,.018,-.05)],(blue,blue_back,blue_belly))
plate(body,'swept dorsal fin',[(0,-.34,.17),(0,-.13,.49),(0,-.04,.51),
    (0,.025,.42),(0,.07,.22)],.035,blue_back,axis='X')
for s in [-1,1]:
    ico('small dolphin eye',(s*.145,.56,.078),(.018,.023,.018),ink,body,2)
    ico('eye gleam',(s*.158,.566,.083),(.004,.006,.005),ivory,body,1)
tail=node('Tail',root,(0,-.62,-.01))
loft(tail,'flexible tail stock',[(-.50,.035,.031,-.015),(-.34,.053,.045,-.018),
    (-.12,.081,.078,-.005),(.045,.085,.095,0)],(blue,blue_back,blue_belly),12)
fluke=node('Fluke',tail,(0,-.45,-.015))
for s in [-1,1]:
    plate(fluke,'horizontal crescent fluke',[(0,.065,0),(s*.16,.08,.006),
        (s*.42,-.015,.018),(s*.45,-.09,.012),(s*.29,-.15,0),
        (s*.11,-.10,0),(0,-.055,0)],.018,blue,blue_belly)
flippers=[]
for side,s in [('L',-1),('R',1)]:
    fin=node('Flipper'+side,root,(s*.18,.31,-.07));flippers.append(fin)
    plate(fin,'swept pectoral fin',[(s*-.025,.08,.025),(s*.09,.025,-.025),
        (s*.24,-.23,-.13),(s*.25,-.31,-.14),(s*.15,-.25,-.13),
        (s*.015,-.09,-.025)],.021,blue,blue_belly)
export('wild_dolphin',[body,tail,fluke,*flippers])


# Seahorse: one upright chest, a bent horse-like neck, a long snout and a
# coiled grasping tail. A repeated surface tint suggests its bony trunk rings.
clean();root=node('Seahorse');body=node('Body',root)
torso=tube(body,'upright seahorse trunk',[
    (0,-.015,.28,.044,.043),(0,.015,.35,.068,.075),
    (0,.045,.43,.09,.115),(0,.045,.51,.088,.12),
    (0,.02,.59,.07,.09),(0,.005,.66,.05,.055),
    (0,.02,.70,.042,.045)],amber,12,amber_belly)
for mat in [amber_back,amber_band]:torso.data.materials.append(mat)
for f in torso.data.polygons:
    if f.normal.y<-.35:f.material_index=2
    elif int((f.center.z-.28)/.04)%2==0:f.material_index=3
for z,y in [(.37,-.045),(.44,-.066),(.51,-.07),(.58,-.045),(.64,-.03)]:
    cone(body,'short trunk crest',(0,y,z),(0,y-.043,z+.018),.018,amber_back)
head=node('Head',root,(0,.02,.66))
tube(head,'horse head and tubular snout',[
    (0,-.008,-.015,.043,.045),(0,0,.07,.065,.068),
    (0,.075,.135,.076,.072),(0,.155,.12,.060,.053),
    (0,.20,.073,.031,.031),(0,.31,.069,.025,.023),
    (0,.33,.069,.022,.022)],amber,12,amber_belly)
for s in [-1,1]:
    ico('seahorse eye',(s*.070,.085,.14),(.018,.021,.018),ink,head,2)
    ico('seahorse eye glint',(s*.083,.091,.146),(.004,.005,.004),ivory,head,1)
for y,z in [(.015,.13),(.055,.17),(.10,.175)]:
    cone(head,'small coronet',(0,y,z),(0,y-.013,z+.04),.018,amber_back)
tail=node('Tail',root,(0,-.015,.30))
tube(tail,'coiled prehensile tail',[(0,0,.025,.046,.046),(0,-.045,-.055,.038,.038),
    (0,-.105,-.14,.031,.031),(0,-.10,-.225,.025,.025),
    (0,-.025,-.265,.021,.021),(0,.045,-.23,.017,.017),
    (0,.06,-.16,.014,.014),(0,.015,-.135,.011,.011),
    (0,-.015,-.16,.006,.006)],amber,10,amber_belly)
fins=[]
for side,s in [('L',-1),('R',1)]:
    fin=node('Fin'+side,root,(s*.045,.012,.61));fins.append(fin)
    plate(fin,'tiny fluttering fin',[(0,.015,.01),(s*.075,-.012,.042),
        (s*.105,-.055,.012),(s*.08,-.085,-.035),(0,-.035,-.018)],.008,fin_gold)
export('wild_seahorse',[body,head,tail,*fins])


# Puffer: compact round body, small steering fins, tiny blunt defensive
# spines, and spots painted on its skin instead of floating discs.
clean();root=node('Puffer');body=node('Body',root)
puffer=spotted_puffer(body)
for i in range(27):
    angle=i*2.399963;latitude=.10+.80*((i*.381966)%1)
    direction=Vector((math.cos(angle)*math.sqrt(1-latitude*latitude),
        math.sin(angle)*math.sqrt(1-latitude*latitude),latitude))
    centre=Vector((direction.x*.184,direction.y*.225,direction.z*.19))
    # Spines stop before the round face and stay small at normal game scale.
    if centre.y>.15:continue
    cone(body,'tiny rounded spine',centre-direction*.006,centre+direction*.024,.008,fin_gold)
for s in [-1,1]:
    ico('puffer eye',(s*.108,.174,.072),(.028,.029,.031),ink,body,2)
    ico('puffer eye shine',(s*.119,.190,.084),(.007,.007,.008),ivory,body,1)
ico('small beak mouth',(0,.277,-.022),(.026,.013,.020),puff_spot,body,2)
tail=node('Tail',root,(0,-.22,0))
plate(tail,'short puffer tail',[(0,.025,.034),(0,-.14,.09),(0,-.19,.065),
    (0,-.20,-.06),(0,-.14,-.09),(0,.025,-.034)],.012,puff_gold,axis='X')
fins=[]
for side,s in [('L',-1),('R',1)]:
    fin=node('Fin'+side,root,(s*.16,.055,-.035));fins.append(fin)
    plate(fin,'small steering fan',[(0,.04,0),(s*.065,.03,.01),
        (s*.105,-.035,.005),(s*.075,-.10,-.01),(0,-.045,-.005)],.009,fin_gold)
export('wild_puffer',[body,tail,*fins])


# Squid: mantle behind the eyes, eight short tapered arms and two longer
# feeding tentacles. Each short arm has a nested distal pivot for a soft curl.
clean();root=node('Squid');body=node('Body',root)
loft(body,'continuous mantle and head',[(-.68,.008,.008,0),(-.58,.065,.055,0),
    (-.42,.12,.095,0),(-.22,.14,.113,0),(-.04,.122,.10,0),
    (.06,.102,.085,0),(.16,.108,.087,0),(.225,.07,.065,0)],
    (salmon,salmon_back,salmon_belly),16)
for s in [-1,1]:
    ico('squid eye pearl',(s*.102,.126,.014),(.025,.043,.037),ivory,body,2)
    ico('squid dark pupil',(s*.122,.139,.018),(.011,.026,.025),ink,body,2)
    ico('squid eye glint',(s*.130,.148,.027),(.003,.006,.006),ivory,body,1)
parts=[body]
for side,s in [('L',-1),('R',1)]:
    fin=node('Fin'+side,root,(s*.085,-.34,0));parts.append(fin)
    plate(fin,'triangular mantle fin',[(s*-.055,-.26,0),(s*.085,-.11,.007),
        (s*.16,.025,0),(s*.12,.09,-.004),(s*.02,.19,-.004),
        (s*-.015,.11,0)],.014,salmon_fin,salmon_belly)
for i in range(8):
    a=i*math.tau/8;dx=math.cos(a);dz=math.sin(a)
    arm=node('Arm'+str(i),root,(dx*.064,.19,dz*.052));parts.append(arm)
    tube(arm,'supple short arm',[(0,-.018,0,.024,.024),
        (dx*.028,.075,dz*.025,.020,.019),
        (dx*.052,.16,dz*.044,.016,.015),
        (dx*.066,.215,dz*.049,.012,.012)],salmon,8,salmon_belly)
    tip=node('ArmTip'+str(i),arm,(dx*.056,.18,dz*.045));parts.append(tip)
    tube(tip,'curled arm tip',[(0,-.015,0,.015,.014),
        (dx*.015,.06,dz*.012,.011,.010),
        (dx*.005,.12,dz*.007,.007,.007),
        (-dx*.025,.15,-dz*.015,.003,.003)],salmon,8,salmon_belly)
for side,s in [('L',-1),('R',1)]:
    tentacle=node('Tentacle'+side,root,(s*.075,.19,-.03));parts.append(tentacle)
    tube(tentacle,'long feeding tentacle',[(0,-.02,0,.016,.016),
        (s*.035,.12,-.035,.013,.013),(s*.055,.27,-.025,.011,.011),
        (s*.04,.39,.005,.014,.012),(s*.02,.45,.025,.025,.015),
        (s*-.005,.495,.028,.018,.012),(s*-.02,.515,.02,.004,.005)],salmon,10,salmon_belly)
export('wild_squid',parts)
print('OCEAN_GUESTS_READY: dolphin, seahorse, puffer, squid')
