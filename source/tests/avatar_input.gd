extends SceneTree
const Avatar=preload("res://scripts/avatar.gd")
var passed=0
var failed=0
func check(value,label):
	if value:passed+=1;print("PASS ",label)
	else:failed+=1;push_error("FAIL "+label)
func fixture(json:Dictionary)->Dictionary:
	var text=JSON.stringify(json);while text.to_utf8_buffer().size()%4!=0:text+=" "
	var bytes=text.to_utf8_buffer();var path="user://avatar-preflight-qa.glb";var f=FileAccess.open(path,FileAccess.WRITE)
	for value in [0x46546C67,2,20+bytes.size(),bytes.size(),0x4E4F534A]:f.store_32(value)
	f.store_buffer(bytes);f.close();var result=Avatar.preflight(path);DirAccess.remove_absolute(path);return result
func _initialize():call_deferred("run")
func run():
	if not "--qa" in OS.get_cmdline_user_args():push_error("QA_REQUIRED: avatar input checks require --qa");quit(2);return
	var bones={};var nodes=[]
	for name in Avatar.REQUIRED:bones[name]={"node":nodes.size()};nodes.append({"name":name})
	var base={"asset":{"version":"2.0"},"nodes":nodes,"accessors":[{"count":3}],"meshes":[{"primitives":[{"attributes":{"POSITION":0}}]}],"extensions":{"VRMC_vrm":{"humanoid":{"humanBones":bones},"meta":{"name":"QA","authors":["test"]}}}}
	check(fixture(base).ok,"VRM 1 humanoid metadata is recognised")
	var old=base.duplicate(true);old.extensions={"VRM":{"humanoid":{"humanBones":[]},"meta":{"title":"QA0","author":"test"}}}
	for name in bones:old.extensions.VRM.humanoid.humanBones.append({"bone":name,"node":bones[name].node})
	check(fixture(old).ok and fixture(old).version=="0","VRM 0 standard humanoid mapping is recognised")
	for section in ["extensions","nodes","images","meshes"]:
		var bad=base.duplicate(true);bad[section]=[3] if section!="extensions" else []
		check(not fixture(bad).ok,"malformed "+section+" fails without a script exception")
	var outside=base.duplicate(true);outside.images=[{"uri":"../../private.png"}]
	check(not fixture(outside).ok,"external file resources are rejected before GLTF loading")
	outside.images=[{"uri":"https://example.com/image.png"}]
	check(not fixture(outside).ok,"remote image resources are rejected before GLTF loading")
	var missing=base.duplicate(true);missing.extensions.VRMC_vrm.humanoid.humanBones.erase("leftFoot")
	check(not fixture(missing).ok,"missing required feet are rejected")
	var excessive=base.duplicate(true);excessive.accessors[0].count=900000
	check(not fixture(excessive).ok,"oversized geometry is rejected")
	var strange=base.duplicate(true);strange.extensions.VRMC_vrm.meta.authors="one author"
	check(fixture(strange).ok and fixture(strange).author=="one author","a scalar author field does not interrupt import")
	print("AVATAR_INPUT_RESULT ",passed," passed / ",failed," failed");quit(0 if failed==0 else 1)
