"""Original articulated coastal animals. All dimensions are in Blender units; +Y is the snout."""
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
from wildlife_mesh import clean, export, ico, material, mesh, node

tau = math.tau
ink = material('Midnight blue', '182733')
milk = material('Porcelain', 'F8F2DC')
slate = material('Silver saddle', '919DA5')
pewter = material('Seal coat', '87999C')
cream = material('Sandstone muzzle', 'D5C8B0')
rust = material('Persimmon shell', 'D65C3D')
apricot = material('Amber claw', 'FAAD56')
pink = material('Bell rim', 'CE9CDC')
ice = material('Moon blue', 'A3E7DF')


def loft(name, rings, parent, palette, sides=24):
    """Elliptical stations with a contiguous painted underside."""
    verts, faces, slots = [], [], []
    for y, width, height, center in rings:
        for j in range(sides):
            a = tau*j/sides
            verts.append((width*math.cos(a), y, center+height*math.sin(a)))
    for i in range(len(rings)-1):
        for j in range(sides):
            k = (j+1)%sides
            faces.append((i*sides+j, (i+1)*sides+j, (i+1)*sides+k, i*sides+k))
            slots.append(int(len(palette)>1 and math.sin(tau*(j+.5)/sides)<-.54))
    faces.extend([tuple(range(sides)), tuple(reversed(range(len(verts)-sides,len(verts))))])
    obj = mesh(name,verts,faces,palette[0],parent)
    for mat in palette[1:]:obj.data.materials.append(mat)
    for poly,slot in zip(obj.data.polygons,slots):poly.material_index=slot
    return obj


def blade(name, outline, thickness, mat, parent):
    mid = sum((Vector(v) for v in outline), Vector())/len(outline)
    offset = Vector(thickness)
    verts = list(outline)+[tuple(mid+offset),tuple(mid-offset)]
    count = len(outline)
    faces = []
    for j in range(count):
        k=(j+1)%count
        faces.extend([(j,k,count),(k,j,count+1)])
    return mesh(name,verts,faces,mat,parent)


def rod(name,a,b,width,mat,parent):
    av,bv=Vector(a),Vector(b)
    obj=ico(name,(av+bv)/2,(width,width,(bv-av).length*.57),mat,parent,1)
    obj.rotation_euler=(bv-av).to_track_quat('Z','Y').to_euler()


def orca():
    clean()
    root=node('Orca');body=node('Body',root)
    rings=[(-1.31,.13,.14,-.025),(-1.02,.22,.23,-.01),(-.67,.34,.34,.02),
           (-.24,.43,.43,.04),(.20,.46,.46,.06),(.55,.43,.425,.055),
           (.80,.39,.37,.035),(1.02,.32,.29,.015),(1.22,.22,.21,-.03),
           (1.33,.09,.105,-.055),(1.35,.012,.03,-.055)]
    loft('Pigmented hull',rings,body,[ink,milk],32)
    # Fit the edge of each marking to the actual curved flank.
    def flank(y,angle,side):
        i=next(k for k in range(len(rings)-1) if rings[k][0]<=y<=rings[k+1][0])
        a,b=rings[i],rings[i+1];u=(y-a[0])/(b[0]-a[0])
        width,height,cz=[a[k]+u*(b[k]-a[k]) for k in (1,2,3)]
        return (side*1.013*width*math.cos(angle),y,cz+1.013*height*math.sin(angle))
    fins=[]
    for side,label in [(-1,'L'),(1,'R')]:
        for name,y0,angle0,dy,da,slant,mat in [('Eye patch',.56,.28,.26,.245,-.19,milk),('Saddle',-.58,.92,.20,.50,-.32,slate)]:
            verts=[flank(y0,angle0,side)]
            faces=[(0,1+j,1+(j+1)%24) for j in range(24)]
            for band in range(1,7):
                for j in range(24):
                    sn=band/6*math.sin(j*tau/24);cs=band/6*math.cos(j*tau/24)
                    verts.append(flank(y0+dy*cs,angle0+da*sn+slant*cs,side))
                    if band>1:
                        k=1+(band-2)*24
                        faces.append((k+j,k+24+j,k+24+(j+1)%24,k+(j+1)%24))
            mesh(name,verts,faces,mat,body)
        ico('Eye',flank(.86,.0,side),(.025,.039,.035),ink,body,2)
        fin=node('Flipper'+label,root,(side*.35,.38,-.19));fins.append(fin)
        blade('Rounded paddle',[(0,.16,0),(side*.18,.13,-.035),(side*.45,-.02,-.11),
              (side*.55,-.26,-.14),(side*.46,-.39,-.145),(side*.27,-.40,-.10),(0,-.16,0)],(0,0,.05),ink,fin)
    blade('Tall swept dorsal',[(0,-.61,.30),(0,-.44,.56),(0,-.45,1.03),(0,-.40,1.14),
          (0,-.26,.95),(0,-.08,.62),(0,.16,.46)],(.068,0,0),ink,body)
    tail=node('Tail',root,(0,-1.24,-.025))
    loft('Peduncle',[(-.46,.065,.067,0),(-.21,.103,.092,0),(.02,.136,.145,0)],tail,[ink,milk],16)
    fluke=node('Fluke',tail,(0,-.42,0))
    blade('Notched flukes',[(0,.075,0),(-.26,.09,.01),(-.55,-.02,0),(-.67,-.22,-.035),
          (-.49,-.25,-.025),(-.17,-.23,0),(0,-.14,0),(.17,-.23,0),(.49,-.25,-.025),
          (.67,-.22,-.035),(.55,-.02,0),(.26,.09,.01)],(0,0,.032),ink,fluke)
    node('Blowhole',root,(0,.69,.43))
    export('wild_orca',[body,tail,fluke,*fins])


def seal():
    clean();root=node('HarborSeal');body=node('Body',root)
    torso=loft('Resting spindle',[(-.76,.08,.08,.11),(-.55,.18,.15,.16),(-.30,.29,.23,.23),
            (.02,.33,.29,.29),(.22,.28,.245,.285),(.33,.20,.19,.30)],body,[pewter,cream])
    # Mottling is painted into the coat instead of separate floating bumps.
    torso.data.materials.append(slate)
    for face in torso.data.polygons:
        if face.center.z>.34 and int((face.center.y+.9)*37+abs(face.center.x)*61)%7==0:face.material_index=2
    chest=node('Chest',body,(0,.16,.22))
    loft('Flexible shoulder',[(-.11,.27,.21,.055),(.035,.27,.23,.075),(.17,.205,.18,.12),(.27,.14,.13,.14)],chest,[pewter,cream])
    head=node('Head',chest,(0,.20,.12))
    ico('Round head',(0,.12,.12),(.23,.23,.21),pewter,head,3)
    for s in [-1,1]:
        ico('Whisker pad',(s*.078,.294,.075),(.115,.085,.085),cream,head,2)
        ico('Dark eye',(s*.155,.246,.177),(.041,.036,.044),ink,head,2)
        ico('Catch light',(s*.165,.269,.196),(.012,.012,.014),milk,head,1)
        for j in range(3):
            rod('Whisker',(s*.115,.341,.06+j*.023),(s*(.24+j*.014),.36-j*.02,.038+j*.027),.008,cream,head)
    ico('Button nose',(0,.352,.115),(.075,.042,.037),ink,head,2)
    fins=[]
    for s,label in [(-1,'L'),(1,'R')]:
        fin=node('Flipper'+label,chest,(s*.23,.05,-.09));fins.append(fin)
        blade('Fore flipper',[(0,.07,0),(s*.15,.08,-.04),(s*.28,-.04,-.09),
              (s*.27,-.18,-.106),(s*.19,-.20,-.09),(0,-.09,0)],(0,0,.027),pewter,fin)
        hind=node('Hind'+label,body,(s*.075,-.67,.075));fins.append(hind)
        blade('Webbed hind flipper',[(0,.06,0),(s*.08,.015,.005),(s*.13,-.20,-.012),
              (s*.09,-.29,-.01),(s*.035,-.26,0),(-s*.025,-.23,0),(-s*.045,-.06,0)],(0,0,.035),pewter,hind)
    export('wild_seal',[body,chest,head,*fins])


def crab():
    clean();root=node('FiddlerCrab');body=node('Body',root)
    ico('Broad carapace',(0,0,.16),(.29,.21,.145),rust,body,2)
    ico('Shell crown',(0,.012,.231),(.232,.156,.082),apricot,body,2)
    parts=[body]
    for s,label in [(-1,'L'),(1,'R')]:
        for j in range(4):
            # Four walking legs per side, with the hip under the carapace.
            # Each joined angular leg pivots as a unit while scuttling.
            y=-.145+j*.088
            leg=node('Leg'+label+str(j),root,(s*.19,y,.15));parts.append(leg)
            x=s*(.15+.032*(j%2));splay=(j-1.5)*.055
            rod('Leg thigh',(0,0,0),(x,splay,-.035),.029,rust,leg)
            knee=node('Knee',leg,(x,splay,-.035));parts.append(knee)
            rod('Leg tip',(0,0,0),(s*.09,splay*.6,-.102),.018,apricot,knee)
            node('Toe',knee,(s*.09,splay*.6,-.102))
        rod('Eyestalk',(s*.13,.12,.23),(s*.145,.165,.30),.029,rust,body)
        ico('Eye',(s*.145,.17,.314),(.035,.034,.041),ink,body,2)
        claw=node('Claw'+label,root,(s*.22,.080,.146));parts.append(claw)
        scale=1 if s<0 else .64
        rod('Elbow',(0,0,0),(s*.135,.13,.065),.047,rust,claw)
        palm=ico('Palm',(s*.14,.15,.09),(.105*scale,.127*scale,.10*scale),apricot,claw,2)
        for j in [-1,1]:
            if j<0:
                finger=node('Pincer'+label,claw,(s*.14+j*.063*scale,.17,.095));parts.append(finger)
                rod('Movable ivory pincer',(0,0,0),(-j*.033*scale,.16*scale,.05),.031*scale,milk,finger)
            else:rod('Fixed ivory pincer',(s*.14+j*.063*scale,.17,.095),(s*.14+j*.030*scale,.17+.16*scale,.145),.031*scale,milk,claw)
    export('wild_crab',parts)


def jelly():
    clean();root=node('MoonJelly');body=node('Body',root)
    ico('Opaline bell',(0,0,.065),(.25,.23,.14),ice,body,2)
    ico('Scalloped cuff',(0,0,.015),(.24,.22,.065),pink,body,2)
    fringe=node('Fringe',root)
    for j in range(8):
        a=tau*j/8;x=.135*math.cos(a);y=.13*math.sin(a);end=-.22-.09*(j%3)
        rod('Ruffled arm',(x,y,0),(x*1.1,y*.85,end*.55),.028,pink,fringe)
        rod('Trailing tip',(x*1.1,y*.85,end*.55),(x*.68,y*1.05,end),.019,ice,fringe)
    export('wild_jelly',[body,fringe])


def ledge():
    clean();root=node('IntertidalLedge');body=node('Shelf',root)
    cliff=material('Wet volcanic rock','475F6B');band=material('Dry rock','A4A08C')
    rim=[(-1.37,-.22),(-1.1,-.61),(-.42,-.76),(.38,-.70),(1.04,-.49),
         (1.31,-.14),(1.24,.34),(.79,.61),(.12,.75),(-.75,.68),(-1.23,.40)]
    verts=[];count=len(rim)
    for scale,z in [(.78,-5.5),(1.07,-.25),(1.,-.066),(.94,0.)]:
        verts.extend([(x*scale,y*scale,z+(0 if z==0 else .052*math.sin(i*2.11))) for i,(x,y) in enumerate(rim)])
    obj=mesh('Tidal bands',verts,[(i*count+j,i*count+(j+1)%count,(i+1)*count+(j+1)%count,(i+1)*count+j) for i in range(3) for j in range(count)]+[tuple(range(3*count,4*count))],cliff,body)
    obj.data.materials.append(band)
    for p in list(obj.data.polygons)[2*count:]:p.material_index=1
    for x,y in [(-1.04,-.22),(-.99,-.26),(-1.03,-.29),(.72,.44),(.79,.42),(.75,.49)]:
        ico('Barnacle',(x,y,0),(.043,.04,.031),milk,body)
    moss=material('Ochre seaweed','9C9962')
    for x,y,z in [(-1.12,-.06,-.02),(.86,-.42,-.04),(.53,.62,-.06),(.32,.65,-.08)]:
        ico('Split weathered rim',(x,y,z),(.15,.11,.08),cliff,body,1)
        ico('Seaweed on stone',(x-.021,y,.044+z),(.085,.082,.044),moss,body,1)
    export('tidal_ledge',[body])


orca();seal();crab();jelly();ledge()
