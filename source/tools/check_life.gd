extends SceneTree

class StudyStub extends Node3D:
	var learning={"data":{"music":true,"actions":0}}
	var speech:AudioStreamPlayer
	var camera:Camera3D
class WorldStub extends Node3D:
	var game
	var globe:Node3D
	var land={Vector2i(0,0):true,Vector2i(1,0):true,Vector2i(0,1):true}
	var terrain=IslandTerrain.new()
	var water=WaterStub.new()
	func surface(p:Vector2)->Vector3:return terrain.point(p)
class WaterStub extends RefCounted:
	func depth_at(_normal:Vector3)->float:return 2.0

var passed=0
var failed=0
func check(condition:bool,label:String):
	if condition:passed+=1;print("PASS ",label)
	else:failed+=1;push_error("FAIL "+label)
func _initialize():call_deferred("run")
func run():
	var game=StudyStub.new();root.add_child(game)
	game.camera=Camera3D.new();game.add_child(game.camera);game.camera.projection=Camera3D.PROJECTION_ORTHOGONAL;game.camera.size=12;game.camera.position=Vector3(0,21,12);game.camera.look_at(Vector3(0,12,0));game.camera.current=true
	game.speech=AudioStreamPlayer.new();game.add_child(game.speech)
	var world=WorldStub.new();game.add_child(world);world.game=game;world.globe=Node3D.new();world.add_child(world.globe)
	var life=IslandWildlife.new();world.add_child(life);life.setup(world)
	var ambient=IslandAmbience.new();game.add_child(ambient);ambient.setup(game)
	await create_timer(.15).timeout
	check(life.animals.size()==15,"small initial island has twelve schooling fish and one whale")
	check(ambient.player.stream.get_length()>79.9 and ambient.player.stream.loop,"original soundtrack is an eighty-second loop")
	var fish_safe=true
	for i in range(600):
		life._process(.016)
		for animal in life.animals:
			if animal.kind=="fish" and animal.anchor.visible:
				var p=animal.anchor.position.normalized()*12
				if not life.water_at(Vector2(p.x,p.z)):fish_safe=false
	check(fish_safe,"fish remain outside existing land through a full swimming cycle")
	for chapter in IslandFrontier.CHAPTERS:
		for cell in chapter.cells:world.land[cell]=true
	life.refresh_habitats();life._process(.016)
	check(life.animals.size()==44,"expanded island grows to thirty-two fish, two whales and ten flying creatures")
	var reacted=false
	for animal in life.animals:
		var p=animal.anchor.global_position;var normal=p.normalized()
		if animal.anchor.visible and normal.dot((game.camera.global_position-p).normalized())>.2:
			if life.handle_tap(game.camera.unproject_position(p)):reacted=true;break
	check(reacted,"visible wildlife reacts to a tap")
	check(game.learning.data.actions==0,"wildlife never changes learning or construction")
	game.speech.stream=ambient.player.stream;game.speech.volume_db=-80;game.speech.play()
	await create_timer(.35).timeout
	check(ambient.ducking and ambient.player.volume_db< -28,"English playback lowers background music automatically")
	game.learning.data.music=false
	await process_frame;await process_frame
	check(not ambient.player.playing,"music switch stops playback")
	game.learning.data.music=true;game.speech.stop()
	await process_frame;await process_frame
	check(ambient.player.playing and not ambient.ducking,"music can resume independently of word audio")
	if "--direct-quit" not in OS.get_cmdline_user_args():
		ambient.shutdown();game.speech.stop();game.queue_free()
		await process_frame;await process_frame
		await create_timer(.08).timeout
	print("LIFE_AUDIO_RESULT ",passed," passed / ",failed," failed")
	quit(0 if failed==0 else 1)
