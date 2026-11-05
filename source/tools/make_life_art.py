"""Original articulated coastal wildlife. Blender +Y is forward, +Z is up.

The gull has a plain white head, swept grey wings with black outer primaries,
and separate wrist pivots. All thin parts have actual thickness. Source meshes
and their named motion pivots are kept in each editable .blend file.
"""
import bpy, math, sys
from pathlib import Path
from mathutils import Vector
sys.path.insert(0, str(Path(__file__).resolve().parent))
from wildlife_mesh import clean, material, node, ico, mesh, export, ONLY

ivory = material('gull white', 'F5F4E8')
grey = material('gull silver mantle', 'ACB6BC')
flight = material('outer flight feather charcoal', '343C49')
dark = material('eye dark brown', '202D36')
gold = material('beak warm yellow', 'E7AF40')
coral = material('coral orange', 'E28C65')
cream = material('fish belly', 'F7DEAC')
mint = material('butterfly jade', '78BBA8')
purple = material('butterfly violet', '8A81BA')
border = material('butterfly dark border', '3D4869')
patch = material('butterfly warm spots', 'F0CF81')
underside_violet = material('butterfly underside violet', '8F91AE')
underside_jade = material('butterfly underside jade', '9BB9AA')


def plate(name, outline, thickness, upper, parent, lower=None):
    """Shallow convex solid with softly crowned upper and lower faces."""
    lower = lower or upper
    points = [Vector(p) for p in outline]
    n = len(points)
    centre = sum(points, Vector()) / n
    vertices = [tuple(p) for p in points]
    vertices += [tuple(p - Vector((0, 0, thickness * .3))) for p in points]
    vertices += [tuple(centre + Vector((0, 0, thickness))),
                 tuple(centre - Vector((0, 0, thickness * .65)))]
    signed_area = sum(points[i].x * points[(i+1) % n].y - points[(i+1) % n].x * points[i].y for i in range(n))
    faces = []
    for i in range(n):
        j = (i+1) % n
        faces.extend([(2*n, i, j), (2*n+1, n+j, n+i), (i, n+i, n+j, j)])
    if signed_area < 0:
        faces = [tuple(reversed(f)) for f in faces]
    obj = mesh(name, vertices, faces, upper, parent)
    obj.data.materials.append(lower)
    for i, polygon in enumerate(obj.data.polygons):
        polygon.material_index = 1 if i % 3 == 1 else 0
    return obj


def rod(name, a, b, radius, mat, parent):
    a, b = Vector(a), Vector(b)
    bpy.ops.mesh.primitive_cone_add(vertices=6, radius1=radius,
                                    radius2=radius*.72, depth=(b-a).length)
    obj = bpy.context.object
    obj.name = name
    obj.parent = parent
    obj.location = (a+b)/2
    obj.rotation_euler = (b-a).to_track_quat('Z', 'Y').to_euler()
    obj.data.materials.append(mat)
    return obj


clean()
root = node('Bird')
body = node('Body', root)
ico('streamlined white body', (0, -.025, 0), (.128, .285, .128), ivory, body, 2)
ico('silver back', (0, -.075, .07), (.114, .23, .064), grey, body, 2)
ico('white neck', (0, .19, .055), (.084, .115, .103), ivory, body, 2)
head = node('Head', root, (0, .24, .083))
ico('plain white head', (0, .035, .018), (.091, .115, .091), ivory, head, 2)
bill = [(-.034,.105,-.003),(.034,.105,-.003),(-.026,.105,.035),(.026,.105,.035),
        (-.013,.229,-.007),(.013,.229,-.007),(0,.236,.010),(0,.197,.033)]
mesh('slender yellow bill', bill,
     [(0,4,5,1),(0,2,7,6,4),(1,5,6,7,3),(2,3,7),(4,6,5),(0,1,3,2)], gold, head)
ico('lower bill spot', (.014,.192,-.004), (.008,.018,.009), coral, head, 1)
for s in [-1, 1]:
    ico('small black eye', (s*.078,.072,.042), (.012,.016,.014), dark, head, 2)
    ico('eye highlight', (s*.088,.076,.047), (.0035,.004,.004), ivory, head, 1)
    rod('tucked leg', (s*.045,-.14,-.095), (s*.045,-.245,-.13), .012, gold, body)
    plate('tucked webbed foot', [(s*.027,-.22,-.13),(s*.070,-.22,-.13),
                               (s*.081,-.285,-.13),(s*.045,-.272,-.135)], .004, gold, body)
tail = node('Tail', root, (0,-.235,.005))
plate('white rounded tail', [(-.065,.025,0),(.065,.025,0),(.112,-.19,-.012),
                             (.075,-.208,-.012),(0,-.217,-.012),(-.075,-.208,-.012),
                             (-.112,-.19,-.012)], .012, ivory, tail)
wings = []
for side, s in [('L', -1), ('R', 1)]:
    wing = node('Wing'+side, root, (s*.093, .015, .04))
    wrist = node('WingTip'+side, wing, (s*.335, .025, -.006))
    wings.extend([wing, wrist])
    plate('grey inner wing', [(0,.13,0),(s*.20,.155,.012),(s*.36,.12,-.006),
                              (s*.38,-.145,-.006),(s*.19,-.195,-.01),(0,-.15,0)],
          .025, grey, wing, ivory)
    plate('grey swept hand wing', [(s*-.025,.108,0),(s*.16,.078,-.012),(s*.29,-.025,-.019),
                                   (s*.23,-.196,-.025),(s*.105,-.194,-.015),(s*-.025,-.14,0)],
          .015, grey, wrist, ivory)
    plate('black outer primaries', [(s*.245,.006,-.018),(s*.36,-.10,-.027),
                                    (s*.465,-.225,-.04),(s*.414,-.221,-.037),
                                    (s*.389,-.254,-.04),(s*.344,-.23,-.036),
                                    (s*.317,-.25,-.037),(s*.271,-.217,-.031),
                                    (s*.218,-.194,-.025)],
          .011, flight, wrist, flight)
    for x,y in [(.366,-.191),(.316,-.203)]:
        plate('white primary mirror', [(s*(x-.017),y+.013,-.018),
                                       (s*(x+.018),y-.008,-.019),
                                       (s*(x+.004),y-.031,-.020),
                                       (s*(x-.022),y-.011,-.018)], .003, ivory, wrist)
export('wild_bird', [body, head, tail, *wings])


clean()
root = node('Fish')
body = node('Body', root)
# A single closed surface carries both back and belly colours. Overlapping
# ellipsoids used to leave little pale fragments along the lower silhouette.
profile = [(-.285,.025,.045),(-.21,.072,.10),(-.09,.112,.155),
           (.055,.117,.17),(.17,.089,.128),(.255,.046,.075),(.29,.023,.035)]
ring_size = 12
vertices = []
for y, width, height in profile:
    for j in range(ring_size):
        angle = 2*math.pi*j/ring_size
        vertices.append((math.cos(angle)*width,y,math.sin(angle)*height))
faces = []
for i in range(len(profile)-1):
    for j in range(ring_size):
        k = (j+1)%ring_size
        faces.append((i*ring_size+j,(i+1)*ring_size+j,(i+1)*ring_size+k,i*ring_size+k))
faces += [tuple(range(ring_size)),tuple((len(profile)-1)*ring_size+j for j in reversed(range(ring_size)))]
fish_body = mesh('continuous coral body and pale belly', vertices, faces, coral, body)
fish_body.data.materials.append(cream)
for polygon in fish_body.data.polygons:
    # Colour the two lowest ring sectors without adding any overlay geometry.
    polygon.material_index = 1 if polygon.center.z < -.093 else 0
for s in [-1,1]:
    ico('eye', (s*.079,.18,.05), (.017,.022,.022), dark, body, 2)
    ico('eye glint', (s*.094,.185,.056), (.004,.005,.005), ivory, body, 1)
rod('small mouth',(-.017,.293,0),(.017,.293,0),.004,dark,body)
plate('low dorsal fin', [(0,.145,.10),(-.009,.03,.275),(0,-.15,.225),(.009,-.205,.09)], .004, gold, body)
fins = []
for side,s in [('L',-1),('R',1)]:
    f = node('Fin'+side, root, (s*.096,.07,-.015))
    fins.append(f)
    plate('pectoral paddle', [(0,.015,0),(s*.125,-.07,-.035),(s*.105,-.14,-.04),(0,-.07,-.012)], .006, gold, f)
tail = node('Tail', root, (0,-.242,0))
ico('tail wrist', (0,-.018,0), (.055,.082,.073), coral, tail, 2)
vertices = [(-.008,.018,.05),(.008,.018,.05),(0,-.235,.17),(0,-.195,.025),
            (0,-.235,-.16),(-.008,.018,-.05),(.008,.018,-.05)]
mesh('vertical forked caudal fin', vertices,
     [(0,2,3,4,5),(1,6,4,3,2),(0,1,2),(5,4,6),(0,5,6,1)], gold, tail)
export('wild_fish', [body, tail, *fins])


clean()
root = node('Butterfly')
body = node('Body', root)
ico('slender abdomen', (0,-.055,0), (.025,.105,.026), border, body, 2)
ico('thorax', (0,.045,.004), (.035,.054,.034), dark, body, 2)
ico('small head', (0,.098,.008), (.029,.03,.028), dark, body, 2)
for s in [-1,1]:
    rod('antenna stem', (s*.013,.115,.015), (s*.050,.188,.027), .0045, border, body)
    ico('antenna club', (s*.050,.188,.027), (.007,.012,.007), border, body, 1)
wings = []
for side,s in [('L',-1),('R',1)]:
    wing = node('Wing'+side, root, (s*.016,0,0))
    hind = node('HindWing'+side, wing, (0,-.045,-.004))
    wings.extend([wing,hind])
    outline = [(0,.055,0),(s*.09,.181,0),(s*.21,.234,0),(s*.281,.194,0),
               (s*.307,.116,0),(s*.257,.004,0),(s*.139,-.052,0),(0,-.038,0)]
    plate('rounded forewing border', outline, .006, border, wing)
    plate('violet forewing field', [(s*.035,.052,.009),(s*.112,.163,.009),
                                    (s*.209,.204,.009),(s*.253,.173,.009),
                                    (s*.269,.116,.009),(s*.229,.03,.009),
                                    (s*.135,-.017,.009)], .003, purple, wing)
    plate('rounded hindwing border', [(0,.03,0),(s*.153,.013,0),(s*.239,-.063,0),
                                     (s*.218,-.133,0),(s*.147,-.188,0),
                                     (s*.071,-.163,0),(0,-.074,0)], .006, border, hind)
    plate('jade hindwing field', [(s*.029,-.013,.009),(s*.148,-.017,.009),
                                  (s*.206,-.064,.009),(s*.187,-.118,.009),
                                  (s*.143,-.153,.009),(s*.09,-.132,.009)], .003, mint, hind)
    for x,y in [(.20,.15),(.242,.111),(.20,.063)]:
        ico('warm forewing dot',(s*x,y,.016),(.016,.022,.003),patch,wing,1)
    ico('hindwing eyespot dark centre',(s*.151,-.097,.016),(.028,.032,.004),border,hind,2)
    ico('hindwing eyespot pale pupil',(s*.151,-.097,.020),(.013,.017,.003),patch,hind,1)
    # Both faces are visible during flight. Mirror only the markings and inner
    # colour fields, with a quieter palette on the underside of the wings.
    for part in [wing,hind]:
        for original in list(part.children):
            if original.type != 'MESH' or not any(word in original.name for word in ['field','dot','eyespot']):
                continue
            underside = original.copy()
            underside.data = original.data.copy()
            underside.name = original.name + ' underside'
            bpy.context.collection.objects.link(underside)
            underside.parent = part
            underside.location.z = -original.location.z
            underside.scale.z = -original.scale.z
            for index, mat in enumerate(underside.data.materials):
                if mat == purple:
                    underside.data.materials[index] = underside_violet
                elif mat == mint:
                    underside.data.materials[index] = underside_jade
export('wild_butterfly', [body, *wings])

if not ONLY or 'wild_whale' in ONLY:
    import runpy
    runpy.run_path(str(Path(__file__).with_name('make_blue_whale.py')), run_name='__main__')
print('WILDLIFE_ASSETS_READY: wild_bird, wild_fish, wild_butterfly, wild_whale')
