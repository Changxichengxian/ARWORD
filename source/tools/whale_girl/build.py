"""Build the editable whale girl and her mobile scene with Blender 4.4."""
from collections import defaultdict
import json
from pathlib import Path
from math import hypot
import sys
import bpy
from mathutils import Euler, Quaternion, Vector
HERE = Path(__file__).resolve().parent
SOURCE = HERE.parents[1]
sys.path.insert(0, str(HERE))
import geometry as geom
import face, fringe, hair, mantle, outfit, tailprops, tailor, wardrobe, portrait, hands, bib
from bake_paint import bake as bake_hair_paint
from acting import meal
from preview_poses import build_clips,set_drivers
from clip_weights import export as export_expression_clips, illustrated

def make_rig():
    data=bpy.data.armatures.new("Whale Girl")
    rig=bpy.data.objects.new("WhaleRig",data)
    bpy.context.collection.objects.link(rig)
    bpy.context.view_layer.objects.active=rig
    bpy.ops.object.mode_set(mode="EDIT")
    def add(name,start,end,parent=None):
        bone=data.edit_bones.new(name)
        bone.head=start
        bone.tail=end
        if parent:
            bone.parent=data.edit_bones[parent]
    hips=(0,.007,.55)
    spine=(0,0,.68)
    chest=(0,0,.81)
    neck=(0,0,.945)
    head=(0,0,.97)
    add("hips",hips,spine)
    add("spine",spine,chest,"hips")
    add("chest",chest,neck,"spine")
    add("neck",neck,head,"chest")
    add("head",head,(0,0,1.59),"neck")
    for sign,side in ((1,"left"),(-1,"right")):
        shoulder=(sign*.155,0,.903)
        elbow=(sign*.315,0,.892)
        wrist=(sign*.46,-.003,.885)
        knee=(sign*.09,-.007,.285)
        ankle=(sign*.092,.005,.112)
        add(side+"UpperArm",shoulder,elbow,"chest")
        add(side+"LowerArm",elbow,wrist,side+"UpperArm")
        add(side+"Hand",wrist,(sign*.54,-.005,.88),side+"LowerArm")
        add(side+"UpperLeg",(sign*.088,.009,.50),knee,"hips")
        add(side+"LowerLeg",knee,ankle,side+"UpperLeg")
        add(side+"Foot",ankle,(sign*.092,-.103,.047),side+"LowerLeg")
    add("TailRoot",(0,.12,.57),(.12,.43,.36),"hips")
    add("TailMid",(.12,.43,.36),(.34,.53,.45),"TailRoot")
    add("TailFin",(.34,.53,.45),(.34,.56,.57),"TailMid")
    for name,x,y in (("HairL",.29,.04),("HairR",-.29,.04),("HairBack",0,.24)):
        add(name,(x,y,1.26),(x,y+.03,.64),"head")
    for name,pos,owner in (("BowlMount",(.465,-.02,.94),"leftHand"),
                            ("SpoonMount",(-.465,-.025,.895),"rightHand"),
                            ("BiteMount",(-.618,-.054,.920),"SpoonMount"),
                            ("BasinMount",(0,0,1.64),"head")):
        add(name,pos,(pos[0],pos[1],pos[2]+.08),owner)
    bpy.ops.object.mode_set(mode="OBJECT")
    return rig

def assemble(rig):
    geom.palette()
    groups=defaultdict(list)
    props={"Bowl":"RiceBowl","Spoon":"RiceSpoon","Bite":"SpoonBite","Basin":"SteelBasin"}
    for component in (face,mantle,fringe,hair,outfit,hands,bib,tailprops):
        geom.SECTION=component.__name__
        component.build()
    for item,section in geom.PARTS:
        mount=next((g.name for g in item.vertex_groups if g.name.endswith("Mount")),None)
        group=props[mount.removesuffix("Mount")] if mount else section.title()
        if section in ("hands","bib"):group="Outfit"
        if item.name.startswith("Bite"):
            group="SpoonBite"
            item.vertex_groups["SpoonMount"].name="BiteMount"
        if section=="outfit":
            if tailor.textile_skip(item.name) or wardrobe.replaced(item.name):
                bpy.data.objects.remove(item,do_unlink=True)
                continue
            wardrobe.fit(item)
        if section=="outfit" and item.data.shape_keys:
            # Bake the naturally cupped palm without animating the entire dress.
            keys=item.data.shape_keys.key_blocks
            if "Palmar vault" in keys:
                keys["Palmar vault"].value=.75
                bpy.context.view_layer.objects.active=item
                bpy.ops.object.shape_key_remove(all=True,apply_mix=True)
        if section=="face":
            keys=item.data.shape_keys
            if keys:
                group="Expression"
                for key in keys.key_blocks:
                    for vertex in key.data:
                        x,y,z=vertex.co
                        if item.name.startswith("Little pout") and key.name=="Basis":
                            x,_,z=portrait.smile(x,y,z)
                            y=geom.face_y(x,z)-.00165
                        vertex.co=portrait.sculpt_face(x,y,z)
            else:
                for vertex in item.data.vertices:vertex.co=portrait.sculpt_face(*vertex.co)
        if section in ("mantle","fringe"):
            group="Hairstyle"
            ink=item.data.attributes.new("Paint view","INT","POINT")
            view=1 if section=="fringe" else 2 if item.name.startswith("Temple silk") else 3
            ink.data.foreach_set("value",[view]*len(item.data.vertices))
            geom.shape(item,"BasinSeat",seat_crown)
        if section=="hair" and item.name.startswith("Fin"):
            for v in item.data.vertices:
                t=min(1.,max(0.,(abs(v.co.x)-.31)/.25))
                v.co.y+=.15*t-.022
                v.co.z-=.097
        if item.name.startswith("CrownLock"):
            group="CrownLock"
            geom.shape(item,"BasinTuck",lambda x,y,z:seat_crown(*tailprops.tucked_crown(x,y,z)))
        unknown=set(g.name for g in item.vertex_groups)-set(rig.data.bones.keys())
        if unknown:raise ValueError((item.name,unknown))
        groups[group].append(item)
    if "CrownLock" not in groups or "SteelBasin" not in groups:
        raise ValueError("The free crown curl and basin must be independently rigged")
    for name,items in groups.items():
        bpy.ops.object.select_all(action="DESELECT")
        for item in items:item.select_set(True)
        group=items[0]
        bpy.context.view_layer.objects.active=group
        if len(items)>1:bpy.ops.object.join()
        group.name=name
        group.data.name=name
        if name=="Hairstyle":
            bake_hair_paint(group)
        group.parent=rig
        modifier=group.modifiers.new("Whale Rig","ARMATURE")
        modifier.object=rig
        print(name,len(group.data.vertices),list(group.data.shape_keys.key_blocks.keys()) if group.data.shape_keys else [])
    return groups

def seat_crown(x,y,z):
    # The underside is flat at the center and slopes toward the rolled rim.
    # Compress the cap against the measured interior once it enters the basin.
    r=hypot(x,y-.016)
    if r >= .357 or z <= 1.466:return x,y,z
    ceiling=1.489+.148-max(0.,r-.197)*.99
    if z>ceiling:
        z=ceiling-.004*(1-1/(1+(z-ceiling)*24))
    return x,y,z

def bake_meal(rig):
    pose=rig.pose.bones
    rest=rig.data.bones
    fps=24
    bpy.context.scene.render.fps=fps
    bpy.context.scene.frame_end=169
    expressions=[]
    for frame in range(1,170,2):
        t=(frame-1)/fps
        sample=meal(t)
        expressions.append([round(sample[k],5) for k in ("mouth","blink","bite")])
        global_rot={"chest":Euler(sample["chest"]).to_quaternion(),"head":Euler(sample["head"]).to_quaternion()}
        global_rot["neck"]=global_rot["chest"]
        for side,sign in (("left",1),("right",-1)):
            upper=rest[side+"UpperArm"]
            lower=rest[side+"LowerArm"]
            hand=rest[side+"Hand"]
            shoulder=rest["chest"].head_local+global_rot["chest"]@(upper.head_local-rest["chest"].head_local)
            spoon_rest=Vector((-.158,-.051,.035))
            target=Vector(sample[side])
            if side=="right":
                target-=sample["spoon"]*(spoon_rest.length-.145)
            delta=target-shoulder
            axis=delta.normalized()
            a=upper.length
            b=lower.length
            dist=max(abs(a-b)+.0001,min(delta.length,a+b-.0001))
            along=(a*a-b*b+dist*dist)/(2*dist)
            pole=Vector((sign*.73,.25,-1))
            outward=(pole-axis*axis.dot(pole)).normalized()
            elbow=shoulder+axis*along+outward*max(0,a*a-along*along)**.5
            wrist=shoulder+axis*dist
            global_rot[upper.name]=(upper.tail_local-upper.head_local).rotation_difference(elbow-shoulder)
            global_rot[lower.name]=(lower.tail_local-lower.head_local).rotation_difference(wrist-elbow)
            global_rot[hand.name]=Quaternion() if sign==1 else spoon_rest.rotation_difference(sample["spoon"])
        for name,rotation in global_rot.items():
            bone=rest[name]
            parent_rotation=global_rot.get(bone.parent.name,Quaternion())
            bind=bone.matrix_local.to_quaternion()
            key=bind.inverted()@parent_rotation.inverted()@rotation@bind
            pb=pose[name]
            key.make_compatible(pb.rotation_quaternion)
            pb.rotation_quaternion=key
            pb.keyframe_insert(data_path="rotation_quaternion",frame=frame,group=name)
    rig.animation_data.action.name="RiceBreak"
    (SOURCE/"assets/characters/whale_meal.json").write_text(json.dumps(expressions,separators=(',',':'))+"\n",encoding="utf8")

def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.filepaths.save_version=0
    rig=make_rig()
    assemble(rig)
    bake_meal(rig)
    build_clips(rig)
    bpy.context.scene.frame_set(1)
    rig["attribution"]="ARWORD; Shangshan, ZipZipPipe, YunYueSama, xiaoweigen. CC BY-NC-SA 4.0. See whale-girl-CREDITS.txt."
    bpy.ops.export_scene.gltf(filepath=str(SOURCE/"assets/characters/whale_girl.glb"),export_format="GLB",
                              export_animation_mode="ACTIONS",export_anim_single_armature=True,
                              export_extras=True,export_morph_normal=False,export_skins=True,
                              export_yup=True)
    model = SOURCE/"assets/characters/whale_girl.glb"
    export_expression_clips(model,model.with_name("whale_meal.json"))
    for mat in bpy.data.materials:
        if not mat.use_nodes or not illustrated(mat.name):continue
        tree=mat.node_tree
        paint=tree.nodes.get("Principled BSDF").inputs["Base Color"]
        ink=tree.nodes.new("ShaderNodeEmission")
        if paint.is_linked:
            tree.links.new(paint.links[0].from_socket,ink.inputs["Color"])
        else:
            ink.inputs["Color"].default_value=paint.default_value
        tree.links.new(ink.outputs[0],tree.nodes.get("Material Output").inputs["Surface"])
    set_drivers(rig)
    bpy.context.scene.frame_set(1)
    for area in bpy.context.screen.areas:
        if area.type=="VIEW_3D":
            view=area.spaces.active
            view.region_3d.view_rotation=Euler((1.54,0,-.14)).to_quaternion()
            view.region_3d.view_distance=2.85
            view.region_3d.view_location=(0,0,.91)
            view.shading.type="MATERIAL"
            view.overlay.show_overlays=False
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/"art-source/whale_girl.blend"),compress=True)
if __name__=="__main__":main()
