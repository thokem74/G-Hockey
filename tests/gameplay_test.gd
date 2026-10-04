extends Node

var failures: int = 0
var checks: int = 0
var pause_transitions: int = 0
var main: Control
var arena: HockeyArena
var viewport: SubViewport

func _ready() -> void:
	call_deferred("_run")

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

func start_match(players: int = 2) -> void:
	main.options.player_count = players
	main.score_target.selected = 0
	main._start_match()
	arena.set_physics_process(false)
	arena._physics_process(3.01)

func touch(index: int, point: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.pressed = pressed
	event.position = arena.get_global_transform_with_canvas() * point
	viewport.push_input(event, true)

func drag(index: int, point: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = arena.get_global_transform_with_canvas() * point
	viewport.push_input(event, true)

func _run() -> void:
	viewport = SubViewport.new()
	viewport.use_hdr_2d = true
	viewport.size = Vector2i(720, 1280)
	get_tree().root.add_child(viewport)
	var previous_reduced := Settings.reduced_effects
	Settings.reduced_effects = true
	main = load("res://scenes/main.tscn").instantiate() as Control
	viewport.add_child(main)
	await get_tree().process_frame
	arena = main.get_node("Gameplay/Arena") as HockeyArena
	_test_bloom(true)
	Settings.reduced_effects = false
	main._apply_feedback_visibility()
	_test_bloom(false)
	Settings.reduced_effects = previous_reduced
	main._apply_feedback_visibility()
	arena.state_changed.connect(func() -> void:
		if arena.state == HockeyArena.State.PAUSED:
			pause_transitions += 1
	)
	main.options.player_count = 2
	main.score_target.selected = 0
	main._start_match()
	arena.set_physics_process(false)
	check(arena.state == HockeyArena.State.COUNTDOWN, "Match begins with countdown")
	arena._physics_process(3.01)
	check(arena.state == HockeyArena.State.PLAYING, "Countdown activates puck")

	for display_size in [Vector2i(720, 1280), Vector2i(720, 1560), Vector2i(720, 1620), Vector2i(960, 1280)]:
		viewport.size = display_size
		await get_tree().process_frame
		start_match()
		_test_layout(display_size)
		_test_controls()
		_test_collisions()
		_test_scoring()
		_test_score_buttons()
		_test_ai()

	# An active resize pauses without resetting score, momentum, or ownership.
	start_match()
	arena.scores = [1, 2]
	arena.puck.velocity = Vector2(500, -400)
	var old_bounds := arena.layout.bounds
	var old_fraction := (arena.puck.position - old_bounds.position) / old_bounds.size
	touch(3, arena.bottom.position, true)
	viewport.size = Vector2i(720, 1620)
	await get_tree().process_frame
	var new_fraction := (arena.puck.position - arena.layout.bounds.position) / arena.layout.bounds.size
	check(arena.state == HockeyArena.State.PAUSED and main.overlay.visible, "Active resize opens pause overlay")
	check(arena.scores == [1, 2], "Resize preserves scores")
	check(arena.puck.velocity == Vector2(500, -400), "Resize preserves puck momentum")
	check(old_fraction.is_equal_approx(new_fraction), "Resize preserves proportional puck position")
	check(arena.controls.fingers.is_empty(), "Resize releases captured fingers")
	main._resume()
	check(arena.state == HockeyArena.State.COUNTDOWN, "Resize resume uses countdown")
	arena._physics_process(3.01)
	check(arena.puck.velocity == Vector2(500, -400), "Countdown does not change preserved momentum")
	start_match()
	arena._on_goal(0)
	main._pause()
	main._resume()
	main._pause()
	main._resume()
	arena._physics_process(3.01)
	check(arena.state == HockeyArena.State.GOAL and arena.scores == [1, 0], "Repeated pause retains pending goal reset")
	arena._physics_process(1.5)
	check(arena.puck.position.is_equal_approx(arena.layout.serve_position(1)), "Interrupted goal still serves to conceding side")

	# Insets move only the HUD; the rink still reaches the full viewport.
	var safe := Rect2(0, 60, 670, arena.layout.logical_size.y - 100)
	main._layout_scores(safe)
	for button: Button in [main.get_node("Gameplay/HUD/TopScore"), main.get_node("Gameplay/HUD/BottomScore")]:
		check(safe.encloses(button.get_rect()), "Score target fits inside safe area")
	check(arena.layout.bounds.end.x == 708, "Safe insets do not shrink rink")
	main._fit_content()
	main._show_setup(1)
	check("Tap either score to pause" in main.get_node("Content/Setup/Hint").text, "Setup explains score buttons")
	_test_settings()
	main.queue_free()
	viewport.queue_free()
	await get_tree().process_frame
	print("Gameplay checks: %d passed, %d failed" % [checks - failures, failures])
	get_tree().quit(1 if failures else 0)

func _test_layout(display_size: Vector2i) -> void:
	var layout := arena.layout
	check(is_equal_approx(layout.logical_size.y, 720.0 * display_size.y / display_size.x), "Logical height follows display aspect")
	check(is_equal_approx(main.gameplay.scale.x, main.gameplay.scale.y), "Gameplay scales uniformly")
	check((main.gameplay.size * main.gameplay.scale).is_equal_approx(Vector2(display_size)), "Gameplay covers whole viewport")
	check(layout.bounds.position == Vector2(12, 12) and layout.bounds.end == layout.logical_size - Vector2(12, 12), "Rails use only twelve-unit edge inset")
	check(arena.controls.layout == layout and arena.puck.layout == layout and arena.ai.layout == layout, "Input, physics, and AI share geometry")
	check(arena.rink.get_node("CenterCircle").position == layout.center, "Visible center circle matches physics center")
	check(arena.rink.get_node("TopLeftEdge").points[1] == layout.bounds.position, "Visible rails match collision bounds")
	check(arena.bottom.position.is_equal_approx(layout.paddle_start(0)), "Bottom paddle uses relative starting position")
	check(arena.top.position.is_equal_approx(layout.paddle_start(1)), "Top paddle uses relative starting position")
	check(arena.puck.position.is_equal_approx(layout.serve_position(0)), "Serve uses relative starting position")
	check(main.countdown.get_rect().get_center().is_equal_approx(layout.center), "Countdown remains centered")
	check(main.modal_dim.size.is_equal_approx(Vector2(display_size)), "Modal dim covers whole display")
	check(not main.hud.has_node("Pause") and not main.hud.has_node("Brand"), "Gameplay has no header or separate pause button")

func _test_controls() -> void:
	var bottom_start := arena.bottom.position
	var top_start := arena.top.position
	touch(0, bottom_start - Vector2(20, 5), true)
	touch(1, top_start + Vector2(20, 5), true)
	touch(2, bottom_start, true)
	check(arena.controls.fingers.size() == 2, "Two independent touches; third touch ignored")
	drag(0, bottom_start + Vector2(100, -100))
	drag(1, top_start + Vector2(-100, 100))
	check(arena.bottom.target.is_equal_approx(bottom_start + Vector2(120, -95)), "Bottom offset preserved through UI dispatch")
	check(arena.top.target.is_equal_approx(top_start + Vector2(-120, 95)), "Top offset preserved through UI dispatch")
	drag(0, arena.top.position)
	arena.bottom.move_toward_target(1.0)
	check(arena.bottom.position.y >= arena.layout.center.y + HockeyPaddle.RADIUS, "Paddle cannot cross center")
	var score := main.get_node("Gameplay/HUD/BottomScore") as Button
	touch(0, score.get_rect().get_center(), false)
	check(not arena.controls.fingers.has(0) and arena.controls.fingers.has(1), "Paddle release over score ends only that finger")
	check(arena.state == HockeyArena.State.PLAYING, "Ending paddle drag over score does not pause")
	touch(1, top_start, false)
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	mouse.position = arena.get_global_transform_with_canvas() * arena.bottom.position
	viewport.push_input(mouse, true)
	check(arena.controls.fingers.has(-1), "Mouse reaches arena")
	mouse.pressed = false
	viewport.push_input(mouse, true)
	check(arena.controls.fingers.is_empty(), "Mouse release clears ownership")

func _test_collisions() -> void:
	var layout := arena.layout
	var bounds := layout.bounds.grow(-HockeyPuck.RADIUS)
	for direction in [-1, 1]:
		arena.puck.reset_at(Vector2(bounds.position.x + 7 if direction == -1 else bounds.end.x - 7, layout.center.y))
		arena.puck.active = true
		arena.puck.velocity = Vector2(direction * 1800, 0)
		arena.puck.simulate(1.0 / 30.0, [])
		check(bounds.grow(0.01).has_point(arena.puck.position) and arena.puck.velocity.x * direction < 0, "Fast puck bounces from side wall")
	for player in [0, 1]:
		var direction := -1 if player == 0 else 1
		arena.puck.reset_at(Vector2(150, bounds.position.y + 5 if player == 0 else bounds.end.y - 5))
		arena.puck.active = true
		arena.puck.velocity = Vector2(0, direction * 1800)
		arena.puck.simulate(1.0 / 30.0, [])
		check(bounds.grow(0.01).has_point(arena.puck.position) and arena.puck.velocity.y * direction < 0, "End wall outside goal remains solid")
	# Each rounded goal post must deflect an incoming puck without scoring.
	for post in layout.goal_posts:
		var direction := -1 if post.y < layout.center.y else 1
		arena.puck.reset_at(post + Vector2(0, -direction * 35))
		arena.puck.active = true
		arena.puck.velocity = Vector2(0, direction * 1200)
		arena.puck.simulate(1.0 / 30.0, [])
		check(arena.puck.active and arena.puck.velocity.y * direction < 0, "Goal post deflects puck")
	arena.bottom.reset_at(layout.serve_position(0) + Vector2(0, 120))
	arena.bottom.target = layout.serve_position(0) - Vector2(0, 40)
	arena.puck.reset_at(layout.serve_position(0))
	arena.puck.active = true
	for step in range(12):
		arena.bottom.move_toward_target(1.0 / 120.0)
		arena.puck.simulate(1.0 / 120.0, [arena.bottom])
	check(arena.puck.velocity.y < -100 and arena.puck.velocity.length() <= 1800, "Moving paddle transfers capped momentum")

func _test_scoring() -> void:
	for player in [0, 1]:
		start_match()
		var direction := -1 if player == 0 else 1
		arena.puck.position = arena.layout.goal_position(player) - Vector2(0, direction * 10)
		arena.puck.velocity = Vector2(0, direction * 1200)
		arena.puck.simulate(0.1, [])
		check(arena.scores[player] == 1 and arena.state == HockeyArena.State.GOAL, "Goal awards correct player")
		arena.puck.simulate(0.1, [])
		check(arena.scores[player] == 1, "Goal counted only once")
		arena._physics_process(1.5)
		check(arena.puck.position.is_equal_approx(arena.layout.serve_position(1 - player)), "Conceding player serves next")
	start_match()
	for goal in range(3):
		arena._on_goal(0)
		if goal < 2:
			arena._physics_process(1.5)
			arena._physics_process(3.01)
	check(arena.state == HockeyArena.State.FINISHED and arena.scores[0] == 3, "Score target finishes match")
	start_match()
	check(arena.scores == [0, 0], "Rematch resets scores")
	for index in range(4):
		var options := MatchOptions.new()
		options.winning_score_index = index
		check(options.winning_score() == [3, 5, 7, 10][index], "Winning target mapping")

func _test_score_buttons() -> void:
	for path in ["Gameplay/HUD/TopScore", "Gameplay/HUD/BottomScore"]:
		for players in [1, 2]:
			start_match(players)
			var button := main.get_node(path) as Button
			check(button.size.x >= 64 and button.size.y >= 64, "Score has large touch target")
			arena.puck.velocity = Vector2(500, -400)
			var previous_position := arena.puck.position
			var previous_transitions := pause_transitions
			touch(8, button.get_rect().get_center(), true)
			touch(8, button.get_rect().get_center(), false)
			check(arena.state == HockeyArena.State.PAUSED and main.overlay.visible, "Either score pauses solo and local matches")
			check(pause_transitions == previous_transitions + 1, "Score tap pauses exactly once")
			check(arena.controls.fingers.is_empty(), "Score touch never captures paddle")
			arena._physics_process(0.5)
			check(arena.puck.position == previous_position, "Pause freezes puck")
			main._resume()
			check(arena.state == HockeyArena.State.COUNTDOWN and not main.modal_dim.visible, "Resume starts countdown and removes dim")
			arena._physics_process(3.01)
			check(arena.puck.velocity == Vector2(500, -400), "Resume preserves momentum")
	# Mouse clicks also activate the score button through Godot GUI dispatch.
	start_match()
	var button := main.get_node("Gameplay/HUD/BottomScore") as Button
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	mouse.position = button.get_global_rect().get_center()
	viewport.push_input(mouse, true)
	mouse.pressed = false
	viewport.push_input(mouse, true)
	check(arena.state == HockeyArena.State.PAUSED, "Mouse click on score pauses")

func _test_ai() -> void:
	for level in range(4):
		main.difficulty.selected = level
		start_match(1)
		arena.ai.rng.seed = 42
		touch(1, arena.top.position, true)
		check(arena.controls.fingers.is_empty(), "Solo mode ignores top-half touch")
		for step in range(400):
			arena.ai.update_target(1.0 / 120.0, arena.top, arena.layout.serve_position(1), Vector2(-700, -500))
			arena.top.move_toward_target(1.0 / 120.0, arena.ai.profile.movement_speed)
		check(arena.top.court.grow(0.01).has_point(arena.top.position), "AI obeys adapted court at every difficulty")
	var puck_bounds := arena.layout.bounds.grow(-HockeyPuck.RADIUS)
	for value in [-4000, 5000]:
		check(arena.ai.reflected_x(value) >= puck_bounds.position.x and arena.ai.reflected_x(value) <= puck_bounds.end.x, "AI reflects predictions inside actual walls")

func _test_bloom(reduced: bool) -> void:
	var environment: Environment = main.get_node("WorldEnvironment").environment
	check(environment.background_mode == Environment.BG_CANVAS, "Environment processes the 2D canvas")
	check(environment.glow_enabled == not reduced, "Reduced effects controls HDR bloom")
	check(viewport.use_hdr_2d, "Reduced effects preserves HDR rendering")
	for emitter: CanvasItem in get_tree().get_nodes_in_group("neon_emitters"):
		if main.is_ancestor_of(emitter):
			var material := emitter.material as ShaderMaterial
			check(is_equal_approx(material.get_shader_parameter("emission_strength"), 1.0 if reduced else 2.5), "Gameplay and preview emission follows feedback settings: " + str(emitter.get_path()))
	check(arena.effects.trail.visible == not reduced, "Reduced effects controls trail visibility")
	check(arena.effects.sparks.visible == not reduced and arena.effects.burst.visible == not reduced, "Reduced effects controls particles")

func _test_settings() -> void:
	# Preserve developer preferences while exercising persistence.
	var save_path := ProjectSettings.globalize_path("user://settings.cfg")
	var existed := FileAccess.file_exists(save_path)
	var backup := FileAccess.get_file_as_bytes(save_path) if existed else PackedByteArray()
	var settings := get_tree().root.get_node("Settings")
	var old_music: float = settings.music_volume
	var old_reduced: bool = settings.reduced_effects
	settings.music_volume = 0.23
	main._show_settings("menu")
	main.get_node("Content/SettingsPanel/Reduced").set_pressed_no_signal(false)
	main.get_node("Content/SettingsPanel/Reduced").button_pressed = true
	main._close_settings()
	_test_bloom(true)
	check(settings.save() == OK, "Settings save succeeds")
	var config := ConfigFile.new()
	check(config.load(save_path) == OK and is_equal_approx(config.get_value("audio", "music"), 0.23), "Settings persist to disk")
	check(config.get_value("feedback", "reduced_effects", false) == true, "Reduced effects persists to disk")
	settings.reduced_effects = false
	settings._ready()
	main._apply_feedback_visibility()
	_test_bloom(true)
	settings.music_volume = old_music
	settings.reduced_effects = old_reduced
	main._apply_feedback_visibility()
	if existed:
		var file := FileAccess.open(save_path, FileAccess.WRITE)
		file.store_buffer(backup)
		file.close()
	else:
		DirAccess.remove_absolute(save_path)
