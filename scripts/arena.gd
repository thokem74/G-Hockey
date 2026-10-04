class_name HockeyArena
extends Node2D

signal score_changed(bottom_score: int, top_score: int)
signal countdown_changed(text: String)
signal match_finished(winner: int)
signal state_changed

const AI_PROFILES: Array[AIProfile] = [
	preload("res://resources/ai_easy.tres"),
	preload("res://resources/ai_normal.tres"),
	preload("res://resources/ai_hard.tres"),
	preload("res://resources/ai_expert.tres"),
]
const CYAN := Color("35e5ff")
const MAGENTA := Color("ff388c")

enum State { MENU, COUNTDOWN, PLAYING, GOAL, PAUSED, FINISHED }

var state: State = State.MENU
var options: MatchOptions
var scores: Array[int] = [0, 0]
var countdown_remaining: float = 0.0
var goal_remaining: float = 0.0
var countdown_destination: State = State.PLAYING
var paused_state: State = State.PLAYING
var last_count: int = -1
var conceding_player: int = 0
var shake_remaining: float = 0.0
var paddles: Array[HockeyPaddle] = []
var layout := RinkLayout.new()

@onready var bottom: HockeyPaddle = $BottomPaddle
@onready var top: HockeyPaddle = $TopPaddle
@onready var puck: HockeyPuck = $Puck
@onready var controls: TouchController = $TouchController
@onready var ai: AIController = $AIController
@onready var effects: Node2D = $Effects
@onready var rink: HockeyRink = $Rink

func _ready() -> void:
	paddles.assign([bottom, top])
	controls.paddles = paddles
	controls.layout = layout
	puck.layout = layout
	ai.layout = layout
	configure_layout(layout.logical_size)
	puck.impact.connect(_on_impact)
	puck.goal_scored.connect(_on_goal)
	set_physics_process(false)

func _physics_process(delta: float) -> void:
	_update_shake(delta)
	match state:
		State.COUNTDOWN:
			countdown_remaining -= delta
			var count := ceili(countdown_remaining)
			if count != last_count and count > 0:
				last_count = count
				countdown_changed.emit(str(count))
				Audio.play_sound("countdown", 0.65)
			if countdown_remaining <= 0.0:
				state = countdown_destination
				puck.active = state == State.PLAYING
				countdown_changed.emit("")
				state_changed.emit()
		State.PLAYING:
			bottom.move_toward_target(delta)
			if options.player_count == 1:
				ai.update_target(delta, top, puck.position, puck.velocity)
				top.move_toward_target(delta, ai.profile.movement_speed)
			else:
				top.move_toward_target(delta)
			puck.simulate(delta, paddles)
			effects.update_trail(puck.position, puck.velocity.length() > 80.0)
		State.GOAL:
			goal_remaining -= delta
			if goal_remaining <= 0.0:
				_reset_round(conceding_player)
				_begin_countdown()

func configure_layout(logical_size: Vector2) -> void:
	var previous_bounds := layout.bounds
	var changed := not logical_size.is_equal_approx(layout.logical_size)
	var preserve_match := state != State.MENU
	if changed and state in [State.PLAYING, State.COUNTDOWN, State.GOAL]:
		pause_match()
	layout.configure(logical_size)
	bottom.court = layout.paddle_court(0, HockeyPaddle.RADIUS)
	top.court = layout.paddle_court(1, HockeyPaddle.RADIUS)
	rink.apply_layout(layout)
	if changed and preserve_match:
		for paddle in paddles:
			var remapped := layout.remap_position(paddle.position, previous_bounds)
			remapped.x = clampf(remapped.x, paddle.court.position.x, paddle.court.end.x)
			remapped.y = clampf(remapped.y, paddle.court.position.y, paddle.court.end.y)
			paddle.reset_at(remapped)
		puck.position = layout.remap_position(puck.position, previous_bounds)
		controls.clear()
		ai.reset()
		effects.clear()
	elif state == State.MENU:
		_reset_round(0)

func start_match(match_options: MatchOptions) -> void:
	options = match_options.duplicate() as MatchOptions
	controls.player_count = options.player_count
	ai.profile = AI_PROFILES[options.difficulty]
	scores = [0, 0]
	score_changed.emit(0, 0)
	visible = true
	set_physics_process(true)
	_reset_round(0)
	_begin_countdown()

func return_to_menu() -> void:
	state = State.MENU
	puck.active = false
	controls.clear()
	effects.clear()
	rink.position = Vector2.ZERO
	shake_remaining = 0.0
	visible = false
	set_physics_process(false)
	countdown_changed.emit("")

func pause_match() -> void:
	if state not in [State.PLAYING, State.COUNTDOWN, State.GOAL]:
		return
	# A second pause during a resume countdown must retain a pending goal reset.
	paused_state = countdown_destination if state == State.COUNTDOWN else state
	state = State.PAUSED
	puck.active = false
	controls.clear()
	countdown_changed.emit("")
	state_changed.emit()

func resume_match() -> void:
	if state == State.PAUSED:
		_begin_countdown(State.GOAL if paused_state == State.GOAL else State.PLAYING)

func handle_input(event: InputEvent) -> void:
	if state != State.PLAYING:
		return
	# Converting from viewport to arena coordinates also handles screen scaling.
	if event is InputEventScreenTouch:
		var point: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		if event.pressed and not event.canceled:
			controls.press(event.index, point)
		else:
			controls.release(event.index)
	elif event is InputEventScreenDrag:
		controls.drag(event.index, get_global_transform_with_canvas().affine_inverse() * event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			controls.press(-1, get_global_transform_with_canvas().affine_inverse() * event.position)
		else:
			controls.release(-1)
	elif event is InputEventMouseMotion:
		controls.drag(-1, get_global_transform_with_canvas().affine_inverse() * event.position)

func _reset_round(server: int) -> void:
	bottom.reset_at(layout.paddle_start(0))
	top.reset_at(layout.paddle_start(1))
	puck.reset_at(layout.serve_position(server))
	controls.clear()
	ai.reset()
	effects.clear()

func _begin_countdown(destination: State = State.PLAYING) -> void:
	state = State.COUNTDOWN
	countdown_destination = destination
	countdown_remaining = 3.0
	last_count = -1
	puck.active = false
	controls.clear()
	state_changed.emit()

func _on_goal(player: int) -> void:
	scores[player] += 1
	conceding_player = 1 - player
	controls.clear()
	score_changed.emit(scores[0], scores[1])
	var color := CYAN if player == 0 else MAGENTA
	effects.celebrate(layout.goal_position(player), color)
	shake_remaining = 0.22
	if Settings.vibration and OS.has_feature("android"):
		Input.vibrate_handheld(65)
	if scores[player] >= options.winning_score():
		state = State.FINISHED
		Audio.play_sound("victory")
		countdown_changed.emit("")
		match_finished.emit(player)
	else:
		state = State.GOAL
		goal_remaining = 1.4
		countdown_changed.emit("GOAL!")
		Audio.play_sound("goal")
	state_changed.emit()

func _on_impact(location: Vector2, strength: float, paddle_hit: bool) -> void:
	Audio.play_sound("paddle" if paddle_hit else "wall", strength / 1000.0)
	effects.impact(location, CYAN if paddle_hit else Color("b4ff85"))

func _update_shake(delta: float) -> void:
	shake_remaining = maxf(shake_remaining - delta, 0.0)
	# Only the decorative rink moves; gameplay and touch coordinates stay fixed.
	if shake_remaining > 0.0 and Settings.screen_shake and not Settings.reduced_effects:
		rink.position = Vector2(sin(shake_remaining * 190.0), cos(shake_remaining * 140.0)) * shake_remaining * 14.0
	else:
		rink.position = Vector2.ZERO
