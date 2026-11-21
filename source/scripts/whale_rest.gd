extends RefCounted

# The upper-body clip and face samples share a 24 fps Blender timeline.
const PROPS = ["RiceBowl", "RiceSpoon", "SpoonBite", "SteelBasin"]
var props = {}
var crown: MeshInstance3D
var hair: MeshInstance3D
var clip: Animation
var tracks = {}
var face_samples: Array
var weight = 0.0
var time = 0.0
var lift = 0.0
var mouth = 0.0
var blink = 0.0

func setup(scene:Node3D, skeleton:Skeleton3D, meshes:Array):
	for mesh in meshes:
		var part = str(mesh.name)
		if part in PROPS:
			props[part] = mesh
			mesh.hide()
		elif part == "CrownLock":
			crown = mesh
		elif part == "Hairstyle":
			hair = mesh
	var player = scene.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player and player.has_animation("RiceBreak"):
		clip = player.get_animation("RiceBreak")
		player.stop()
		player.active = false
		for index in clip.get_track_count():
			if clip.track_get_type(index) != Animation.TYPE_ROTATION_3D: continue
			var name = clip.track_get_path(index).get_concatenated_subnames()
			if str(name) in ["head","chest","neck","leftUpperArm","leftLowerArm","leftHand","rightUpperArm","rightLowerArm","rightHand"]:
				var bone = skeleton.find_bone(name)
				if bone >= 0: tracks[bone] = index
	var samples = JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/whale_meal.json"))
	if samples is Array: face_samples = samples

func sample(world, neutral:bool):
	var worker = world.worker
	var resting = not neutral and worker.work_left <= 0 and worker.waking <= 0 and not worker.carry.visible and not world.transporting and not (world.move_tween and world.move_tween.is_running())
	time = clampf(worker.rest_time, 0.0, 7.0)
	weight = 0.0
	mouth = 0.0
	blink = 0.0
	var bite = 0.0
	if resting and worker.rest_variant == 3 and clip and not face_samples.is_empty():
		weight = smoothstep(0.0,.55,time) * (1.0-smoothstep(6.55,7.0,time))
		var phase = minf(time*12,face_samples.size()-1)
		var a:Array = face_samples[floori(phase)]
		var b:Array = face_samples[ceili(phase)]
		mouth = lerpf(a[0],b[0],fmod(phase,1))*weight
		blink = lerpf(a[1],b[1],fmod(phase,1))*weight
		bite = lerpf(a[2],b[2],fmod(phase,1))
	var hat = resting and worker.rest_variant == 0 and time > .85 and time < 5.45
	# The curl folds before the rim lowers and springs back after it lifts.
	var tuck = 0.0
	lift = 0.0
	if resting and worker.rest_variant == 0:
		tuck = smoothstep(.70,1.18,time)*(1.0-smoothstep(5.13,5.65,time))
		lift = .26*(1.0-smoothstep(.88,1.45,time)+smoothstep(4.90,5.42,time))
	for name in props:
		match name:
			"SteelBasin": props[name].visible = hat
			"SpoonBite": props[name].visible = weight > .55 and bite > .15
			_: props[name].visible = weight > .55
	if crown: crown.set_blend_shape_value(crown.find_blend_shape_by_name("BasinTuck"),tuck)
	if hair: hair.set_blend_shape_value(hair.find_blend_shape_by_name("BasinSeat"),tuck)

func apply(bone:int, original:Basis, parent:Basis)->Basis:
	if weight <= 0.0 or not tracks.has(bone): return original
	var rotation = clip.rotation_track_interpolate(tracks[bone],time)
	return original.slerp(parent * Basis(rotation),weight)
