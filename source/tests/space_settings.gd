extends SceneTree
var passed=0
var failed=0
func check(value:bool,label:String):
	if value:passed+=1;print("PASS ",label)
	else:failed+=1;push_error("FAIL "+label)
func _initialize():call_deferred("run")
func run():
	var game=load("res://main.tscn").instantiate();root.add_child(game)
	root.size=Vector2i(540,960);await create_timer(.5).timeout
	var before=JSON.stringify(game.learning.data.words)
	game.space_settings();await process_frame;await process_frame
	var sliders=game.hud.overlay.find_children("Space_*","HSlider",true,false)
	check(sliders.size()==5,"five live space controls are available")
	check(game.hud.overlay.color.a==0 and game.hud.screen=="space_settings","adjusting the sky leaves its real colors unobscured")
	var panel=game.hud.overlay.get_child(game.hud.overlay.get_child_count()-1).get_child(0)
	var bounds=panel.get_global_rect()
	check(bounds.position.y>=420 and bounds.end.y<=960 and bounds.end.x<=540,"the whole control panel fits below an unobstructed sky without scrolling")
	var nebula=game.hud.overlay.find_child("Space_nebula",true,false);nebula.value=2.35
	check(absf(game.learning.data.space_settings.nebula-2.35)<.001,"a slider changes the active setting immediately")
	var saved=JSON.parse_string(JSON.stringify(game.learning.data));var restored=IslandLearning.new()
	check(restored.accept_save(saved) and absf(restored.data.space_settings.nebula-2.35)<.001,"custom sky values survive normal save serialization")
	saved.space_settings={"nebula":-3,"color":"invalid","stars":9};restored=IslandLearning.new();restored.accept_save(saved)
	check(restored.data.space_settings.nebula==0 and restored.data.space_settings.color==1.3 and restored.data.space_settings.stars==2 and restored.data.space_settings.drift==1,"invalid or partial old settings are clamped and filled safely")
	game.reset_space_settings();await process_frame;await process_frame
	check(game.learning.data.space_settings==IslandLearning.SPACE_DEFAULTS,"restoring defaults resets all five controls")
	check(JSON.stringify(game.learning.data.words)==before,"art controls never change vocabulary records")
	game.hud.close();game.settings();await process_frame;await process_frame
	check(game.hud.overlay.color.a>.6,"ordinary settings regain their normal backdrop after the live sky panel")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--visual-out="):
			game.space_settings();await create_timer(.3).timeout
			var directory=arg.trim_prefix("--visual-out=");DirAccess.make_dir_recursive_absolute(directory)
			await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(directory.path_join("space-settings.png"))
	print("SPACE_SETTINGS_RESULT ",passed," passed / ",failed," failed")
	game.closing=true;game.ambience.shutdown();game.speech.stop();game.speech.stream=null;await create_timer(.10).timeout
	game.queue_free();await process_frame;await process_frame;quit(0 if failed==0 else 1)
