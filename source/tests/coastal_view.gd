extends SceneTree

var game
var failures=0

func _initialize():
	if not "--qa" in OS.get_cmdline_user_args():quit(2);return
	call_deferred("run")

func sample()->Image:
	await RenderingServer.frame_post_draw
	var frame=root.get_texture().get_image()
	frame.resize(270,600,Image.INTERPOLATE_NEAREST)
	return frame

func marker(c:Color)->bool:return c.r>.68 and c.b>.65 and c.g<.32

func run():
	root.size=Vector2i(540,1200)
	DisplayServer.window_set_size(root.size)
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	game.frontier.finish_for_development(true)
	var world=game.world
	world.sync_buildings(false)
	var ocean=[]
	for part in world.globe.find_children("*","MeshInstance3D",true,false):
		if part.material_override==world.water.material:ocean.append(part)
	assert(not ocean.is_empty())
	# Give the known dry building a measurable color. Compare precisely the
	# same held frame with and without the transparent ocean surface.
	var probe=StandardMaterial3D.new()
	probe.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	probe.albedo_color=Color.MAGENTA
	for part in world.buildings[1].find_children("*","MeshInstance3D",true,false):part.material_override=probe
	game.select_site("windmill")
	await create_timer(.55).timeout
	for i in 9:
		if i%3==0:game.explore()
		elif i%3==1:game.select_site("windmill")
		world.drag(Vector2((i%3-1)*22,12 if i%2 else -12))
		await create_timer(.11).timeout
		paused=true
		var scene=await sample()
		for part in ocean:part.hide()
		var dry=await sample()
		var reference=0;var matched=0
		for y in dry.get_height():
			for x in dry.get_width():
				if marker(dry.get_pixel(x,y)):
					reference+=1
					if marker(scene.get_pixel(x,y)):matched+=1
		if reference<24 or matched<reference*.97:failures+=1
		print("DRY_WINDMILL ",i," ",matched,"/",reference)
		for part in ocean:part.show()
		paused=false
	print("COASTAL_VIEW_RESULT 9 views / ",failures," failed")
	game.closing=true;game.queue_free();await process_frame;quit(int(failures>0))
