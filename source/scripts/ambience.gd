extends Node
class_name IslandAmbience

var game
var player:AudioStreamPlayer
var ducking=false
var was_enabled=true
var shutting_down=false
const TRACKS=["island_drift","harbor_six","orchard_keys","glass_orbit"]
var track_index=0

func setup(owner_game):
	game=owner_game
	player=AudioStreamPlayer.new();add_child(player)
	player.volume_db=-11
	track_index=randi()%TRACKS.size()
	load_track()
	player.finished.connect(next_track)
	was_enabled=bool(game.learning.data.get("music",true))
	if was_enabled:player.play()

func load_track():
	var stream=load("res://assets/audio/"+TRACKS[track_index]+".ogg").duplicate()
	stream.loop=false
	player.stream=stream

func next_track():
	if shutting_down or not game.learning.data.music:return
	track_index=(track_index+1)%TRACKS.size()
	load_track()
	player.play()

func _process(dt):
	if shutting_down or not is_instance_valid(game) or not is_instance_valid(player):return
	var enabled=bool(game.learning.data.get("music",true))
	if enabled and not was_enabled:player.play()
	if not enabled and was_enabled:player.stop()
	was_enabled=enabled
	ducking=is_instance_valid(game.speech) and game.speech.playing
	var target=-29.0 if ducking else -11.0
	player.volume_db=lerpf(player.volume_db,target,1-exp(-dt*(10 if ducking else 1.8)))

func shutdown():
	shutting_down=true
	if is_instance_valid(player):
		player.stop();player.stream=null

func _exit_tree():
	shutdown()
