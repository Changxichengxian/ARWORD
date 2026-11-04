extends RefCounted

# Only personal builds contain the approved, pre-rendered English recordings.
# The cached pack also works after updating to a public build.
const PACK_NAME="feiyu-cute-v1.arvoice"
const BUNDLED="res://assets/characters/"+PACK_NAME
var archive:ZIPReader

func prepare(folder:String,bundled:String=BUNDLED):
	var cache=folder.path_join(PACK_NAME)
	archive=open_cache(cache)
	if archive!=null or not FileAccess.file_exists(bundled):return
	if DirAccess.make_dir_recursive_absolute(folder)!=OK:return
	var temporary=cache+".part"
	if copy_recordings(bundled,temporary) and DirAccess.rename_absolute(temporary,cache)==OK:
		archive=open_cache(cache)
	if FileAccess.file_exists(temporary):DirAccess.remove_absolute(temporary)

func open_cache(path:String)->ZIPReader:
	if not FileAccess.file_exists(path):return null
	var pack=ZIPReader.new()
	if pack.open(ProjectSettings.globalize_path(path))!=OK:return null
	if pack.file_exists("index.json"):return pack
	pack.close()
	return null

func copy_recordings(bundled:String,path:String)->bool:
	# Android assets are streams inside the APK. Only open the ZIP on real storage.
	var source=FileAccess.open(bundled,FileAccess.READ)
	if source==null or source.get_length()==0:return false
	var output=FileAccess.open(path,FileAccess.WRITE)
	if output==null:return false
	var digest=HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	var remaining=source.get_length()
	while remaining>0:
		var bytes=source.get_buffer(mini(262144,remaining))
		if bytes.is_empty():return false
		output.store_buffer(bytes)
		if output.get_error()!=OK:return false
		digest.update(bytes)
		remaining-=bytes.size()
	output.close()
	return FileAccess.get_sha256(path)==digest.finish().hex_encode()

func recording(path:String)->AudioStream:
	if archive==null or not archive.file_exists(path):return null
	var bytes=archive.read_file(path)
	return AudioStreamMP3.load_from_buffer(bytes) if not bytes.is_empty() else null

