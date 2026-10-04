extends Node

var failures: int = 0
var checks: int = 0

func _ready() -> void:
	call_deferred("_run")

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

func _run() -> void:
	var main := load("res://scenes/main.tscn").instantiate() as Control
	get_tree().root.add_child(main)
	await get_tree().process_frame
	var arena := main.get_node("Content/Arena") as HockeyArena
	var options := MatchOptions.new()
	options.player_count = 2
	options.winning_score_index = 0
	main.options = options
	main.score_target.selected = 0
	main._start_match()
	arena.set_physics_process(false)
	check(arena.state == HockeyArena.State.COUNTDOWN, "Match begins with countdown")
	arena._physics_process(3.01)
	check(arena.state == HockeyArena.State.PLAYING, "Countdown activates puck")

	# Exercise Godot's event dispatch, not just the controller methods.
	var transform := arena.get_global_transform_with_canvas()
	var press := InputEventScreenTouch.new()
	press.index = 7
	press.pressed = true
	press.position = transform * Vector2(360, 985)
	get_tree().root.push_input(press, true)
	await get_tree().process_frame
	check(arena.controls.fingers.has(7), "Touch passes through gameplay UI to arena")
	var drag := InputEventScreenDrag.new()
	drag.index = 7
	drag.position = transform * Vector2(460, 900)
	get_tree().root.push_input(drag, true)
	await get_tree().process_frame
	check(arena.bottom.target.is_equal_approx(Vector2(460, 900)), "Touch drag transforms viewport coordinates")
	press.pressed = false
	press.position = transform * Vector2(600, 52)
	get_tree().root.push_input(press, true)
	check(not arena.controls.fingers.has(7), "Touch release over a HUD button ends finger ownership")
	arena.controls.clear()
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	mouse.position = transform * Vector2(360, 985)
	get_tree().root.push_input(mouse, true)
	await get_tree().process_frame
	check(arena.controls.fingers.has(-1), "Mouse passes through gameplay UI to arena")
	mouse.pressed = false
	get_tree().root.push_input(mouse, true)
	arena.controls.clear()

	# Finger ownership, offsets, ignored extra fingers, and crossing the midline.
	arena.controls.press(0, Vector2(340, 980))
	arena.controls.press(1, Vector2(380, 350))
	arena.controls.press(2, Vector2(400, 900))
	check(arena.controls.fingers.size() == 2, "Two independent touches; third touch ignored")
	arena.controls.drag(0, Vector2(500, 800))
	arena.controls.drag(1, Vector2(200, 450))
	check(arena.bottom.target == Vector2(520, 805), "Bottom finger offset preserved")
	check(arena.top.target == Vector2(180, 455), "Top finger offset preserved")
	arena.controls.drag(0, Vector2(500, 300))
	arena.bottom.move_toward_target(1.0)
	check(arena.bottom.position.y >= 714.0, "Paddle cannot cross center")
	arena.controls.release(1)
	check(arena.controls.fingers.has(0) and not arena.controls.fingers.has(1), "Releasing one finger preserves the other")
	arena.controls.clear()

	# Fast puck must bounce, and a fast paddle must transfer momentum.
	arena.puck.reset_at(Vector2(75, 700))
	arena.puck.active = true
	arena.puck.velocity = Vector2(-1800, 0)
	arena.puck.simulate(1.0 / 30.0, [])
	check(arena.puck.position.x >= 68.0 and arena.puck.velocity.x > 0, "Fast puck cannot tunnel through side wall")
	arena.puck.reset_at(Vector2(150, 235))
	arena.puck.active = true
	arena.puck.velocity = Vector2(0, -1800)
	arena.puck.simulate(1.0 / 30.0, [])
	check(arena.puck.position.y >= 230.0 and arena.puck.velocity.y > 0, "Top wall outside goal remains solid")
	arena.bottom.reset_at(Vector2(360, 920))
	arena.bottom.target = Vector2(360, 760)
	arena.puck.reset_at(Vector2(360, 800))
	arena.puck.active = true
	for step in range(12):
		arena.bottom.move_toward_target(1.0 / 120.0)
		arena.puck.simulate(1.0 / 120.0, [arena.bottom])
	check(arena.puck.velocity.y < -100 and arena.puck.velocity.length() <= 1800, "Moving paddle strikes stationary puck with capped speed")

	# Scoring is emitted by physics, once, then the conceding side serves.
	arena.start_match(options)
	arena.set_physics_process(false)
	arena._physics_process(3.01)
	arena.puck.position = Vector2(360, 220)
	arena.puck.velocity = Vector2(0, -1200)
	arena.puck.simulate(0.1, [])
	check(arena.scores == [1, 0] and arena.state == HockeyArena.State.GOAL, "Top goal scores for bottom player")
	arena.puck.simulate(0.1, [])
	check(arena.scores == [1, 0], "Inactive puck does not duplicate goal")
	arena._physics_process(1.5)
	check(arena.puck.position.y == 520, "Conceding top player receives puck")
	arena._physics_process(3.01)
	arena.puck.velocity = Vector2(500, -400)
	arena.pause_match()
	var frozen_position := arena.puck.position
	arena._physics_process(0.5)
	check(arena.puck.position == frozen_position, "Pause freezes match")
	arena.resume_match()
	check(arena.state == HockeyArena.State.COUNTDOWN, "Resume starts countdown")
	arena._physics_process(3.01)
	check(arena.puck.velocity == Vector2(500, -400), "Resume preserves puck velocity")
	arena._on_goal(0)
	arena._physics_process(1.5)
	arena._physics_process(3.01)
	arena._on_goal(0)
	check(arena.state == HockeyArena.State.FINISHED and arena.scores[0] == 3, "Winning score finishes match")
	arena.start_match(options)
	arena.set_physics_process(false)
	check(arena.scores == [0, 0], "Rematch resets scores")

	for target in range(4):
		options.winning_score_index = target
		check(options.winning_score() == [3, 5, 7, 10][target], "Winning target mapping")
	for level in range(4):
		options.player_count = 1
		options.difficulty = level
		arena.start_match(options)
		arena.set_physics_process(false)
		arena.ai.rng.seed = 42
		arena.controls.press(1, Vector2(360, 350))
		check(arena.controls.fingers.is_empty(), "Solo mode ignores top-half touch")
		for step in range(400):
			arena.ai.update_target(1.0 / 120.0, arena.top, Vector2(80, 280), Vector2(-700, -500))
			arena.top.move_toward_target(1.0 / 120.0, arena.ai.profile.movement_speed)
		check(arena.top.court.grow(0.01).has_point(arena.top.position), "AI stays inside its court at every difficulty")
	check(arena.ai.reflected_x(-4000) >= 68 and arena.ai.reflected_x(5000) <= 652, "AI predictions reflect distant wall bounces")

	# Settings are tested with a backup so developer preferences are restored.
	var save_path := ProjectSettings.globalize_path("user://settings.cfg")
	var existed := FileAccess.file_exists(save_path)
	var backup := FileAccess.get_file_as_bytes(save_path) if existed else PackedByteArray()
	var settings := get_tree().root.get_node("Settings")
	var old_music: float = settings.music_volume
	settings.music_volume = 0.23
	check(settings.save() == OK, "Settings save succeeds")
	var config := ConfigFile.new()
	check(config.load(save_path) == OK and is_equal_approx(config.get_value("audio", "music"), 0.23), "Settings persist to disk")
	settings.music_volume = old_music
	if existed:
		var file := FileAccess.open(save_path, FileAccess.WRITE)
		file.store_buffer(backup)
		file.close()
	else:
		DirAccess.remove_absolute(save_path)
	arena.return_to_menu()
	main.queue_free()
	await get_tree().process_frame
	print("Gameplay checks: %d passed, %d failed" % [checks - failures, failures])
	get_tree().quit(1 if failures else 0)
