extends SceneTree

func _initialize():
	if not "--qa" in OS.get_cmdline_user_args():quit(2);return
	call_deferred("run")

func run():
	var game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await create_timer(.8).timeout
	var failures=0
	var store=game.study_voice
	if game.learning.data.feiyu_voice or store.archive!=null:failures+=1
	var legacy=game.learning.data.duplicate(true);legacy.erase("voice_choice_version");legacy.feiyu_voice=true
	var loaded=IslandLearning.new();loaded.accept_save(legacy)
	if loaded.data.feiyu_voice:failures+=1
	var sample=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--voice-file="):sample=arg.trim_prefix("--voice-file=")
	if not sample.is_empty():
		if store.install_file(game.cast_store.folder,"res://project.godot"):failures+=1
		if not store.install_file(game.cast_store.folder,sample):failures+=1
		game.voice_imported("ready")
		var archive=store.archive as ZIPReader
		if archive==null:
			print("FAIL personal voice pack did not open");quit(1);return
		var manifest=JSON.parse_string(archive.read_file("index.json").get_string_from_utf8())
		if not manifest is Dictionary or manifest.get("tracks",0)<10696:failures+=1
		var word=game.learning.active_bank[0].audio
		for path in [word,"audio/work00_cue.mp3","audio/work00_full.mp3"]:
			game.play_speech(path)
			if not game.speech.playing or game.speech.stream.data!=archive.read_file(path):failures+=1
		var reopened=load("res://scripts/study_voice.gd").new()
		reopened.prepare(game.cast_store.folder)
		if reopened.recording("audio/work00_cue.mp3")==null:failures+=1
	game.learning.data.feiyu_voice=false
	game.play_speech("audio/work00_cue.mp3",true)
	if not game.speech.playing or game.speech.stream!=load("res://assets/audio/work00_cue.mp3") or not is_equal_approx(game.speech.pitch_scale,.85):failures+=1
	print("STUDY_VOICE_RESULT ",failures," failed")
	game.closing=true;game.queue_free();await process_frame;quit(int(failures!=0))

