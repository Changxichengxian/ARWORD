"""Low-poly meadow rabbit. The wide head, haunches and short paws read at game scale."""
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from wildlife_mesh import clean, export, ico, material, mesh, node

fur = material('warm cinnamon fur', 'CBA990')
light = material('cream muzzle and paws', 'F6E8D1')
inner = material('dusty rose ear interior', 'DFABAC')
dark = material('espresso eyes', '302934')
nose_color = material('rose nose', 'AB6D76')
white = material('ivory eye glint', 'FFF9EE')


def ear_skin(parent, lean):
    rings = [
        (0, 0, .032, .021), (.055, .002, .055, .024),
        (.134, .006, .060, .025), (.204, .020, .052, .022),
        (.253, .033, .034, .017), (.273, .040, .013, .009),
    ]
    sides = 12
    vertices = [
        (lean * x + width * math.cos(j * math.tau / sides),
         .015 * math.sin(z * 8) + depth * math.sin(j * math.tau / sides), z)
        for z, x, width, depth in rings for j in range(sides)
    ]
    faces = [tuple(reversed(range(sides)))]
    for i in range(len(rings) - 1):
        for j in range(sides):
            k = (j + 1) % sides
            faces.append((i*sides+j, i*sides+k, (i+1)*sides+k, (i+1)*sides+j))
    faces.append(tuple(range(len(vertices)-sides, len(vertices))))
    ear = mesh('rounded ear with rose inset', vertices, faces, fur, parent)
    ear.data.materials.append(inner)
    for i in range(1, 4):
        for j in range(1 if i == 2 else 2, 5 if i == 2 else 4):
            ear.data.polygons[1 + i*sides + j].material_index = 1


clean()
root = node('Rabbit')
body = node('Body', root, (0, -.065, .253))
torso = ico('low pear-shaped torso', (0, 0, 0), (.192, .226, .185), fur, body, 2)
torso.data.materials.append(light)
for face in torso.data.polygons:
    if face.center.y > .45 and face.center.z < -.18:
        face.material_index = 1

head = node('Head', body, (0, .156, .147))
ico('wide round head', (0, .022, .008), (.198, .169, .165), fur, head, 3)
for s in [-1, 1]:
    ico('soft cream muzzle', (s*.055, .144, -.035), (.069, .056, .050), light, head, 2)
nose = node('Nose', head, (0, .192, -.017))
ico('little rose nose', (0, 0, 0), (.025, .012, .017), nose_color, nose, 2)

parts = [body, head, nose]
for side, s in [('L', -1), ('R', 1)]:
    eye = node('Eye'+side, head, (s*.110, .152, .041))
    eye.rotation_euler.z = -s*.48
    ico('large dark eye', (0, 0, 0), (.033, .012, .041), dark, eye, 2)
    ico('eye glint', (-.007, .011, .015), (.010, .003, .010), white, eye, 2)
    ear = node('Ear'+side, head, (s*.079, -.012, .112))
    ear_skin(ear, s)
    ear.scale.z = 1.03 if side == 'L' else .94

    fore = node('Fore'+side, root, (s*.092, .108, .191))
    ico('short foreleg', (0, -.008, -.065), (.065, .063, .110), fur, fore, 2)
    paw = node('ForePaw'+side, fore, (0, .021, -.137))
    front_toes = ico('rounded front paw', (0, .027, -.010), (.061, .080, .044), fur, paw, 2)
    front_toes.data.materials.append(light)
    for face in front_toes.data.polygons:
        if face.center.y > .04 or face.center.z < -.26:
            face.material_index = 1
    hind = node('Hind'+side, root, (s*.118, -.178, .212))
    ico('round haunch', (s*.010, .012, -.018), (.107, .143, .145), fur, hind, 2)
    foot = node('HindPaw'+side, hind, (s*.012, .040, -.154))
    hind_toes = ico('tucked hind paw', (0, .052, -.013), (.071, .105, .045), fur, foot, 2)
    hind_toes.data.materials.append(light)
    for face in hind_toes.data.polygons:
        if face.center.y > .10 or face.center.z < -.27:
            face.material_index = 1
    parts.extend([eye, ear, fore, paw, hind, foot])

tail = node('Tail', body, (0, -.217, .015))
ico('cream cotton tail', (0, -.031, .022), (.086, .082, .088), light, tail, 2)
export('wild_rabbit', [*parts, tail])
