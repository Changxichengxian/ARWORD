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

func visible_label(label:String):
	for text in game.hud.overlay.find_children("*","Label",true,false):
		if text.is_visible_in_tree() and text.text==label:return text
	return null

func settle():
	for i in range(3):await process_frame

func run():
	var args=OS.get_cmdline_user_args()
	if not "--qa" in args or not "--qa-with-cast" in args:
		push_error("QA_REQUIRED: use --qa --qa-with-cast for isolated character checks")
		quit(2)
		return
	var scope=""
	for arg in args:
		if arg.begins_with("--qa-avatar-scope="):scope=arg.trim_prefix("--qa-avatar-scope=").validate_filename()
	if scope in ["", ".", ".."]:
		push_error("QA_REQUIRED: provide an isolated --qa-avatar-scope for the old-choice startup check")
		quit(2)
		return
	var directory="user://qa-characters/".path_join(scope)
	DirAccess.make_dir_recursive_absolute(directory)
	var old_choice=ConfigFile.new();old_choice.set_value("cast","id","default")
	check(old_choice.save(directory.path_join("choice.cfg"))==OK,"the isolated fixture starts with the retired default-character choice")
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	game.closing=true;game.ambience.shutdown();game.speech.stop();game.speech.stream=null;game.world.set_process(false)
	var history=JSON.stringify(game.learning.data)
	check(not game.world.builder.visible and not game.world.actor.find_child("ContinuousBody",true,false).visible,"startup keeps the invisible motion rig hidden before the private character loads")
	await settle()
	check(game.cast_store.folder.begins_with("user://qa-characters/"),"character test uses an isolated directory")
	check(game.cast_store.saved_for_update,"personal installation caches the approved character for later updates")
	check(game.fixed_character=="deepseek" and is_instance_valid(game.world.avatar) and game.cast_store.preferred()=="deepseek","an old default choice automatically uses the approved fish character")
	check(game.world.builder.is_visible_in_tree() and game.world.avatar.is_visible_in_tree() and not game.world.actor.find_child("ContinuousBody",true,false).visible,"the fish is visible while the underlying motion rig stays hidden")
	if is_instance_valid(game.world.avatar):
		check(game.world.avatar.used_baked_surfaces==9 and game.world.avatar.foot_probes.size()>0,"all nine character surfaces use precomputed contact points")
	game.settings();await settle()
	var character=visible_button("人物")
	check(character!=null,"settings contains character information")
	if character:character.pressed.emit()
	await settle()
	check(visible_label("大肥鱼")!=null and visible_label("DeepSeek 娘 · 木子恶魔")!=null,"the character page shows the fish name and attribution")
	check(visible_button("✓  大肥鱼")==null and visible_button("大肥鱼")==null and visible_button("默认人物")==null,"the character page has no character-switching controls")
	check(visible_button("选择 VRM 模型")==null,"no file picker action appears")
	var identity=game.world.avatar.get_instance_id()
	check(not game.apply_fixed_character("default",true) and game.world.avatar.get_instance_id()==identity and game.fixed_character=="deepseek" and not game.cast_store.remember("default"),"the retired default ID cannot replace or persist over the active fish")
	var public_cast=preload("res://scripts/fixed_cast.gd").new(game.cast_store.folder)
	public_cast.prepare("","")
	check(public_cast.saved_for_update and public_cast.preferred()=="deepseek","a build without the private model recovers the existing approved cache")
	game.world.worker.carry.show();game.world.set_tool(0);game.world.clear_local_avatar()
	var hidden=not game.world.builder.is_visible_in_tree() and not game.world.actor.find_child("ContinuousBody",true,false).visible and not game.world.worker.carry.is_visible_in_tree()
	for tool in game.world.tools.values():hidden=hidden and not tool.is_visible_in_tree()
	check(game.world.avatar==null and hidden,"clearing the character exposes neither the white rig nor floating tools and cargo")
	var restored=game.world.load_local_avatar(game.cast_store.model_path)
	check(restored.ok and game.world.builder.is_visible_in_tree() and game.world.avatar.is_visible_in_tree() and not game.world.actor.find_child("ContinuousBody",true,false).visible,"reloading the approved fish restores visible character rendering")
	var installed_store=game.cast_store
	var missing_cast=preload("res://scripts/fixed_cast.gd").new(directory.path_join("no-private-model"));missing_cast.prepare("","")
	game.world.clear_local_avatar();game.cast_store=missing_cast;game.fixed_character="";game.show_avatar_settings();await settle()
	check(missing_cast.preferred().is_empty() and visible_label("大肥鱼尚未安装")!=null and visible_button("默认人物")==null and not game.world.builder.is_visible_in_tree(),"without a private model the page explains installation and keeps the rig hidden")
	game.cast_store=installed_store
	check(game.apply_fixed_character("deepseek",false),"the private character can be restored after the missing-model check")
	game.show_avatar_settings();await settle()
	check(history==JSON.stringify(game.learning.data),"character migration, rejection and reload leave learning and construction records intact")
	for arg in args:
		if arg.begins_with("--visual-out=") and DisplayServer.get_name()!="headless":
			var output=arg.trim_prefix("--visual-out=")
			DirAccess.make_dir_recursive_absolute(output)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output.path_join("fixed-characters.png"))
	print("FIXED_CAST_RESULT ",count," checks / ",failures," failed")
	game.queue_free();await settle();game=null
	quit.call_deferred(0 if failures==0 else 1)
