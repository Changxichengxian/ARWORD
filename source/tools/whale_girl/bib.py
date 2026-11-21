"""Sculpt the gathered bib, neck bow and shell brooch in the drawing's front coordinates."""
from math import cos, pi, sin, sqrt
from geometry import painted


def build():
    def pos(u,v,relief):
        x=(u-247)*.0029
        z=.952-(v-278)*.00345
        width=.168-.038*min(1,abs(v-309)/45)
        depth=.119-.012*min(1,abs(v-314)/45)
        y=-depth*sqrt(max(.15,1-(x/width)**2))-relief
        return x,y,z
    def panel(name,fn,columns=32,rows=26):
        coords=[];faces=[];uv=[]
        for j in range(rows+1):
            for i in range(columns+1):
                u,v,d=fn(i/columns,j/rows)
                coords.append(pos(u,v,d));uv.append((u,v))
                if i and j:
                    a=j*(columns+1)+i
                    faces.append((a-columns-2,a-1,a,a-columns-1))
        return painted(name,"chest",coords,faces,uv)
    def center(s,t):
        v=281+70*t
        r=26+10*sin(pi*t)-2*t
        return 247+(2*s-1)*r,v,.009
    panel("Vanilla shirred bib",center)
    for sign in (-1,1):
        def lace(s,t):
            v=287+59*t
            inside=29+5*sin(pi*t)-4*t
            width=(11+6*cos(7*pi*t-.4))*(1-.37*t)
            return (247+sign*(inside+s*width),v+s*1.7*sin(7*pi*t),
                    .010+.003*sin(pi*s)+.004*s*(.5+.5*cos(7*pi*t-.4)))
        panel("Gathered collar lace",lace,12,64)
        def bow(s,t):
            # Two soft loops, then a wider cut end falling onto the bib.
            x=sign*(5+17*s)
            h=(3.1+4.8*sin(pi*s)**.8)*(2*t-1)
            return 247+x,297+h+.8*s,.018+.008*sin(pi*s)
        panel("Blue throat bow",bow,26,12)
        def ribbon(s,t):
            x=sign*(4+14*t+(2*s-1)*(4.4+4.8*t))
            return 247+x,300+t*(26+3*(2*s-1)),.020+.003*sin(pi*t)
        panel("Blue ribbon ends",ribbon,18,24)
    def brooch(s,t):
        # A domed scallop with seven raised ribs and a rounded lower hinge.
        a=2*pi*s
        shell=t*(1+.04*cos(7*a))
        u=247+14.2*shell*cos(a)
        v=298+11*shell*sin(a)
        return u,v,.029+.0085*sqrt(max(0,1-t*t))+.0017*(1+cos(7*a))*t
    panel("Painted shell brooch",brooch,64,12)
