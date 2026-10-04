extends Node

func _ready() -> void:
	call_deferred("_run")

func capture(main: Control, name: String) -> void:
	await get_tree().create_timer(0.25).timeout
	await RenderingServer.frame_post_draw
	main.get_viewport().get_texture().get_image().save_png("/tmp/ghockey-" + name + ".png")

func _run() -> void:
	var main := load("res://scenes/main.tscn").instantiate() as Control
	var viewport := SubViewport.new()
	viewport.size = Vector2i(720, 1280)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_tree().root.add_child(viewport)
	viewport.add_child(main)
	await capture(main, "menu")
	main._show_setup(1)
	await capture(main, "setup")
	main._show_settings("menu")
	await capture(main, "settings")
	main._start_match()
	await capture(main, "countdown")
	var arena := main.get_node("Gameplay/Arena") as HockeyArena
	arena.set_physics_process(false)
	arena._physics_process(3.01)
	await capture(main, "game")
	main._pause()
	await capture(main, "pause")
	main._resume()
	arena._physics_process(3.01)
	for goal in range(main.options.winning_score()):
		arena._on_goal(0)
	await capture(main, "result")
	main._show_setup(2)
	await capture(main, "duel-setup")
	main._start_match()
	arena.set_physics_process(false)
	arena._physics_process(3.01)
	await capture(main, "duel")
	viewport.size = Vector2i(960, 1280)
	await get_tree().process_frame
	main._resume()
	arena._physics_process(3.01)
	await capture(main, "tablet")
	main._pause()
	main._show_settings("pause")
	await capture(main, "tablet-settings")
	viewport.size = Vector2i(720, 1620)
	await get_tree().process_frame
	main._start_match()
	arena.set_physics_process(false)
	arena._physics_process(3.01)
	await capture(main, "tall-phone")
	main._show_menu()
	await capture(main, "tall-phone-menu")
	print("Visual captures saved to /tmp/ghockey-*.png")
	get_tree().root.get_node("Audio").stop_all()
	await get_tree().create_timer(0.08).timeout
	get_tree().quit()
