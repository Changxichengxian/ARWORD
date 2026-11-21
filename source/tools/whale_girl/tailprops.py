# SPDX-License-Identifier: CC-BY-NC-SA-4.0
# See assets/characters/whale-girl-CREDITS.txt.
from geometry import material, mesh, oval, strand, tint, tube
from math import cos, exp, pi, sin, sqrt
from mathutils import Vector

def tucked_crown(x,y,z):
    # The buried heel of the curl is a hinge, not a translating island.
    h = max(0.,z-1.632)
    t = min(1.,h/.024)
    t = t*t*(3.-2.*t)
    return (x*(1.-.49*t), y+.32*h*t, z-t*(h-.014*(1.-exp(-h/.034))))


def build():
    ocean = material("Transfer cobalt","#475D9F",0,.34)
    steel = material("Spun stainless","#CBD1DF",.87,.25)
    mirror = material("Polished stainless","#E8EAF0",.90,.15)
    china = material("Whaleware ivory","#FFF8EA",.02,.23)
    grain = material("Pearl rice","#FFFCF1",0,.42)
    bed = material("Warm rice shadow","#F4E8D1",0,.53)

    def clamp(v):
        return max(0.,min(1.,v))
    def mix(a,b,t):
        return tuple(u+(v-u)*t for u,v in zip(a,b))
    def smooth(t):
        t=clamp(t)
        return t*t*(3-2*t)
    def spline(keys,t):
        i=min(int(t),len(keys)-2)
        f=t-i
        return tuple(.5*(2*b+(c-a)*f+(2*a-5*b+4*c-d)*f*f+
                         (3*b-a-3*c+d)*f*f*f)
                     for a,b,c,d in zip(keys[max(0,i-1)],keys[i],keys[i+1],
                                         keys[min(len(keys)-1,i+2)]))
    def wheel(name,bone,mat,profile,place,n=64):
        vs=[]; rows=[]; fs=[]
        for r,z in profile:
            row=[]
            for k in range(n if r else 1):
                row.append(len(vs))
                vs.append(place(r*cos(2*pi*k/n),r*sin(2*pi*k/n),z))
            rows.append(row)
        for a,b in zip(rows,rows[1:]):
            for i in range(n):
                j=(i+1)%n
                if len(a)==1: fs.append((a[0],b[j],b[i]))
                elif len(b)==1: fs.append((a[i],a[j],b[0]))
                else: fs.append((a[i],a[j],b[j],b[i]))
        return mesh(name,bone,mat,vs,fs)
    def bead(name,bone,mat,place,r,z,w,h):
        return wheel(name,bone,mat,[(r+w*cos(i*pi/6),z+h*sin(i*pi/6))
                                     for i in range(13)],place)
    def line(name,bone,mat,pts,r):
        return tube(name,bone,mat,pts,r,n=8)
    # Ink transfer projected onto each curved substrate, not a hovering badge.
    def whale(name,bone,place):
        outline=[(-.61,.06),(-.48,.22),(-.20,.29),(.03,.27),(.24,.16),
                 (.43,-.01),(.59,.05),(.65,.28),(.80,.39),(.81,.19),
                 (.74,.02),(.91,.01),(.99,-.10),(.78,-.14),(.57,-.11),
                 (.35,-.17),(.12,-.34),(-.21,-.38),(-.47,-.29),(-.62,-.12)]
        # Body and flukes have separate convex fans to preserve the notch.
        for tag,poly,center in [(" sounding whale",outline[:7]+outline[14:],(-.04,-.04)),
                (" lifted fluke",outline[6:12]+[outline[14]],(.71,.08)),
                (" trailing fluke",outline[10:15],(.79,-.065))]:
            vs=[place(*center)]+[place(*p) for p in poly]
            mesh(name+tag,bone,ocean,vs,[(0,i+1,(i+1)%len(poly)+1)
                 for i in range(len(poly))])
        for k in range(2):
            pts=[(-.38,.26),(-.4+.09*k,.43),(-.53+.24*k,.53),
                 (-.62+.39*k,.49)]
            line(name+" fountain",bone,ocean,[place(x,y) for x,y in pts],
                 [.0008,.0011,.001,.0005])
        for k in range(2):
            line(name+" wavelet",bone,ocean,[place(-.84+.07*j+.76*k,
                 -.47+.06*sin(j*pi/4)) for j in range(9)],.001)
    def tailrig(x,y,z):
        t=smooth((x+.34*y-.09)/.29)
        f=smooth((x-.425)/.082)
        return {"TailRoot":1-t,"TailMid":t*(1-f),"TailFin":t*f}
    def stockcolor(x,y,z):
        # Pale underside follows the centreline through the ascending bend.
        base=spline(stock,min(len(stock)-1,nearest_stock(x,y,z)))[2]
        c=mix((.228,.295,.652),(.324,.553,.935),smooth((x-.16)/.34))
        return mix(c,(.803,.886,.98),smooth((base-z-.005)/.018))
    stock=[(0,.099,.551,.077,.078),(.025,.194,.460,.078,.071),
           (.113,.253,.352,.073,.058),(.226,.259,.299,.066,.052),
           (.338,.254,.302,.055,.046),(.434,.249,.35,.043,.038),
           (.496,.242,.407,.030,.031),(.527,.239,.449,.021,.021)]
    samples=[spline(stock,i/6) for i in range(43)]
    def nearest_stock(x,y,z):
        return min(range(43),key=lambda i:(samples[i][0]-x)**2+
                   (samples[i][1]-y)**2+(samples[i][2]-z)**2)/6
    tint(strand("Tail_Sweeping stock",tailrig,"white",stock,axis=(0,1,0),n=24),stockcolor)
    for side,keys in [("inshore",[(.497,.242,.403,.022,.019),
            (.515,.239,.444,.038,.025),(.508,.247,.492,.052,.029),
            (.493,.266,.544,.044,.022),(.499,.284,.593,.024,.013),
            (.518,.297,.626,.001,.001)]),("offshore",[(.503,.24,.413,.022,.02),
            (.546,.235,.449,.046,.028),(.595,.233,.483,.058,.03),
            (.637,.236,.534,.047,.025),(.663,.244,.590,.024,.013),
            (.676,.251,.639,.001,.001)])]:
        o=strand("TailFin_"+side,"TailFin","white",keys,axis=(1,0,-.57),n=24)
        def flukecolor(x,y,z):
            t=smooth((z-.48)/.15)
            c=mix((.296,.514,.91),(.162,.207,.52),t)
            return mix(c,(.72,.85,.98),.71*smooth((y-.252)/.034)*(1-.66*t))
        tint(o,flukecolor)

    B="BasinMount"
    def pan(x,y,z):
        return x,.016+y,1.489+z
    wheel("Basin_Deep drawn stainless wash pan",B,steel,
          [(0,.155),(.196,.155),(.207,.154),(.216,.151),(.225,.145),
           (.239,.131),(.264,.101),(.294,.062),(.32,.028),(.333,.013),
           (.339,.008),(.346,.006),(.347,.002),(.34,.001),(.334,.004),
           (.328,.009),(.316,.023),(.29,.057),(.259,.096),(.235,.126),
           (.222,.140),(.213,.147),(.204,.150),(0,.150)][::-1],pan,96)
    bead("Basin_Rolled tubular lip",B,mirror,pan,.346,.005,.006,.005)
    bead("Basin_Standing foot ring",B,mirror,pan,.207,.155,.006,.004)
    bead("Basin_Draw line",B,steel,pan,.327,.018,.0015,.0014)

    B="BowlMount"
    def bowl(x,y,z):
        return .494+x,-.006+y,.898+z
    wheel("Bowl_Footed porcelain",B,china,[(0,.001),(.018,.001),(.021,0),
        (.027,0),(.028,.005),(.038,.009),(.052,.017),(.064,.028),
        (.074,.042),(.081,.058),(.083,.067),(.082,.069),(.079,.069),
        (.078,.06),(.071,.044),(.06,.031),(.048,.022),(.033,.015),(0,.013)],bowl)
    bead("Bowl_Cobalt rim",B,ocean,bowl,.082,.066,.0015,.0014)
    bead("Bowl_Foot pinstripe",B,ocean,bowl,.027,.004,.0011,.0009)
    for k in range(3):
        def transfer(x,h):
            z=.042+h*.031
            wall=[(.017,.052),(.028,.064),(.042,.074),(.058,.081),(.067,.083)]
            r=.08
            for (a,ra),(b,rb) in zip(wall,wall[1:]):
                if a<=z<=b: r=ra+(rb-ra)*(z-a)/(b-a)
            ang=k*2*pi/3+x*.74
            return bowl((r+.0007)*sin(ang),-(r+.0007)*cos(ang),z)
        whale("Bowl transfer %d"%k,B,transfer)
    def ricepile(prefix,bone,place,rx,ry,h,d,count,size):
        oval(prefix+" steamed mound",bone,bed,place(0,0,h),(rx,ry,d))
        vs=[]; fs=[]
        for i in range(count):
            a=i*2.399963; r=.981*sqrt((i+.4)/count)
            root=sqrt(1-r*r)
            p=Vector((rx*r*cos(a),ry*r*sin(a),h+d*root))
            yaw=a+1.2*sin(13.9*i)
            c,s=cos(yaw),sin(yaw)
            u=Vector((c,s,-d*r*(c*cos(a)/rx+s*sin(a)/ry)/root)).normalized()
            v=Vector((-s,c,0)); w=u.cross(v)
            start=len(vs); length=size*(1+.12*cos(i*3))
            for station,rad in [(-1,.08),(-.69,.79),(0,1),(.69,.79),(1,.08)]:
                for j in range(8):
                    b=j*pi/4
                    q=p+length*(u*station+rad*(.60*cos(b)*v+.50*sin(b)*w))
                    vs.append(place(*tuple(q)))
            for l in range(4):
                for j in range(8):
                    a0=start+l*8+j; b0=start+l*8+(j+1)%8
                    fs.append((a0,b0,b0+8,a0+8))
            fs.extend([tuple(start+j for j in reversed(range(8))),
                       tuple(start+32+j for j in range(8))])
        mesh(prefix+" short pearl grains",bone,grain,vs,fs)
    ricepile("Bowl",B,bowl,.079,.078,.066,.024,185,.0066)
    S="SpoonMount"
    # WRIST -> scoop centre (REST metres) = (-.158, -.051, +.035)
    strand("Spoon_Fiddle handle",S,mirror,[(-.485,.005,.885,.003,.002),
        (-.494,.002,.886,.009,.003),(-.508,-.006,.888,.008,.0034),
        (-.531,-.017,.893,.0054,.0028),(-.562,-.031,.904,.0042,.0024),
        (-.594,-.044,.921,.0055,.0025)],axis=(0,1,0),n=16)
    def spoon(x,y,z):
        return (-.618+.032*x-.006*y,-.054+.013*x+.021*y,.920+z-.001*x)
    wheel("Spoon_Planished oval scoop",S,mirror,[(0,-.0065),(.45,-.0053),
        (.78,-.0021),(.97,.0022),(1,.0043),(.98,.0052),(.76,.0002),
        (.43,-.0032),(0,-.0044)],spoon,40)
    def bite(x,y,z):
        return -.618+x,-.054+y,.920+z
    ricepile("Bite",S,bite,.022,.016,.001,.0075,22,.0047)
