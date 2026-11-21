extends SceneTree

var failures := 0
var captures := ""
var game
var world
var sun: DirectionalLight3D

func _initialize():
	if not "--qa" in OS.get_cmdline_user_args():
		quit(2)
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--captures="):
			captures = arg.trim_prefix("--captures=")
			DirAccess.make_dir_recursive_absolute(captures)
	call_deferred("run")

func check(ok: bool, label: String):
	if not ok:
		failures += 1
	print("PASS " if ok else "FAIL ", label)

func capture(label: String):
	if captures.is_empty():
		return
	for frame in 3:
		await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(captures.path_join(label + ".png")) == OK, label)

func fixture_mesh(parent: Node3D, shape: Mesh, at: Vector3):
	var mesh := MeshInstance3D.new()
	mesh.mesh = shape
	mesh.position = at
	var matte := StandardMaterial3D.new()
	matte.albedo_color = Color(0.8, 0.8, 0.8)
	matte.metallic_specular = 0.0
	mesh.material_override = matte
	parent.add_child(mesh)

# Measure the rendered shadow edge against the projection of the box's top
# corner onto a flat receiver. Subtracting the expected movement leaves jitter.
func edge_error(fixture: Node3D, image: Image, along := 0.0) -> float:
	var ray := fixture.global_basis.inverse() * -sun.global_basis.z
	var edge_x := 0.25 + 1.5 * ray.x / -ray.y
	var pixel: Vector2 = game.camera.unproject_position(fixture.to_global(Vector3(edge_x, 0, along)))
	var x := roundi(pixel.x)
	var y := roundi(pixel.y)
	var reach := maxi(7, roundi(0.46 * image.get_width() / game.camera.size))
	var dark := image.get_pixel(x - reach, y).r
	var bright := image.get_pixel(x + reach, y).r
	if bright - dark < 0.08:
		return NAN
	var middle := (dark + bright) * 0.5
	for col in range(x - reach, x + reach):
		var left := image.get_pixel(col, y).r
		var right := image.get_pixel(col + 1, y).r
		if left <= middle and right > middle:
			return col + 0.5 + (middle - left) / (right - left) - pixel.x
	return NAN

func measure_drag(fixture: Node3D, zoom: float):
	world.globe.quaternion = Quaternion(Vector3.UP, deg_to_rad(12))
	world.desired_rotation = world.globe.quaternion
	game.frame_view(fixture.global_position, zoom, false)
	for warmup in 4:
		await RenderingServer.frame_post_draw
	var errors := PackedFloat32Array()
	var steps := PackedFloat32Array()
	var contour := PackedFloat32Array()
	for frame in 61:
		world.drag(Vector2(0.14, -0.22))
		world._process(1.0 / 60.0)
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		var error := edge_error(fixture, image, -0.3)
		if is_nan(error):
			await capture("missing-%.1f" % zoom)
			check(false, "no distinct shadow edge at zoom %.1f frame %d" % [zoom, frame])
			return
		if not errors.is_empty():
			steps.append(absf(error - errors[-1]))
		errors.append(error)
		if frame == 30:
			if not captures.is_empty():
				check(image.save_png(captures.path_join("straight-%.1f.png" % zoom)) == OK, "saved straight edge")
			for sample in 41:
				var residual := edge_error(fixture, image, lerpf(-1.0, -0.2, sample / 40.0))
				if is_finite(residual):
					contour.append(residual)
	steps.sort()
	contour.sort()
	check(contour.size() == 41, "sampled whole straight edge")
	if contour.size() == 41:
		print("EDGE zoom=%.1f p95=%.3f peak=%.3f contour=%.3f pixels" % [zoom, steps[56], steps[-1], contour[38] - contour[2]])
		var close_up := zoom < 6.0
		check(steps[56] < (2.4 if close_up else 1.25), "slow drag stays within its pixel tolerance")
		check(contour[38] - contour[2] < (3.2 if close_up else 1.6), "straight shadow edge stays within its pixel tolerance")

func run():
	if DisplayServer.get_name() == "headless":
		push_error("This check measures actual rendered pixels")
		quit(2)
		return
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	DisplayServer.window_set_size(Vector2i(540, 960))
	DisplayServer.window_set_position(Vector2i(-2200, -1600))
	await process_frame
	game.frontier.finish_for_development(true)
	world = game.world
	world.sync_buildings(false)
	game.explore(true, false)
	game.hud.hide()
	game.stop_view_transition()
	game.process_mode = Node.PROCESS_MODE_DISABLED
	# The phone's shadow map and 3D render scale are also reproducible on desktop.
	RenderingServer.directional_shadow_atlas_set_size(2048, true)
	root.scaling_3d_scale = .85
	for node in world.find_children("*", "DirectionalLight3D", true, false):
		if node.shadow_enabled:
			sun = node
			break
	check(sun != null, "shadow-casting sun present")
	if sun == null:
		quit(1)
		return
	var light_frame := sun.global_transform
	var house: Node3D = world.buildings[0]
	world.globe.quaternion = Quaternion(house.position.normalized(), Vector3.UP)
	world.desired_rotation = world.globe.quaternion
	game.frame_view(house.global_position, 7.8, false)
	await capture("cottage-start")
	world.drag(Vector2(55, 28))
	for frame in 45:
		world._process(1.0 / 60.0)
	check(light_frame.is_equal_approx(sun.global_transform), "drag keeps main light fixed in world space")
	await capture("cottage-drag")
	for child in world.globe.get_children():
		if child is Node3D:
			child.hide()
	var fixture := Node3D.new()
	world.globe.add_child(fixture)
	fixture.position = Vector3(0, IslandTerrain.RADIUS, -1.8)
	var plane := PlaneMesh.new()
	plane.size = Vector2(8, 8)
	fixture_mesh(fixture, plane, Vector3.ZERO)
	var box := BoxMesh.new()
	box.size = Vector3(0.5, 1.5, 3)
	fixture_mesh(fixture, box, Vector3.UP * 0.75)
	for zoom in [5.0, 11.0, 25.5]:
		await measure_drag(fixture, zoom)
	game.closing = true
	game.ambience.shutdown()
	game.queue_free()
	await process_frame
	print("PLANET_SHADOWS_RESULT ", failures, " failed")
	quit(int(failures > 0))
