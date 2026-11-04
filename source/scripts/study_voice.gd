extends RefCounted

# Only personal builds contain the approved, pre-rendered English recordings.
# The cached pack also works after updating to a public build.
const PACK_NAME="feiyu-cute-v1.arvoice"
const BUNDLED="res://assets/characters/"+PACK_NAME
var archive:ZIPReader

func prepare(folder:String,bundled:String=BUNDLED):
	var cache=folder.path_join(PACK_NAME)
	if not FileAccess.file_exists(cache) and FileAccess.file_exists(bundled):
		if DirAccess.make_dir_recursive_absolute(folder)==OK:
			var temporary=cache+".part"
			if DirAccess.copy_absolute(bundled,temporary)==OK and FileAccess.get_sha256(temporary)==FileAccess.get_sha256(bundled):
				DirAccess.rename_absolute(temporary,cache)
			if FileAccess.file_exists(temporary):DirAccess.remove_absolute(temporary)
	for path in [cache,bundled]:
		if not FileAccess.file_exists(path):continue
		var pack=ZIPReader.new()
		if pack.open(path)==OK and pack.file_exists("index.json"):
			archive=pack
			return

func recording(path:String)->AudioStream:
	if archive==null or not archive.file_exists(path):return null
	var bytes=archive.read_file(path)
	return AudioStreamMP3.load_from_buffer(bytes) if not bytes.is_empty() else null

