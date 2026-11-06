extends RefCounted

# Device-local derived data. Never package generated caches or replace the VRM.
# Bump FORMAT when import/material preparation changes; animation stays in scripts.
const FORMAT=1
const SCENE="prepared-character.scn"
const MANIFEST="prepared-character.json"
const MAX_CACHE_BYTES=64*1024*1024

static func engine_key()->String:
	return str(Engine.get_version_info().get("hash",""))+"/"+OS.get_name()

static func read(folder:String,model_hash:String)->Node3D:
	if folder.is_empty():return null
	var manifest_path=folder.path_join(MANIFEST)
	var scene_path=folder.path_join(SCENE)
	if not FileAccess.file_exists(manifest_path) or not FileAccess.file_exists(scene_path):return null
	var file=FileAccess.open(manifest_path,FileAccess.READ)
	if file==null or file.get_length()>4096:return null
	var meta=JSON.parse_string(file.get_as_text());file.close()
	if not meta is Dictionary or meta.get("format",0)!=FORMAT or meta.get("model","")!=model_hash or meta.get("engine","")!=engine_key():return null
	file=FileAccess.open(scene_path,FileAccess.READ)
	if file==null:return null
	var size=file.get_length();file.close()
	if size<64 or size>MAX_CACHE_BYTES or size!=meta.get("bytes",0):return null
	if FileAccess.get_sha256(scene_path)!=meta.get("sha256",""):return null
	var packed=ResourceLoader.load(scene_path,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	if not packed is PackedScene:return null
	var scene=packed.instantiate()
	if not scene is Node3D or not scene.get_meta("arword_import",{}) is Dictionary:
		if is_instance_valid(scene):scene.free()
		return null
	var info:Dictionary=scene.get_meta("arword_import",{})
	if not info.has_all(["title","author","version","vertices","json","bone_names","expression_paths"]):scene.free();return null
	if not info.json is Dictionary or not info.bone_names is Dictionary or not info.expression_paths is Dictionary:scene.free();return null
	return scene

static func write(folder:String,model_hash:String,packed:PackedScene)->bool:
	if folder.is_empty() or packed==null or DirAccess.make_dir_recursive_absolute(folder)!=OK:return false
	var path=folder.path_join(SCENE)
	var staged=folder.path_join("prepared-character.part.scn")
	var meta_path=folder.path_join(MANIFEST)
	if ResourceSaver.save(packed,staged,ResourceSaver.FLAG_BUNDLE_RESOURCES|ResourceSaver.FLAG_COMPRESS)!=OK:return false
	var file=FileAccess.open(staged,FileAccess.READ)
	if file==null:return false
	var size=file.get_length();file.close()
	if size<64 or size>MAX_CACHE_BYTES:DirAccess.remove_absolute(staged);return false
	var meta={"format":FORMAT,"model":model_hash,"engine":engine_key(),"bytes":size,"sha256":FileAccess.get_sha256(staged)}
	file=FileAccess.open(meta_path+".part",FileAccess.WRITE)
	if file==null:DirAccess.remove_absolute(staged);return false
	file.store_string(JSON.stringify(meta));file.flush();file.close()
	# A crash between these replacements only invalidates derived data. The VRM stays intact.
	if FileAccess.file_exists(path) and DirAccess.remove_absolute(path)!=OK:return false
	if DirAccess.rename_absolute(staged,path)!=OK:return false
	if FileAccess.file_exists(meta_path) and DirAccess.remove_absolute(meta_path)!=OK:return false
	return DirAccess.rename_absolute(meta_path+".part",meta_path)==OK
