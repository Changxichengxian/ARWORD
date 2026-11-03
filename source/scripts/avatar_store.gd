extends RefCounted

# Avatar files have their own transaction and never share the learning save.
const MAX_BYTES=64*1024*1024
var directory:String
var had_previous=false
var installed=false

func _init(path:String):directory=path
func file(name:String)->String:return directory.path_join(name)
func current_path()->String:return file("current.vrm")
func failure(message:String)->Dictionary:return {"ok":false,"error":message}
func read_config(path:String)->Dictionary:
	if not FileAccess.file_exists(path):return {}
	var handle=FileAccess.open(path,FileAccess.READ)
	if handle==null or handle.get_length()>8192:return {}
	var value=JSON.parse_string(handle.get_as_text());handle.close()
	if not value is Dictionary or int(value.get("version",0))!=1:return {}
	if str(value.get("selected","")) not in ["default","local"]:return {}
	value.version=1
	return value
func matches(path:String,config:Dictionary)->bool:
	return FileAccess.file_exists(path) and str(config.get("sha256","")).length()==64 and FileAccess.get_sha256(path)==str(config.sha256)
func recover()->Dictionary:
	# The committed configuration decides which file survived an interrupted import.
	for config_path in [file("current.json"),file("current.json.previous")]:
		var config=read_config(config_path)
		if config.is_empty():continue
		if config.selected=="default":return {"ok":true,"selected":"default"}
		if matches(current_path(),config):return config
		if matches(file("previous.vrm"),config):
			if FileAccess.file_exists(current_path()):DirAccess.remove_absolute(current_path())
			if DirAccess.rename_absolute(file("previous.vrm"),current_path())==OK:return config
			return failure("人物文件暂时无法恢复")
	return {"ok":true,"selected":"default"}
func prepare(source:String)->Dictionary:
	installed=false;had_previous=false
	var input=FileAccess.open(source,FileAccess.READ)
	if input==null:return failure("无法读取这个文件，请重新选择")
	var length=input.get_length()
	if length<20 or length>MAX_BYTES:input.close();return failure("请选择 64 MB 以内的 VRM 模型")
	if input.get_32()!=0x46546c67 or input.get_32()!=2 or input.get_32()!=length:
		input.close();return failure("这个文件不是完整的 VRM 模型")
	input.seek(0)
	if DirAccess.make_dir_recursive_absolute(directory)!=OK:input.close();return failure("人物文件夹暂时无法写入")
	var pending=FileAccess.open(file("pending.vrm"),FileAccess.WRITE)
	if pending==null:input.close();return failure("人物文件暂时无法保存")
	var remaining=length
	while remaining>0:
		var amount=mini(1024*1024,remaining);var bytes=input.get_buffer(amount)
		if bytes.size()!=amount:input.close();pending.close();cancel();return failure("文件读取中断，请重试")
		pending.store_buffer(bytes);remaining-=bytes.size()
	pending.flush();var error=pending.get_error();pending.close();input.close()
	if error!=OK:cancel();return failure("人物文件暂时无法保存")
	return {"ok":true,"path":file("pending.vrm")}
func cancel():
	if FileAccess.file_exists(file("pending.vrm")):DirAccess.remove_absolute(file("pending.vrm"))
	if FileAccess.file_exists(file("current.json.pending")):DirAccess.remove_absolute(file("current.json.pending"))
func install()->Dictionary:
	if not FileAccess.file_exists(file("pending.vrm")):return failure("人物文件尚未准备好")
	if FileAccess.file_exists(file("previous.vrm")) and DirAccess.remove_absolute(file("previous.vrm"))!=OK:return failure("旧人物文件暂时无法备份")
	had_previous=FileAccess.file_exists(current_path())
	if had_previous and DirAccess.rename_absolute(current_path(),file("previous.vrm"))!=OK:return failure("旧人物文件暂时无法备份")
	if DirAccess.rename_absolute(file("pending.vrm"),current_path())!=OK:
		if had_previous:DirAccess.rename_absolute(file("previous.vrm"),current_path())
		return failure("新人物文件暂时无法保存")
	installed=true;return {"ok":true,"path":current_path()}
func rollback():
	if not installed:return
	if FileAccess.file_exists(current_path()):DirAccess.remove_absolute(current_path())
	if had_previous:DirAccess.rename_absolute(file("previous.vrm"),current_path())
	installed=false;cancel()
func clean_label(value:String,limit:int)->String:
	var result=""
	for character in value:
		if character.unicode_at(0)>=32:result+=character
	return result.strip_edges().substr(0,limit)
func write_config(config:Dictionary)->bool:
	if DirAccess.make_dir_recursive_absolute(directory)!=OK:return false
	var pending=file("current.json.pending");var output=FileAccess.open(pending,FileAccess.WRITE)
	if output==null:return false
	output.store_string(JSON.stringify(config));output.flush();var error=output.get_error();output.close()
	if error!=OK:return false
	var path=file("current.json");var previous=file("current.json.previous")
	if FileAccess.file_exists(previous) and DirAccess.remove_absolute(previous)!=OK:return false
	var existed=FileAccess.file_exists(path)
	if existed and DirAccess.rename_absolute(path,previous)!=OK:return false
	if DirAccess.rename_absolute(pending,path)!=OK:
		if existed:DirAccess.rename_absolute(previous,path)
		return false
	return true
func confirm(info:Dictionary)->Dictionary:
	var config={"version":1,"selected":"local","sha256":FileAccess.get_sha256(current_path()),"title":clean_label(str(info.get("title","本地人物")),100),"author":clean_label(str(info.get("author","")),180)}
	if not write_config(config):return failure("人物设置暂时无法保存")
	installed=false
	if FileAccess.file_exists(file("previous.vrm")):DirAccess.remove_absolute(file("previous.vrm"))
	if FileAccess.file_exists(file("current.json.previous")):DirAccess.remove_absolute(file("current.json.previous"))
	return {"ok":true,"info":config}
func clear()->bool:
	# Commit the default selection before removing files, so an interrupted reset stays reset.
	if not write_config({"version":1,"selected":"default"}):return false
	for name in ["current.vrm","previous.vrm","pending.vrm","current.json.previous"]:
		if FileAccess.file_exists(file(name)):DirAccess.remove_absolute(file(name))
	return true
