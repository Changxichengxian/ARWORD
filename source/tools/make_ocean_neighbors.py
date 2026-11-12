"""Original low-poly octopus, hammerhead and ocean sunfish, with movable fins and arms."""
import math
import sys
from pathlib import Path

from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
from wildlife_mesh import clean, export, ico, material, mesh, node

ink = material('deep blue eyes', '172F40')
glint = material('soft eye highlights', 'E9F1ED')
amber = material('octopus apricot', 'D88D60')
rose = material('octopus terracotta', 'BE7864')
cream = material('octopus pale underside', 'F1BD92')
slate = material('shark blue grey', '7899AB')
shark_back = material('shark slate back', '526F8F')
shark_belly = material('shark pearl belly', 'C9DCDD')
sunfish = material('sunfish light teal', '7ABAB9')
sunfish_back = material('sunfish blue green', '4B858D')
sunfish_belly = material('sunfish pale silver', 'C3DCD2')


def skin(name, parent, rings, palette, axis='Y', sides=14):
    """Closed, flat-shaded skin. Each ring gives its centre and two radii."""
    vertices = []
    for y, z, width, height in rings:
        for j in range(sides):
            angle = j*math.tau/sides
            x = width*math.cos(angle)
            vertical = height*math.sin(angle)
            vertices.append((x, y, z+vertical) if axis == 'Y' else (x, z+vertical, y))
    faces = [tuple(range(sides))]
    for i in range(len(rings)-1):
        for j in range(sides):
            k = (j+1)%sides
            faces.append((i*sides+j, (i+1)*sides+j, (i+1)*sides+k, i*sides+k))
    faces.append(tuple(reversed(range(len(vertices)-sides, len(vertices)))))
    if axis == 'Z':
        faces = [tuple(reversed(face)) for face in faces]
    obj = mesh(name, vertices, faces, palette[0], parent)
    for mat in palette[1:]:
        obj.data.materials.append(mat)
    for face in obj.data.polygons:
        if face.normal.z > .45:
            face.material_index = 1
        elif face.normal.z < -.35:
            face.material_index = 2
    return obj


def fin(name, parent, outline, thickness, mat, axis='Z'):
    points = [Vector(point) for point in outline]
    normal = Vector((0, 0, 1) if axis == 'Z' else (1, 0, 0))
    if (points[1]-points[0]).cross(points[2]-points[0]).dot(normal) < 0:
        points.reverse()
    center = sum(points, Vector()) / len(points)
    vertices = [tuple(point) for point in points]
    vertices.extend([tuple(center+normal*thickness), tuple(center-normal*thickness)])
    count = len(points)
    faces = []
    for i in range(count):
        j = (i+1)%count
        faces.extend([(count, i, j), (count+1, j, i)])
    return mesh(name, vertices, faces, mat, parent)


def eye(parent, x, y, z, size):
    side = 1 if x > 0 else -1
    ico('dark eye', (x, y, z), (size*.54, size, size*.92), ink, parent, 2)
    ico('small catchlight', (x+side*size*.45, y+size*.27, z+size*.28),
        (size*.18, size*.24, size*.24), glint, parent)


def octopus():
    clean()
    root = node('Octopus')
    body = node('Body', root)
    skin('rounded mantle', body, [
        (-.16, -.025, .067, .08), (-.12, -.036, .133, .113),
        (-.03, -.037, .192, .156), (.085, -.057, .217, .185),
        (.198, -.096, .170, .144), (.251, -.111, .101, .090),
        (.273, -.116, .032, .030),
    ], [amber, rose, cream], axis='Z', sides=16)
    for side in [-1, 1]:
        ico('raised brow', (side*.141, .077, .017), (.071, .063, .060), amber, body, 2)
        eye(body, side*.202, .107, .025, .032)
    parts = [body]
    for i in range(8):
        angle = (i+.5)*math.tau/8
        socket = node('ArmSocket'+str(i), root, (.118*math.sin(angle), .114*math.cos(angle), -.127))
        socket.rotation_euler.z = -angle
        arm = node('Arm'+str(i), socket)
        arm_length = 1+.14*math.cos(angle)
        skin('tapered arm', arm, [
            (-.05, .015, .052, .054), (.052, -.012, .048, .046),
            (.143*arm_length, -.071, .040, .034), (.244*arm_length, -.097, .031, .027),
            (.288*arm_length, -.091, .024, .020),
        ], [amber, rose, cream], sides=10)
        tip = node('ArmTip'+str(i), arm, (0, .260*arm_length, -.092))
        skin('curling tip', tip, [
            (-.029, -.003, .028, .023), (.035, -.002, .023, .017),
            (.110, .009, .016, .013), (.163, .046, .010, .009), (.189, .074, .003, .003),
        ], [amber, rose, cream], sides=9)
        for y, z, width in [(.064, -.063, .016), (.118, -.092, .014), (.177, -.112, .013), (.220, -.123, .011)]:
            for side in [-1, 1]:
                ico('pale sucker', (side*width, y*arm_length, z),
                    (width*.65, width*.75, .007), cream, arm)
        parts.extend([arm, tip])
    export('wild_octopus', parts)


def hammerhead():
    clean()
    root = node('Hammerhead')
    body = node('Body', root)
    skin('continuous shark body and wide head', body, [
        (-.67, -.015, .036, .056), (-.48, -.018, .073, .086),
        (-.26, -.008, .133, .126), (-.03, .003, .162, .133),
        (.18, .006, .143, .113), (.29, .005, .130, .076),
        (.34, .004, .193, .063), (.387, .008, .313, .066),
        (.44, .009, .350, .064), (.502, .009, .318, .052),
        (.539, .006, .222, .035), (.549, .006, .097, .024),
    ], [slate, shark_back, shark_belly], sides=18)
    for side in [-1, 1]:
        eye(body, side*.344, .435, .027, .028)
        for y in [.143, .177, .207]:
            ico('short gill', (side*(.150-(y-.143)*.14), y, -.027), (.005, .007, .027), shark_back, body)
    fin('tall swept dorsal fin', body, [(0,.14,.106),(0,.003,.328),(0,-.087,.285),(0,-.214,.091)], .035, shark_back, axis='X')
    tail = node('Tail', root, (0, -.626, -.015))
    skin('tail stock', tail, [
        (-.284, .043, .022, .031), (-.158, .011, .026, .047), (-.012, -.001, .038, .054), (.051, .001, .046, .056),
    ], [slate, shark_back, shark_belly], sides=10)
    fluke = node('Fluke', tail, (0, -.226, .025))
    fin('uneven crescent tail', fluke, [
        (0,.034,.043),(0,-.095,.265),(0,-.198,.352),(0,-.188,.208),(0,-.119,.028),
        (0,-.187,-.168),(0,-.096,-.145),(0,.025,-.050),
    ], .028, shark_back, axis='X')
    parts = [body, tail, fluke]
    for side, s in [('L', -1), ('R', 1)]:
        flipper = node('Flipper'+side, root, (s*.109, .061, -.044))
        fin('swept pectoral fin', flipper, [
            (0,.082,.001),(s*.143,.002,-.024),(s*.278,-.176,-.054),
            (s*.216,-.188,-.042),(s*.033,-.105,0),
        ], .026, slate)
        parts.append(flipper)
    export('wild_hammerhead', parts)


def ocean_sunfish():
    clean()
    root = node('OceanSunfish')
    body = node('Body', root)
    skin('flat round body', body, [
        (-.35, .005, .056, .216), (-.268, .009, .111, .266),
        (-.14, .013, .149, .296), (.017, .008, .153, .273),
        (.166, .004, .120, .209), (.278, .004, .077, .117),
        (.324, -.020, .048, .049), (.340, -.020, .031, .030),
    ], [sunfish, sunfish_back, sunfish_belly], sides=16)
    for side in [-1, 1]:
        eye(body, side*.101, .222, .046, .034)
    ico('small pursed mouth', (0,.339,-.022), (.025,.009,.018), sunfish_back, body, 2)
    parts = [body]
    for name, side in [('Dorsal',1), ('Anal',-1)]:
        fin_joint = node(name, root, (0,-.122,side*.252))
        fin('tall sculling fin', fin_joint, [
            (0,.121,0),(0,.021,side*.227),(0,-.108,side*.359),
            (0,-.185,side*.316),(0,-.169,side*.185),(0,-.192,0),
        ], .038, sunfish_back, axis='X')
        parts.append(fin_joint)
    tail = node('Tail', root, (0,-.326,.006))
    fin('rounded tail fringe', tail, [
        (0,.026,.215),(0,-.084,.188),(0,-.128,.104),(0,-.145,.022),
        (0,-.126,-.103),(0,-.086,-.173),(0,.018,-.204),
    ], .046, sunfish, axis='X')
    parts.append(tail)
    for side, s in [('L', -1), ('R', 1)]:
        flipper = node('Fin'+side, root, (s*.128,.092,-.03))
        fin('small rounded pectoral fin', flipper, [
            (0,.054,.001),(s*.084,-.025,.011),(s*.071,-.114,-.039),(s*.018,-.077,-.035),
        ], .019, sunfish_belly)
        parts.append(flipper)
    export('wild_sunfish', parts)


octopus()
hammerhead()
ocean_sunfish()
