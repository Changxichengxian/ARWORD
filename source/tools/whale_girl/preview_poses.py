"""Author editable idle/prop clips alongside the gameplay IK performance."""
import bpy
from math import sin,pi
from mathutils import Quaternion, Vector
from acting import meal

def ease(t):
    t=max(0.,min(1.,t))
    return t*t*(3-2*t)

def build_clips(rig):
    actor=rig.animation_data
    rice=actor.action
    rice.use_fake_user=True
    for motion,duration in (("RiceBreak",7),("BalanceBasin",6),("IslandIdle",5)):
        actor.action=rice if motion=="RiceBreak" else bpy.data.actions.new(motion)
        actor.action.use_fake_user=True
        for frame in range(1,duration*24+2,2):
            time=(frame-1)/24
            wearing=motion=="BalanceBasin"
            eating=motion=="RiceBreak"
            weight=ease((time-.70)/.48)*(1-ease((time-5.13)/.52)) if wearing else 0
            lift=.26*(1-ease((time-.88)/.57)+ease((time-4.90)/.52)) if wearing else 0
            snack=meal(time) if eating else {}
            for name,show in (("BasinMount",wearing and .85<time<5.45),("BowlMount",eating),("SpoonMount",eating),("BiteMount",snack.get("bite",0)>.15)):
                pb=rig.pose.bones[name]
                pb.scale=(1.,)*3 if show else (.0001,)*3
                pb.keyframe_insert(data_path="scale",frame=frame,group=name)
            bone=rig.pose.bones["BasinMount"]
            bone.location=bone.bone.matrix_local.to_quaternion().inverted()@Vector((0,0,lift))
            bone.keyframe_insert(data_path="location",frame=frame,group=bone.name)
            for key,value in (("Tuck",weight),("Eyelid",snack.get("blink",ease((time-2.08)/.085)*(1-ease((time-2.25)/.14)))),
                              ("Jaw",snack.get("mouth",.015)),("Spoonful",snack.get("bite",0))):
                rig[key]=value
                rig.keyframe_insert(data_path='["'+key+'"]',frame=frame,group="Expression")
            if eating:continue
            for p in rig.pose.bones:
                p.rotation_quaternion=Quaternion()
            for sign,side in ((1,"left"),(-1,"right")):
                p=rig.pose.bones[side+"UpperArm"]
                b=p.bone
                direction=Vector((sign*.55,-.13+.025*sin(time*1.5),-1))
                bind=b.matrix_local.to_quaternion()
                swing=(b.tail_local-b.head_local).rotation_difference(direction)
                p.rotation_quaternion=bind.inverted()@swing@bind
                # Show the soft palm and rounded fingertips from the front.
                palm=rig.pose.bones[side+"Hand"]
                palm_bind=palm.bone.matrix_local.to_quaternion()
                palm.rotation_quaternion=palm_bind.inverted()@Quaternion((1,0,0),-1.0)@palm_bind
            rig.pose.bones["head"].rotation_quaternion=Quaternion((0,1,0),.055*sin(time*2*pi/duration))
            for p in rig.pose.bones:
                p.keyframe_insert(data_path="rotation_quaternion",frame=frame,group=p.name)
    # Make the initial modeling pose pleasant when opened outside the game.
    actor.action=bpy.data.actions["IslandIdle"]
    bpy.context.scene.frame_set(1)
    return rice

def set_drivers(rig):
    for obj,key,setting in (("CrownLock","BasinTuck","Tuck"),("Hairstyle","BasinSeat","Tuck"),
                             ("Expression","blink","Eyelid"),("Expression","ih","Jaw")):
        prop=bpy.data.objects[obj].data.shape_keys.key_blocks[key]
        driver=prop.driver_add("value").driver
        var=driver.variables.new();var.name="amount";var.type="SINGLE_PROP"
        var.targets[0].id=rig;var.targets[0].data_path='["'+setting+'"]'
        driver.expression="amount"
