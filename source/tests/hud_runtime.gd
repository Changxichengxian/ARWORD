extends SceneTree

var game
var failures=0
var checks=0
var visibility_changes=0

func _initialize():
	if not "--qa" in OS.get_cmdline_user_args():quit(2);return
	# Headless windows default to a square surface. Fix the logical portrait
	# viewport so the camera and the simulated phone safe area use the same units.
	root.content_scale_size=Vector2i(540,960)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_IGNORE
	call_deferred("run")

func check(ok:bool,label:String):
	checks+=1
	if not ok:failures+=1
	print("PASS " if ok else "FAIL ",label)

func settle():
	for i in 8:await process_frame

func on_visibility_changed():visibility_changes+=1

func visible_ids()->Array:
	var ids=[]
	for id in game.hud.world_progress:
		if game.hud.world_progress[id].panel.visible:ids.append(id)
	ids.sort()
	return ids

func run():
	game=load("res://main.tscn").instantiate();root.add_child(game);await settle()
	game.ambience.shutdown()
	check(game.hud.safe_rect.size.is_equal_approx(Vector2(540,960)),"camera and safe-area fixture share a 540 by 960 logical viewport")
	game.hud.set_process(false)
	game.world.set_process(false)
	game.stop_view_transition()
	game.frontier.choose("grove")
	game.hud.overlay.hide();game.hud.set_card_open(false,false)
	game.frame_view(Vector3(0,10,0),16.0,false)
	game.world.recenter();game.world.globe.quaternion=game.world.desired_rotation
	game.hud.sync_goal();await settle()
	game.hud.update_world_progress()
	var item=game.hud.world_progress[game.frontier.data.active]
	check(item.panel.visible,"recentered front-side worksite has a visible label")
	for progress_item in game.hud.world_progress.values():progress_item.panel.visibility_changed.connect(on_visibility_changed)
	var before=visible_ids()
	for i in 120:game.hud.update_world_progress()
	check(visible_ids()==before,"unchanged scene keeps the same visible worksite labels")
	check(visibility_changes==0,"stationary label updates do not repeatedly show and hide occluded panels")
	var front_rotation=game.world.globe.quaternion
	game.world.globe.quaternion=Quaternion(Vector3.RIGHT,PI)*front_rotation
	game.hud.update_world_progress()
	check(not item.panel.visible,"turning the selected worksite to the back hides its label")
	game.world.globe.quaternion=front_rotation;game.hud.update_world_progress()
	check(item.panel.visible,"returning the worksite to the front restores its label")
	game.camera.h_offset=game.camera.size*2.0;game.hud.update_world_progress()
	check(not item.panel.visible,"a projected worksite beyond the screen edge is hidden")
	game.camera.h_offset=0.0;game.hud.update_world_progress()
	check(item.panel.visible,"returning inside the screen edge restores the label")
	var original=item.title.text
	item.title.text="A deliberately long worksite heading for layout verification"
	await settle()
	var wide=item.panel.size.x
	check(wide>=item.panel.get_combined_minimum_size().x,"changed title expands the panel without a per-frame size reset")
	item.title.text="X"
	await settle()
	check(item.panel.size.x<wide,"shortened title shrinks the panel after its minimum size changes")
	item.title.text=original
	item.small.show();item.stepbar.show();await settle()
	var tall=item.panel.size.y
	item.small.hide();item.stepbar.hide();await settle()
	check(item.panel.size.y<tall,"hiding the quota text and bar shrinks the worksite panel height")
	game.hud.sync_goal();await settle()
	game.hud.overlay.show();game.hud.update_world_progress()
	check(visible_ids().is_empty(),"modal overlay hides worksite labels")
	visibility_changes=0
	for i in 60:game.hud.update_world_progress()
	check(visibility_changes==0,"open modal does not trigger redundant visibility changes")
	game.hud.overlay.hide()
	game.hud.apply_safe_rect(Rect2(20,65,490,820));await settle()
	game.hud.update_world_progress()
	check(item.panel.visible,"front-side label remains visible after asymmetric safe-area changes")
	var in_bounds=true
	for entry in game.hud.world_progress.values():
		var panel=entry.panel
		if not panel.visible:continue
		in_bounds=in_bounds and panel.position.x>=5 and panel.position.y>=86
		in_bounds=in_bounds and panel.position.x+panel.size.x<=game.hud.safe_rect.size.x-5
		in_bounds=in_bounds and panel.position.y+panel.size.y<=game.hud.safe_rect.size.y-8
	check(in_bounds,"visible labels stay inside changed safe-area bounds")
	var original_card_height=game.hud.card_height
	var label_bottom=item.panel.position.y+item.panel.size.y
	# Raise the real learning card just across the previously visible label.
	game.hud.layout_card(game.hud.safe_rect.size.y-20.0-label_bottom+4.0)
	game.hud.set_card_open(true,false);await settle();game.hud.update_world_progress()
	check(game.hud.card.visible and not item.panel.visible,"visible learning card hides the overlapping worksite label")
	var above_card=true
	for entry in game.hud.world_progress.values():
		if entry.panel.visible:above_card=above_card and entry.panel.position.y+entry.panel.size.y<=game.hud.card.position.y-8
	check(above_card,"visible labels respect the learning card top edge, not just the safe-area bottom")
	game.hud.layout_card(original_card_height);game.hud.set_card_open(false,false)
	game.hud.update_world_progress()
	check(item.panel.visible,"closing the learning card restores the previously covered label")
	game.closing=true;game.ambience.shutdown();game.speech.stop();game.speech.stream=null
	game.queue_free();await process_frame;await process_frame;game=null
	print("HUD_RUNTIME_RESULT ",checks," checks / ",failures," failed")
	quit.call_deferred(int(failures>0))
