extends SceneTree

var game
var failed=0
var checks=0
var captures=""

func _initialize():
	if not "--qa" in OS.get_cmdline_user_args():quit(2);return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--captures="):captures=arg.trim_prefix("--captures=")
	call_deferred("run")

func inspect_card(label:String):
	for frame in 6:await process_frame
	var hud=game.hud
	var rect=hud.card.get_global_rect()
	var fits=hud.safe_rect.encloses(rect) and rect.position.y>=hud.header.get_global_rect().end.y
	var scroll=hud.card_scroll
	fits=fits and not scroll.get_h_scroll_bar().visible and not scroll.get_v_scroll_bar().visible
	for control in hud.body.find_children("*","Control",true,false):
		if not control.is_visible_in_tree():continue
		fits=fits and scroll.get_global_rect().grow(1).encloses(control.get_global_rect())
		if control is RichTextLabel:fits=fits and not control.scroll_active and control.get_content_height()<=control.size.y+1
	checks+=1
	if not fits:
		failed+=1
		print("FAIL ",label," ",hud.safe_rect," card ",rect," content ",hud.body.size)
	if not captures.is_empty() and DisplayServer.get_name()!="headless" and label in ["normal","multi-result","word-help"]:
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(captures.path_join(label+".png"))

func run():
	game=load("res://main.tscn").instantiate();root.add_child(game)
	game.word_review.setup(game.learning.by_id)
	game.frontier.data.active="smelter";game.exploring=false;game.mode="word"
	var hud=game.hud;hud.set_card_open(true,false)
	for bounds in [Rect2(0,0,540,960),Rect2(8,30,394,542),Rect2(10,25,320,500)]:
		hud.apply_safe_rect(bounds)
		for id in ["boiler","referendum","temporary","right"]:
			game.learning.data.words.erase(id)
			game.current=game.word_senses.prepare(game.learning.by_id[id])
			game.order=range(game.current.options.size());hud.show_task()
			await inspect_card("intro-"+id)
			game.learning.introduce(id)
			for kind in ["text","audio","reverse","spelling"]:
				game.current=game.word_review.prepare(game.word_senses.prepare(game.learning.by_id[id]),kind,game.learning.active_bank)
				game.order=range(game.current.options.size());hud.show_task()
				await inspect_card("normal" if kind=="text" else kind)
				hud.show_word_feedback(int(game.current.correct),true)
				await inspect_card("multi-result" if game.current.options.size()==6 else "result")
			hud.show_help();await inspect_card("word-help")
	game.closing=true;game.queue_free();await process_frame
	print("WORD_CARD_FIT_RESULT ",checks," checks / ",failed," failed");quit(int(failed>0))
