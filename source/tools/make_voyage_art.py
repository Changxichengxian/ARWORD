"""Authored low-poly rocket, working gold mine, mint and island trader. Blender source retained."""
from pathlib import Path
exec(Path(__file__).with_name('make_frontier_art.py').read_text('utf-8').split("clean();r=node('Shipyard')")[0])
teal=mat('deep turquoise','287E8A');ivory=mat('rocket ceramic','F3E9CE');red=mat('coral trim','D77557')
purple=mat('midnight scales','555875');pink=mat('warm underside','B7A3B9');dark=mat('deep opening','182936');coin=mat('minted gold','F0C65F');shine=mat('gold edge','FFE4A0')

clean();r=node('Rocket')
cyl('launch plinth',(0,0,.12),1.15,.24,stone,r,12)
for i in range(12):
    a=i*math.tau/12;box('pad marking',(.94*math.cos(a),.94*math.sin(a),.25),(.12,.08,.018),ivory,r,.006)
cyl('engine throat',(0,0,.50),.40,.50,navy,r,12,.29)
cyl('engine gold rim',(0,0,.30),.43,.11,gold,r,12)
body=node('RocketBody',r)
cyl('ivory fuselage',(0,0,1.51),.57,1.65,ivory,body,16,.48)
cyl('lower teal ring',(0,0,.82),.59,.19,teal,body,16)
cyl('shoulder ring',(0,0,2.26),.50,.12,gold,body,16)
cyl('pointed nose',(0,0,2.70),.49,.80,red,body,16,.02)
for a in [0,2.094,4.188]:
    f=node('Fin',r);f.rotation_euler.z=a
    mesh('swept fin',[(.40,-.06,.62),(.40,-.06,1.42),(1.02,-.06,.36),(.95,-.06,.25),(.40,.06,.62),(.40,.06,1.42),(1.02,.06,.36),(.95,.06,.25)],[(0,1,2,3),(4,7,6,5),(0,4,5,1),(1,5,6,2),(2,6,7,3),(0,3,7,4)],teal,f)
    box('landing foot',(.89*math.cos(a),.89*math.sin(a),.29),(.26,.24,.10),navy,r)
for name,radius,y in [('port brass',.24,-.503),('port glass',.185,-.548)]:
    o=cyl(name,(0,y,1.74),radius,.07,gold if 'brass' in name else blue,body,16);o.rotation_euler.x=math.pi/2
box('port glint',(-.06,-.59,1.81),(.045,.016,.10),ivory,body,.01)
door=node('Hatch',body,(-.17,-.565,1.04));box('hatch',(.17,0,0),(.34,.065,.48),navy,door,.045);box('handle',(.26,-.05,0),(.04,.04,.12),gold,door)
for z in [.35,.48,.61]:beam('ladder step',(-.20,-.87,z),(.20,-.87,z),.045,ivory,r)
for x in [-.23,.23]:beam('ladder rail',(x,-.93,.25),(x,-.59,.89),.045,gold,r)
lamp=node('ReadyLamp',r,(0,.03,3.13));ico('lamp',(0,0,0),(.10,.10,.10),mint,lamp,2)
export('rocket')

clean();r=node('GoldMine')
# An actual open arch; rocks do not fill the entrance volume.
for i,(x,y,z,s) in enumerate([(-.80,.10,.53,.58),(.80,.13,.52,.58),(-.59,.30,1.18,.48),(.57,.28,1.20,.5),(0,.30,1.51,.48),(-.40,.85,.66,.70),(.40,.85,.65,.72)]):
    ico('rock face',(x,y,z),(s,s*.72,s*.9),black if i%2 else stone,r,1)
box('dark tunnel',(0,.94,.63),(.95,.05,1.05),dark,r,.12)
for x in [-.58,.58]:beam('timber support',(x,-.10,.05),(x,-.10,1.20),.14,wood,r)
beam('portal lintel',(-.69,-.10,1.18),(.69,-.10,1.18),.18,light,r)
for x in [-.25,.25]:beam('rail',(x,-1.05,.055),(x,.85,.055),.045,navy,r)
for y in [-.9,-.55,-.2,.15,.5]:box('sleeper',(0,y,.03),(.77,.075,.045),wood,r,.008)
cart=node('MineCart',r,(0,-.66,.20));box('cart',(0,0,.18),(.45,.46,.29),teal,cart)
for x in [-.25,.25]:
    for y in [-.15,.15]:
        o=cyl('wheel',(x,y,0),.09,.055,navy,cart,10);o.rotation_euler.y=math.pi/2
for i in range(5):ico('ore in cart',((i%2-.5)*.18,(i//2-1)*.11,.36),(.14,.12,.13),coin if i%2 else stone,cart)
for x,y,z in [(-.91,-.23,.63),(.80,-.22,.78),(-.31,.03,1.55)]:
    ico('gold vein',(x,y,z),(.13,.055,.19),coin,r)
beam('lantern arm',(.55,-.15,1.18),(.85,-.15,1.18),.045,navy,r)
box('mine lantern',(.85,-.15,1.03),(.15,.15,.22),shine,r)
export('gold_mine')

clean();r=node('GoldMint')
box('hearth base',(-.32,.10,.16),(1.10,1.04,.32),black,r,.09)
for x in [-.72,.10]:box('fire side',(x,.06,.62),(.22,.82,.86),stone,r,.05)
box('back',(-.31,.40,.65),(.76,.18,.90),stone,r)
box('fire hollow',(-.31,.37,.48),(.65,.03,.45),dark,r)
box('coals',(-.31,-.03,.34),(.62,.57,.04),ember,r)
cyl('crucible',(-.31,.06,1.04),.37,.29,navy,r,12,.42)
cyl('molten gold',(-.31,.06,1.195),.34,.022,coin,r,16)
cyl('hood',(-.31,.38,1.49),.39,.38,stone,r,8,.22)
cyl('chimney',(-.31,.38,1.95),.18,.57,cream,r,8)
box('casting bench',(.55,-.12,.47),(.65,.87,.12),light,r)
for x in [.31,.80]:beam('bench leg',(x,-.10,.02),(x,-.10,.44),.09,wood,r)
for y in [-.35,-.05,.25]:box('casting mold',(.55,y,.57),(.42,.21,.06),navy,r,.02);cyl('fresh coin',(.55,y,.615),.077,.02,coin,r,12)
wheel=node('MintWheel',r,(-.82,.04,.65))
o=cyl('flywheel',(0,0,0),.31,.05,wood,wheel,16);o.rotation_euler.y=math.pi/2
for i in range(6):a=i*math.tau/6;beam('wheel spoke',(0,0,0),(0,.3*math.cos(a),.3*math.sin(a)),.04,gold,wheel)
export('gold_mint')

def tentacle(name,parent,a):
    branch=node(name,parent);vertices=[];faces=[]
    count=14;edges=7
    def path(t):
        rad=.42+1.32*t;angle=a+.55*math.sin(t*math.pi)
        return Vector((math.cos(angle)*rad,math.sin(angle)*rad,.35-.19*math.sin(t*math.pi)+.42*t**5))
    for j in range(count):
        t=j/(count-1);center=path(t)
        tangent=(path(min(1,t+.01))-path(max(0,t-.01))).normalized()
        side=Vector((-tangent.y,tangent.x,0)).normalized();up=tangent.cross(side).normalized()
        radius=.23*(1-t)+.035
        for k in range(edges):
            q=k*math.tau/edges;vertices.append(tuple(center+radius*(side*math.cos(q)+up*math.sin(q))))
        if j:
            for k in range(edges):u=(j-1)*edges+k;v=(j-1)*edges+(k+1)%edges;faces.append((u,v,v+edges,u+edges))
    faces.extend([tuple(reversed(range(edges))),tuple((count-1)*edges+k for k in range(edges))]);mesh('curled limb',vertices,faces,purple,branch)
    return branch
clean();r=node('SeaTrader')
for i in range(6):tentacle('Arm'+str(i),r,i*math.tau/6)
head=node('Head',r,(0,0,.60));ico('mantle',(0,0,.59),(.82,.68,.94),purple,head,2)
ico('soft face',(0,-.44,.40),(.62,.26,.52),pink,head,2)
for x in [-.29,.29]:
    ico('eye white',(x,-.68,.55),(.17,.075,.14),ivory,head,2)
    ico('pupil',(x,-.747,.54),(.066,.026,.092),dark,head,2)
    ico('eye shine',(x-.018,-.768,.58),(.021,.009,.025),ivory,head,1)
    beam('brow',(x-.15,-.72,.72),(x+.13,-.72,.74),.075,purple,head)
ico('small mouth',(0,-.72,.23),(.115,.035,.055),dark,head,1)
for sign in [-1,1]:mesh('head fin',[(sign*.53,0,1.08),(sign*1.03,.08,1.48),(sign*.83,-.10,.70)],[(0,1,2),(2,1,0)],teal,head)
box('trading tray',(0,-1.28,.18),(.9,.42,.13),wood,r,.04)
coins=node('CoinPile',r,(0,-1.24,.25))
for i in range(8):cyl('saved coin',((i%3-1)*.17,(i//3%2-.5)*.12,(i//6)*.06),.10,.055,coin,coins,12)
export('sea_trader')

clean();r=node('GoldOre');ico('ore',(0,0,.18),(.25,.20,.22),stone,r)
for i in range(5):a=i*math.tau/5;ico('gold seam',(.18*math.cos(a),.15*math.sin(a),.22+.03*i),(.085,.065,.10),coin,r)
export('gold_ore')
clean();r=node('GoldCoin')
for i in range(4):cyl('coin',((i%2-.5)*.13,(i//2-.5)*.10,.035+i*.035),.14,.035,coin,r,14)
cyl('stamp',(.065,.05,.164),.075,.012,shine,r,6)
export('gold_coin')
