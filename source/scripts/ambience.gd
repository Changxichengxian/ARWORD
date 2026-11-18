extends Node
class_name IslandAmbience

const MUSIC_DIR="res://assets/music/"
var game
var player:AudioStreamPlayer
var tracks:Array[String]=[]
var track_index=0
var ducking=false
var was_enabled=false
var shutting_down=false
var first_play=true

func setup(owner_game):
	game=owner_game
	player=AudioStreamPlayer.new();add_child(player);player.volume_db=-11
	if not DirAccess.dir_exists_absolute(MUSIC_DIR):return
	for file in ResourceLoader.list_directory(MUSIC_DIR):
		if file.get_extension().to_lower() in ["ogg","mp3","wav"]:tracks.append(file)
	if tracks.is_empty():return
	tracks.shuffle()
	var history:Array=game.learning.data.music_openers
	var available=tracks.filter(func(file):return file not in history)
	if available.is_empty():
		var last=history.back() if not history.is_empty() else ""
		history.clear()
		available=tracks.filter(func(file):return file!=last)
	if not available.is_empty():track_index=tracks.find(available.front())
	player.finished.connect(next_track)
	was_enabled=game.learning.data.music
	if was_enabled:play_track()

func play_track():
	if tracks.is_empty():return
	var file=tracks[track_index]
	var original=load(MUSIC_DIR+file)
	if not original is AudioStream:return
	var stream=original.duplicate()
	if stream is AudioStreamWAV:stream.loop_mode=AudioStreamWAV.LOOP_DISABLED
	else:stream.loop=false
	player.stream=stream;player.play()
	if first_play:
		game.learning.data.music_openers.append(file)
		game.save_progress();first_play=false

func next_track():
	if shutting_down or tracks.is_empty() or not game.learning.data.music:return
	track_index=(track_index+1)%tracks.size()
	play_track()

func _process(dt):
	if shutting_down or not is_instance_valid(game) or not is_instance_valid(player):return
	var enabled=bool(game.learning.data.get("music",true))
	if enabled and not was_enabled:play_track()
	if not enabled and was_enabled:player.stop()
	was_enabled=enabled
	ducking=is_instance_valid(game.speech) and game.speech.playing
	player.volume_db=lerpf(player.volume_db,-29.0 if ducking else -11.0,1-exp(-dt*(10 if ducking else 1.8)))

func shutdown():
	shutting_down=true
	if is_instance_valid(player):player.stop();player.stream=null

func _exit_tree():shutdown()
