extends Control

const LOGICAL_SIZE := Vector2(720, 1280)
const DEFAULT_OPTIONS: MatchOptions = preload("res://resources/default_match.tres")

var options: MatchOptions = DEFAULT_OPTIONS.duplicate() as MatchOptions
var settings_return: String = "menu"

@onready var content: Control = $Content
@onready var arena: HockeyArena = $Content/Arena
@onready var menu: Control = $Content/Menu
@onready var setup: Control = $Content/Setup
@onready var settings_panel: Control = $Content/SettingsPanel
@onready var hud: Control = $Content/HUD
@onready var overlay: Control = $Content/Overlay
@onready var countdown: Label = $Content/Countdown
@onready var difficulty: OptionButton = $Content/Setup/Difficulty
@onready var score_target: OptionButton = $Content/Setup/ScoreTarget

func _ready() -> void:
	get_tree().auto_accept_quit = false
	get_viewport().size_changed.connect(_fit_content)
	_fit_content()
	_connect_buttons()
	arena.score_changed.connect(_update_score)
	arena.countdown_changed.connect(func(text: String) -> void: countdown.text = text)
	arena.match_finished.connect(_show_result)
	difficulty.selected = options.difficulty
	score_target.selected = options.winning_score_index
	$Content/SettingsPanel/Music.value = Settings.music_volume * 100.0
	$Content/SettingsPanel/Sounds.value = Settings.effects_volume * 100.0
	$Content/SettingsPanel/Vibration.button_pressed = Settings.vibration
	$Content/SettingsPanel/Shake.button_pressed = Settings.screen_shake
	$Content/SettingsPanel/Reduced.button_pressed = Settings.reduced_effects
	$Content/SettingsPanel/Music.value_changed.connect(_set_music)
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
		Audio.music.stream_paused = true
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_APPLICATION_RESUMED:
		Audio.apply_settings()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		_quit_game()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_back()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_back()
		get_viewport().set_input_as_handled()
	else:
		arena.handle_input(event)

func _connect_buttons() -> void:
	$Content/Menu/OnePlayer.pressed.connect(func() -> void: _show_setup(1))
	$Content/Menu/TwoPlayers.pressed.connect(func() -> void: _show_setup(2))
	$Content/Menu/Settings.pressed.connect(func() -> void: _show_settings("menu"))
	$Content/Menu/Quit.pressed.connect(_quit_game)
	$Content/Setup/Start.pressed.connect(_start_match)
	$Content/Setup/Back.pressed.connect(_show_menu)
	$Content/SettingsPanel/Back.pressed.connect(_close_settings)
	$Content/HUD/Pause.pressed.connect(_pause)
	$Content/Overlay/Resume.pressed.connect(_resume)
	$Content/Overlay/Restart.pressed.connect(_start_match)
	$Content/Overlay/Settings.pressed.connect(func() -> void: _show_settings("pause"))
	$Content/Overlay/Menu.pressed.connect(_show_menu)
	for button in get_tree().get_nodes_in_group("menu_buttons"):
		button.pressed.connect(func() -> void: Audio.play_sound("click", 0.45))

func _fit_content() -> void:
	var viewport_size := get_viewport_rect().size
	var usable := Rect2(Vector2.ZERO, viewport_size)
	if OS.has_feature("android"):
		var screen_size := Vector2(DisplayServer.screen_get_size())
		var safe := Rect2(DisplayServer.get_display_safe_area())
		if screen_size.x > 0.0 and screen_size.y > 0.0 and safe.has_area():
			var ratio := viewport_size / screen_size
			usable = Rect2(safe.position * ratio, safe.size * ratio)
	var fit := minf(usable.size.x / LOGICAL_SIZE.x, usable.size.y / LOGICAL_SIZE.y)
	content.scale = Vector2.ONE * fit
	content.position = usable.position + (usable.size - LOGICAL_SIZE * fit) * 0.5

func _hide_panels() -> void:
	menu.hide()
	setup.hide()
	settings_panel.hide()
	overlay.hide()

func _show_menu() -> void:
	_hide_panels()
	arena.return_to_menu()
	hud.hide()
	menu.show()
	countdown.text = ""

func _show_setup(players: int) -> void:
	_hide_panels()
	options.player_count = players
	$Content/Setup/Title.text = "SOLO MATCH" if players == 1 else "LOCAL DUEL"
	$Content/Setup/Description.text = "You vs. the machine" if players == 1 else "Two players. One screen."
	difficulty.visible = players == 1
	$Content/Setup/DifficultyLabel.visible = players == 1
	$Content/Setup/Hint.text = "Drag on your half to move.\nStrike the puck into the top goal." if players == 1 else "Sit at opposite ends of the device.\nEach player drags on their own half."
	setup.show()

func _start_match() -> void:
	options.difficulty = difficulty.selected
	options.winning_score_index = score_target.selected
	_hide_panels()
	hud.show()
	$Content/HUD/TopName.text = HockeyArena.AI_PROFILES[options.difficulty].display_name.to_upper() + " AI" if options.player_count == 1 else "PLAYER 2"
	$Content/HUD/BottomName.text = "YOU" if options.player_count == 1 else "PLAYER 1"
	$Content/HUD/Rule.text = "FIRST TO %d  /  %s" % [options.winning_score(), "SOLO" if options.player_count == 1 else "LOCAL DUEL"]
	arena.start_match(options)

func _update_score(bottom: int, top: int) -> void:
	$Content/HUD/BottomScore.text = str(bottom)
	$Content/HUD/TopScore.text = str(top)

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
	overlay.show()

func _resume() -> void:
	overlay.hide()
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
	overlay.show()

func _show_settings(origin: String) -> void:
	settings_return = origin
	_hide_panels()
	settings_panel.show()

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

func _set_music(value: float) -> void:
	Settings.music_volume = value / 100.0
	Audio.apply_settings()

func _set_sounds(value: float) -> void:
	Settings.effects_volume = value / 100.0

func _back() -> void:
	if settings_panel.visible:
		_close_settings()
	elif setup.visible:
		_show_menu()
	elif arena.state == HockeyArena.State.PAUSED:
		_resume()
	elif arena.state == HockeyArena.State.FINISHED:
		_show_menu()
	elif not menu.visible:
		_pause()

func _apply_feedback_visibility() -> void:
	arena.effects.sparks.visible = not Settings.reduced_effects
	arena.effects.burst.visible = not Settings.reduced_effects
	for halo_path in [
		"Content/Arena/BottomPaddle/Halo", "Content/Arena/TopPaddle/Halo",
		"Content/Arena/Puck/Halo", "Content/Menu/Preview/CyanPaddle/Halo",
		"Content/Menu/Preview/PinkPaddle/Halo", "Content/Menu/Preview/Puck/Halo",
	]:
		get_node(halo_path).visible = not Settings.reduced_effects

func _quit_game() -> void:
	await get_tree().process_frame
	Audio.stop_all()
	# Give the audio mixer a frame to release its playbacks before shutdown.
	await get_tree().create_timer(0.08).timeout
	get_tree().quit()
