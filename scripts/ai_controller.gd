class_name AIController
extends Node

var profile: AIProfile
var reaction_remaining: float = 0.0
var aim_offset: float = 0.0
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()

func reset() -> void:
	reaction_remaining = 0.0
	aim_offset = 0.0

func update_target(delta: float, paddle: HockeyPaddle, puck_position: Vector2, puck_velocity: Vector2) -> void:
	reaction_remaining -= delta
	if reaction_remaining > 0.0:
		return
	reaction_remaining = profile.reaction_seconds
	aim_offset = rng.randf_range(-profile.aiming_error, profile.aiming_error)
	var target_x := puck_position.x
	if puck_velocity.y < -20.0:
		var travel_time := maxf((paddle.position.y - puck_position.y) / puck_velocity.y, 0.0)
		var predicted_x := reflected_x(puck_position.x + puck_velocity.x * travel_time)
		target_x = lerpf(target_x, predicted_x, profile.prediction_weight)
	var target_y := 340.0
	if puck_position.y < 620.0:
		# Approach from behind the puck so the strike sends it toward the bottom goal.
		target_y = puck_position.y - 56.0
		if paddle.position.y > puck_position.y:
			target_x += 85.0 if puck_position.x < 360.0 else -85.0
	elif puck_velocity.y < 0.0:
		target_y = 290.0
	else:
		target_x = lerpf(target_x, 360.0, 0.65)
	paddle.target = Vector2(target_x + aim_offset, target_y)

func reflected_x(value: float) -> float:
	# Fold the prediction back into the rink for any number of side-wall bounces.
	var width := 584.0
	var folded := fposmod(value - 68.0, width * 2.0)
	return 68.0 + (folded if folded <= width else width * 2.0 - folded)
