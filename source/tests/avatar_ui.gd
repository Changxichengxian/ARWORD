extends SceneTree

var game
var failures=0
var count=0

func _initialize():call_deferred("run")

func check(ok:bool,label:String):
	count+=1
	if not ok:failures+=1
	print("PASS " if ok else "FAIL ",label)

func visible_button(label:String):
	for button in game.hud.overlay.find_children("*","Button",true,false):
		if button.is_visible_in_tree() and button.text==label:return button
	return null

func settle():
	for i in range(3):await process_frame

func run():
	var args=OS.get_cmdline_user_args()
	if not "--qa" in args or not "--qa-with-cast" in args:
		push_error("QA_REQUIRED: use --qa --qa-with-cast for isolated character checks")
		quit(2)
		return
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await settle()
	var history=JSON.stringify(game.learning.data)
	check(game.cast_store.folder.begins_with("user://qa-characters/"),"character test uses an isolated directory")
	check(game.cast_store.saved_for_update,"personal installation caches the approved character for later updates")
	check(game.fixed_character=="deepseek" and is_instance_valid(game.world.avatar),"new personal installation has the actual fish character on the planet")
	check(not game.world.actor.find_child("ContinuousBody",true,false).visible,"fallback body is hidden when the character is active")
	if is_instance_valid(game.world.avatar):
		check(game.world.avatar.used_baked_surfaces==9 and game.world.avatar.foot_probes.size()>0,"all nine character surfaces use precomputed contact points")
	game.settings();await settle()
	var character=visible_button("人物")
	check(character!=null,"settings contains character selection")
	if character:character.pressed.emit()
	await settle()
	check(visible_button("✓  大肥鱼")!=null and visible_button("默认人物")!=null,"character page offers the two authored characters")
	check(visible_button("选择 VRM 模型")==null,"no file picker action appears")
	var fallback=visible_button("默认人物")
	if fallback:fallback.pressed.emit()
	await settle()
	check(game.fixed_character=="default" and not is_instance_valid(game.world.avatar) and game.cast_store.preferred()=="default","fallback selection activates and persists")
	var fish=visible_button("大肥鱼")
	if fish:fish.pressed.emit()
	await settle()
	check(game.fixed_character=="deepseek" and is_instance_valid(game.world.avatar),"fish button activates the rig without asking for a file")
	var public_cast=preload("res://scripts/fixed_cast.gd").new(game.cast_store.folder)
	public_cast.prepare("","")
	check(public_cast.saved_for_update and public_cast.preferred()=="deepseek","a build without the model recovers the private character and choice")
	check(history==JSON.stringify(game.learning.data),"switching characters leaves learning and construction records intact")
	for arg in args:
		if arg.begins_with("--visual-out=") and DisplayServer.get_name()!="headless":
			var output=arg.trim_prefix("--visual-out=")
			DirAccess.make_dir_recursive_absolute(output)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output.path_join("fixed-characters.png"))
	print("FIXED_CAST_RESULT ",count," checks / ",failures," failed")
	game.closing=true;game.queue_free();await settle()
	quit(0 if failures==0 else 1)
