"""Rounded palms with a continuous finger silhouette traced from the approved front drawing."""
from math import exp, hypot, sqrt
from mathutils import Quaternion, Vector
from mathutils.geometry import delaunay_2d_cdt
from geometry import painted, mesh, tint

# Each cubic ends at the next landmark, including the two little finger clefts.
CONTOUR=[(141.5,397.3),
 (144,394.5,154,398.9,158.6,403.0),(160.7,405.5,159.5,412.2,156.6,416.5),
 (154,420.0,151.5,422.4,149.4,426.4),(147.6,430.4,142.5,429.3,142.3,426.6),
 (142,423.6,145.0,420.2,144.6,417.1),(142.0,417.6,139.3,418.8,137.7,420.6),
 (136.1,422.5,135.2,427.2,133.2,429.8),(131.6,431,130.1,430.6,129.5,429.7),
 (129.0,429.6,128.8,428.9,129.0,428.6),(127.9,430.1,126.3,430.8,125.4,430.2),
 (124.5,430.0,124.3,429.4,124.4,428.3),(123.4,429.6,122.2,429.6,121.8,428.4),
 (121.4,427.5,121.7,426.0,122.0,425.3),(120.8,426.2,120.3,425.0,120.9,423.5),
 (123.2,415.8,128.7,407.1,135.3,401.8),(138.6,399.4,140,398.3,141.5,397.3)]


def build():
    boundary=[Vector(CONTOUR[0])]
    for ax,ay,bx,by,cx,cy in CONTOUR[1:]:
        start=boundary[-1]
        a,b,c=Vector((ax,ay)),Vector((bx,by)),Vector((cx,cy))
        for i in range(1,7):
            t=i/6
            boundary.append((1-t)**3*start+3*(1-t)**2*t*a+3*(1-t)*t*t*b+t**3*c)
    boundary.pop()
    n=len(boundary)
    edges=[(i,(i+1)%n) for i in range(n)]
    points=boundary+[Vector((u+.37,v+.21)) for v in range(396,431,2) for u in range(120,161,2)]
    vertices,_,faces,*_=delaunay_2d_cdt(points,edges,[list(range(n))],1,.00001)
    faces=[tuple(f) for f in faces]
    boundary_edges={}
    for f in faces:
        for i,a in enumerate(f):
            b=f[(i+1)%len(f)]
            k=tuple(sorted((a,b)))
            if k in boundary_edges:boundary_edges[k]=None
            else:boundary_edges[k]=(a,b)
    perimeter=[edge for edge in boundary_edges.values() if edge]
    def distance(p):
        best=1e8
        for i,j in edges:
            a,b=boundary[i],boundary[j]
            d=b-a
            t=max(0,min(1,(p-a).dot(d)/max(d.length_squared,1e-10)))
            best=min(best,(p-(a+t*d)).length)
        return best
    distances=[distance(p) for p in vertices]
    for sign,side in ((1,"left"),(-1,"right")):
        shoulder=Vector((sign*.155,0,.903))
        elbow=Vector((sign*.315,0,.892))
        wrist=Vector((sign*.46,-.003,.885))
        swing=(elbow-shoulder).rotation_difference(Vector((sign*.55,-.13,-1)))
        undo=(swing@Quaternion((1,0,0),-1.0)).inverted()
        top=[];bottom=[];uv=[]
        for (u,v),edge in zip(vertices,distances):
            # Both sides roll into the common silhouette. The back of the
            # hand carries the illustrated knuckles in its own fixed UVs.
            d=sqrt(max(0,min(1.,edge/4)))
            width=-sign*(u-149)*.00265
            height=(399.4-v)*.00318
            dorsal=.0038+.0155*d
            hollow=.002+.011*d
            rake=.0065*(v-400)/28
            top.append(wrist+undo@Vector((width,-dorsal-rake,height)))
            bottom.append(wrist+undo@Vector((width,hollow-rake,height)))
            uv.append((u,v))
        bone=side+"Hand"
        front=[tuple(reversed(f)) if sign>0 else f for f in faces]
        painted(side+" painted knuckles",bone,top,front,uv)
        count=len(top)
        shell=[tuple(i+count for i in reversed(f)) for f in front]
        for a,b in perimeter:
            shell.append((a,b,b+count,a+count) if sign>0 else (b,a,a+count,b+count))
        palm=mesh(side+" palm and finger pads",bone,"white",top+bottom,shell)
        coords={tuple(round(q,5) for q in p):d for p,d in zip(top+bottom,distances*2)}
        def pigment(x,y,z):
            t=min(1,coords.get(tuple(round(q,5) for q in (x,y,z)),0)/4)
            return (.99,.77+.13*t,.70+.14*t)
        tint(palm,pigment)
