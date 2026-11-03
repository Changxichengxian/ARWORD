extends Node3D
class_name IslandAvatar

# Fixed character rig. The model bytes are supplied with the personal installation.
const MAX_BYTES=64*1024*1024
const HEIGHT=1.085
const REQUIRED=["hips","spine","head","leftUpperArm","leftLowerArm","leftHand","rightUpperArm","rightLowerArm","rightHand","leftUpperLeg","leftLowerLeg","leftFoot","rightUpperLeg","rightLowerLeg","rightFoot"]
var world
var scene:Node3D
var skeleton:Skeleton3D
var info:Dictionary={}
var humanoid:Dictionary={}
var semantics:Dictionary={}
var local_rest:Array=[]
var global_rest:Array=[]
var poses:Array=[]
var down:Dictionary={}
var meshes:Array=[]
var foot_probes:Array=[]
var support_probes:Array=[]
var blink_bindings:Array=[]
var native_to_game=Basis.IDENTITY
var unit_scale=1.0
var clearance=.43
var gait_ratio=1.0
var tail_bones:Array=[]
var ground_offset=0.0
var rest_key=""
var rest_actor_height=0.0
var rest_cached=false
var rest_length=1.20
var enabled=false
var is_fish=false
var baked_surfaces={}
var used_baked_surfaces=0

static func preflight(path:String)->Dictionary:
	var f=FileAccess.open(path,FileAccess.READ)
	if f==null:return {"ok":false,"error":"无法读取这个模型文件"}
	var size=f.get_length()
	if size<20 or size>MAX_BYTES:return {"ok":false,"error":"模型需为 64 MB 内的 VRM 文件"}
	var bytes=f.get_buffer(size);f.close()
	if bytes.decode_u32(0)!=0x46546C67 or bytes.decode_u32(4)!=2 or bytes.decode_u32(8)!=size:return {"ok":false,"error":"模型文件头或长度不完整"}
	var length=bytes.decode_u32(12)
	if bytes.decode_u32(16)!=0x4E4F534A or length<2 or length>size-20:return {"ok":false,"error":"模型说明数据损坏"}
	var parsed=JSON.parse_string(bytes.slice(20,20+length).get_string_from_utf8())
	if not parsed is Dictionary:return {"ok":false,"error":"无法解析模型说明"}
	var ext=parsed.get("extensions",{})
	if not ext is Dictionary:return {"ok":false,"error":"模型扩展数据损坏"}
	for section in ["nodes","accessors","buffers","bufferViews","images","materials","meshes","skins"]:
		if not parsed.get(section,[]) is Array:return {"ok":false,"error":"模型结构数据损坏"}
		for item in parsed.get(section,[]):
			if not item is Dictionary:return {"ok":false,"error":"模型结构条目损坏"}
	var version="1" if ext.has("VRMC_vrm") else "0" if ext.has("VRM") else ""
	if version.is_empty():return {"ok":false,"error":"请选择带有人形骨骼的 VRM 模型"}
	for section in ["buffers","images"]:
		for resource in parsed.get(section,[]):
			if resource.has("uri") and not str(resource.uri).begins_with("data:"):return {"ok":false,"error":"模型必须自带贴图，不能引用外部文件或网址"}
	if parsed.get("nodes",[]).size()>1024 or parsed.get("images",[]).size()>32 or parsed.get("materials",[]).size()>64:return {"ok":false,"error":"模型结构过大，暂不支持"}
	var vertices=0
	for mesh in parsed.get("meshes",[]):
		if not mesh.get("primitives",[]) is Array:return {"ok":false,"error":"模型表面数据损坏"}
		for primitive in mesh.get("primitives",[]):
			if not primitive is Dictionary or not primitive.get("attributes",{}) is Dictionary:return {"ok":false,"error":"模型表面属性损坏"}
			if not (primitive.attributes.get("POSITION") is int or primitive.attributes.get("POSITION") is float):return {"ok":false,"error":"缺少模型位置数据"}
			var index=int(primitive.get("attributes",{}).get("POSITION",-1))
			if index<0 or index>=parsed.get("accessors",[]).size():return {"ok":false,"error":"模型顶点数据不完整"}
			var count=parsed.accessors[index].get("count",0)
			if not (count is int or count is float) or not is_finite(float(count)) or float(count)<1 or float(count)>250000:return {"ok":false,"error":"模型顶点数量损坏"}
			vertices+=int(count)
	if vertices<1 or vertices>250000:return {"ok":false,"error":"模型面数过高，暂不支持"}
	for skin in parsed.get("skins",[]):
		if not skin.get("joints",[]) is Array:return {"ok":false,"error":"模型骨架数据损坏"}
		if skin.get("joints",[]).size()>256:return {"ok":false,"error":"模型骨骼过多，暂不支持"}
	var vrm=ext.VRMC_vrm if version=="1" else ext.VRM
	if not vrm is Dictionary or not vrm.get("humanoid",{}) is Dictionary:return {"ok":false,"error":"人形骨骼说明损坏"}
	var bones={}
	if version=="1":
		if not vrm.humanoid.get("humanBones",{}) is Dictionary:return {"ok":false,"error":"人形骨骼映射损坏"}
		for name in vrm.get("humanoid",{}).get("humanBones",{}):
			var bone=vrm.humanoid.humanBones[name]
			if not bone is Dictionary or not (bone.get("node") is int or bone.get("node") is float):return {"ok":false,"error":"人形骨骼节点损坏"}
			bones[name]=int(bone.node)
	else:
		if not vrm.humanoid.get("humanBones",[]) is Array:return {"ok":false,"error":"人形骨骼映射损坏"}
		for bone in vrm.get("humanoid",{}).get("humanBones",[]):
			if not bone is Dictionary or not (bone.get("node") is int or bone.get("node") is float):return {"ok":false,"error":"人形骨骼节点损坏"}
			bones[str(bone.get("bone",""))]=int(bone.node)
	for name in REQUIRED:
		if not bones.has(name) or bones[name]<0 or bones[name]>=parsed.get("nodes",[]).size():return {"ok":false,"error":"缺少必要的人形骨骼："+name}
	for index in bones.values():
		if index<0 or index>=parsed.nodes.size():return {"ok":false,"error":"人形骨骼节点超出范围"}
	var meta=vrm.get("meta",{})
	if not meta is Dictionary:return {"ok":false,"error":"模型署名数据损坏"}
	var authors=meta.get("authors",[meta.get("author","")]);var author=""
	if authors is Array:
		for entry in authors:author+=(", " if not author.is_empty() else "")+str(entry).left(128)
	else:author=str(authors)
	return {"ok":true,"error":"","title":str(meta.get("name",meta.get("title","本地人物"))).left(256),"author":author.left(512),"version":version,"bytes":bytes,"json":parsed,"bones":bones,"vertices":vertices}

func load_file(owner_world,path:String)->Dictionary:
	world=owner_world
	var result=preflight(path)
	if not result.ok:return result
	is_fish=FileAccess.get_sha256(path)==preload("res://scripts/fixed_cast.gd").MODEL_HASH
	var document=GLTFDocument.new();var state=GLTFState.new()
	if document.append_from_buffer(result.bytes,"",state)!=OK:return {"ok":false,"error":"原生引擎无法读取这个模型"}
	scene=document.generate_scene(state)
	if scene==null:return {"ok":false,"error":"无法生成模型"}
	add_child(scene)
	var skeletons=scene.find_children("*","Skeleton3D",true,false)
	if skeletons.size()!=1:return {"ok":false,"error":"暂不支持这个模型的骨架结构"}
	skeleton=skeletons[0]
	if skeleton.get_bone_count()>256:return {"ok":false,"error":"模型骨骼过多"}
	for name in result.bones:
		var source_name=str(state.get_nodes()[result.bones[name]].original_name)
		var index=skeleton.find_bone(source_name)
		if index<0:index=skeleton.find_bone(source_name.replace(":","_").replace("/","_"))
		if index>=0:humanoid[name]=index;semantics[index]=name
	for name in REQUIRED:
		if not humanoid.has(name):return {"ok":false,"error":"无法对应人形骨骼："+name}
	for i in skeleton.get_bone_count():
		local_rest.append(skeleton.get_bone_rest(i));global_rest.append(skeleton.get_bone_global_rest(i));poses.append(skeleton.get_bone_global_rest(i))
		if str(skeleton.get_bone_name(i)).begins_with("WeiBa"):tail_bones.append(i)
	native_to_game=Basis(Vector3.UP,PI) if result.version=="1" else Basis.IDENTITY
	basis=native_to_game
	meshes=scene.find_children("*","MeshInstance3D",true,false)
	var box=AABB();var found=false
	for mesh in meshes:
		var mesh_box=scene.global_transform.affine_inverse()*mesh.global_transform*mesh.get_aabb()
		box=box.merge(mesh_box) if found else mesh_box;found=true
	if not found or box.size.y<.05 or box.size.y>20:return {"ok":false,"error":"人物尺寸不合理"}
	unit_scale=HEIGHT/box.size.y
	scale=Vector3.ONE*unit_scale/IslandWorker.ACTOR_SCALE
	scene.position.y-=box.position.y
	clearance=clampf(box.size.x*unit_scale*.5+.035,.30,.65)
	var thigh:Vector3=global_rest[humanoid.leftUpperLeg].origin;var knee:Vector3=global_rest[humanoid.leftLowerLeg].origin;var ankle:Vector3=global_rest[humanoid.leftFoot].origin
	gait_ratio=clampf((thigh.distance_to(knee)+knee.distance_to(ankle))*unit_scale/(.75*IslandWorker.ACTOR_SCALE),.30,1.2)
	for side in ["left","right"]:
		var upper:int=humanoid[side+"UpperArm"];var lower:int=humanoid[side+"LowerArm"]
		var direction:Vector3=(global_rest[lower].origin-global_rest[upper].origin).normalized()
		var target=native_to_game.inverse()*Vector3(-.16 if side=="left" else .16,-1,-.035).normalized()
		down[side]=Basis(Quaternion(direction,target))
	prepare_materials();prepare_probes();prepare_blink(result.json,state)
	if foot_probes.is_empty() or support_probes.is_empty():return {"ok":false,"error":"模型缺少可适配的脚部蒙皮"}
	update_pose(true)
	var extent=0.0
	for probe in support_probes:
		var p=scene.global_transform.affine_inverse()*probe_point(probe);p=native_to_game*p*unit_scale
		extent=maxf(extent,Vector2(p.x,p.z).length())
	clearance=maxf(clearance,extent+.035)
	if clearance>.85:return {"ok":false,"error":"这个人物的尾巴或附件太宽，暂时无法安全通过工地"}
	info={"ok":true,"error":"","title":result.title,"author":result.author,"version":result.version,"height":HEIGHT,"vertices":result.vertices,"bones":skeleton.get_bone_count()}
	return info.duplicate()

func prepare_materials():
	var texture_cache={}
	for mesh in meshes:
		for surface in mesh.mesh.get_surface_count():
			var source=mesh.get_active_material(surface)
			if not source is StandardMaterial3D:continue
			var material=source.duplicate()
			# This avatar is authored unlit; preserve its colors and opaque hair/clothes.
			if material.emission_energy_multiplier<=.0001:material.emission_enabled=false
			var texture=material.albedo_texture
			if texture and not str(mesh.name).begins_with("head") and max(texture.get_width(),texture.get_height())>1024:
				var key=texture.get_instance_id()
				if not texture_cache.has(key):
					var img=texture.get_image();var ratio=1024.0/max(img.get_width(),img.get_height())
					if img.is_compressed():img.decompress()
					img.resize(maxi(1,roundi(img.get_width()*ratio)),maxi(1,roundi(img.get_height()*ratio)),Image.INTERPOLATE_LANCZOS);img.generate_mipmaps()
					texture_cache[key]=ImageTexture.create_from_image(img)
				material.albedo_texture=texture_cache[key]
			# Replace the mesh material as well, so its old 2K texture can be released.
			mesh.mesh.surface_set_material(surface,material);mesh.set_surface_override_material(surface,material)

func prepare_probes():
	var profile={}
	var profile_path="res://assets/characters/contact_points.json"
	if is_fish and FileAccess.file_exists(profile_path):
		var data=JSON.parse_string(FileAccess.get_file_as_string(profile_path))
		if data is Dictionary and data.get("hash","")==preload("res://scripts/fixed_cast.gd").MODEL_HASH:
			profile=data.get("surfaces",{})
	for mesh in meshes:
		if mesh.skin==null:continue
		var binds=[]
		for i in mesh.skin.get_bind_count():
			var bone=skeleton.find_bone(mesh.skin.get_bind_name(i)) if not mesh.skin.get_bind_name(i).is_empty() else mesh.skin.get_bind_bone(i)
			binds.append({"bone":bone,"pose":mesh.skin.get_bind_pose(i)})
		for surface in mesh.mesh.get_surface_count():
			var arrays=mesh.mesh.surface_get_arrays(surface)
			var key=str(mesh.name)+"/"+str(surface)
			var saved=profile.get(key,{})
			if saved.get("vertices",-1)==arrays[Mesh.ARRAY_VERTEX].size() and saved.get("points") is Array:
				add_contacts(arrays,binds,saved.points)
				used_baked_surfaces+=1
				continue
			var chosen={}
			for i in arrays[Mesh.ARRAY_VERTEX].size():
				var v:Vector3=arrays[Mesh.ARRAY_VERTEX][i];var dominant=-1;var weight=0.0
				for j in range(4):
					if arrays[Mesh.ARRAY_WEIGHTS][i*4+j]>weight:weight=arrays[Mesh.ARRAY_WEIGHTS][i*4+j];dominant=binds[arrays[Mesh.ARRAY_BONES][i*4+j]].bone
				var group=dominant
				while group>=0:
					var semantic=str(semantics.get(group,""))
					if not semantic.is_empty() and not ("Thumb" in semantic or "Index" in semantic or "Middle" in semantic or "Ring" in semantic or "Little" in semantic):break
					group=skeleton.get_bone_parent(group)
				for axis in range(14):
					var direction=Vector3.ZERO
					if axis<6:direction[axis/2]=1 if axis%2==0 else -1
					else:direction=Vector3(1 if (axis-6)&1 else -1,1 if (axis-6)&2 else -1,1 if (axis-6)&4 else -1).normalized()
					var score=v.dot(direction);var direction_key=group*14+axis
					if not chosen.has(direction_key) or score<chosen[direction_key].score:chosen[direction_key]={"index":i,"score":score,"group":group,"axis":axis}
			var unique={}
			for chosen_point in chosen.values():
				var name_hint=str(semantics.get(chosen_point.group,""))
				var is_foot=chosen_point.axis<6 and (name_hint.ends_with("Foot") or name_hint.ends_with("Toes"))
				unique[chosen_point.index]=is_foot or unique.get(chosen_point.index,false)
			var points=[]
			for index in unique:points.append(int(index)*2+int(unique[index]))
			baked_surfaces[key]={"vertices":arrays[Mesh.ARRAY_VERTEX].size(),"points":points}
			add_contacts(arrays,binds,points)

func add_contacts(arrays:Array,binds:Array,points:Array):
	for encoded in points:
		var index=int(encoded)/2
		if index<0 or index>=arrays[Mesh.ARRAY_VERTEX].size():continue
		var weights=[]
		for j in range(4):
			var weight=arrays[Mesh.ARRAY_WEIGHTS][index*4+j]
			if weight>0:weights.append({"bind":binds[arrays[Mesh.ARRAY_BONES][index*4+j]],"weight":weight})
		var probe={"position":arrays[Mesh.ARRAY_VERTEX][index],"weights":weights}
		support_probes.append(probe)
		if int(encoded)%2==1:foot_probes.append(probe)

func prepare_blink(json:Dictionary,state:GLTFState):
	var ext=json.extensions;var bindings=[]
	if ext.has("VRMC_vrm"):
		var expressions=ext.VRMC_vrm.get("expressions",{});var preset=expressions.get("preset",{}) if expressions is Dictionary else {};var blink=preset.get("blink",{}) if preset is Dictionary else {};var targets=blink.get("morphTargetBinds",[]) if blink is Dictionary else []
		if not targets is Array:targets=[]
		for bind in targets:
			if not bind is Dictionary or not (bind.get("node") is int or bind.get("node") is float) or not (bind.get("index") is int or bind.get("index") is float) or not (bind.get("weight") is int or bind.get("weight") is float):continue
			if int(bind.node)<0 or int(bind.node)>=state.get_nodes().size():continue
			var node=state.get_scene_node(int(bind.node))
			if node is MeshInstance3D:bindings.append({"mesh":node,"index":int(bind.index),"weight":float(bind.weight)})
	for binding in bindings:
		if binding.index>=0 and binding.index<binding.mesh.mesh.get_blend_shape_count():blink_bindings.append(binding)
	if blink_bindings.is_empty():
		for mesh in meshes:
			for i in mesh.mesh.get_blend_shape_count():
				if str(mesh.mesh.get_blend_shape_name(i)).to_lower()=="blink":blink_bindings.append({"mesh":mesh,"index":i,"weight":1.0})

func canonical(rotation:Basis)->Basis:return native_to_game.inverse()*rotation*native_to_game
func update_pose(neutral=false):
	if (not enabled and not neutral) or not is_instance_valid(skeleton) or world.worker==null:return
	position=Vector3.ZERO
	var body=Basis.IDENTITY if neutral else Basis.from_euler(world.limbs.Body.rotation);var head=Basis.from_euler(world.worker.head_pivot.rotation) if not neutral and world.worker.head_pivot else Basis.IDENTITY
	var napping=not neutral and world.worker.work_left<=0 and world.worker.rest_variant==1 and world.worker.waking<=0
	if napping:head=Basis.from_euler(Vector3(.14,0,.035))
	var rotations={humanoid.spine:canonical(Basis.IDENTITY.slerp(body,.55)),humanoid.head:canonical(body*head)}
	for part in ["chest","upperChest","neck"]:
		if humanoid.has(part):rotations[humanoid[part]]=canonical(body)
	for side in ["left","right"]:
		var suffix="L" if side=="left" else "R"
		var arm=Basis.IDENTITY if neutral else Basis.from_euler(world.limbs["Arm"+suffix].rotation);var elbow=Basis.IDENTITY if neutral else Basis.from_euler(world.limbs["Elbow"+suffix].rotation)
		rotations[humanoid[side+"UpperArm"]]=canonical(body*arm)*down[side]
		rotations[humanoid[side+"LowerArm"]]=canonical(body*arm*elbow)*down[side]
		var leg=Basis.IDENTITY if neutral else Basis.from_euler(world.limbs["Leg"+suffix].rotation);var knee=Basis.IDENTITY if neutral else Basis.from_euler(world.limbs["Knee"+suffix].rotation)
		rotations[humanoid[side+"UpperLeg"]]=canonical(leg)
		rotations[humanoid[side+"LowerLeg"]]=canonical(leg*knee)
	for i in skeleton.get_bone_count():
		var parent=skeleton.get_bone_parent(i);var pose:Transform3D=local_rest[i] if parent<0 else poses[parent]*local_rest[i]
		if rotations.has(i):pose.basis=rotations[i]*global_rest[i].basis
		if i in tail_bones:
			var n=str(skeleton.get_bone_name(i))
			var effort=clampf(world.motion_speed,0,1) if not neutral else 0.0
			var wave=sin(world.time*1.7-i*.22)*(.012 if napping else .035+.025*effort)
			# The long tail curls upward so it does not drag through ground or walls.
			if n=="WeiBa":pose.basis=canonical(Basis(Vector3.RIGHT,-.92))*pose.basis
			else:pose.basis=pose.basis*Basis(Vector3.FORWARD,wave)
		poses[i]=pose;skeleton.set_bone_global_pose_override(i,pose,1.0,true)
	skeleton.force_update_all_bone_transforms()
	if neutral:return
	var worker=world.worker;var resting=worker.work_left<=0 and worker.waking<=0 and not (world.move_tween and world.move_tween.is_running())
	var key=str(worker.rest_variant)+str(world.builder.position.snapped(Vector3.ONE*.001))+str(world.land.size())
	if not resting or rest_key!=key or worker.rest_time<.95:rest_cached=false
	if resting and rest_cached:ground_offset-=world.actor.position.y-rest_actor_height
	else:
		var lowest=INF
		for probe in (support_probes if resting else foot_probes):
			var p=probe_point(probe)
			var local=world.globe.to_local(p);var ground=world.ground_point(world.terrain.coordinates(local));var gap=world.builder.to_local(p).y if world.transporting else (local-ground).dot(world.builder.basis.y)
			lowest=minf(lowest,gap)
		if is_finite(lowest):ground_offset=(.022 if resting else .012)-lowest
		rest_cached=resting and worker.rest_time>=.95;rest_key=key
	rest_actor_height=world.actor.position.y
	global_position+=world.builder.global_basis.y.normalized()*ground_offset
	var blink_time=fmod(world.time+1.7,4.6);var blink=sin(blink_time/.18*PI) if blink_time<.18 else 0.0
	if napping:blink=.94
	for binding in blink_bindings:binding.mesh.set_blend_shape_value(binding.index,blink*binding.weight)
	var hand=hand_point("right")
	for tool in world.tools.values():tool.global_position=hand
	if worker.carry.visible:
		worker.carry.global_position=(hand+hand_point("left"))*.5-worker.carry.global_basis*Vector3(0,.29,-.42)

func probe_point(probe:Dictionary)->Vector3:
	var point=Vector3.ZERO
	for weight in probe.weights:
		if weight.bind.bone>=0:point+=(poses[weight.bind.bone]*weight.bind.pose*probe.position)*weight.weight
	return skeleton.to_global(point)
func hand_point(side:String)->Vector3:
	var pose:Transform3D=poses[humanoid[side+"Hand"]]
	return skeleton.to_global(pose.origin+pose.basis.y.normalized()*.025)
