extends SceneTree

var game
var world
var plan: Dictionary
var output: String
var tracked: Dictionary
var close_offset: Vector3
var coast: Vector3
var written := 0
var failed := false

func _initialize():
	call_deferred("run")

func fail(message: String):
	failed = true
	push_error(message)
	quit(1)

func run():
	var args := OS.get_cmdline_user_args()
	if "--qa" not in args or DisplayServer.get_name() == "headless":
		fail("Recording needs an isolated graphical session.")
		return
	for arg in args:
		if arg.begins_with("--capture-dir="):
			output = arg.trim_prefix("--capture-dir=")
	if not FileAccess.file_exists(output.path_join("plan.json")):
		fail("Missing recording plan.")
		return
	plan = JSON.parse_string(FileAccess.get_file_as_string(output.path_join("plan.json")))
	seed(8703)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	world = game.world
	root.size = Vector2i(plan.width, plan.height)
	DisplayServer.window_set_position(Vector2i(-3000, -2000))
	game.learning.rng.seed = 1201
	game.learning.data.review_style = "text"
	game.cosmos.set_sky_seed(831)
	game.cosmos.set_black_hole(true)
	game.hud.hide()
	for i in 4:
		await process_frame
	if not is_instance_valid(world.avatar):
		fail("Install the personal Feiyu character for the work shot.")
		return
	coast = world.surface(Vector2(-0.4, 0.9))
	var fps := int(plan.fps)
	for scene in plan.scenes:
		var shot := str(scene.shot)
		await start_shot(scene)
		if failed: return
		print("CAPTURE ", shot, " ", scene.frames)
		for index in int(scene.frames):
			var u := float(index) / maxf(1, int(scene.frames)-1)
			direct(shot, index, u, fps, int(scene.frames))
			if failed: return
			await RenderingServer.frame_post_draw
			var img := root.get_texture().get_image()
			if img.get_size() != Vector2i(plan.width, plan.height):
				fail("Unexpected recording dimensions: " + str(img.get_size()))
				return
			if img.save_jpg(output.path_join("%06d.jpg" % written), .96) != OK:
				fail("Could not write frame " + str(written))
				return
			written += 1
			await process_frame
	print("INTRO_COMPLETE ", written)
	game.closing = true
	game.ambience.shutdown()
	game.queue_free()
	await process_frame
	quit()

func face(point: Vector3, width: float, offset: Vector3, lift := 0.0):
	world.globe.quaternion = Quaternion(point.normalized(), Vector3.UP)
	world.desired_rotation = world.globe.quaternion
	var target: Vector3 = world.globe.to_global(point) + Vector3.UP * lift
	game.camera.position = target + offset
	game.camera.look_at(target)
	game.camera.size = width

func start_shot(scene: Dictionary):
	var shot := str(scene.shot)
	game.stop_view_transition()
	game.hud.hide()
	match shot:
		"opening":
			# A flash-forward to the same observatory seen at the end.
			game.frontier.data.progress.mountain = game.frontier.chapter("mountain").need
			game.open_observatory(true)
		"shore":
			game.close_observatory()
			game.frontier.data.progress.mountain = 0
			game.hud.hide()
		"word":
			var id := str(scene.word)
			if not game.learning.wordbooks.contains(scene.book, id):
				fail("The filmed word is missing from the selected book: " + id)
				return
			game.choose_wordbook(scene.book)
			game.select_site("grove")
			game.current = game.word_senses.prepare(game.learning.by_id[id])
			game.hud.show_task()
			game.hud.show()
		"work":
			if game.review_feedback != "next":
				fail("The on-screen word answer was not accepted.")
				return
			game.explore()
			game.stop_view_transition()
			close_offset = Quaternion(world.builder.position.normalized(), Vector3.UP) * (world.builder.basis * Vector3(5, 3.4, -4))
		"growth":
			if world.land.size() != game.frontier.cells().size():
				world.sync_buildings(false)
		"rabbit":
			world.wildlife.land_life.refresh_habitat()
			await frame_rabbit()
		"butterfly":
			tracked = {}
			var best := -INF
			for animal in world.wildlife.animals:
				if animal.kind == "butterfly" and animal.support != Vector3.ZERO and animal.support.distance_to(world.builder.position) > best:
					tracked = animal
					best = animal.support.distance_to(world.builder.position)
			if tracked.is_empty():
				fail("No butterfly landing site.")
				return
			# Advance the real landing animation to its quiet beat before the cut.
			for step in 480:
				if tracked.perch_phase == "perched": break
				world.wildlife._process(.05)
		"archipelago":
			game.frontier.finish_for_development(true)
			world.sync_buildings(false)
		"disk":
			game.open_observatory(true)
	if shot in ["disk", "opening"]:
		if not game.cosmos.observatory_active:
			fail("The black hole close view did not open.")
			return
		move_disk(shot, 0.0)
		game.cosmos.advance_observation(5.0)

func frame_rabbit():
	# Choose a clear sightline in the current habitat. Compare the same frame with
	# and without the rabbit, so a foreground tree cannot be mistaken for the subject.
	paused = true
	var best := 0
	for animal in world.wildlife.land_life.rabbits:
		if not animal.anchor.visible: continue
		var p: Vector3 = animal.anchor.position
		var basis: Basis = Basis(Quaternion(p.normalized(), Vector3.UP)) * animal.anchor.basis
		for direction in [Vector3(3,2.7,-5), Vector3(-3,2.7,-5), Vector3(5,3,0), Vector3(-5,3,0), Vector3(0,6,-3)]:
			var offset: Vector3 = basis * direction
			face(p, 1.55, offset, .19)
			await RenderingServer.frame_post_draw
			var visible_frame := root.get_texture().get_image()
			visible_frame.resize(96, 170)
			animal.model.hide()
			await RenderingServer.frame_post_draw
			var absent := root.get_texture().get_image()
			absent.resize(96, 170)
			animal.model.show()
			var pixels := 0
			for y in range(55, 115):
				for x in range(20, 76):
					var delta := visible_frame.get_pixel(x,y) - absent.get_pixel(x,y)
					if absf(delta.r)+absf(delta.g)+absf(delta.b) > .15: pixels += 1
			if pixels > best:
				best = pixels
				tracked = animal
				close_offset = offset
	paused = false
	if best < 85:
		fail("No clear camera angle for the rabbit.")
		return
	tracked.state = "groom"
	tracked.elapsed = 0.
	tracked.duration = 8.

func move_disk(shot: String, u: float):
	var sky = game.cosmos
	var ease := smoothstep(0., 1., u)
	if shot == "opening":
		sky.observation_pitch = lerpf(.18, .04, ease)
		sky.observation_yaw = lerpf(-.32, .02, ease)
		sky.observation_zoom = lerpf(1.5, 1.33, ease)
	else:
		sky.observation_pitch = lerpf(-.17, .48, ease)
		sky.observation_yaw = lerpf(.1, .9, ease)
		sky.observation_zoom = lerpf(1.18, 1.95, ease)

func show_review():
	# Introductions do not grant work. Wait for a real recall card in this book.
	for i in 24:
		if not game.introducing(): return
		game.introduce_word(game.current.id)
	fail("No recall card appeared.")

func expand_to(site: String, units: int):
	if not game.frontier.choose(site):
		fail("Unavailable filming location: " + site)
		return
	# Replay the book's introductions and correct recalls off camera. Only recall
	# earns work. The matched edits show the accumulated land without a burst of FX.
	var learning = game.learning
	var now := Time.get_unix_time_from_system()
	while game.frontier.data.progress[site] < units:
		var word: Dictionary = learning.next_word(now, [], true)
		if word.is_empty():
			fail("Ran out of practice words during the growth sequence.")
			return
		if learning.needs_intro(word.id):
			learning.introduce(word.id)
			continue
		learning.record(word.id, false, now, false, world.active_kind)
		game.frontier.study_advance()
	world.sync_buildings(true)

func direct(shot: String, index: int, u: float, fps: int, frames: int):
	match shot:
		"opening", "disk":
			move_disk(shot, u)
		"shore", "growth":
			face(coast, 12.8, Vector3(2, 13, 6))
			if shot == "growth":
				if index == roundi(.85*fps): expand_to("grove", 2)
				if index == roundi(2.4*fps): expand_to("grove", 4)
				if index == roundi(4.0*fps): expand_to("grove", 6)
				if index == roundi(5.9*fps): expand_to("quarry", 4)
				if index == roundi(7.3*fps): expand_to("meadow", 4)
		"word":
			if index == roundi(2.0*fps): show_review()
			if index == frames - roundi(1.05*fps):
				if game.word_senses.is_multi(game.current):
					for answer in game.current.correct_indices: game.toggle_word_answer(answer)
					game.submit_word_answers()
				else:
					game.answer(game.current.correct)
		"work":
			face(world.builder.position, lerpf(2.5, 3.2, u), close_offset, .38)
		"rabbit":
			var point: Vector3 = tracked.anchor.position
			# Look towards the nose from slightly off the rabbit's shoulder.
			face(point, 1.55, close_offset, .19)
		"butterfly":
			if index == roundi(2.1*fps):
				var screen: Vector2 = game.camera.unproject_position(tracked.anchor.global_position)
				world.wildlife.handle_tap(screen, true)
			face(tracked.anchor.position, 1.45, Vector3(-2, 11, 3), .035)
		"archipelago":
			face(coast, lerpf(16., 26., smoothstep(0., 1., u)), Vector3(2+2*u, 13, 6), -.6)
		"lookout":
			face(world.facilities.mountain.position, lerpf(7.4, 6.3, u), Vector3(3, 5, 8), .75)
