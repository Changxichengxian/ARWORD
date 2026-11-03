extends SceneTree

var failures=0
var passed=0
var photo_dir=""

func _initialize():
	if not "--qa" in OS.get_cmdline_user_args():
		push_error("QA_REQUIRED: voyage checks require --qa")
		quit(2)
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--voyage-photos="):photo_dir=arg.trim_prefix("--voyage-photos=")
	call_deferred("run")

func check(ok:bool,message:String):
	if ok:
		passed+=1
		print("PASS ",message)
	else:
		failures+=1
		push_error(message)

func run():
	var learning=IslandLearning.new()
	var frontier=IslandFrontier.new(learning)
	check(frontier.available("rocket") and not frontier.choose("rocket") and not frontier.rocket_open(),"new player can discover the occupied berth before gaining access to it")
	check(not frontier.available("goldmine") and not frontier.available("smelter"),"remote ore and mint require real transport and facilities")
	frontier.data.progress.shipyard=12
	check(frontier.available("goldmine"),"shipyard opens distant gold mine construction")
	frontier.data.progress.goldmine=8
	frontier.data.progress.kiln=8
	check(frontier.available("smelter"),"completed mine and kiln open the island mint")
	frontier.data.progress.smelter=8
	frontier.record_delivery(frontier.work_route("smelter"))
	check(frontier.data.voyage.ore==1 and frontier.data.voyage.coins==0,"empty mint sources one ore parcel from distant mine")
	frontier.record_delivery(frontier.work_route("smelter"))
	check(frontier.data.voyage.ore==0 and frontier.data.voyage.coins==2,"mint consumes that ore to cast two coins")
	check(frontier.offer_gold()==2 and frontier.offer_gold()==0 and frontier.data.voyage.paid==2,"a second trade cannot spend the same coins")
	for i in range(17):
		frontier.record_delivery(frontier.work_route("goldmine"))
		frontier.record_delivery(frontier.work_route("smelter"))
	check(frontier.offer_gold()==6 and frontier.data.voyage.coins==28,"a full purse offers only one bag of six")
	while frontier.offer_amount()>0:
		frontier.offer_gold()
	check(not frontier.try_unlock_rocket() and not frontier.rocket_open(),"36 coins clear the berth but do not complete a book")
	var book=learning.current_book()
	for word in book.words:
		learning.data.words[word]={"correct":1}
	var last=book.words.back()
	learning.data.words.erase(last)
	learning.record(last,true,Time.get_unix_time_from_system()-300,false,1)
	check(not frontier.try_unlock_rocket(),"hinted-only last word cannot open hatch")
	learning.record(last,false,Time.get_unix_time_from_system(),false,1)
	check(frontier.try_unlock_rocket() and frontier.rocket_open() and frontier.data.voyage.earned_book==book.id,"last independent first-pass answer records that book and opens hatch")
	learning.select_book("tem8")
	var copy=IslandLearning.new()
	check(copy.accept_save(JSON.parse_string(JSON.stringify(learning.data))),"voyage inventory uses the existing save format")
	var restored=IslandFrontier.new(copy)
	check(restored.rocket_open() and restored.data.voyage==frontier.data.voyage and not restored.try_unlock_rocket(),"switching books and reopening retain trade and unlock, without reissuing it")
	var dev=IslandFrontier.new(IslandLearning.new())
	dev.finish_for_development(true)
	check(dev.rocket_open() and dev.data.voyage.dev_open and dev.data.voyage.earned_book=="" and dev.data.voyage.paid==0 and dev.learning.independent_count()==0,"developer tour gives access without inventing trade or first-pass results")
	if not "--data-only" in OS.get_cmdline_user_args():await scene_checks()
	print("VOYAGE_RESULT ",passed," passed / ",failures," failed")
	quit(0 if failures==0 else 1)

func scene_checks():
	var game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var world=game.world
	check(world.facilities.rocket.visible and world.trader.is_visible_in_tree() and world.land.size()==6,"rocket and resident trader are physically present on the starting globe")
	var a=world.surface(game.frontier.target("rocket")).normalized()
	check(a.dot(world.surface(Vector2.ZERO).normalized())<-.99,"the berth is on the back of the main island")
	check(world.rocket_hatch and world.rocket_lamp and world.trader.arms.size()==4 and not world.trader.find_child("Head",true,false),"native meshes have the authored hatch, beacon and articulated trader")
	for i in world.trader.arms.size():
		check(not world.trader.channels[i].has(-1),"authored grip, ripple and release present on "+str(world.trader.arms[i].name))
	var trench=world.trader.transform*Vector3(-4.3,-1.0,-2.4)
	var depth=world.water.depth_at(trench)
	check(depth>2.7 and world.water.floor_radius(trench)<IslandWater.BASE_RADIUS-2.7,"offshore arms emerge from a physical trench deeper than 2.7 world units")
	world.desired_rotation=Quaternion(a,Vector3.UP)
	world.globe.quaternion=world.desired_rotation
	game.frame_view(Vector3(0,10.4,0),10.5,false)
	var arm_pixel=game.camera.unproject_position(world.trader.to_global(Vector3(-1.38,-.42,2.14)))
	var open_water=game.camera.unproject_position(world.trader.to_global(Vector3(-4.8,-1,4.9)))
	check(world.trader.hit(arm_pixel) and not world.trader.hit(open_water),"a visible offshore limb accepts taps while neighboring open water stays free")
	game.show_rocket()
	check(game.hud.screen=="rocket" and game.hud.overlay.visible and not game.frontier.rocket_open(),"normal berth interaction opens an occupied trade page")
	game.hud.close()
	game.fast_forward(true)
	await create_timer(.85).timeout
	game.resume_voyage()
	game.hud.close()
	check(world.facilities.goldmine.visible and world.facilities.smelter.visible and not world.rocket_lamp.visible,"mine and mint appear on real land; developer preview can return to actual voyage")
	game.frontier.choose("goldmine")
	game.exploring=false
	game.next_task()
	game.skip_learning()
	game.skip_learning()
	check(game.frontier.data.voyage.ore==1 and game.frontier.data.voyage.coins==0,"one normal skip action at the completed mine supplies one ore even on double tap")
	await create_timer(1.5).timeout
	game.select_site("smelter")
	game.skip_learning()
	check(game.frontier.data.voyage.ore==0 and game.frontier.data.voyage.coins==2,"real mint action consumes stock and casts coins")
	await create_timer(1.5).timeout
	game.show_rocket()
	game.pay_trader()
	game.pay_trader()
	check(game.frontier.data.voyage.paid==2 and game.frontier.data.voyage.coins==0 and world.trader.pulse>0,"normal trade button debits once and triggers a visible response")
	var stock=game.frontier.data.voyage.duplicate(true)
	for i in range(90):world.animate_voyage(.05)
	check(stock==game.frontier.data.voyage,"several seconds of character and machine animation issue no stock")
	check(is_equal_approx(world.trader.release,2.0/IslandFrontier.TRADE_PRICE) and world.trader.arms[0].get_blend_shape_value(world.trader.channels[0][0])<.05,"small real payment settles into partial release while the crown still grips")
	if not photo_dir.is_empty() and DisplayServer.get_name()!="headless":
		DirAccess.make_dir_recursive_absolute(photo_dir)
		game.hud.hide()
		await create_timer(1.2).timeout
		for view_id in ["goldmine","smelter","tideworks","rocket","rocket-close","rocket-three-quarter","rocket-orbit","rocket-open"]:
			var id="rocket" if view_id.begins_with("rocket") else view_id
			if view_id=="rocket-open":
				game.frontier.finish_for_development(true)
				world.sync_voyage()
				for i in range(34):world.animate_voyage(.1)
			world.desired_rotation=Quaternion(world.surface(game.frontier.target(id)).normalized(),Vector3.UP)
			if view_id=="rocket-three-quarter":world.desired_rotation=Quaternion(Vector3.UP,.92)*world.desired_rotation
			world.globe.quaternion=world.desired_rotation
			if view_id=="rocket-orbit":game.frame_view(Vector3(0,2.0,0),26.0,false)
			else:game.frame_view(Vector3(0,10.4,0),10.5 if view_id.begins_with("rocket") and view_id!="rocket-close" else 7.2,false)
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(photo_dir.path_join(view_id+".png"))
	game.frontier.finish_for_development(true)
	world.sync_voyage()
	world.desired_rotation=Quaternion(a,Vector3.UP)
	world.globe.quaternion=world.desired_rotation
	for i in range(34):world.animate_voyage(.1)
	check(world.trader.arms[0].get_blend_shape_value(world.trader.channels[0][0])>.99 and world.rocket_lamp.visible,"opening the berth submerges the crown and switches on the launch beacon")
	game.closing=true
	game.ambience.shutdown()
	game.queue_free()
	await process_frame
