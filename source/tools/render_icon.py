import bpy,math
from mathutils import Vector
from pathlib import Path
R=Path(__file__).resolve().parents[1]
bpy.ops.wm.open_mainfile(filepath=str(R/'art-source/planet.blend'))
def add_model(name,x,y,scale):
    with bpy.data.libraries.load(str(R/'art-source'/(name+'.blend')),link=False) as (data,target):target.objects=data.objects
    objects=[o for o in target.objects if o]
    for o in objects:bpy.context.collection.objects.link(o)
    root=[o for o in objects if not o.parent][0]
    p=Vector((x,y,math.sqrt(4.84**2-x*x-y*y)));root.location=p;root.rotation_euler=Vector((0,0,1)).rotation_difference(p.normalized()).to_euler();root.scale=(scale,)*3
for name,x,y,s in [('cottage',-1.8,0,.95),('windmill',1,-1,.9),('garden',1.6,1.7,.8),('oak',-2.6,-1.7,.85),('oak',-.4,-2.8,.7),('oak',2.7,-.6,.72),('oak',-2.4,1.8,.7)]:add_model(name,x,y,s)
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=32;scene.render.resolution_x=512;scene.render.resolution_y=512;scene.render.resolution_percentage=100
scene.world.color=(.15,.25,.34)
for p,power,size in [((3,-5,12),1800,8),((-7,-3,7),1000,7)]:
    bpy.ops.object.light_add(type='AREA',location=p);o=bpy.context.object;o.data.energy=power;o.data.shape='DISK';o.data.size=size;o.rotation_euler=(-o.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=(9,-13,13));cam=bpy.context.object;cam.rotation_euler=(Vector((0,0,.6))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=12.6;scene.camera=cam
scene.view_settings.view_transform='AgX';scene.render.image_settings.file_format='PNG';scene.render.film_transparent=False
scene.render.filepath=str(R/'assets/icon.png');bpy.ops.render.render(write_still=True)
scene.render.film_transparent=True;cam.data.ortho_scale=15.4;scene.render.filepath=str(R/'assets/icon-foreground.png');bpy.ops.render.render(write_still=True)
print('PLANET_ICON_COMPLETE')
