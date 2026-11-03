"""Original low-poly coastal wildlife; Blender 4.4 background source generator."""
import bpy, math, sys
from pathlib import Path
from mathutils import Vector
sys.path.insert(0,str(Path(__file__).resolve().parent))
from wildlife_mesh import clean, material, node, ico, mesh, export, ONLY
cream=material('warm ivory','FFF5D7');blue=material('sea blue','4B9FB4');dark=material('ink','244E68');gold=material('sunset gold','EEAF50');coral=material('coral','F29777');mint=material('mint','86D7C0');purple=material('lavender','A797DE')
clean();root=node('Bird');body=node('Body',root)
ico('breast',(0,0,0),(.13,.29,.13),cream,body,2)
ico('head',(0,.25,.075),(.105,.13,.105),cream,body,2)
ico('cap',(0,.24,.11),(.11,.12,.07),blue,body)
mesh('beak',[(-.055,.31,.045),(.055,.31,.045),(0,.46,.025),(0,.32,.105)],[(0,2,1),(0,3,2),(1,2,3),(0,1,3)],gold,body)
for x in [-.081,.081]:ico('eye',(x,.302,.085),(.018,.022,.018),dark,body,1)
mesh('tail',[(-.095,-.23,.01),(.095,-.23,.01),(.13,-.43,.025),(0,-.37,.035),(-.13,-.43,.025)],[(0,1,2,3,4),(4,3,2,1,0)],blue,body)
wings=[]
for side,sign in [('L',-1),('R',1)]:
    wing=node('Wing'+side,root,(sign*.09,0,.045));wings.append(wing)
    mesh('wide wing',[(0,.15,0),(sign*.40,.05,.02),(sign*.70,-.27,-.01),(sign*.30,-.20,0),(0,-.15,0)],[(0,1,2,3,4),(4,3,2,1,0)],cream,wing)
    mesh('ink feather',[(sign*.40,.05,.022),(sign*.70,-.27,-.009),(sign*.43,-.23,.008)],[(0,1,2),(2,1,0)],blue,wing)
export('wild_bird',[body,*wings])

clean();root=node('Fish');body=node('Body',root)
ico('body',(0,0,0),(.13,.31,.16),coral,body,2)
ico('belly',(0,.035,-.04),(.117,.24,.103),cream,body,1)
for x in [-.101,.101]:ico('eye',(x,.19,.055),(.022,.027,.025),dark,body)
mesh('dorsal',[(0,-.15,.11),(0,-.05,.30),(0,.16,.12)],[(0,1,2),(2,1,0)],gold,body)
for sign in [-1,1]:mesh('side fin',[(sign*.09,.06,0),(sign*.27,-.06,-.025),(sign*.10,-.12,-.04)],[(0,1,2),(2,1,0)],gold,body)
tail=node('Tail',root,(0,-.25,0))
mesh('tail fan',[(0,0,.05),(-.18,-.21,.16),(-.13,-.19,-.13),(0,-.10,-.04),(.13,-.19,-.13),(.18,-.21,.16)],[(0,1,2,3),(0,3,4,5),(3,2,1,0),(5,4,3,0)],gold,tail)
export('wild_fish',[body,tail])

clean();root=node('Butterfly');body=node('Body',root)
ico('body',(0,0,0),(.026,.13,.028),dark,body,1)
ico('head',(0,.12,0),(.035,.038,.035),dark,body,1)
for sign in [-1,1]:
    mesh('antenna',[(sign*.012,.13,.01),(sign*.05,.21,.03),(sign*.055,.20,.03)],[(0,1,2),(2,1,0)],dark,body)
wings=[]
for side,sign in [('L',-1),('R',1)]:
    wing=node('Wing'+side,root,(sign*.014,0,0));wings.append(wing)
    mesh('fore wing',[(0,.06,0),(sign*.18,.24,.02),(sign*.32,.17,.015),(sign*.28,-.015,.005),(0,-.06,0)],[(0,1,2,3,4),(4,3,2,1,0)],purple,wing)
    mesh('hind wing',[(0,-.02,0),(sign*.26,-.05,.01),(sign*.19,-.24,.015),(sign*.045,-.18,0)],[(0,1,2,3),(3,2,1,0)],mint,wing)
    mesh('gold patch',[(sign*.09,.08,.003),(sign*.18,.18,.024),(sign*.24,.13,.019),(sign*.18,.045,.013)],[(0,1,2,3),(3,2,1,0)],gold,wing)
export('wild_butterfly',[body,*wings])

# Keep the current blue-whale generator as the single source of truth.
if not ONLY or 'wild_whale' in ONLY:
    import runpy
    runpy.run_path(str(Path(__file__).with_name('make_blue_whale.py')),run_name='__main__')
print('WILDLIFE_ASSETS_READY: wild_bird, wild_fish, wild_butterfly, wild_whale')
