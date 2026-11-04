extends SceneTree

func _initialize():
	if not "--qa" in OS.get_cmdline_user_args():quit(2);return
	call_deferred("run")

func run():
	var game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await create_timer(.8).timeout
	var failures=0
	var personal="--qa-with-cast" in OS.get_cmdline_user_args()
	var store=game.study_voice
	if personal:
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
		reopened.prepare(game.cast_store.folder,"res://absent.arvoice")
		if reopened.recording("audio/work00_cue.mp3")==null:failures+=1
	game.learning.data.feiyu_voice=false
	game.play_speech("audio/work00_cue.mp3",true)
	if not game.speech.playing or game.speech.stream!=load("res://assets/audio/work00_cue.mp3") or not is_equal_approx(game.speech.pitch_scale,.85):failures+=1
	print("STUDY_VOICE_RESULT ",failures," failed")
	game.closing=true;game.queue_free();await process_frame;quit(int(failures!=0))

