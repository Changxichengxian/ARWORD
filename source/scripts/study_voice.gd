extends RefCounted

const PACK_NAME="feiyu-cute-v1.arvoice"
const PACK_SIZE=56907124
const PACK_HASH="b8df8b5e2222f2aa5a287003f0fe6673c7a9cf0445d16fd8ba733f2495fb77f9"
const RELEASE_PATH="/Changxichengxian/ARWORD-voice/releases/download/feiyu-cute-v1/"+PACK_NAME
const CACHE_MAX_RECORDINGS=32
const CACHE_MAX_BYTES=8*1024*1024
var archive:ZIPReader
var _recordings:Dictionary={}
var _recording_order:Array[String]=[]
var _recording_bytes=0

func prepare(folder:String):
	_recordings.clear();_recording_order.clear();_recording_bytes=0
	if archive!=null:archive.close()
	archive=open_cache(folder.path_join(PACK_NAME))

func install_file(folder:String,source_path:String)->bool:
	var cache=folder.path_join(PACK_NAME)
	if DirAccess.make_dir_recursive_absolute(folder)!=OK:return false
	var temporary=cache+".part"
	var copied=copy_recordings(source_path,temporary)
	var committed=copied and DirAccess.rename_absolute(temporary,cache)==OK
	if committed:prepare(folder)
	if FileAccess.file_exists(temporary):DirAccess.remove_absolute(temporary)
	return committed and archive!=null

func open_cache(path:String)->ZIPReader:
	if not FileAccess.file_exists(path):return null
	var pack=ZIPReader.new()
	if pack.open(ProjectSettings.globalize_path(path))!=OK:return null
	if pack.file_exists("index.json"):return pack
	pack.close()
	return null

func copy_recordings(source_path:String,path:String)->bool:
	var source=FileAccess.open(source_path,FileAccess.READ)
	if source==null or source.get_length()!=PACK_SIZE:return false
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
	return digest.finish().hex_encode()==PACK_HASH and FileAccess.get_sha256(path)==PACK_HASH

func recording(path:String)->AudioStream:
	if archive==null:return null
	if _recordings.has(path):
		_recording_order.erase(path);_recording_order.append(path)
		return _recordings[path].stream
	if not archive.file_exists(path):return null
	var bytes=archive.read_file(path)
	if bytes.is_empty():return null
	var stream=AudioStreamMP3.load_from_buffer(bytes)
	if stream==null:return null
	# Bound both the number of recordings and their encoded MP3 data. Long
	# recordings can still play without displacing the entire recent cache.
	if bytes.size()>CACHE_MAX_BYTES:return stream
	while not _recording_order.is_empty() and (_recordings.size()>=CACHE_MAX_RECORDINGS or _recording_bytes+bytes.size()>CACHE_MAX_BYTES):
		var oldest=_recording_order.pop_front()
		_recording_bytes-=int(_recordings[oldest].bytes)
		_recordings.erase(oldest)
	_recordings[path]={"stream":stream,"bytes":bytes.size()}
	_recording_order.append(path)
	_recording_bytes+=bytes.size()
	return stream

