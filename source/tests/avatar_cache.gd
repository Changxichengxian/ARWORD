extends SceneTree
const Avatar=preload("res://scripts/avatar.gd")
const Cache=preload("res://scripts/avatar_cache.gd")
const ExpressionTest=preload("res://tests/avatar_expression.gd")
var passed=0
var failed=0
func check(value:bool,label:String):
	if value:passed+=1;print("PASS ",label)
	else:failed+=1;push_error("FAIL "+label)
func _initialize():
	if not "--qa" in OS.get_cmdline_user_args():quit(2);return
	call_deferred("run")
func digest(bytes:PackedByteArray)->String:
	var hash=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(bytes)
	return hash.finish().hex_encode()
func snapshot(avatar)->Dictionary:
	var result={"info":avatar.info,"humanoid":avatar.humanoid,"scale":avatar.scale,"transform":avatar.scene.transform,"clearance":avatar.clearance,"gait":avatar.gait_ratio,"feet":avatar.foot_probes,"support":avatar.support_probes,"meshes":[],"bones":[],"expressions":{}}
	for i in avatar.skeleton.get_bone_count():result.bones.append([avatar.skeleton.get_bone_name(i),avatar.skeleton.get_bone_rest(i),avatar.skeleton.get_bone_pose(i)])
	for mesh in avatar.meshes:
		var data=[str(mesh.name),mesh.transform,mesh.skeleton,[],[],[]]
		for i in mesh.mesh.get_surface_count():
			var material=mesh.get_active_material(i);var texture=material.albedo_texture
			data[3].append([mesh.mesh.surface_get_arrays(i),material.albedo_color,material.shading_mode,material.transparency,material.emission_enabled,digest(texture.get_image().get_data()) if texture else ""])
		for i in mesh.mesh.get_blend_shape_count():data[4].append([mesh.mesh.get_blend_shape_name(i),mesh.get_blend_shape_value(i)])
		if mesh.skin:
			for i in mesh.skin.get_bind_count():data[5].append([mesh.skin.get_bind_name(i),mesh.skin.get_bind_bone(i),mesh.skin.get_bind_pose(i)])
		result.meshes.append(data)
	for name in avatar.expression_bindings:
		result.expressions[name]=[]
		for bind in avatar.expression_bindings[name]:result.expressions[name].append([str(bind.mesh.name),bind.index,bind.weight])
	return result
func run():
	var path="res://assets/characters/deepseek.vrm"
	if not FileAccess.file_exists(path):print("SKIP private model unavailable");quit();return
	var original=FileAccess.get_sha256(path)
	var folder="user://qa-characters/cache-test-"+str(Time.get_ticks_usec())
	var world=ExpressionTest.ExpressionWorld.new()
	var cold=Avatar.new();root.add_child(cold)
	check(cold.load_file(world,path,folder).get("ok",false) and not cold.used_prepared_cache,"first load imports the verified model")
	check(FileAccess.file_exists(folder.path_join(Cache.SCENE)),"first load saves a device-local prepared scene")
	var warm=Avatar.new();root.add_child(warm)
	check(warm.load_file(world,path,folder).get("ok",false) and warm.used_prepared_cache,"repeat load uses the prepared scene")
	var before=snapshot(cold);var after=snapshot(warm)
	for key in before:check(var_to_bytes(before[key])==var_to_bytes(after[key]),"cached and imported "+key+" match exactly")
	world.worker.expression={"effort":.9,"focus":.6,"sleep":.3,"look":Vector2(.4,-.6)}
	cold.apply_expression(world.worker.expression,8.25);warm.apply_expression(world.worker.expression,8.25)
	check(var_to_bytes(snapshot(cold).meshes)==var_to_bytes(snapshot(warm).meshes),"cached character preserves the applied facial expression")
	var manifest_path=folder.path_join(Cache.MANIFEST)
	var manifest=FileAccess.get_file_as_string(manifest_path)
	var invalid=JSON.parse_string(manifest);invalid.format=-1
	var file=FileAccess.open(manifest_path,FileAccess.WRITE);file.store_string(JSON.stringify(invalid));file.close()
	check(Cache.read(folder,original)==null,"an old cache format is rejected")
	file=FileAccess.open(manifest_path,FileAccess.WRITE);file.store_string(manifest);file.close()
	file=FileAccess.open(folder.path_join(Cache.SCENE),FileAccess.READ_WRITE);file.seek(32);file.store_8(file.get_8()^0xff);file.close()
	check(Cache.read(folder,original)==null,"corrupt cached bytes are rejected before loading")
	var recovered=Avatar.new();root.add_child(recovered)
	check(recovered.load_file(world,path,folder).get("ok",false) and not recovered.used_prepared_cache,"a corrupt cache rebuilds from the original model")
	var missing=Avatar.new();root.add_child(missing)
	check(not missing.load_file(world,"user://qa-characters/missing.vrm",folder).get("ok",false),"a prepared cache cannot replace a missing original model")
	check(FileAccess.get_sha256(path)==original,"the private original model stays byte-identical")
	cold.free();warm.free();recovered.free();missing.free()
	print("AVATAR_CACHE_RESULT ",passed," passed / ",failed," failed")
	quit.call_deferred(0 if failed==0 else 1)
