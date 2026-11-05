"""Original low-poly meadow rabbit, with separate ears and articulated paws."""
import bpy, sys, math
from pathlib import Path
from mathutils import Vector
sys.path.insert(0,str(Path(__file__).resolve().parent))
from wildlife_mesh import clean, material, node, ico, mesh, export

fur=material('warm oat fur','CBB493')
light=material('ivory cheeks and belly','EEE5D3')
inner=material('muted pink inner ear','CC9E95')
dark=material('deep brown eyes','323035')
nose=material('small rose nose','A57B76')
white=material('eye glint','FFF8E7')

def lobe(name, outline, thickness, mat, parent):
    n=len(outline);v=[tuple(p) for p in outline]
    v += [(p[0],p[1]-thickness,p[2]) for p in outline]
    faces=[tuple(range(n)),tuple(reversed(range(n,2*n)))]
    faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    return mesh(name,v,faces,mat,parent)

clean();root=node('Rabbit');body=node('Body',root,(0,-.035,.28))
ico('pear shaped torso',(0,0,0),(.165,.25,.195),fur,body,2)
# Belly is coloured on the same torso, with no intersecting surface layer.
torso=next(o for o in body.children if o.type=='MESH')
torso.data.materials.append(light)
for face in torso.data.polygons:
    if face.center.z<-.45:face.material_index=1
head=node('Head',body,(0,.225,.145))
ico('round head',(0,.02,0),(.139,.145,.135),fur,head,2)
ico('left soft cheek',(-.044,.118,-.039),(.065,.074,.056),light,head,2)
ico('right soft cheek',(.044,.118,-.039),(.065,.074,.056),light,head,2)
ico('nose',(0,.183,-.021),(.022,.013,.016),nose,head,1)
for s in [-1,1]:
    ico('bright dark eye',(s*.110,.077,.031),(.021,.024,.025),dark,head,2)
    ico('eye glint',(s*.122,.087,.041),(.006,.006,.007),white,head,1)
ears=[]
for side,s in [('L',-1),('R',1)]:
    ear=node('Ear'+side,head,(s*.064,-.012,.091));ears.append(ear)
    # Broad base, long soft taper; all tips have thickness and rounded facets.
    lobe('long tapered ear',[(s*-.034,.014,0),(s*-.041,.018,.17),
                            (s*-.009,.014,.345),(s*.023,.012,.385),
                            (s*.049,.012,.34),(s*.066,.014,.17),(s*.036,.012,0)],.025,fur,ear)
    lobe('pink ear interior',[(s*-.013,.020,.055),(s*-.019,.023,.17),
                             (s*.012,.020,.322),(s*.024,.019,.343),
                             (s*.037,.020,.31),(s*.042,.021,.17),(s*.018,.020,.055)],.004,inner,ear)
limbs=[]
for side,s in [('L',-1),('R',1)]:
    fore=node('Fore'+side,root,(s*.105,.125,.265));limbs.append(fore)
    ico('foreleg',(0,0,-.105),(.050,.058,.13),fur,fore,2)
    paw=node('ForePaw'+side,fore,(0,.025,-.208));limbs.append(paw)
    ico('front paw',(0,.035,-.015),(.057,.10,.04),light,paw,2)
    hind=node('Hind'+side,root,(s*.135,-.19,.24));limbs.append(hind)
    ico('round haunch',(s*.022,.015,-.025),(.105,.135,.145),fur,hind,2)
    foot=node('HindPaw'+side,hind,(s*.012,.045,-.185));limbs.append(foot)
    ico('long hind foot',(0,.045,-.014),(.073,.14,.04),light,foot,2)
tail=node('Tail',body,(0,-.247,-.014))
ico('small cotton tail',(0,-.026,.015),(.072,.073,.074),light,tail,2)
export('wild_rabbit',[body,head,*ears,*limbs,tail])
print('RABBIT_READY: body, head, ears, four limbs, four paws, tail')
