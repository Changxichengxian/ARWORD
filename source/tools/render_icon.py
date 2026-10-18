import bpy,math
from mathutils import Vector
from pathlib import Path
root=Path(__file__).resolve().parents[1]
bpy.ops.wm.open_mainfile(filepath=str(root/'art-source/ranger.blend'))
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=32
scene.render.resolution_x=512;scene.render.resolution_y=512;scene.render.resolution_percentage=100
scene.world.color=(.23,.35,.39)
def material(name,color):
    m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);return m
bpy.ops.mesh.primitive_cylinder_add(vertices=8,radius=1.2,depth=.28,location=(0,0,-.18));bpy.context.object.data.materials.append(material('Moss',(.10,.37,.19)))
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.35));bpy.context.object.data.materials.append(material('Backdrop',(.035,.21,.28)))
for pos,power,size in [((3,4,7),500,5),((-4,0,4),350,4),((0,-4,3),220,3)]:
    bpy.ops.object.light_add(type='AREA',location=pos);o=bpy.context.object;o.data.energy=power;o.data.shape='DISK';o.data.size=size;o.rotation_euler=(Vector((0,0,1))-o.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=(3.4,5,3.6));cam=bpy.context.object;cam.rotation_euler=(Vector((0,0,.8))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=3.15;scene.camera=cam
scene.view_settings.view_transform='AgX';scene.render.image_settings.file_format='PNG';scene.render.filepath=str(root/'assets/icon.png')
bpy.ops.render.render(write_still=True)
scene.render.film_transparent=True;bpy.data.objects['Plane'].hide_render=True
cam.data.ortho_scale=3.8;scene.render.filepath=str(root/'assets/icon-foreground.png')
bpy.ops.render.render(write_still=True)
