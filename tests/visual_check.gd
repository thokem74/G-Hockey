extends Node

func _ready() -> void:
	call_deferred("_run")

func capture(main: Control, name: String) -> void:
	await get_tree().create_timer(0.25).timeout
	await RenderingServer.frame_post_draw
	var image := main.get_viewport().get_texture().get_image()
	if main.get_viewport().use_hdr_2d:
		# Convert before quantizing to 8 bits, preserving dark neon gradients.
		var display_image := Image.create(image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8)
		for y in range(image.get_height()):
			for x in range(image.get_width()):
				display_image.set_pixel(x, y, image.get_pixel(x, y).linear_to_srgb())
		image = display_image
	assert(image.save_png("/tmp/ghockey-" + name + ".png") == OK)


func _run() -> void:
	var old_reduced := Settings.reduced_effects
	Settings.reduced_effects = false
	var main := load("res://scenes/main.tscn").instantiate() as Control
	var viewport := SubViewport.new()
	viewport.use_hdr_2d = true
	viewport.size = Vector2i(720, 1280)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_tree().root.add_child(viewport)
	viewport.add_child(main)
	print("Visual renderer: ", RenderingServer.get_current_rendering_method(), "/", RenderingServer.get_current_rendering_driver_name())
	for display_size in [Vector2i(720, 1280), Vector2i(720, 1620), Vector2i(960, 1280)]:
		viewport.size = display_size
		await get_tree().process_frame
		var suffix := "-%dx%d" % [display_size.x, display_size.y]
		await _capture_layout(main, suffix)
	Settings.reduced_effects = old_reduced
	main._apply_feedback_visibility()
	print("Visual captures saved to /tmp/ghockey-*.png")
	get_tree().root.get_node("Audio").stop_all()
	await get_tree().create_timer(0.08).timeout
	get_tree().quit()

func _capture_layout(main: Control, suffix: String) -> void:
	main._show_menu()
	await capture(main, "menu" + suffix)
	main._show_settings("menu")
	await capture(main, "settings" + suffix)
	main.get_node("Content/Menu/OnePlayer").pressed.emit()
	await capture(main, "countdown" + suffix)
	var arena := main.get_node("Gameplay/Arena") as HockeyArena
	arena.set_physics_process(false)
	arena._physics_process(3.01)
	await capture(main, "game" + suffix)
	# Render an actual trail and both particle types with the HDR material.
	for index in range(12):
		arena.effects.update_trail(arena.puck.position - Vector2(index * 8, index * 5), true)
	arena.effects.impact(arena.bottom.position, HockeyArena.CYAN)
	arena.effects.celebrate(arena.top.position, HockeyArena.MAGENTA)
	await capture(main, "effects" + suffix)
	main._pause()
	await capture(main, "pause" + suffix)
	main._resume()
	arena._physics_process(3.01)
	for goal in range(main.options.winning_score()):
		arena._on_goal(0)
	await capture(main, "result" + suffix)
	main._show_menu()
	main.get_node("Content/Menu/TwoPlayers").pressed.emit()
	arena.set_physics_process(false)
	arena._physics_process(3.01)
	await capture(main, "duel" + suffix)
	Settings.reduced_effects = true
	main._apply_feedback_visibility()
	await capture(main, "reduced-game" + suffix)
	main._show_menu()
	await capture(main, "reduced-menu" + suffix)
	Settings.reduced_effects = false
	main._apply_feedback_visibility()
