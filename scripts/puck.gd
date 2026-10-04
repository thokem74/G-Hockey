class_name HockeyPuck
extends Node2D

signal impact(location: Vector2, strength: float, paddle_hit: bool)
signal goal_scored(player: int)

const RADIUS := 20.0
const MAX_SPEED := 1800.0

var layout: RinkLayout
var velocity := Vector2.ZERO
var active: bool = false
var collision_cooldown: float = 0.0

func reset_at(location: Vector2) -> void:
	position = location
	velocity = Vector2.ZERO
	active = false
	collision_cooldown = 0.0

func simulate(delta: float, paddles: Array[HockeyPaddle]) -> void:
	if not active:
		return
	collision_cooldown = maxf(collision_cooldown - delta, 0.0)
	# Small steps keep both the puck and fast paddles from crossing a collision.
	var steps := maxi(1, ceili(MAX_SPEED * delta / 8.0))
	var step_delta := delta / steps
	for step in range(steps):
		position += velocity * step_delta
		for paddle in paddles:
			var sample := paddle.position - paddle.velocity * step_delta * (steps - step - 1)
			_collide_paddle(paddle, sample)
		_collide_walls()
		if position.y < layout.bounds.position.y - RADIUS:
			active = false
			goal_scored.emit(0)
			return
		if position.y > layout.bounds.end.y + RADIUS:
			active = false
			goal_scored.emit(1)
			return
	velocity *= pow(0.985, delta)

func _collide_paddle(paddle: HockeyPaddle, sample: Vector2) -> void:
	var separation := position - sample
	var distance := separation.length()
	var combined_radius := RADIUS + HockeyPaddle.RADIUS
	if distance >= combined_radius:
		return
	var normal := separation / distance if distance > 0.001 else Vector2.DOWN
	position = sample + normal * (combined_radius + 0.1)
	var incoming := (velocity - paddle.velocity).dot(normal)
	if incoming < 0.0:
		velocity -= normal * incoming * 1.92
		velocity = velocity.limit_length(MAX_SPEED)
		_emit_impact(absf(incoming), true)

func _collide_walls() -> void:
	var puck_bounds := layout.bounds.grow(-RADIUS)
	if position.x < puck_bounds.position.x:
		position.x = puck_bounds.position.x
		velocity.x = absf(velocity.x)
		_emit_impact(absf(velocity.x), false)
	elif position.x > puck_bounds.end.x:
		position.x = puck_bounds.end.x
		velocity.x = -absf(velocity.x)
		_emit_impact(absf(velocity.x), false)
	# The puck must fit fully through the goal; round posts close the corners.
	for post in layout.goal_posts:
		var separation: Vector2 = position - post
		if separation.length() < RADIUS + RinkLayout.POST_RADIUS:
			var normal := separation.normalized() if separation.length() > 0.001 else Vector2.DOWN
			position = post + normal * (RADIUS + RinkLayout.POST_RADIUS + 0.1)
			if velocity.dot(normal) < 0.0:
				velocity = velocity.bounce(normal)
				_emit_impact(velocity.length(), false)
	var outside_goal := position.x < layout.goal_left or position.x > layout.goal_right
	if outside_goal and position.y < puck_bounds.position.y and velocity.y < 0.0:
		position.y = puck_bounds.position.y
		velocity.y = absf(velocity.y)
		_emit_impact(absf(velocity.y), false)
	elif outside_goal and position.y > puck_bounds.end.y and velocity.y > 0.0:
		position.y = puck_bounds.end.y
		velocity.y = -absf(velocity.y)
		_emit_impact(absf(velocity.y), false)

func _emit_impact(strength: float, paddle_hit: bool) -> void:
	if collision_cooldown <= 0.0 and strength > 60.0:
		impact.emit(position, strength, paddle_hit)
		collision_cooldown = 0.035
