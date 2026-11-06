extends Node3D
class_name IslandAvatar

# Fixed character rig. The model bytes are supplied with the personal installation.
const MAX_BYTES=64*1024*1024
const HEIGHT=1.085
const REQUIRED=["hips","spine","head","leftUpperArm","leftLowerArm","leftHand","rightUpperArm","rightLowerArm","rightHand","leftUpperLeg","leftLowerLeg","leftFoot","rightUpperLeg","rightLowerLeg","rightFoot"]
const FACE_EXPRESSIONS=["blink","blinkLeft","blinkRight","lookUp","lookDown","lookLeft","lookRight","ih","happy","angry","relaxed"]
const FACE_FOCUS=.10
const FACE_EFFORT=.18
const FACE_MOUTH=.07
const FACE_HAPPY=.08
const FACE_RELAX=.18
const FACE_LOOK=.22
const PreparedCache=preload("res://scripts/avatar_cache.gd")
var used_prepared_cache=false
var expression_paths:Dictionary={}
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
var expression_bindings:Dictionary={}
var expression_targets:Array=[]
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

func load_file(owner_world,path:String,cache_folder:String="")->Dictionary:
	world=owner_world
	var model_hash=FileAccess.get_sha256(path) if FileAccess.file_exists(path) else ""
	is_fish=model_hash==preload("res://scripts/fixed_cast.gd").MODEL_HASH
	if not is_fish:cache_folder=""
	scene=PreparedCache.read(cache_folder,model_hash)
	used_prepared_cache=scene!=null
	var result:Dictionary={};var state:GLTFState;var bone_names:Dictionary={}
	if used_prepared_cache:
		result=scene.get_meta("arword_import").duplicate(true)
		bone_names=result.bone_names;expression_paths=result.expression_paths
	else:
		result=preflight(path)
		if not result.ok:return result
		var document=GLTFDocument.new();state=GLTFState.new()
		if document.append_from_buffer(result.bytes,"",state)!=OK:return {"ok":false,"error":"原生引擎无法读取这个模型"}
		scene=document.generate_scene(state)
		for name in result.bones:bone_names[name]=str(state.get_nodes()[result.bones[name]].original_name)
	if scene==null:return {"ok":false,"error":"无法生成模型"}
	var imported_transform=scene.transform
	add_child(scene)
	var skeletons=scene.find_children("*","Skeleton3D",true,false)
	if skeletons.size()!=1:return {"ok":false,"error":"暂不支持这个模型的骨架结构"}
	skeleton=skeletons[0]
	if skeleton.get_bone_count()>256:return {"ok":false,"error":"模型骨骼过多"}
	for name in bone_names:
		var source_name=str(bone_names[name])
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
	if not used_prepared_cache:prepare_materials()
	prepare_probes();prepare_blink(result.json,state)
	if foot_probes.is_empty() or support_probes.is_empty():return {"ok":false,"error":"模型缺少可适配的脚部蒙皮"}
	# Capture the imported rest pose, before the animation driver changes bones.
	var packed:PackedScene
	if not used_prepared_cache and not cache_folder.is_empty():
		scene.set_meta("arword_import",{"title":result.title,"author":result.author,"version":result.version,"vertices":result.vertices,"json":result.json,"bone_names":bone_names,"expression_paths":expression_paths})
		var placed_transform=scene.transform;scene.transform=imported_transform
		packed=PackedScene.new()
		if packed.pack(scene)!=OK:packed=null
		scene.transform=placed_transform
	update_pose(true)
	var extent=0.0
	for probe in support_probes:
		var p=scene.global_transform.affine_inverse()*probe_point(probe);p=native_to_game*p*unit_scale
		extent=maxf(extent,Vector2(p.x,p.z).length())
	clearance=maxf(clearance,extent+.035)
	if clearance>.85:return {"ok":false,"error":"这个人物的尾巴或附件太宽，暂时无法安全通过工地"}
	info={"ok":true,"error":"","title":result.title,"author":result.author,"version":result.version,"height":HEIGHT,"vertices":result.vertices,"bones":skeleton.get_bone_count()}
	if packed!=null:PreparedCache.write(cache_folder,model_hash,packed)
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
	# Resolve only known facial expressions once. Clothing morphs (such as TiePen)
	# and the original model bytes are never changed by the expression driver.
	blink_bindings.clear();expression_bindings.clear();expression_targets.clear()
	if state!=null:
		# GLTF's forward map may reference replaced ImporterMeshInstance nodes.
		# Resolve from live nodes instead, and persist only relative scene paths.
		var named={}
		for mesh in meshes:
			var mesh_name=str(mesh.name)
			named[mesh_name]=null if named.has(mesh_name) else mesh
			var index=state.get_node_index(mesh)
			if index>=0:expression_paths[str(index)]=scene.get_path_to(mesh)
		var nodes=state.get_nodes()
		for index in nodes.size():
			if expression_paths.has(str(index)):continue
			var mesh_name=str(nodes[index].original_name).validate_node_name()
			var node=named.get(mesh_name)
			if is_instance_valid(node):expression_paths[str(index)]=scene.get_path_to(node)
	var ext=json.get("extensions",{});var vrm=ext.get("VRMC_vrm",{}) if ext is Dictionary else {}
	var expressions=vrm.get("expressions",{}) if vrm is Dictionary else {}
	var preset=expressions.get("preset",{}) if expressions is Dictionary else {}
	for name in FACE_EXPRESSIONS:
		expression_bindings[name]=[]
		var expression=preset.get(name,{}) if preset is Dictionary else {}
		var targets=expression.get("morphTargetBinds",[]) if expression is Dictionary else []
		if not targets is Array:continue
		for bind in targets:
			if not bind is Dictionary:continue
			var valid=true
			for key in ["node","index","weight"]:
				var value=bind.get(key)
				if not (value is int or value is float) or not is_finite(float(value)):valid=false;break
			if not valid or float(bind.node)!=float(int(bind.node)) or float(bind.index)!=float(int(bind.index)) or int(bind.node)<0 or int(bind.node)>=json.get("nodes",[]).size():continue
			var node_path=expression_paths.get(str(int(bind.node)),NodePath())
			if node_path.is_empty():continue
			var node=scene.get_node_or_null(node_path)
			if not is_instance_valid(node):continue
			add_expression_binding(name,node,int(bind.index),float(bind.weight))
	# Older models may only expose blend-shape names. Keep their blink support.
	for name in FACE_EXPRESSIONS:
		if not expression_bindings[name].is_empty():continue
		for mesh in meshes:
			if not is_instance_valid(mesh):continue
			if not mesh is MeshInstance3D or not is_instance_valid(mesh.mesh):continue
			for i in mini(mesh.mesh.get_blend_shape_count(),mesh.get_blend_shape_count()):
				if str(mesh.mesh.get_blend_shape_name(i)).to_lower()==name.to_lower():add_expression_binding(name,mesh,i,1.0)
	blink_bindings.append_array(expression_bindings.blink)
	if blink_bindings.is_empty():
		blink_bindings.append_array(expression_bindings.blinkLeft);blink_bindings.append_array(expression_bindings.blinkRight)
	# Several expressions can share a shape. Sum them before writing it once.
	var by_target={}
	for name in FACE_EXPRESSIONS:
		for binding in expression_bindings[name]:
			if not valid_expression_target(binding.mesh,binding.index):continue
			var key=str(binding.mesh.get_instance_id())+":"+str(binding.index)
			if not by_target.has(key):
				var target={"mesh":binding.mesh,"index":binding.index,"weights":{}}
				by_target[key]=target;expression_targets.append(target)
			by_target[key].weights[name]=binding.weight

func valid_expression_target(node,index:int)->bool:
	# GLTF may retain a scene-node reference after replacing a generated node.
	# A freed reference must be rejected before even using the type operator.
	if not is_instance_valid(node):return false
	if not node is MeshInstance3D or not is_instance_valid(node.mesh):return false
	return index>=0 and index<node.mesh.get_blend_shape_count() and index<node.get_blend_shape_count()

func add_expression_binding(name:String,node,index:int,weight:float):
	if not valid_expression_target(node,index) or not is_finite(weight) or weight<=0 or not expression_bindings.has(name):return
	for binding in expression_bindings[name]:
		if binding.mesh==node and binding.index==index:return
	expression_bindings[name].append({"mesh":node,"index":index,"weight":clampf(weight,0,1)})

static func expression_amount(state:Dictionary,key:String)->float:
	var value=state.get(key,0.0)
	return clampf(float(value),0,1) if (value is int or value is float) and is_finite(float(value)) else 0.0

static func blink_pulse(t:float)->float:
	if t<0 or t>.22:return 0.0
	return smoothstep(0,.065,t) if t<.065 else 1.0-smoothstep(.065,.22,t)

static func natural_blink(now:float)->float:
	# Pure time sampling: settling the feet can evaluate the same pose twice.
	# Neither that nor the frame rate should advance a blink or consume randomness.
	var time=maxf(0,now) if is_finite(now) else 0.0
	var cycle=floori(time/5.1);var phase=fmod(time,5.1)
	var seed=sin(float(cycle)*12.9898+4.71)*43758.5453
	var start=1.3+(seed-floor(seed))*2.3
	var blink=blink_pulse(phase-start)
	if cycle%7==4:blink=maxf(blink,blink_pulse(phase-start-.31)*.85)
	return blink

static func expression_values(state:Dictionary,now:float,neutral:bool=false)->Dictionary:
	var values={}
	for name in FACE_EXPRESSIONS:values[name]=0.0
	if neutral:return values
	var sleep=expression_amount(state,"sleep")
	var effort=expression_amount(state,"effort")*(1.0-sleep)
	var focus=expression_amount(state,"focus")*(1.0-sleep)
	var relax=expression_amount(state,"relax")*(1.0-sleep)*(1.0-effort*.75)
	# A small sustained squint follows strain; full blinks remain brief. It
	# relaxes with the load instead of switching the whole face at each step.
	values.blink=lerpf(maxf(natural_blink(now),effort*effort*.22),.94,sleep)
	values.blinkLeft=values.blink;values.blinkRight=values.blink
	values.angry=FACE_FOCUS*focus+FACE_EFFORT*effort
	values.ih=FACE_MOUTH*effort
	values.happy=FACE_HAPPY*relax
	values.relaxed=FACE_RELAX*(relax+sleep)
	var look=state.get("look",Vector2.ZERO)
	if look is Vector2 and look.is_finite():
		# Positive X looks to the character's right; positive Y looks up.
		var strength=FACE_LOOK*(1.0-sleep)
		values.lookRight=clampf(look.x,0,1)*strength;values.lookLeft=clampf(-look.x,0,1)*strength
		values.lookUp=clampf(look.y,0,1)*strength;values.lookDown=clampf(-look.y,0,1)*strength
	return values

func apply_expression(state:Dictionary,now:float,neutral:bool=false):
	var values=expression_values(state,now,neutral)
	# Combined and per-eye blink shapes usually deform the same vertices.
	if not expression_bindings.get("blink",[]).is_empty():values.blinkLeft=0.0;values.blinkRight=0.0
	for target in expression_targets:
		if not valid_expression_target(target.mesh,target.index):continue
		var value=0.0
		for name in target.weights:value+=values.get(name,0.0)*target.weights[name]
		target.mesh.set_blend_shape_value(target.index,clampf(value,0,1))

func canonical(rotation:Basis)->Basis:return native_to_game.inverse()*rotation*native_to_game
func update_pose(neutral=false):
	if (not enabled and not neutral) or not is_instance_valid(skeleton) or world.worker==null:return
	position=Vector3.ZERO
	var body=Basis.IDENTITY if neutral else Basis.from_euler(world.limbs.Body.rotation);var head=Basis.from_euler(world.worker.head_pivot.rotation) if not neutral and world.worker.head_pivot else Basis.IDENTITY
	var napping=not neutral and world.worker.work_left<=0 and world.worker.rest_variant==1 and world.worker.waking<=0
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
	var expression=world.worker.get("expression")
	apply_expression(expression if expression is Dictionary else {},world.time,neutral)
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
	var hand=hand_point("right")
	for tool in world.tools.values():tool.global_position=hand
	if worker.carry.visible:
		# Cradle the bottom of the bundle with both palms; its centre should not
		# occupy the hands. Keep it slightly toward the body so the grip reads.
		worker.carry.global_position=(hand+hand_point("left"))*.5-worker.carry.global_basis*Vector3(0,.16,-.46)

func probe_point(probe:Dictionary)->Vector3:
	var point=Vector3.ZERO
	for weight in probe.weights:
		if weight.bind.bone>=0:point+=(poses[weight.bind.bone]*weight.bind.pose*probe.position)*weight.weight
	return skeleton.to_global(point)
func hand_point(side:String)->Vector3:
	var pose:Transform3D=poses[humanoid[side+"Hand"]]
	return skeleton.to_global(pose.origin+pose.basis.y.normalized()*.025)
