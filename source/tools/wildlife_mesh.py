"""Shared Blender primitives and vertex-painted wildlife export."""
import bpy, sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
ONLY=sys.argv[sys.argv.index('--only')+1].split(',') if '--only' in sys.argv else []
bpy.context.preferences.filepaths.save_version=0
def clean():
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
def material(name,color):
    rgb=[int(color[i:i+2],16)/255 for i in (0,2,4)]
    rgb=[v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in rgb]
    mat=bpy.data.materials.new(name);mat.use_nodes=True;mat.diffuse_color=(*rgb,1)
    mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(*rgb,1)
    mat.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.8
    mat.use_backface_culling=False
    return mat
def node(name,parent=None,position=(0,0,0)):
    obj=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(obj);obj.parent=parent;obj.location=position;return obj
def ico(name,position,scale,mat,parent,sub=1):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=sub,radius=1)
    obj=bpy.context.object;obj.name=name;obj.parent=parent;obj.location=position;obj.scale=scale;obj.data.materials.append(mat);return obj
def mesh(name,vertices,faces,mat,parent):
    data=bpy.data.meshes.new(name);data.from_pydata(vertices,[],faces);data.update()
    obj=bpy.data.objects.new(name,data);bpy.context.collection.objects.link(obj);obj.parent=parent;obj.data.materials.append(mat);return obj
def merge_branch(parent):
    # One vertex-painted draw per articulated part, keeping wing and tail pivots.
    parts=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.parent==parent]
    if not parts:return
    bpy.ops.object.select_all(action='DESELECT')
    for obj in parts:obj.select_set(True)
    bpy.context.view_layer.objects.active=parts[0]
    if len(parts)>1:bpy.ops.object.join()
    obj=bpy.context.object
    tint=obj.data.color_attributes.new(name='Tint',type='FLOAT_COLOR',domain='CORNER')
    for polygon in obj.data.polygons:
        color=obj.data.materials[polygon.material_index].diffuse_color
        for index in polygon.loop_indices:tint.data[index].color=color
    paint=material(parent.name+' palette','FFFFFF');v=paint.node_tree.nodes.new('ShaderNodeVertexColor');v.layer_name='Tint'
    paint.node_tree.links.new(v.outputs['Color'],paint.node_tree.nodes['Principled BSDF'].inputs['Base Color'])
    obj.data.materials.clear();obj.data.materials.append(paint)
    for polygon in obj.data.polygons:polygon.material_index=0
def export(name,parts):
    if ONLY and name not in ONLY:return
    for part in parts:merge_branch(part)
    for obj in bpy.context.scene.objects:
        if obj.type=='MESH':obj.data.validate();obj.data.update()
    bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets/models'/f'{name}.glb'),export_format='GLB',export_yup=True,export_apply=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art-source'/f'{name}.blend'))
