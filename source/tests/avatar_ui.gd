extends SceneTree
var game
var failed=0
var passed=0
var output="../work/qa11/avatar-ui"
var source_model=""
func _initialize():
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	DirAccess.make_dir_recursive_absolute(output)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--avatar-test-model="):source_model=arg.trim_prefix("--avatar-test-model=")
	call_deferred("run")
func check(ok:bool,label:String):
	print("PASS " if ok else "FAIL ",label)
	if ok:passed+=1
	else:failed+=1
func settle():
	for i in range(3):await process_frame
func screenshot(name:String):
	await settle();await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(name+".png"))
func find_button(label:String):
	for button in game.hud.overlay.find_children("*","Button",true,false):
		if button.text==label and button.is_visible_in_tree():return button
	return null
func fits()->bool:
	for button in game.hud.overlay.find_children("*","Button",true,false):
		if button.is_visible_in_tree():
			var rect=button.get_global_rect()
			if rect.position.x<0 or rect.position.y<0 or rect.end.x>540 or rect.end.y>960:return false
	return true
func click(button):
	if button==null:return
	var pos=button.get_global_rect().get_center()
	for pressed in [true,false]:
		var event=InputEventMouseButton.new();event.position=pos;event.global_position=pos;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;event.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed else 0
		Input.parse_input_event(event);await settle()
func run():
	if not "--qa" in OS.get_cmdline_user_args():push_error("avatar UI checks require --qa");quit(2);return
	game=load("res://main.tscn").instantiate();root.add_child(game)
	DisplayServer.window_set_size(Vector2i(540,960));DisplayServer.window_set_position(Vector2i(DisplayServer.screen_get_usable_rect().end.x-100,60))
	await create_timer(.7).timeout
	check(game.avatar_store.directory.begins_with("user://qa-avatars/"),"native avatar checks use an isolated private QA directory")
	var history=JSON.stringify(game.learning.data)
	game.settings();await settle()
	check(find_button("人物")!=null and fits(),"settings expose the character entry and fit at 540 by 960 without scrolling")
	await screenshot("settings")
	await click(find_button("人物"));await settle()
	check(game.hud.screen=="avatar" and fits(),"native character entry opens the compact character panel")
	check(find_button("恢复白色人物").disabled,"built-in character does not offer a redundant reset")
	await screenshot("before-import")
	if not source_model.is_empty():
		var source_hash=FileAccess.get_sha256(source_model)
		var result=game.import_local_avatar(source_model)
		check(result.get("ok",false),"explicit local VRM import succeeds through the full transaction")
		if result.get("ok",false):
			var imported=game.avatar_info.duplicate();var saved_hash=FileAccess.get_sha256(game.avatar_store.current_path())
			check(source_hash==saved_hash and FileAccess.get_sha256(source_model)==source_hash,"private model copy matches the untouched selected file")
			check(not str(imported.author).is_empty() and not str(imported.title).is_empty(),"VRM title and original author are available for attribution")
			game.show_avatar_settings();await settle();await screenshot("imported")
			check(fits() and not find_button("恢复白色人物").disabled,"imported character panel and reset action fit without scrolling")
			var broken=game.avatar_store.directory.path_join("broken.vrm");var file=FileAccess.open(broken,FileAccess.WRITE);file.store_string("broken selected file");file.close()
			var rejected=game.import_local_avatar(broken)
			check(not rejected.get("ok",false) and game.avatar_info==imported and FileAccess.get_sha256(game.avatar_store.current_path())==saved_hash,"bad import retains the old model file and selection")
			game.world.clear_local_avatar();game.avatar_info={}
			var restored=game.restore_avatar()
			check(restored.get("ok",false) and game.avatar_info==imported,"saved selection restores through the same startup path")
			var stable_scope=false
			for arg in OS.get_cmdline_user_args():
				if arg.begins_with("--qa-avatar-scope="):stable_scope=true
			if stable_scope:
				check(JSON.stringify(game.learning.data)==history,"first application instance retains all learning records")
				game.closing=true;game.ambience.shutdown();game.speech.stop();game.speech.stream=null;game.queue_free();await process_frame;await process_frame
				game=load("res://main.tscn").instantiate();root.add_child(game)
				DisplayServer.window_set_size(Vector2i(540,960));DisplayServer.window_set_position(Vector2i(DisplayServer.screen_get_usable_rect().end.x-100,60))
				await create_timer(.7).timeout
				check(game.avatar_info==imported and is_instance_valid(game.world.avatar),"a completely new application scene automatically restores the persisted VRM")
				history=JSON.stringify(game.learning.data)
			game.hud.close();game.world.recenter();await create_timer(.6).timeout;await screenshot("on-planet")
			game.show_avatar_settings();await settle();await click(find_button("恢复白色人物"))
			check(game.avatar_info.is_empty() and not FileAccess.file_exists(game.avatar_store.current_path()),"native reset returns the white character and clears only its private model")
			check(game.avatar_store.recover().selected=="default" and FileAccess.get_sha256(source_model)==source_hash,"reset persists without touching the external source")
	check(JSON.stringify(game.learning.data)==history,"avatar changes never alter learning or construction records")
	game.avatar_picker_cancelled();await settle();check(not game.avatar_busy,"cancelled file selection releases the UI state")
	await click(find_button("返回"));check(game.hud.screen=="settings","character panel returns to settings")
	print("AVATAR_UI_RESULT ",passed," passed / ",failed," failed")
	game.closing=true;game.ambience.shutdown();game.speech.stop();game.speech.stream=null;game.queue_free();await process_frame;await process_frame
	quit(0 if failed==0 else 1)
