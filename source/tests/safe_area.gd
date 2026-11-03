extends SceneTree
const Area=preload("res://scripts/safe_area.gd")
var failed=0
var checks=0
func _initialize():
	if not "--qa" in OS.get_cmdline_user_args():quit(2);return
	call_deferred("run")
func check(ok:bool,label:String):
	checks+=1
	if not ok:failed+=1
	print("PASS " if ok else "FAIL ",label)
func settle():
	for i in 5:await process_frame
func run():
	var g=load("res://main.tscn").instantiate();root.add_child(g);await settle()
	var h=g.hud
	var window=Rect2(100,80,1080,2400)
	var logical=Vector2(540,1200)
	var usable=Rect2(120,164,1008,2236)
	check(Area.from_display(window,logical,usable,[]).is_equal_approx(Rect2(10,42,504,1118)),"screen origin, four asymmetric insets and density are handled")
	check(Area.from_display(window,logical,window,[Rect2(600,90,100,70)]).position.y==40,"interior punch hole reserves the full top edge")
	check(Area.from_display(window,logical,window,[Rect2(1130,700,50,180)]).end.x==515,"side cutout is not mistaken for a top notch")
	for bounds in [Rect2(26,78,448,680),Rect2(40,21,394,542)]:
		h.apply_safe_rect(bounds);g.select_site("cottage");await settle()
		check(bounds.encloses(h.header.get_global_rect()) and bounds.encloses(h.card.get_global_rect()),"toolbar and learning card fit the safe area")
		check(not g.world_area(bounds.position-Vector2.ONE),"system gesture strips do not accept worksite taps")
		g.settings();await settle()
		check(bounds.encloses(h.active_panel.get_global_rect()),"settings stay within all four edges")
		check(h.overlay.get_global_rect().size.is_equal_approx(h.size),"modal backdrop still covers the entire viewport")
		if bounds.size.y<600:check(h.active_scroll.get_v_scroll_bar().visible,"compact settings keep every action reachable by scrolling")
		g.lookup("harbor");await settle();check(bounds.encloses(h.active_panel.get_global_rect()),"dictionary fits")
		g.show_rocket();await settle();check(bounds.encloses(h.active_panel.get_global_rect()),"bottom-aligned berth panel fits")
		g.enter_trench();await settle();check(bounds.encloses(h.active_panel.get_global_rect()),"dive return control fits")
		g.leave_trench();h.close()
	g.learning.data.black_hole=true;g.cosmos.set_black_hole(true);g.open_observatory(true)
	await settle();var close=g.observatory_layer.find_children("*","BaseButton",true,false)[0]
	check(h.safe_rect.encloses(close.get_global_rect()),"fullscreen observation respects safe content bounds")
	h.apply_safe_rect(Rect2(17,115,410,680));await settle()
	check(close.global_position.y>=115 and h.safe_rect.encloses(close.get_global_rect()),"observation updates with live window insets")
	g.close_observatory();g.closing=true;g.queue_free();await process_frame
	print("SAFE_AREA_RESULT ",checks," checks / ",failed," failed");quit(int(failed>0))
