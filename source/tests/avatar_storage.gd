extends SceneTree
const Store=preload("res://scripts/avatar_store.gd")
var failed=0
var passed=0
var base="user://qa-avatars/storage-"+str(Time.get_ticks_usec())
func _initialize():call_deferred("run")
func check(value:bool,label:String):
	print("PASS " if value else "FAIL ",label)
	if value:passed+=1
	else:failed+=1
func model(path:String,tag:String):
	var bytes=tag.to_utf8_buffer();var file=FileAccess.open(path,FileAccess.WRITE)
	file.store_32(0x46546c67);file.store_32(2);file.store_32(20+bytes.size());file.store_32(bytes.size());file.store_32(0x4e4f534a);file.store_buffer(bytes);file.close()
func clean(path:String):
	for name in DirAccess.get_files_at(path):DirAccess.remove_absolute(path.path_join(name))
	for name in DirAccess.get_directories_at(path):clean(path.path_join(name))
	DirAccess.remove_absolute(path)
func run():
	if not "--qa" in OS.get_cmdline_user_args():push_error("QA_REQUIRED: avatar storage checks require --qa");quit(2);return
	DirAccess.make_dir_recursive_absolute(base)
	var outside=base.path_join("selected-original.vrm");model(outside,"original")
	var next=base.path_join("selected-next.vrm");model(next,"replacement")
	var original_hash=FileAccess.get_sha256(outside);var next_hash=FileAccess.get_sha256(next)
	var store=Store.new(base.path_join("profile"))
	check(store.recover().selected=="default","fresh avatar storage starts with the built-in character")
	check(store.prepare(outside).ok,"copies a selected model into staging")
	check(FileAccess.get_sha256(outside)==original_hash,"selected source file remains untouched")
	check(store.install().ok and store.confirm({"title":"测试人物","author":"作者\n署名"}).ok,"separate model and metadata commit succeeds")
	var restart=Store.new(store.directory);var config=restart.recover()
	check(config.selected=="local" and config.title=="测试人物" and config.author=="作者署名","restart restores local model and bounded credit text")
	check(FileAccess.get_sha256(store.current_path())==original_hash,"committed copy matches the original bytes")
	var invalid=base.path_join("broken.vrm");var bad=FileAccess.open(invalid,FileAccess.WRITE);bad.store_string("not a VRM model file at all");bad.close()
	check(not store.prepare(invalid).ok and FileAccess.get_sha256(store.current_path())==original_hash,"invalid file cannot replace a working model")
	check(not store.prepare(base.path_join("missing.vrm")).ok,"unreadable selection is rejected")
	store.prepare(next);store.cancel()
	check(FileAccess.get_sha256(store.current_path())==original_hash and not FileAccess.file_exists(store.file("pending.vrm")),"cancelled staging preserves the current model")
	store.prepare(next);store.install()
	check(FileAccess.get_sha256(store.current_path())==next_hash,"candidate is installed before metadata commit")
	var recovered=Store.new(store.directory).recover()
	check(recovered.selected=="local" and FileAccess.get_sha256(store.current_path())==original_hash,"interrupted import rolls back to the last committed model on restart")
	store=Store.new(store.directory);store.prepare(next);store.install()
	DirAccess.make_dir_absolute(store.file("current.json.pending"))
	check(not store.confirm({"title":"next"}).ok,"metadata write failure is reported")
	store.rollback();DirAccess.remove_absolute(store.file("current.json.pending"))
	check(FileAccess.get_sha256(store.current_path())==original_hash and Store.new(store.directory).recover().title=="测试人物","failed metadata commit rolls back both file selection and metadata")
	store.prepare(next);store.install();var result=store.confirm({"title":"next","author":"a".repeat(400)})
	check(result.ok and result.info.author.length()==180,"successful replacement limits externally supplied author length")
	check(Store.new(store.directory).recover().title=="next" and FileAccess.get_sha256(store.current_path())==next_hash,"replacement survives a fresh storage instance")
	check(store.clear() and Store.new(store.directory).recover().selected=="default" and not FileAccess.file_exists(store.current_path()),"reset commits the built-in character and removes its private VRM copy")
	check(FileAccess.get_sha256(outside)==original_hash and FileAccess.get_sha256(next)==next_hash,"reset leaves both externally selected files intact")
	check(not FileAccess.file_exists(base.path_join("island4.json")),"avatar storage never creates or edits a learning save")
	clean(base)
	print("AVATAR_STORAGE_RESULT ",passed," passed / ",failed," failed")
	quit(1 if failed else 0)
