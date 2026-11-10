extends SceneTree
var game
var failures=0
func _initialize():call_deferred("run")
func check(ok:bool,label:String):
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1;push_error(label)
func settle():
	for i in range(3):await process_frame
func tap(button:Button):
	await settle()
	var at=button.get_global_rect().get_center()
	for down in [true,false]:
		var event=InputEventMouseButton.new();event.position=at;event.global_position=at;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;root.push_input(event,true)
	await settle()
func run():
	game=load("res://main.tscn").instantiate();game.set_script(load("res://tests/startup_recovery_game.gd"));root.add_child(game)
	game.startup.fail("测试场景加载失败")
	var words=JSON.stringify(game.learning.data.words);var units=game.frontier.finished_units()
	await tap(game.hud.settings_button)
	check(game.hud.screen=="settings","settings still opens when the world cannot load")
	var update=game.hud.active_box.find_child("CheckUpdates",true,false)
	check(update!=null,"update entry is available without a world or character")
	if update:await tap(update)
	check(game.update_requests==1 and game.hud.screen=="updates","actual update button click reaches updater independently of world initialization")
	game.hud.close();await tap(game.hud.books_button)
	check(game.hud.screen=="wordbooks","wordbook stays usable after a startup failure")
	var selected=str(game.learning.wordbooks.books[1].id)
	game.select_book_panel();game.choose_wordbook(selected);await settle()
	check(game.learning.data.book_id==selected,"a real book change is saved before world initialization")
	check(game.world==null,"book selection does not access a missing world")
	game.hud.close();game.word_search_query="传统";await tap(game.hud.search_button)
	check(game.hud.screen=="search" and game.word_details.search("传统").has("tradition"),"Chinese lookup stays usable after startup failure")
	game.lookup("tradition")
	check(game.spoken.size()==1,"failed world does not block word pronunciation")
	check(words==JSON.stringify(game.learning.data.words) and units==game.frontier.finished_units(),"failure recovery does not invent learning or construction progress")
	check(game.startup.sky.stars.size()==315,"opening contains three times as many stars")
	print("STARTUP_RECOVERY_RESULT ",failures," failed")
	await game.request_exit()
	if failures:quit(1)
