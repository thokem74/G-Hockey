extends Control

const LOGICAL_SIZE := Vector2(720, 1280)
const DIFFICULTY_NAMES: Array[String] = ["Easy", "Normal", "Hard", "Expert"]
const DEFAULT_OPTIONS: MatchOptions = preload("res://resources/default_match.tres")

var options: MatchOptions = DEFAULT_OPTIONS.duplicate() as MatchOptions
var settings_return: String = "menu"

@onready var content: Control = $Content
@onready var gameplay: Control = $Gameplay
@onready var arena: HockeyArena = $Gameplay/Arena
@onready var modal_dim: ColorRect = $ModalDim
@onready var menu: Control = $Content/Menu
@onready var settings_panel: Control = $Content/SettingsPanel
@onready var hud: Control = $Gameplay/HUD
@onready var overlay: Control = $Content/Overlay
@onready var countdown: Label = $Gameplay/Countdown
@onready var difficulty: Button = $Content/Menu/Difficulty
@onready var score_target: Button = $Content/Menu/ScoreTarget

func _ready() -> void:
	get_tree().auto_accept_quit = false
	get_viewport().size_changed.connect(_fit_content)
	_fit_content()
	_connect_buttons()
	arena.score_changed.connect(_update_score)
	arena.countdown_changed.connect(func(text: String) -> void: countdown.text = text)
	arena.match_finished.connect(_show_result)
	_update_match_option_labels()
	$Content/SettingsPanel/Sounds.value = Settings.effects_volume * 100.0
	$Content/SettingsPanel/Vibration.button_pressed = Settings.vibration
	$Content/SettingsPanel/Shake.button_pressed = Settings.screen_shake
	$Content/SettingsPanel/Reduced.button_pressed = Settings.reduced_effects
	$Content/SettingsPanel/Sounds.value_changed.connect(_set_sounds)
	$Content/SettingsPanel/Vibration.toggled.connect(func(value: bool) -> void: Settings.vibration = value)
	$Content/SettingsPanel/Shake.toggled.connect(func(value: bool) -> void: Settings.screen_shake = value)
	$Content/SettingsPanel/Reduced.toggled.connect(func(value: bool) -> void: Settings.reduced_effects = value)
	_apply_feedback_visibility()
	_show_menu()

func _notification(what: int) -> void:
	if not is_node_ready():
		return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		_pause()
		Audio.stop_all()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		_quit_game()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_back()

func _input(event: InputEvent) -> void:
	# A paddle drag owns its finger until release, even over a score button.
	var owned := false
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		owned = arena.controls.fingers.has(event.index)
	elif event is InputEventMouseMotion or event is InputEventMouseButton:
		owned = arena.controls.fingers.has(-1)
	if owned:
		arena.handle_input(event)
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_back()
		get_viewport().set_input_as_handled()
	else:
		arena.handle_input(event)

func _connect_buttons() -> void:
	$Content/Menu/OnePlayer.pressed.connect(func() -> void: _select_mode(1))
	$Content/Menu/TwoPlayers.pressed.connect(func() -> void: _select_mode(2))
	$Content/Menu/Settings.pressed.connect(func() -> void: _show_settings("menu"))
	$Content/Menu/Quit.pressed.connect(_quit_game)
	$Content/Menu/Start.pressed.connect(_start_match)
	score_target.pressed.connect(_cycle_score_target)
	difficulty.pressed.connect(_cycle_difficulty)
	for button: Button in [$Content/Menu/OnePlayer, $Content/Menu/TwoPlayers, $Content/Menu/Start, score_target, difficulty]:
		button.gui_input.connect(_on_match_button_input.bind(button))
	$Content/SettingsPanel/Back.pressed.connect(_close_settings)
	for score_button: Button in [$Gameplay/HUD/TopScore, $Gameplay/HUD/BottomScore]:
		score_button.pressed.connect(_pause)
		score_button.gui_input.connect(_on_score_input.bind(score_button))
	$Content/Overlay/Resume.pressed.connect(_resume)
	$Content/Overlay/Restart.pressed.connect(_start_match)
	$Content/Overlay/Settings.pressed.connect(func() -> void: _show_settings("pause"))
	$Content/Overlay/Menu.pressed.connect(_show_menu)
	for button in get_tree().get_nodes_in_group("menu_buttons"):
		button.pressed.connect(func() -> void: Audio.play_sound("click", 0.45))

func _fit_content() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var usable := _safe_area(viewport_size)
	var fit := minf(usable.size.x / LOGICAL_SIZE.x, usable.size.y / LOGICAL_SIZE.y)
	content.scale = Vector2.ONE * fit
	content.position = usable.position + (usable.size - LOGICAL_SIZE * fit) * 0.5
	# The game fills the viewport independently of the centered menu canvas.
	var game_scale := viewport_size.x / RinkLayout.LOGICAL_WIDTH
	var logical_size := viewport_size / game_scale
	gameplay.scale = Vector2.ONE * game_scale
	gameplay.size = logical_size
	var previous_state := arena.state
	arena.configure_layout(logical_size)
	hud.size = logical_size
	_layout_scores(Rect2(usable.position / game_scale, usable.size / game_scale))
	countdown.position = Vector2(72, arena.layout.center.y - 80)
	if previous_state != HockeyArena.State.PAUSED and arena.state == HockeyArena.State.PAUSED:
		_show_pause_panel()

func _safe_area(viewport_size: Vector2) -> Rect2:
	var usable := Rect2(Vector2.ZERO, viewport_size)
	if OS.has_feature("android"):
		var screen_size := Vector2(DisplayServer.screen_get_size())
		var safe := Rect2(DisplayServer.get_display_safe_area())
		if screen_size.x > 0.0 and screen_size.y > 0.0 and safe.has_area():
			var ratio := viewport_size / screen_size
			var intersection := usable.intersection(Rect2(safe.position * ratio, safe.size * ratio))
			if intersection.has_area():
				usable = intersection
	return usable

func _layout_scores(safe_area: Rect2) -> void:
	var right := minf(arena.layout.bounds.end.x - 4.0, safe_area.end.x - 8.0)
	var middle := clampf(arena.layout.center.y, safe_area.position.y + 88.0, safe_area.end.y - 88.0)
	$Gameplay/HUD/TopScore.position = Vector2(right - 64.0, middle - 76.0)
	$Gameplay/HUD/BottomScore.position = Vector2(right - 64.0, middle + 12.0)

func _on_score_input(event: InputEvent, button: Button) -> void:
	# Handle native touches even when mouse emulation is disabled for two players.
	if event is InputEventScreenTouch:
		button.accept_event()
		if event.pressed and not event.canceled:
			_pause()

func _hide_panels() -> void:
	menu.hide()
	settings_panel.hide()
	overlay.hide()
	modal_dim.hide()

func _show_menu() -> void:
	_hide_panels()
	arena.return_to_menu()
	gameplay.hide()
	hud.hide()
	_select_mode(options.player_count)
	menu.show()
	countdown.text = ""

func _select_mode(players: int) -> void:
	options.player_count = players
	# Native touch dispatch emits pressed directly, so synchronize toggle states.
	$Content/Menu/OnePlayer.set_pressed_no_signal(players == 1)
	$Content/Menu/TwoPlayers.set_pressed_no_signal(players == 2)

func _cycle_score_target() -> void:
	options.winning_score_index = (options.winning_score_index + 1) % 4
	_update_match_option_labels()

func _cycle_difficulty() -> void:
	options.difficulty = (options.difficulty + 1) % DIFFICULTY_NAMES.size()
	_update_match_option_labels()

func _update_match_option_labels() -> void:
	score_target.text = "GOALS TO WIN\n%d" % options.winning_score()
	difficulty.text = "DIFFICULTY\n%s" % DIFFICULTY_NAMES[options.difficulty]

func _on_match_button_input(event: InputEvent, button: Button) -> void:
	# Mouse emulation is disabled so gameplay can own independent fingers.
	if event is InputEventScreenTouch:
		button.accept_event()
		if event.pressed and not event.canceled:
			button.pressed.emit()

func _start_match() -> void:
	_hide_panels()
	gameplay.show()
	hud.show()
	arena.start_match(options)

func _update_score(bottom: int, top: int) -> void:
	$Gameplay/HUD/BottomScore.text = str(bottom)
	$Gameplay/HUD/TopScore.text = str(top)

func _pause() -> void:
	if arena.state not in [HockeyArena.State.PLAYING, HockeyArena.State.COUNTDOWN, HockeyArena.State.GOAL]:
		return
	arena.pause_match()
	_show_pause_panel()

func _show_pause_panel() -> void:
	_hide_panels()
	$Content/Overlay/Title.text = "TAKE A BREATHER"
	$Content/Overlay/Title.modulate = Color.WHITE
	$Content/Overlay/Subtitle.text = "Your match is paused."
	$Content/Overlay/Restart.position.y = 678.0
	$Content/Overlay/Menu.position.y = 850.0
	$Content/Overlay/Card.size.y = 610.0
	$Content/Overlay/Resume.show()
	$Content/Overlay/Restart.text = "RESTART MATCH"
	$Content/Overlay/Settings.show()
	modal_dim.show()
	overlay.show()

func _resume() -> void:
	overlay.hide()
	modal_dim.hide()
	arena.resume_match()

func _show_result(winner: int) -> void:
	var winner_name := "YOU WIN" if winner == 0 else "AI WINS"
	if options.player_count == 2:
		winner_name = "PLAYER %d WINS" % (winner + 1)
	$Content/Overlay/Title.text = winner_name
	$Content/Overlay/Title.modulate = HockeyArena.CYAN if winner == 0 else HockeyArena.MAGENTA
	$Content/Overlay/Subtitle.text = "%d  —  %d\nReady for another round?" % [arena.scores[0], arena.scores[1]]
	$Content/Overlay/Restart.position.y = 610.0
	$Content/Overlay/Menu.position.y = 708.0
	$Content/Overlay/Card.size.y = 470.0
	$Content/Overlay/Resume.hide()
	$Content/Overlay/Restart.text = "REMATCH"
	$Content/Overlay/Settings.hide()
	modal_dim.show()
	overlay.show()

func _show_settings(origin: String) -> void:
	settings_return = origin
	_hide_panels()
	settings_panel.show()
	modal_dim.visible = origin == "pause"

func _close_settings() -> void:
	var error := Settings.save()
	if error != OK:
		$Content/SettingsPanel/Status.text = "Could not save settings (%d). Tap Back to retry." % error
		return
	_apply_feedback_visibility()
	$Content/SettingsPanel/Status.text = "Saved on this device."
	if settings_return == "pause":
		_show_pause_panel()
	else:
		_show_menu()

func _set_sounds(value: float) -> void:
	Settings.effects_volume = value / 100.0

func _back() -> void:
	if settings_panel.visible:
		_close_settings()
	elif arena.state == HockeyArena.State.PAUSED:
		_resume()
	elif arena.state == HockeyArena.State.FINISHED:
		_show_menu()
	elif not menu.visible:
		_pause()

func _apply_feedback_visibility() -> void:
	if Settings.reduced_effects:
		arena.rink.clear_flashes()
	arena.effects.sparks.visible = not Settings.reduced_effects
	arena.effects.burst.visible = not Settings.reduced_effects
	arena.effects.trail.visible = not Settings.reduced_effects
	$WorldEnvironment.environment.glow_enabled = not Settings.reduced_effects
	# Each reusable scene owns its material, so changing feedback stays local.
	for emitter: CanvasItem in get_tree().get_nodes_in_group("neon_emitters"):
		if is_ancestor_of(emitter):
			var material := emitter.material as ShaderMaterial
			material.set_shader_parameter("emission_strength", 1.0 if Settings.reduced_effects else 2.5)

func _quit_game() -> void:
	await get_tree().process_frame
	Audio.stop_all()
	# Give the audio mixer a frame to release its playbacks before shutdown.
	await get_tree().create_timer(0.08).timeout
	get_tree().quit()
