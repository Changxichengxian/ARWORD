extends RefCounted

# The personal installation seeds this exact character once. Public updates use the
# existing private copy. No arbitrary files, URLs or character packs are accepted.
const MODEL_HASH="c14879ff5c42501043896aae03ce971b2c11eee2e76106d47ee98741aa842ff5"
const MODEL_SIZE=18480432
const BUILTIN="res://assets/characters/deepseek.vrm"
var folder:String
var model_path=""
var saved_for_update=false

func _init(directory:String):
	folder=directory

static func approved_model(path:String)->bool:
	if path.is_empty() or not FileAccess.file_exists(path):return false
	var file=FileAccess.open(path,FileAccess.READ)
	if file==null or file.get_length()!=MODEL_SIZE:return false
	file.close()
	return FileAccess.get_sha256(path)==MODEL_HASH

func prepare(bundled:String=BUILTIN,legacy:String=""):
	var cache=folder.path_join("deepseek.vrm")
	model_path=""
	saved_for_update=approved_model(cache)
	if saved_for_update:
		model_path=cache
		return
	for candidate in [bundled,legacy]:
		if approved_model(candidate):
			model_path=candidate
			break
	if model_path.is_empty() or DirAccess.make_dir_recursive_absolute(folder)!=OK:return
	var source_file=FileAccess.open(model_path,FileAccess.READ)
	var staged=cache+".part"
	var destination=FileAccess.open(staged,FileAccess.WRITE)
	if source_file==null or destination==null:return
	while source_file.get_position()<MODEL_SIZE:
		var bytes=source_file.get_buffer(mini(262144,MODEL_SIZE-source_file.get_position()))
		if bytes.is_empty():break
		destination.store_buffer(bytes)
		if destination.get_error()!=OK:break
	destination.close()
	source_file.close()
	if not approved_model(staged):
		DirAccess.remove_absolute(staged)
		return
	if FileAccess.file_exists(cache):DirAccess.remove_absolute(cache)
	if DirAccess.rename_absolute(staged,cache)==OK:
		model_path=cache
		saved_for_update=true

func preferred()->String:
	# Old choice files may still select the retired white placeholder. The
	# approved character is now the sole visible choice; never revive that mesh.
	return "" if model_path.is_empty() else "deepseek"

func remember(id:String)->bool:
	if id!="deepseek" or model_path.is_empty():return false
	if DirAccess.make_dir_recursive_absolute(folder)!=OK:return false
	var cfg=ConfigFile.new()
	cfg.set_value("cast","id",id)
	var path=folder.path_join("choice.cfg")
	if cfg.save(path+".part")!=OK:return false
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(path+".bak"):DirAccess.remove_absolute(path+".bak")
		if DirAccess.rename_absolute(path,path+".bak")!=OK:return false
	if DirAccess.rename_absolute(path+".part",path)==OK:return true
	if FileAccess.file_exists(path+".bak"):DirAccess.rename_absolute(path+".bak",path)
	return false
