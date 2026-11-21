# SPDX-License-Identifier: CC-BY-NC-SA-4.0
# See assets/characters/whale-girl-CREDITS.txt.
from geometry import loft, material, mesh, oval, shape, strand, tube
from math import cos, exp, pi, sin, sqrt

def build():
    twill = material("Midnight faille", "#292B51")
    indigo = material("Iris grosgrain", "#404574")
    ivory = material("Vanilla porcelain linen", "#FFF0DC")
    binding = material("Biscuit silk", "#E1BFA2")
    leather = material("Patent blueberry", "#292D55", .12, .23)
    tread = material("Stacked heel", "#292536")
    thread = material("Delft embroidery", "#535E9B")
    def sat(x):
        return min(1,max(0,x))
    def mix(a,b,t):
        return a+(b-a)*t
    def weights(a,b,t):
        t=sat(t)
        t=t*t*(3-2*t)
        return {a:1-t,b:t}
    def body(x,y,z):
        if z<.75:
            return weights("hips","spine",(z-.64)/.09)
        return weights("spine","chest",(z-.75)/.1)
    def panel(name,b,m,fn,n,k,closed=False,flip=False):
        vs=[]
        fs=[]
        N=n if closed else n+1
        for j in range(k+1):
            for i in range(N):
                vs.append(fn(i/n,j/k))
        for j in range(k):
            for i in range(n):
                a=j*N+i
                c=j*N+(i+1)%N
                fs.append((a,a+N,c+N,c) if flip else (a,c,c+N,a+N))
        return mesh(name,b,m,vs,fs)
    def edge(name,b,m,fn,n,r):
        return tube(name,b,m,[fn(i/n) for i in range(n+1)],r,8)
    def shell(name,b,m,rows):
        return loft(name,b,m,[(z,0,y,w,d) for z,y,w,d in rows],64)
    def sample(rows,z):
        for i in range(1,len(rows)):
            if z<=rows[i][0]:
                a,b=rows[i-1],rows[i]
                t=sat((z-a[0])/(b[0]-a[0]))
                return [mix(a[j],b[j],t) for j in range(1,len(a))]
        return rows[-1][1:]
    shell("Neck","neck","skin",[(.895,0,.055,.045),(.936,0,.05,.045),(.989,0,.059,.051)])
    bod=[(.527,.007,.112,.079),(.58,.006,.127,.089),(.654,.004,.11,.08),(.698,.002,.106,.077),(.768,0,.123,.087),(.842,-.002,.147,.097),(.889,0,.158,.088),(.91,.001,.132,.072),(.931,.001,.055,.046)]
    shell("Princess seamed dress",body,twill,bod)
    def chestpoint(x,z,l):
        y,w,d=sample(bod,z)
        return (x,y-d*sqrt(max(.015,1-(x/w)**2))-l,z)
    def bibwidth(t):
        return .052+.035*sin(.59*pi*t)+.008*t
    def bib(s,t):
        q=2*s-1
        z=.680+.238*t-.013*(1-q*q)*t**3
        return chestpoint(q*bibwidth(t),z,.005+.004*(1-q*q)+.0015*cos(4*pi*s))
    panel("Cream pintucked stomacher",body,ivory,bib,32,20)
    for sign in [-1,1]:
        def frill(s,t):
            x,y,z=bib(1 if sign>0 else 0,t)
            wave=.5-.5*cos(2*pi*6*t)
            return chestpoint(x+sign*s*(.011+.016*wave),z+.006*s*sin(12*pi*t),.004+s*(.002+.007*wave))
        panel("Fluted bib side flounce",body,ivory,frill,8,84,flip=sign<0)
        edge("Bib rouleau",body,binding,lambda t:bib(1 if sign>0 else 0,t),32,.0023)
        def streamer(s,t):
            q=2*s-1
            z=.889-.081*t+.009*q*t**5
            return chestpoint(sign*(.005+.031*t+q*(.008+.009*t)),z,.016+.004*sin(pi*t))
        panel("Falling throat ribbon","chest",indigo,streamer,9,18,flip=sign>0)
        oval("Cravat wing","chest",twill,chestpoint(sign*.025,.891,.012),(.026,.009,.014),rot=(0,-sign*.25,0))
    oval("Gilt scallop bezel","chest","gold",chestpoint(0,.884,.025),(.025,.009,.021))
    for j in range(-3,4):
        a=j*.275
        tube("Repousse scallop rib","chest","gold",[(0,-.122,.865),(.013*sin(a),-.13,.876+.005*cos(a)),(.028*sin(a),-.12,.878+.025*cos(a))],[.002,.005,.0035])
    def skirt(a,t,p=0):
        u=1-t
        f=(.5+.5*cos(16*a+.21*t))**.52
        r=.108+.157*u**.85
        d=.080+.113*u**.89
        g=(.003+.020*u)*(f-.52)
        return ((r+g+p)*sin(a),.006-(d+g+p)*cos(a),.386+.29*t+.003*u*f)
    panel("Sixteen pressed fan pleats","hips",twill,lambda s,t:skirt(2*pi*s,t),256,16,True)
    panel("Indigo woven hem","hips",indigo,lambda s,t:skirt(2*pi*s,.018+.018*t,.0012),256,2,True)
    def slip(s,t):
        a=2*pi*s
        petal=sqrt(max(0,.5-.5*cos(24*a)))
        x,y,z=skirt(a,0,-.007-.003*t)
        return (x*(1+.014*(1-t)),y,z+.014*t-(1-t)*(.013+.022*petal))
    panel("Shell petal underskirt","hips",ivory,slip,288,7,True)
    edge("Petticoat picot braid","hips",binding,lambda t:slip(t,0),288,.0018)
    def apron(s,t,offset=0):
        q=2*s-1
        a=q*(.99-.13*t)
        bot=.222+.207*abs(q)**3
        h=bot+(1-bot)*t
        u=1-h
        p=.015+offset+.003*cos(5*pi*q)*u
        return ((.108+.157*u**.85+p)*sin(a),.006-(.080+.113*u**.89+p)*cos(a),.386+.29*h)
    panel("Separate U-front pinafore","hips",ivory,apron,72,20)
    # One continuous gathered border, from waistband to waistband.
    def perimeter(t):
        if t<.24:
            return (0,1-t/.24)
        if t>.76:
            return (1,(t-.76)/.24)
        return ((t-.24)/.52,0)
    def flounce(t,v):
        s,h=perimeter(t)
        x,y,z=apron(s,h)
        s0,h0=perimeter(max(0,t-.001))
        s1,h1=perimeter(min(1,t+.001))
        a,b,c=apron(s0,h0)
        d,e,f=apron(s1,h1)
        dx,dz=d-a,f-c
        length=sqrt(dx*dx+dz*dz)+.0000001
        wave=(.5-.5*cos(16*pi*t))**.62
        w=v*(.014+.029*wave)*(.4+.6*sin(pi*t)**.3)
        return (x+w*dz/length,y-w*(.31+.20*wave)+.001-.003*v*sin(16*pi*t),z-w*dx/length)
    panel("Eight gathered apron shells","hips",ivory,flounce,160,9,flip=True)
    edge("Apron pearl seam","hips",binding,lambda t:flounce(t,0),120,.0028)
    edge("Fine shell edging","hips",binding,lambda t:flounce(t,1),160,.0016)
    shell("Wrapped cummerbund","hips",ivory,[(.656,.005,.128,.102),(.662,.005,.128,.102),(.681,.004,.122,.094),(.693,.003,.116,.087)])
    def motif(x,z,l=.003):
        t=(z-.386)/.29
        d=.08+.113*(1-t)**.89+.015
        w=.108+.157*(1-t)**.85+.015
        return (x,.006-d*sqrt(1-(x/w)**2)-l,z)
    def whale(s,t):
        x=mix(-.033,.058,s)
        mid=.535+.022*s-.009*sin(pi*s)
        rad=.016*sin(pi*s)**.62
        return motif(x,mid+(2*t-1)*rad,.005)
    panel("Satin stitched sounding whale","hips",thread,whale,42,8)
    for p in [[(-.031,.535),(-.047,.543),(-.056,.557)],[(-.031,.535),(-.031,.551),(-.022,.561)],[(.017,.533),(.012,.522),(.001,.515)]]:
        tube("Embroidered whale fin","hips",thread,[motif(x,z,.005) for x,z in p],[.002,.007,.001])
    oval("Whale seed pearl","hips","white",motif(.043,.553,.008),(.0024,.002,.0024))
    for j in range(2):
        edge("Delft wave flourish","hips",thread,lambda t:motif(-.059+.115*t,.509-.008*j+.006*sin(2*pi*t+j),.005),32,.002-j*.0004)
    for sign,side in [(1,"left"),(-1,"right")]:
        U,L,H=side+"UpperArm",side+"LowerArm",side+"Hand"
        A,B,F=side+"UpperLeg",side+"LowerLeg",side+"Foot"
        def arm(x,y,z,U=U,L=L,H=H):
            q=abs(x)
            if q<.20:
                return weights("chest",U,(q-.126)/.061)
            if q<.38:
                return weights(U,L,(q-.285)/.058)
            return weights(L,H,(q-.449)/.022)
        def limb(name,b,m,keys,n=20):
            return strand(side+" "+name,b,m,[(sign*x,y,z,w,d) for x,y,z,w,d in keys],axis=(0,1,0),n=n)
        limb("arm",arm,"skin",[(.131,0,.9,.039,.039),(.179,0,.903,.042,.043),(.315,0,.892,.031,.031),(.351,-.001,.891,.032,.032),(.46,-.003,.885,.019,.016),(.47,-.003,.885,.019,.016)])
        def sleeve(s,t):
            q=2*pi*s
            puff=sin(pi*t)**.68
            r=.042-.011*t+.024*puff+.019*exp(-((t-.72)/.20)**2)+(.003+.005*cos(pi*t)**4)*cos(8*q+.8*t)
            return (sign*(.135+.27*t),r*cos(q),.903-.016*t+r*sin(q)-.008*puff)
        panel(side+" gathered bishop sleeve",arm,twill,sleeve,72,36,True,flip=sign<0)
        limb("gauntlet cuff",L,ivory,[(.396,-.002,.887,.036,.036),(.401,-.002,.887,.038,.037),(.431,-.003,.886,.03,.03),(.45,-.003,.885,.024,.024),(.453,-.003,.885,.024,.024)])
        oval(side+" cuff button",L,"gold",(sign*.424,-.034,.89),(.006,.003,.006))
        # Sculpt a closed ovoid with a dished palmar surface.
        palm=oval(side+" thenar and hypothenar pad",arm,"skin",(sign*.481,-.003,.885),(.031,.026,.015))
        def dish(x,y,z):
            u=(sign*x-.481)/.031
            v=(y+.003)/.026
            return (x,y,z+.005*v*v+.003*u*u-.004*exp(-3*(v*v+u*u))*sat((z-.885)/.009))
        shape(palm,"Palmar vault",dish)
        for i,tip in enumerate([.537,.54,.535,.527]):
            y=-.022+.012*i
            rise=(.011 if sign>0 else .019)-.0015*i
            limb("digit "+str(i+1),H,"skin",[(.495,y*.83,.885,.007,.009),(.509,y,.886,.0067,.0075),(tip-.008,y*1.05,.886+rise*.48,.0059,.0062),(tip-.002,y*1.06,.886+rise,.005,.0047),(tip,y*1.06,.888+rise,.002,.002)])
        limb("opposed thumb",H,"skin",[(.467,-.011,.886,.012,.012),(.477,-.023,.886,.012,.011),(.484,-.034,.891,.009,.009),(.492,-.039,.899,.008,.008),(.499,-.038,.904,.003,.004)])
        def leg(x,y,z,A=A,B=B,F=F):
            if z>.43:
                return weights(A,"hips",(z-.47)/.075)
            if z>.19:
                return weights(B,A,(z-.255)/.06)
            return weights(F,B,(z-.09)/.046)
        def shoeform(name,b,m,rows):
            return loft(side+" "+name,b,m,[(z,sign*.092,y,w,d) for z,y,w,d in rows],48)
        loft(side+" leg",leg,"skin",[(z,sign*x,y,w,d) for z,x,y,w,d in [(.048,.092,.007,.032,.033),(.112,.092,.005,.034,.036),(.17,.092,.009,.041,.043),(.213,.091,.008,.047,.047),(.256,.09,-.001,.044,.044),(.285,.09,-.007,.046,.047),(.319,.09,-.004,.05,.05),(.404,.088,.006,.063,.066),(.50,.088,.009,.064,.069),(.55,.075,.007,.055,.057)]],48)
        shoeform("leather sole",F,tread,[(0,-.028,.048,.08),(.004,-.028,.056,.086),(.016,-.028,.056,.086),(.019,-.027,.054,.084)])
        shoeform("rounded patent vamp",F,leather,[(.017,-.028,.055,.085),(.033,-.029,.056,.085),(.049,-.028,.054,.079),(.061,-.021,.05,.069),(.065,-.012,.046,.06)])
        oval(side+" exposed instep",F,"skin",(sign*.092,-.012,.059),(.043,.058,.031))
        shoeform("button strap",F,leather,[(.096,.005,.038,.04),(.099,.005,.039,.041),(.116,.005,.039,.041),(.119,.005,.037,.04)])
        # Rounded rectangular buckle in a plane tangent to the outer ankle.
        def buckle(s,t):
            a=2*pi*s
            c,d=cos(a),sin(a)
            return (sign*(.132+.002*sin(pi*t)), -.002+(.018-.006*t)*(1 if c>=0 else -1)*abs(c)**.32,.107+(.015-.005*t)*(1 if d>=0 else -1)*abs(d)**.32)
        panel(side+" square brass buckle",F,"gold",buckle,40,5,True,flip=sign<0)
        tube(side+" buckle tongue",F,"gold",[(sign*.135,-.017,.107),(sign*.136,-.002,.107)],.0022)
        def loop(s,t):
            a=2*pi*s
            u=.5-.5*cos(a)
            q=2*t-1
            return (sign*(.009+.125*u),.124+.022*u+.024*sin(a)+.004*q*q,.67+.019*u+q*(.013+.037*u**.66))
        panel(side+" indigo butterfly loop","hips",indigo,loop,64,9,True)
        edge(side+" gilt bow selvedge","hips","gold",lambda t:loop(t,0),64,.0026)
        def ribbon(s,t):
            q=2*s-1
            z=.667-.203*t+.021*(1-abs(q+.16))*t**7
            return (sign*(.013+.08*t+q*(.017+.024*t)),.119+.088*t+.008*sin(pi*t)+.004*q*q,z)
        panel(side+" fishtail ribbon","hips",indigo,ribbon,18,24)
        edge(side+" ribbon end gilt","hips","gold",lambda s:ribbon(s,1),24,.003)
        edge(side+" ribbon outer gilt","hips","gold",lambda t:ribbon(1,t),24,.002)
    oval("Butterfly bow cinch","hips",twill,(0,.126,.672),(.026,.024,.031),rot=(0,.12,0))
